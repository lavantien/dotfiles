#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= distributed fundamentals

A distributed system is one where a machine you do not control can
slow you down, reorder you, or vanish, and where the speed of light
is a latency floor you bill for. Everything in the second half of
this book, consensus, partitioning, messaging, observability,
resilience, is engineering around those three facts. This chapter
fixes the vocabulary and builds the two algorithmic primitives every
later chapter leans on: logical clocks and quorum arithmetic. The
three samples, lamport, vector, and quorum, are pure functions in
all six trees, no concurrency at all, and the shared fixtures land
as the same literals in every lane.

== the fallacies, as constraints

The old list of eight fallacies of distributed computing, the
network is reliable, latency is zero, bandwidth is infinite, the
network is secure, topology does not change, there is one
administrator, transport cost is zero, the network is homogeneous,
reads as a checklist of assumptions production systems violate
weekly. Each tree's native error surface encodes the answers: go's
`error` values and c's status codes carry network failure back to
the caller without crashing anyone, c\# and python raise,
javascript rejects a promise, lua returns nil plus a message,
latency gets its deadline through the context objects of chapter 8,
and transient loss meets the jittered retries of chapter 15. The
list is not trivia, it is a requirements document.

#diagram([the eight fallacies mapped to the answers the book builds on], length: 13pt, {
  cdraw.content((4.4, 7.15), [the fallacy], size: 6.5pt)
  cdraw.content((16.1, 7.15), [the answer], size: 6.5pt)
  let cols = ((0.4, 8.4), (8.8, 23.4))
  let rows = (
    ([the network is reliable], [error values, not panics]),
    ([latency is zero], [context deadlines]),
    ([transient loss], [retries with jitter, ch15]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.4 - i * 1.5
    for (j, cell) in row.enumerate() {
      let c = cols.at(j)
      cdraw.rect((c.at(0), y), (c.at(1), y + 1.3), fill: luma(235), radius: 0.02)
      cdraw.content(((c.at(0) + c.at(1)) / 2, y + 0.65), cell, size: 6pt)
    }
  }
  cdraw.content((11.9, 0.9), [six more fallacies, named and budgeted: bandwidth, security, topology,#linebreak()one administrator, transport cost, homogeneity], size: 6pt)
})

The number that disciplines intuition: a round trip within a
datacenter is around 0.5 milliseconds, across a continent around
30, and reading an nvme drive is around 100 microseconds. A
protocol that adds 10 sequential cross-continent round trips costs
300 milliseconds before any work happens, which is why the raft
chapter counts messages and why every resilience pattern in
chapter 15 trades round trips for retries.

== why wall clocks are not clocks

Every machine's `time.Now()` disagrees, ntp keeps the disagreement
bounded but never zero, and the clock can jump backward during
correction. Any ordering or timeout logic built on comparing two
machines' wall clocks inherits all of it. The rule this book
follows: wall clocks are for humans reading logs, monotonic clocks
(`time.Since`, read from the same machine) are for measuring
durations, and logical clocks are for ordering events. Every tree
keeps the same split with its own primitive, `clock_gettime` over a
monotonic clock id in c, `Stopwatch` in c\#, `performance.now` in
javascript, `time.monotonic` in python, and nothing in lua, whose
stdlib offers only wall `os.time` and cpu-time `os.clock`, so the
lua lanes in this book carry time through the scheduler instead.

#diagram([two wall clocks drift, ntp steps one back, no ordering survives], length: 13pt, {
  cdraw.line((1, 0.9), (22, 5.4), stroke: luma(100))
  cdraw.content((2.2, 1.7), [machine a], size: 6pt)
  cdraw.line((1, 1.3), (13, 6.1), stroke: luma(100))
  cdraw.line((13, 4.8), (22, 6.6), stroke: luma(100))
  cdraw.content((4.0, 3.6), [machine b, running fast], size: 6pt)
  cdraw.line((13, 6.1), (13, 4.8), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((9.3, 5.1), [ntp steps b back], size: 6pt)
  cdraw.line((18, 4.55), (18, 5.87), stroke: 1pt)
  cdraw.content((18, 6.6), [same instant, two readings], size: 6pt)
  cdraw.line((1, 0.2), (1, 0.0), stroke: luma(100)); cdraw.line((1, 0.1), (22, 0.1), stroke: luma(100))
  cdraw.content((11.5, -0.4), [real time], size: 6pt)
  let chip = (x0, x1, txt) => {
    cdraw.rect((x0, -2.9), (x1, -1.2), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, -2.05), txt, size: 6pt)
  }
  chip(0.4, 7.4, [wall clock:#linebreak()humans reading logs])
  chip(8.0, 15.9, [monotonic clock:#linebreak()durations, one machine])
  chip(16.5, 23.4, [logical clock:#linebreak()ordering events])
})

== lamport clocks

Lamport's 1978 insight: order does not have to come from time, it
can come from communication. Each process keeps a counter, ticks it
on every event, and folds the maximum on receive:

The dry run: the same walk in all six lanes.

- a leader's 100 local ticks leave its stamp at exactly 100, and a
  lagging clock receiving that stamp lands on 101, max then tick
- along a send and receive chain every later event strictly
  out-stamps the earlier one, the one-way property
- an independent clock can hold a smaller stamp than a message it
  never saw, the false converse, and every lane pins that falsehood
  as expected behavior

#listing("patterns-concurrency-distributed/samples-c/src/Ch10/lamport.c", first: 21, last: 41, caption: [C, the clock is a struct, tick, send, and receive are plain functions over it])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch10/Lamport.cs", first: 3, last: 30, caption: [C\#, the clock is a class, Receive folds the max then ticks])

#listing("patterns-concurrency-distributed/samples/ch10/clocks.go", first: 10, last: 33, caption: [Go, tick, send, receive: the whole scheme in three methods])

#listing("patterns-concurrency-distributed/samples-js/src/ch10-lamport.mjs", first: 7, last: 35, caption: [JavaScript, the counter sits behind a private class field, the same three methods])

#listing("patterns-concurrency-distributed/samples-py/src/Ch10/lamport.py", first: 16, last: 32, caption: [Python, the clock is a small class, count starts at zero])

#listing("patterns-concurrency-distributed/samples-lua/ch10_lamport.lua", first: 7, last: 30, caption: [Lua, the clock is a table dispatched through its metatable])

The counter's carrier is the only thing the six trees disagree on:
go keeps `count uint64` in a struct, c a `uint64_t` beside the
process name, c\# a `ulong` property, javascript a private class
field, python an attribute on `self`, lua a table field reached
through `__index`. Receive is max then increment in every spelling,
and because the scheme is pure arithmetic over one integer, all six
fixtures print the same numbers with no portability seam at all.

#diagram([local events tick, receive takes the max then ticks, order is one way], length: 13pt, {
  cdraw.content((0, 4.1), [process 1], size: 6.5pt)
  cdraw.content((0, -0.1), [process 2], size: 6.5pt)
  cdraw.line((0, 3.4), (24, 3.4), stroke: 1pt)
  cdraw.line((0, 0.6), (24, 0.6), stroke: 1pt)
  cdraw.content((12, -0.9), [time], size: 6pt)
  cdraw.line((23.4, 0.35), (24, 0.6)); cdraw.line((23.4, 0.85), (24, 0.6))

  cdraw.circle((3, 3.4), radius: 0.12, fill: luma(30))
  cdraw.content((3, 3.85), [1], size: 6.5pt)
  cdraw.circle((8, 3.4), radius: 0.12, fill: luma(30))
  cdraw.content((8, 3.85), [2], size: 6.5pt)
  cdraw.circle((13, 3.4), radius: 0.12, fill: luma(30))
  cdraw.content((12.2, 3.85), [3, send], size: 6.5pt)

  cdraw.circle((3, 0.6), radius: 0.12, fill: luma(30))
  cdraw.content((3, 0.05), [1], size: 6.5pt)
  cdraw.circle((16, 0.6), radius: 0.12, fill: luma(30))
  cdraw.content((15.2, 0.05), [4, receive], size: 6.5pt)
  cdraw.circle((21, 0.6), radius: 0.12, fill: luma(30))
  cdraw.content((21, 0.05), [5], size: 6.5pt)

  cdraw.line((13, 3.25), (16, 0.78), stroke: 1pt)
  cdraw.content((10.8, 2.3), [message, stamp 3], size: 6.5pt)
  cdraw.content((19.0, 1.7), [receive: max, then tick], size: 6.5pt)
  cdraw.content((12, 4.85), [the causal chain: 1 < 2 < 3 < 4 < 5, stamps preserved], size: 6.5pt)
  cdraw.content((12, 6.0), [p2 tick (1) < p1 send (3) yet unrelated: the converse is false], size: 6.5pt)
})

The guarantee is one direction only: if a happens-before b, then
`stamp(a) < stamp(b)`. The converse is false, and the test pins that
honestly, an independent process with a smaller stamp is not
"earlier" in any causal sense, it is simply unrelated. Lamport
clocks buy total order cheaply (ties broken by process id) at the
price of ordering things that have no relationship, which is
acceptable for choosing a lock acquisition order and unacceptable
for deciding which write wins.

== vector clocks

To recover the true causal relation, each process records the latest
stamp it has seen from every process:

The dry run: the fork-merge fixture, identical in all six lanes.

- 2 independent first ticks stamp {a:1} and {b:1} and compare
  concurrent
- after a ticks again to {a:2} and b merges it, b holds {a:2,b:2}:
  before one way and after the other
- b's pre-merge fork stamp stays concurrent with a's later {a:3}
- a clone of a stamp compares equal to the stamp it came from

#listing("patterns-concurrency-distributed/samples-c/src/Ch10/vector.c", first: 41, last: 87, caption: [C, merge folds elementwise max then ticks, compare walks the slots of a fixed two-process stamp])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch10/Vector.cs", first: 45, last: 94, caption: [C\#, the four-way compare over the sorted union of process names, missing slots read zero])

#listing("patterns-concurrency-distributed/samples/ch10/clocks.go", first: 36, last: 66, caption: [Go, stamp per process, elementwise merge, tick on the receive itself])

#listing("patterns-concurrency-distributed/samples/ch10/clocks.go", first: 69, last: 112, caption: [Go, comparison: all-less is before, all-greater is after, mixed is concurrent])

#listing("patterns-concurrency-distributed/samples-js/src/ch10-vector.mjs", first: 7, last: 49, caption: [JavaScript, the stamp is a Map, compare returns the relation as a string])

#listing("patterns-concurrency-distributed/samples-py/src/Ch10/vector.py", first: 21, last: 57, caption: [Python, the stamp is a dict, compare walks the sorted union with zero defaults])

#listing("patterns-concurrency-distributed/samples-lua/ch10_vector.lua", first: 9, last: 60, caption: [Lua, the stamp is a plain table, compare names the relation it returns])

The carrier widens from one integer to a map of them and the trees
split by grain: go a `map[string]uint64`, c\# a
`Dictionary<string, ulong>`, javascript a `Map`, python a `dict`,
lua a plain table, and c a fixed two-slot array, honest about a
fixture that only ever forks two processes. Compare walks the union
of process names in all six, sorted first in go, c\#, python, and
lua, javascript settling for Set order over its Map keys, and c
scanning its two slots, a missing name reading zero through
`TryGetValue`, `?? 0`, `.get(name, 0)`, `or 0`, and c's zeroed
array. The relation itself is an enum in go, c, and c\# and a
returned name in javascript, python, and lua, the same four outcomes
either way.

Comparison over the union of process ids yields exactly four
outcomes, and `Concurrent` is the outcome this section exists for,
the formal statement "these two events have no causal order, any
ordering between them is a choice we make". The test builds the fork
and merge scenario: two independent ticks compare `Concurrent`, after
a message flows one direction the relation flips to `Before`/`After`,
and the pre-merge fork stamp stays concurrent with later independent
work. Vector clocks cost o(n) per message against lamport's o(1),
the standard trade of size for truth, and production systems
compress them into version vectors and dotted version vectors
instead of abandoning them.

#diagram([the test's fork and merge scenario, stamps are vectors], length: 13pt, {
  cdraw.content((0, 4.1), [process 1], size: 6.5pt)
  cdraw.content((0, -0.1), [process 2], size: 6.5pt)
  cdraw.line((0, 3.4), (24, 3.4), stroke: 1pt)
  cdraw.line((0, 0.6), (24, 0.6), stroke: 1pt)
  cdraw.content((12, -0.9), [time], size: 6pt)
  cdraw.line((23.4, 0.35), (24, 0.6)); cdraw.line((23.4, 0.85), (24, 0.6))

  cdraw.circle((3, 3.4), radius: 0.12, fill: luma(30))
  cdraw.content((3, 3.85), [(1,0)], size: 6.5pt)
  cdraw.circle((8, 3.4), radius: 0.12, fill: luma(30))
  cdraw.content((7.0, 3.85), [(2,0), send], size: 6.5pt)
  cdraw.circle((16, 3.4), radius: 0.12, fill: luma(30))
  cdraw.content((16, 3.85), [(3,0)], size: 6.5pt)

  cdraw.circle((3, 0.6), radius: 0.12, fill: luma(30))
  cdraw.content((3, 0.05), [(0,1)], size: 6.5pt)
  cdraw.circle((10, 0.6), radius: 0.12, fill: luma(30))
  cdraw.content((9.6, 0.05), [(2,2), receive], size: 6.5pt)
  cdraw.circle((16, 0.6), radius: 0.12, fill: luma(30))
  cdraw.content((16, 0.05), [(2,3)], size: 6.5pt)

  cdraw.line((8, 3.25), (10, 0.78), stroke: 1pt)
  cdraw.content((12.6, 2.3), [message], size: 6.5pt)
  cdraw.content((12, 5.0), [(3,0) and (2,3) compare mixed: concurrent, no causal order], size: 6.5pt)
})

#callout("note", "concurrent is not simultaneous", [
  `Concurrent` in the vector clock sense means causally unrelated,
  regardless of which event physically happened first in wall time.
  Two clients writing the same key from opposite coasts are
  concurrent to each other even when one clearly typed faster, and
  a conflict resolution rule, last-writer-wins by wall clock,
  application merge, or a human, is then mandatory, not optional.
])

