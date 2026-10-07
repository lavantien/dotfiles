#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= practical structures

The book so far has chased exact answers, and production systems
chase affordable ones. Redis evicts keys from an approximate lru
order, leveldb bolts a bloom filter onto every sstable and keeps its
memtable in a skip list, cdns use one to turn one-hit urls away at
the door. This chapter builds the four structures behind those
moves, each a screen of code with its behavior pinned by tests, and
chapter 43's engine ships 2 of them with the same hash idioms
taught here.

== the bloom filter

A set that may report a stranger as present and never reports a
member as absent. Adding a key sets k bit positions chosen by
hashes, a probe that finds a clear bit answers no for certain, and
a probe that finds all k set answers maybe. The maybe rate is
bought up front with arithmetic, m = -n ln p / (ln 2)^2 bits for
n expected keys at target rate p, then k = m/n ln 2 positions per
key. At n = 10,000 and p = 0.01 that is 95,851 bits, 9.6 per key,
and 7 positions.

The dry run: the fixture is that design point and its probe census,
asserted by the C\# suite, while C and java bound lies at 6 of 40,
go and lua pair fnv-1a with djb2, javascript runs bigint words, and
python's 8-bit arena pins its lies by name, java carrying that
8-bit lane beside its own bounds.

+ Sizing prices the filter first: m = -n ln p / (ln 2)² rounds up
  to 95,851 bits, and k = 95,851 / 10,000 × ln 2 = 6.64, rounded up
  to 7 positions per key.
+ The whole arena costs 95,851 / 8 = 11,982 bytes, just under 12
  kilobytes to screen 10,000 keys.
+ All 10,000 keys added, every member probe answers maybe, the
  no-false-negative assert: bits only ever set.
+ Probing 10,000 absent keys then measures 59 lies, 59 / 10,000 =
  0.59 percent, inside the asserted bound of 200 and under the 1
  percent design.
+ The lies cluster because the 7 positions come from one hash pair,
  never fully independent, so the realized rate rides either side
  of the design point.

