#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at google

Google's loop, as candidates report it, is front-loaded with coding.
The page this chapter stands on carries 636 questions by its own
header counter, 306 from technical screens and 203 from onsite
rounds by its FAQ, and the mix skews medium. The same page disagrees
with itself in the open, which is why every count below names the
surface it came from: the header counter, the intro paragraph, the
FAQ block, or the explore-more block. The companies index rolls
Google up to 416 questions, the page itself says 636, and the page
wins, because the page's own number is the company number and the
rollup is somebody else's addition.

The chapter follows the arc the other loop chapters follow. The loop
map first, the rounds and their weights. The bank second, roles,
categories, difficulty, each number pinned to its surface. The
quirks third, Googleyness above all, the named behavioral identity
no other arc page carries, plus the visible first-hand experience
entries. Then the recurring prompts as an xref map into chapters
that already work them, two prompts worked fresh here in go, the
url router from a reported L4 onsite round and the dynamic island
count, and two design drills in the
#xref-to("repertoire", "design-prompts") protocol, a ci system that
runs one million tests in ten minutes and llm summarization of
e-commerce reviews with attackers inside the input.

== the loop map [DRILL]

The rounds, from the FAQ's own distribution. 306 questions are
tagged technical screen, 203 onsite. Online assessments contribute
a smaller set whose count the page does not state, and recruiter or
HR screens carry 10. Coding shows up in both technical stages, and
the FAQ says the behavioral round assessed on Googleyness sits
mostly in the onsite block. Say the map aloud in that order,
screen, onsite, then the thin OA and recruiter layers, because the
prep budget follows it: the median candidate's loop is decided in
the two coding-bearing stages.

The header block frames the whole bank. Questions 636, updated
10.06.2026, 63 added in the last 90 days, 3 questions tagged as
AI-assisted rounds. The intro paragraph repeats 636, 63, and
three on its own, so those three survive a two-surface check, the
update date lives in the header alone. The
first-hand experiences do not: the intro paragraph says 99, the
footer link says all 146, and the honest statement is that the page
carries at least 99 and links a fuller list. The question list
itself shows 20 results on page 1 of 32, so only about 20 card
titles are public, and this chapter quotes no card body, only
visible titles, because pages 2 to 32 and the locked card are
premium-gated and stay unfetched.

The 636 against 416 split is worth 30 seconds in any prep
conversation. The companies index page claims 416 for Google, the
company page counts 636, and nothing on either page reconciles
them. Work from 636, name the surface, and move on.

== the bank [DRILL]

Roles, and the surfaces agree twice. The intro paragraph and the
FAQ both say Software Engineer 322, Data Scientist 145, Machine
Learning Engineer 37, Product Manager 30, and the FAQ adds a
handful of Data Engineer entries. The explore-more block runs
higher, 399, 147, 46, 30, the same order with looser counting. The
two-surface pair is the one to carry into the room, SWE at roughly
half the bank, DS at roughly a quarter.

Categories, where the surfaces disagree by more than rounding. The
FAQ is the fullest named split: Coding and Algorithms 233,
Behavioral and Leadership 84, System Design 43, Machine Learning
38, Analytics and Experimentation 37, Statistics and Math 33. The
intro paragraph states the first three and compresses the rest into
a remainder clause. The explore-more block says 269, 105, 50, 46,
40, 34, and adds Software Engineering Fundamentals 33 and ML System
Design 20, rows the FAQ does not carry. Study from the FAQ split,
it names every bucket, and treat the explore block as a reminder
that the bank also holds data-structure-design and ml-design rows
worth a pass.

Difficulty, from the FAQ and the intro paragraph in agreement: 368
medium, 129 hard, 41 easy. The mix skews medium, the page's own
sentence, and the hard tier is the second-largest slice. Timed
practice at medium with hard mixed in is the shape of the bank.

== quirks of this loop [DRILL]

