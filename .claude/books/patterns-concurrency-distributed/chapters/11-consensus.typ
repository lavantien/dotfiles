#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= replication and consensus: raft

Replication is copying state so failures cost capacity instead of
data. Consensus is getting a cluster to agree on the order of events
so the copies cannot disagree, and raft, from Ongaro and
Ousterhout's 2014 paper "In Search of an Understandable Consensus
Algorithm", is the design this book builds its capstone on. This
chapter is the theory, distilled to the parts the capstone
implements, each rule extracted as a pure function with a test
before chapter 16 wires them into nodes. Four samples carry it in
all seven trees, append, vote, commit, and timeout, pure functions
everywhere, and every fixture below is a shared literal except
where its dry run names the split.

== the state machine approach

Every server runs the same deterministic state machine against the
same input log. If server A applied "set a=1" as entry 1 and "set
b=2" as entry 2, and server B applied anything else in those slots,
the cluster has forked without crashing. Consensus is the agreement
on log contents, not on values, and the safety property falls out:
once a command is applied at index n by any server, no server ever
applies a different command at index n.

#flow(
  [the replicated state machine],
  node((0, 0), [client command]),
  node((1.9, 0), [raft log, agreed order]),
  node((3.9, 0), [state machine]),
  node((3.9, -1.1), [replica 1]),
  node((3.9, 1.1), [replica 2]),
  node((1.9, 1.1), [same log, replicated]),
  edge((0, 0), (1.9, 0), "-|>"),
  edge((1.9, 0), (3.9, 0), "-|>"),
  edge((1.9, 0), (1.9, 1.1), "-|>"),
  edge((1.9, 1.1), (3.9, 1.1), "-|>"),
  edge((3.9, 0), (3.9, -1.1), "-|>"),
)

== terms and leader election

Raft divides time into terms, monotonically numbered logical
epochs, each with at most one leader. A follower that hears nothing
from a leader before its election timeout fires becomes a
candidate, increments the term, votes for itself, and asks the rest
for votes. A majority of votes makes it leader, and the very first
act of leadership is a heartbeat `AppendEntries` that resets every
other timeout, suppressing further elections.

Two rules carry the weight. Each server votes at most once per
term, recorded in the persistent `votedFor`, so two candidates
cannot both scrape a majority out of the same term. And the
timeouts are randomized, in the paper's example 150 to 300
milliseconds, so split votes, everyone a candidate at once and
nobody a majority, resolve on the next round because someone's
timer fires first. Randomized restart doing the scheduling a
smarter protocol would need is the same move the metaheuristics
chapter explores, #xref-to("dsa", "metaheuristics"), and the seeded
generator that chapter pinned for the whole corpus is the one the
six new lanes draw from here.

The dry run: the timeout draw is the one place this chapter splits
its contract, and the split is the lesson.

- the frozen go lane draws from `rand/v2`'s pcg and asserts
  properties: 5 nodes land inside [150, 300), the same node
  redraws its own value, and at least 2 distinct values appear
- the six new lanes draw from the corpus lcg, seed node+1, output
  the high 32 bits, and pin the exact vectors: nodes 0 through 4
  draw 213, 265, 166, 218, 270, so node 2 fires first at 166
- the six new trees assert the lcg warm-up vectors first, seed 1
  drawing 1817669548 then 2187888307, before anything depends on
  the stream

#listing("patterns-concurrency-distributed/samples-c/src/Ch11/timeout.c", first: 21, last: 41, caption: [C, uint64 state wrapping mod 2^64, the draw is the high 32 bits, below(k) multiplies without modulo bias])

#listing("patterns-concurrency-distributed/samples/ch11/consensus.go", first: 84, last: 87, caption: [Go, seeded draw from the base plus spread interval])

#listing("patterns-concurrency-distributed/samples-java/src/Ch11/Timeout.java", first: 21, last: 44, caption: [Java, long arithmetic wraps mod 2^64 like c's uint64_t, the draw is the unsigned high half, no limb work anywhere])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch11/Timeout.cs", first: 3, last: 16, caption: [C\#, the draw rides a CorpusLcg helper shared across the tree's chapters])

#listing("patterns-concurrency-distributed/samples-js/src/ch11-timeout.mjs", first: 35, last: 70, caption: [JavaScript, the 64-bit state as 32-bit halves multiplied through 16-bit limbs, no decimal literal past 2^53 anywhere])

#listing("patterns-concurrency-distributed/samples-py/src/Ch11/timeout.py", first: 16, last: 34, caption: [Python, a masked int carries the state, the constants verbatim])