#diagram([the absent-probe census as a run, 10,000 strangers each reading 7 positions, 9,941 stopped by a clear bit], length: 13pt, {
  cdraw.rect((4.6, 7.0), (14.0, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((9.3, 7.6), [10,000 absent probes], size: 6.5pt)
  cdraw.line((14.0, 7.6), (15.6, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.8, 8.15), [each reads 7], size: 6pt)
  cdraw.rect((15.6, 7.0), (20.4, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((18.0, 7.6), [7 positions each], size: 6.5pt)
  // the split: one clear bit answers no, all set is the lie
  cdraw.line((17.0, 7.0), (15.4, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.0, 7.0), (20.6, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.2, 5.2), [9,941 hit a clear bit: no], size: 6pt)
  cdraw.rect((19.0, 4.4), (23.6, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((21.3, 5.0), [59 all set: maybe], size: 6pt)
  cdraw.content((4.6, 3.2), [59 / 10,000 = 0.59 percent], size: 6pt)
  cdraw.content((4.6, 2.3), [assert bound: under 200], size: 6pt)
  cdraw.content((4.6, 1.4), [design target: 1 percent], size: 6pt)
  cdraw.content((4.6, 0.5), [members can never read no], size: 6pt)
})

The 59 of 10,000 inside a 95,851-bit arena is the pinned trade, and
the listings below buy it in seven languages.

#listing("dsa/samples-c/src/Ch25/bloom.c", first: 19, last: 61, caption: [c, fnv-1a against djb2, the second mixer chosen so the feeds stay independent])
#listing("dsa/samples-go/ch25/bloom.go", first: 19, last: 47, caption: [go, bit slots by double hashing, h1 and h1 plus h2 into one word array])
#listing("dsa/samples-java/src/Ch25/Bloom.java", first: 25, last: 79, caption: [java, fnv-1a with djb2, every hash mod through `Long.remainderUnsigned`, the offset parsed unsigned])
#listing("dsa/samples/src/Ch25/Practical.cs", first: 12, last: 60, caption: [c\#, sizing in the ctor, kirsch-mitzenmacher probes off one fnv pair, an odd stride])
#listing("dsa/samples-js/src/ch25-bloom.mjs", first: 9, last: 35, caption: [javascript, the 64-bit hashes imported from chapter 6 as bigint])
#listing("dsa/samples-py/src/Ch25/bloom.py", first: 17, last: 34, caption: [python, an 8-bit filter where the false positives pin exactly])
#listing("dsa/samples-lua/ch25_bloom.lua", first: 27, last: 42, caption: [lua, fnv-1a and djb2 over 512 bits, floor modulo with a plus one])

The 2 hashes are one fnv-1a pass with 2 seeds, chapter 6's hash run
twice with the second seed mixing a byte into every round, and the
k positions come from the kirsch-mitzenmacher combination
g_i = h_1 + i h_2, one multiply per probe instead of k separate
hash functions. The tests pin the design point exactly, 95,851 bits
and 7 positions, then add all 10,000 keys and probe each one, and
zero report absent because bits only ever set. Probing 10,000
absent keys measured 59 lies, 0.59 percent, under the 1 percent
target, and that is expected, the k positions drawn from a single
hash pair are never fully independent, so the realized rate can
land on either side of the design. The whole
filter sits in just under 12 kilobytes, and 1 absent lookup in 100
still pays the disk while the other 99 skip it.

The second hash differs per language, and the choice is measurable.
The c listing states the reason in a comment: a re-seeded copy of
one hash family correlates its bit choices and inflates the rate,
so its second feed is djb2 against fnv-1a, false positives bounded
at 6 of 40 probes on 64 bits and 2 of 40 on 256. Go and lua pair
the same two hashes, go combining them double-hash style into h1
and h1 plus h2, lua spreading 64 keys over 512 bits with the bound
at 10 of 64 and a live-bit count pinned strictly between 64 and
128, proving the two feeds really disagree. Java pairs the same two
feeds with the same correlation comment and mirrors C's bounds, 6
of 40 at 64 bits and 2 of 40 at 256, but the road there is its
own: the fnv offset 14695981039346656037 sits past 2^63, so the
constant parses through `Long.parseUnsignedLong` and every modulo
runs through `Long.remainderUnsigned`, signed % disagreeing exactly
where a hash crosses 2^63. Java also mirrors a C quirk frozen in
the fixture: the query array declares 40 slots and fills 39, so
the 40th probe is the empty string, and the java twin hashes that
empty string too. Javascript imports both
64-bit words from chapter 6 and runs them on bigint, dropping back
to number at the modulo. Python shrinks the arena to 8 bits with
key mod 8 and 3 key mod 8 so the lies pin by name, 6, 9, 10, 11,
java carrying that 8-bit lane with the same four names.
One invariant never bends in any of the seven: members always
answer yes, because bits only ever set.

#diagram([one key through the fnv pair into k = 7 positions over a 16 slot toy, the tested filter is 95,851 bits for 10,000 keys, and the absent probe dies on one clear bit], length: 13pt, {
  // key through two seeded hashes into one combination, down into the strip
  let node = (pos, w, body, hot) => {
    cdraw.rect((pos.at(0) - w / 2, pos.at(1) - 0.3), (pos.at(0) + w / 2, pos.at(1) + 0.3), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content(pos, body, size: 6pt)
  }
  cdraw.content((14.0, 8.4), [hashes in, one bit strip out], size: 6.5pt)
  node((2.2, 7.0), 2.0, [key-42], false)
  node((5.4, 7.7), 1.4, [h_1], false)
  node((5.4, 6.3), 1.4, [h_2], false)
  node((9.2, 7.0), 4.6, [g_i = h_1 + i h_2], true)
  let e = (a, b) => cdraw.line(a, b, stroke: luma(100), mark: (end: ">"))
  e((3.2, 7.15), (4.7, 7.6))
  e((3.2, 6.85), (4.7, 6.45))
  e((6.1, 7.55), (6.85, 7.25))
  e((6.1, 6.45), (6.85, 6.75))
  e((9.2, 6.7), (9.2, 5.75))
  cdraw.content((11.0, 6.2), [sets 7 bits], size: 6pt)
  // the strip, 16 toy slots, 7 set
  let hot = (1, 4, 6, 9, 11, 13, 15)
  for i in range(16) {
    let x = 1.0 + i * 1.05
    cdraw.rect((x, 4.8), (x + 1.05, 5.6), fill: if i in hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.525, 5.2), if i in hot { [1] } else { [0] }, size: 6pt)
  }
  // the absent probe, 6 of its 7 positions set, 1 clear
  node((2.2, 2.8), 2.2, [absent-7], false)
  for i in (1, 4, 6, 11, 13, 15) {
    cdraw.line((3.3, 3.05), (1.525 + i * 1.05, 4.75), stroke: (paint: luma(160), dash: "dashed"))
  }
  cdraw.line((3.3, 3.05), (9.925, 4.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.55, 4.95), (10.3, 5.45), stroke: luma(100))
  cdraw.line((9.55, 5.45), (10.3, 4.95), stroke: luma(100))
  cdraw.content((4.5, 1.5), [h_1 and h_2: one fnv pass, 2 seeds], size: 6pt)
  cdraw.content((19.0, 3.5), [6 of 7 positions hit set bits], size: 6pt)
  cdraw.content((19.0, 2.5), [the seventh is clear: no], size: 6pt)
  cdraw.content((19.0, 1.5), [a lie needs all 7 set], size: 6pt)
})

#callout("pitfall", "no deletes in a plain bloom filter", [
  Clearing the k bits of a removed key clears bits that other keys
  still need, which manufactures false negatives, the one answer
  the structure promises never to give. Systems that must delete
  either rebuild the filter from the surviving keys or switch to a
  counting variant.
])