Googleyness is the quirk. The FAQ states it plainly, the behavioral
round is assessed on Googleyness and sits mostly in the onsite
block, a named rubric no other company page in this arc carries.
Two visible experience entries echo it from the candidate side, one
onsite with a Googlyness manager question beside a grid path and a
max-rectangle problem, one loop with a phone screen, Googlyness,
and two graph-heavy onsite rounds. Prep it with the story cards of
#xref-to("repertoire", "behavioral-answers"), and say the word
Googleyness when the behavioral round opens.

The visible experience entries carry the rest. A team-matching
timeline after the onsite, so the loop does not end at the last
round. A senior loop downleveled from L5 to L4 after round 1,
openly, with findBestAnagram and three behavioral questions in the
screen. An engineering analyst reporting four team matches and a
verbal offer after a long loop. A new-grad technical screen whose
second question was verbal only. An intern screen with a 10-minute
resume grill then first missing positive in O(1) space. A PhD
intern with two back-to-back original coding rounds. Two of those
eight touch this chapter directly, the URL router one below is a
reported L4 onsite round 2, and the missing-positive grill is the
recurring-prompts map's sharpest row.

== recurring prompts [DRILL]

The 20 visible card titles, mapped to chapters that already work
them. The two this chapter works fresh follow in their own
sections.

The graph family dominates. Group prerequisite-linked courses into
the earliest possible rounds is Kahn's topological sort, worked in
#xref-to("repertoire", "graphs"). Reachability between stations in
a timed train schedule is the same chapter's traversal discipline
on a schedule-shaped graph. Count islands in a grid and track the
count as land cells are added is worked below and floors on
#xref-to("repertoire", "weightedgraphs").

The structure family. Median of all values across several sorted
integer arrays is the two-heap median over k heads,
#xref-to("repertoire", "datastructures"). Return all binary search
tree keys inside an inclusive range is the same chapter's ordered
walk with bounds pruning. Find the nearest common manager of K
employees in a reporting tree is the ancestor question on that
tree. Repeatedly delete leaves matching a target value is the
post-order deletion the tree section's walk already carries.

The array family. Smallest missing positive integer in linear time
and constant space is the index-as-hash span walk of
#xref-to("dsa", "arrays"), and the intern experience above says it
arrives right after a resume grill. The first larger value for
every element of a circular array and the O(1) range query asking
whether a subarray's elements are all distinct both reduce to the
precompute-then-query register of #xref-to("repertoire",
"algopatterns"), the window section's last-seen map is the same
table the distinctness query needs, doubled around the circle for
the circular walk. Detect timed-out RPC calls from paired start and
end log records is a pairing sweep the two-pointers section frames.

The stats and design family. Explain p-values and confidence
intervals in simple linear regression floors on
#xref-to("math", "statistics") with the spoken register of
#xref-to("repertoire", "math-answers"). Compare predictive models
from two vendors is the model-evaluation row the same pair covers.
Design an LLM agent for manufacturing sits on the page as an
ML System Design row, this chapter works the two primary design
prompts instead. Predict the most frequent next word in constant
time is the one locked card on page 1, premium-gated, its title is
public and its body is not, and nothing here quotes it. The
behavioral pair, the senior's four-story card and the why-google
card, drill with #xref-to("repertoire", "behavioral-answers").

== worked: the url router [TDD]

The card is visible on page 1: implement a URL router that matches
request paths against patterns with placeholders, tagged Software
Engineering Fundamentals, Data Structure Design and Trees, rated
hard, role Software Engineer, 203 solves against 22 likes. The
experience list makes it real, a reported L4 onsite round 2 with
two coding questions and a URL router. The title is the whole
public statement of the problem, so the requirements come from the
title and standard router sense: patterns carry literal segments
and `:name` placeholders, a placeholder matches exactly one
segment, and matching must be deterministic.

The design is one decision. A pattern is a vector of segments, each
literal or named, and a path matches when segment counts align and
every literal equals its path segment. Precedence compares the
vectors left to right, literal beats placeholder, so `/users/new`
wins over `/users/:id` on the path `/users/new` and `/a/:x` wins
over `/:y/b` on `/a/b` because the leftmost difference decides:

