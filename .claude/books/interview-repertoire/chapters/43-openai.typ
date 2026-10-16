// chapter 43: the openai loop, the page's own numbers, payments and
// gpu scheduling as the design spine, two worked go prompts
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at openai

One page, 373 questions, and a shape the page itself calls
design-weighted. The openai bank at prachub leans harder on system
design than any other company page in this arc, its explore block is
the only one that ranks design above coding, and the same page says
 outright that its hard band sits in payments and streaming. This
chapter reads the page the way the no-metrics law demands, every
count named to the surface it came from because the surfaces
disagree with each other, then works the two most-engaged coding
cards test-driven in go, a fault-tolerant work queue and a
spreadsheet engine with cycle detection, and drills two design
walkthroughs in the #xref-to("repertoire", "design-prompts") voice,
card payments with tips and nightly settlement, and a text-to-video
GPU scheduler with fair queueing.

The discipline is the arc's discipline. Only page 1 of the question
list is public, its 20 visible card titles, and every worked prompt
here is authored from those visible titles alone. The premium-gated
bodies on pages 2 to 19 were never fetched, never quoted, never
reconstructed. Counts come from the header, the intro paragraph, the
FAQ block, the footer, and the explore block, each named at use,
because the intro says 49 first-hand experiences while the footer
link says 73, and the intro's role counts sit far under the explore
block's for the same roles on the same page.

== the loop map [DRILL]

The header says 373 questions, updated 10.10.2026, 51 added in the
last 90 days. The question list runs 19 pages and shows 20 results
on page 1. The rounds, from the FAQ block's own question about the
loop: 179 questions tagged technical screen, 91 onsite, 12 from HR
screens, 5 from online assessments. Screen-heavy is the reading to
say aloud, 179 of the 287 tagged rounds are screens of one kind or
another, so the first live conversation decides most outcomes, and
the onsite is where the design band lands.

The FAQ's loop descriptions are the citable color: a phone screen
followed by a virtual onsite, one loop with a silent extra round
afterwards, another with two back-to-back screens and no break, and
system design appearing as a Design ChatGPT session. The intro
paragraph counts 49 first-hand experiences on the site, the footer
link says all 73, and 8 experience entries are visible on page 1.
The discrepancy is not noise to resolve, it is the surface law in
action, each number is quoted with its surface and neither is
silently promoted over the other.