== the count-min sketch

The bloom filter's counting sibling answers how many, roughly. The
sketch is d rows of w counters, an increment adds its count to one
hash chosen cell in every row, and an estimate reads the key's d
cells and returns the smallest. Collisions only ever add, so the
minimum can only overestimate, and the width prices the error, with
w = e over eps counters per row the expected overestimate stays
within eps of the total count streamed so far.

The dry run: the fixture is python's 2 by 4 sketch, pinned cell by
cell because the C\# anchor asserts ranges only, 100 to 102 after a
hundred adds of one key, its 2,048-wide run pricing the error
instead.

+ The four adds land twice each, one cell per row, row 1 by
  h1 = key mod 4 and row 2 by h2 = 2 × key mod 4.
+ Row 1 collides keys 1 and 5 into slot 1, 2 + 1 = 3, and pins
  0, 3, 1, 3.
+ Row 2 piles keys 1, 3, and 5 into slot 2, 2 + 3 + 1 = 6, and pins
  1, 0, 6, 0.
+ Key 1 reads min(3, 6) = 3 against truth 2, and key 5 reads the
  same 3 against truth 1, overestimates both.
+ Keys 2 and 3 read exact, 1 and 3, the unclobbered case, and the
  unadded 4 reads 0.
+ Five more of key 2 accumulate in place and its estimate moves only
  up, to 6.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*key*], [*row 1*], [*row 2*], [*min*], [*truth*]),
  [1], [3], [6], [3], [2],
  [5], [3], [6], [3], [1],
  [3], [3], [6], [3], [3],
  [2], [1], [1], [1], [1],
  [4], [0], [0], [0], [unadded],
)

The 3 against truths 2 and 1 is the pinned overestimate, and the
listings below count in seven languages.

#listing("dsa/samples-c/src/Ch25/countmin.c", first: 24, last: 42, caption: [c, affine hashes picked so the collisions are hand-traceable])
#listing("dsa/samples-go/ch25/countmin.go", first: 7, last: 38, caption: [go, rows injected with hash functions, add and estimate])
#listing("dsa/samples-java/src/Ch25/Countmin.java", first: 22, last: 68, caption: [java, affine hashes sharing a multiplier so the mod-8 collision is hand-traceable, the py width-4 lane in the same file])
#listing("dsa/samples/src/Ch25/Practical.cs", first: 70, last: 105, caption: [c\#, the seed rotates per row so the hashes disagree, the estimate is the row minimum])
#listing("dsa/samples-js/src/ch25-countmin.mjs", first: 9, last: 39, caption: [javascript, rows mixed from the two bigint hashes per depth])
#listing("dsa/samples-py/src/Ch25/countmin.py", first: 16, last: 34, caption: [python, two rows of width 4, both pinned cell by cell])
#listing("dsa/samples-lua/ch25_countmin.lua", first: 39, last: 58, caption: [lua, the two hashes alternating across four rows, total tracked beside])

The seed rotates by row so the d hash functions disagree about where
a key lands, one fnv pass over the same bytes per row. The never
underestimates test streams counts of 1 to 50 over 100 keys into a
width 64 sketch, small enough that collisions are guaranteed, and
every estimate lands at or above the truth while Total reports the
exact sum. The tight test uses the geometry worth remembering,
width 2048 and depth 5: after 100 increments of one key and 7 of
another, the heavy key reads exactly 100 because at least 1 of 5
rows is collision free, and the light key reads 7 the same way.
Five rows of 2,048 long counters is 80 kilobytes to count an
unbounded key space, and the expected inflation on that test stream
is e over 2048 times the total, under 0.15 counts.

