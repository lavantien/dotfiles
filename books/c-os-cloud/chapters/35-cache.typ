#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow

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
price. This chapter prices it in the platform's own parts: a fixed
preallocated table with lru order threaded through indexes and ttl
beside it, the http semantics a private api owes its clients, the
stampede collapsed through the previous chapter's singleflight,
invalidation as delete after write, and the policy table that is
deny by default so the exclusion list is the empty set of accidents.
Nothing in the steady path allocates, and time enters only as a
caller's now, which is what makes whole lifetimes test arithmetic.

== what caching promises

A cache answers from a copy to save the origin the work, and both
sides of the bargain matter: the copy must be cheap to find, and the
answer must be one the origin would still give. Every caching
decision is a bet that the read will be asked again before it
changes, and the three terms of the bet are capacity, how many
copies, lifetime, how long each stays, and invalidation, what a
write owes the copies it made wrong. Miss any term and the cache
stops being an optimization and becomes a second source of truth,
the failure mode every caching chapter exists to prevent.

This service's copy lives in one layer, a fixed table of rows in
front of the route handlers, constructed with its capacity and
lifetime up front and reached through one lock, because request
workers share it. The clock is not read anywhere in the layer: now
arrives as a value, so a test that wants a row to age out adds to a
number instead of waiting on a wall.

#listing("c-os-cloud/api/src/cache_lru.c", first: 59, last: 69, caption: [the layer's construction: fixed storage, one lock, the lifetime stated once]) // PIN: cache init

