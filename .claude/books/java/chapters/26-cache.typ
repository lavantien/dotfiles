#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= caching

A cache is a promise with two prices. The promise is freshness within
a stated window, the first price is memory, which must be bounded,
and the second price is the stampede, the crowd of concurrent misses
that all decide to fill the same key and hammer the backend they were
supposed to protect. This chapter builds both answers in
`javabook.cache`: a bounded table of expiring entries over one
`ConcurrentHashMap`, and a single-flight fill so one loader runs per
key no matter how many callers arrive together. The go book built
the same layer from lru upward, #xref-to("go", "cache"), and its
stampede section is the one this chapter's future map answers
directly. Java's jdk has no cache of its own, `ConcurrentHashMap`
is the raw material and everything above it is owned here, which is
the stdlib-exclusive lane's whole trade.

== ttl from first principles

An entry carries its own deadline. On read, a deadline that has
passed means the entry is gone, removed by the very read that
noticed it, and no thread ever sweeps the table on a timer. The
boundary is exact and the tests pin it: an entry with a 100 nanos
ttl answers at 99 and is dead at 100, at-or-after means gone, and a
ttl of zero or less is refused outright because an entry born dead
is a defect, not a policy. The clock is injected, `System::nanoTime`
in production and a hand-driven counter in every test, so not one
test sleeps:

#listing("java/api/src/javabook/cache/TtlTable.java", first: 45, last: 55, caption: [the read: live values only, the noticing read reaps, no timer anywhere])

== bounded: the eviction decision

Memory must be capped, and past the cap the table evicts in a fixed
order. First the dead: an expired entry is free space the sweep
reclaims before anything live is touched. Then, when everything
held is live, the entry dying soonest goes, the one whose remaining
life is shortest, so the table sheds the entries it was about to
lose anyway. That is not lru: tracking access order means a queue
updated on every read and locks around it, and the deadline the
entry already carries is a free eviction rank that deterministic
tests can pin exactly. The whole write path, eviction plus insert,
runs under one monitor, and reads never take it, cells are
immutable records published through the map's own atomics:

#listing("java/api/src/javabook/cache/TtlTable.java", first: 63, last: 73, caption: [the write: room is made under the monitor, a replaced key never evicts a neighbor])

The edge table is the contract: a full table of three entries with
deadlines 100, 50, and 200 loses the 50 on the fourth insert, a dead
entry is swept in preference to any live one, replacing an existing
key never evicts another, and a flood of 50 distinct keys against a
cap of 3 ends with 3 held. The monotone claim the tests assert is
`size() <= maxEntries` under any interleaving, including 8 virtual
threads racing 200 writes each.

The eviction scan is linear in the table, walked only when a new key
arrives at a full table, and that cost is a number the design owns
rather than hides: at book scale, thousands of entries, the scan is
microseconds of work under the write monitor, and the escape hatch
when it stops being cheap is a shard per core or a heap keyed on the
deadline, both named here so the ceiling is a decision and not a
discovery. The cache chapter of the go book answered crowding with an
lru list whose every read moves a node, bookkeeping this design
declines upfront: reads here stay untouched by the capacity
machinery entirely.

== reads without locks

A read is one `get` on the map plus a deadline comparison, and it
never touches the monitor, which is a claim about memory visibility
that deserves its proof. Every stored cell is an immutable record,
one value and one deadline, published through the
`ConcurrentHashMap` put, and the map's atomics create the
happens-before edge chapter 10 established: a reader that observes
the cell observes a fully constructed object, never a torn one. The
conditional remove, `remove(key, cell)` with the cell as witness,
means two readers racing to reap the same dead entry both succeed
harmlessly, the second's removal finds nothing and returns false,
and a writer that replaced the cell in between is not undone,
because the witness no longer matches. The whole read path is three
lock-free steps, and the concurrency claims are pinned twice, 8
racing writers holding the cap exact, and 16 threads sliding one
hot key 8,000 times without ever recreating it.

== the sliding window, the same table serving reuse