Every build bumps one cell per row and reads the row minimum, so
overestimate-only is structural, and the six new suites make the
collisions legible instead of pricing them. C pins a 2 by 8 sketch
whose affine hashes share a multiplier, so key 9, congruent to key
1 mod 8, collides in both rows at once and reads the full 3 against
a truth of 0, and java runs that exact fixture, the same shared
multiplier putting key 9 and key 17 in key 1's cells, with
python's pinned rows in the same file. Python's 2 by 4 sketch pins
both rows cell by cell,
0, 3, 1, 3 and 1, 0, 6, 0, then reads 3 for keys 1 and 5 against
truths 2 and 1. Javascript mixes its two bigint hashes per row,
kirsch-mitzenmacher style, and lua alternates the two hashes across
4 rows of width 16 while tracking the exact total beside the
estimates. Overestimate-only is asserted everywhere: the truth is a
floor, never a ceiling.

#diagram([the sketch as memory, d rows of w counters, the key lands hot in every row, one row eats a stranger, and the row minimum survives], length: 13pt, {
  // 5 rows of 8 shown of 2048, key a hot, stranger b gray, row 2 shared
  cdraw.content((6.0, 8.4), [count-min, depth d, width w], size: 6.5pt)
  cdraw.content((6.0, 7.95), [columns 0 to 6 of 2048], size: 6pt)
  let cell = (x, y, v, fill) => {
    cdraw.rect((x, y), (x + 1.16, y + 0.62), fill: fill, radius: 0.02)
    cdraw.content((x + 0.58, y + 0.31), v, size: 6pt)
  }
  let aCells = ((0, 2), (1, 6), (2, 3), (3, 0), (4, 5))
  let bCells = ((0, 5), (1, 1), (2, 3), (3, 6), (4, 2))
  for r in range(5) {
    let top = 7.5 - r * 0.62
    cdraw.content((1.75, top - 0.31), [#r], size: 6pt)
    for c in range(7) {
      let isA = (r, c) in aCells
      let isB = (r, c) in bCells
      let v = if isA and isB { [107] } else if isA { [100] } else if isB { [7] } else { [0] }
      let fill = if isA and isB { luma(185) } else if isA { luma(205) } else if isB { luma(225) } else { luma(235) }
      cell(2.2 + c * 1.3, top - 0.62, v, fill)
    }
    cdraw.content((11.85, top - 0.31), [...], size: 6pt)
  }
  cdraw.content((18.6, 6.9), [every row counts the key], size: 6pt)
  cdraw.content((18.6, 5.9), [row 2 counts a stranger too: 100 + 7], size: 6pt)
  cdraw.content((18.6, 4.9), [estimate: the smallest, 100], size: 6pt)
  cdraw.content((18.6, 3.9), [never under, only over], size: 6pt)
  cdraw.content((18.6, 2.9), [width 2048, depth 5 in the tests], size: 6pt)
})

== lru and lfu caches

Both caches need 2 constant time operations, lookup and eviction,
and both get them from a dictionary plus a list the dictionary
maintains as a side effect. Lru threads one doubly linked list
through the map, newest first, a get unlinks the node and relinks
it at the front, and a put into a full cache evicts from the back.

The dry run: the fixtures are the three capacity 2 transcripts
asserted by the C\# suite, two lru and one lfu, while the ring
builders in C, go, java, python, and lua replay the evictions and
javascript's ordered map reads its first key.

+ Put a, get a, put b threads the ring b, a front to back, and put
  c evicts the back: a, with count 2, get b at 2, and get c at 3
  pinned after.
+ The second transcript moves the touch later, put a, put b, get a:
  the get unlinks a and relinks it at the front, the ring reads a,
  b, and put c now evicts b.
+ The pins read evicted b, get a at 1, get c at 3, one get
  redirecting the victim.
+ The lfu transcript counts instead: put a, get a, get a leaves a
  at frequency 3, and put b lands at frequency 1.
+ Put c evicts from the lowest bucket, b goes even though it is the
  newer key, and the pins read evicted b with a and c answering.

#table(
  columns: (1.8fr, auto, 1.4fr, auto, 1.4fr),
  inset: 4pt,
  table.header([*transcript*], [*policy*], [*order before*], [*evicts*], [*pins*]),
  [a, get a, b, c], [lru], [b, a], [a], [count 2, b 2, c 3],
  [a, b, get a, c], [lru], [a, b], [b], [a 1, c 3],
  [a, get a, get a, b, c], [lfu], [freq 3: a, freq 1: b], [b], [a 1, c 3],
)

The eviction names a, then b, then b across the transcripts, and
the listings below thread these rings in seven languages.

