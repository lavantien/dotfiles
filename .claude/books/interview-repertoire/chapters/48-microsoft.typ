#import "../../theme/lib.typ": listing, callout, xref-to, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at microsoft

Microsoft is the volume entry in this arc and the porous one. The
pinned page serves 291 questions while the companies index rolls the
same company up to 173, updated 09.30.2026 with 17 added in the last
90 days, and its loop leaks code into every stage: the FAQ records
lowest common ancestor and merge intervals put to machine learning
engineers in the HR screen, a boundary no other page in this arc
records. This chapter maps that loop, works its 2 most engaged coding
prompts test-first, a binary-searched houses pick in go and an
ai-generated url shortener bug hunt in c sharp, and walks its 2 most
microsoft-distinctive design prompts in the
#xref-to("repertoire", "design-prompts") voice, a lab machine fleet
monitor with hang detection and remote reboot, and a windows app
notification system built while working with an ai assistant.

== the loop map [DRILL]

Four stages, counted by the intro paragraph and the FAQ together:
technical screens carry 107 questions, onsites 99, online assessments
15, and HR screens 11. Those 4 buckets sum to 232 against the header's
291, so the round tags overlap or leave questions untagged, and the
page publishes no reconciliation, the same surface discipline this
arc keeps everywhere. The header counter itself: 291 questions,
updated 09.30.2026, 17 added in the last 90 days, 1 AI-assisted round
tag in the whole set. The question list shows 20 results on page 1 of
15. First-hand experiences split by surface too: the intro paragraph
says 30, the footer link says `All 63 Microsoft interview experiences`,
and 8 of them are visible on page 1.

The porous boundary is the FAQ's own sentence, quoted verbatim:
`Coding problems turn up across the onsite, the online assessment, and even the HR screen, where lowest common ancestor and merge intervals were put to machine learning engineers.`
Three role-specific interview guides also live on the site, the FAQ's
closing note on the loop.

== the bank [DRILL]

Roles, with each number named to its surface. The intro paragraph and
the FAQ agree: Software Engineer 144, Data Scientist 44, Machine
Learning Engineer 33. The FAQ adds 7 for product managers, 3 for
technical program managers, and 1 for data engineering. The
explore-more block says Software Engineer 200, Data Scientist 43,
Machine Learning Engineer 33. Software Engineer is the disagreement,
144 against 200 on one page, and any claim cites its surface.

Categories, intro paragraph: Coding & Algorithms 108, System Design
33, Behavioral & Leadership 22, Machine Learning 20, ML System Design
14, Software Engineering Fundamentals 13. The explore-more block
counts Coding & Algorithms 133, System Design 44, Behavioral &
Leadership 33, Machine Learning 21, Software Engineering
Fundamentals 21, ML System Design 17, every row higher, so the 2
surfaces measure different things and neither explains itself.

Difficulty, from the page's spread block: 171 medium, 41 hard, 20
easy. The FAQ's own characterization is worth keeping verbatim for
its shape: `Expect standard-shaped algorithm problems asked cleanly rather than exotic ones.` Seniority, FAQ block: 188 General, 34 Senior+,
10 intern or new grad, a set weighted to the generalist.

== quirks of this loop [DRILL]

The HR screen carries code, and that is the quirk. Merge intervals
and lowest common ancestor in a screen most companies reserve for
schedules and relocation means the round boundaries are porous in
practice, and preparing for a "behavioral" slot at microsoft still
means warming the tree walks of
#xref-to("repertoire", "datastructures").

The FAQ names its problem families plainly: graphs, trees, and grids
run through the recorded set, minimising fuel cost across cities,
minimum moves on a grid with k-cell jumps, the best connected strength
for every tree node, and lowest common ancestor in both a binary tree
and a binary search tree. Bit manipulation and intervals appear.
Candidate reports add a DNA reassembly problem with an Euler path
follow-up and a knapsack solution that timed out, the rare page where
a report names the follow-up rather than the base question.

