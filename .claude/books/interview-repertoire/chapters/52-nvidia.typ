#import "../../theme/lib.typ": listing, callout, xref-to, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at nvidia

Nvidia's page counts its questions and almost nothing else. The
header says 105, updated 10.07.2026, the companies index rolls the
same company up to 81, the footer links all 24 first-hand
experiences, and the question list runs 6 pages, but no numeric
round count and no numeric difficulty count appears anywhere, the
FAQ's prose is the whole characterization. What the page does
publish is an identity: a verification plan for a FIFO and an
arbiter asked of a new grad, endianness and ring buffers in
firmware, CUDA GEMM tiling and memory coalescing named as data
scientist subtopics, int8 quantization as its own card. This
chapter maps that prose loop, works the page's flagship coding
prompt test-first in go, the multi-producer multi-consumer circular
buffer at 29 likes and 275 solved, beside the streaming top-k card
that refuses a heap in its own title, and walks 2 design prompts in
the #xref-to("repertoire", "design-prompts") voice, the
autonomous-vehicle camera pipeline and the control plane for a
compute cluster, because a company that builds the hardware asks
systems questions about the machines that run it.

== the loop map [DRILL]

The FAQ carries the sequence in prose, quoted verbatim: `recruiter
screen, one or two technical phone screens, then a virtual onsite
loop of four to six interviews in one or two days followed by a
hiring manager conversation.` That is the whole map, and the honesty
to keep is that the counts other pages in this arc publish as spread
tables are absent here by name: round distribution is not displayed
as counts, difficulty is not either, and the added-in-last-90-days
and AI-assisted fields are not displayed at all, absent is the
honest reading, never zero.

The header counter says 105 questions, updated 10.07.2026, and the
question list shows 20 results on page 1 of 6. The footer link says
`All 24 NVIDIA interview experiences`, 8 of them visible on page 1.
The FAQ's one concession to duration is preparation, not rounds:
candidates with regular practice are `interview-ready in four to six
weeks`, field switchers `should plan eight to twelve weeks`, and the
final 7 to 10 days go to full mock loops and behavioral rehearsals.

== the bank [DRILL]

Roles split by surface, and the split is the page's own honesty
problem. The intro prose names Software Engineer, Data Scientist and
Machine Learning Engineer as the core roles, no counts attached. The
explore-more block carries exactly one role row, Software Engineer
84, and nothing else, so the data scientist and ML engineer banks are
citable as present and uncountable, never as zeros.

Categories split the same way. The intro prose names Coding &
Algorithms and System Design first, then Software Engineering
Fundamentals, Behavioral & Leadership, and Machine Learning, no
counts. The explore-more block counts three of them: Coding &
Algorithms 33, Software Engineering Fundamentals 21, Behavioral &
Leadership 15. System Design, named second in the intro, is exactly
the one the counting surface omits, and Software Engineering
Fundamentals, named third, is the one it ranks second, so every
number here carries its surface's name.

Difficulty is prose only, the FAQ's characterization: software
engineering screens `skew medium-to-hard for coding`, senior roles
demand `systems reasoning, low-latency design, and deep CUDA or ML
deployment fluency`. The one countable difficulty signal is a page-1
observation, surface named: 4 of the 20 visible cards are tagged
Hard and 2 Easy, the remaining 14 Medium.

== quirks of this loop [DRILL]