== quorums

Consensus in the next chapter reduces to arithmetic: a quorum is the
smallest majority, and any two quorums of the same cluster
intersect:

The dry run: quorum over cluster sizes 1 through 7 reads 1, 2, 2, 3,
3, 4, 4 in every lane.

- majority(2, 3) carries, majority(1, 3) does not, majority(3, 3)
  carries, all six, and the c and python lanes add the even
  cluster, where half is never enough
- quorum(n) + quorum(n) > n, the overlap the raft chapters stand
  on, swept for n up to 20 by the lua lane and checked at 5 and 7
  by python

#listing("patterns-concurrency-distributed/samples-c/src/Ch10/quorum.c", first: 18, last: 22, caption: [C, two functions, the whole arithmetic])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch10/Quorum.cs", first: 3, last: 10, caption: [C\#, Of and Majority as static one-liners])

#listing("patterns-concurrency-distributed/samples/ch10/clocks.go", first: 115, last: 118, caption: [Go, quorum and majority])

#listing("patterns-concurrency-distributed/samples-js/src/ch10-quorum.mjs", first: 1, last: 12, caption: [JavaScript, Math.floor spells the same formula over real division])

#listing("patterns-concurrency-distributed/samples-py/src/Ch10/quorum.py", first: 15, last: 20, caption: [Python, the same two functions in the script style])