The ai thread is louder here than the 1 AI-assisted round tag
suggests. The visible cards carry 3 ai-flavored entries: the
ai-generated shortener bug hunt at 94 likes and 633 solved, the most
engaged card on the page by likes and by solves, a behavioral card on
your view of ai tools in engineering work, and the windows
notification design card itself tagged AI-Assisted Development. The
experience entries close the loop: an SDE-2 loop pairing an
ai-assisted design round with a Linux cp deep dive.

The experiences set the tempo, 8 visible of the claimed 30 or 63:
four rounds in one day, a screen and four hiring-event rounds, the
SDE-2 ai-assisted loop above, language expectations and stateful
naming in a rejection, a virtual onsite after which the req was
cancelled, two renamed leetcode problems in a 75-minute online
assessment, product pages with trackable links and anonymous users,
and four back-to-back rounds where the candidate was late to the
first one.

== recurring prompts [DRILL]

Where each recurring shape floors in this corpus, by chapter id:

Trees and lowest common ancestor, asked in both the binary tree and
the binary search tree form, floor on the implemented search trees of
#xref-to("repertoire", "datastructures").

The visible grid card, `Sizes of 4-Connected Foreground Regions in a Binary Image, in Scan Order`, easy at 16 likes and 127 solved, floors
on the 4-connected regions card of #xref-to("repertoire", "classics1").

The window and binary search families, the most frequent substring
card, the zero-sum triplets card, and the houses pick worked below,
floor on #xref-to("repertoire", "algopatterns"), which owns both
halves of that solution.

Grids with jumps and the DNA reassembly Euler path follow-up floor on
#xref-to("repertoire", "graphs").

The shortener bug hunt worked below floors on
#xref-to("repertoire", "design-prompts"), which owns the shortener
design and its base62 codec workspace in go.

The ai-assist norms, what an assistant may see and what it may never
send, and the debugging round shape itself floor on
#xref-to("repertoire", "observed-answers").

The Linux cp deep dive floors on
#xref-to("repertoire", "systems-answers") for the syscall and page
cache mechanics it walks.

The fallback design card, food-delivery proximity search within 10
km, floors on the geo predicate of #xref-to("repertoire",
"db-answers").

The behavioral battery, negative feedback and what changed,
cross-region collaboration, the deadline you will miss and why adding
engineers late backfires, ranking 8 candidates for 1 role, floors on
the register of #xref-to("repertoire", "behavioral-answers").

== the houses pick, worked [TDD]

The visible card is titled `Minimize the Largest Value When Picking at Least k Non-Adjacent Houses`,
medium, 7 likes, 92 solved, dated Sep 7 2026. The premium body is
gated, so the prompt is authored from the title alone: given a row of
house values and a quota k, pick at least k pairwise non-adjacent
houses so the largest picked value is as small as possible.

The decision procedure binary-searches the answer over the sorted
distinct values, and feasibility at a threshold t is one greedy
left-to-right scan that takes every house with value at most t and
not adjacent to the last take. Both halves floor on
#xref-to("repertoire", "algopatterns"), the search family and the
greedy family.

Why the greedy check is enough, the exchange argument: greedy's first
pick sits at or before the optimal's first, and whenever greedy's
i-th pick sits at or before the optimal's i-th, the optimal's next
pick is eligible after greedy's too, so greedy's next is again at or
before it, and by induction greedy makes at least as many picks as
any eligible set. Monotonicity is the other leg, raising a threshold
only adds eligible houses and never removes a pick, so feasibility
is monotone and the binary search is legal. The answer is a house
value by construction, the max of the winning set is one of its own
picked values, so the search space is the sorted distinct values and
nothing wider.

The at-least-k phrasing is a free lunch worth saying aloud: any
at-least-k set contains an exactly-k subset no worse, so the two
optima coincide and the greedy never stops at k, it counts
everything the threshold admits. The contract errors are 2, each
pinned by a test: a non-positive k is refused outright, and a k above
(n+1)/2, the most non-adjacent picks a row of n houses allows, is
infeasible at every threshold because adjacency, not value, binds.

