#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= concurrency control

The store chapter's compare-and-swap gave one writer the win and the
other the fact. This chapter moves that fact to the http edge and
builds everything around it, re-derived for one thread instead of
many: why node has no locks and still has races, strong etags over the
exact bytes with the conditional GET and the guarded PATCH, the duel
two concurrent PATCHers settle over real tcp, idempotency keys with
stored response snapshots so a retried register replays instead of
double-creating, and the in-flight window a promise map closes.

== one thread, many interleavings

Node executes every statement of js on one thread, so the
shared-memory data race, two writers inside one field with no
ordering, does not exist here. What survives is the race condition,
because `await` is a preemption point. Two async handlers interleaving
at their awaits can read the same row, both compute, both write, and one
update silently vanishes, exactly the lost update the go lane needed
goroutines to stage. The interleave points are countable, everything
between two `await`s is atomic, and that fact is the whole locking
story of this vehicle: no mutexes because no second thread exists, and
still protocols, because interleaving does.

So js needs the same three answers, for a different reason. The
compare-and-swap in the store is the atomic layer. Etags carry
versions to the client. Idempotency keys make retries safe. And the
code that coordinates them leans on the atomic stretch: the keyed
runner below keeps claim and lookup inside one await-free stretch, a
critical section nobody had to lock, because the scheduler cannot
enter it.

#listing("javascript/api/src/conc/guard.mjs", first: 34, last: 42, caption: [the runner head: ungoverned routes pass through, the triple names one flight])