#listing("dsa/samples-c/src/Ch25/lru.c", first: 40, last: 84, caption: [c, one ring threaded through a fixed slot array, keys 0 to 7])
#listing("dsa/samples-go/ch25/lru.go", first: 26, last: 66, caption: [go, a map for lookup, a sentinel ring for order, both splices inline])
#listing("dsa/samples-java/src/Ch25/Lru.java", first: 41, last: 83, caption: [java, a class node with prev and next, unlink and push front, the sentinel head handing over the victim])
#listing("dsa/samples/src/Ch25/Practical.cs", first: 108, last: 177, caption: [c\#, sentinels at both ends, unlink and relink, the back hands over the victim])

The same c\# file carries the lfu twin. Lfu orders by use count
instead of touch order, 1 bucket per frequency, each bucket itself
recency ordered so ties break the same way lru breaks them, and a
minimum frequency pointer that only moves on insert or when a
bucket empties:

#listing("dsa/samples/src/Ch25/Practical.cs", first: 179, last: 255, caption: [c\#, lanes per bucket, a bump per get, the lane helpers below repeat the lru pair])
#listing("dsa/samples-js/src/ch25-lru.mjs", first: 5, last: 36, caption: [javascript, the insertion-ordered map is the whole cache, refresh by delete and re-set])
#listing("dsa/samples-py/src/Ch25/lru.py", first: 24, last: 59, caption: [python, dict plus ring, evictions recorded as they happen])
#listing("dsa/samples-lua/ch25_lru.lua", first: 14, last: 56, caption: [lua, unlink and push front over a table-keyed ring])

The eviction tests read like transcripts. Capacity 2 with put a,
get a, put b, put c evicts a, because the get left a newer than b.
Capacity 2 with put a, put b, get a, put c evicts b, the get moved
a off the cold end. And put a, get a, get a, put b, put c evicts
b under lfu, a sits at frequency 3 and the frequency 1 bucket
loses its only key. The bcl answer is `MemoryCache`, eviction keyed
to memory pressure instead of a strict count, so treat these as
the machinery a policy sits on top of. Redis ships both policies
for real, allkeys-lru approximated by sampling a few keys and
allkeys-lfu over a decayed counter.

Six of the seven builds share the same shape, a hash map for the
lookup and a doubly linked ring for the order. Javascript is the
exception that proves the map can carry both jobs: its builtin Map
keeps insertion order, so a get refreshes by delete and re-set and
the first key iterator hands over the victim, no ring at all. The
transcripts agree across the ring-builders, touching a saves it and
c evicts b at capacity 2 in c\#, java, python, and lua. C threads
its ring
through a fixed slot array over keys 0 to 7 and pins the longer
eviction sequence 2 then 1, java pinning that same sequence over
heap nodes, python and java add the capacity 1 churn case
and the update that evicts nothing, and go exposes an order dump
that tests read front to back.

#diagram([lru reorders one list on every touch and evicts from the back, lfu moves keys up a bucket per get and evicts the lowest bucket], length: 13pt, {
  // left: 3 lru frames, cap 2. right: 2 lfu frames
  let box = (x, y, v, hot) => {
    cdraw.rect((x - 0.32, y - 0.25), (x + 0.32, y + 0.25), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), v, size: 6pt)
  }
  let xout = (x, y) => {
    cdraw.line((x - 0.22, y - 0.18), (x + 0.22, y + 0.18), stroke: luma(100))
    cdraw.line((x - 0.22, y + 0.18), (x + 0.22, y - 0.18), stroke: luma(100))
  }
  cdraw.content((4.5, 8.45), [lru, one list, newest at the front], size: 6.5pt)
  cdraw.content((4.25, 7.7), [put a, put b], size: 6pt)
  cdraw.content((1.85, 7.1), [front], size: 6pt)
  cdraw.content((6.45, 7.1), [back], size: 6pt)
  box(3.9, 7.1, [b], true)
  box(4.8, 7.1, [a], false)
  cdraw.content((4.25, 6.3), [get a], size: 6pt)
  box(3.9, 5.6, [a], true)
  box(4.8, 5.6, [b], false)
  cdraw.line((2.6, 6.75), (2.6, 6.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.8, 6.8), (4.0, 5.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.25, 4.6), [put c], size: 6pt)
  box(3.9, 4.0, [c], true)
  box(4.8, 4.0, [a], false)
  box(6.5, 4.0, [b], false)
  xout(6.5, 4.0)
  cdraw.content((8.6, 4.0), [evicted], size: 6pt)
  cdraw.line((2.6, 5.25), (2.6, 4.55), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.25, 2.9), [a get unlinks and relinks, O(1)], size: 6pt)
  cdraw.content((4.25, 1.9), [the back hands over the eviction], size: 6pt)

  cdraw.content((17.5, 8.45), [lfu, buckets by use count], size: 6.5pt)
  cdraw.content((17.5, 7.7), [put a, get a, get a, put b], size: 6pt)
  cdraw.content((14.5, 7.1), [freq 3], size: 6pt)
  box(15.6, 7.1, [a], true)
  cdraw.content((18.7, 7.1), [freq 1], size: 6pt)
  box(19.8, 7.1, [b], false)
  cdraw.content((17.5, 6.3), [put c, bucket 1 evicts b], size: 6pt)
  cdraw.content((14.5, 5.6), [freq 3], size: 6pt)
  box(15.6, 5.6, [a], true)
  cdraw.content((18.7, 5.6), [freq 1], size: 6pt)
  box(19.8, 5.6, [c], true)
  cdraw.line((13.6, 6.75), (13.6, 6.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.5, 3.9), [a get bumps the key one bucket up], size: 6pt)
  cdraw.content((17.5, 2.9), [a fresh put lands in bucket 1], size: 6pt)
  cdraw.content((17.5, 1.9), [eviction reads the lowest bucket], size: 6pt)
})