#listing("interview-repertoire/samples/ch46-go/router.go", first: 46, last: 102, caption: [the match walk, then the precedence rule: compare segment by segment from the left, literal weight 2 over placeholder weight 1])

The determinism argument is the part to say at the board. Two
patterns that match the same path with equal weight vectors must
have literals in the same positions holding the same values, since
each literal must equal the path's segment there, so they differ
only in placeholder names. That shape is rejected at registration
time, `/users/:id` and `/users/:uid` cannot coexist, which removes
the tie before it can reach a match:

#listing("interview-repertoire/samples/ch46-go/router.go", first: 104, last: 118, caption: [shape equality ignores placeholder names, so two routes that can only ever tie are refused at registration])

Malformed input dies on both sides. Patterns need a leading slash,
no trailing slash, no empty segment, placeholder names that are
non-empty letters and digits, and no repeated name within a
pattern. Paths fail closed the same way, empty, missing slash,
trailing slash, or an interior empty segment all return no match
rather than an error, because a request path is data, not a
contract. The suite pins all of it, 11 test functions under `go
vet` and `go test -race`, with the precedence table carrying the
load:

#listing("interview-repertoire/samples/ch46-go/router_test.go", first: 67, last: 92, caption: [the precedence pin: leftmost literal wins at the first differing segment, and a shape neither route owns matches neither])

The traps, one line each. Registration order as the tiebreaker,
refused here because ties are refused. Wildcards in the middle of a
segment, out of scope, say so and keep placeholders whole-segment.
Trailing-slash tolerance, a product decision this router refuses
rather than half-honors. The tree tag on the card invites a trie of
segments, a fine optimization at thousands of routes and noise at
interview scale, the linear scan with the weight rule is the answer
that ships in 45 minutes.

== worked: islands as land arrives [TDD]

The second worked prompt is the most-liked unlocked card on page 1:
count islands in a grid and track the count as land cells are
added, tagged Coding and Algorithms with Graphs and Grids and
Matrices, rated medium, role Software Engineer, 115 likes and 847
solves, dated Oct 2, 2026. The dynamic half is the point, land
arrives one cell at a time and the count must answer after every
arrival, which rules out re-flooding the grid per query and picks
union-find, the structure #xref-to("repertoire", "weightedgraphs")
builds with path compression and union by rank.

The count arithmetic is one line: an arrival increments, and every
merge with a distinct neighboring island decrements, so the count
is exact after each add with no global pass:

#listing("interview-repertoire/samples/ch46-go/islands.go", first: 37, last: 58, caption: [one arrival: idempotent on land, increment, then one decrement per actual merge with the four neighbors])

The union is the textbook pair, path halving on find and rank on
union, and the merge report drives the decrement:

#listing("interview-repertoire/samples/ch46-go/islands.go", first: 62, last: 83, caption: [path-halving find, union by rank, the boolean merge report the count consumes])

Eleven test functions hold it, all expectations hand-computed. The
bridge fixture is the one to narrate in an interview, adds at
columns 0, 2, and 4 of a row report 1, 2, 3, then column 1 merges
two islands for 2, then column 3 closes it for 1. The center
fixture lands the four arms then the center, 1, 2, 3, 4, then 1.
The reading-order property is the quiet one, filling a 3 by 3 grid
cell by cell never lets the count exceed 1, because every arrival
after the first touches an existing neighbor. The diagonal fixture
pins what an island is not, corner cells stay separate, and the
re-add fixture pins idempotence, landing twice counts once and
never re-merges.

The traps, one line each. Flood fill per query, O(n^2) over the
add sequence, the trap the title is built around. Counting merges
by neighbors checked rather than merges performed, the four checks
can contain two merges into one island and only real root joins
decrement. Connecting diagonals, islands are 4-connected, the
diagonal fixture fails any 8-connected slip. Resetting on re-add,
the land check comes before the increment or a repeat add
inflates the count.

== design: one million tests in ten minutes [DRILL]