#listing("patterns-concurrency-distributed/samples-lua/ch10_quorum.lua", first: 6, last: 14, caption: [Lua, floor division, same formula])

The formula survives translation because every language here floors
its integer division: `n / 2 + 1` verbatim in c, go, and c\#, `n
// 2 + 1` in python and lua, and `Math.floor(n / 2) + 1` in
javascript, where `/` alone is real division and would hand back
2.5 seats for a five-node cluster. The majority predicate is one
comparison everywhere. The number itself does the work in the next
chapter, where elections and log commitment both reduce to reaching
it.

#diagram([any two majorities of five share a node, reads meet writes], length: 13pt, {
  let xs = (2, 6, 10, 14, 18)
  for i in range(5) {
    let f = if i == 2 { luma(205) } else { luma(235) }
    cdraw.circle((xs.at(i), 3.0), radius: 0.55, fill: f, stroke: luma(100))
    cdraw.content((xs.at(i), 3.0), [n#(i + 1)], size: 6pt)
  }
  cdraw.circle((10, 3.0), radius: 0.8, stroke: 1pt)
  cdraw.rect((0.7, 1.8), (11.7, 4.2), radius: 0.1, stroke: luma(100))
  cdraw.rect((8.3, 1.8), (19.3, 4.2), radius: 0.1, stroke: luma(100))
  cdraw.content((6.2, 4.75), [write quorum, any 3 of 5], size: 6pt)
  cdraw.content((14.4, 4.75), [read quorum, another 3], size: 6pt)
  cdraw.content((10, 1.2), [the shared node carries the write to the read], size: 6pt)
  cdraw.content((10, 0.2), [quorum(n) = n / 2 + 1, so 3 of 5 and 4 of 7], size: 6pt)
})