The hardware accent is the identity. A hard card at 5 likes and 86
solved asks for `Verification Plan for a FIFO, a Round-Robin Arbiter
and a Valid/Ready Handshake`, targeted at a Software Engineer New
Grad, which is the tell, at nvidia even the new grad software loop
reaches for hardware protocols. C++ smart pointers appear twice,
once as `Implement a Thread-Safe Reference-Counted Smart Pointer in
C++`, medium, 4 likes, 48 solved, and once locked as `Implement and
Explain a C++ Smart Pointer`, medium, 13 likes, 1 comment, 104
solved. Firmware gets its own card, `Reason About Endianness, Ring
Buffers, and Stack Behavior in Firmware`, medium, locked, 5 likes,
87 solved. The ML lane's version of the same instinct is `FP32 to
Int8 Tensor Quantization: Scale, Zero Point, Clipping and Outliers`,
medium, 2 likes, 38 solved: precision and layout, not just accuracy.

The FAQ subtopics second the motion. Data scientists drill `CUDA
GEMM optimizations including tiling and memory coalescing`, software
engineers get `disk-space managers, KV stores, URL shorteners, and
low-latency system design`, and across roles the page demands
`complexity analysis, concurrency and memory reasoning`. The tips
block asks GPU-role candidates to `explicitly reason about memory
access patterns, tiling, occupancy, and coalescing`.

The experience entries add 2 tracks unique to this page among the 12
in this arc: a QA Engineer thread, a unique-word Python script
screen, a project walkthrough with DSA and a long timeline, a
HackerRank with a pending onsite, and an Embedded Engineer thread, a
firmware protocol system design and a two-hour C coding screen. The
rest set the tempo: a new grad verification-role offer after eight
weeks, a GPU search engine team phone screen on counting distinct
strings, applied scientist research deep dives, and three onsite
rounds rejected three days later.

== recurring prompts [DRILL]

Where each recurring shape floors in this corpus, by chapter id:

The ring buffer flagship worked below, `Design a Multi-Producer
Multi-Consumer Circular Buffer`, hard, locked, 29 likes, 275 solved,
and the firmware card `Reason About Endianness, Ring Buffers, and
Stack Behavior in Firmware`, medium, locked, 5 likes, 87 solved,
floor on the concurrency discipline of
#xref-to("patterns", "concpatterns") and on the scheduler and memory
model behind it, #xref-to("repertoire", "go-runtime").

The top-k card worked below declines the heap in its own title, and
the heap family it declines floors on the implemented priority
queue of #xref-to("repertoire", "datastructures").

`Merge Sorted Arrays, Then Scale to Huge Files and a Global Sort of
N Files`, medium, 2 likes, 33 solved, floors on the external merge
of #xref-to("dsa", "sorting").

`Count Substrings with No Repeated Characters`, hard, locked, 5
likes, 83 solved, floors on the window family of
#xref-to("repertoire", "algopatterns").

`Return all file paths via DFS`, easy, 27 likes, 192 solved, and
`Determine Whether One Point Can Reach Another`, hard, locked, 9
likes, 112 solved, floor on the graph walks of
#xref-to("repertoire", "graphs").

The memory, stack, and concurrency reasoning the FAQ subtopics
demand across roles floors on
#xref-to("repertoire", "systems-answers"), and both design prompts
walked below run the protocol of
#xref-to("repertoire", "design-prompts") against the register of
#xref-to("repertoire", "design-answers") with the arithmetic of
#xref-to("repertoire", "estimation-answers").

Three cards have no corpus home, and the absence is part of the
honest picture. The verification plan card, FIFO, arbiter, and
valid-ready handshake, is digital design territory this corpus does
not teach. The int8 quantization card and the CUDA GEMM tiling and
coalescing subtopics are GPU numerics, same verdict. When the loop
asks them, work them from first principles and stated arithmetic the
way the walkthroughs below do.

== the multi-producer multi-consumer circular buffer, worked [TDD]

The visible card is titled `Design a Multi-Producer Multi-Consumer
Circular Buffer`, hard, locked, tagged Software Engineering
Fundamentals, Concurrency, Data Structure Design, Software Engineer
Senior+, 29 likes, 0 comments, 275 solved, dated Jul 16 2026, the
most engaged card on the page by likes and by solves. The premium
body is gated, so the prompt is authored from the title and the
tags: a bounded ring, many producers, many consumers, concurrent
enqueues and dequeues, no external lock.

The design puts a sequence number on every slot and lets arithmetic
separate full from empty with no count field anywhere. Each slot
starts at its own index, head and tail are free-running counters
that never wrap, and a mask maps a position to its slot. A producer
reads the tail, finds the slot for that position, and may claim it
only when the slot's sequence equals the position, one
compare-and-swap on the tail settles the race against every other
producer, then the value lands and the sequence publishes the claim:

#listing("interview-repertoire/samples/ch52-go/ring.go", first: 33, last: 49, caption: [enqueue: the claim ladder, the cas settles the producer race, the sequence store publishes the value])

A consumer is the mirror image. It claims a position when the
sequence has reached position plus one, wins it with one
compare-and-swap on the head, reads the value, then releases the
slot for the next lap by storing position plus capacity, the exact
position at which that slot becomes writable again:

#listing("interview-repertoire/samples/ch52-go/ring.go", first: 51, last: 67, caption: [dequeue: the release arithmetic, pos plus capacity hands the slot to the next lap])

Full and empty fall out of the sequence arithmetic without a count:
a slot whose sequence sits below the attempted position is still
occupied one lap back, the ring is full and the enqueue refuses, and
a slot whose sequence has not reached position plus one is not yet
published, the ring is empty for that consumer. One capacity law is
load-bearing and the constructor enforces it: capacity must be a
power of two of at least 2, because at capacity 1 the release store
position plus 1 equals the publish store position plus 1, the full
check goes blind, and a second enqueue overwrites an unconsumed
value. The counters are int64 and free-running, at a billion
operations a second they outlive the machine.

The suite is 5 test functions under `go vet` and `go test -race`. A
hand-traced walk pins fifo order across a refill at capacity 4, a
laps test fills and drains capacity 8 three times so slot reuse
across laps is exercised, and the contract test holds the capacity
law. The concurrency differential runs 4 producers by 250 values
through capacity 64 with 4 consumers and asserts the collected
multiset is exactly the offered one, every value once:

#listing("interview-repertoire/samples/ch52-go/ring_test.go", first: 100, last: 124, caption: [the multiset differential: every offered value seen exactly once, deadline-guarded, race-clean])

The order test is the strictest, capacity 2, one producer, one
consumer, 5000 values, arrival order asserted value by value under
the race detector, the smallest legal ring spinning at its fullest
and emptiest. The discipline floors on
#xref-to("patterns", "concpatterns"), and the memory model claims
that make the plain value field safe between the sequence stores are
the ones #xref-to("repertoire", "go-runtime") drills.

== streaming top-k frequent elements, worked [TDD]

The visible card is titled `Streaming Top-K Frequent Elements with
O(1) Updates Instead of a Heap`, medium, 3 likes, 0 comments, 30
solved, dated Sep 15 2026, tagged Software Engineering Fundamentals,
Data Structure Design, Heaps & Priority Queues. The title does the
interviewer's work, it names the structure everyone reaches for and
forbids it. The premium body is gated, so the prompt is authored
from the title: a stream of items, a fixed k, maintain the k most
frequent with constant-time updates, no heap.

The answer is the space-saving sketch. At most k items are tracked,
each holding an approximate count, and the counts live in buckets
strung on a doubly linked list in ascending order, each bucket
holding its items in arrival order. An increment is one node moving
one bucket right, a constant-time splice. A new item arriving when
all k slots are full evicts the head of the minimum bucket,
deterministic because arrival order is the rule, and takes its place
at the minimum count plus one, which is the sketch's whole error
story:

#listing("interview-repertoire/samples/ch52-go/counter.go", first: 44, last: 72, caption: [add and promote: the eviction rewrites the node in place, the increment is one splice right, an empty bucket unlinks])

The plus-one is not decoration, it is the error bound. A tracked
item's reported count can only over-count, by at most the final
minimum counter, and any untracked item's true count sits at or
below that same minimum, so the tracked set holds every candidate
for heavy hitter. The eviction keeps the node and rewrites its item,
no allocation on the hot path, and the map lookup plus one splice is
the whole cost of an update.

The suite is 4 test functions. Hand-traced streams pin the eviction
arithmetic, k of 2 over the stream `a b a c` ends at a of 2 and c of
2 with b evicted, and the determinism test runs one seeded stream
through 2 counters and demands identical output. The differential is
the error bound itself, 300 seeded rounds over an 8-item alphabet at
every k from 2 to 5 against exact counts computed in the test:

#listing("interview-repertoire/samples/ch52-go/counter_test.go", first: 96, last: 116, caption: [the error-bound differential: tracked counts stay between exact and exact plus min, untracked counts stay at or below min])

The heap family this card declines, the sift arithmetic and the
position map it would have needed, floors on
#xref-to("repertoire", "datastructures"), and the differential
discipline is the one chapter 41 built for the byte oracle.

== the autonomous-vehicle camera pipeline and its perception system [DRILL]

From the visible card, `Design an Autonomous-Vehicle Camera Pipeline
and Its Perception System`, medium, 4 likes, 36 solved, dated Sep 15
2026, tagged System Design, System Design Fundamentals, Computer
Vision, Software Engineer Senior+, with a locked twin, `Design an
Autonomous-Vehicle Perception Pipeline`, medium, 4 likes, 64 solved.
The prompt is authored from the title and the tags: several cameras
feed a perception stack that must detect and track objects
continuously, on the vehicle, in real time.

The estimation, assumptions stated, arithmetic this chapter's own in
the method of #xref-to("repertoire", "estimation-answers"). Assume 8
cameras at 1920x1080 and 30 frames a second in YUV 4:2:0: 3.1 MB a
frame, 240 frames a second across the sensor set, 746 MB/s of raw
pixels per vehicle, 2.7 TB an hour. That one product kills every
design that uploads raw video and closes the loop on the vehicle:
what leaves the car is encoded clips, roughly 10 Mbps a camera is
10 MB/s, and detections measured in KB. The second arithmetic is the
latency budget, sensor to plan in 100 ms, capture and ISP around 20,
inference 25, tracking 5, fusion and planning 30, about 20 of
headroom. The third decides the compute shape: 240 inferences a
second at 3 ms a pass is 72 percent of one accelerator, so the batch
is 8 cameras wide inside one timestamp, never across time.

#flow(
  [the loop closes on the vehicle, only clips and detections leave it],
  node((0, 0), [8 cameras, #linebreak() 30 fps each]),
  node((0, 1.2), [isp + aggregate, #linebreak() 746 MB/s]),
  node((0, 2.4), [timestamped rings, #linebreak() the backpressure device]),
  node((0, 3.6), [detection, #linebreak() 8-wide, one timestamp]),
  node((0, 4.8), [tracking, #linebreak() ids across frames]),
  node((2.4, 3.6), [clip selector, #linebreak() 10 MB/s encoded]),
  node((2.4, 4.8), [upload queue, #linebreak() detections in KB]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 2.4), (2.4, 3.6), "->"),
  edge((2.4, 3.6), (2.4, 4.8), "->"),
)

The walk over hops: each camera stamps its frames at the sensor, the
isp stage aggregates the 8 streams, timestamped ring buffers hold
seconds of history so the tracker can reach back, detection runs
batched across the 8 cameras of one timestamp, the tracker lifts
detections into persistent ids, and the clip selector picks what
deserves the 10 MB/s upload budget beside the detection stream.

The bottleneck, volunteered before being asked: memory bandwidth
into the accelerator, not flops. Moving 746 MB/s of pixels dwarfs the
cost of the arithmetic once they are resident, so the pipeline's
shape is about copies, zero-copy handoffs, the model reading from
the ring's own memory, and batching that raises the arithmetic done
per byte moved.

The traps, 1 line each. Timestamp at the sensor, never at the
consumer, clock domain drift is invisible downstream otherwise. The
ring is the backpressure device, overload drops whole oldest frames
and never blocks the camera. A failed inference is a degraded mode
with a fallback model and an event, never a crash. Exposure and
shutter sync across cameras is a calibration contract, stereo and
motion estimation fail quietly without it. Detections and clips are
the only egress, the bandwidth story and the privacy story are the
same story.

== the control plane for a compute cluster [DRILL]

From the visible card, `Design the Control Plane for a Compute
Cluster: Host Monitoring + Job Dispatch`, medium, locked, 23 likes, 0
comments, 214 solved, dated Jun 20 2026, tagged System Design,
System Design Fundamentals, Fault Tolerance & Failover. The prompt
is authored from the title: a fleet of hosts reports cpu, memory,
disk, and gpu state, jobs arrive with resource asks, and the control
plane places them and survives its own failures.

The estimation, assumptions stated, arithmetic this chapter's own.
Assume 10k hosts heartbeating every 5 seconds at 1 KB: 2k heartbeats
a second, 2 MB/s of ingress, one process's nic. Job arrivals at 50 a
second, each placement a scan over an in-memory view of the fleet,
and 10k hosts at 2 KB a record is 20 MB of state, one process's
memory. Those three numbers decide the shape before any box is
drawn: a small hot state with 2 independent paths through it, a
write-heavy monitoring path and a read-and-place dispatch path, on a
hot-standby pair over a replicated log, not a fleet of
microservices.

#flow(
  [heartbeats write the state, dispatch reads it, the log makes both survive],
  node((0, 0), [10k host agents, #linebreak() 1 KB every 5 s]),
  node((0, 1.2), [heartbeat ingest, #linebreak() 2k a second]),
  node((0, 2.4), [replicated log, #linebreak() quorum, replayable]),
  node((0, 3.6), [fleet view, #linebreak() 20 MB in memory]),
  node((2.2, 3.6), [scheduler, #linebreak() 50 placements a second]),
  node((2.2, 2.4), [dispatch api, #linebreak() leases, idempotent starts]),
  node((0, 4.8), [failure detector, #linebreak() timeout, requeue lanes]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (2.2, 3.6), "->"),
  edge((2.2, 3.6), (2.2, 2.4), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (2.2, 3.6), "-|>", label: [requeue]),
)

The walk over hops: the host agent samples cpu, memory, disk, and
gpu counters and ships a 1 KB heartbeat, the ingest path stamps and
validates it, the replicated log is the durability boundary and the
replay source, the fleet view is the in-memory projection the
scheduler scans, placements leave as leases through the dispatch
api, and the failure detector watches heartbeat gaps and requeues
the jobs of hosts that go silent.

The bottleneck, volunteered: the rescheduling storm, not steady
state. One rack of 40 hosts holding 10 jobs each is 400 jobs
re-queued inside seconds while the heartbeat flood and the
re-dispatch collide on the same view, so the requeue path needs
priority lanes, rate limits, and jitter, and the timeout window is
tuned so a rack blip does not trigger a mass re-schedule of jobs
that were fine.

The traps, 1 line each. Dispatch grants leases, at-least-once with
idempotent starts, never assume the agent that acked is the agent
that runs. Monitoring and dispatch fail independently, a blind
scheduler that keeps placing is worse than one that stops. Failover
is a quorum decision, an odd number of voters, never a race between
2 standbys. Per-job metric labels are a cardinality bomb, aggregate
per host and sample per job. A heartbeat proves liveness, not
progress, a wedged trainer still hearts.

#callout("pitfall", "the surfaces disagree on every count", [
  The header says 105 questions while the companies index says 81,
  the intro names 3 roles with no counts while the explore block
  counts only Software Engineer 84, the intro ranks System Design
  second among categories while the explore block omits it entirely
  and counts the other three, and the question list shows 20 results
  on page 1 of 6 with the rest premium-gated. Every number in this
  chapter carries the surface it came from because the surfaces
  disagree, the page's own header is the company number, and an
  absent count is absence, never zero.
])

sources: every count in this chapter traces to
`ref/prachub/nvidia/page.md`, fetched 2026-10-15 from
prachub.com/companies/nvidia/ and pinned verbatim, through the
transcription at `ref/prachub/nvidia/facts.md`, with the
companies-index rollup read from the pinned index bytes. The worked
prompts are authored from visible truncated card titles only,
premium-gated bodies never quoted or reconstructed, and both design
walkthroughs carry their arithmetic as stated assumptions in the
#xref-to("repertoire", "estimation-answers") method, arithmetic this
chapter's own, not numbers from the page. No other online source was
consulted for this chapter.