The prompt is a page 1 card, design a CI system that runs one
million tests in ten minutes, tagged System Design with CI/CD and
Job Scheduling. The corpus just acquired its floor for this exact
question, #xref-to("infrastructure", "vcs") carries the Scion
numbers, and this drill quotes them only as that chapter states
them: CI performs on the order of 25 million code checkouts per
day, and CI alone realized a 25 percent cpu capacity win when the
checkout layer was rebuilt. Those two sentences are the premise, a
test fleet's cheapest win is not in the tests.

The arithmetic first, the four-move method of
#xref-to("repertoire", "estimation-answers") on stated assumptions:
one million tests per main merge, a mean of 2 seconds of cpu per
test, a 10 minute wall budget for the verdict. Two million
cpu-seconds over 600 wall seconds is about 3,333 cores busy on average,
so 4,000 test executors with 20 percent headroom for skew. The mean
is not the budget, the tail is: if one test in a hundred runs 60
seconds, random static shards of 250 tests each draw two or three
tails, and the verdict waits on the slowest shard. Scheduling by
work stealing with a per-test timeout at 300 seconds and a retry
lane is a requirement, not a tuning knob, one 60 second straggler
in a 600 second budget spends 10 percent of the wall alone.

#flow(
  [verdict path: affected tests out of the million, warm executors stealing work, cached pairs never rerun],
  node((0, 0), [push]),
  node((0, 1.2), [merge queue, #linebreak() batched verdicts]),
  node((0, 2.4), [change detection, #linebreak() touched targets]),
  node((0, 3.6), [affected-test graph, #linebreak() transitive closure]),
  node((2.2, 3.6), [result cache, #linebreak() test, code, env hash]),
  node((0, 4.8), [work-stealing executors, #linebreak() 4k warm cores]),
  node((0, 6.0), [artifact store, #linebreak() content addressed]),
  node((0, 7.2), [verdict + flake quarantine]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (2.2, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (0, 6.0), "->"),
  edge((0, 6.0), (0, 7.2), "->"),
)

The walk over the hops. The merge queue batches commits, one
verdict per batch, because a per-push fleet at the vcs chapter's
reported 30,000 merges a day
is the stampede the Scion chapter's write rate makes plain. Change
detection diffing the batch's tree against its parent produces
touched targets, the affected-test graph walks the dependency
closure to the test set, and the full million runs only on main
merges, pull requests run their affected slice. The result cache
answers before any executor fires, keyed by test id, code content
hash, and environment hash, and an unchanged pair never reruns.
Executors steal test claims from a shared queue with warm pools,
image and checkout preloaded, which is where the 25-million-a-day
checkout arithmetic lands: a cold checkout per shard is the fleet's
hidden second job, and the vcs chapter's 25 percent cpu capacity
win came from exactly that layer, so the design says warm pools,
content-addressed snapshots, and no naive fetch anywhere. The
artifact store keeps every test's outputs content addressed so a
retry or a flake rerun reuses inputs. The verdict hop aggregates
with partial results streaming, failures reported the moment they
happen, and the flake quarantine moves a test that fails then
passes on retry out of the blocking path with a budget, never an
infinite retry.

The bottleneck, volunteered: the slowest single test owns the
verdict, so the tail and the setup dominate, the mean is a
scheduling detail. Second, the artifact store becomes the write
amplifier, every cached result is a write, and its throughput caps
the fleet at a place nothing in the test code suggests.

The traps, one line each. Static shards, tails strand and the
verdict waits. Cache keyed on code hash alone, an image bump
invalidates nothing and lies green. Rerunning the full million per
push, the stampede again. Retrying flakes forever, the quarantine
with a retry budget is the trust answer, and a suite nobody
believes is worse than a slow one. The merge queue as FIFO
theater, batching only helps if the batch shares one verdict.

== design: review summarization with attackers inside [DRILL]

The second design card on page 1: design LLM summarization of
e-commerce reviews with prompt-injection and PII defenses, tagged
System Design with Application Security and LLM Applications. The
prompt names its own traps, injection and data leakage, so the
security posture is the answer, not the model choice, and the named
taxonomy behind the injection half is #xref-to("repertoire",
"security-answers").

The arithmetic, stated: 2 million new or edited reviews a month at
a mean 150 tokens each is 300 million input tokens a month, about
114 tokens a second sustained, call the daily peak 3x at roughly
340. Batched inference absorbs that without a conversation, so
throughput is not the design's problem. The tail is: one product
with 100,000 reviews is 15 million tokens, no single context holds
it, so summarization is map-reduce per product, chunked partial
summaries folded in batches, with the fold bounded by stratified
sampling, newest 10,000 reviews plus a rating-stratified spread,
stated as a product contract because it is one, the summary
describes a window of the review stream and the page must say so.

#flow(
  [reviews in, redacted before the model, summaries validated and cached by content hash],
  node((0, 0), [review ingest]),
  node((0, 1.2), [pii redaction, #linebreak() before the model]),
  node((0, 2.4), [per-product buffer, #linebreak() content hash keyed]),
  node((0, 3.6), [map: chunk summaries]),
  node((0, 4.8), [reduce: stratified fold, #linebreak() bounded input]),
  node((0, 6.0), [output validation, #linebreak() injection + pii scan]),
  node((2.2, 6.0), [summary cache, #linebreak() content addressed]),
  node((0, 7.2), [product page]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (0, 6.0), "->"),
  edge((0, 6.0), (2.2, 6.0), "->"),
  edge((0, 6.0), (0, 7.2), "->"),
)

The walk. Ingest receives attacker-controlled text by definition, a
review can say anything, so the first hop redacts before any model
sees bytes: pattern and detector-based PII scrubbing at ingest,
because redacting after generation is too late, a paraphrase can
reassemble what a filter would have caught. The per-product buffer
keys on the content hash of its review set, so a summary cache hit
requires the input multiset to be unchanged, and edits invalidate
cleanly. The map hop summarizes fixed-size chunks under an
instruction hierarchy, review text rides inside delimited data
blocks marked untrusted, never in the instruction channel, and the
summarizer gets no tools and no access tier above the reviews
themselves, an injected instruction that cannot reach a privilege
is a sentence, not an attack. The reduce hop folds the partials
over the bounded, stratified sample. Output validation scans the
generated summary for both classes, injection artifacts like
instruction text leaking into prose, and PII the redaction missed
or the model reconstructed, and fails closed to a template summary,
never to an unvalidated one. Serving reads the cache.

The bottleneck, volunteered: the ingest redaction scan runs on
every review at arrival, a steady per-review floor the model's
batch capacity never touches, so the scanner's throughput is the
system's heartbeat. Second, the tail product, one viral listing
spikes a single fold to the bound.

The traps, one line each. Injection as a prompt-wording problem,
it is a privilege problem, the instruction hierarchy and the
toolless summarizer are the fix. Coordinated review poisoning, the
aggregate is attacker-steerable at scale and needs cluster
anomaly detection on the review stream, not a stronger system
prompt. Cache poisoning, a bad summary cached forever, the content
hash key plus output validation before the write. Post-hoc PII
filtering only, redact at ingest, scan at egress, both. The
unbounded fold, a context-window error on a tuesday for one
product, the sampling bound is the contract that prevents it.

sources: every count and card fact in this chapter traces to
`ref/prachub/google/page.md`, the prachub google company page
fetched 2026-10-15 and cached verbatim, transcribed into
`ref/prachub/google/facts.md` with each number pinned to the
surface that states it, header counter, intro paragraph, FAQ block,
or explore-more block. Only page 1 of the question list, its 20
visible card titles and their metadata, is public, pages 2 to 32
and the locked card body are premium-gated and were neither fetched
nor reconstructed, and the worked prompts are authored from the
visible titles alone. The scion numbers in the ci drill are quoted
from #xref-to("infrastructure", "vcs") as that chapter states
them. No other online source was consulted for this chapter.
