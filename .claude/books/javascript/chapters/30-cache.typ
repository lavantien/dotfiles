#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= caching

A cache is a promise to answer from a copy, and every promise has a
price. This chapter prices it honestly in the node idiom: what caching
promises and what it silently trades away, the LRU over one `Map`
where the go book needed a map and a list, TTL beside LRU so age
evicts as well as crowding, the stampede guard as a singleflight hand
rolled from a promise map, invalidation by delete after write, and the
discipline of what never gets cached at all.

== what caching promises

A cache answers from a copy to save the origin the work, and both
sides of the bargain matter: the copy must be cheap to find, and the
answer must be one the origin would still give. Every caching decision
is a bet that the read will be asked again before it changes, and the
three terms of the bet are capacity, how many copies, lifetime, how
long each stays, and invalidation, what a write owes the copies it
made wrong. Miss any term and the cache stops being an optimization
and becomes a second source of truth, which is the failure mode every
caching chapter exists to prevent.

This service's copy lives in one layer, a bounded store of responses
in front of the route table, constructed with its three terms up front
and an injected clock so every one of them is testable as arithmetic
rather than waiting. The wiring names the whole contract in one call:

#listing("javascript/api/src/cache/wire-cache.mjs", first: 8, last: 12, caption: [the layer at construction: capacity, lifetime, and a clock, three terms up front])

