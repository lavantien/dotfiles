#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= hashing

The hash table is the structure the language leans on hardest:
`Dictionary<K,V>` backs half of ordinary code. This chapter builds the
two families from scratch, open addressing and chaining, around a
visible hash function, and prices the trade each one makes.

== the hash function

FNV-1a is small enough to hold in your head and good enough to build
on: xor the byte into the accumulator, multiply by the prime, repeat.
The constants are definitional, the offset basis and the 1099511628211
prime. C carries both families, FNV-1a and djb2, in 24 lines.

The dry run: the fixtures are the reference vectors and the spread
check, asserted by the C\# suite, and the djb2 ladder with its
arithmetic spelled out, asserted by the C, Java, and JavaScript
suites; all seven languages pin the same digests.

+ The empty string hashes to the offset basis itself, cbf29ce484222325,
  "a" to af63dc4c8601ec8c, "foobar" to 85944171f73967e8.
+ djb2 over "a" is one step: 5381 × 33 + 97 = 177670.
+ "ab" folds b in, 177670 × 33 + 98 = 5863208, and "abc" one more,
  5863208 × 33 + 99 = 193485963.
+ The spread check: 1000 sequential int keys over 64 buckets, mean
  1000 / 64 = 15.625, and no bucket reaches twice that, 31.25.
+ FNV-1a wraps its accumulator mod 2^64 at every multiply, which is
  why JavaScript runs it on BigInt while Java's long wraps exactly
  like C's unsigned long long, and djb2 stays small at these lengths
  and needs no ring yet.

