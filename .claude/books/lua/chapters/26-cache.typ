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
price. This chapter prices it in the platform's own currency: the lru
as two plain tables, because lua has no container library to lean on,
the ttl as arithmetic on an injected clock, the vary pair in the key
so two identities never share an entry, the guarded fill that
memoizes successes only, invalidation as delete after write scoped by
path, and the exclusion table that makes caching opt-in rather than a
default someone must remember to turn off.

== the lru in two tables

Least recently used needs two structures that agree. The map finds
any key in constant time, the links carry the recency order, and in
lua both are tables: every entry is a node with `prev` and `next`
fields pointing at its neighbors, the map points at nodes, and each
node carries its own key so eviction can drop it from the map without
walking the map. Two sentinels, `head` and `tail`, close the list so
the front and back cases need no branches of their own. A write
inserts at the front, a read moves its node to the front, and when
capacity is exceeded the node at `tail.prev` is the eviction, found
and removed in constant time.

The proof is the scramble test: fill to capacity, touch the oldest
insert so it becomes the hottest, and the next insert evicts the true
least recently used entry instead. The count rides a plain field,
maintained at every insert, evict, and lazy expiry, because lua's
`#` operator on a hash of nodes is a length nobody promised, and the
op-stream test pins both invariants at once, the count never exceeds
capacity across two hundred seeded operations and a walk over the
links from `head` to `tail` visits every key the map holds exactly
once:

#listing("lua/service/cache.lua", first: 71, last: 89, caption: [the pairing: the map finds, the links order, the node carries its key])

#diagram([a read moves its node to the front, an insert evicts the back], length: 13pt, {
  cdraw.content((11.0, 7.5), [the links, hottest at the front], size: 6.5pt)
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
  cdraw.content((11.0, 1.6), [two plain tables, sentinels close the list, O(1) everywhere], size: 6pt)
})

== ttl with the injected clock

The lru answers crowding, not age. An entry nobody reads can be least
recently used forever and still hold its bytes, and an entry
everybody reads can stay hot long after the origin moved on. The ttl
stamps an expiry from the injected clock at write time, and reads
check it lazily: an expired entry deletes itself on contact, so every
read is its own eviction decision. A re-put refreshes both the value
and the expiry, and the arithmetic is exact, one millisecond short of
the ttl the entry still answers, at the ttl it is gone.

No sweep exists anywhere, and that is a platform fact rather than a
design choice: the vm has no background thread to run a janitor on,
so an entry nobody reads leaves either by contact, when some request
finally asks for it, or under capacity pressure, when crowding evicts
it like any other cold entry. The test states the honest cost in two
lines, both entries aged out and unread still hold their bytes, and
the next insert evicts one while the other waits for a contact that
deletes it. Nothing waits for a timer, and no test sleeps:

#listing("lua/service/cache.lua", first: 55, last: 69, caption: [the read: lazy expiry, delete on contact, move to front])

