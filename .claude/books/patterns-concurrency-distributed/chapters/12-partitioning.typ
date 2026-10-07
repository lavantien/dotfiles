#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= partitioning and consistent hashing

Partitioning spreads data over machines so capacity grows with the
cluster, and the engineering problem is not the spread, it is the
reshuffle. `key mod n` places keys perfectly uniformly, and adding
one machine moves almost every key, which at cache scale is an
outage wearing a maintenance window. This chapter builds the two
placement schemes that move the minimum, consistent hashing and
rendezvous, plus jump hash, the stateless special case, and one
hashing bug worth more than all of them. It is also this book's
exact-lane chapter: the raw hash universe and every placement
sequence are pinned byte-identical across the six sibling trees,
while the frozen go tests hold the stability and band properties,
and the dry runs below say which lane asserts what.

== the naive baseline and its cost

With `n` nodes and `key mod n`, taking the cluster from n to n+1
changes the modulus, so every key whose remainder changes relocates,
for typical sizes that is `n/(n+1)` of the key space, near total
churn. The goal shape instead: when a node joins, only the keys that
move are the ones handed to the new node, roughly `1/(n+1)`, and
when a node leaves, only its keys redistribute to survivors.

#diagram([key mod n churns almost everything, the goal shape moves 1/(n+1)], length: 13pt, {
  let owner-fill = (a: luma(60), b: luma(140), c: luma(200), d: rgb("#B8860B"))
  let strip(y, label, owners) = {
    cdraw.content((1.9, y + 0.6), label, size: 6pt)
    for k in range(12) {
      let o = owners.at(k)
      cdraw.rect((4.2 + k * 1.5, y), (5.6 + k * 1.5, y + 1.2), fill: owner-fill.at(o), radius: 0.02)
      cdraw.content((4.9 + k * 1.5, y + 0.6), [#o], size: 6pt, fill: white)
    }
  }
  // key mod 3: keys 0-11 owned by k % 3
  strip(6.4, [key mod 3], ("a", "b", "c", "a", "b", "c", "a", "b", "c", "a", "b", "c"))
  // key mod 4 after d joins: k % 4, ticks under keys whose owner changed
  strip(3.9, [key mod 4,#linebreak()d joins], ("a", "b", "c", "d", "a", "b", "c", "d", "a", "b", "c", "d"))
  for k in (3, 4, 5, 6, 7, 8, 9, 10, 11) {
    cdraw.line((4.9 + k * 1.5, 3.85), (4.9 + k * 1.5, 3.5), stroke: luma(30))
  }
  cdraw.content((13.5, 3.0), [9 of 12 keys find a new owner], size: 6pt)
  // the goal: only the keys handed to the new node move, outlined
  strip(1.4, [the goal], ("a", "b", "c", "d", "b", "c", "a", "d", "c", "a", "b", "d"))
  for k in (3, 7, 11) {
    cdraw.rect((4.2 + k * 1.5, 1.4), (5.6 + k * 1.5, 2.6), radius: 0.02, stroke: 1pt)
  }
  cdraw.content((13.5, 0.55), [3 of 12 move, all of them handed to d], size: 6pt)
})

== consistent hashing with virtual nodes

Each physical node is hashed onto `vnodes` points around a ring of
uint64 values, and a key belongs to the first point at or clockwise
after its own hash:

The dry run: the exact-lane contract, split by design.

- the go lane's frozen tests pin stability and bands: ownership
  never drifts across queries, a 1-of-4 join moves between 1500 and
  3500 of 10000 keys with every mover landing on the new node,
  four-node balance stays inside 550..1450 of 4000, and removal
  never disturbs a survivor
- the six sibling trees pin the exact sequences off the same
  implementation: the join moves exactly 2303 keys, all to n4, with
  post counts 2870/2267/2560/2303, balance lands 1174/1024/879/923,
  and removing n2 relocates exactly 705 keys, 321 to n1 and 384 to
  n3
- ring{alpha,beta} at 64 vnodes owns user:0..9 as
  a,a,a,b,a,a,a,b,a,b, the ownership strip the six new trees pin

#listing("patterns-concurrency-distributed/samples-c/src/Ch12/ring.c", first: 73, last: 123, caption: [C, insertion-sorted points with the node name breaking hash ties, owner scans for the first point at or after the key])

#listing("patterns-concurrency-distributed/samples/ch12/hashing.go", first: 38, last: 105, caption: [Go, ring points sorted by hash, owner is the first point after the key, wrapping])

#listing("patterns-concurrency-distributed/samples-java/src/Ch12/Ring.java", first: 55, last: 101, caption: [Java, points sorted by unsigned hash with the node name tiebreak, owner scans for the first point at or after the key])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch12/Ring.cs", first: 21, last: 46, caption: [C\#, Add hashes each vnode string and sorts by hash with an ordinal tiebreak, Remove drops the node's points])

#listing("patterns-concurrency-distributed/samples-js/src/ch12-ring.mjs", first: 14, last: 52, caption: [JavaScript, the ring over {hi, lo} hash pairs, the lower-bound binary search written by hand])

#listing("patterns-concurrency-distributed/samples-py/src/Ch12/ring.py", first: 40, last: 68, caption: [Python, points sorted as (hash, node) tuples, bisect_left finds the wrap point])

#listing("patterns-concurrency-distributed/samples-lua/ch12_ring.lua", first: 50, last: 96, caption: [Lua, the sign bit xored into the comparison key so wrapped negatives sort where they belong])

Virtual nodes are the balance mechanism: one hash point per node
leaves ownership proportional to random arc lengths, wildly uneven
for small clusters, while 100 to 200 vnodes per node averages the
arcs until each node's share sits near `1/n`. The tiebreak matters
as much as the sort: points with equal hashes order by node name in
every lane, go through `slices.Compare` on the names, c through
`strcmp` inside its insertion sort, c\# through `CompareOrdinal`,
and the dynamic four through their native string order, which is
one of the two details that keep seven independent implementations
on one movement sequence. The other is the hash itself, next
section.

The test side is half the fixture, and each tree answers with its
own test artifact: the frozen go test file, the xunit and node test
files, and the check regions of the C, java, python, and lua
modules.

#listing("patterns-concurrency-distributed/samples-c/src/Ch12/ring.c", first: 148, last: 181, caption: [C, the check region: 2303 movers, all gained, post counts exact, the go lane's band stated beside them])

#listing("patterns-concurrency-distributed/samples/ch12/hashing_test.go", first: 26, last: 62, caption: [Go, a one-of-four join moves a quarter of keys, and only to the new node])

#listing("patterns-concurrency-distributed/samples-java/src/Ch12/Ring.java", first: 128, last: 157, caption: [Java, the check region: 2303 movers all gained, post counts 2870, 2267, 2560, 2303, the band beside])

#listing("patterns-concurrency-distributed/samples-cs/tests/Ch12/RingTests.cs", first: 26, last: 73, caption: [C\#, xunit pins the witnessed actuals inside the band the go lane asserts])

#listing("patterns-concurrency-distributed/samples-js/test/ch12.test.mjs", first: 53, last: 76, caption: [JavaScript, node:test pins moved 2303, gained equal, post counts exact])

#listing("patterns-concurrency-distributed/samples-py/src/Ch12/ring.py", first: 89, last: 109, caption: [Python, the script region: 2303 movers, post counts, the band checked beside])

#listing("patterns-concurrency-distributed/samples-lua/ch12_ring.lua", first: 123, last: 144, caption: [Lua, the movement row: 2303 movers, 2303 gained, counts exact])

Adding a fourth node to three moves 10000 keys by roughly 2500, all
of them landing on the new node, no key ever shuffling between
survivors, and the six exact lanes say it is 2303 for this
generator. Removal symmetrically relocates only the departed node's
keys, 705 of them here. That is the whole sales pitch of the ring,
and the same test walk checks balance, four nodes within a band
around 1000 of 4000 keys each, 1174/1024/879/923 exact, because a
scheme that moves nothing but concentrates everything is not a
solution.

#diagram([the ring, vnode points, and the clockwise owner rule], length: 13pt, {
  let cx = 6.5
  let cy = 3.2
  let rad = 3.0
  cdraw.circle((cx, cy), radius: rad, stroke: 0.7pt)
  let pts = (30deg, 170deg, 290deg, 90deg, 210deg, 330deg, 150deg, 250deg, 10deg)
  let fills = (luma(60), luma(60), luma(60), luma(140), luma(140), luma(140), luma(200), luma(200), luma(200))
  for i in range(9) {
    let a = pts.at(i)
    cdraw.circle((cx + rad * calc.cos(a), cy + rad * calc.sin(a)), radius: 0.14, fill: fills.at(i))
  }
  // one key, its arc to the first point clockwise
  let ka = 60deg
  let kp = (cx + rad * calc.cos(ka), cy + rad * calc.sin(ka))
  cdraw.rect((kp.at(0) - 0.12, kp.at(1) - 0.12), (kp.at(0) + 0.12, kp.at(1) + 0.12), fill: rgb("#B8860B"))
  cdraw.arc((cx, cy), start: ka, stop: 10deg, radius: rad, ccw: false, stroke: 1pt)
  cdraw.content((cx, cy - rad - 1.0), [the arc runs clockwise from the key to its owner], size: 6.5pt)
  // legend
  let leg(y, fill, t, square: false) = {
    if square { cdraw.rect((13.4, y - 0.12), (13.64, y + 0.12), fill: fill) }
    else { cdraw.circle((13.5, y), radius: 0.14, fill: fill) }
    cdraw.content((16.3, y), [#t], size: 6.5pt)
  }
  leg(5.0, luma(60), [node a vnodes])
  leg(3.8, luma(140), [node b vnodes])
  leg(2.6, luma(200), [node c vnodes])
  leg(1.4, rgb("#B8860B"), [key hash], square: true)
})

== the bug the probe caught

The first implementation hashed vnodes with raw FNV-1a and the
balance test failed with one node owning 60 percent of 4000 keys. A
one-off probe printed the vnode hashes and found the problem in one
line: every node's points shared their high bits, the entire vnode
population occupied a narrow arc of the ring, and almost every key
wrapped around to the first point after that arc. FNV-1a diffuses
downstream bytes beautifully into low bits, its high bits barely
avalanche, and ring placement lives in the high bits. The bit-level
anatomy of hashing, avalanche included, is the dsa hashing
chapter's subject, #xref-to("dsa", "hashing"). The fix is a
finalizer:

The dry run: the raw hash universe, 13 inputs through fnv64a plus
the mix64 finalizer.

- the six new trees pin the exact decimals: alpha
  8596495612706370024, beta 17294041484173018516, n1
  17934566338607214163, n2 13970388862098144604, n3
  4545224107033280897, n4 12077200234615595018, user:7
  977887655448102184, and the routing keys A through F
- the go lane's frozen tests pin no raw hash at all, they pin the
  behavior the hashes produce, so the raw universe is the six
  trees' contract
- javascript keeps src on limb pairs and converts to BigInt only in
  the test to state the constants exactly, lua parses every pin
  from a decimal string because a decimal literal past 2^63 lexes
  as a float, and java carries the pins above 2^63 through
  `Long.parseUnsignedLong` on the identical decimal string because
  no positive long literal reaches past `Long.MAX_VALUE`

#listing("patterns-concurrency-distributed/samples-c/src/Ch12/hash.c", first: 20, last: 37, caption: [C, mix64 after fnv, the outputs are the pinned decimals])

#listing("patterns-concurrency-distributed/samples/ch12/hashing.go", first: 11, last: 31, caption: [Go, fnv then splitmix-style mix: placement hashes need avalanche in every bit])

#listing("patterns-concurrency-distributed/samples-java/src/Ch12/Hash.java", first: 18, last: 41, caption: [Java, long arithmetic wraps like ulong, mix64 verbatim, the pins above 2^63 carried by parseUnsignedLong])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch12/Hash.cs", first: 11, last: 35, caption: [C\#, ulong arithmetic, the finalizer verbatim])

#listing("patterns-concurrency-distributed/samples-js/src/ch12-hash.mjs", first: 82, last: 96, caption: [JavaScript, the finalizer over limb pairs, xor-shift and multiply in 16-bit pieces])

#listing("patterns-concurrency-distributed/samples-py/src/Ch12/hash.py", first: 21, last: 43, caption: [Python, the raw fnv and the finalizer side by side, masked to 64 bits])

#listing("patterns-concurrency-distributed/samples-lua/ch12_hash.lua", first: 8, last: 28, caption: [Lua, wrapping integer multiplies, the finalizer in three lines])

The finalizer is where the carriers separate most. C, c\#, go, and
lua multiply unsigned 64-bit values that wrap by construction, c
and lua because the types wrap, c\# because `ulong` overflow wraps
silently, go because `uint64` is defined to. Java's signed `long`
overflow wraps silently the same way, so the recurrence is one
line, and the lane meters avalanche as an exact unsigned interval
through `Long.compareUnsigned`. Python masks by hand after every
multiply, javascript runs every multiply through 16-bit limbs of
32-bit halves, and the lua lane even meters the avalanche directly,
one changed input digit moving 9 output bits through raw fnv and 33
through the finalizer. Same integers, same decimals, very different
proofs.

#diagram([raw fnv vnodes crowd one arc, mix64 spreads them over the ring], length: 13pt, {
  let dot(cx, cy, a, fill) = cdraw.circle((cx + 2.2 * calc.cos(a), cy + 2.2 * calc.sin(a)), radius: 0.14, fill: fill)
  let fills = (luma(60), luma(140), luma(200))
  // before: all vnode hashes inside one narrow arc
  cdraw.circle((5.0, 3.2), radius: 2.2, stroke: 0.7pt)
  let clustered = (25deg, 34deg, 43deg, 52deg, 61deg, 70deg, 79deg)
  for i in range(7) { dot(5.0, 3.2, clustered.at(i), fills.at(calc.rem(i, 3))) }
  cdraw.content((5.0, 6.4), [raw fnv-1a], size: 6.5pt)
  cdraw.content((5.0, 0.4), [all points crowd one narrow arc,#linebreak()one node owns 60 percent], size: 6pt)
  // after: avalanche spreads the same seven points
  cdraw.circle((17.5, 3.2), radius: 2.2, stroke: 0.7pt)
  for i in range(7) { dot(17.5, 3.2, i * (360deg / 7) + 10deg, fills.at(calc.rem(i, 3))) }
  cdraw.content((17.5, 6.4), [fnv then mix64], size: 6.5pt)
  cdraw.content((17.5, 0.4), [avalanche in every bit spreads#linebreak()the same points over the ring], size: 6pt)
})

This is a general lesson wearing a specific costume: check the
output distribution of a hash at the bit granularity the consumer
uses. A hash that looks fine for checksums, where any bit change
detects corruption, can be catastrophically biased for placement,
where uniformity per bit region is the product. The same `mix64`
now guards the rendezvous scheme's node ranking.

== rendezvous, highest random weight

Rendezvous hashing reaches the same minimal-movement property with
no ring and no vnodes: rank every node by `hash(node, key)` and take
the maximum:

The dry run: exact winners and exact movement, five trees against
the go lane's bands.

- user:0..5 rank n2,n3,n2,n2,n2,n3 over {n1,n2,n3} and flip to
  n2,n4,n4,n4,n2,n4 once n4 joins, pinned by the six new trees
- the join moves exactly 1010 of 4000 keys, every mover captured by
  n4, exact in the six new trees
- all seven lanes assert moved equal to gained inside the band
  500..1500

#listing("patterns-concurrency-distributed/samples-c/src/Ch12/rendezvous.c", first: 58, last: 82, caption: [C, the score is hash over node, a real NUL byte, then key, matching go's join byte for byte])

#listing("patterns-concurrency-distributed/samples/ch12/hashing.go", first: 123, last: 150, caption: [Go, one hash per node per key, winner owns it])

#listing("patterns-concurrency-distributed/samples-java/src/Ch12/Rendezvous.java", first: 34, last: 76, caption: [Java, the score hashes node chars, the NUL, then key chars, the max taken by unsigned comparison])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch12/Rendezvous.cs", first: 7, last: 34, caption: [C\#, the whole scheme is a sorted list and one max scan])

#listing("patterns-concurrency-distributed/samples-js/src/ch12-rendezvous.mjs", first: 7, last: 32, caption: [JavaScript, cmp64 orders the {hi, lo} weights, the max scan over sorted nodes])

#listing("patterns-concurrency-distributed/samples-py/src/Ch12/rendezvous.py", first: 37, last: 55, caption: [Python, the max over hash(node, key) scores])

#listing("patterns-concurrency-distributed/samples-lua/ch12_rendezvous.lua", first: 34, last: 60, caption: [Lua, ukey flips the sign bit so the max is unsigned])

The join every lane hashes is `node`, one NUL byte, `key`, byte
identical in all seven, go and javascript through the `\x00`
escape, c by building the buffer with a real zero byte, c\# and
python through their own spellings, lua through `\0`, java by
an xor against a literal 0 between the two strings.
Unsigned comparison is the only trap left, and two lanes pay it
openly: lua xors the sign bit into the comparison key because its
integers are signed, and java routes every hash ordering through
`Long.compareUnsigned`, because `>`, `>=`, and `Long.compare` are
signed and would sort the values above 2^63 as negatives. When a
node joins it captures exactly the keys where it outranks the
incumbent winner, which is again `1/(n+1)` of the space. The trade
is lookup cost, o(n) hashes against o(log v) binary searches,
against simplicity, no state, no rebuild on membership change, no
vnode tuning. Client-side placement, where the cluster list is
small and public, favors rendezvous, server-side placement at scale
favors the ring.

#diagram([highest random weight: per key, every node is scored, the max owns it], length: 13pt, {
  cdraw.content((2.0, 7.4), [node], size: 6.5pt)
  let keys = ("key 1", "key 2", "key 3")
  for j in range(3) {
    cdraw.content((6.9 + j * 6.4, 7.4), keys.at(j), size: 6.5pt)
  }
  // winners per column: key1 -> b, key2 -> a, key3 -> c then d after the join
  let winners = (1, 0, 2)
  let rows = (("node a", ("0x51", "0xc7", "0x29")), ("node b", ("0x9a", "0x3b", "0x77")), ("node c", ("0x2f", "0x68", "0x8e")))
  for (i, row) in rows.enumerate() {
    let y = 6.0 - i * 1.4
    cdraw.content((2.0, y + 0.6), row.at(0), size: 6pt)
    for j in range(3) {
      let win = winners.at(j) == i
      cdraw.rect((3.9 + j * 6.4, y), (9.9 + j * 6.4, y + 1.2), fill: if win { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((6.9 + j * 6.4, y + 0.6), [hash = #row.at(1).at(j)], size: 6pt)
    }
  }
  // the joining node, dashed, outranks the incumbent only on key 3
  let y = 6.0 - 3 * 1.4
  cdraw.content((2.0, y + 0.6), [node d joins], size: 6pt)
  for j in range(3) {
    let win = j == 2
    cdraw.rect((3.9 + j * 6.4, y), (9.9 + j * 6.4, y + 1.2), radius: 0.02, fill: if win { luma(205) } else { none }, stroke: (paint: luma(100), dash: "dashed"))
    cdraw.content((6.9 + j * 6.4, y + 0.6), [hash = #(("0x44", "0x5a", "0xb1")).at(j)], size: 6pt)
  }
  cdraw.content((6.9, 1.15), [owned by b], size: 6pt)
  cdraw.content((13.3, 1.15), [owned by a], size: 6pt)
  cdraw.content((19.7, 1.15), [c, then d after the join], size: 6pt)
  cdraw.content((11.9, -0.05), [the winner is the maximum, a joining node captures exactly the keys it outranks the incumbent on], size: 6pt)
})

== jump consistent hash

Lamping and Veach's jump hash answers "which bucket owns key k when
there are n buckets" with a loop and no memory at all, and its
stability property is exact: growing from n to n+1 buckets, every
key either stays or moves to bucket n, never between old buckets:

The dry run: the table and the two properties.

- rows across bucket counts 1..5 are pinned byte-exact by the six
  new trees: k=2 [0,0,0,3,3], k=3 [0,0,2,3,3], k=4 [0,1,1,1,1],
  k=5 [0,1,1,1,4], k=6 [0,1,2,2,2], k=8 [0,0,0,0,4], k=9
  [0,0,2,2,2], and the c, java, python, and lua lanes pin the full
  table, all-zero rows k=0, k=1, and k=7 included
- growing 3 to 4 buckets over k=1..500 never moves a key anywhere
  but the new bucket, all seven lanes
- 10000 keys over 5 buckets land 2001/1996/2002/2005/1996, exact
  in the six new trees, band 1300..2700 in all seven

#listing("patterns-concurrency-distributed/samples-c/src/Ch12/jump.c", first: 21, last: 30, caption: [C, the ladder with j held in int64_t, a windows long is 32 bits and the rung passes 2^31])

#listing("patterns-concurrency-distributed/samples/ch12/hashing.go", first: 153, last: 160, caption: [Go, the o(log n) ladder, moving only what must move])

#listing("patterns-concurrency-distributed/samples-java/src/Ch12/Jump.java", first: 20, last: 29, caption: [Java, the ladder verbatim over a long key and ieee doubles, the unsigned shift for the high bits, the rung past 2^31 held in a long])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch12/Jump.cs", first: 8, last: 21, caption: [C\#, the float64 ladder over unchecked ulong arithmetic])

#listing("patterns-concurrency-distributed/samples-js/src/ch12-jump.mjs", first: 8, last: 23, caption: [JavaScript, the ladder over limb pairs, the 2^31 division on exact doubles])

#listing("patterns-concurrency-distributed/samples-py/src/Ch12/jump.py", first: 19, last: 26, caption: [Python, python floats are ieee doubles, exactly what the ladder assumes])

#listing("patterns-concurrency-distributed/samples-lua/ch12_jump.lua", first: 11, last: 19, caption: [Lua, the 2147483648.0 division forces the float, tointeger rounds the rung])

The ladder's arithmetic is a portability contract of its own: the
division must be IEEE double in every lane, c's `double`, c\#'s
`double`, java's ieee `double` with the rung held in a `long` for
the same reason c holds `int64_t`, python's float, javascript's
Number, lua forcing the fraction through a 2147483648.0 literal so
the rung stays float, and go the reference. The c lane's `j` is
`int64_t` on purpose, a windows `long` is 32 bits and the rung
routinely passes 2^31, the trap its header comment records for the
corpus. The restrictions
are as real as the elegance: jump hash needs bucket counts to only
grow (one at a time, from 1), cannot remove a bucket without
renumbering everything, and says nothing about node weighting,
which makes it the tool for shard counts inside one deployment,
not for membership across machines.

#diagram([one key as buckets grow: stay, or jump to the new bucket, never sideways], length: 13pt, {
  let x = (c) => 4.0 + c * 2.8
  let y = (b) => 0.9 + b * 0.62
  // the diagonal a move always lands on
  cdraw.line((x(1), y(1)), (x(7), y(7)), stroke: (paint: luma(220), dash: "dashed"))
  // the step path: buckets 1,1,3,3,3,6,6
  let owners = (1, 1, 3, 3, 3, 6, 6)
  for i in range(6) {
    cdraw.line((x(i + 1), y(owners.at(i))), (x(i + 2), y(owners.at(i + 1))), stroke: luma(100))
  }
  for c in range(7) {
    let b = owners.at(c)
    let moved = c >= 1 and owners.at(c) != owners.at(c - 1)
    cdraw.circle((x(c + 1), y(b)), radius: 0.12, fill: if moved { luma(30) } else { luma(160) })
    cdraw.content((x(c + 1), 0.35), [#(c + 1)], size: 6pt)
  }
  cdraw.line((3.0, 0.9), (23.0, 0.9), stroke: luma(100))
  cdraw.content((12.5, -0.2), [bucket count], size: 6pt)
  cdraw.content((10.0, 4.3), [moves land on the new bucket], size: 6pt)
  cdraw.content((x(5), y(3) - 0.8), [stays], size: 6pt)
  cdraw.content((12.5, 5.6), [bucket ids on the vertical, dashed line is bucket = count], size: 6pt)
})

#callout("note", "choosing between them", [
  Fixed shard count, growth by appending shards: jump hash. Dynamic
  membership, weighted nodes, server side: the vnode ring. Small
  cluster list known to clients, no server state wanted: rendezvous.
  All three are placement decisions, none of them replication, which
  stays quorum work from chapter 10.
])

#flow(
  [choosing a placement scheme, replication is none of them],
  node((0, 0), [placement,#linebreak()problem]),
  node((3.1, 1.5), [fixed shard count,#linebreak()append-only growth]),
  node((3.1, 0), [dynamic membership,#linebreak()weighted nodes]),
  node((3.1, -1.5), [small public list,#linebreak()no server state]),
  node((6.2, 1.5), [jump hash]),
  node((6.2, 0), [vnode ring]),
  node((6.2, -1.5), [rendezvous]),
  edge((0, 0), (3.1, 1.5), "-|>"),
  edge((0, 0), (3.1, 0), "-|>"),
  edge((0, 0), (3.1, -1.5), "-|>"),
  edge((3.1, 1.5), (6.2, 1.5), "-|>"),
  edge((3.1, 0), (6.2, 0), "-|>"),
  edge((3.1, -1.5), (6.2, -1.5), "-|>"),
)

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [454], [libc],
  [strcmp tiebreaks, int64_t rung past 2^31, the join built with a real NUL],
  [go], [126], [stdlib],
  [frozen lane pinning movement bands where the siblings pin exact decimals],
  [java], [460], [jdk 27 stdlib],
  [every hash ordering through Long.compareUnsigned, parseUnsignedLong pins, ieee double ladder],
  [c\#], [132], [bcl],
  [CompareOrdinal tiebreaks, the jump ladder over unchecked ulong],
  [javascript], [147], [node stdlib, one sibling module],
  [16-bit limb multiplies, the lower bound by hand, BigInt only in tests],
  [python], [302], [stdlib only],
  [hand-masked multiplies, (hash, node) tuples with bisect_left, float ladder],
  [lua], [397], [lib.lua harness],
  [sign bit xored into sort keys, decimal-string pins, 2147483648.0 ladder],
)

sources: Karger et al., "Consistent Hashing and Random Trees",
STOC 1997, for the ring and its `1/(n+1)` bound, Thaler and
Ravishankar, "Using Name-Based Mappings to Increase Hit Rates",
CSE-TR-356-96, University of Michigan 1996, journal form IEEE/ACM
Transactions on Networking 1998, for the HRW formulation,
Thatcher, "Rendezvous Hashing Explained", for the walkthrough,
Lamping and Veach, "A Fast, Minimal Memory, Consistent Hash
Algorithm", arXiv 1406.2294, for jump hash and its growth rule,
accessed 2026-09-08. Verified by the seven chapter legs: 4 C
programs with 4745 embedded checks, `go test` at 6 tests in
`patternsbook/ch12`, the java runner's 63 checks across 4 programs
in `samples-java/src/Ch12`, 13 xunit facts, node's 10 cases across
4 suites in `test/ch12.test.mjs`, the python runner's 55 checks
across 4 modules, and the lua runner's 17 ch12 rows.
