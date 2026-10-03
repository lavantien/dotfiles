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
clients, the LRU from first principles over a dict and a list with the
platform's fused OrderedDict spelling proven equivalent beside it, TTL
beside LRU so age evicts as well as crowding, the stampede guard that
rides the previous chapter's loader, invalidation by delete after
write, and the discipline of what never gets cached at all. Everything
lives in pyapi/cache.py over an injected clock, and the stdlib ships
no cache module, functools's memoization being the nearest kin and
not one, so every line of the structure is owned and stated.

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
rather than waiting. The clock is a callable returning epoch
milliseconds, the same convention the token bucket and the idempotency
window use, and no test in the family sleeps:

#listing("python/api/pyapi/cache.py", first: 18, last: 34, caption: [the layer's substrate: capacity, lifetime, and a clock, stated at construction]) // PIN: lru construction

#diagram([the layer sits between client and origin, answering what it can], length: 13pt, {
  let stage(y, t, l1) = {
    cdraw.rect((6.4, y), (15.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((10.8, y + 0.95), [#t], size: 6pt)
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

== http caching semantics for private apis

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
its etag through the 304 lane the previous chapter built, and the
layer's own copy is short-lived and keyed by the vary values, a
latency optimization behind the protocol, never a replacement for it.
The table is deny by default: a route is cacheable only when a row
says so, and no other file in the service can make one cacheable by
accident. The two cacheable rows are the user reads, the collection
and the single resource, and everything else, every write route and
every credential route, carries the no-store posture the exclusion
section enforces:

#listing("python/api/pyapi/cache.py", first: 198, last: 209, caption: [the per-route policy: two cacheable reads, everything else no-store by default]) // PIN: policy table

#diagram([two freshness decisions: the client's and the layer's], length: 13pt, {
  cdraw.content((4.8, 7.3), [the client asks], size: 6.5pt)
  cdraw.content((4.8, 6.5), [#"GET, If-None-Match: etag"], size: 6pt)
  cdraw.line((4.8, 6.1), (4.8, 5.3), stroke: luma(100), mark: (end: ">>"))
  pane(0.6, 9.0, 5.2, [the 304 lane], [etag matches,], [empty body, ch33])
  cdraw.content((4.8, 3.9), [stale or absent: fresh 200], size: 6pt)
  cdraw.content((15.4, 7.3), [the layer answers], size: 6.5pt)
  cdraw.content((15.4, 6.5), [#"key = path + vary values"], size: 6pt)
  cdraw.line((15.4, 6.1), (15.4, 5.3), stroke: luma(100), mark: (end: ">>"))
  pane(11.2, 19.6, 5.2, [the hit lane], [entry live: replay,], [X-Cache: hit])
  cdraw.content((15.4, 3.9), [miss: fill under the guard], size: 6pt)
  cdraw.content((10.1, 2.4), [both lanes agree: nothing stale is ever served], size: 6pt)
  cdraw.content((10.1, 1.3), [#"Vary: Authorization, Cookie" is the contract for both], size: 6pt)
})

== lru from first principles

Least recently used is one dict and one list, from scratch. The dict
finds any key in constant time, the list carries the recency order
with the coldest key at index 0, and the two agree because every entry
lives in both. A read moves its key to the hot end, a write inserts
at the hot end, and when capacity is exceeded the key at index 0 is
the eviction, removed from both structures.

The honest cost of the from-scratch spelling is linear time in the
recency dimension: `list.remove` scans to find the key and `pop(0)`
shifts the tail, both fine at book scale and both stated where the
code pays them. The platform's fused spelling exists because of
exactly this: the collections documentation says OrderedDict "was
designed to be good at reordering operations" while the plain dict
"was designed to be very good at mapping operations", that its
algorithm "can handle frequent reordering operations better than
dict", which "makes it suitable for implementing various kinds of LRU
caches", and that a plain dict "does not have an efficient equivalent"
for moving a key to the cold end. `move_to_end` is the read's reorder
in constant time and `popitem(last=False)` is the coldest eviction, so
FusedLru is the same structure in one object. The parity test proves
the two interchangeable over seeded op streams, the same answers, the
same count, the same recency order, step after step, which is what
makes either one safe to grow from. The proof of eviction is the
scramble: fill to capacity, touch a key from the middle, and the next
insert evicts the true least recently used entry, not the oldest
insert:

#listing("python/api/pyapi/cache.py", first: 36, last: 51, caption: [the pairing in the from-scratch spelling: the dict finds, the list orders, the scan is the stated cost]) // PIN: lru get

#diagram([a read moves its key to the hot end, an insert evicts index 0], length: 13pt, {
  cdraw.content((11.0, 7.5), [the list, coldest at index 0], size: 6.5pt)
  let node(x, label, hot) = {
    cdraw.rect((x - 1.3, 5.4), (x + 1.3, 6.8), fill: hot, radius: 0.02)
    cdraw.content((x, 6.1), [#label], size: 6pt)
  }
  node(2.0, [b], luma(245))
  node(5.4, [c], luma(235))
  node(8.8, [a], luma(235))
  cdraw.line((8.8, 5.2), (8.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((8.8, 3.9), [read a: move to the hot end], size: 6pt)
  node(12.2, [hot], luma(235))
  cdraw.line((15.0, 6.1), (16.2, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((16.4, 5.4), (18.8, 6.8), fill: luma(220), radius: 0.02)
  cdraw.content((17.6, 6.4), [insert d], size: 6pt)
  cdraw.content((17.6, 5.7), [full], size: 6pt)
  cdraw.line((2.0, 5.2), (2.0, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 6.4, 3.0, [b evicted], [the true lru,], [not the oldest insert])
  cdraw.content((11.0, 1.6), [dict: key to value and expiry, list: order, both updated], size: 6pt)
})

== ttl beside lru

LRU answers crowding, not age. An entry nobody reads can be least
recently used forever and still hold its bytes, and an entry everybody
reads can be hot long after the origin moved on. The TTL gives every
entry an expiry stamped from the injected clock at write time, and
reads check it lazily: an expired entry evicts itself on contact, so
every read is its own eviction decision and no sweep is needed for
correctness. The lazy branch lives in both spellings, and the fused
one shows it in the least code:

The sweep is for memory, not correctness. It walks the entries once
and drops whatever aged out unread, so a key the traffic forgot
cannot squat on its bytes forever, and because it is nothing but the
injected clock and a delete loop, the test for a whole simulated hour
is a loop that steps the clock by hand and counts what fell out, no
thread, no timer, no sleep. The wiring may call it from a daemon loop
if it wants a janitor, and the chapter states the trade plainly: the
janitor saves memory between reads, it never saves correctness,
because the lazy branch already owns that:

#listing("python/api/pyapi/cache.py", first: 117, last: 127, caption: [the fused read: lazy expiry on contact, then move_to_end]) // PIN: fused get

#diagram([two clocks push entries out: age and crowding], length: 13pt, {
  cdraw.line((0.8, 4.6), (21.8, 4.6), stroke: luma(140))
  cdraw.content((11.3, 5.6), [entry lifetime on the injected clock], size: 6.5pt)
  cdraw.rect((3.0, 3.0), (9.0, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 3.9), [written], size: 6pt)
  cdraw.content((6.0, 3.25), [#"exp = now + ttl"], size: 6pt)
  cdraw.line((9.2, 3.6), (13.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.1, 2.9), [live: reads move it forward], size: 6pt)
  cdraw.line((13.2, 3.6), (17.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.6, 3.0), (21.6, 4.2), fill: luma(225), radius: 0.02)
  cdraw.content((18.6, 3.9), [expired], size: 6pt)
  cdraw.content((18.6, 3.25), [lazy on read, swept unread], size: 6pt)
  cdraw.content((6.0, 1.9), [the sweep: the clock and a delete loop, nothing else], size: 6pt)
  cdraw.content((6.0, 0.8), [hours simulated by stepping the clock, never sleeping], size: 6pt)
})

== the stampede and its guard

Every entry expires eventually, and the moment a hot one does, the
herd arrives together: a hundred concurrent misses, a hundred
identical origin reads, the exact load spike the cache existed to
prevent, arriving at the worst moment, the cold one. The guard is the
previous chapter's loader worn one layer down: a miss fills through
the loader, the herd collapses into one origin read, every waiter
receives the same settled outcome, and that outcome is the only thing
that ever writes the cache entry.

The collapse test holds the loader's synchronous registration exactly
the way the conc chapter's does: three callers claim the key, one owns
the fill and holds it open on an event, two join, one fill happens,
and all three answers are the same value. And errors do not land in
the cache, a failed fill raises having stored nothing, so an origin
outage cannot be memoized into a sticky failure, and the next caller
after the outage fills again:

#listing("python/api/pyapi/cache.py", first: 162, last: 178, caption: [the read-through form: a live entry answers, a miss fills under the loader]) // PIN: get or fill

#diagram([the same expiry, with and without the guard], length: 13pt, {
  cdraw.content((5.6, 7.4), [without the guard], size: 6.5pt)
  for x in (2.2, 4.2, 6.2, 8.2) {
    cdraw.line((x, 6.6), (x, 5.6), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.content((5.2, 6.9), [the herd, all missing together], size: 6pt)
  cdraw.rect((1.4, 4.0), (9.0, 5.6), fill: luma(225), radius: 0.02)
  cdraw.content((5.2, 5.1), [n identical origin reads], size: 6pt)
  cdraw.content((5.2, 4.4), [the spike the cache caused], size: 6pt)
  cdraw.content((16.0, 7.4), [with the guard], size: 6.5pt)
  for x in (12.6, 14.6, 16.6, 18.6) {
    cdraw.line((x, 6.6), (x, 5.6), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.content((15.6, 6.9), [the herd, still missing together], size: 6pt)
  cdraw.rect((11.8, 4.0), (19.4, 5.6), fill: luma(225), radius: 0.02)
  cdraw.content((15.6, 5.1), [one fill, everyone waits on it], size: 6pt)
  cdraw.content((15.6, 4.4), [the loader, ch33's collapse], size: 6pt)
  cdraw.content((11.3, 2.6), [the fill's outcome is the only cache writer], size: 6pt)
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
store leaves the wrong value with a fresh timestamp, the worst of both
worlds. The staged test runs two layers through the same write, one
updated by push, one deleted and refilled, pushes the origin twice,
and only the deleted one converges on the truth both times.

The rule is path plus collection: a write to a row invalidates the row
and the list that reads it, a write to a collection invalidates the
list and any children under it, and nothing else. The key carries the
path first, so the drop is one filtered pass, and a failed write
invalidates nothing because the origin never moved:

#listing("python/api/pyapi/cache.py", first: 308, last: 321, caption: [delete after write: the path, its collection, its children, nothing else]) // PIN: invalidate

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
  cdraw.content((10.7, 3.6), [status under 400], size: 6pt)
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
that. The test pins the posture route by route, every write route and
every credential route absent from the table, and the layer refuses
to store a snapshot for a route with no row, so the day someone adds
a cacheable row to the wrong route, this is the test that says which
lane they put it in:

#listing("python/api/tests/test_cache.py", first: 328, last: 341, caption: [the exclusion posture: deny by default, route by route]) // PIN: deny by default

#diagram([the exclusion list, each row with its reason], length: 13pt, {
  let row(y, route, reason) = {
    cdraw.rect((0.6, y), (22.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.0, y + 0.75), [#route], size: 6pt)
    cdraw.content((14.0, y + 0.75), [#reason], size: 6pt)
  }
  cdraw.content((5.0, 7.5), [route], size: 6.5pt)
  cdraw.content((14.0, 7.5), [why it is never cached], size: 6.5pt)
  row(5.6, [#"POST /api/auth/login"], [secrets, and timing that must stay flat])
  row(3.9, [#"POST /api/auth/refresh"], [credential rotation, replay is theft])
  row(2.2, [429 responses, any route], [the budget must reach the client])
  row(0.5, [no-store by policy], [a promise in the contract, not a hint])
  cdraw.content((14.0, -0.8), [deny by default: a row opts in, or nothing caches], size: 6pt)
})

sources: docs.python.org for the collections page, accessed 2026-09-27,
the OrderedDict entry quoting that it "was designed to be good at
reordering operations" beside the plain dict "designed to be very good
at mapping operations", that its algorithm "can handle frequent
reordering operations better than dict" and "makes it suitable for
implementing various kinds of LRU caches", with move_to_end and
popitem(last=False) read from the same entry, the threading page for
the lock the structures share, the 3.14 library index for the absence
of any cache module in the standard library, and the Cache-Control,
Vary, and no-store semantics read from RFC 9111 section 5.2 at
rfc-editor.org at the same date. Verified by the cache family's 19
tests in tests/test_cache.py under the pyapi gate, with the parity
loop running 20 seeded trials of 400 operations each over both
spellings and the stampede collapse pinned through the loader's
synchronous claim seam from the previous chapter.