== the skip list

Chapter 7's avl tree keeps a sorted set balanced with rotations, a
deterministic guarantee. The skip list buys the same expected
log n search with coin flips. Every insert builds a tower, the
generator advances once per promotion at p = 1/2, so half the keys
reach level 2, a quarter reach level 3, and lane widths halve as
they rise. A search starts on the tallest lane and moves right
while the next key is smaller, dropping a lane on every overshoot,
and it never backtracks.

The dry run: the fixture is the seeded census, a thousand shuffled
keys, 4,096 towers, and 1,024 searches, asserted by the C\# suite,
while the deterministic siblings state their promotion policies, go,
java, and python pinning the ruler ladder 1, 2, 1, 3, 1, 2, 1, 4.

+ A thousand keys arrive shuffled and lane 0 enumerates them 0
  through 999 sorted, one walk down the bottom lane.
+ Contains answers true for all 1,000 members and false for the 100
  probes at 1,000 and up.
+ Of 4,096 towers 2,041 reach level 2, 2,041 / 4,096 = 0.498,
  inside the asserted band 0.45 to 0.55 around the expected half.
+ The remaining 4,096 - 2,041 = 2,055 stop at level 1, the lane
  widths halving as they rise.
+ Searching all 1,024 members costs a mean of 16.0 comparisons,
  under the asserted bound 2 log2 1,024 = 20.
+ The ruler ladder pins the deterministic side: the first eight
  inserts rise to 1, 2, 1, 3, 1, 2, 1, 4.