The intersection property is what makes replication safe: if a write
must reach a quorum and a read must consult a quorum, any read
overlaps any write, so a quorum system cannot silently split into
two worlds that each believe they are the whole world. Raft's
elections and its log commitment are both this one property
applied, and the capstone leans on it five times over.

== cap, as an engineering decision

The CAP theorem states a distributed system facing a partition must
choose between consistency and availability for the partitioned
minority. The practical reading is narrower than the slogan:
partitions are not optional, they are the network's resting state
at scale, so the choice is per operation, CP operations reject
minority requests to keep one truth, AP operations serve stale
answers to stay up. Raft, and this book's capstone, sits on the CP
side: a minority partition stops accepting writes, and chapter 16's
tests exercise exactly that stoppage.

#flow(
  [cap as a per-operation decision, raft sits on the cp side],
  node((0, 0), [request reaches#linebreak()the minority]),
  node((3.0, 1.2), [cp: reject,#linebreak()keep one truth]),
  node((3.0, -1.2), [ap: serve stale,#linebreak()stay up]),
  node((6.0, 1.2), [raft, and this capstone]),
  edge((0, 0), (3.0, 1.2), "-|>"),
  edge((0, 0), (3.0, -1.2), "-|>"),
  edge((3.0, 1.2), (6.0, 1.2), "-|>"),
)

== across the six languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [178], [libc],
  [uint64_t clock, two-slot fixed vector stamps, an enum relation, n / 2 + 1],
  [c\#], [102], [bcl],
  [ulong clock, Dictionary stamps, TryGetValue zeros, static quorum one-liners],
  [go], [86], [stdlib],
  [frozen reference lane, map[string]uint64 stamps over the sorted union],
  [javascript], [64], [node stdlib],
  [private-field clock, Map stamps in Set order, Math.floor over real division],
  [python], [143], [stdlib only],
  [dict stamps with .get zeros, script style, the even-cluster probe added],
  [lua], [180], [lib.lua harness],
  [plain-table stamps with or-zero, floor division, the overlap swept to n of 20],
)

sources: L. Lamport, "Time, Clocks, and the Ordering of Events in
a Distributed System", CACM 1978, for the logical clock
construction and its one-directional guarantee, the fallacies
list as compiled by Deutsch and others at Sun, Peter Norvig's
latency numbers and the Berkeley interactive latency guide for the
orders of magnitude, Gilbert and Lynch, "Brewer's Conjecture and
the Feasibility of Consistent, Available, Partition-Tolerant Web
Services", 2002, for CAP, accessed 2026-09-08. Verified by the six
chapter legs: 3 C programs with 40 embedded checks, 10 xunit
facts, `go test` at 5 tests in `patternsbook/ch10`, node's 4
cases across 3 suites in `test/ch10.test.mjs`, the python runner's
33 checks across 3 modules, and the lua runner's 11 ch10 rows.