#diagram([the round funnel the page reports, and the loop shapes its candidates describe], length: 13pt, {
  // left: round counts as a descending bar stack, right: loop shapes
  let bar(y, count, label) = {
    let w = calc.max(0.4, calc.round(count * 0.024, digits: 2))
    cdraw.rect((0.4, y), (0.4 + w, y + 1.15), fill: luma(215), stroke: luma(120), radius: 0.02)
    cdraw.content((1.1 + w, y + 0.55), [#label], size: 6pt)
  }
  cdraw.content((3.3, 9.4), [faq round tags, 287 tagged of 373], size: 6.5pt)
  bar(7.9, 179, [technical screen 179])
  bar(6.6, 91, [onsite 91])
  bar(5.3, 12, [hr screens 12])
  bar(4.0, 5, [online assessments 5])
  cdraw.content((13.9, 9.4), [loop shapes candidates describe], size: 6.5pt)
  let shape(y, name, line) = {
    cdraw.rect((10.4, y), (17.4, y + 1.1), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((13.9, y + 0.62), [#name], size: 6pt)
    cdraw.content((13.9, y + 0.22), [#line], size: 5.5pt)
  }
  shape(7.9, [phone screen], [then a virtual onsite])
  shape(6.6, [one loop], [a silent extra round after])
  shape(5.3, [another loop], [two screens, back to back, no break])
  shape(4.0, [the design round], [a Design ChatGPT session])
  cdraw.content((11.7, 2.4), [screens decide most outcomes,#linebreak()the onsite carries the design band], size: 6pt)
})

== the bank [DRILL]

Roles, from the intro paragraph: Software Engineer 178, Machine
Learning Engineer 77, Data Scientist 21, plus a few Android, iOS and
Frontend entries. The explore block's role tiles say 255, 84, and 22
for the same three roles, higher on every row. The category split,
intro paragraph first: Coding and Algorithms 91, System Design 82,
ML System Design 30, Machine Learning 28, Software Engineering
Fundamentals 20, Behavioral and Leadership 13. The explore block
re-ranks the same bank: System Design 115 first, Coding and
Algorithms 99 second, Software Engineering Fundamentals 51, Machine
Learning 34, ML System Design 30, Behavioral and Leadership 20. The
only page in this arc whose explore block puts design above coding,
and the design-weighted reading survives both surfaces: intro
arithmetic puts System Design plus ML System Design at 112 against
Coding's 91, the explore block's gap is wider still at 145 against
99.

Difficulty, from the FAQ's own hard question: 117 hard, 160 medium,
10 easy, a steep curve where hard is a much larger share than easy.
The same FAQ answer says the hard band sits mostly in system design,
naming the streaming AI feature and the high-throughput payment
settlement prompts, plus fundamentals with awkward semantics such as
implementing a set with readable snapshots.

The header count is the company number throughout: 373 questions,
not the companies-index rollup, which is stale across the whole site
and undercounts every page in this arc. Where this chapter quotes a
distribution it names the surface, header, intro, FAQ, footer, or
explore block, and where two surfaces disagree both numbers stand.

== quirks of this loop [DRILL]

The FAQ loop shapes, said aloud as the drill: the canonical loop is
a phone screen then a virtual onsite. One reported loop had a silent
extra round after the candidate believed it was over, so the loop
does not end when you think it ends, ask the recruiter what remains
before you relax. Another had two back-to-back screens with no
break, so stamina is part of the design, a snack and a prepared
reset ritual between screens is a real tactic. And the design round
can arrive as a Design ChatGPT session, a product-design conversation
about a system you use, which rewards having opinions about the
product's failure modes, not just its architecture.

The visible first-hand entries on page 1 give the loop its texture,
quoted by their titles. Two rejected phone screens, one failed on a
fault-tolerant queue plus a typing race design, one failed on a
malloc implementation, and both cards are visible in the bank, the
work queue card is this chapter's first worked prompt and the
allocator discipline behind malloc is the memory law of
#xref-to("c-os-cloud", "allocators"). An onsite rescheduled a dozen
times that still ran a GPU credit coding round, and a separate entry
reports strong coding closed out as a borderline case after the
virtual onsite, the calibration to prepare for: strong is not safe,
the design band decides. One in-progress screen paired the same
fault-tolerant queue with a metrics monitoring design round, an
onsite ran a real-time trivia battle royale platform design, another
ran a three-part sliding window coding round, and the data scientist
entry is a free-trial take-home followed by four final rounds, a
different loop shape from the engineer track entirely.

The rescheduled-dozen-times entry is the one to internalize: the
loop's calendar chaos is normal, the loop's content is stable.
Payments, streaming, stateful structures, the same threads recur in
the FAQ's recurring-subjects answer, which is the next section's
whole map.

== recurring prompts [DRILL]

The FAQ names the recurring threads and this corpus already owns
most of them. Payment systems come in three separate framings, the
intro paragraph says authorization, capture and batch settlement,
the high-throughput authorization and settlement system, and the
full lifecycle from hold to charge, and the coffee-shop walkthrough
below works that whole lifecycle. The floor is
#xref-to("repertoire", "distributed-answers") for delivery
semantics, at-least-once into an idempotent consumer, and
#xref-to("repertoire", "db-answers") for money is cents, never
floats.

Generation and streaming services are the second thread, the intro
names asynchronous text-to-video and a large-scale streaming AI
feature, and the second walkthrough below works the text-to-video
scheduler. The floors are #xref-to("infrastructure", "jetstream")
for a durable stream with acks and consumers that actually runs in
this corpus and #xref-to("patterns", "messaging") for the queue
semantics underneath it.

Stateful data structures arrive with real semantics, the intro names
a set with readable snapshots and serializing and restoring an
in-memory key-value store, both are
#xref-to("repertoire", "datastructures") territory with a snapshot
twist. Simulation with immunity is the plant infection grid card,
days to stabilize with immune plants and expiring immunity, a
multi-source flood walk in #xref-to("repertoire", "graphs") clothing.
Matchmaking with clocks, the deterministic topological sort card,
and the linked-list endpoint card all xref to
#xref-to("repertoire", "graphs") as well, the sort card's heap floor
is the priority queue of the same book's structures chapter. The
prefix-product backward pass card, hand-written gradients, is
reverse-mode autodiff done by hand, the running product inverted on
the way back is exactly the adjoint sweep of
#xref-to("math", "autodiff").

Two visible cards have no corpus home and the honest map says so:
the transformer debug cards, four bugs then a KV cache, and the
decoding KV cache itself, have no chapter in this corpus that walks
attention internals, so preparation for the ML engineer track needs
an outside source for those. The design rounds floor on
#xref-to("repertoire", "design-prompts") and
#xref-to("repertoire", "design-answers"), and the 13 Behavioral and
Leadership questions the intro counts floor on
#xref-to("repertoire", "behavioral-answers").

== worked: the fault-tolerant work queue [TDD]

The page's most-engaged card by a wide margin, 147 likes and 1297
solved against the next card's 46 and 532, titled implement a
fault-tolerant work queue that never loses tasks when workers fail.
The card is Medium, tagged Software Engineering Fundamentals with
Data Structure Design and Concurrency, and one visible experience
entry reports failing a phone screen on exactly this prompt, so the
card is not decorative, it stops real candidacies.

The contract the test suite pins first: enqueue assigns a monotonic
id, lease hands the oldest ready task to one worker with a
visibility deadline, ack retires it, and reclaim flips leases whose
deadline passed back to ready. The never-loses property is an
invariant, ready plus leased plus done equals enqueued after any
interleaving, and the delivery contract is at-least-once, a worker
that dies before acking is indistinguishable from a worker that is
merely slow, so redelivery is mandatory and the consumer dedupes on
the task id, the exactly-once-effect shape of
#xref-to("repertoire", "distributed-answers") and the ack-after-effect
law of #xref-to("patterns", "messaging"). Time is injected as a
parameter, the queue never reads a clock itself, so the tests drive
expiry deterministically, and a reclaimed task keeps its id, which
makes redelivery land in original FIFO order for free because lease
picks the smallest ready id:

#listing("interview-repertoire/samples/ch43-go/queue.go", first: 50, last: 98, caption: [lease picks the smallest ready id, ack is valid only while leased, reclaim is the sole reader of deadlines])

The ack contract is where candidates lose the thread. An ack for an
unknown id, an ack of a task never leased, a double ack, and the
late ack after reclaim each fail as distinct errors, because the
late ack means another worker may already hold the task, and
silently accepting it would lose the second delivery's work. The
concurrency test is the gate that earns the card's title: 8
workers, 200 tasks, a third of all lease attempts deliberately
abandoned without ack to simulate deaths, then a reclaim-and-drain
pass, and the assertion is that every enqueued task is acked exactly
once across the whole run, race-clean under
`go test -race`, the concurrency being the point:

#listing("interview-repertoire/samples/ch43-go/queue_test.go", first: 150, last: 209, caption: [the never-loses gate, workers that abandon leases, then reclaim and drain, every task acked exactly once])

Seven test functions over the queue and seven over the spreadsheet
engine, 14 in the module, table-driven with hand-built fixtures,
expected values stated in the test, never observed from the
implementation. The scan-for-min lease is the honest simplicity, O(n)
over the task map per lease, and the interview follow-up is the
production answer, a WAL plus a ready queue in memory and per-task
visibility records, the shape #xref-to("infrastructure", "jetstream")
ships, but the invariant, the ack discipline, and the redelivery
semantics are identical, and that is what the round grades.

== worked: the spreadsheet engine [TDD]

The second card, titled spreadsheet engine with setCell, getCell,
cell references, and cycle detection, 43 likes, 405 solved, Medium,
tagged Graphs with Data Structure Design. The contract the suite
pins: references are letters then a positive row, normalized to
upper case, a cell holds either an integer literal or a formula of
references and integers joined by plus and minus, an unset cell
reads as zero, and a write clears the memo so updates propagate.

Cycle detection is the card's named ask and the suite drives it as a
graph problem, which it is: evaluation is a DFS over the dependency
graph, the active map is the gray set, and a gray hit is a back
edge, the same tri-color walk of #xref-to("repertoire", "graphs").
The diamond case, A1 from B1 and C1, both from D1, pins that shared
ancestors are not cycles, D1 is visited twice through different
paths and only a back edge to an in-progress cell errors, with the
error naming the cell where the cycle closed so the interviewee can
point at the exact ring:

#listing("interview-repertoire/samples/ch43-go/sheet.go", first: 174, last: 216, caption: [memo first, then the gray-set check, unset cells memoize zero, the cycle error names its cell])

#listing("interview-repertoire/samples/ch43-go/sheet_test.go", first: 68, last: 96, caption: [self ring, two-cell ring, a three-cell ring entered mid chain, and the diamond that must not fire])

The whole-memo clear on write is the stated simplicity, O(cells)
per write instead of dependency-indexed invalidation, and saying
the next step aloud is the point of the round: keep a reverse index,
cell to dependents, and on a write walk only the transitive
dependents dirty, which is a topological order over the dependency
graph, kahn's queue from the same graphs chapter with the initial
in-degree taken from the reverse index. Lazy evaluation plus memo
plus a gray set is 43 lines of go, and the parse rejecting
`=A1+` or `=A1*2` at write time, never mid evaluation, is the
failure-mode answer interviewers probe for.

== design: coffee-shop card payments [DRILL]

The card, titled design coffee-shop card payments with tips and
nightly batch settlement at scale, Medium, tagged Payments and
Ledgers with Distributed Transactions and Idempotency, and the FAQ's
recurring-subjects answer names the payments thread as this loop's
first recurring cluster. Requirements, functional first: authorize
at the register while the card is present, adjust a tip after
signature, capture the final amount, settle in a nightly batch per
store, refund, and never double charge. Non-functional: the auth
wait is the customer holding a card, so it is a latency budget of
small seconds end to end, capture and settlement are throughput
problems with no human waiting, and correctness outranks
availability for money, a reconcile job is mandatory.

The arithmetic first, stated assumptions, the four moves of
#xref-to("repertoire", "estimation-answers"). Assume 10000 stores
averaging 200 card transactions per store-day: 2 million charges a
day, 23 per second steady, a morning peak at 10x is 230 authorizes
per second fleet-wide, small per-store load, the fleet number is
what sizes the service. The average ticket with tip, assume 1500
cents plus a 300 cent average tip: every charge is three ledgers at
minimum, the charge, the tip, and the processor fee, so the ledger
takes about 6 million rows a day, 70 per second, and five years of
rows at 200 bytes is about 2.2 terabytes before indexes, one
sharded relational store, not a kv swap. The nightly batch is 2
million rows over a four-hour window, 140 per second, a non-event,
which is the estimate's punchline: the synchronous auth hop is the
only part of this system that is ever hard.

#flow(
  [auth on the hot path, capture async, settlement a nightly batch, reconcile the judge],
  node((0, 0), [register]),
  node((0, 1.2), [store service, #linebreak() idempotent charge id]),
  node((0, 2.4), [payments service, #linebreak() auth, capture, refund]),
  node((2.2, 2.4), [card network, #linebreak() sub-second auth]),
  node((0, 3.6), [double-entry ledger, #linebreak() cents]),
  node((0, 4.8), [batch settlement, #linebreak() nightly, per store]),
  node((2.2, 4.8), [settlement file, #linebreak() from the network]),
  node((0, 6.0), [reconcile job, #linebreak() ledger against file]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (2.2, 2.4), "->", label: [auth, capture]),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (2.2, 4.8), "->"),
  edge((2.2, 4.8), (0, 6.0), "->"),
  edge((0, 3.6), (0, 6.0), "-|>"),
)

The walk over hops. The register takes the card and the store
service mints a client-side charge id before the first network call,
so a retry after a timeout carries the same id and the payments
service sees a duplicate, not a second charge, the idempotency
contract of #xref-to("repertoire", "distributed-answers"). The
payments service authorizes for the base amount plus a tip reserve,
say 20 percent, a hold that guarantees the funds, then capture
lands after signature for the signed amount, the hold-to-charge
lifecycle the intro paragraph names as this page's payments
framing. The ledger appends double-entry rows in cents, the money
law of #xref-to("repertoire", "db-answers"), one append per
business event, never an update in place. The nightly batch groups
captures per store and per processor into one settlement file
exchange, and the reconcile job compares the ledger against the
network's settlement file line by line, every mismatch is a defect
with a name, not a surprise found by accounting at month end.

The bottleneck, volunteered: the synchronous card network auth round
trip, every other hop in this design is local or batch. The answer
is timeout plus retry on the idempotent id, a circuit breaker so a
slow network degrades the register to a clear declined message
rather than a stuck queue, and a terminal-state machine per charge
so a retried auth on a captured charge returns the capture, never a
second hold.

Traps, one line each. Tips above the reserve mean a capture over
the hold, so either incremental auth when the network supports it or
capture the hold and charge the delta as a second transaction, say
which and why. Refunds are a new credit entry against the original
charge id, never a negative re-swipe. Floats for money is an
instant fail, cents and integer arithmetic end to end. The batch is
idempotent per settlement date and store, a rerun after a crash
re-sends the same file idempotently. And the reconcile job owns the
truth: an unreconciled ledger is a liability, quote it in cents or
do not quote it.

== design: the text-to-video GPU job scheduler [DRILL]

The card, titled design a text-to-video GPU job scheduler with one
GPU per task and fair queueing, Medium, tagged Job Scheduling and
Workflows with Fault Tolerance and Failover, the intro's
asynchronous text-to-video generation service arrived in a system
interview. Requirements: tenants submit a prompt and a duration,
jobs run asynchronously, exactly one GPU per task, no sharing, no
preemption of the model state mid pass unless checkpointed, tenants
see queue position, and a noisy tenant cannot starve the rest, fair
queueing is in the prompt, so the fairness mechanism is the design.

The arithmetic, stated assumptions. Assume 10000 jobs a day and a
render cost of one GPU-second per output second, so a 60 second clip
is a GPU-minute and the mix averages 8 GPU-minutes per job: 10000
jobs times 480 GPU-seconds is 4.8 million GPU-seconds a day, about
56 GPU-seconds per wall second, a steady-state fleet of 56 GPUs
busy. The peak is the number that sizes the fleet, a 5x daytime
curve is 280 concurrent, call it 300 GPUs with headroom for failures
and drains, and the daily fleet cost is the number to say aloud
because it makes queueing policy a money conversation: at an
assumed 2 dollars per GPU-hour, 300 idle-ready GPUs cost 14400
dollars a day, and every queue-wait minute a job spends is fleet
time someone paid for.

#flow(
  [one queue per tenant, the scheduler deals GPUs round robin, workers lease jobs],
  node((0, 0), [tenant apis]),
  node((0, 1.2), [job store, #linebreak() idempotent job id]),
  node((0, 2.4), [per-tenant queues, #linebreak() depth capped]),
  node((0, 3.6), [scheduler, #linebreak() round robin, one lease each]),
  node((0, 4.8), [gpu workers, #linebreak() one task per gpu]),
  node((2.2, 4.8), [heartbeat + lease, #linebreak() expired means redeliver]),
  node((0, 6.0), [object store, #linebreak() segments, then notify]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (2.2, 4.8), "<->", label: [lease, heartbeat back]),
  edge((0, 4.8), (0, 6.0), "->"),
)

The walk. Submit mints the job id tenant-side, the store is
append-only, and each tenant gets its own queue with a depth cap so
a flooding tenant fails at submit with a 429 instead of eating
shared buffers, the bucket contract of #xref-to("go", "limit"). The
scheduler deals in round robin across tenant queues, one job leased
per tenant per pass, so fairness is structural: with n tenants
active, each waits at most n minus 1 job starts beyond its own, no
starvation case exists, and the follow-up, weighted fair queueing
for paying tiers, is the same round robin with weights, the answer
that ends the product version of the question. The worker lease is
the worked queue's lease again, a heartbeat and a visibility
deadline, a dead worker's job returns to its tenant queue and reruns
on another GPU, idempotent on the job id so a checkpoint-restarted
render never publishes twice, the delivery semantics of
#xref-to("patterns", "messaging") one chapter down.

The bottleneck, volunteered: not the GPUs, the long tail of jobs.
One GPU per task means no fragmentation ever, but a 60-second job
stuck behind three 8-minute renders waits 24 minutes for a minute of
work, so the scheduler bins jobs by expected duration, stated in
tokens at submit, and keeps a short-job lane so quick clips never
queue behind renders, at least one GPU reserved for it. The honest
trade: binning adds idle time when the mix is thin, and the
mitigation is letting the long lane borrow short-lane GPUs when the
short queue is empty, borrowed back on the next short submit.

Traps, one line each. Checkpoint per segment or the redelivered job
restarts from zero and the lease deadline must exceed the longest
job, else healthy work is reclaimed mid render. One GPU per task is
a utilization decision, say the cost out loud, batched inference on
shared GPUs is the counterfactual the follow-up will raise. The
notify path is a callback plus a poll endpoint, never a held
connection, the async service answer. And tenant quotas ride the
429 at submit, not rejection at dequeue, a job accepted and never
scheduled is an outage with a delay.

sources: every count in this chapter comes from the openai page at
prachub pinned verbatim under `ref/prachub/openai/page.md`, fetched
2026-10-15, sha256
38635e1cb1ef6b1f7ccf8ccb74f6718afb065a1cb551aa5f8a5eeae347550bee,
and transcribed to `ref/prachub/openai/facts.md`, and each count
names its surface at use, header totals, intro paragraph, FAQ block,
footer, explore block, or the visible card table, because the
surfaces disagree, 49 against 73 experiences, 178 against 255
software engineer. Only page 1 of the 19-page list is public and
this chapter used its 20 visible card titles, the premium-gated
bodies were never fetched and every worked prompt is authored from
the visible truncated titles alone. The two design walkthroughs
follow the ch 36 protocol and their arithmetic is the chapter's own,
stated assumptions, not page claims. The go module under
`samples/ch43-go` carries the two worked prompts, 14 test functions
under `go vet` and `go test -race`, expected values from hand-built
fixtures, never observed from the implementation.