#diagram([two clocks push entries out: age and crowding], length: 13pt, {
  cdraw.line((0.8, 4.6), (21.8, 4.6), stroke: luma(140))
  cdraw.content((11.3, 5.6), [entry lifetime on the injected clock], size: 6.5pt)
  cdraw.rect((3.0, 3.0), (9.0, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 3.9), [written], size: 6pt)
  cdraw.content((6.0, 3.25), [#"expiry = clock() + ttl"], size: 6pt)
  cdraw.line((9.2, 3.6), (13.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.1, 2.9), [live: hits move it forward], size: 6pt)
  cdraw.line((13.2, 3.6), (17.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((15.6, 3.0), (21.6, 4.2), fill: luma(225), radius: 0.02)
  cdraw.content((18.6, 3.9), [expired], size: 6pt)
  cdraw.content((18.6, 3.25), [lazy on read, or evicted unread], size: 6pt)
  cdraw.content((6.0, 1.9), [no janitor: the vm has no background thread], size: 6pt)
  cdraw.content((6.0, 0.8), [no timer, no sleep, arithmetic on an injected clock], size: 6pt)
})

== vary and the cache key

A private api's representation depends on who is asking, and the vary
pair names that dependency: the authorization header and the session
cookie. The cache key carries the path plus each vary value in fixed
order, so two identities never share an entry and the same identity
shares across requests that present the same pair. The key uses the
values themselves rather than a derived identity, because the promise
is about what was asked, not about who the router decided was asking,
and the fixed order makes the key a pure function of its inputs, the
same request always building the same key.

The wire states the same contract through the `Vary` response header,
and the two must agree: the header tells any client-side cache which
request headers the representation varies by, the layer's key list is
the same fact stated in code. A body that varies by identity without
a vary key is a cross-user leak waiting for traffic, and the pairing
test pins the shape, two tokens on one path, two entries, no
bleed-through either way:

#listing("lua/service/cache.lua", first: 11, last: 21, caption: [the vary pair and the key, fixed order, values not identities])

#diagram([one path, two identities, two entries], length: 13pt, {
  cdraw.content((4.6, 7.4), [#"GET /api/users/u-1"], size: 6.5pt)
  cdraw.line((3.0, 6.6), (3.0, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((3.0, 5.1), [#"Authorization: tok-a"], size: 6pt)
  cdraw.line((6.4, 6.6), (6.4, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.4, 5.1), [#"Authorization: tok-b"], size: 6pt)
  cdraw.rect((1.2, 3.2), (5.0, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.1, 4.1), [entry for a], size: 6pt)
  cdraw.content((3.1, 3.5), [#"u-1|tok-a|"], size: 6pt)
  cdraw.rect((5.4, 3.2), (9.2, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((7.3, 4.1), [entry for b], size: 6pt)
  cdraw.content((7.3, 3.5), [#"u-1|tok-b|"], size: 6pt)
  cdraw.content((15.6, 5.6), [the same fact on the wire:], size: 6pt)
  cdraw.content((15.6, 4.7), [#"Vary: Authorization, Cookie"], size: 6pt)
  cdraw.content((15.6, 3.5), [no shared entry, no leak], size: 6pt)
  cdraw.content((9.0, 1.6), [fixed order: the key is a pure function of its inputs], size: 6pt)
})

== the guarded fill

A miss runs the loader, and the guard decides what the miss may
leave behind: only a 200-shaped answer memoizes, so an origin error
never becomes a sticky failure, a refused fill misses again on the
next ask and the origin gets another chance. The verdicts are named
at the call, `hit`, `filled`, `refused`, and the hit answers from the
copy without the loader running at all.

The other lanes wrap this fill in singleflight because a hot expiry
means a herd of identical origin reads. This vm cannot have that
herd: one instruction stream, no preemption point between the miss
and the fill, so the first request to miss is necessarily the only
one running until it lands. The chapter states the divergence rather
than building the missing machinery, and the single-writer discipline
survives it, the fill's result is the only thing that ever writes the
entry, so an error can never be parked in the copy by a second hand:

#listing("lua/service/cache.lua", first: 97, last: 106, caption: [the fill: a hit answers, a 200 stores, anything else refuses])

#diagram([one miss, one fill, the guard at the exit], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 4.0), (x0 + w, 6.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 5.5), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 4.6), [#l1], size: 6pt)
  }
  step(0.3, 4.2, [the ask], [a read on the layer])
  cdraw.line((4.7, 5.1), (5.1, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(5.3, 4.4, [miss], [the only runner])
  cdraw.line((9.9, 5.1), (10.3, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(10.5, 4.6, [the loader], [the origin read])
  cdraw.line((15.3, 5.1), (15.7, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(15.9, 6.4, [the guard], [200 stores, else refuses])
  cdraw.content((8.9, 2.9), [no herd: one instruction stream owns the miss], size: 6pt)
  cdraw.content((8.9, 1.8), [a refused fill misses again, never memoized], size: 6pt)
  cdraw.content((8.9, 0.7), [single writer: the fill is the only hand that stores], size: 6pt)
})

== path-scoped invalidation on write

A write changes the origin, and the copies of what it changed are now
wrong. The discipline is delete after write, never update: the writer
drops the affected entries and the next read refills through the
guard. Deleting is idempotent and always safe, updating instead
pushes the writer's view into the entry, sounds cheaper, and leaves
the wrong value carrying a fresh timestamp the moment any raced
ordering lands, the worst of both worlds. The refilled copy always
reads the origin's current truth, and the staged test spells the
whole arc, a stale copy answers, the write drops it, the refill reads
new.

The rule is path plus collection. A write to a row drops the row
entry, the collection that reads it, and any child under it. A write
to a collection drops the collection and everything beneath it. The
sibling row survives a row write, the reports entry survives a users
write, and the drop count rides home so the caller can state what it
invalidated. The staleness window is stated honestly and not
apologized for: a role grant leaves the member's cached object stale
to ttl, because the grant writes roles and the cache holds the user
representation, and a revalidating client can loop on the stale copy
until age takes it. The other lanes pay the same price with the same
scoping, and the fix is the same everywhere, invalidate what the
write touched and accept the window on what it did not:

#listing("lua/service/cache.lua", first: 108, last: 125, caption: [delete after write: the row, its collection, its children, nothing else])

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
  cdraw.content((17.5, 0.7), [a role grant leaves the object stale to ttl], size: 6pt)
})

== what never caches

The last decision is the one that prevents the incidents, and the
shape is a table that denies by default: a route is cacheable only
where the predicate says so, and nothing else in the service can flip
that by accident. The predicate governs the object read route only.
The list family is not acted on by the running service, the row
policy states that boundary instead of hiding it, and a future wave
that wants the list cached changes one predicate and owns the
invalidation that comes with it.

The exclusions carry reasons. Credential routes carry secrets and
must never be replayable from a copy, and the policy already refuses
them, they are not GET. Rate-limited answers must always reach the
client, because a cached budget answer is a lie about money, and the
fill's guard is the second wall, a 429 never memoizes. A
personalized body without a vary key is a cross-user leak, and the
vary section closed that door. Everything else answers from the
origin every time, and the cheap check is the one worth keeping in
the gate, because the day someone widens the predicate by accident,
this is the test that names the lane they put it in:

#listing("lua/service/cache.lua", first: 23, last: 30, caption: [the policy: one object route opts in, everything else denies])

#diagram([the exclusion rows, each with its reason], length: 13pt, {
  let row(y, route, reason) = {
    cdraw.rect((0.6, y), (22.2, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.0, y + 0.75), [#route], size: 6pt)
    cdraw.content((14.0, y + 0.75), [#reason], size: 6pt)
  }
  cdraw.content((5.0, 7.5), [route], size: 6.5pt)
  cdraw.content((14.0, 7.5), [why it never caches], size: 6.5pt)
  row(5.6, [#"POST /api/auth/login"], [secrets, and timing that must stay flat])
  row(3.9, [#"POST /api/auth/refresh"], [credential rotation, replay is theft evidence])
  row(2.2, [429 answers, any route], [the budget must reach the client])
  row(0.5, [the list family], [not acted on, the boundary the policy states])
  cdraw.content((14.0, -0.8), [deny by default: one predicate opts in, or nothing caches], size: 6pt)
})

sources: rfc-editor.org for RFC 9111 section 5.2 Cache-Control
directives and RFC 9110 section 12.5.5 Vary, with the no-store
promise of RFC 9111 section 5.2.1.5, accessed 2026-09-27, lua.org
manual 5.5 sections 2.1 and 3.4.9 for tables as references and the
length operator's promise on sequences, accessed 2026-09-27, and the
staleness window statement restated from this book's c-os-cloud
chapter 35 as the cross-lane ruling it is. Verified by
`books/lua/service/cache.lua`, 11 checks on the plain pin, the
scramble, the ttl arithmetic, the vary pairing, the guarded fill, the
two invalidation rules, the policy table, and the op-stream capacity
invariant, green in the plain lane's runner.