#listing("interview-repertoire/samples/ch48-go/houses.go", first: 13, last: 43, caption: [the search over sorted distinct values, the greedy feasibility scan that counts everything the threshold admits])

The oracle battery is 2 brute forces that share no code with the
solution, one enumerating every non-adjacent subset for the best max,
one counting the most eligible picks at a fixed threshold. 500 seeded
random arrays drive both against the implementation at every feasible
k:

#listing("interview-repertoire/samples/ch48-go/houses_test.go", first: 71, last: 87, caption: [the differential run: 500 seeded arrays, every feasible k, the brute-force best max against the searched answer])

Beside the differential, the table of 10 named facts pins the
semantics, the inner pair beating the rails, full parity forcing the
rails, negative values, the adjacency cap at k above half, and the
boundary pin that the answer is feasible while the next lower
distinct value is not. 6 test functions under `go vet` and
`go test -race`, and the red run came first, all 6 failing against a
stub that answered every call with the k error before a line of the
search existed.

== the ai shortener bug hunt, worked [TDD]

The visible card is titled `Find the Bugs in an AI-Generated URL Shortener`,
locked, medium, 94 likes, 2 comments, 633 solved, dated Jun 12 2026,
the most engaged card on the page by likes and by solves. The premium
body is gated, so the defect classes are authored, and the prompt
shape is a red-first bug hunt: the workspace ships the ai-generated
shortener, the spec suite that fails on it first, then the fixed
implementation.

The 3 defect classes, each one found by a red test:

The decode edge. The ai decode loop stops 1 character early, so
single-character codes decode to 0 and `10` decodes to 1. The latent
twin sits beside it, `Alphabet.IndexOf` returns -1 on a bad byte and
the fold turns it into a wrong value instead of an error.

The code collision window. The ai pool's `Reserve` reads the cursor
and returns it without advancing, so every window reservation hands
back the same start, one instance re-mints `0` for every url and two
instances collide on every code, and the first url is silently lost
to the map overwrite.

The unbounded alias. `RegisterAlias` accepts any string, a
5000-character alias and one carrying slashes both land in the route
namespace, and a route namespace with no bounds is a contract with no
edges.

#listing("interview-repertoire/samples/ch48-cs/src/AiShortener.cs", first: 22, last: 41, caption: [the ai artifact under audit: the decode that drops the final character, the reserve that never advances])

The fixes, each with its reason. Decode walks every character with
the pre-multiply overflow check before the accumulate, because a
wrapped int64 is silent, the same codec law the go shortener of
#xref-to("repertoire", "design-prompts") pins. `Reserve` advances the
cursor under a lock, written as `size > Ceiling - _next` so no
intermediate can overflow. The alias contract is 1 to 16 characters
from the code alphabet, rejection rather than sanitization, because
an alias is a route and a route is a contract:

#listing("interview-repertoire/samples/ch48-cs/src/Base62.cs", first: 26, last: 45, caption: [the fixed decode: every character read, the digit table rejecting unknown bytes, the overflow check before the multiply])

The hunt surfaces 1 namespace subtlety worth its own test: aliases
and counter codes share one map, a user who registers the alias `10`
has taken the spelling of counter code 62, so the counter path skips
past a spelled code instead of overwriting the alias, and 63 shorts
around the collision pin it. The red run came first, 3 spec tests
against the ai artifact and 3 failures, 1 per defect class, then the
fixed classes landed and the hunt suite flipped to asserting the
defects as pinned behavior beside the spec suite. 26 test methods
expanding to 33 xunit cases under `dotnet test`, and the 3 defect
assertions now fail loudly if anyone "fixes" the artifact the hunt
documents.

== the lab machine fleet monitor [DRILL]