#listing("patterns-concurrency-distributed/samples-lua/ch11_timeout.lua", first: 8, last: 32, caption: [Lua, integers wrap mod 2^64 natively, the whole draw stays integral])

The carrier is where the languages disagree, and every disagreement
is a number-theory fact wearing a syntax costume. C, c\#, go, and
lua hold 64-bit unsigned arithmetic natively, `uint64_t`, `ulong`,
`uint64`, and lua's wrapping integers, so the recurrence is one
line. Java's signed `long` wraps through the same mod 2^64
arithmetic, one line again, and only the high-half draw needs the
unsigned shift. Python holds arbitrary precision and masks to 64
bits by hand. Javascript has no exact 64-bit `Number` at all, so
its lane splits the state into high and low 32-bit halves and
multiplies through 16-bit limbs, every partial product staying
inside the exact double range, which is why the constants appear as
hex limb pairs instead of decimals. Seven carriers, one stream, six
identical timeout vectors and one honestly unrepeatable pcg.

#flow(
  [election state machine, one vote per term, randomized timeouts break splits],
  node((0, 0), [follower,#linebreak()timeout fires]),
  node((2.7, 0), [candidate,#linebreak()term++, self-vote]),
  node((5.4, 0), [leader,#linebreak()heartbeats reset all]),
  edge((0, 0), (2.7, 0), "-|>", label: [randomized timeout]),
  edge((2.7, 0), (5.4, 0), "-|>", label: [votes >= quorum]),
  edge((5.4, 0), (0, 0), "-|>", bend: 35deg, label: [higher term seen, step down]),
)

The test pins the properties that matter: 5 nodes draw inside
the interval, the same node draws the same value twice, and at least
2 distinct values appear, randomization actually happening.

== the election restriction

Blind majority voting would let a stale log win an election and
erase committed entries. Section 5.4.1 closes the hole: a voter
grants its vote only if the candidate's log is at least as
up-to-date as its own, where up-to-date is decided by the index and
term of the last entries, larger last term wins outright, equal
terms go to the longer log:

The dry run: the 5.4.1 matrix over the shared fixture log1 =
[(1, "set a=1"), (1, "set b=2"), (2, "set c=3")], last term 2, last
index 3, the same decisions in all seven lanes.

- a candidate ending at term 3 is up-to-date and a candidate ending
  at term 1 is not, at any length the lanes probe, go, java, c\#,
  javascript, and lua probing 1 and 99, python 2 and 9, c adding 0
- equal terms go to the longer log, and the exact tie goes to the
  candidate
- the c, java, python, and lua lanes widen the matrix with the
  empty voter, whose last term reads 0 and who accepts anyone

#listing("patterns-concurrency-distributed/samples-c/src/Ch11/vote.c", first: 30, last: 42, caption: [C, the comparison in one function, term first, length only on ties])

#listing("patterns-concurrency-distributed/samples/ch11/consensus.go", first: 44, last: 57, caption: [Go, the voter side of request vote, both rules in five lines])

#listing("patterns-concurrency-distributed/samples-java/src/Ch11/Vote.java", first: 22, last: 35, caption: [Java, term first, length only on ties, the log a list of records and the empty tail's term guarded to 0])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch11/Vote.cs", first: 3, last: 23, caption: [C\#, the same five decisions, the empty log reading term 0])

#listing("patterns-concurrency-distributed/samples-js/src/ch11-vote.mjs", first: 1, last: 14, caption: [JavaScript, the tail read through a conditional, falseness standing in for 0])

#listing("patterns-concurrency-distributed/samples-py/src/Ch11/vote.py", first: 16, last: 21, caption: [Python, the empty log's last term read through a conditional])

#listing("patterns-concurrency-distributed/samples-lua/ch11_vote.lua", first: 14, last: 27, caption: [Lua, the tail read at the table's end, term compared before length])

Every lane walks the same two comparisons in the same order, and
the only spelling that differs is how an empty log yields its last
term: a guarded read in go, c, java, and lua, `Count > 0` in c\#, a
conditional expression in javascript, and python's negative-index
conditional. The function is small because the rule is small, and
the rule is small because the paper wanted implementers to get it
right the first time.

#diagram([the up-to-date matrix, larger last term first, length only breaks ties], length: 13pt, {
  cdraw.content((4.4, 7.15), [the voter compares], size: 6.5pt)
  cdraw.content((16.1, 7.15), [the vote], size: 6.5pt)
  let cols = ((0.4, 8.4), (8.8, 23.4))
  let rows = (
    ([candidate last term > mine], [grant]),
    ([candidate last term < mine], [deny]),
    ([equal terms, candidate log >= mine], [grant]),
    ([equal terms, candidate log shorter], [deny]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.5 - i * 1.4
    for (j, cell) in row.enumerate() {
      let c = cols.at(j)
      cdraw.rect((c.at(0), y), (c.at(1), y + 1.2), fill: luma(235), radius: 0.02)
      cdraw.content(((c.at(0) + c.at(1)) / 2, y + 0.6), cell, size: 6pt)
    }
  }
  cdraw.content((11.9, 0.1), [a committed entry sits on a quorum, every majority meets that quorum,#linebreak()so any election winner carries every committed entry], size: 6pt)
})

The consequence is the paper's leader completeness property: any
committed entry is present on a quorum, any majority intersects
that quorum, so any election winner carries every committed entry.

== log replication and the consistency check

The leader streams `AppendEntries` carrying the index and term of
the entry immediately preceding the new ones. The follower rejects
the whole request unless its log holds a matching entry at that
position, and on acceptance overwrites conflicts and extends:

The dry run: the log1 fixture walks the four behaviors in every
lane.

- prev(3, 2) extending with (2, "set d=4") accepts, 4 entries
- prev(9, 2) and prev(3, 1) both reject, the log handed back
  unchanged
- prev(2, 1) carrying (3, "set c=9") and (3, "set d=4") truncates
  the conflict, leaving [(1, a), (1, b), (3, c=9), (3, d=4)]
- re-delivering entries already present is a no-op, the second
  append returns a log equal to the first

#listing("patterns-concurrency-distributed/samples-c/src/Ch11/append.c", first: 49, last: 79, caption: [C, a fixed-capacity log by value, the caller's copy untouched on rejection])

#listing("patterns-concurrency-distributed/samples/ch11/consensus.go", first: 15, last: 42, caption: [Go, prev check, conflict truncation, skip-already-present, extend])

#listing("patterns-concurrency-distributed/samples-java/src/Ch11/Append.java", first: 30, last: 57, caption: [Java, append is pure over immutable lists, a new log comes back frozen, rejection hands back the caller's own])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch11/Append.cs", first: 13, last: 47, caption: [C\#, the input list never mutated, RemoveRange truncates, AddRange extends])

#listing("patterns-concurrency-distributed/samples-js/src/ch11-append.mjs", first: 7, last: 30, caption: [JavaScript, slice and spread rebuild the log, the input array shared on rejection])

#listing("patterns-concurrency-distributed/samples-py/src/Ch11/append.py", first: 15, last: 31, caption: [Python, list slicing spells truncate and extend, tuples carrying each entry])

#listing("patterns-concurrency-distributed/samples-lua/ch11_append.lua", first: 23, last: 56, caption: [Lua, the copy made entry by entry, the same four rules in 1-based indices])

Purity is the pattern: go and c\# copy before mutating, java copies
the immutable input and freezes the successor with `List.copyOf`,
javascript and python build the successor out of slices, c copies
the log by value into the out parameter, lua builds a fresh table.
The 1-based languages pay one index shift and say so in a comment,
the rule itself unchanged. Rejection returns the caller's own log,
which is
what lets the leader retry a lower `nextIndex` without corrupting
the follower it is repairing.

#diagram([a diverged follower, the prev anchor, the walk back, and the repair], length: 13pt, {
  let box(x, y, t, dark: false) = {
    cdraw.rect((x, y), (x + 1.6, y + 0.9), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.8, y + 0.45), [#t], size: 6pt)
  }
  // before panel
  cdraw.content((4.4, 8.3), [before], size: 6.5pt)
  cdraw.content((1.3, 7.7), [leader], size: 6pt)
  for i in range(4) { box(0.8 + i * 1.8, 6.7, ("T1", "T1", "T2", "T2").at(i)) }
  cdraw.content((1.3, 4.6), [follower], size: 6pt)
  for i in range(3) { box(0.8 + i * 1.8, 3.6, ("T1", "T1", "T3").at(i), dark: i == 2) }
  cdraw.line((0.9, 6.55), (4.1, 6.55), stroke: 1pt)
  cdraw.content((2.5, 6.15), [prev = (2, T1)], size: 6pt)
  cdraw.line((0.8 + 2 * 1.8 + 0.8, 3.6), (0.8 + 2 * 1.8 + 0.8, 4.5), stroke: luma(100))
  cdraw.line((0.8 + 2 * 1.8 + 0.8, 4.5), (0.8 + 3 * 1.8 + 0.8, 4.5), stroke: luma(100))
  cdraw.content((5.6, 4.85), [conflict at 3], size: 6pt)
  for i in range(4) { cdraw.content((0.8 + i * 1.8 + 0.8, 3.15), [#(i + 1)], size: 6pt) }
  cdraw.content((4.2, 1.9), [rejection walks nextIndex back], size: 6pt)
  // after panel
  cdraw.content((17.0, 8.3), [after], size: 6.5pt)
  cdraw.content((13.9, 7.7), [leader], size: 6pt)
  for i in range(4) { box(13.4 + i * 1.8, 6.7, ("T1", "T1", "T2", "T2").at(i)) }
  cdraw.content((13.9, 4.6), [follower], size: 6pt)
  for i in range(4) { box(13.4 + i * 1.8, 3.6, ("T1", "T1", "T2", "T2").at(i), dark: i >= 2) }
  cdraw.content((17.4, 1.9), [truncated, overwritten, redelivery a no-op], size: 6pt)
})

The `prevIndex, prevTerm` pair is an induction anchor: if my entry
at index n matches yours at index n, and each append proves its own
prefix, the logs agree on everything up to the new entries. A
rejection makes the leader step its `nextIndex` for that follower
back by one and retry, walking back until the prefix matches, which
is how a lagging or diverged follower is repaired. The pure
function's tests cover the four behaviors the capstone's followers
will rely on: extension, rejection without mutation on both
mismatch flavors, truncation on conflict, and the quiet one,
re-delivery of entries already present is a no-op, because rpcs can
retry and an idempotent log operation is what makes at-least-once
delivery safe, chapter 13's whole subject arriving early.

== commitment

An entry is committed once stored on a quorum, but the counting
rule has a famous restriction, section 5.4.2: a leader only commits
entries from its own current term by counting replicas. Entries
from earlier terms commit indirectly, when a current-term entry
above them commits. The paper's figure 8 walk-through shows why:
without the restriction a re-elected leader can commit a
prior-term entry and later see it overwritten. Followers learn the
commit index from the leader's `leaderCommit`, clamped to their own
last index:

The dry run: the commit rules over the same fixture.

- AdvanceCommit(2, 5, 3) = 3 and (1, 9, 3) = 3, the clamp, and
  (5, 2, 3) = 5, no regress. The six new trees pin that triple,
  the go lane's frozen test pins its own, (0, 2, 3) = 2,
  (0, 99, 3) = 3, (2, 1, 3) = 2, against the same three rules
- CommitByCounting refuses a prior-term entry even at 3 of 3
  replicas, (3, 3, term 1, current 2) is false in six lanes,
  python making the same refusal at 2 of 3
- a current-term entry commits at quorum, (2, 3, 2, 2) true, and
  does not below it, (1, 3, 2, 2) false

#listing("patterns-concurrency-distributed/samples-c/src/Ch11/commit.c", first: 19, last: 35, caption: [C, the clamp and the counting restriction, two small functions])

#listing("patterns-concurrency-distributed/samples/ch11/consensus.go", first: 59, last: 81, caption: [Go, clamp to what i hold, never regress, and the counting restriction])

#listing("patterns-concurrency-distributed/samples-java/src/Ch11/Commit.java", first: 18, last: 36, caption: [Java, the clamp never regresses, the counting check refuses any term but the current one])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch11/Commit.cs", first: 3, last: 33, caption: [C\#, Advance and ByCounting as static pure functions])

#listing("patterns-concurrency-distributed/samples-js/src/ch11-commit.mjs", first: 7, last: 22, caption: [JavaScript, two functions, floor division rebuilding the quorum])

#listing("patterns-concurrency-distributed/samples-py/src/Ch11/commit.py", first: 15, last: 26, caption: [Python, the same pair, floor division rebuilding the quorum])

#listing("patterns-concurrency-distributed/samples-lua/ch11_commit.lua", first: 6, last: 23, caption: [Lua, the same pair, floor division over wrapping integers])

Nothing here needs a data structure at all, three integers in, one
or a boolean out, and the seven listings are near transcriptions
of each other. That flatness is deliberate on the paper's part: the
commit rules are the safety argument, and safety arguments that
depend on clever code are not arguments. The lua commit file adds a
monotone envelope sweep, every (myCommit, leaderCommit) pair in a
grid checked to stay never above the log and never below the
current commit, a property the other lanes pin only at points.

#diagram([a current-term entry commits by counting and carries the prior term with it], length: 13pt, {
  let rows = (([leader], 6.4, (1, 1, 2)), ([follower a], 4.9, (1, 1, 2)), ([follower b], 3.4, (1, 1)))
  for (name, y, terms) in rows {
    cdraw.content((0.9, y + 0.45), name, size: 6pt)
    for i in range(terms.len()) {
      let dark = terms.at(i) == 2
      cdraw.rect((2.6 + i * 1.7, y), (4.1 + i * 1.7, y + 0.9), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((3.35 + i * 1.7, y + 0.45), [T#terms.at(i)], size: 6pt)
    }
  }
  cdraw.rect((6.0, 3.4), (7.7, 4.3), radius: 0.02, stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((6.85, 3.85), [missing], size: 6pt)
  for i in range(3) { cdraw.content((3.35 + i * 1.7, 2.45), [#(i + 1)], size: 6pt) }
  cdraw.content((3.35, 1.7), [entry 2, term 1: on a quorum, counting still refuses, term too old], size: 6pt)
  cdraw.content((3.35, 0.45), [entry 3, term 2: current term, 2 of 3 commits it, and 2 rides along], size: 6pt)
  cdraw.content((16.8, 4.6), [follower b clamps the leader's commit index to 2,#linebreak()what it actually holds], size: 6pt)
})

== the state, and what the capstone keeps

Each server persists `currentTerm`, `votedFor`, and the log,
everything needed to safely restart, and keeps volatile
`commitIndex`, `lastApplied`, and, as leader, `nextIndex` and
`matchIndex` per follower. The capstone implements exactly this
shape with a wal-backed sqlite store holding the persistent
triple, over an in-memory channel transport, with fixed membership,
the paper's joint-consensus membership changes being the labeled
door this book names and walks past.

#callout("note", "raft versus paxos", [
  Paxos family algorithms reach consensus on single values with no
  designated leader, at the cost of a protocol most readers cannot
  hold in their head. Raft trades a stronger leadership assumption
  for decomposability, election, replication, safety, three
  subproblems studied separately, which is why this chapter could
  be written and why the capstone fits in a few hundred tested
  lines.
])

#diagram([hard state persists, volatile state is rebuilt, joint consensus stays closed], length: 13pt, {
  cdraw.rect((0.4, 3.4), (11.0, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.7, 6.25), [persistent, survives restart], size: 6.5pt)
  cdraw.rect((0.8, 3.8), (10.6, 5.7), fill: luma(205), radius: 0.02)
  cdraw.content((5.7, 4.75), [currentTerm, votedFor, log], size: 6pt)
  cdraw.content((5.7, 2.7), [sqlite, wal journal, one transaction per save], size: 6pt)
  cdraw.rect((12.4, 3.4), (23.4, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((17.9, 6.25), [volatile, rebuilt on start], size: 6.5pt)
  cdraw.rect((12.8, 3.45), (23.0, 5.75), fill: luma(205), radius: 0.02)
  cdraw.content((17.9, 5.05), [commitIndex, lastApplied], size: 6pt)
  cdraw.content((17.9, 3.95), [nextIndex, matchIndex, per follower], size: 6pt)
  cdraw.rect((4.4, 0.6), (19.4, 2.1), radius: 0.02, stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((11.9, 1.35), [joint consensus, membership change: the named door this book does not open], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [234], [libc],
  [wrapping uint64_t lcg, the log copied by value into an out parameter],
  [go], [56], [stdlib],
  [frozen reference lane, the pcg timeout draw with its own property test],
  [java], [269], [jdk 27 stdlib],
  [long-wrapped lcg with no limb work, records over immutable lists frozen with List.copyOf],
  [c\#], [87], [bcl],
  [shared CorpusLcg helper, append never mutates the input, RemoveRange truncates],
  [javascript], [104], [node stdlib],
  [lcg state in 32-bit halves through 16-bit limbs, slices rebuild the log],
  [python], [180], [stdlib only],
  [a hand-masked int for the lcg, the empty log read through a negative index],
  [lua], [244], [lib.lua harness],
  [native 2^64 wrapping, 1-based indices, the commit file's monotone sweep],
)

sources: Ongaro and Ousterhout, "In Search of an Understandable
Consensus Algorithm (Extended Version)", raft.github.io/raft.pdf,
sections 5.2, 5.3, 5.4.1, and 5.4.2 and figure 2, accessed
2026-09-08, plus Ongaro's dissertation for the membership change
reference. Verified by the seven chapter legs: 4 C programs with 66
embedded checks, `go test` at 8 tests in `patternsbook/ch11`, the
java runner's 60 checks across 4 programs in `samples-java/src/Ch11`,
17 xunit facts, node's 7 cases across 5 suites in
`test/ch11.test.mjs`, the python runner's 48 checks across 4
modules, and the lua runner's 17 ch11 rows.