One more read shape earns its keep in the next chapter: the sliding
window, where every hit slides the deadline to now plus the window.
An entry that keeps being touched never expires, an idle one dies
one window after its last touch, which turns the same bounded table
into an idle-key reaper. The rate limiter stores its per-key buckets
here, so a key that stops asking costs nothing after its window and
a key that keeps asking keeps its bucket, and the cache's production
presence in the service is exactly that seat:

#listing("java/api/src/javabook/cache/TtlTable.java", first: 88, last: 116, caption: [sliding: the hit slides in one per-key atomic step, only creation takes the monitor])

The hot path deserves its own sentence: a hit is one `computeIfPresent`
that swaps the cell for one with a slid deadline, atomic per key, no
table-wide monitor and no capacity scan, so the rate chapter's
per-request bucket touch never queues behind an eviction. The maker
runs under the write monitor on the creation path, so it must be
cheap, and that rule carries weight: the expensive fill belongs to
the single flight, which waits outside every lock, and the reason is
the next section's whole argument.

== single flight

The stampede, precisely: a popular key expires, 64 requests miss in
the same instant, and each one walks to the backend because each
innocently observed a miss. The fix is one future per key. The first
caller installs a `CompletableFuture` in an inflight map and becomes
the filler, every caller that arrives while the fill runs joins that
same future, and when the fill lands the entry is stored and the
future completes for everyone:

#listing("java/api/src/javabook/cache/Cache.java", first: 46, last: 69, caption: [one future per key: the winner fills, riders join, failure is never stored])

Why not `computeIfAbsent` and be done: the map's own contract holds
the bin lock through the mapping function, so a 150 ms fill pins
every key that hashes into the same bin behind it, and the jdk's
docs say so plainly, the computation "should be short and simple".
The future map pays nothing while the fill runs, the filler is the
only thread working, and the riders park on the join, which under
virtual threads unmounts them off their carriers:

#listing("java/api/test/javabook/cache/CacheTests.java", first: 125, last: 156, caption: [64 racers behind one latch, one fill, every racer served])

A failed fill completes its future exceptionally and is never
cached: riders observe the failure, wrapped by the join's
`CompletionException`, the inflight entry is removed, and the next
get starts fresh, which the tests pin with a loader that throws once
then succeeds. A null from a loader is refused loudly rather than
stored as an eternal miss.

The one-loader guarantee has to be airtight, not probabilistic, and
the race that breaks naive versions is worth naming because a test
with a sleeping loader can never catch it. A loser reads a miss,
the winner's whole fill lands, and only then does the loser install
its own future and fill again, two backend calls for one stampede.
The closing move is an ordering argument, not a lock: the filler
stores the entry before it removes its future, so for a loser to
install into an empty map the winner's removal must already have
happened, which means the winner's store happened too, which means
the loser's re-check after installing finds the entry and stands
down. The blind attackers ran 400,000 two-racer rounds against this
exact window and filled twice in none of them.

One recursion rule closes the section: a loader must not read its
own key through this cache. It would join the very future it is
filling and wait on itself forever, the single-flight contract
turned inside out, and the javadoc says so in those words.

#diagram([the stampede collapsed: one fill, everyone else parked on its future], length: 13pt, {
  cdraw.content((11.0, 9.0), [64 concurrent misses on one key], size: 6.5pt)
  pane(0.3, 7.3, 7.4, [caller 1], [installs the future], [runs the loader])
  pane(8.0, 15.0, 7.4, [callers 2 to 64], [join the same future], [parked, unmounted])
  pane(15.7, 22.7, 7.4, [the fill lands], [one entry stored], [one completion wakes all])
  cdraw.line((7.5, 5.6), (7.9, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((15.2, 5.6), (15.6, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.0, 2.6), [uncoordinated: 64 fills, measured below], size: 6pt)
  cdraw.content((11.0, 1.5), [single flight: 1 fill, every caller served], size: 6pt)
})

== measured: the stampede and the hit rate