#diagram([the djb2 ladder over a, ab, abc: one multiply-add per folded byte, every value pinned by the suites], length: 13pt, {
  let vals = ("5381", "177670", "5863208", "193485963")
  let folds = ("a", "b", "c")
  for (i, v) in vals.enumerate() {
    let x = 0.6 + i * 5.2
    cdraw.rect((x, 3.4), (x + 3.0, 4.3), fill: if i > 0 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.5, 3.85), [#v], size: 6pt)
    if i < 3 {
      cdraw.line((x + 3.15, 3.85), (x + 5.05, 3.85), stroke: luma(100), mark: (end: ">"))
      cdraw.content((x + 4.1, 4.75), [× 33 + #(97 + i)], size: 6pt)
      cdraw.content((x + 4.1, 3.0), [fold #folds.at(i)], size: 6pt)
    }
  }
  cdraw.content((2.1, 5.3), [the seed], size: 6pt)
  cdraw.content((17.7, 5.3), [pinned three steps up], size: 6pt)
  cdraw.content((10.5, 1.8), [fnv-1a: the same loop shape, xor then multiply, wrapping mod 2^64], size: 6pt)
  cdraw.content((10.5, 0.9), [its three vectors pin in all seven suites], size: 6pt)
})

The three vectors and the three ladder values are pinned, and the
listings below hash in seven languages.

#listing("dsa/samples-c/src/Ch06/fnv.c", first: 17, last: 40, caption: [c, fnv-1a, the incremental update, and djb2])

#listing("dsa/samples-go/ch06/fnv.go", first: 14, last: 31, caption: [go, fnv-1a and djb2 over native uint64])

The other five languages pin the same digests:

#listing("dsa/samples-java/src/Ch06/Fnv.java", first: 21, last: 47, caption: [java, the basis rides parseUnsignedLong, fnv-1a, the incremental update, djb2])

The C\# class is generic over the input shape:

#listing("dsa/samples/src/Ch06/Hashing.cs", first: 4, last: 32, caption: [c\#, fnv 1a over bytes, strings, and fixed width ints])

The int overload hashes the four little endian bytes of the value,
which is how binary keys must be handled, hash the bytes not the
decimal spelling. The test pins the published reference vectors, the
empty string hashes to the offset basis itself, and checks the
spread: 1000 sequential ints into 64 buckets with no bucket beyond
twice the mean.

#listing("dsa/samples-js/src/ch06-fnv.mjs", first: 7, last: 18, caption: [javascript, fnv-1a on BigInt with a 64-bit ring])

#listing("dsa/samples-py/src/Ch06/fnv.py", first: 18, last: 36, caption: [python, fnv-1a with an explicit 64-bit mask, djb2 beside it])

#listing("dsa/samples-lua/ch06_fnv.lua", first: 8, last: 34, caption: [lua, a hex parser feeding the wrapped accumulator])

The reference vectors hold in all seven: the empty string hashes to
the offset basis, "a" to af63dc4c8601ec8c, "foobar" to
85944171f73967e8, and djb2 climbs 5381, 177670, 5863208, 193485963.
How each language survives the multiply is the real story. C's
unsigned long long wraps silently and the vectors fit anyway. Go's
uint64 multiply is native. Java's long multiplies wrap mod 2^64 the
same way, and only the decimal offset basis 14695981039346656037
exceeds `Long.MAX_VALUE`, so it rides `Long.parseUnsignedLong` in and
`Long.toUnsignedString` back out, the suite's one unsigned-law site,
no ordering of two hashes ever needs `compareUnsigned`. Python masks
with `(1 << 64) - 1` after every step. Lua's integers are
signed 64-bit, so the pinned values arrive through a hex parser and
foobar reads negative once its top bit sets. JavaScript is where
Number stops: past 2^53 the double loses low bits, so fnv runs on
BigInt with `asUintN(64)` as the ring, the first appearance of a
boundary chapter 16 returns to.

#diagram([fnv 1a, xor the byte, multiply by the prime, offset basis in, 64 bit digest out], length: 13pt, {
  let box = (x0, x1, y0, y1, t) => {
    cdraw.rect((x0, y0), (x1, y1), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, (y0 + y1) / 2), t, size: 6pt)
  }
  // two byte sources feed one loop: strings, and fixed width ints
  box(0.6, 4.2, 6.0, 6.9, [key "cat"])
  cdraw.line((4.2, 6.45), (4.9, 6.45), stroke: luma(100), mark: (end: ">"))
  box(4.9, 10.9, 6.0, 6.9, [bytes 63 61 74])
  cdraw.line((10.9, 6.45), (12.6, 6.45), stroke: luma(100), mark: (end: ">"))
  box(0.6, 3.6, 3.7, 4.6, [int key])
  cdraw.line((3.6, 4.15), (4.3, 4.15), stroke: luma(100), mark: (end: ">"))
  box(4.3, 12.0, 3.7, 4.6, [little endian bytes])
  cdraw.line((12.0, 4.15), (12.6, 4.15), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.2, 3.0), [same loop], size: 6pt)
  // the loop body, then its two definitional constants underneath
  cdraw.rect((12.6, 3.4), (18.2, 7.0), fill: luma(205), radius: 0.02)
  cdraw.content((15.4, 6.5), [per byte:], size: 6pt)
  cdraw.content((15.4, 5.4), [acc ^= byte], size: 6pt)
  cdraw.content((15.4, 4.3), [acc \*= prime], size: 6pt)
  cdraw.content((15.4, 2.8), [offset basis in], size: 6pt)
  cdraw.content((15.4, 1.7), [prime 1099511628211], size: 6pt)
  cdraw.line((18.2, 5.55), (18.9, 5.55), stroke: luma(100), mark: (end: ">"))
  box(18.9, 23.3, 5.1, 6.0, [64-bit digest])
  cdraw.content((10.5, 0.5), [hash the bytes, not the decimal spelling], size: 6.5pt)
})

#callout("note", "what object.GetHashCode gives you", [
  The runtime hash for strings is randomized per process,
  `BitConverter.ToString` of it differs between runs, which protects
  against hash flooding and means you must never persist it. Ints
  hash to themselves, so sequential int keys collide only modulo
  capacity, exactly what the probe tests below exercise. A
  production table under adversarial keys needs a keyed hash,
  .NET's `System.IO.Hashing.XxHash3` for speed or an SipHash style
  for resistance.
])

== open addressing

One array, entries live in it, collisions walk to the next slot.
The linear probe is the simplest walk, and the table counts every
probe so the cost claims stay testable. C keeps the two anchored
pieces small, the rehash that purges tombstones and the probe-counted
get.

The dry run: the fixture is the djb2 keys "a" through "i" over a
capacity 8 table, traced by the C, Java, JavaScript, and Lua suites;
C\# counts probes over 4096 int keys instead and Python walks
ordinals.