#diagram([the layer sits between client and origin], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((6.4, y), (15.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((10.8, y + 0.95), [#title], size: 6pt)
    cdraw.content((10.8, y + 0.3), [#l1], size: 6pt)
  }
  stage(6.2, [client], [gets, if-none-match, retries])
  cdraw.line((10.8, 6.1), (10.8, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((4.6, 3.6), (17.0, 5.5), fill: luma(225), radius: 0.02)
  cdraw.content((10.8, 5.0), [the layer], size: 6pt)
  cdraw.content((10.8, 4.2), [hit: answer the copy, miss: fill under the guard], size: 6pt)
  cdraw.line((10.8, 3.5), (10.8, 2.9), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [origin], [the routes, the store, the work])
  cdraw.content((19.6, 5.0), [capacity], size: 6pt)
  cdraw.content((19.6, 4.2), [lifetime], size: 6pt)
  cdraw.content((19.6, 3.4), [invalidation], size: 6pt)
})

== LRU over one Map

Least recently used is one `Map`. The js `Map` already remembers
insertion order, the iteration walks entries oldest first, and that
single fact collapses the two structures the textbook pairs: `delete`
then `set` moves a key to the most recent position, and the first key
the iterator offers is the eviction. Every operation is constant time,
and there is no hand-threaded node list to keep honest, the ordering
lives inside the structure the language guarantees.

The proof is the scramble test: fill to capacity, touch a key from
the middle of the order, and the next insert evicts the true least
recently used entry, not the oldest insert. A plain object with string
keys would evict nothing and grow forever, and a second list would
re-implement what `Map` iteration already answers. The property loop
drives it further, a seeded splitmix32 stream of two thousand mixed
set, get, and delete ops against a deliberately naive reference model,
an array scanned front to back, and the two agree on every answer and
every size, the bound never blown.

#listing("javascript/api/src/cache/lru.mjs", first: 31, last: 37, caption: [the write: re-insert at the end, evict the first key while over capacity])

#diagram([one Map, oldest first, hottest last], length: 13pt, {
  cdraw.content((11.0, 7.5), [iteration order, most recent at the end], size: 6.5pt)
  let node(x, label, hot) = {
    cdraw.rect((x - 1.3, 5.4), (x + 1.3, 6.8), fill: hot, radius: 0.02)
    cdraw.content((x, 6.1), [#label], size: 6pt)
  }
  node(2.0, [d], luma(245))
  node(5.4, [c], luma(235))
  node(8.8, [b], luma(235))
  node(12.2, [a], luma(220))
  cdraw.content((12.2, 4.9), [most recent], size: 6pt)
  cdraw.line((2.0, 5.2), (2.0, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 6.4, 3.0, [eviction], [the first key,], [the true lru])
  cdraw.line((8.8, 5.2), (8.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((8.8, 3.9), [read b: delete, set again], size: 6pt)
  cdraw.content((11.0, 1.6), [no second structure, the Map is the order], size: 6pt)
})

== TTL beside LRU

LRU answers crowding, not age. An entry nobody reads can be least
recently used forever and still hold its bytes, and an entry everybody
reads can be hot long after the origin moved on. Every entry carries
its own expiry stamped from the injected clock at write time, and
reads check it lazily: an expired entry evicts itself on contact, so
every read is its own eviction decision and no sweep is needed for
correctness.

The sweep is for memory, not correctness, and it is nothing but a
loop over the same expiry test, runnable on demand or on an interval
the wiring owns. Because the clock is injected, the tests drive whole
lifetimes with `tick` and never sleep: the sweep test writes two
entries, advances the clock to the exact expiry, shows both still held
until something touches them, then sweeps and shows the store empty,
hours of wall time inside microseconds.

#listing("javascript/api/test/cache/lru.test.mjs", first: 48, last: 57, caption: [the sweep test: tick is the only clock, no sleep anywhere])

#diagram([two pressures push entries out: age and crowding], length: 13pt, {
  cdraw.line((0.8, 4.6), (21.8, 4.6), stroke: luma(140))
  cdraw.content((11.3, 5.6), [entry lifetime on the injected clock], size: 6.5pt)
  cdraw.rect((3.0, 3.0), (9.0, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 3.9), [written], size: 6pt)
  cdraw.content((6.0, 3.25), [#"expires = now + ttl"], size: 6pt)
  cdraw.line((9.2, 3.6), (13.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.1, 2.9), [live: reads refresh nothing but order], size: 6pt)
  cdraw.line((13.2, 3.6), (17.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.6, 3.0), (21.6, 4.2), fill: luma(225), radius: 0.02)
  cdraw.content((18.6, 3.9), [expired], size: 6pt)
  cdraw.content((18.6, 3.25), [lazy on read, swept unread], size: 6pt)
  cdraw.content((6.0, 1.9), [the sweep: the same expiry test, nothing else], size: 6pt)
  cdraw.content((6.0, 0.8), [mock.timers tick, hours in microseconds], size: 6pt)
})

== the stampede guard: singleflight from a promise map

Every entry expires eventually, and the moment a hot one does, the
herd arrives together: a hundred concurrent misses, a hundred
identical origin reads, the exact load spike the cache existed to
prevent, arriving at the worst moment, the cold one. The guard is the
singleflight pattern, and in js it is a promise map, hand rolled:
the first caller for a key starts the fill and parks the promise in
the map, every concurrent caller receives that same promise, and the
entry is forgotten the moment the call settles.

The properties the tests pin are three. The collapse: three callers
registered together run the fill exactly once and all receive the
same answer, and because registration is synchronous, one `Map.get`
and one `Map.set` with no `await` between them, callers that arrive
together have provably joined one flight, no scheduling window. The
forgetting: after the settle the entry is gone, so the herd that
arrives after the lull fills again, a collapse tool, not a cache. And
the errors: a rejected fill rejects for every caller and is never
memoized, so an origin outage cannot be baked into the key, the retry
after recovery fills fresh.

#listing("javascript/api/src/cache/singleflight.mjs", first: 17, last: 28, caption: [the loader: one promise per key, forgotten on settle, errors never stored])

#diagram([the same expiry, with and without the guard], length: 13pt, {
  cdraw.content((5.6, 7.4), [without the guard], size: 6.5pt)
  for x in (2.2, 4.2, 6.2, 8.2) {
    cdraw.line((x, 6.6), (x, 5.6), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.content((5.2, 6.9), [the herd, all missing together], size: 6pt)
  cdraw.rect((1.4, 4.0), (9.0, 5.6), fill: luma(225), radius: 0.02)
  cdraw.content((5.2, 5.1), [N identical origin reads], size: 6pt)
  cdraw.content((5.2, 4.4), [the spike the cache caused], size: 6pt)
  cdraw.content((16.0, 7.4), [with the guard], size: 6.5pt)
  for x in (12.6, 14.6, 16.6, 18.6) {
    cdraw.line((x, 6.6), (x, 5.6), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.content((15.6, 6.9), [the herd, still missing together], size: 6pt)
  cdraw.rect((11.8, 4.0), (19.4, 5.6), fill: luma(225), radius: 0.02)
  cdraw.content((15.6, 5.1), [one fill, everyone awaits it], size: 6pt)
  cdraw.content((15.6, 4.4), [the shared promise], size: 6pt)
  cdraw.content((11.3, 2.6), [registration is await-free: join is provable], size: 6pt)
  cdraw.content((11.3, 1.5), [the fill's result is the only cache writer], size: 6pt)
})

== invalidation on write

A write changes the origin, and the copies of what it changed are now
wrong. The discipline is delete after write, never update: the writer
drops the affected entries and lets the next read refill them through
the guard. Deleting is idempotent and always safe. Updating instead,
pushing the writer's view into the entry, sounds cheaper, one write
instead of a miss, but the writer does not know what a concurrent
reader cached mid-flight, and the staged test shows the ending, an
entry holding the stale bytes with a fresh ttl, the worst of both
worlds, while its deleted twin refills the origin's new truth.

The rule is path plus collection: a write to a row invalidates the
row, the list that reads it, and any child under it, nothing else. The
test stages four entries and one write and shows exactly the three
affected gone and the stranger still hit. Failed writes invalidate
nothing, the origin never moved.

#listing("javascript/api/src/cache/layer.mjs", first: 68, last: 79, caption: [delete after write: the path, its collection, its children, nothing else])

#diagram([write to a row: the row, the list, and children go, the refill is the only writer], length: 13pt, {
  let node(x, y, label, fill) = {
    cdraw.rect((x - 2.2, y - 0.8), (x + 2.2, y + 0.8), fill: fill, radius: 0.02)
    cdraw.content((x, y), [#label], size: 6pt)
  }
  node(4.0, 6.4, [list entry], luma(235))
  node(4.0, 4.4, [row u-1], luma(235))
  node(4.0, 2.4, [row u-2], luma(245))
  cdraw.content((10.6, 6.4), [#"PATCH /api/users/u-1"], size: 6pt)
  cdraw.line((7.0, 4.4), (8.6, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.8, 3.2), (12.6, 5.6), fill: luma(220), radius: 0.02)
  cdraw.content((10.7, 5.0), [the write lands], size: 6pt)
  cdraw.content((10.7, 4.3), [origin moved], size: 6pt)
  cdraw.content((10.7, 3.6), [status under 400], size: 6pt)
  cdraw.line((12.8, 4.4), (14.4, 4.4), stroke: luma(100), mark: (end: ">>"))
  node(16.6, 4.4, [delete], luma(225))
  cdraw.line((16.6, 3.4), (16.6, 2.4), stroke: luma(100), mark: (end: ">>"))
  pane(13.6, 20.4, 2.0, [next read], [miss, one guarded fill], [refill, never a push])
  cdraw.content((10.7, 1.6), [failed writes invalidate nothing], size: 6pt)
})

== what never gets cached

The last decision is the one that prevents the incidents. Credential
routes, login and refresh, carry secrets and must never be replayable
from a copy. Rate-limited responses, the 429 lane, must always reach
the client, because a cached budget answer is a lie about money.
Personalized bodies without a vary key to separate identities are a
cross-user leak waiting for traffic, which is why the entry key
carries the vary values, the bearer token and the session cookie, so
two identities reading the same url hold two entries. The policy
table is deny by default, a route is cacheable only when a row says
so, and the two rows that say so are the reads, `GET /api/users` and
`GET /api/users/:id`, both telling clients `private, max-age=0,
must-revalidate`, nothing fresh for long, every reuse round-trips its
etag through the 304 lane the previous chapter built.

The exclusion test pins the posture end to end: a route with no row,
login, asked three times reaches the origin three times, answers from
itself every time, and never once says hit. The cheap check is the
one worth keeping in the gate, because the day someone adds a row to
the wrong route, this is the test that says which lane they put it in.

#listing("javascript/api/test/cache/layer.test.mjs", first: 65, last: 79, caption: [the exclusion test: no row, no copy, the origin answers every time])

#diagram([the exclusion list, each row with its reason], length: 13pt, {
  let row(y, route, reason) = {
    cdraw.rect((0.6, y), (22.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.0, y + 0.75), [#route], size: 6pt)
    cdraw.content((14.0, y + 0.75), [#reason], size: 6pt)
  }
  cdraw.content((5.0, 7.5), [route], size: 6.5pt)
  cdraw.content((14.0, 7.5), [why it is never cached], size: 6.5pt)
  row(5.6, [#"POST /api/auth/login"], [secrets, and timing that must stay flat])
  row(3.9, [#"POST /api/auth/refresh"], [credential rotation, replay is theft evidence])
  row(2.2, [429 responses, any route], [the budget must reach the client])
  row(0.5, [no row in the table], [deny by default is the whole design])
  cdraw.content((14.0, -0.8), [a route opts in, or nothing caches], size: 6pt)
})

sources: `developer.mozilla.org/docs/Web/JavaScript/Reference/Global_Objects/Map`
for the insertion-order iteration guarantee the LRU stands on,
accessed 2026-09-26, nodejs.org/api/test.md for `mock.timers` and the
tick discipline every ttl path rides, accessed 2026-09-26, and the
`Cache-Control`, `Vary`, and `no-store` semantics quoted from RFC 9111
section 5.2 at rfc-editor.org, accessed 2026-09-26. Verified by
`books/javascript/api` tests, 19 of them in `test/cache`, the seeded
property loop with its committed 0x12345678 seed included, under
`node --test` in `npm run verify`.