#diagram([the two pinned statistics, the tower census against the expected half and the search mean under its bound], length: 13pt, {
  // left: census bars, axis zoomed to 1,800..2,200, asserted band shaded
  let y = v => 0.9 + (v - 1800) / 400 * 3.0
  cdraw.rect((1.6, y(1843)), (5.4, y(2200)), fill: luma(240), stroke: none)
  cdraw.content((3.4, 5.4), [towers of 4,096], size: 6.5pt)
  cdraw.rect((2.2, 0.9), (3.3, y(2055)), fill: luma(235), radius: 0.02)
  cdraw.content((2.75, y(2055) + 0.3), [2,055], size: 6pt)
  cdraw.rect((3.7, 0.9), (4.8, y(2041)), fill: luma(205), radius: 0.02)
  cdraw.content((4.25, y(2041) + 0.3), [2,041], size: 6pt)
  cdraw.line((1.6, y(2048)), (5.4, y(2048)), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.content((5.7, y(2048)), [expected half], size: 6pt, anchor: "west")
  cdraw.content((2.2, 0.2), [stop at 1], size: 6pt)
  cdraw.content((3.7, 0.2), [reach 2], size: 6pt)
  cdraw.content((1.2, 4.6), [band], size: 6pt)
  cdraw.content((1.2, 4.2), [0.45], size: 6pt)
  cdraw.content((1.2, 1.3), [0.55], size: 6pt)
  // right: the search mean against the 2 log2 n bound
  let m = v => 13.6 + v / 20 * 5.4
  cdraw.content((16.0, 5.4), [mean comparisons, n = 1,024], size: 6.5pt)
  cdraw.line((m(0), 3.4), (m(20.6), 3.4), stroke: luma(120), mark: (end: ">"))
  for v in (0, 5, 10, 15, 20) {
    cdraw.line((m(v), 3.28), (m(v), 3.52), stroke: luma(120))
    cdraw.content((m(v), 2.85), [#v], size: 6pt)
  }
  cdraw.circle((m(16.0), 4.1), radius: 0.16, fill: luma(205))
  cdraw.line((m(16.0), 3.95), (m(16.0), 3.52), stroke: luma(100))
  cdraw.content((m(16.0), 4.55), [16.0 measured], size: 6pt)
  cdraw.line((m(20), 3.28), (m(20), 4.3), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.content((m(20), 4.55), [20 = 2 log2 n], size: 6pt)
  cdraw.content((13.6, 1.8), [probabilistic balance for the], size: 6pt)
  cdraw.content((13.6, 1.2), [avl's deterministic one], size: 6pt)
})

The 0.498 against the half and the 16.0 under 20 are the pinned
statistics, and the listings below flip these coins in seven
languages.

#listing("dsa/samples-c/src/Ch25/skiplist.c", first: 32, last: 83, caption: [c, the ruler promotion, splice points collected on the way down])
#listing("dsa/samples-go/ch25/skiplist.go", first: 25, last: 49, caption: [go, promotion by trailing zeros of the insertion index, math slash bits])
#listing("dsa/samples-java/src/Ch25/Skiplist.java", first: 34, last: 83, caption: [java, the ruler policy, find dropping a lane on overshoot, insert collecting its splice points on the descent])
#listing("dsa/samples/src/Ch25/Practical.cs", first: 284, last: 362, caption: [c\#, the descent collects splice points, contains drops a lane on overshoot])

#listing("dsa/samples/src/Ch25/Practical.cs", first: 364, last: 399, caption: [c\#, lane widths by count, sorted enumeration, one fresh flip per promotion])
#listing("dsa/samples-js/src/ch25-skiplist.mjs", first: 14, last: 54, caption: [javascript, the tower is 1 plus trailing zeros of the key's fnv hash])
#listing("dsa/samples-py/src/Ch25/skiplist.py", first: 17, last: 50, caption: [python, the ruler sequence drives promotion, splice per level])
#listing("dsa/samples-lua/ch25_skiplist.lua", first: 9, last: 42, caption: [lua, promotion as a pure function of the value, divisibility by 4, 8, 16])

The tests pin the statistics. One thousand inserts in shuffled
order enumerate sorted and answer Contains for every member while
missing 100 absent probes. Of 4,096 towers, 2,041 reach level 2,
0.498 against the expected one half. And searching all 1,024
members of a seeded list takes a mean of 16.0 comparisons, under
the 2 log2 n bound of 20, the probabilistic balance the avl gets
deterministically. LevelDB's memtable and redis sorted sets are
this list in production.

The other six builds are deterministic, and each states its
promotion policy out loud. Go, java, python, and c use the ruler
sequence, the i-th insert rises to 1 plus the trailing zeros of i,
and go, java, and python all pin the height ladder 1, 2, 1, 3, 1,
2, 1,
4 while python and java read tower heights per value off a map,
java also dumping whole lanes, lane 1 skipping the odds and lane 3
holding only the tallest key.
Javascript hashes the key itself and counts trailing zero bits of
the 64-bit word, so towers depend on the data rather than the
insertion order, and lua makes promotion a pure function of
divisibility, level 2 exactly when the value is divisible by 4,
capped at 16. Whatever the policy, the search spine is identical
in all seven: descend from the top lane, walk right while smaller,
drop a lane on every overshoot, never backtrack.

#callout("pitfall", "one coin per promotion, not one per tower", [
  A tower generator that draws a single random value and tests it
  in a loop produces heights of exactly 1 or the maximum, half and
  half. Sortedness still holds and small tests still pass, but the
  top lane holds every second key and search degrades toward
  scanning half the list. The generator must advance between
  promotions, the measured 16.0 above depends on it.
])

#diagram([towers from coin flips over 5 keys, the shaded search rides the tall lanes and drops where a lane overshoots, never backtracking], length: 13pt, {
  // head plus 5 keys, heights 4 1 3 1 2 4, search 33 shaded
  let laneY = (l) => 5.65 + (l - 1) * 0.75
  let xs = (2.0, 5.5, 9.0, 12.5, 16.0, 19.5)
  let vals = ([head], [12], [18], [25], [33], [47])
  let heights = (4, 1, 3, 1, 2, 4)
  for (i, h) in heights.enumerate() {
    for l in range(1, h + 1) {
      cdraw.rect((xs.at(i) - 0.45, laneY(l) - 0.25), (xs.at(i) + 0.45, laneY(l) + 0.25), fill: if i == 4 { luma(205) } else { luma(235) }, radius: 0.02)
    }
    cdraw.content((xs.at(i), 4.85), vals.at(i), size: 6pt)
  }
  let lane = (l, a, b, stroke) => cdraw.line(a, b, stroke: stroke, mark: (end: ">"))
  // every lane, thin
  for (x1, x2) in ((2.0, 5.5), (5.5, 9.0), (9.0, 12.5), (12.5, 16.0), (16.0, 19.5)) {
    lane(1, (x1 + 0.45, laneY(1)), (x2 - 0.45, laneY(1)), luma(215))
  }
  for (x1, x2) in ((2.0, 9.0), (9.0, 16.0), (16.0, 19.5)) {
    lane(2, (x1 + 0.45, laneY(2)), (x2 - 0.45, laneY(2)), luma(215))
  }
  for (x1, x2) in ((2.0, 9.0), (9.0, 19.5)) {
    lane(3, (x1 + 0.45, laneY(3)), (x2 - 0.45, laneY(3)), luma(215))
  }
  lane(4, (2.45, laneY(4)), (19.05, laneY(4)), luma(215))
  // the search for 33, dark: ride, probe, drop
  cdraw.line((2.45, laneY(4)), (19.05, laneY(4)), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.line((2.0, 7.65), (2.0, 7.4), stroke: luma(60), mark: (end: ">"))
  lane(3, (2.45, laneY(3)), (8.55, laneY(3)), luma(60) + 0.6pt)
  cdraw.line((9.45, laneY(3)), (19.05, laneY(3)), stroke: (paint: luma(60), dash: "dashed"))
  cdraw.line((9.0, 6.9), (9.0, 6.65), stroke: luma(60), mark: (end: ">"))
  lane(2, (9.45, laneY(2)), (15.55, laneY(2)), luma(60) + 0.6pt)
  cdraw.content((1.1, laneY(4)), [4], size: 6pt)
  cdraw.content((1.1, laneY(3)), [3], size: 6pt)
  cdraw.content((1.1, laneY(2)), [2], size: 6pt)
  cdraw.content((1.1, laneY(1)), [1], size: 6pt)
  cdraw.content((1.1, 4.3), [lane], size: 6pt)
  cdraw.content((11.0, 3.6), [search 33: 4 comparisons, hit on lane 2], size: 6pt)
  cdraw.content((11.0, 2.6), [each promotion halves the lane: 1/2, 1/4, 1/8], size: 6pt)
  cdraw.content((11.0, 1.6), [dashed probes overshoot and drop a lane], size: 6pt)
  cdraw.content((11.0, 0.7), [expected 2 log2 n, measured 16.0 at n = 1024], size: 6pt)
})

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's four sample files, the c\# file also carrying the lfu
cache section above, which has no matrix twin in the other six:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [384], [byte bit arrays, slot-backed ring], [djb2 second hash with the correlation comment, bounded lie counts],
  [c\#], [341], [`Dictionary<TKey,TValue>`, `List<T>`], [the only coin-flip skiplist, kirsch-mitzenmacher k of 7, lfu included],
  [go], [204], [`map[string]*lruNode`, slices], [double-hash bloom slots, promotion by insertion index],
  [java], [518], [jdk 27 stdlib], [fnv offset parsed unsigned, every hash mod through `Long.remainderUnsigned`, the c fixture's empty 40th probe mirrored, both count-min fixtures in one file],
  [javascript], [125], [`Map` in insertion order, `Set`], [bigint hash words, the map doubles as the lru ring],
  [python], [229], [`dict`, list of bools], [8-bit bloom with lies pinned by name, ruler promotion],
  [lua], [338], [`table` with string splice-free keys], [fnv offset built from a hex literal, divisibility promotion],
)

sources: learn.microsoft.com, `Dictionary<TKey,TValue>` under both
caches, `SortedSet<T>` filling the ordered set role in the bcl,
go.dev for `math/bits.TrailingZeros`, developer.mozilla.org for the
insertion-ordered `Map` and bigint operators, docs.python.org for
`__slots__`, lua.org for `math.maxinteger` and floor modulo,
accessed 2026-09-12 and 2026-09-14. Sample behavior verified by
the seven suite gates scoped to chapter 25: c 4 files and 89
checks, c\# 11 tests, go 12 tests, java 4 files and 98 checks,
javascript 10 tests, python 4 files and
36 asserts, lua 16 checks, zero skipped.