#diagram([one thread, preemption only at awaits], length: 13pt, {
  cdraw.line((0.6, 4.2), (22.4, 4.2), stroke: luma(140))
  cdraw.content((11.5, 5.6), [handler A], size: 6.5pt)
  cdraw.line((2.0, 5.0), (5.0, 5.0), stroke: luma(80))
  cdraw.line((5.0, 5.0), (8.0, 5.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((8.0, 5.0), (12.0, 5.0), stroke: luma(80))
  cdraw.line((12.0, 5.0), (15.0, 5.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 2.9), [handler B], size: 6.5pt)
  cdraw.line((6.0, 2.3), (9.0, 2.3), stroke: luma(80))
  cdraw.line((9.0, 2.3), (12.0, 2.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.0, 2.3), (16.0, 2.3), stroke: luma(80))
  cdraw.content((6.5, 5.6), [#"await"], size: 6pt)
  cdraw.content((12.5, 5.6), [#"await"], size: 6pt)
  cdraw.content((10.5, 2.9), [#"await"], size: 6pt)
  cdraw.content((18.2, 4.9), [dark runs are atomic], size: 6pt)
  cdraw.content((18.2, 3.9), [arrows are the yields], size: 6pt)
  cdraw.content((18.2, 2.9), [B may enter at A's arrow], size: 6pt)
})

== strong etags over the exact bytes

The strong etag of a representation is the sha256 hex of the exact
response body, quoted. The exactness is the contract: the body is
stringified in the contract's member order, insertion order is
serialization order, and one byte of drift is a different
representation, the test proves it by upper-casing one letter of a
frozen body and refusing the equal etag. The frozen vectors carry the
proof the other way: the hash of vector 09's body equals the ETag
header the vector freezes, and vector 11's patched body hashes to its
own header, so the mechanism reproduces the contract's bytes, not
approximately but exactly.

The conditional GET spends the etag. An `If-None-Match` that equals
the current etag answers 304 with the etag stamped and no body, the
client already holds the body the etag names, and a 304 with a body
would poison the client cache into holding the wrong thing for the
wrong reason. Vector 10 freezes that exchange, the same etag in, 304
out. The decision is pure, `null` means run the handler, anything
else is the answer, and stale, absent, or a missing resource all pass
through.

#listing("javascript/api/src/conc/etag.mjs", first: 10, last: 12, caption: [the strong etag: sha256 hex of the exact body, quoted])

#diagram([body bytes to etag to the 304 lane], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 3.9), (x0 + w, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 5.7), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 4.7), [#l1], size: 6pt)
  }
  step(0.3, 4.4, [the exact body], [member order frozen])
  cdraw.line((4.9, 5.1), (5.3, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(5.3, 4.6, [sha256, quoted], [one byte drifts, new etag])
  cdraw.line((10.1, 5.1), (10.5, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(10.5, 5.0, [the 304 lane], [#"If-None-Match equals, no body"])
  cdraw.line((15.7, 5.1), (16.1, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(16.1, 6.2, [vectors 09, 10, 11], [the frozen bytes reproduce])
  cdraw.content((9.0, 2.7), [stale or absent: a fresh 200], size: 6pt)
  cdraw.content((9.0, 1.6), [a 304 with a body would poison the client], size: 6pt)
})

== the duel: two patchers, one version

The unsafe side requires the precondition. `If-Match` is mandatory,
the contract chose 412 over the 428 the RFC suggests, and a value
stale against the current representation refuses the request before
the handler burns its decode. Vector 12 freezes the refusal, code
`precondition_failed`, message "etag mismatch", and the test pins the
message from the vector's own bytes. The fast fail is the cheap layer,
the store's compare-and-swap remains the guarantee, because a route
can exist without the wrapper and the check and the write must still
be one atomic exchange.

The duel stages the whole chain over real tcp: a `node:http` server
mounting the real store, two PATCHers carrying the same valid etag,
fired together through `Promise.all`. Both may pass the fast-fail
check, the check reads the row before either write lands, and the
compare-and-swap still crowns exactly one. The assertion is on the
counts, one 200 and one 412, never the order, and version 2 standing
after, which is what makes the test deterministic under any
interleaving the loop picks.

#listing("javascript/api/test/conc/duel.test.mjs", first: 88, last: 100, caption: [the duel: two shooters, one Promise.all, counts asserted, never order])

#diagram([two patchers, one fast fail, one cas, one winner], length: 13pt, {
  cdraw.content((2.6, 7.4), [writer A], size: 6.5pt)
  cdraw.content((12.4, 7.4), [writer B], size: 6.5pt)
  cdraw.line((0.6, 6.6), (4.6, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((2.6, 5.9), [#"If-Match: the v1 etag"], size: 6pt)
  cdraw.line((10.4, 6.6), (14.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.4, 5.9), [#"If-Match: the v1 etag"], size: 6pt)
  cdraw.rect((4.8, 6.1), (10.2, 7.1), fill: luma(225), radius: 0.02)
  cdraw.content((7.5, 6.8), [the fast fail], size: 6pt)
  cdraw.content((7.5, 6.3), [both may pass it], size: 6pt)
  cdraw.line((4.8, 5.6), (4.8, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.2, 5.6), (10.2, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((3.0, 3.0), (12.0, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((7.5, 4.1), [the cas in one write transaction], size: 6pt)
  cdraw.content((7.5, 3.4), [version check and bump, one statement], size: 6pt)
  pane(14.6, 21.6, 4.6, [A commits], [200, version 2], [the new etag])
  pane(14.6, 21.6, 1.4, [B refused], [412, stale], [retry from v2])
})

== idempotency keys and stored snapshots

A client that times out retries, and a register route that recreates
on retry is a double-charge machine. The contract's answer is the
`Idempotency-Key` header. The exact request bytes are hashed under
sha256, whitespace drift is a different request, and the key is scoped
by route and caller identity, so two clients may use the same key
freely. The first successful run is stored as a snapshot, status,
headers, body, and a later request with the same key and the same
hash replays those bytes at the stored status: vector 02's retried
register returns the original 201, Location and ETag included, byte
for byte.

Two failure paths are as deliberate. The same key under a different
hash is refused with a thrown failure the kernel's one writer renders
at 422, details array beside the code in the writer's member order,
the one place the envelope carries details, and the guard never draws
a body itself. The stored snapshot is untouched. A failing first run
is never stored, a retry after a validation error deserves a fresh
run, not a replayed failure, so only outcomes under 400 become
snapshots.
Keys live for 24 hours in the store chapter's `idem` table, expiry
lazy on read. The reports route is deliberately not on this guard:
replaying a completed job is a read, so a stored 202 upgrades to the
completed report at 200, the one sanctioned divergence, and the test
asserts the upgrade against vector 16's frozen bytes.

#listing("javascript/api/src/conc/guard.mjs", first: 44, last: 54, caption: [the two verdict exits: mismatch throws for the one writer, match replays the snapshot])

#diagram([one key's life: first run, snapshot, replay, refusal], length: 13pt, {
  let node(x, y, title, l1) = {
    cdraw.rect((x - 2.4, y - 1.0), (x + 2.4, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.45), [#title], size: 6pt)
    cdraw.content((x, y - 0.45), [#l1], size: 6pt)
  }
  node(2.8, 5.8, [first request], [#"key k, hash h"])
  cdraw.line((5.2, 5.8), (7.2, 5.8), stroke: luma(100), mark: (end: ">>"))
  node(9.6, 5.8, [run handler], [only on a miss])
  cdraw.line((12.0, 5.8), (14.0, 5.8), stroke: luma(100), mark: (end: ">>"))
  node(16.4, 5.8, [store snapshot], [#"under 400, 24 h"])
  cdraw.line((2.8, 4.6), (2.8, 2.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.2, 3.7), [retry: same key, same hash], size: 6pt)
  node(2.8, 1.8, [replay 201], [stored bytes, verbatim])
  cdraw.line((9.6, 4.6), (9.6, 2.8), stroke: luma(100), mark: (end: ">>"))
  node(9.6, 1.8, [new hash], [422 with details])
  cdraw.line((16.4, 4.6), (16.4, 2.8), stroke: luma(100), mark: (end: ">>"))
  node(16.4, 1.8, [first run 4xx], [not stored, retry fresh])
})

== the in-flight window

The missing half was concurrency, and the window is real even on one
thread. A lookup that misses, a handler that awaits, a save that lands
only after the handler resolves: two callers under the same key inside
that window both miss, both run, and the loser answers the handler's
own conflict for an operation that succeeded and is recorded under its
key. The guard closes the window with a promise map keyed by the same
route, identity, and key triple the stored rows live under. The first
caller claims the slot, runs, and settles a promise on its way out,
and a later caller awaits that promise and reads the settled row
again. The await-free stretch from lookup to claim is the critical
section, one thread cannot enter it, so there is no scheduling window
at all.

The tests hold the window open with a gate, a promise the test
resolves by hand, zero timers, zero sleeps. Two callers under one key
collapse into one handler run and both receive the stored snapshot.
The darker path is pinned too: a waiter whose first run failed, a 422
is never stored, wakes to find no row and proceeds with a fresh run,
so a failed first attempt cannot wedge the key forever. And the map
entry is gone the moment the run settles, so the herd that arrives
after the lull fills again.

#listing("javascript/api/src/conc/guard.mjs", first: 55, last: 76, caption: [claim or wait: first caller runs and settles, later callers await then re-read])

#diagram([the window, closed by a promise map], length: 13pt, {
  cdraw.rect((0.8, 4.0), (9.6, 5.6), fill: luma(225), radius: 0.02)
  cdraw.content((5.2, 5.1), [the promise map], size: 6pt)
  cdraw.content((5.2, 4.4), [#"route + identity + key to promise"], size: 6pt)
  cdraw.line((5.2, 3.9), (5.2, 3.2), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 5.0, 3.0, [first caller], [claims, runs,], [settles the promise])
  cdraw.line((11.0, 2.4), (11.4, 2.4), stroke: luma(100), mark: (end: ">>"))
  pane(11.6, 17.2, 3.0, [later caller], [awaits, re-reads], [the settled row])
  cdraw.line((17.4, 2.4), (17.8, 2.4), stroke: luma(100), mark: (end: ">>"))
  pane(18.0, 22.6, 3.0, [no row], [a failed run], [proceeds fresh])
  cdraw.content((11.3, 6.4), [lookup to claim is await-free: the critical section], size: 6pt)
  cdraw.content((11.3, 1.2), [the entry is forgotten on settle, the next wave fills], size: 6pt)
})

== the reports route over the wire

The reports pair is the conc family's own route. `POST /api/reports`
runs the ladder the contract orders: the actor first, 401 with no
identity, the `Idempotency-Key` second, 422 with one detail when it is
missing, then the body read once under the codec's cap with the exact
bytes hashed before anything else looks at them, the strict member set
so an unknown member is a decode failure, and the window rules, one
detail per broken rule, kind, day shapes, ordering, with days checked
as real calendar days because 2026-13-99 has the right shape and no
day behind it.

The interesting half is what the route does not need. From the lookup
to the save, miss, insert the pending report row, store the 202
snapshot under the key, the whole exchange is one synchronous
stretch, no `await` anywhere inside it, so the single thread makes it
atomic and the concurrent double submit simply serializes: the second
caller's lookup reads the first caller's row and replays. The register
guard needed a promise map because its handler awaits, the reports
route needs nothing because it does not. `GET` computes the series on
first read and flips the row to done, and the replay answers the
upgraded 200, vector 16 walked end to end over a real kernel app with
the identity seam stubbed at the same layer the composition mounts:

#listing("javascript/api/src/conc/reports.mjs", first: 105, last: 125, caption: [the create ladder: actor, key, exact-byte hash, strict bind, window rules])

#diagram([claim to settle with no await inside: the loop cannot enter], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 3.9), (x0 + w, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 5.7), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, 4.7), [#l1], size: 6pt)
  }
  step(0.3, 4.2, [lookup], [miss, match, mismatch])
  cdraw.line((4.7, 5.1), (5.1, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(5.1, 4.6, [insert pending], [the report row])
  cdraw.line((9.9, 5.1), (10.3, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(10.3, 5.2, [save snapshot], [the 202 under the key])
  cdraw.line((15.7, 5.1), (16.1, 5.1), stroke: luma(100), mark: (end: ">>"))
  step(16.1, 6.2, [answer 202], [Location plus the body])
  cdraw.content((9.0, 2.7), [one synchronous stretch, no promise map needed], size: 6pt)
  cdraw.content((9.0, 1.6), [a second caller serializes after it and replays], size: 6pt)
})

sources: nodejs.org/api/crypto.html for `createHash` and the sha256
digest contract, accessed 2026-09-26, nodejs.org/api/http.md for the
duel's `node:http` server, accessed 2026-09-26, nodejs.org/api/test.md
for `mock.fn` and the timer discipline the gates replace, accessed
2026-09-26, and the `If-Match` and `If-None-Match` semantics read from
developer.mozilla.org/docs/Web/HTTP/Headers with RFC 9110 sections
13.1.1 and 13.1.2 at rfc-editor.org, accessed 2026-09-26. Verified by
`books/javascript/api` tests, 28 of them in `test/conc`, the duel over
real tcp and the vector 16 route walk included, under `node --test` in
`npm run verify`.
