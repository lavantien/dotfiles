#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= distributed systems answers

The distributed round rewards the structure of the design round plus
one move the other rounds do not test, the honest concession. Every
answer floors to the patterns handbook, whose raft, ring, and
messaging chapters carry the gated implementations, and the drills
are written to survive "have you actually run this", because one of
them has to answer no out loud.

== replication: leaders, followers, and lag [DRILL]

Single-leader replication is one node accepting writes and every
other node applying the same log in order, so the leader holds the
newest state and a follower read is a staleness decision, not a
free win. Lag is the leader's index minus the follower's, one
number, the per-follower matchIndex a raft leader keeps, and it is
a budget, not a bug: leader reads pay the queue, follower reads
accept staleness, read-your-writes pins the session to the node
that took the write. Promotion is an election, not a switch: a
follower that stops hearing heartbeats past a randomized timeout
runs for leader, needs f plus 1 votes out of 2f plus 1 nodes, and
the election restriction refuses the vote to a log that is behind,
so a stale replica cannot win. What promotion costs, volunteered:
the unreplicated tail is lost and survivors truncate diverged
suffixes, the repair walk #xref-to("patterns", "consensus")
implements. The follow-up is bounding the lag, answered with an
alert on the gap and a read path that names its staleness contract.

#diagram([the leader's log, two followers behind it, the gap is the lag], length: 13pt, {
  // one leader row and two follower rows, committed prefix shaded, the lag bracketed
  let cell(x, y, t, fill: luma(215)) = {
    cdraw.rect((x, y), (x + 1.6, y + 0.9), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + 0.8, y + 0.45), [#t], size: 6pt)
  }
  cdraw.content((0.2, 8.7), [leader], size: 6.5pt)
  for i in range(6) {
    cell(2.6 + i * 1.8, 8.3, [#(i + 1)], fill: if i < 4 { luma(215) } else { luma(245) })
  }
  cdraw.line((9.8, 8.0), (9.8, 9.5), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((6.2, 9.9), [committed], size: 6pt)
  cdraw.content((12.6, 9.9), [unreplicated], size: 6pt)
  cdraw.content((0.2, 6.7), [follower a], size: 6.5pt)
  for i in range(4) { cell(2.6 + i * 1.8, 6.3, [#(i + 1)]) }
  cdraw.content((0.2, 4.7), [follower b], size: 6.5pt)
  for i in range(3) { cell(2.6 + i * 1.8, 4.3, [#(i + 1)]) }
  cdraw.line((7.0, 3.8), (12.4, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.7, 3.3), [lag, 3 entries], size: 6pt)
  cdraw.content((11.5, 1.2), [a timeout fires, a majority elects, b's suffix is truncated], size: 6pt)
})

== sharding and partitioning strategies [DRILL]

Range partitioning hands each node a contiguous slice of the key
space: range scans stay cheap, and load concentrates where keys
cluster, the timestamp table whose newest range is one machine's
problem on every insert. Hash partitioning hashes the key first,
spreads the space evenly, and gives up the scan, so the choice is
locality against uniformity. Hot keys survive both, and the fixes
are the triplet: a cache in front, salt on the one key, split the
one burning range. Rebalancing is where the blast radius lives:
key mod n moves almost every key the moment the modulus changes,
while the ring with virtual nodes moves roughly 1/(n+1) on a join,
all of it to the new node and none between survivors,
#xref-to("patterns", "partitioning"). Both placements are valid
mid-move, so a rebalance ships as backfill plus cutover behind a
flag, and a botched one is an outage wearing a maintenance window.
The follow-up is the hot key, and the triplet answers it.

#diagram([range concentrates the hot end, hash spreads evenly, the join sets the blast radius], length: 13pt, {
  // two placement strips with a note under each, then the two rebalance panels
  let strip(y, label, hot: false) = {
    cdraw.content((1.2, y + 0.55), label, size: 6pt)
    for i in range(12) {
      let f = if hot and i >= 9 { luma(140) } else { luma(230) }
      cdraw.rect((4.6 + i * 1.5, y), (6.1 + i * 1.5, y + 1.1), fill: f, stroke: luma(120), radius: 0.02)
    }
  }
  strip(8.6, [range], hot: true)
  cdraw.content((11.5, 8.1), [range scans cheap, the hot end is one machine], size: 6pt)
  strip(6.4, [hash])
  cdraw.content((11.5, 5.9), [even, but no range scan], size: 6pt)
  cdraw.rect((1.0, 2.2), (11.2, 4.4), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((6.1, 3.9), [key mod n], size: 6.5pt)
  cdraw.content((6.1, 2.95), [n to n+1 moves n/(n+1)], size: 6pt)
  cdraw.rect((12.4, 2.2), (22.6, 4.4), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((17.5, 3.9), [the ring], size: 6.5pt)
  cdraw.content((17.5, 2.95), [a join moves 1/(n+1), all to the new node], size: 6pt)
  cdraw.content((11.8, 1.2), [mid-move both placements are valid: backfill, cutover, behind a flag], size: 6pt)
})

== consensus and raft, honestly [DRILL]

Raft guarantees two things: at most one leader per term, each server
voting once per term and persisting that vote, and a committed
entry is never overwritten, commitment needing a majority of the
current term, any two majorities of 2f plus 1 nodes sharing a node.
The prior-term restriction, an old entry committing only when a
current-term entry above it does, is the rule people forget. Then
the concession, before anyone asks it: the corpus has no production
raft. What exists is the patterns handbook's capstone, elections,
log repair, the commit rules, persistence across restarts, over an
in-memory channel transport with a drop predicate standing in for
the network, #xref-to("patterns", "capstone"). So "have you run it"
answers no, not in production, and here is exactly where the pieces
have run: the election restriction, the repair walk, and the commit
counting are pure functions with pinned fixtures,
#xref-to("patterns", "consensus"), and the capstone wires them into
nodes and kills the leader in its tests. Production adds what I
would read first, real rpcs, snapshots, joint consensus, and naming
the boundary beats claiming the stack. The follow-up is usually
paxos, answered with raft's design point, decomposability, one
head.

#diagram([one leader per term, the committed prefix survives the change, the tail does not], length: 13pt, {
  // left: term 1 dies holding an unreplicated entry, right: term 2 carries the prefix forward
  let cell(x, y, t, committed: true) = {
    cdraw.rect((x, y), (x + 1.5, y + 0.9), fill: if committed { luma(215) } else { luma(248) }, stroke: luma(120), radius: 0.02)
    cdraw.content((x + 0.75, y + 0.45), [#t], size: 6pt)
  }
  cdraw.content((4.0, 9.4), [term 1, the leader dies], size: 6.5pt)
  cdraw.content((0.2, 8.4), [leader], size: 6pt)
  cell(2.0, 8.0, [1]); cell(3.6, 8.0, [2]); cell(5.2, 8.0, [3])
  cdraw.rect((6.8, 8.0), (8.3, 8.9), fill: luma(248), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((7.55, 8.45), [4], size: 6pt)
  cdraw.content((0.2, 6.7), [follower a], size: 6pt)
  cell(2.0, 6.3, [1]); cell(3.6, 6.3, [2]); cell(5.2, 6.3, [3])
  cdraw.content((0.2, 5.0), [follower b], size: 6pt)
  cell(2.0, 4.6, [1]); cell(3.6, 4.6, [2])
  cdraw.content((16.6, 9.4), [term 2, a wins the vote], size: 6.5pt)
  cdraw.content((12.0, 8.4), [leader a], size: 6pt)
  cell(12.8, 8.0, [1]); cell(14.4, 8.0, [2]); cell(16.0, 8.0, [3])
  cdraw.rect((17.6, 8.0), (19.1, 8.9), fill: luma(215), stroke: 1pt, radius: 0.02)
  cdraw.content((18.35, 8.45), [4], size: 6pt)
  cdraw.content((12.0, 6.7), [follower b], size: 6pt)
  cell(12.8, 6.3, [1]); cell(14.4, 6.3, [2]); cell(16.0, 6.3, [3])
  cdraw.rect((17.6, 6.3), (19.1, 7.2), fill: luma(215), stroke: 1pt, radius: 0.02)
  cdraw.content((18.35, 6.75), [4], size: 6pt)
  cdraw.content((11.5, 3.9), [index 4 exists twice, term 1's copy is lost, term 2's is committed], size: 6pt)
  cdraw.content((11.5, 2.9), [the restriction: b, holding 1 and 2, could not win the election], size: 6pt)
})

== crdts versus distributed transactions [DRILL]

A crdt is a data type whose merge is associative, commutative, and
idempotent, so replicas take writes in any order, take them twice,
still converge, counters, sets, registers with a merge rule. What
it survives is the concurrency the vector clock names, two writes
with no causal order, and last-writer-wins by wall clock is the one
merge rule to refuse, #xref-to("patterns", "distributed"). A
distributed transaction is the opposite bet: a coordinator prepares
every participant, locks are held, one round commits or aborts all,
atomicity across shards bought with the round trips and the
in-doubt window, a coordinator dying after prepare leaving everyone
holding locks and guessing. The trade, said out loud: a crdt write
is one local write, available through a partition, a two-phase
commit pays the round trips, holds the locks, blocks on the
coordinator. Crdt for mergeable state, counts, carts, presence,
transactions for money or nobody's, the saga the pragmatic middle,
compensations orchestrated the way the design chapter draws it,
#xref-to("repertoire", "design-answers"). Say the distinction
first: raft is not two-phase commit, one log replicated to
identical replicas against one commit across different
participants. The follow-up is the failure question, answered with
the window, the locks, and who is allowed to guess.

#diagram([merge converges with no coordinator, prepare and commit hold locks across round trips], length: 13pt, {
  // left: two replicas converge on a merge, right: a coordinator, two shards, the in-doubt window
  cdraw.content((5.2, 9.1), [crdt], size: 6.5pt)
  cdraw.rect((1.0, 7.5), (4.4, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((2.7, 7.95), [replica a: x=1], size: 6pt)
  cdraw.rect((6.0, 7.5), (9.4, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((7.7, 7.95), [replica b: x=2], size: 6pt)
  cdraw.content((5.2, 6.7), [concurrent writes], size: 6pt)
  cdraw.line((2.7, 7.4), (4.4, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.7, 7.4), (6.0, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.6, 5.1), (7.8, 6.0), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((5.2, 5.55), [merged: x=1,2], size: 6pt)
  cdraw.content((5.2, 4.1), [one local write, merge later], size: 6pt)
  cdraw.content((17.5, 9.1), [two-phase commit], size: 6.5pt)
  cdraw.rect((14.5, 7.5), (20.5, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.5, 7.95), [coordinator], size: 6pt)
  cdraw.rect((13.0, 5.2), (16.2, 6.1), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((14.6, 5.65), [shard 1], size: 6pt)
  cdraw.rect((18.8, 5.2), (22.0, 6.1), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((20.4, 5.65), [shard 2], size: 6pt)
  cdraw.line((15.0, 7.4), (14.3, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.0, 7.4), (20.7, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.9, 6.7), [prepare, locks held], size: 6pt)
  cdraw.line((14.3, 5.0), (15.2, 4.3), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((20.7, 5.0), (19.8, 4.3), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((17.5, 3.8), [commit or abort, the in-doubt window in between], size: 6pt)
  cdraw.content((11.5, 2.5), [a crdt write is local and partition-safe, a 2pc write blocks on the coordinator], size: 6pt)
})

== delivery semantics and idempotency [DRILL]

At-most-once is fire and forget, right for telemetry where a lost
sample is cheaper than a retry. At-least-once retries until
acknowledged and duplicates, the sender unable to tell a delivery
that never arrived from an ack that drowned. Exactly-once delivery
does not exist on a real network, what the phrase names is
exactly-once effect, at-least-once into a consumer that remembers
what it applied, #xref-to("patterns", "messaging"). The idempotency
key is the design: minted once by the sender, stable across
retries, never derived from the arrival, a fresh key per retry
deduping nothing. The outbox closes the dual write: state change
and message in one database transaction, a relay draining
afterward, so a crash between saved and sent loses nothing. The
running code behind the answer: the durable consumer of the
streaming chapter binds by name, tracks its ack floor, naks
failures back for redelivery, and after a broker restart receives
exactly the unacked tail, #xref-to("repertoire", "go-streaming"),
the same contract #xref-to("infrastructure", "jetstream") runs
against a real broker. The follow-up is the double delivery,
answered with the applied set, one membership test, the effect
once.

#callout("pitfall", "exactly-once is an effect, not a delivery setting", [
  No transport delivers exactly once across a real network, because
  the acknowledgment itself can be lost after the effect happened.
  What a broker's exactly-once means is at-least-once delivery into
  a consumer that deduplicates on a stable idempotency key, so the
  claim to defend in the interview is the dedupe, never the wire.
])

#diagram([at-least-once into an idempotent consumer, the outbox closing the dual write], length: 13pt, {
  // one transaction holds the state row and the outbox row, then relay, broker, and the dedup
  cdraw.rect((0.4, 6.8), (7.6, 8.9), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((4.0, 8.35), [one transaction], size: 6.5pt)
  cdraw.content((4.0, 7.45), [state row + outbox row], size: 6pt)
  cdraw.line((7.6, 7.85), (8.9, 7.85), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.9, 6.8), (13.3, 8.9), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((11.1, 8.35), [relay], size: 6.5pt)
  cdraw.content((11.1, 7.45), [drains, at-least-once], size: 6pt)
  cdraw.line((13.3, 7.85), (14.6, 7.85), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.6, 6.8), (19.9, 8.9), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.25, 8.35), [broker], size: 6.5pt)
  cdraw.content((17.25, 7.45), [durable, ack floor], size: 6pt)
  cdraw.line((19.9, 7.85), (21.3, 7.85), stroke: luma(100), mark: (end: ">"))
  cdraw.line((21.3, 7.85), (21.3, 5.5), (17.3, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.9, 4.5), (17.3, 6.2), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((15.1, 5.7), [the consumer], size: 6.5pt)
  cdraw.content((15.1, 4.95), [applied set, dedupe], size: 6pt)
  cdraw.line((12.9, 5.5), (9.3, 5.5), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((7.4, 5.9), [ack], size: 6pt)
  cdraw.content((11.5, 3.6), [duplicates arrive, the effect happens once], size: 6pt)
  cdraw.content((11.5, 2.6), [a lost ack is a redelivery, never a loss, never a double effect], size: 6pt)
})

sources: no measurements in this chapter, every number is the
textbook value, quorums as 2f+1 and movement as 1/(n+1), and every
drill floors to the patterns handbook,
#xref-to("patterns", "distributed") for quorum arithmetic and
concurrency, #xref-to("patterns", "consensus") for the election and
commit rules, #xref-to("patterns", "partitioning") for the ring,
#xref-to("patterns", "messaging") for the dedup contract and the
outbox, and #xref-to("patterns", "capstone") for the raft that
actually runs.
