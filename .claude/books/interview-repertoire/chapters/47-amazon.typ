#import "../../theme/lib.typ": listing, callout, xref-to, flow
#import "@preview/fletcher:0.5.8": node, edge

= the loop at amazon

The Amazon page is the widest bank in this arc and the one where the
surfaces disagree the most inside a single url. The header counter
says 862 questions, the companies index still says 555, the intro
counts 71 first-hand experiences while the footer link says 157, and
the role list names a different title depending on which block you
read. This chapter works the page the way the whole arc does: every
number names the surface it rode in on, the page's own header is the
company number, and the two coding prompts and two design
walkthroughs are authored from the 20 visible card titles on
page 1 of the question list, never from the premium-gated bodies.

== the loop map [DRILL]

The company number first. The header counter block reads 862
questions, updated 10.09.2026, one company. The intro paragraph adds
105 questions in the last 90 days and 6 tagged as AI-assisted rounds.
The companies index rollup of 555, recorded in the facts
transcription, is the stale surface, and the page's own 862 wins,
the rule every chapter in this arc follows.

The round distribution rides two surfaces that agree, the intro
paragraph and the FAQ block: 369 questions from technical screens,
261 from onsite rounds, 67 from online assessments, and 12 from
recruiter screens. The technical screen is the largest single bucket,
and the online assessment share is large enough that the FAQ treats
it as its own stage: the experiences it cites describe an OA first
then a virtual onsite of four rounds, and one two-part OA that
included a system design problem.

The experience count is where one page disagrees with itself. The
intro paragraph says 71 first-hand interview experiences are on the
site, the footer link says all 157, and the chapter cites both
surfaces rather than picking one. The question list itself runs 44
pages at about 20 cards a page, and only page 1 is public here. Its
8 visible experience entries sketch the loop shape: three rounds of
graphs, system design and leadership principles, phone screens
including an L6 screen and an SDE II screen, online assessments
paired with AI tasks, and a frontend SDE I loop that was one DSA
round, two mediums, rejected.

== the bank [DRILL]

Roles, three surfaces. The intro paragraph and the FAQ block agree
exactly, the explore-more block runs larger and swaps one title:

#table(
  columns: (auto, auto, auto),
  inset: 4.5pt,
  align: (left, right, right),
  table.header[*role*][*intro and FAQ*][*explore-more block*],
  [Software Engineer], [380], [507],
  [Data Scientist], [203], [205],
  [Machine Learning Engineer], [75], [absent],
  [Applied Scientist], [absent], [80],
  [Product Manager], [29], [27],
  [Business Intelligence Engineer], [15], [19],
)

The FAQ adds a few Data Engineer entries with no count. The
role-name mismatch is the page's own: intro and FAQ say Machine
Learning Engineer 75 while the explore-more block lists Applied
Scientist 80 in its place, so any role claim in an answer should
name its surface.

Categories, same three surfaces plus a fourth column the FAQ adds:

#table(
  columns: (auto, auto, auto, auto),
  inset: 4.5pt,
  align: (left, right, right, right),
  table.header[*category*][*intro*][*FAQ*][*explore-more*],
  [Coding & Algorithms], [243], [243], [292],
  [Behavioral & Leadership], [156], [156], [214],
  [Machine Learning], [78], [78], [84],
  [Data Manipulation (SQL/Python)], [67], [67], [68],
  [System Design], [58], [58], [66],
  [Analytics & Experimentation], [absent], [31], [35],
  [Software Engineering Fundamentals], [absent], [absent], [49],
  [ML System Design], [absent], [absent], [21],
)

Difficulty runs 501 medium, 150 hard, 59 easy on both the intro and
the FAQ. The FAQ's characterization is worth carrying into an answer:
the hard band concentrates in the algorithmic and design material,
its own examples being returning the maximum of every sliding window
and designing a recursive file-search API, while the easy end is
short pattern work such as validating properly nested brackets and
finding the earliest pair with a target sum, which tends to appear
in technical screens.