#diagram([the layer sits between client and origin, answering what it can], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((6.4, y), (15.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((10.8, y + 0.95), [#title], size: 6pt)
    cdraw.content((10.8, y + 0.3), [#l1], size: 6pt)
  }
  stage(6.2, [client], [gets, retries])
  cdraw.line((10.8, 6.1), (10.8, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((4.6, 3.6), (17.0, 5.5), fill: luma(225), radius: 0.02)
  cdraw.content((10.8, 5.0), [the layer], size: 6pt)
  cdraw.content((10.8, 4.2), [hit: answer from the copy, miss: fill under the flight], size: 6pt)
  cdraw.line((10.8, 3.5), (10.8, 2.9), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [origin], [the routes, the store])
  cdraw.content((19.6, 5.0), [capacity], size: 6pt)
  cdraw.content((19.6, 4.2), [lifetime], size: 6pt)
  cdraw.content((19.6, 3.4), [invalidation], size: 6pt)
})

== http semantics for a private api

A private api's responses are personalized and credentialed, so the
shared-cache machinery of the web mostly does not apply, but the
headers still owe clients a contract. Cache-Control states what may
be stored and for how long, and private keeps shared proxies out of
it, these bodies vary by who is asking. Vary names the request
members the representation depends on, here the bearer token and the
session cookie, which is precisely the pair the cache key carries,
method and path joined with the identity, so two identities never
share a row. no-store means never, not even for a moment, and it is
the default.

The reads are revalidation business: the client's etag round-trips
through the 304 lane the previous chapter built, and the layer's own
copy is a latency optimization behind the protocol, never a
replacement for it. The policy table is the whole story on the wire
side: a route is cacheable only where a row says so, two rows in
this service, the row read at 30 seconds and the list page at 5, and
no other file can make one cacheable by accident. One honesty note
on the composition: the wired layer governs the object route only,
so the list row is family truth the running service does not yet act
on, the list answering no-store through the same ungoverned posture
every other route takes.

#listing("c-os-cloud/api/src/cache_policy.c", first: 13, last: 37, caption: [the per-route policy: two cacheable reads, everything else no-store by default]) // PIN: policy table

#diagram([two freshness decisions: the client's and the layer's], length: 13pt, {
  cdraw.content((4.8, 7.3), [the client asks], size: 6.5pt)
  cdraw.content((4.8, 6.5), [#"GET, If-None-Match: etag"], size: 6pt)
  cdraw.line((4.8, 6.1), (4.8, 5.3), stroke: luma(100), mark: (end: ">>"))
  pane(0.6, 9.0, 5.2, [the 304 lane], [etag matches,], [empty body, ch34])
  cdraw.content((4.8, 3.9), [stale or absent: fresh 200], size: 6pt)
  cdraw.content((15.4, 7.3), [the layer answers], size: 6.5pt)
  cdraw.content((15.4, 6.5), [#"key = method path identity"], size: 6pt)
  cdraw.line((15.4, 6.1), (15.4, 5.3), stroke: luma(100), mark: (end: ">>"))
  pane(11.2, 19.6, 5.2, [the hit lane], [row live: replay,], [the miss fills])
  cdraw.content((10.1, 2.4), [nothing stale is ever served on either lane], size: 6pt)
  cdraw.content((10.1, 1.3), [#"Vary: Authorization, Cookie" is the contract for both], size: 6pt)
})

== lru over a fixed table

Least recently used is one table and one order. In the go chapter the
pairing was a map and a list, and the c pairing is an array and an
intrusive doubly linked list threaded through indexes: every slot
carries its prev and next as indexes into the same array, the head is
the hottest, the tail is the eviction, and the free list is a third
chain of indexes through the same storage. A read detaches its slot
and pushes it to the front, a write takes a free slot or evicts the
tail, and every operation is index arithmetic under the one lock,
nothing allocates and nothing chases a pointer off the heap.

The proof is the scramble, the same test the go lane wrote, restated
over the fixed table: fill to capacity, touch a key from the middle
of the order, and the next insert evicts the true least recently
used row, not the oldest insert. A plain array evicts nothing and the
order never moves, which is the point the pairing exists to make:

#listing("c-os-cloud/api/src/cache_lru.c", first: 79, last: 102, caption: [the read: lazy expiry, the copy, and the hit that moves its slot to the front]) // PIN: cache get

#diagram([a read moves its slot to the front, an insert evicts the tail], length: 13pt, {
  cdraw.content((11.0, 7.5), [the recency list, hottest at the front], size: 6.5pt)
  let node(x, label, hot) = {
    cdraw.rect((x - 1.3, 5.4), (x + 1.3, 6.8), fill: hot, radius: 0.02)
    cdraw.content((x, 6.1), [#label], size: 6pt)
  }
  node(2.0, [d], luma(245))
  node(5.4, [c], luma(235))
  node(8.8, [b], luma(235))
  cdraw.line((8.8, 5.2), (8.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((8.8, 3.9), [read b: to the front], size: 6pt)
  node(12.2, [a], luma(235))
  cdraw.content((12.2, 4.9), [front], size: 6pt)
  cdraw.line((15.0, 6.1), (16.2, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((16.4, 5.4), (18.8, 6.8), fill: luma(220), radius: 0.02)
  cdraw.content((17.6, 6.4), [insert e], size: 6pt)
  cdraw.content((17.6, 5.7), [full], size: 6pt)
  cdraw.line((2.0, 5.2), (2.0, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 6.4, 3.0, [d evicted], [the true lru,], [not the oldest insert])
  cdraw.content((11.0, 1.6), [prev and next are indexes, the free list a third chain], size: 6pt)
})

== ttl beside lru

Lru answers crowding, not age. An entry nobody reads can be least
recently used forever and still hold its bytes, and an entry
everybody reads can be hot long after the origin moved on. The ttl
gives every row an expiry stamped from the caller's now at write
time, and reads check it lazily: an expired row evicts itself on
contact, so every read is its own eviction decision and correctness
never waits for a sweep.

The sweep is for memory, not correctness. It walks the fixed table
once and frees whatever aged out unread, and because the clock is a
value the tests pass in, whole lifetimes run as arithmetic: a row is
live the instant before its expiry, miss the instant of it, and the
sweep at any later moment drops every aged row in one pass. The go
lane needed a synctest bubble for its janitor goroutine, and the
caller-supplied clock makes the same lesson cheaper here:

#listing("c-os-cloud/api/src/cache_lru.c", first: 157, last: 168, caption: [the sweep: one walk over the fixed table, age decides, memory not correctness]) // PIN: cache sweep

#diagram([two clocks push rows out: age and crowding], length: 13pt, {
  cdraw.line((0.8, 4.6), (21.8, 4.6), stroke: luma(140))
  cdraw.content((11.3, 5.6), [row lifetime on the caller's now], size: 6.5pt)
  cdraw.rect((3.0, 3.0), (9.0, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 3.9), [written], size: 6pt)
  cdraw.content((6.0, 3.25), [#"exp = now + ttl"], size: 6pt)
  cdraw.line((9.2, 3.6), (13.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.1, 2.9), [live: hits move it forward], size: 6pt)
  cdraw.line((13.2, 3.6), (17.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.6, 3.0), (21.6, 4.2), fill: luma(225), radius: 0.02)
  cdraw.content((18.6, 3.9), [expired], size: 6pt)
  cdraw.content((18.6, 3.25), [lazy on read, swept unread], size: 6pt)
  cdraw.content((6.0, 1.9), [the whole life is arithmetic on a stepped value], size: 6pt)
  cdraw.content((6.0, 0.8), [no wall clock inside the layer anywhere], size: 6pt)
})

== the stampede and its collapse

Every entry expires eventually, and the moment a hot one does, the
herd arrives together: many concurrent misses, many identical origin
reads, the exact load spike the cache existed to prevent, arriving at
the cold moment. The guard is the previous chapter's singleflight
worn one layer down: a miss fills through the flight keyed by the
cache key, the herd collapses into one origin read, every waiter
receives the same result, and the fill's result is the only thing
that ever writes the row.

Errors do not land in the cache, a failed fill misses again, so an
origin outage cannot be memoized into a sticky failure. The proof is
the parked origin: the test parks the first reader's origin read on
an event, starts the second reader into the open window, closes the
gate only once the flight table holds both, and asserts one origin
run, identical answers, a hit for the next reader with the origin
never re-run, and the outage never stored:

#listing("c-os-cloud/api/src/cache_policy.c", first: 43, last: 67, caption: [the guarded fill: the fill's result is the only writer, failures never land]) // PIN: guarded fill

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
  cdraw.content((15.6, 4.4), [singleflight, ch34's table], size: 6pt)
  cdraw.content((11.3, 2.6), [the fill's result is the only cache writer], size: 6pt)
  cdraw.content((11.3, 1.5), [errors are not memoized: a failed fill misses again], size: 6pt)
})

== invalidation, delete after write

A write changes the origin, and the copies of what it changed are now
wrong. The discipline is delete after write, never update: the writer
drops the affected rows and lets the next read refill them through
the guard. Deleting is idempotent and always safe, the refill is the
single writer the cache already trusts, and updating instead, pushing
the writer's view into the row, sounds cheaper but the writer does
not know what a concurrent reader cached mid-flight, so an update
that lands just before a stale read's own set leaves the wrong value
with a fresh timestamp, the worst of both worlds.

The rule is path plus collection: a write to a member drops the
member's row and the list that reads it, one prefix walk over the
table, and a route outside the write keeps its copy. The failed
writes invalidate nothing, because nothing they would fix is wrong
yet. Path scoping has a stated cost: a grant or revoke under the
roles route changes the roles the member's cached representation
carries, yet touches no cached key, so for up to the entry's ttl the
layer replays the old roles, and a revalidating client can loop on
the stale copy, its etag mismatch sending it down past the
conditional read while the cache below answers with the stored bytes
and the old etag again. The go lane's invalidation is path scoped
the same way, so the window is mirrored, not invented, and closing
it means invalidating from the roles route to the member's prefix,
one deliberate write beyond the rule this lane did not take:

#listing("c-os-cloud/api/src/cache_lru.c", first: 141, last: 155, caption: [delete after write: the prefix drops rows and list together, nothing else]) // PIN: invalidate

#diagram([write to a row: the row and the list go, the refill is the only writer], length: 13pt, {
  let node(x, y, label, fill) = {
    cdraw.rect((x - 2.2, y - 0.8), (x + 2.2, y + 0.8), fill: fill, radius: 0.02)
    cdraw.content((x, y), [#label], size: 6pt)
  }
  node(4.0, 6.4, [list row], luma(235))
  node(4.0, 4.4, [row u1], luma(235))
  node(4.0, 2.4, [row u2], luma(245))
  cdraw.content((10.6, 6.4), [#"PATCH /api/users/u1"], size: 6pt)
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

== what never gets cached

The last decision is the one that prevents the incidents. Credential
routes, login and refresh, carry secrets and must never be replayable
from a copy, and their timing must stay flat, so a cache hit on a
login is wrong twice. Rate limited responses must always reach the
client, because a cached budget answer is a lie about money. And
anything the contract marks no-store is a legal promise, not a hint.
The policy table is deny by default, cacheable only where a row says
so, which makes the exclusion list the empty set of accidents: a new
route opts in or it does not get cached, and no change elsewhere in
the service can flip that.

The cheap check is the one worth keeping in the gate, because the
day someone adds a cacheable row to the wrong route, this is the
test that says which lane they put it in. The suite pins the posture
in three assertions: the two cacheable reads answer their rows, the
login route answers no row, and a key that cannot fit is refused
rather than truncated:

#listing("c-os-cloud/api/tests/test_cache.c", first: 127, last: 135, caption: [the exclusion test: two rows opt in, the login route answers none]) // PIN: policy test

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
  row(0.5, [no row in the table], [a promise in the contract, not a hint])
  cdraw.content((14.0, -0.8), [deny by default: a row opts in, or nothing caches], size: 6pt)
})

sources: rfc-editor.org for RFC 9111 section 5.2 Cache-Control and
section 4.1 Vary, RFC 9110 section 12.5.5 for the response header
semantics, all accessed 2026-09-27, learn.microsoft.com for SRW locks
at the same date, and the singleflight forget-on-completion property
restated from the x/sync v0.22.0 source as the go lane's chapter 24
quotes it. Verified by the cache family suite, 33 checks in
`tests/test_cache.c`, green in `make verify-capi` with the whole
stream at 173 checks across the store, conc, and cache families, the
stampede collapse deterministic on a parked origin and a closed
gate, and every lifetime an arithmetic step on a value the tests
chose.