From the visible card, `Design a Lab Machine Fleet Monitor: Payload Dispatch, Hang Detection, and Remote Reboot`,
easy, 4 likes, 69 solved, dated Sep 30 2026. Requirements: queue test
payloads with machine requirements, os sku, gpu class, region,
schedule them onto idle matching machines, detect payloads that hang,
reboot the machines hosting a confirmed hang, and rejoin machines
after reboot. Non-functional: dispatch decisions in seconds, a hang
flagged within minutes, no payload lost to a reboot, reboot actions
audited and rate limited per machine.

The estimation, assumptions stated, arithmetic this chapter's own in
the method of #xref-to("repertoire", "estimation-answers"). Assume
5000 machines each cycling payloads back to back at 20 minutes a
payload: that is 5000 over 1200 seconds, about 4 dispatches a second
steady and 20 at a 5x morning peak when nightly runs finish.
Payloads at 2 GB each, os and game images are heavy, fetched from
content-addressed storage at an 80 percent hit rate, so the miss
stream is 0.8 fetches a second steady and 1.6 GB per second at peak,
which is why machines pull and the scheduler never ships bytes.
Heartbeats every 10 seconds per machine are 500 tiny writes a second.
The fleet state is 5000 records at 4 KB, 20 MB, one process's
memory, so scale is not the question here, coordination and failure
handling are.

