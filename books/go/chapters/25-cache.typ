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
price. This chapter prices it honestly: what caching promises and what
it silently trades away, the http semantics a private api owes its
clients, the LRU from first principles over container/list and a map,
TTL beside LRU so age evicts as well as crowding, the stampede guard
that rides the previous chapter's singleflight, invalidation by delete
after write, and the discipline of what never gets cached at all.

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
rather than waiting:

#listing("go/api/internal/cache/httpsem.go", first: 50, last: 59, caption: [the layer: capacity, lifetime, and a clock, stated at construction])

#diagram([the layer sits between client and origin, answering what it can], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((6.4, y), (15.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((10.8, y + 0.95), [#title], size: 6pt)
    cdraw.content((10.8, y + 0.3), [#l1], size: 6pt)
  }
  stage(6.2, [client], [gets, if-none-match, retries])
  cdraw.line((10.8, 6.1), (10.8, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((4.6, 3.6), (17.0, 5.5), fill: luma(225), radius: 0.02)
  cdraw.content((10.8, 5.0), [the layer], size: 6pt)
  cdraw.content((10.8, 4.2), [hit: answer from the copy, miss: fill under the guard], size: 6pt)
  cdraw.line((10.8, 3.5), (10.8, 2.9), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [origin], [the routes, the store, the work])
  cdraw.content((19.6, 5.0), [capacity], size: 6pt)
  cdraw.content((19.6, 4.2), [lifetime], size: 6pt)
  cdraw.content((19.6, 3.4), [invalidation], size: 6pt)
})

== HTTP caching semantics for private APIs

A private api's responses are personalized and credentialed, so the
shared-cache machinery of the web mostly does not apply, but the
headers still owe clients a contract. Cache-Control states what may be
stored and for how long, and private keeps shared proxies out of it,
these bodies vary by who is asking. Vary names the request headers the
representation depends on, here the bearer token and the session
cookie, which is precisely the pair the cache key carries so two
identities never share an entry. no-store means never, not even for a
moment, and it is the default.

The reads are revalidation business. max-age=0 with must-revalidate
tells the client nothing is fresh for long, every reuse round-trips
the etag through the 304 lane the previous chapter built, and the
layer's own copy is short-lived and keyed by the vary values, a
latency optimization behind the protocol, never a replacement for it.
The table is deny by default: a route is cacheable only when a row
says so, and no other file in the service can make one cacheable by
accident:

#listing("go/api/internal/cache/httpsem.go", first: 26, last: 33, caption: [the per-route policy: two cacheable reads, everything else no-store by default])

#diagram([two freshness decisions: the client's and the layer's], length: 13pt, {
  cdraw.content((4.8, 7.3), [the client asks], size: 6.5pt)
  cdraw.content((4.8, 6.5), [#"GET, If-None-Match: etag"], size: 6pt)
  cdraw.line((4.8, 6.1), (4.8, 5.3), stroke: luma(100), mark: (end: ">>"))
  pane(0.6, 9.0, 5.2, [the 304 lane], [etag matches,], [empty body, ch24])
  cdraw.content((4.8, 3.9), [stale or absent: fresh 200], size: 6pt)
  cdraw.content((15.4, 7.3), [the layer answers], size: 6.5pt)
  cdraw.content((15.4, 6.5), [#"key = path + vary values"], size: 6pt)
  cdraw.line((15.4, 6.1), (15.4, 5.3), stroke: luma(100), mark: (end: ">>"))
  pane(11.2, 19.6, 5.2, [the hit lane], [entry live: replay,], [X-Cache: hit])
  cdraw.content((15.4, 3.9), [miss: fill under the guard], size: 6pt)
  cdraw.content((10.1, 2.4), [both lanes agree: nothing stale is ever served], size: 6pt)
  cdraw.content((10.1, 1.3), [#"Vary: Authorization, Cookie" is the contract for both], size: 6pt)
})

== LRU from first principles

Least recently used is one map and one list. The map finds any key in
constant time, the list carries the recency order with the hottest key
at the front, and the two agree through pointers: every entry lives in
both structures, the map pointing at the list node and the node
carrying the key so eviction can delete from the map without walking
it. A read moves its node to the front, a write inserts at the front,
and when capacity is exceeded the node at the back is the eviction,
found in constant time, removed from both structures in constant time.

The proof is the scramble test: fill the cache to capacity, touch a
key from the middle of the order, and the next insert evicts the true
least recently used entry, not the oldest insert. A plain map evicts
nothing and grows forever, a plain list finds in linear time, and the
pairing is the textbook answer to why both exist:

#listing("go/api/internal/cache/cache.go", first: 21, last: 36, caption: [the pairing: the map finds, the list orders, the entry carries its key and expiry])

#diagram([a read moves its node to the front, an insert evicts the back], length: 13pt, {
  cdraw.content((11.0, 7.5), [the list, hottest at the front], size: 6.5pt)
  let node(x, label, hot) = {
    cdraw.rect((x - 1.3, 5.4), (x + 1.3, 6.8), fill: hot, radius: 0.02)
    cdraw.content((x, 6.1), [#label], size: 6pt)
  }
  node(2.0, [d], luma(245))
  node(5.4, [c], luma(235))
  node(8.8, [b], luma(235))
  cdraw.line((8.8, 5.2), (8.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((8.8, 3.9), [read b: move to front], size: 6pt)
  node(12.2, [a], luma(235))
  cdraw.content((12.2, 4.9), [front], size: 6pt)
  cdraw.line((15.0, 6.1), (16.2, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((16.4, 5.4), (18.8, 6.8), fill: luma(220), radius: 0.02)
  cdraw.content((17.6, 6.4), [insert e], size: 6pt)
  cdraw.content((17.6, 5.7), [full], size: 6pt)
  cdraw.line((2.0, 5.2), (2.0, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 6.4, 3.0, [d evicted], [the true lru,], [not the oldest insert])
  cdraw.content((11.0, 1.6), [map: key to node, both directions, O(1) everywhere], size: 6pt)
})

== TTL beside LRU

LRU answers crowding, not age. An entry nobody reads can be least
recently used forever and still hold its bytes, and an entry everybody
reads can be hot long after the origin moved on. The TTL gives every
entry an expiry stamped from the injected clock at write time, and
reads check it lazily: an expired entry evicts itself on contact, so
every read is its own eviction decision and no sweep is needed for
correctness.

The sweep is for memory, not correctness. A janitor goroutine wakes on
a ticker and removes whatever aged out unread, and because it is
nothing but a ticker and a clock, it tests whole hours inside a
synctest bubble, the fake clock advancing only when every goroutine in
the bubble is parked, the assertion after the sleep running in
microseconds of real time:

#listing("go/api/internal/cache/cache.go", first: 50, last: 70, caption: [the read: expiry is lazy, the hit moves to the front, the miss cleans up])

#diagram([two clocks push entries out: age and crowding], length: 13pt, {
  cdraw.line((0.8, 4.6), (21.8, 4.6), stroke: luma(140))
  cdraw.content((11.3, 5.6), [entry lifetime on the injected clock], size: 6.5pt)
  cdraw.rect((3.0, 3.0), (9.0, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 3.9), [written], size: 6pt)
  cdraw.content((6.0, 3.25), [#"exp = now + ttl"], size: 6pt)
  cdraw.line((9.2, 3.6), (13.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.1, 2.9), [live: hits move it forward], size: 6pt)
  cdraw.line((13.2, 3.6), (17.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.6, 3.0), (21.6, 4.2), fill: luma(225), radius: 0.02)
  cdraw.content((18.6, 3.9), [expired], size: 6pt)
  cdraw.content((18.6, 3.25), [lazy on read, swept unread], size: 6pt)
  cdraw.content((6.0, 1.9), [the janitor: a ticker and a clock, nothing else], size: 6pt)
  cdraw.content((6.0, 0.8), [tested in a synctest bubble, hours in microseconds], size: 6pt)
})

== the stampede and its guard

Every entry expires eventually, and the moment a hot one does, the
herd arrives together: a hundred concurrent misses, a hundred
identical origin reads, the exact load spike the cache existed to
prevent, arriving at the worst moment, the cold one. The guard is the
previous chapter's loader worn one layer down: a miss fills through
singleflight, the herd collapses into one origin read, every waiter
receives the same result, and that result is the only thing that ever
writes the cache entry.

Fill rides the loader's DoChan door on purpose. Registration is
synchronous, so once Fill returns the caller has provably joined an
in-flight fill or started the only one, and the collapse test holds
that property exactly: three callers registered while the origin read
is held open on a channel, one fill, three identical answers, no
scheduling window. And errors do not land in the cache, a failed fill
misses again, so an origin outage cannot be memoized into a sticky
failure:

#listing("go/api/internal/cache/stampede.go", first: 11, last: 31, caption: [the fill: registered synchronously, collapsed to one origin read])

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
  cdraw.content((15.6, 5.1), [one fill, everyone waits on it], size: 6pt)
  cdraw.content((15.6, 4.4), [singleflight, ch24's loader], size: 6pt)
  cdraw.content((11.3, 2.6), [the fill's result is the only cache writer], size: 6pt)
  cdraw.content((11.3, 1.5), [errors are not memoized: a failed fill misses again], size: 6pt)
})

== invalidation on write

A write changes the origin, and the copies of what it changed are now
wrong. The discipline is delete after write, never update: the writer
drops the affected entries and lets the next read refill them through
the guard. Deleting is idempotent and always safe, and the refill is
the single writer the cache already trusts. Updating instead, pushing
the writer's view into the entry, sounds cheaper, one write instead of
a miss, but the writer does not know what a concurrent reader cached
mid-flight, and an update that lands just before a stale read's own
set leaves the wrong value with a fresh timestamp, the worst of both
worlds.

The rule is path plus collection: a write to a row invalidates the row
and the list that reads it, a write to the collection invalidates the
list and any rows under it. The staged test runs two identical caches
through the same write, one updated, one deleted, and only the deleted
one refills the origin's new truth:

#listing("go/api/internal/cache/invalidation.go", first: 14, last: 25, caption: [delete after write: the path, its collection, its children, nothing else])

#diagram([write to a row: the row and the list go, the refill is the only writer], length: 13pt, {
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
  cdraw.content((10.7, 4.3), [origin moves], size: 6pt)
  cdraw.content((10.7, 3.6), [status < 400], size: 6pt)
  cdraw.line((12.8, 4.4), (14.4, 4.4), stroke: luma(100), mark: (end: ">>"))
  node(16.6, 4.4, [delete], luma(225))
  cdraw.line((16.6, 3.4), (16.6, 2.4), stroke: luma(100), mark: (end: ">>"))
  pane(13.6, 20.4, 2.0, [next read], [miss, one guarded fill], [refill, never a push])
  cdraw.content((10.7, 1.6), [failed writes invalidate nothing], size: 6pt)
})

== what not to cache

The last decision is the one that prevents the incidents. Credential
routes, login and refresh, carry secrets and must never be replayable
from a copy. Rate-limited responses, the 429 lane, must always reach
the client, because a cached budget answer is a lie about money.
Personalized bodies without a vary key to separate identities are a
cross-user leak waiting for traffic. Anything the contract marks
no-store is a legal promise, not a hint. The layer's policy table is
deny by default, cacheable only where a row says so, which makes the
exclusion list the empty set of accidents: a new route opts in or it
does not get cached, and no change elsewhere in the service can flip
that.

The test pins the posture end to end: a no-store route asked three
times reaches the origin three times, answers from itself every time,
and never once says hit. The cheap check is the one worth keeping in
the gate, because the day someone adds a cacheable row to the wrong
route, this is the test that says which lane they put it in:

#listing("go/api/internal/cache/cache_test.go", first: 273, last: 295, caption: [the exclusion test: no-store routes always pay the origin])

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
  row(0.5, [no-store by policy], [a promise in the contract, not a hint])
  cdraw.content((14.0, -0.8), [deny by default: a row opts in, or nothing caches], size: 6pt)
})

sources: pkg.go.dev for container/list, net/http, and testing/synctest,
accessed 2026-09-25, the Cache-Control, Vary, and no-store semantics
quoted from RFC 9111 section 5.2 and RFC 9110 section 12.5.5 at
rfc-editor.org, the
synctest bubble rules read from the go 1.27 source and its
documentation, and singleflight's DoChan registration semantics from
the x/sync v0.22.0 source in the module cache, pinned by the previous
chapter. Verified by `go/api/internal/cache` tests, 13 of them, under
gofmt, go vet, go test, and the scoped race leg, with the janitor's
whole life exercised inside one synctest bubble.