+ djb2 of one character is 5381 × 33 + code, so "a" hashes to
  177670, and mod 8 the seven keys home to 6, 7, 0, 1, 2, 3, 4: one
  probe each, no collision yet.
+ The seventh insert crosses the load line, used 7 > 8 × 3 / 4 = 6,
  and the rehash doubles the table to 16 slots.
+ Homes mod 16 shift to 6 through 12: the block re-lands contiguous,
  still one probe per key.
+ Deleting "b" parks a tombstone at slot 7, and proving "b" absent
  walks the whole block, 7 probes, to the empty slot 13.
+ "h" homes to 13 and "i" to 14, one probe each, and every survivor
  still answers.

#diagram([the table at both sizes: the block already wrapped at capacity 8, then rebased to 6 through 12 at 16 with the tombstone and the absence walk], length: 13pt, {
  let slots8 = ("c", "d", "e", "f", "g", none, "a", "b")
  cdraw.content((0.7, 5.9), [capacity 8], size: 6.5pt)
  for i in range(8) {
    let x = 2.6 + i * 1.15
    let v = slots8.at(i)
    if v == none {
      cdraw.rect((x, 5.0), (x + 1.1, 5.8), fill: none, stroke: luma(160), radius: 0.02)
    } else {
      cdraw.rect((x, 5.0), (x + 1.1, 5.8), fill: luma(205), radius: 0.02)
      cdraw.content((x + 0.55, 5.4), [#v], size: 6pt)
    }
    cdraw.content((x + 0.55, 4.6), [#i], size: 6pt)
  }
  cdraw.content((12.6, 5.4), [the block wraps: a b at 6 7], size: 6pt)
  let slots16 = (none, none, none, none, none, none, "a", "b", "c", "d", "e", "f", "g", "h", "i", none)
  cdraw.content((0.7, 2.4), [capacity 16], size: 6.5pt)
  for i in range(16) {
    let x = 2.6 + i * 1.15
    let v = slots16.at(i)
    if v == none {
      cdraw.rect((x, 1.5), (x + 1.1, 2.3), fill: none, stroke: luma(160), radius: 0.02)
    } else if v == "b" {
      cdraw.rect((x, 1.5), (x + 1.1, 2.3), fill: luma(215), radius: 0.02)
      cdraw.content((x + 0.55, 1.9), [#sym.dagger], size: 6pt)
    } else {
      cdraw.rect((x, 1.5), (x + 1.1, 2.3), fill: luma(205), radius: 0.02)
      cdraw.content((x + 0.55, 1.9), [#v], size: 6pt)
    }
    cdraw.content((x + 0.55, 1.1), [#i], size: 6pt)
  }
  cdraw.line((2.6 + 7 * 1.15 + 0.55, 0.72), (2.6 + 13 * 1.15 + 0.55, 0.72), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.2, 0.2), [absence of b: 7 probes to slot 13], size: 6pt)
})

The 7 probe absence walk behind the tombstone is the pin that keeps
deletion honest, and the listings below build the table in seven
languages.

#listing("dsa/samples-c/src/Ch06/openaddr.c", first: 61, last: 92, caption: [c, the rehash rebases live keys, get counts its probes])

#listing("dsa/samples-go/ch06/openaddr.go", first: 61, last: 90, caption: [go, put reuses the first tombstone and rehashes at three quarters])

The other five builders, Java handing the probe count back inside a
lookup record:

#listing("dsa/samples-java/src/Ch06/Openaddr.java", first: 53, last: 85, caption: [java, the rehash rebases live keys, the lookup record carrying probes and slot])

#listing("dsa/samples/src/Ch06/Hashing.cs", first: 34, last: 112, caption: [c\#, linear probing with states, probe counting, the finder])

Deletion is the subtle part. Emptying a slot would break the probe
chain of anything inserted past it, so removal writes a tombstone, a
dead marker the finder walks through but the inserter reuses. The
test kills a middle key and checks both neighbors stay reachable.
Load is kept under 0.7 counting tombstones, because probe cost
climbs steeply as the table fills, and the rehash rebuilds from live
entries only, so tombstones vanish on resize:

#listing("dsa/samples/src/Ch06/Hashing.cs", first: 113, last: 148, caption: [insert with load check, rehash purges tombstones])

The probe meter backs the constant-time claim with a number: 4096
sequential int keys at 0.7 load average under 10 probes per
operation in the test, far from the worst case and stable. The
runtime `Dictionary` works differently: separate chaining, an int
bucket array holding the first index of a chain threaded through
one flat entries array by `next` links, bucket picked by a modulo
of the hash, no probe walk anywhere in its source. Open addressing
here is the deliberate choice, a table whose collision cost is
countable.

Three more builders:

#listing("dsa/samples-js/src/ch06-openaddr.mjs", first: 89, last: 110, caption: [javascript, put with tombstone reuse and the load check])

#listing("dsa/samples-py/src/Ch06/openaddr.py", first: 28, last: 48, caption: [python, put counts its own probes through tombstones])

#listing("dsa/samples-lua/ch06_openaddr.lua", first: 52, last: 69, caption: [lua, put over string states, rehash past three quarters])

C, Java, JavaScript, and Lua trace the same fixture: djb2 lands "a"
through "g" in one contiguous block, every insert costs one probe,
the seventh crosses the load line and rehashes to 16 slots, the block
re-lands at slots 6 through 12, deleting "b" leaves a tombstone that
costs 7 probes to prove absence, and "h" and "i" settle one past the
block at 13 and 14. Python homes by ordinal sum and pins its own
walks, "i" resting at slot 4 after four probes, a tombstone recycled
by the next put, the 6-in-8 edge doubling to 16. Go injects the hash
so its tests can force collisions, and masks instead of dividing.
C\# counts every probe across the run, 4096 int keys averaging under
10 probes per operation at 0.7 load.

== separate chaining

Buckets of linked nodes instead of walking the array. Deletion is
trivial, no tombstones exist, and the worst case is a bucket that
grew long rather than a table-wide stall. C appends at the bucket
tail and counts compares on the walk.

The dry run: the fixture is the crafted key set "a" through "i",
traced by the C, Java, JavaScript, and Lua suites; C\# reads the chain
gauge over 102 keys plus the adversarial constant hash, and Python
buckets by key length.

+ djb2 mod 8 sends "a" through "h" to 6, 7, 0, 1, 2, 3, 4, 5, and
  "i" wraps back to 6, behind "a".
+ Nine puts leave the bucket lengths reading 1 1 1 1 1 1 2 1: one
  bucket of two, none empty.
+ The walk to "i" compares two nodes, "a" first, against one compare
  for "a" itself.
+ Deleting the chain head "a" unsplices locally: bucket 6 holds "i"
  alone and the walk drops to one compare.
+ The C\# gauge holds the longest chain at or under 8 over 102 keys,
  and the constant-hash keys collapse into one chain of 5, correct
  but linear.

#diagram([the nine keys over eight buckets, "i" chaining behind "a" at bucket 6, and the head delete dropping the walk], length: 13pt, {
  let keys = ("c", "d", "e", "f", "g", "h", none, "b")
  for b in range(8) {
    let x = 0.8 + b * 2.65
    cdraw.rect((x, 5.4), (x + 2.0, 6.1), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.0, 5.75), [#b], size: 6pt)
    let chain = if b == 6 { ("a", "i") } else { (keys.at(b),) }
    for (j, k) in chain.enumerate() {
      let y = 4.4 - j * 0.9
      cdraw.rect((x + 0.1, y), (x + 1.9, y + 0.7), fill: luma(205), radius: 0.02)
      cdraw.content((x + 1.0, y + 0.35), [#k], size: 6pt)
      cdraw.line((x + 1.0, y + 0.7), (x + 1.0, y + 0.9), stroke: luma(100))
    }
    cdraw.line((x + 1.0, 5.4), (x + 1.0, 5.3), stroke: luma(100))
  }
  cdraw.content((4.0, 1.6), [bucket 6: a then i, get i costs 2 compares], size: 6pt)
  cdraw.rect((0.8, 0.2), (2.8, 0.9), fill: luma(235), radius: 0.02)
  cdraw.content((1.8, 0.55), [6], size: 6pt)
  cdraw.rect((0.9, -0.7), (2.7, 0.0), fill: luma(205), radius: 0.02)
  cdraw.content((1.8, -0.35), [i], size: 6pt)
  cdraw.line((1.8, 0.0), (1.8, 0.2), stroke: luma(100))
  cdraw.content((4.0, -0.35), [after delete a: one compare], size: 6pt)
})

The length vector and the two-into-one compare drop are pinned, and
the listings below chain in seven languages.

#listing("dsa/samples-c/src/Ch06/chainmap.c", first: 50, last: 77, caption: [c, tail append, the compare-counted get])

#listing("dsa/samples-go/ch06/chainmap.go", first: 27, last: 36, caption: [go, chains as slices, overwrite in place])

The same interface in the other five languages, Java's get returning
the compare count, negative on a miss:

#listing("dsa/samples-java/src/Ch06/Chainmap.java", first: 44, last: 72, caption: [java, tail append over pooled nodes, the get that returns the compare count])

#listing("dsa/samples/src/Ch06/Hashing.cs", first: 150, last: 245, caption: [c\#, chaining with longest chain stat, resize at load 1])

The `LongestChain` property is the health gauge, the test inserts
102 keys and asserts no chain passed 8. The adversarial test goes
further: a key type whose `GetHashCode` returns a constant forces
every key into one chain, correctness survives, five keys, chain of
five, and the structure degrades into an unsorted list. That is the
hash table's contract: average constant, worst case linear, and the
worst case is one bad hash away.

#listing("dsa/samples-js/src/ch06-chainmap.mjs", first: 16, last: 29, caption: [javascript, array chains with a compare-counted get])

#listing("dsa/samples-py/src/Ch06/chainmap.py", first: 13, last: 32, caption: [python, bucket by key length, the honest worst case on display])

#listing("dsa/samples-lua/ch06_chainmap.lua", first: 25, last: 38, caption: [lua, tail append and the counted walk])

C, Java, JavaScript, and Lua share the crafted key set, "a" through
"i", whose djb2 values are consecutive mod 8, so "i" chains behind
"a" in bucket 6, the length vector reads 1 1 1 1 1 1 2 1, and
deleting the chain head drops "i" from two compares to one. Python
hashes by key length, pins cat and dog sharing bucket 3 against bird
alone, then piles four five-letter keys into one bucket and watches
every lookup still answer. Go keeps buckets as slices and reports the
maximum chain. C\# carries the adversarial case the others skip, a
constant `GetHashCode` forcing one chain of five.

#diagram([the two collision families, walk the array or hang a chain], length: 13pt, {
  // left: open addressing, one array, collisions probe forward
  cdraw.content((6.4, 7.0), [open addressing], size: 7pt)
  let occ = (none, none, "x", "y", "k", none, "dagger", none)
  for i in range(8) {
    let f = if i == 6 { luma(215) } else { luma(235) }
    cdraw.rect((i * 1.6, 4.6), (i * 1.6 + 1.6, 5.6), fill: f, radius: 0.02)
    if i == 6 { cdraw.content((i * 1.6 + 0.8, 5.1), [#sym.dagger], size: 7pt) }
    else if occ.at(i) != none { cdraw.content((i * 1.6 + 0.8, 5.1), [#occ.at(i)], size: 6pt) }
  }
  cdraw.content((4.0, 3.7), [h(k) = 2, occupied], size: 6.5pt)
  cdraw.line((4.0, 3.95), (4.0, 4.5))
  cdraw.line((4.0, 6.0), (7.2, 6.0))
  cdraw.content((5.6, 6.3), [probe 2, 3, place at 4], size: 6pt)
  cdraw.content((6.4, 2.9), [the dagger at slot 6 is a tombstone, reused on insert], size: 6.5pt)

  // right: separate chaining, buckets of linked nodes
  cdraw.content((17.4, 7.0), [separate chaining], size: 7pt)
  for i in range(4) {
    cdraw.rect((13.0 + i * 1.7, 4.6), (13.0 + (i + 1) * 1.7, 5.6), fill: luma(235), radius: 0.02)
    cdraw.content((13.85 + i * 1.7, 5.1), [#i], size: 6pt)
  }
  let chain(y, t) = {
    cdraw.rect((15.25, y), (19.25, y + 0.8), fill: luma(245), stroke: luma(120), radius: 0.05)
    cdraw.content((17.25, y + 0.4), [#t], size: 6pt)
  }
  chain(3.4, "k1"); chain(2.0, "k2"); chain(0.6, "k3")
  cdraw.line((17.25, 4.6), (17.25, 4.2)); cdraw.line((17.25, 3.4), (17.25, 2.8)); cdraw.line((17.25, 2.0), (17.25, 1.4))
  cdraw.content((17.4, -0.2), [bucket 2 grew a chain, three keys, no tombstones], size: 6.5pt)
})

#callout("warning", "the contract on the key", [
  A mutable key that changes after insertion is lost, its bucket is
  where the old hash says, not the new one. .NET documents this for
  `Dictionary`: do not mutate a key while it is in the table. The
  pairing rule is equally binding, equal keys must return equal
  hashes, so `Equals` and `GetHashCode` must be overridden together
  or never, which is why records derive both and hand-written
  overrides get both.
])

== the hash set

A set is the map with the value column deleted, membership only.
All seven build it on the open addressing core, C first with the
Knuth multiplicative mix.

The dry run: the fixture is the integer sets 1 2 3 4 against 3 4 5
6, asserted by the C\# suite and pinned identically in C, Java,
JavaScript, and Lua; Go and Python run string sets instead.

+ Set a adds 1, 2, 3, 4: four members. Set b adds 3, 4, 5, 6: four
  members.
+ Membership gates both ways: a holds 1 and refuses 5 and 0, b
  refuses 1 and holds 6.
+ Re-adding 3 to a leaves the count at 4: the probe found it live
  and stopped.
+ Union adds every member of both sides, 4 + 4 = 8 adds landing 6
  distinct, 1 through 6.
+ Intersect keeps only the overlap, 3 and 4, and the disjoint probe
  against {10} lands empty, count 0.

#diagram([the two set operations as runs, union swallowing the duplicates it re-adds, intersect asking the other side member by member], length: 13pt, {
  let chip = (x, y, label, hot) => {
    cdraw.rect((x, y), (x + 0.9, y + 0.7), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.45, y + 0.35), label, size: 6pt)
  }
  cdraw.content((0.6, 6.4), [union run], size: 6.5pt)
  cdraw.content((3.3, 6.9), [from a], size: 6pt)
  for (i, v) in ("1", "2", "3", "4").enumerate() { chip(2.9 + i * 1.05, 5.5, [#v], true) }
  cdraw.content((8.6, 6.9), [from b], size: 6pt)
  for (i, v) in ("3", "4", "5", "6").enumerate() {
    let x = 8.2 + i * 1.05
    if i < 2 {
      cdraw.rect((x, 5.5), (x + 0.9, 6.2), fill: none, stroke: luma(160), radius: 0.02)
      cdraw.content((x + 0.45, 5.85), [#v], size: 6pt)
      cdraw.content((x + 0.45, 5.15), [dup], size: 6pt)
    } else { chip(x, 5.5, [#v], true) }
  }
  cdraw.content((14.4, 5.85), [6 members: 1 2 3 4 5 6], size: 6pt)
  cdraw.content((0.6, 3.6), [intersect run], size: 6.5pt)
  cdraw.content((3.3, 4.1), [a, asking b], size: 6pt)
  let verdicts = ("no", "no", "yes", "yes")
  for (i, v) in ("1", "2", "3", "4").enumerate() {
    chip(2.9 + i * 1.05, 2.7, [#v], i >= 2)
    cdraw.content((3.35 + i * 1.05, 2.25), [#verdicts.at(i)], size: 6pt)
  }
  cdraw.content((8.6, 3.05), [2 members: 3 4], size: 6pt)
  cdraw.content((2.9, 1.1), [disjoint probe against 10: count 0], size: 6pt)
  cdraw.content((11.0, 1.1), [re-add a member: still 4], size: 6pt)
})

The 6 member union and the 3, 4 intersect are pinned, and the
listings below build the set seven ways.

#listing("dsa/samples-c/src/Ch06/hashset.c", first: 35, last: 54, caption: [c, add and contains over the multiply-probe core])

#listing("dsa/samples-go/ch06/hashset.go", first: 46, last: 66, caption: [go, union and intersect over the shared open map])

#listing("dsa/samples-java/src/Ch06/Hashset.java", first: 25, last: 54, caption: [java, the knuth mix over the masked low 32 bits, add and contains])

#listing("dsa/samples/src/Ch06/HashSet.cs", first: 17, last: 61, caption: [c\#, add and contains over the same mix, union and intersect on top])

#listing("dsa/samples-js/src/ch06-hashset.mjs", first: 22, last: 47, caption: [javascript, add, has, and the sorted dump])

#listing("dsa/samples-py/src/Ch06/hashset.py", first: 22, last: 41, caption: [python, add, contains, values sorted for pinning])

#listing("dsa/samples-lua/ch06_hashset.lua", first: 15, last: 31, caption: [lua, add and has over string states])

The BCL's own `HashSet<T>` stays the production answer, and the C\#
suite builds the same core by hand beside its map families. The seven
hand builds carry the point,
one probe loop with one comparison per slot, union is add-everything
while intersect is add-if-the-other-has-it. The integer fixtures pin
identically in C, C\#, Java, JavaScript, and Lua: 1 2 3 4 against
3 4 5 6 unions to 1 through 6 and intersects to 3 4, a disjoint pair
intersects to empty, and re-adding a member is a no-op. Python and Go
run string sets, a b c against b c x, union a b c x, intersect b c,
Go sorting keys before compare so order never depends on the table.
JavaScript's mix keeps the product under 2^53 with a comment at the
multiply.

#diagram([two sets over the same probe core, union keeps every member, intersect keeps the overlap], length: 13pt, {
  // six slots, membership shaded, set a holds 1-4, set b holds 3-6
  let strip = (y, label, on) => {
    cdraw.content((-0.4, y + 0.35), [label], size: 6.5pt)
    for i in range(6) {
      cdraw.rect((1.6 + i * 1.2, y), (2.8 + i * 1.2, y + 0.7), fill: if on.at(i) { luma(205) } else { luma(235) }, radius: 0.02)
      if on.at(i) { cdraw.content((2.2 + i * 1.2, y + 0.35), [#(i + 1)], size: 6pt) }
    }
  }
  strip(5.0, [a], (true, true, true, true, false, false))
  strip(3.7, [b], (false, false, true, true, true, true))
  strip(2.4, [a union b], (true, true, true, true, true, true))
  strip(1.1, [a intersect b], (false, false, true, true, false, false))
  cdraw.content((5.2, 0.15), [union adds everything, intersect adds only what the other set already holds], size: 6.5pt)
})

== across the seven languages

Build sizes count non-comment source lines over the featured files;
bundled checks count where the language puts them in the same file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [419], [libc, qsort for dumps], [unsigned long long wraps silently and the pinned vectors fit anyway, string keys live in fixed 8-byte slot fields],
  [go], [228], [slices for sorting], [the map's hash is injected, tests force collisions on purpose],
  [java], [430], [jdk 27 stdlib], [long wraps mod 2^64 like c, the offset basis 14695981039346656037 rides parseUnsignedLong and renders via toUnsignedString, no compareUnsigned anywhere because no two hashes are ever ordered],
  [c\#], [283], [bcl only], [int keys hash their little endian bytes, the int-key spread check, the open set rides the same knuth mix],
  [javascript], [200], [node stdlib], [fnv runs on BigInt with asUintN(64), the book's first 2^53 boundary],
  [python], [264], [stdlib only], [a sentinel tombstone object marks deleted slots, identity-checked],
  [lua], [345], [lib.lua harness], [signed int64 wrap reads negative once the top bit sets, pinned vectors arrive as hex strings],
)

sources: learn.microsoft.com, `Dictionary<TKey,TValue>` remarks that
it is a hash table whose retrieval speed tracks hash quality,
`GetHashCode` guidelines, `Object.GetHashCode` remarks on mutable
keys, `System.IO.Hashing` namespace overview, accessed 2026-09-08,
dotnet/runtime `Dictionary.cs` source for the bucket and entry
layout, accessed 2026-09-10. Sample behavior verified by
`make verify-csharp`, 15 tests in chapter 6 of the samples suite.
The seven-language layer verifies the same way: 4 C programs under
`make verify-c`, 13 Go tests, the java runner's 63 Ch06 checks over
4 files under `run-java-samples`, 15 `node --test` cases, 44 Python
checks across 4 files, and 17 Lua checks under `run.lua`.
