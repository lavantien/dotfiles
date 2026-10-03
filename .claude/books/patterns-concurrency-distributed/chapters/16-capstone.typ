#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= capstone: raft replicated configuration service

The capstone is raft itself, small enough to hold, complete enough
to be real: elections with randomized timeouts, log replication
with the consistency check, commitment with the prior-term
restriction, persistence across restarts, and a configuration
service on top that hides leadership changes behind retries. It
lives at `patterns-concurrency-distributed/capstone/`, one module,
two packages, nineteen tests, zero skipped, every file under 370
lines.

== the shape

Every node is chapter 8's pattern in miniature: one goroutine
owning all state, consuming one inbox channel, no locks anywhere in
the consensus code. The transport is a hub of inbox channels with a
drop predicate standing in for the network. And the clock is
explicit: elections fire on tick counts, never on wall time, so a
test advances the world one round at a time and every interleaving
is a choice the test made.

#listing("patterns-concurrency-distributed/capstone/raft/node.go", first: 8, last: 32, caption: [the whole node: persistent triple, volatile state, leader bookkeeping])

#flow(
  [one node's event loop],
  node((0, 0), [inbox chan]),
  node((1.7, 0), [handle: one message]),
  node((3.5, 0), [raft state, unlocked]),
  node((5.3, 0), [hub.Send replies]),
  node((3.5, 1.1), [apply to config map]),
  edge((0, 0), (1.7, 0), "-|>"),
  edge((1.7, 0), (3.5, 0), "-|>"),
  edge((3.5, 0), (5.3, 0), "-|>"),
  edge((3.5, 0), (3.5, 1.1), "-|>"),
)

The hub's one subtlety earned its comment the honest way, by
panicking during development: delivery is serialized against
teardown under the hub's mutex, so a send can never land on a
closed channel when a node restarts. And the partition predicate
applies only to the four raft rpcs, ticks are a node's own clock,
probes are the harness looking in, client requests arrive at the
node they address. The first version dropped ticks addressed
through a partitioned link and the isolated node's election timer
froze, invisible until a test asserted its term never grew.

#listing("patterns-concurrency-distributed/capstone/raft/hub.go", first: 29, last: 48, caption: [drop only what crosses the network])

== elections

Chapter 11's rules, wired to state:

#listing("patterns-concurrency-distributed/capstone/raft/node.go", first: 136, last: 221, caption: [tick counting, candidacy, the 5.4.1 restriction on granting votes])