== quirks of this loop [DRILL]

Behavioral is the identity of this loop. Behavioral & Leadership is
the second-largest category at 156 on the intro and the FAQ, the FAQ
says the behavioral share is enough that it cannot be an
afterthought, and one Product Manager experience on the site reports
five rounds that were all behavioral. The intro names the story
shapes the prompts build: delivering under a tight deadline without
hiding risk, making progress when requirements are ambiguous,
finding and fixing a root cause, turning critical feedback into a
measurable improvement. That is the Leadership Principles story
machine, and the register and rehearsal method for it live in
#xref-to("repertoire", "behavioral-answers").

The AI-assisted OA is its own recorded shape. Six round tags exist
on the intro, and the most-solved card visible on page 1 is one of
them: Debug Watch List Movie Operations, Medium, tagged for the
Software Engineer AI role, 1173 likes and 12322 solved, dated Jun 12
2026. The experience entries describe the pairing: an OA with a
window-sort coding question plus an AI debug task, another with a
merge-strings conflict problem plus an AI Spring Boot bug-fix task,
and the FAQ's two-part OA that included a system design problem. The
debugging discipline these tasks ride is
#xref-to("repertoire", "observed-answers"), and the behavioral side
has its own card in the same family, GenAI Literacy Questions on
daily AI use, handling bad AI output, and RAG projects, 2 likes and
38 solved.

The screens that stick are on the visible experience list. The L6
phone screen entry reports an impatient interviewer and an LCA
follow-up the candidate got stuck on, the same shape as the lowest
common manager card worked below. The SDE II entry reports a maze
problem with no backtracking and restricted turns. The frontend SDE
I entry is the shortest loop on the page. All of these are page-1
titles and tags, the gated bodies were never opened.

== recurring prompts [DRILL]

The visible cards map onto chapters this book already owns. The
table names each card's page tags and difficulty, then the floor:

#table(
  columns: (1.6fr, 1.1fr, auto, 1.4fr),
  inset: 4.5pt,
  align: (left, left, center, left),
  table.header[*visible card*][*page tags*][*difficulty*][*floors in*],
  [Lowest Common Manager of a Group of Employees in an Org Chart], [Trees], [Medium], [#xref-to("repertoire", "datastructures"), worked below],
  [Answer a large batch of variable-ratio queries from division equations], [Graphs], [Medium], [#xref-to("repertoire", "graphs")],
  [Which Recipes Can Be Made When Ingredients Can Themselves Be Recipes], [Graphs], [Medium], [#xref-to("repertoire", "graphs"), the topological sort sections],
  [Grid Reachability for a Robot That Cannot Reverse and Has Restricted Turns], [Grids & Matrices, Graphs], [Medium], [#xref-to("repertoire", "graphs")],
  [Lexicographically Largest Permutation After Sorting One Fixed-Length Window], [Greedy, Two Pointers & Sliding Window], [Medium], [#xref-to("repertoire", "algopatterns")],
  [Maximize the Bitwise AND of K Elements After Spending an Increment Budget], [Bit Manipulation, Greedy], [Hard], [#xref-to("repertoire", "algopatterns"), the bits sections],
  [Minimum Adjacent Swaps to Group a Binary Array], [Coding & Algorithms], [Medium], [#xref-to("repertoire", "algopatterns"), the two-pointer swaps],
  [Minimize Grid Inconvenience by Adding One Delivery Center], [Grids & Matrices, Binary Search], [Medium], [#xref-to("repertoire", "algopatterns"), the search sections],
  [Minimum Priority Conflicts When Interleaving Two Lowercase Strings], [Dynamic Programming], [Hard], [#xref-to("repertoire", "classics2")],
  [Design an Object-Oriented Shopping Cart], [Software Engineering Fundamentals], [Medium], [#xref-to("repertoire", "paradigms"), walked below],
  [Design a Kafka-Based File Watcher for Millions of Files], [System Design, Messaging & Event-Driven], [Medium], [#xref-to("infrastructure", "jetstream") and #xref-to("patterns", "messaging"), walked below],
)

Two more design surfaces live in prose rather than cards: the FAQ
names the recursive file-search API in its hard band and the intro
names a reliable AI chatbot architecture, both flooring on
#xref-to("repertoire", "design-answers") and the four worked
protocols of #xref-to("repertoire", "design-prompts").

== worked coding prompt: the lowest common manager [TDD]

The card: Lowest Common Manager of a Group of Employees in an Org
Chart, tagged Coding & Algorithms with Trees, Medium, Software
Engineer Senior+, 46 likes and 364 solved, dated Oct 2 2026. The
body is public on the page but truncated, so the worked prompt here
is authored from the title alone: an org chart tree, a group of
employees, return the lowest single manager above them all. The
reading this chapter commits to is ancestor-or-self: the deepest
node that is an ancestor of every member or a member itself, so a
group whose senior member manages the rest reports that member. The
fold law makes any group pairwise: the common manager of a, b, c is
the common manager of the common manager of a and b, with c.

One query wants a parent walk, one hop at a time up the chain, O of
depth per answer. The L6 screen entry's stuck follow-up is exactly
the pressure that kills the parent walk, so the workspace builds for
many queries: binary lifting, one O(n log n) build, then O(log n)
per query, read-only after the build and therefore safe under
concurrent queries, which the race test drives. The build is one
breadth-first pass from the ceo for depth, with the reachability
check doubling as the cycle guard, then a doubling table where level
k means two to the k hops:

#listing("interview-repertoire/samples/ch47-go/orgchart.go", first: 46, last: 76, caption: [one breadth-first pass for depth and the unreachable-chain guard, then the doubling table, level k built from level k minus one])

Every build and query failure has its own name: a manager chain
that never reaches the ceo is a cycle, an employee reporting to a
name outside the chart is unknown, the ceo cannot report to anyone,
an empty group is refused, and so is any unknown name mid-fold. The
group answer and the pairwise query it folds over:

#listing("interview-repertoire/samples/ch47-go/orgchart.go", first: 91, last: 125, caption: [the group answer folds pairwise, the query lifts by the set bits of the depth gap, then both descend until their parents agree])

The suite, 7 test functions here of 13 in the workspace: hand-stated
pair and group expectations on a 7-node fixture, all 49 ordered
pairs against a parent-walk reference stated inside the test, a
4096-node chain where the answer is the shallowest member of the
query, the build and query error paths, and the concurrent leg, 8
goroutines through 200 rounds of pairwise and three-member queries
under `go test -race`, green with `go vet` beside it.

== worked coding prompt: the frequency stack [TDD]

The card: Stack Whose Pop Removes the Most Frequent Value, Ties
Broken by Recency, tagged Coding & Algorithms with Data Structure
Design and Stacks & Queues, Medium, Software Engineer, 15 likes and
169 solved, dated Oct 2 2026. Authored from the title: push and pop,
pop removes and returns the most frequent value, and when several
values tie on frequency the one pushed most recently among them goes
first.

The tie is the whole problem. A heap keyed by frequency alone loses
recency, keying by frequency and sequence number works but pays a
log factor and a counter. The board answer is one stack per
frequency: a value's k-th push lands on group k, so the top of the
highest nonempty group is by construction both the most frequent
value and the most recent push at that frequency, and push and pop
are both constant time:

#listing("interview-repertoire/samples/ch47-go/freqstack.go", first: 13, last: 40, caption: [push lands on the group of its new count, pop takes the top of the highest nonempty group and steps the max down when it empties])

The invariant the suite pins: group f is nonempty exactly while some
value sits at count f or above, so stepping the max down after an
emptied group always lands on a nonempty one. The zero value of the
stack is ready to use, the map initializes on first push. The 6
functions here include the full drain of six pushes in the order
5, 7, 5, 4, 7, 5 hand-derived before any code ran, the pure recency
tie 1, 3, 2, 1, interleaved push-pop legs, a frequency re-climb
after the max decayed, the old-occurrence case where a value's
earlier copy must resurface from the low group in the order
5, 3, 5, 4, 3, 2, 1, and the empty-pop errors.

== design walkthrough: a kafka file watcher for millions of files [DRILL]

The card: Design a Kafka-Based File Watcher for Millions of Files,
tagged System Design with Messaging & Event-Driven and Data
Ingestion & CDC, Medium, 19 likes and 137 solved. The floors are
real systems this corpus runs, the kafka comparison belongs to
#xref-to("infrastructure", "jetstream") and the delivery semantics
to #xref-to("patterns", "messaging"). Requirements, functional:
detect create, modify, delete, and rename across a large tree,
deliver each as an event to independent consumers, survive watcher
restarts, and never claim an event that was missed. Non-functional,
assumed and stated: 10 million files, 1000 change events a second
steady, 5000 at peak, 200 bytes an event, 7 days of replay
retention.

The arithmetic first, the method of
#xref-to("repertoire", "estimation-answers"), and it settles the
shape before any box is drawn. 5000 events a second at 200 bytes is
1 megabyte a second of ingress. A day at the steady 1000 is 86
gigabytes, the 7-day retention window about 600 gigabytes, one
broker's disk and a fraction of its throughput, so the broker is
never the constraint and saying so aloud is the opening move. The
hard parts are the edges: watch apis cap handles per process, so the
tree is sharded across a watcher fleet, and a 10 million file tree
at 50000 stat operations a second per scanner is 200 seconds of
walking per scanner, a cadence decision rather than a crisis.
Partitioning follows the same arithmetic: key by file path and
per-file ordering is preserved inside a partition, 16 partitions
carry vastly more than 1 megabyte a second, so the partition count
is a consumer-parallelism decision, with per-file ordering as the
declared contract.

#flow(
  [the file watcher: a sharded watcher fleet, a path-keyed topic, the scan as the source of truth],
  node((0, 0), [filesystem, #linebreak() 10 million files]),
  node((0, 1.2), [watcher fleet, #linebreak() sharded by directory]),
  node((0, 2.4), [kafka topic, #linebreak() path-keyed, 16 partitions]),
  node((0, 3.6), [indexer consumers, #linebreak() idempotent by path, mtime, size]),
  node((0, 4.8), [metadata store, #linebreak() the live index]),
  node((2.2, 4.8), [downstream, #linebreak() audit, search, pipelines]),
  node((2.2, 1.2), [reconciliation scanner, #linebreak() full walk on a cadence]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
  edge((0, 4.8), (2.2, 4.8), "->"),
  edge((2.2, 1.2), (0, 2.4), "->", label: [synthetic events]),
  edge((0, 0), (2.2, 1.2), "-|>", label: [walks]),
)

The walk over hops. Watcher agents each own a directory shard and
emit change events to the topic keyed by path. Consumers build the
metadata index, at-least-once by contract, idempotent on a content
hash of path, mtime, and size, the duplicate-suppression side of
#xref-to("patterns", "messaging"). Renames arrive as a create and a
delete on two different path keys, and the consumer reassembles them
from the metadata rather than asking the log for what it cannot
promise. The reconciliation scanner walks the whole tree on a
cadence and emits synthetic events for anything the watchers missed,
deletes included, because delete detection is where the watch apis
are weakest.

The bottleneck, volunteered: the edge, never the log. The fleet's
handle budget and the scanner's walk are the two scaling surfaces,
and both are sharded by the same directory prefix. The traps, one
line each. Per-file ordering needs the path key, per-directory
ordering is weaker and usually enough, state which one you claim.
At-least-once means duplicates reach every consumer, dedupe belongs
to the consumer, and the exactly-once discussion is owned by
#xref-to("patterns", "messaging"). A lagging consumer can fall past
the 7-day retention window, monitor lag against the retention, and
replay comes from the scanner, not from the log, past that line.
Deletes are the weakest native signal, so the scan is the source of
truth and the watchers are a latency optimization on top of it.

== design walkthrough: an object-oriented shopping cart [DRILL]

The card: Design an Object-Oriented Shopping Cart, tagged Software
Engineering Fundamentals, Medium, Software Engineer New Grad, locked
for premium, 50 likes and 788 solved, so this walkthrough is
authored from the title alone. The object model floors on
#xref-to("repertoire", "paradigms"). Requirements: add items with
quantity and variant, change quantities, remove lines, price the
whole cart under stacked rules, and keep a session stable while the
catalog moves underneath it. One number anyway, the
#xref-to("repertoire", "estimation-answers") discipline: 10 million
users with 5 percent holding a live cart, 50 lines each at 100
bytes, is 250 megabytes of hot session state, any key-value store
carries it, so the design work is entirely in the class boundaries
and the round knows it.

#flow(
  [the cart: snapshots at add time, rules in a declared pipeline, cents everywhere],
  node((0, 0), [client, #linebreak() add, update, remove]),
  node((0, 1.2), [cart service, #linebreak() optimistic version]),
  node((0, 2.4), [cart, #linebreak() lines merged by product]),
  node((2.2, 2.4), [product snapshot, #linebreak() price and title at add]),
  node((2.2, 3.6), [catalog, #linebreak() changes never touch live lines]),
  node((0, 3.6), [pricing pipeline, #linebreak() ordered rules, cents]),
  node((0, 4.8), [total, #linebreak() cached until dirty]),
  edge((0, 0), (0, 1.2), "->"),
  edge((0, 1.2), (0, 2.4), "->"),
  edge((2.2, 2.4), (0, 2.4), "->"),
  edge((2.2, 3.6), (2.2, 2.4), "->"),
  edge((0, 2.4), (0, 3.6), "->"),
  edge((0, 3.6), (0, 4.8), "->"),
)

The walk. The cart owns line items and nothing else. A line holds a
product snapshot, price and title copied at add time, because a
cart that reprices itself overnight when the catalog changes is the
defect this prompt exists to catch. Money is integer cents, the
money-is-cents law of #xref-to("repertoire", "db-answers"). Pricing
rules are a pipeline behind one interface, each rule reads the
running total and returns a delta, percent-off and fixed-fee rules
compose in a declared order, and stacking order is a product
decision the diagram must show: 10 percent off then 5 off the
result is not 15 percent off. Adding the same product twice merges
into one line with a summed quantity, the identity rule stated
aloud. Variants are composition, a variant holds its own sku and
price delta against the base product, and inheritance loses
everywhere in this model, the same floor
#xref-to("repertoire", "paradigms") lays down.

The cost to volunteer: the pricing pass is lines times rules on
every read, so cache the computed total on the cart and invalidate
on mutation with one dirty bit, the recomputation becomes
write-proportional. The traps, one line each. Live product
references in lines, snapshots instead. Float money, cents instead.
Discount stacking order left implicit, declare the pipeline order.
Two tabs on one cart, optimistic versioning or last write wins, and
say which one and when.

sources: every count in this chapter traces to the pinned bytes at
`ref/prachub/amazon/page.md`, fetched 2026-10-15 from
https://prachub.com/companies/amazon/ with its sha256 in the front
matter, through the transcription at `ref/prachub/amazon/facts.md`,
and each count names its surface, header counter, intro paragraph,
FAQ block, explore-more block, footer link, pagination, or the
visible card table, because the surfaces disagree on this page: 71
experiences in the intro against 157 in the footer, Machine
Learning Engineer 75 against Applied Scientist 80, and the
companies-index rollup of 555 recorded in the facts transcription
against the page's own 862. Only page 1 of the 44-page list is
public, its 20 visible card titles are the sole raw material for
the worked prompts and walkthroughs here, the premium-gated bodies
were never opened, and list pages 2 to 44 were not fetched. The
design-walkthrough arithmetic follows the chapter 36 method with
its assumptions stated inline, and that arithmetic is this
chapter's own, the company counts are not.
