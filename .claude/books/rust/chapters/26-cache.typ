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

A cache is a promise with two prices. The promise is freshness inside a
stated window, the first price is memory, which must be bounded, and
the second price is the stampede, the crowd of concurrent misses that
all decide to fill the same key and hammer the handler they were
supposed to protect. This chapter builds both answers in
`rustapi::cache`: a bounded table of expiring entries over one mutex,
and a single flight so one fill runs per key no matter how many
callers arrive together. The snapshot type is chapter 25's, the same
status, headers, and body triple the idempotency store replays, and
that reuse is the point: one stored-response shape serves both
chapters. The go book built its layer over `container/list` and
`golang.org/x/sync`, #xref-to("go", "cache"), the java book over one
`ConcurrentHashMap` with a deadline-rank eviction, #xref-to("java",
"cache"), and this lane takes java's rank with go's wire posture, the
std collections, and nothing else.

#diagram([the two prices and their two answers], length: 13pt, {
  pane(0.3, 7.3, 7.8, [the promise], [fresh within a window], [every entry carries its deadline])
  cdraw.line((7.5, 6.2), (7.9, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(8.1, 15.3, 7.8, [price one: memory], [a bound, an eviction rank], [dead first, then soonest to die])
  cdraw.line((15.5, 6.2), (15.9, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(16.1, 22.9, 7.8, [price two: the herd], [one flight per key], [waiters share the one fill])
})

== ttl from first principles, lazy on the read

An entry carries its own deadline, and the read is its own eviction
decision: a deadline that has passed means the entry is gone, removed
by the very read that noticed it, and no thread ever wakes on a timer
to do the same work. The clock is injected, a millis counter the whole
plane shares, so every boundary test is arithmetic:

#listing("rust/api/src/cache.rs", first: 42, last: 52, caption: [the read: live values only, the noticing read reaps, the boundary at-or-after means gone])

The boundary is exact and the test pins it: an entry with a 100 ms ttl
answers at 99 and is dead at 100, `now < expires_at` with no tolerance
and no rounding, and after the noticing read the table holds one fewer
entry, the corpse never answers twice. A ttl of zero or less is
refused by `set` before anything is written, an entry born dead is a
defect, not a policy, and the constructor refuses a bound of zero the
same way, a table that holds nothing cannot serve.

== the bound and the eviction rank

Memory is capped at `max_entries`, and a new key arriving at a full
table makes room in a fixed order. First the dead: the same retain the
sweep runs reclaims every expired entry for free, because a corpse is
space nobody is owed. Then, when everything held is live, the entry
dying soonest goes, the one whose remaining life is shortest, so the
table sheds what it was about to lose anyway:

#listing("rust/api/src/cache.rs", first: 54, last: 87, caption: [the write: replace refreshes in place, the dead are swept before any live one, then the soonest deadline is the victim])

That rank is java's, not go's, and the trade deserves its sentence. An
lru list tracks access order with a queue every read must move, and
its payback needs a workload that revisits old keys, while the
deadline the entry already carries is a free eviction rank whose
behavior deterministic tests pin exactly. The edge table is the
contract: a full table of three with deadlines 100, 50, and 200 loses
the 50 on the fourth insert, a dead entry is swept in preference to
any live one, and replacing an existing key refreshes its value and
its deadline without evicting a neighbor, because a replace is not an
admission. The eviction scan is linear in the table and runs only when
a new key arrives at a full table of live entries, the same cost the
java chapter owned at book scale, with the shard and the deadline heap
named there as the escape hatches here.

== the eager sweep

Lazy expiry keeps correctness, every read reaps what it notices, and
correctness is not memory discipline: an unread hot key squatting on
its bytes forever is invisible to the read path. The eager half is one
function the wiring can drive on a cadence, the same retain under the
same lock, answering how many it took:

#listing("rust/api/src/cache.rs", first: 89, last: 101, caption: [sweep and delete_matching: the same retain twice, one for the janitor, one for invalidation])

Go ran its sweep on a ticker inside the cache itself and exercised the
janitor's whole life in a synctest bubble, and java declined the timer
entirely. The rust lane splits the difference the wiring decides: the
sweep is a plain method, the main of chapter 27 spawns one thread that
sleeps and sweeps, and no test ever needs the thread because the
method is the contract and the clock is injected. The sweep test reaps
one of three unread entries at a chosen tick and answers zero the
second time, nothing left to reap.

== single flight, one fill per key

The stampede, precisely: a popular key expires, 8 requests miss in the
same instant, and each one innocently walks the handler because each
innocently observed a miss. The fix is one flight per key. The first
caller registers a slot in the flight map and becomes the filler,
every caller that arrives while the fill runs parks on the slot's
condvar, and when the fill lands the entry is stored and every parked
caller wakes into the stored value:

#listing("rust/api/src/cache.rs", first: 112, last: 116, caption: [the slot: a done flag, a condvar, and a parked count the tests read])

#listing("rust/api/src/cache.rs", first: 144, last: 179, caption: [get_or_fill: hit first, register under the lock, fill outside every lock, store before done, the waiter's recheck])

Two rules carry the weight. The fill runs outside every lock, a fill
that held the flights mutex would serialize every unrelated key behind
one slow handler, the same reason java kept its loader out of
`computeIfAbsent`'s bin lock, and rust's one-liner for that lesson is
that the closure runs between `register` and the store with nothing
held. And the store happens before `done` is set, which is the whole
correctness argument for the waiter's recheck: a parked caller wakes
only after the flag flipped, the flag flipped only after the store,
so the table read the waiter performs next must find the entry, unless
the fill failed and stored nothing, which is the next section. The
`retire` removes the key only when the map still holds this slot,
`Arc::ptr_eq`, so a fresh flight a late arrival may have started is
never clobbered, and the next wave after a lull starts a new flight,
which is what keeps the plane a guard and not a second cache:

#listing("rust/api/src/cache.rs", first: 181, last: 213, caption: [register and retire: present means join, absent means start, retirement checks the pointer, waiting_on reads the parked count])

The collapse test is counted, not timed. The fill blocks on a channel
it controls, 8 callers arrive, and the test watches `waiting_on` until
exactly 7 are parked, program state, not a stopwatch. The release
lands the fill, all 8 callers answer the identical stored body, the
fill counter reads exactly 1, and the table holds exactly 1 entry.

#diagram([the herd collapsed: one fill, seven parked, everyone served from the store], length: 13pt, {
  cdraw.content((11.5, 9.4), [8 concurrent misses on one key], size: 6.5pt)
  pane(0.3, 7.3, 7.4, [caller 1], [registers the slot], [fills outside every lock])
  pane(8.0, 15.0, 7.4, [callers 2 to 8], [park on the condvar], [waiting_on reads 7])
  pane(15.7, 22.7, 7.4, [the fill lands], [store, then done, then wake], [all 8 served, 1 execution])
  cdraw.line((7.5, 5.6), (7.9, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((15.2, 5.6), (15.6, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 2.6), [uncoordinated: 8 fills. here: 1, counted], size: 6pt)
})

== the recheck window and the failed fill

A failed fill is never stored. The waiter wakes into a table that
still misses, loops, and registers again, so the herd that waited on a
failure re-runs the fill serially, at most one at a time, never
concurrently, the same settle semantics the go lane chose and the java
lane declined in favor of sharing the error. Sharing the failure
saves the recomputes and teaches every rider the origin's error,
recomputing keeps every rider's answer its own, and the rust lane
follows go because the idempotency flight of chapter 25 already made
the same call one module over. The test drives the failure lane
exactly: a loader that fails once answers the error, the table holds
zero entries, the next call refills to a success, and the call after
that answers from the store with the loader never reached, 2 attempts
in total across the three calls.

== the layer at the wire

The plane becomes a layer over the router for the governed patterns,
the same `match_pattern` the authz guard reads, and the lane order is
the whole policy. A governed GET without a conditional header hits the
table first, a hit answers the snapshot with `x-cache: hit`, a miss
fills under the flight and answers `x-cache: miss`, both stamped with
`cache-control: private, max-age=0, must-revalidate` and
`vary: authorization`, because the key folds the actor in beside the
path and the vary header is the wire telling the truth about the key:

#listing("rust/api/src/cache.rs", first: 243, last: 248, caption: [the key: path and actor, one nul between, identities never share an entry])

#listing("rust/api/src/cache.rs", first: 291, last: 325, caption: [the serve: hit, miss, the conditional bypass, writes invalidate on success, everything else no-store])

A conditional GET carries `if-none-match` and skips the snapshot
entirely, the handler answers its own 304 with a bodyless response and
no `x-cache` at all. The go layer served its cached 200 to a
conditional request, the entry short-circuited the handler before its
own revalidation could run, and this lane declines that: the 304 saves
the body, the cache saves the rebuild, and letting the conditional
request through composes them without a cached 200 ever answering a
client that asked a question. The composition is safe because chapter
25 computes the etag, a stored representation and a fresh one carry
the same digest, so nothing the layer does can make a 304 lie.

Writes do better than waiting out the ttl. A non-GET, non-HEAD
response under 400 invalidates the path it touched, the written path
itself, its parent collection, and any child under it, the delete
that is idempotent against the update that can leave a stale window
mid-flight. Everything else, ungoverned GETs included, answers
`private, no-store`, a private api caches nothing unless a route says
otherwise:

#listing("rust/api/src/cache.rs", first: 215, last: 228, caption: [invalidate: the path, the parent, and the children, dropped by one retain])

The wire test drives the whole lane over a real socket with a counter
in the handler: miss, hit off one execution, the conditional 304
bypassing with the counter moving, the hit still standing after the
bypass because the bypass never touched the table, the PUT answering
no-store and emptying the table to zero, and the next GET refilling.
The invalidation test holds four keys and drops exactly the three the
geometry names, the entry, its child, and the parent collection, with
the unrelated key untouched.

== the count

The module is 325 lines and its test file 404, and the 12 tests land
green three consecutive runs under the full gate, fmt, clippy at
`-D warnings`, the locked offline build, dated 2026-10-14: the exact
tick, the refused zero ttl and the refused zero bound, the eager sweep
count, the deadline rank, the dead-before-live room, the replace
without eviction, the counted 8-to-1 collapse with 7 observed parked,
the failed fill refilled, the invalidation geometry, the wire lane,
the no-store default, and the error arms carrying the route policy.
The crate holds 128 tests this wave, the 116
landed ones green unchanged.

sources: RFC 9111, HTTP Caching, section 3 on storing responses and
section 5.2 on the no-store and private directives at rfc-editor.org,
accessed 2026-10-14, and RFC 9110 section 12.5.5 for the Vary field
the governed responses carry, same access date. The lazy-reap read,
the deadline-rank eviction, the
single-flight ordering argument, and the failed-fill policy follow the
java book's cache chapter, book 4 chapter 26 of this corpus, and the
wire posture, the hit and miss marks, the vary-keyed layer, and
delete-after-write invalidation follow the go book's cache chapter,
book 4 chapter 25, read for the parallel contracts. The 8-to-1
collapse, the parked count of 7, and the sweep counts produced by
`cargo test --locked` under `CARGO_NET_OFFLINE=true` on the pinned
1.99.0 build, three consecutive green runs, dated 2026-10-14.