#diagram([three tick counters, randomized timeouts, someone fires first and resets everyone], length: 13pt, {
  let tx = (t) => 1.2 + t * 1.28
  let nodes = (([node 0], 5.6, 12), ([node 1], 4.0, 9), ([node 2], 2.4, 14))
  for (name, y, timeout) in nodes {
    cdraw.content((0.0, y), name, size: 6pt)
    cdraw.line((tx(0), y), (tx(16.5), y), stroke: 1pt)
    // each node's randomized timeout, hollow: never reached
    cdraw.circle((tx(timeout), y), radius: 0.13, stroke: luma(100), fill: white)
  }
  // node 1 fires first, wins the term
  cdraw.circle((tx(9), 4.0), radius: 0.13, fill: luma(30))
  cdraw.content((tx(9) - 2.9, 4.45), [fires first, term++, wins], size: 6pt)
  // the heartbeat resets the other two timers
  cdraw.line((tx(10.5), 1.6), (tx(10.5), 6.3), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.circle((tx(10.5), 5.6), radius: 0.13, fill: luma(30))
  cdraw.circle((tx(10.5), 2.4), radius: 0.13, fill: luma(30))
  cdraw.content((tx(10.5) + 1.4, 6.55), [heartbeat resets the counters], size: 6pt)
  // the axis
  cdraw.line((tx(0), 1.2), (tx(16.5), 1.2), stroke: luma(100))
  for t in (0, 5, 10, 15) {
    cdraw.line((tx(t), 1.05), (tx(t), 1.35), stroke: luma(100))
    cdraw.content((tx(t), 0.7), [#t], size: 6pt)
  }
  cdraw.content((tx(8), -0.1), [ticks, timeouts drawn 8 to 15 from a seeded pcg], size: 6pt)
  cdraw.content((tx(8), -1.4), [same seed, same election schedule every run], size: 6pt)
})

Each node's timeout is 8 to 15 ticks drawn from a seeded PCG, so
split votes resolve because someone's timer fires first, and the
same seed means the same schedule every run. `onVote` is the
paper's figure 2 condition written down: step down on a higher
term, then grant only if the vote is unused this term and the
candidate's log is at least as up-to-date, larger last term wins,
equal terms go to length.

== replication and commitment

The follower path is ch11's pure `Append` with the persistence and
commit clamps attached:

#listing("patterns-concurrency-distributed/capstone/raft/node.go", first: 253, last: 307, caption: [prev check, conflict truncation, commit clamped to my log])

#flow(
  [leader bookkeeping: replies set matchindex to what was sent],
  node((0, 0), [append sent,#linebreak()sentThrough records it]),
  node((2.7, 1.2), [rejected: prev mismatch,#linebreak()nextIndex walks back]),
  node((2.7, -1.2), [accepted reply:#linebreak()matchIndex = sentThrough]),
  node((5.6, 0), [advanceCommit,#linebreak()current-term entries only]),
  edge((0, 0), (2.7, 1.2), "-|>", label: [conflict]),
  edge((0, 0), (2.7, -1.2), "-|>", label: [success]),
  edge((2.7, 1.2), (0, 0), "-|>", bend: 40deg, label: [retry]),
  edge((2.7, -1.2), (5.6, 0), "-|>"),
)

The leader path tracks `nextIndex` and `matchIndex` per peer, with
one addition beyond the paper's minimum, `sentThrough`, the highest
index actually put on the wire per peer, because a success reply
must set `matchIndex` to what was sent, not what the leader wishes
was sent. Commitment counts replicas only for current-term entries
and, on becoming leader, the node appends a no-op entry from its
own term so prior-term entries ride its commitment, section 5.4.2
in two lines:

#listing("patterns-concurrency-distributed/capstone/raft/leader.go", first: 70, last: 88, caption: [the counting restriction, wired])

#listing("patterns-concurrency-distributed/capstone/raft/node.go", first: 223, last: 240, caption: [leadership claimed with a heartbeat and a no-op])

Persistence is the paper's hard state, `currentTerm`, `votedFor`,
the log, written to SQLite as one transaction per save over a wal
journal at synchronous full, so a crash leaves the old state or the
new, never half:

#listing("patterns-concurrency-distributed/capstone/raft/sqlite_store.go", first: 75, last: 110, caption: [one transaction per save: term, vote, and the whole log rewritten atomically])

The json store from the first draft survives beside it as the
reference implementation, and a parity test cross-checks the two on
every shape the log takes:

#listing("patterns-concurrency-distributed/capstone/raft/persist.go", first: 24, last: 38, caption: [write temp, rename over: the reference store the parity test cross-checks])

== the service

The configuration service wraps the cluster and routes writes to
whoever leads. Its interesting logic is failure handling: an
isolated stale leader neither refuses nor commits, it stalls, so a
timeout is treated as a rejection, the clock advances to give the
majority time to elect, and the write rides the new leader:

#listing("patterns-concurrency-distributed/capstone/service/service.go", first: 35, last: 64, caption: [round the nodes, treat stalls as rejections, tick between rounds])

#flow(
  [stalls are rejections, the clock advances so a majority can elect],
  node((0, 0), [write(key, val)]),
  node((2.2, 0), [try node 0..n-1]),
  node((4.6, 1.3), [not leader,#linebreak()next node]),
  node((4.6, 0), [stall: treated#linebreak()as rejection]),
  node((4.6, -1.3), [leader commits]),
  node((7.0, 0.6), [TickN(16),#linebreak()second round]),
  edge((0, 0), (2.2, 0), "-|>"),
  edge((2.2, 0), (4.6, 1.3), "-|>", label: [ErrNotLeader]),
  edge((2.2, 0), (4.6, 0), "-|>", label: [timeout]),
  edge((2.2, 0), (4.6, -1.3), "-|>", label: [ok]),
  edge((4.6, 1.3), (7.0, 0.6), "-|>"),
  edge((4.6, 0), (7.0, 0.6), "-|>"),
)

That loop is chapter 15's retry discipline applied to consensus,
and the test for it is the capstone's centerpiece: elect a leader,
commit a value, partition the leader away, write through the
service anyway, and assert the write landed and the old leader
resynchronized after healing. A follower rejecting a client write
with `ErrNotLeader` is also pinned, the error the service loops on.

== what the tests prove

The suite runs green through `make verify-go`, repeatedly, and
under `go test -race`:

#listing("patterns-concurrency-distributed/capstone/raft/raft_test.go", first: 85, last: 124, caption: [the partition test: majority commits, minority stalls, ghost never applies])

#diagram([eight raft tests, eight pinned properties], length: 13pt, {
  cdraw.content((4.4, 8.35), [the test], size: 6.5pt)
  cdraw.content((16.1, 8.35), [the property it pins], size: 6.5pt)
  let cols = ((0.4, 8.4), (8.8, 23.4))
  let rows = (
    ([single node], [elects and commits without peers]),
    ([three node replication], [same commit index, same applied map]),
    ([follower write], [rejected with ErrNotLeader]),
    ([majority partition], [ghost entry overwritten, never applied]),
    ([lagging follower], [catches up by heartbeat alone]),
    ([restart], [term, vote, log intact, no double vote]),
    ([election restriction], [stale log loses at a higher term]),
    ([quiescent drain], [everything settles in bounded time]),
  )
  for (i, row) in rows.enumerate() {
    let y = 6.7 - i * 1.1
    for (j, cell) in row.enumerate() {
      let c = cols.at(j)
      cdraw.rect((c.at(0), y), (c.at(1), y + 0.9), fill: luma(235), radius: 0.02)
      cdraw.content(((c.at(0) + c.at(1)) / 2, y + 0.45), cell, size: 6pt)
    }
  }
})

Single-node election and commit. Three-node replication with every
node reaching the same commit index and the same applied map.
Follower write rejection. The majority-partition scenario, the
minority's uncommitted "ghost" entry overwritten rather than
applied after healing, which is the log truncation path doing its
job. A lagging follower catching up through heartbeats alone.
Restart with term, vote, and log intact, the recovered node not
voting twice in one term. The election restriction holding when a
stale-log node arrives with a pumped-up term. And quiescent drain
in bounded time.

The honest boundaries, stated in the code and here: membership is
fixed at construction, the paper's joint consensus is a named door
this book does not open. Snapshots do not exist, the log replays in
full on restart, right at teaching sizes, wrong at millions of
entries. Reads serve the leader's applied state first and fall
back to followers, eventual but committed, and a linearizable read
would need the read-index round trip the paper describes. The
transport is in-memory, so the capstone proves the protocol, not
the serialization. Each of those lines is where production raft,
etcd and its kin, spends its next ten thousand lines.

sources: Ongaro and Ousterhout, raft.github.io/raft.pdf, figure 2
and sections 5.2 through 5.4.2, implemented and verified against
go 1.27, accessed 2026-09-08. Verified by `make verify-go` plus
`go test -race`, 15 raft-package tests (8 protocol, 7 store) and
4 service tests, zero skipped.