The counterfactual runs beside the real thing in the test class. On
one side, 64 virtual threads race an uncoordinated get-or-load over
a plain map, check, miss, sleep, store: measured 2026-10-05 on this
machine, 64 fills, every racer paid the backend. On the other side
the same 64 race the cache: 1 fill, all 64 served. The hit rate has
its own deterministic workload, 1,000 gets over 10 distinct keys
under a frozen clock: 10 misses, 990 hits, 99.0 percent, an exact
number because the sequence and the clock are both fixed and the
test asserts the miss count rather than eyeballing a ratio. Both
numbers print in the junit lane's output, dated by the run.

== invalidation on write

The ttl bounds staleness from above, and the write path can do
better than waiting for it. Derived data whose source changed should
be recomputed or dropped at the moment of the write, and the honest
shape over this table is small: the writer knows the keys its write
touches, so it stores the fresh value under the same key the reader
will ask for, or lets the next read refill by simply not storing
anything. The layer offers `put` for the first and a short ttl for
the second, and the choice between them is one question, does the
rebuild cost more than the write-path complexity. What the layer
refuses to grow is the catalog of dependencies, key A invalidates
keys B through D, because that graph is where caches earn their
reputation for being clever in ways nobody can audit. A reader that
can name what it wants and a writer that can name what it changed
is the whole contract.

The user family needs none of this yet, which is worth stating as a
fact rather than an omission: the store's reads are a tree map clone at
book scale and the hash of the representation is cheaper than the
bytes it names, so the cache waits for a reader expensive enough to
earn it. The layer exists because that reader arrives with the
observability and load chapters, and building it now against the
limiter's real seat means its boundedness and its stampede answers
are already tested the day it is first pointed at a handler.

== the etag interplay

Chapter 21's conditional read closes a loop with this layer. The
etag is sha256 over the exact wire bytes and the writer is
deterministic, so a cached representation and a recomputed one
carry the same etag forever, which means a cache in front of the
representation layer can never cause a 304 to lie: if the client's
`If-None-Match` matches the cached bytes' hash, it matches the
fresh bytes' hash too, because the same record produces the same
bytes both ways. The 304 already saves the body, the cache saves
the rebuild, and the two compose without coordination. That is not
luck, it is the payoff of chapter 21's decision to compute the etag
rather than store it, a function cannot drift from a value it never
held separately.

== what not to cache

The layer takes a key and a loader, so the discipline is in what
gets keyed. Roles are never cached, chapter 23's rule that authz
reads store truth at request time, and a cached role set is an
access decision frozen past its revocation. Anything derived from a
token's claims is not cache state, the token is already the client's
own compact representation. And a personal response under a shared
key is a leak in waiting, the key must name the audience the value
serves. The positive cases are exactly the expensive and the
communal: derived aggregates, third-party answers, the kind of read
a stampede hurts.

The chapter's tests are fourteen: the ttl boundary both sides of the
deadline, the zero-ttl refusal, the three-way eviction order, the
dead-before-living sweep, the replace-without-eviction, the sliding
window's slide and death and rebuild, the flood bound, the 64-racer
single flight at exactly one fill, the uncoordinated counterfactual
at 64, the failed fill never cached, the rider seeing the wrapped
failure, the exact hit rate, the 8-thread bounded stress, and the
16-thread hot-key slide that never recreates. The rate chapter adds
10 more against the same table through the limiter.

sources: `ConcurrentHashMap.computeIfAbsent`'s short-and-simple
guidance and its locking behavior read from the pinned build's own
sources, `tools/jdk27/build/jdk-27/lib/src.zip`, oracle jdk 27 ga
build 27+35-2325, accessed 2026-10-05, and
`CompletableFuture.join`'s `CompletionException` contract from the
same zip. The stampede and hit-rate measurements (64 uncoordinated
fills against 1 single-flight fill, 990 of 1,000 hits over 10 keys)
printed by the `javabook.cache` tests under the vendored junit 6.1.3
lane, dated 2026-10-05 on tools/jdk27/build/jdk-27, 20 reported
cores, 14 tests green three consecutive runs. The ttl, lru, and
invalidation framing follows the go book's cache chapter, book 3,
chapter 25, read for the parallel contracts.