#flow(
  [machines pull payloads, the monitor watches heartbeats and cuts power],
  node((0, 0), [payload queue, #linebreak() requirements, id]),
  node((0, 1.2), [scheduler, #linebreak() idle match, seconds]),
  node((0, 2.4), [machine agent, #linebreak() pulls by cache key]),
  node((0, 3.6), [payload runner, #linebreak() heartbeat 10 s]),
  node((0, 4.8), [monitor, #linebreak() silence window, backoff]),
  node((2.2, 4.8), [reboot channel, #linebreak() fence token, audit]),
  node((0, 6.0), [results sink, #linebreak() retry by payload id]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (2.2, 4.8), "->", label: [confirmed hang]),
  edge((2.2, 4.8), (0, 2.4), "-|>", label: [rejoin]),
  edge((0, 3.6), (0, 6.0), "->"),
)

The walk over hops: the queue holds payloads keyed by id with their
machine requirements, the scheduler matches them against idle
machines in seconds, the machine agent pulls the payload bytes by
content key so a cached 2 GB image costs nothing, the runner executes
and heartbeats every 10 seconds, the monitor holds a silence window
per payload, a confirmed hang escalates through the reboot channel
with a fencing token so 2 monitors never cut power twice, the machine
reboots, the agent rejoins the pool, and the interrupted payload
re-enters the queue by id while its partial results land in the sink.

The bottleneck, volunteered: the flapping machine, not the dispatch
throughput. One machine that hangs every payload becomes a reboot
loop that burns fleet capacity and audit budget, so reboots back off
exponentially per machine and a machine over its daily reboot
allowance drops into quarantine, where it holds for a human instead
of cycling. The system's scarce resource is operator attention, and
the quarantine tier is where it is spent.

The traps, 1 line each. Silence means the channel may be dead, not
the machine, cross-check the management controller before cutting
power. Kill the runner on the machine when abandoning a payload
server-side, or the "dead" payload keeps writing results. Re-dispatch
dedupes by payload id with an idempotent runner, at-least-once
delivery is fine, double execution is not. A machine mid image
upgrade is a new machine, pin payload-to-image compatibility. The
heartbeat path and the results path share a queue at your peril, one
backlog then hides as hangs.

== the windows app notification system with an ai assistant [DRILL]

From the visible card, `Design a Windows App Notification System While Working With an AI Assistant`,
medium, 1 like, 26 solved, dated Sep 6 2026, tagged System Design
Fundamentals and AI-Assisted Development, and paired on-page with the
behavioral card on your view of ai tools in engineering work. It is
the most microsoft-distinctive design card in the cache because the
surface is windows itself.

Requirements: apps raise notifications, the system renders toasts and
keeps them in the action center, focus assist and do-not-disturb are
hard gates no notification may bypass, notifications deep link into
app content, and the assistant layer summarizes the feed, drafts
replies, and surfaces what matters, with raw content staying on the
device unless the user consents per category.

The estimation, assumptions stated, arithmetic this chapter's own.
Assume 100 million devices running the client at 50 notifications per
user per day: 5 billion events a day, about 58k a second steady and
5x at the evening peak, and rendering is local, so the service side
sees only the cross-device and assistant traffic. Windows already
ships a push fabric, the design rides it rather than rebuilding it.
The assistant is the cost center: on-device triage with a small
quantized model gates everything, and one cloud digest per hour per
opted-in user, assume 10 million opted in, is about 2.8k model calls
a second at 2k input tokens each, roughly 6 million input tokens a
second at peak, a spend line that dictates the split.

#flow(
  [local render free, on-device triage gating a metered cloud digest],
  node((0, 0), [app events]),
  node((0, 1.2), [local store, #linebreak() dedupe, persist]),
  node((0, 2.4), [renderer, #linebreak() toast + action center]),
  node((2.2, 2.4), [focus assist, #linebreak() hard gate]),
  node((0, 3.6), [on-device triage, #linebreak() small model]),
  node((0, 4.8), [digest queue, #linebreak() hourly, jittered]),
  node((0, 6.0), [cloud digest, #linebreak() opted in, per category]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (2.2, 2.4), "-|>", label: [gates]),
  edge((0, 1.2), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (0, 6.0), "->"),
)

The walk over hops: an app raises an event, the local store persists
it and dedupes re-raises, the renderer turns it into a toast and an
action center entry with focus assist gating both, the on-device
triage model scores the stream continuously and costs the device
only, the digest queue batches what triage marked worth a summary,
jittered so the fleet does not spike on the hour, and the cloud
digest returns one summary plus drafts the user can open from the
action center. Deep links ride the original event, so a tap lands in
the app at the content, not at a home screen.

The bottleneck, volunteered: the model lifecycle, not the pipes. The
on-device model ships inside the client and ages in place, so triage
quality decays between releases while the notification stream drifts,
which forces a model version floor, telemetry on triage precision,
and a keyword-rule fallback when the model is stale, the same
ship-then-age problem any embedded model carries.

The traps, 1 line each. Focus assist is a contract, a notification
that bypasses it is a product bug shipped as a feature. The action
center persists, so the same event re-raised after reboot must merge,
never duplicate. Deep links need contract-stable uris that survive
app updates, a broken link is a deleted notification. The assistant
drafts and never sends, the ai-assist norm of
#xref-to("repertoire", "observed-answers"). Consent per category, not
per app and not global, or the setting dies unused and the assistant
goes dark either way. Digest latency is a product promise, an hourly
summary of a meeting starting now is worthless, urgent tiers bypass
the queue on device rules alone.

#callout("pitfall", "the count that is not the company number", [
  The companies index rolls microsoft up to 173 questions while the
  company page's own header says 291, updated 09.30.2026. The page's
  own count is the company number everywhere in this arc, the rollup
  is a different measurement published nowhere with its method, and
  the gap of 118 questions is larger than many whole companies in the
  cache. Every count in this chapter names its surface, the header
  counter, the intro paragraph, the FAQ, the explore-more block, or a
  visible card row, because the surfaces disagree on every page and
  microsoft's disagree the most.
])

sources: every count in this chapter traces to
`ref/prachub/microsoft/page.md`, fetched 2026-10-15 from
prachub.com/companies/microsoft/ and pinned verbatim, through the
transcription at `ref/prachub/microsoft/facts.md`. The worked prompts
are authored from visible truncated card titles only, premium-gated
bodies never quoted or reconstructed, and both design walkthroughs
carry their arithmetic as stated assumptions in the
#xref-to("repertoire", "estimation-answers") method, arithmetic this
chapter's own, not numbers from the page. No other online source was
consulted.
