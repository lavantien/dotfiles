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

The store chapter's guard gave one writer the win and the loser the
fact. This chapter moves the fact toward the wire and builds the
platform's own version of everything around it: the etag duel two
writers settle on one version, the conditional read that answers 304
before a body is spent, and the idempotency store that turns a
retried register into a replay instead of a second create. The other
lanes buy determinism with machinery, barriers to release writers
together, singleflight to collapse a herd, locks to keep tables
honest. This vm has one instruction stream, so those problems do not
arise here, and the chapter says so plainly where the machinery is
absent, as the platform's own lesson rather than an apology.

== the duel: two writers, one version

Two clients read the same user, both hold the etag of version 1, and
both patch. The wire answers in layers, and the store's guard is the
layer that is atomic. The pure precondition ladder this chapter lands
refuses a missing or stale `If-Match` before any decode burns, the
same decision the middleware chain will carry at the edge, and a
handler can check again because a route can exist without the edge.
The store's `user_patch_cas` is the guarantee: the read that decides
and the guarded write share one instruction stream here, and the
where clause still carries the version, the seat the invariant keeps
on any host that ever threads this code.

The duel rides the real store, so its suite lives in the jit lane
where the store lives. There is no barrier object, because the vm
never preempts: the test's own resume order is the schedule, every
order is a legal one, and the guard is the arbiter. The choreography
is three writer coroutines created around one shared read, resumed in
the order the test names, and the outcome is a fact about the guard,
never about the schedule:

#listing("lua/service/store_jit.lua", first: 336, last: 353, caption: [three writers around one shared read, resumed in the test's order])

Exactly one writer carries home the bumped row, the other two answer
the version sentinel the handler renders as the 412 the contract
freezes, and the row stands at version 2 after every run.

#diagram([two etags read at v1, the guard crowns one], length: 13pt, {
  cdraw.content((2.6, 7.4), [writer A], size: 6.5pt)
  cdraw.content((12.4, 7.4), [writer B], size: 6.5pt)
  cdraw.line((0.6, 6.6), (4.6, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((2.6, 5.9), [#"If-Match: v1"], size: 6pt)
  cdraw.line((10.4, 6.6), (14.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.4, 5.9), [#"If-Match: v1"], size: 6pt)
  cdraw.rect((5.6, 6.1), (9.4, 7.1), fill: luma(225), radius: 0.02)
  cdraw.content((7.5, 6.8), [the schedule], size: 6pt)
  cdraw.content((7.5, 6.3), [a resume order, no barrier], size: 6pt)
  cdraw.line((4.8, 5.6), (4.8, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.2, 5.6), (10.2, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((3.0, 3.0), (12.0, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((7.5, 4.1), [the version guard in the where clause], size: 6pt)
  cdraw.content((7.5, 3.4), [read, check, write guarded], size: 6pt)
  pane(14.6, 21.6, 4.6, [A commits], [200, version 2], [a fresh etag])
  pane(14.6, 21.6, 1.4, [B refused], [412, version sentinel], [retry from v2])
})

== the conditional read answers 304

The read side of the same coin costs nothing when nothing changed. A
GET carrying an `If-None-Match` that matches the representation the
resource wears right now answers 304 Not Modified, the body is never
marshaled, and the client keeps the copy the etag names. Both
preconditions are pure functions over two strings, the header the
client sent and the etag the resource wears, so the whole wire
decision is testable as arithmetic:

#listing("lua/service/idem.lua", first: 21, last: 32, caption: [the 304 ladder: absent, star, list membership, fresh])

Four decisions in order. No header means an ordinary read. A header
against a resource that is gone passes through, so the handler's own
404 answers and the precondition never invents a status. A list
matches when any member equals the current etag. Only the match
answers 304, with the etag stamped and an empty body, because a 304
with a body would teach the client to cache the wrong thing for the
wrong reason. The write side is the same shape one section up:
`check_if_match` answers `missing` for an absent header, accepts
`*` against any live representation, and answers `stale` for a value
the row no longer wears and for any value on a gone row, because the
precondition is about the write, never the read.

One line on the wire itself: the contract and the frozen vectors pin
single exact etags, and the handlers implement exactly that
equality, the go mirror byte-identical on every pinned case -- a
list-bearing `If-None-Match` reads as no match and answers the full
200, a star `If-Match` fails the equality and answers 412 -- while
the two ladders above remain the vocabulary a contract with lists
and stars would wire.

#diagram([the conditional GET decision], length: 13pt, {
  let step(y, q, yes, no) = {
    cdraw.content((6.0, y), [#q], size: 6pt)
    cdraw.content((2.9, y - 0.6), [#"no: " + no], size: 6pt)
    cdraw.content((9.7, y - 0.6), [#"yes: " + yes], size: 6pt)
  }
  step(7.0, [If-None-Match present?], [], [ordinary read])
  cdraw.line((6.0, 6.6), (6.0, 5.9), stroke: luma(100), mark: (end: ">>"))
  step(5.6, [resource exists?], [], [pass through, handler 404s])
  cdraw.line((6.0, 5.2), (6.0, 4.5), stroke: luma(100), mark: (end: ">>"))
  step(4.2, [a member equals the etag?], [fresh read, 200], [])
  cdraw.line((6.0, 3.8), (6.0, 3.1), stroke: luma(100), mark: (end: ">>"))
  pane(2.2, 9.8, 3.0, [304], [etag stamped,], [empty body])
  cdraw.content((13.5, 4.2), [two pure functions over two strings], size: 6pt)
  cdraw.content((13.5, 3.1), [no marshal, no store read on the match], size: 6pt)
})

== the idem store and the replay contract

A client that times out retries, and a register route that recreates
on retry is a double-charge machine. The contract's answer is the
`Idempotency-Key` header, and the composition ruling for this service
is that one layer owns every idempotency decision: the scope triple,
route, identity, key, is composed inside `idem.lua` and nowhere else,
and no handler keeps an inline check. The exact request bytes are
hashed, whitespace drift is a different request, and the verdict is
one of three answers. A miss runs the handler. A replay returns the
stored snapshot at the stored status, the retried register answers
its original 201 with the same bytes, `Location` and `ETag`
included. A mismatch, the same key under a different hash, is the
422 with details, the client misusing the contract, and the stored
snapshot is untouched by the refusal:

#listing("lua/service/idem.lua", first: 54, last: 65, caption: [three verdicts, and the expired row deletes itself on contact])

Two guardrails ride the store. Only outcomes under 400 become
snapshots, because a retry after a validation error deserves a fresh
run, never a replayed failure. And expiry is lazy against the
injected clock: an expired row deletes itself on contact, so
correctness never waits for a sweep, and no sweep exists anywhere,
because the vm has no background thread to run one. The rows are a
lua table, and the boundary is stated rather than hidden: replays
live exactly as long as the vm, this lane's answer where the c lane
persists idem rows in sqlite. The backstop behind that boundary is
the store itself, the register group's email claim, so a key lost to
a restart degrades to a correct 409, never a double create.

The reports routes replay through the same layer with one sanctioned
divergence, and the divergence stays handler logic, never store
logic: the routes live in their own module beside the store, the idem
row carries the 202 a first submission answered, the report row the
snapshot names decides the replay answer, pending replays the 202 and
a finished job upgrades to the 200 of the completed body, exactly the
pair the frozen vectors pin, byte for byte over the store's
deterministic series.

#diagram([one key's life: first run, snapshot, replay], length: 13pt, {
  let node(x, y, title, l1) = {
    cdraw.rect((x - 2.4, y - 1.0), (x + 2.4, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.45), [#title], size: 6pt)
    cdraw.content((x, y - 0.45), [#l1], size: 6pt)
  }
  node(2.8, 5.8, [first request], [#"key k, hash h"])
  cdraw.line((5.2, 5.8), (7.2, 5.8), stroke: luma(100), mark: (end: ">>"))
  node(9.6, 5.8, [run handler], [only on a miss])
  cdraw.line((12.0, 5.8), (14.0, 5.8), stroke: luma(100), mark: (end: ">>"))
  node(16.4, 5.8, [store snapshot], [#"under 400, ttl stamped"])
  cdraw.line((2.8, 4.6), (2.8, 2.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.2, 3.7), [retry: same key, same hash], size: 6pt)
  node(2.8, 1.8, [replay 201], [stored bytes, verbatim])
  cdraw.line((9.6, 4.6), (9.6, 2.8), stroke: luma(100), mark: (end: ">>"))
  node(9.6, 1.8, [same key, new hash], [])
  cdraw.content((9.6, 1.2), [422 with details], size: 6pt)
  cdraw.line((16.4, 4.6), (16.4, 2.8), stroke: luma(100), mark: (end: ">>"))
  node(16.4, 1.8, [past the ttl], [])
  cdraw.content((16.4, 1.2), [delete on contact, miss again], size: 6pt)
})

== what the single vm buys

The c lane had to build the unlocked-table race before it could lock
it, and the go lane parks a herd on a channel inside singleflight.
Neither problem can exist here, and the reason is not discipline but
physics: one instruction stream means no two bytecodes interleave, so
a table the vm reads and writes cannot be read by anyone else
mid-thought. What the other lanes buy with locks, this platform buys
by having no second reader. The chapter states this as the honest
divergence, singleflight is unnecessary, and the test suite never
spends a sleep proving it.

The gap is still real in one specific sense, and the module stages it
rather than denying it. Coroutines are cooperative, so a yield placed
between the idem lookup and the save opens exactly the window
singleflight exists to close: a second caller sees the same miss, and
the layer has no defense of its own. The vm never places that yield,
no handler yields inside the window, and the seam contract says so.
If the contract is ever broken, the backstop answers, the store's
register group refuses the second create with the email conflict, so
the worst case is a correct 409 and a lost replay, never a double
create:

#listing("lua/service/idem.lua", first: 256, last: 276, caption: [the yield placed in the gap: the window exists only if code opens it])

#diagram([one stream versus a parked coroutine], length: 13pt, {
  pane(0.4, 10.4, 7.2, [the vm's promise], [one instruction stream,], [no preemption anywhere])
  cdraw.line((5.4, 4.6), (5.4, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 10.4, 3.4, [the gap staged], [a yield in the window,], [second caller misses too])
  cdraw.content((13.2, 6.2), [what the other lanes build], size: 6.5pt)
  cdraw.content((16.0, 5.2), [singleflight parks the herd], size: 6pt)
  cdraw.content((16.0, 4.2), [the c lane locks its tables], size: 6pt)
  cdraw.content((16.0, 3.2), [here: no yield in the window,], size: 6pt)
  cdraw.content((16.0, 2.4), [the seam contract], size: 6pt)
  cdraw.content((16.0, 1.2), [backstop: the register group's 409], size: 6pt)
})

== interleavings as scripted resume orders

Every interleaving the other lanes stage with barriers, channels, and
bubbles, this lane stages as a resume order, and the staging is
deterministic by construction: the test names the schedule, the vm
runs it, and no two runs can differ because there is nothing to
differ. The matrix test makes that a named invariant over a replay:
for every legal resume order of the same three writers, the outcome
set is identical, one bump and two refusals, because the schedule an
order picks cannot move a guarded row. Six orders, six identical
verdicts, zero sleeps, and the property is the chapter's whole
argument in one loop:

#listing("lua/service/store_jit.lua", first: 378, last: 391, caption: [six legal orders, one invariant, the schedule cannot move a guarded row])

The replay property runs against the idem layer too, on the plain
lane: a seeded op stream over three keys, and the invariant that the
layer is a pure function of its ops, replaying the stream twice and
asserting every step's verdict matches. Seeded streams, fixed
invariants, no framework, the discipline the testing spine named and
this family keeps.

#diagram([orders in, the same verdict out], length: 13pt, {
  let order(y, l1) = {
    cdraw.rect((0.6, y), (6.2, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((3.4, y + 0.4), [#l1], size: 6pt)
  }
  cdraw.content((3.4, 7.0), [resume orders], size: 6.5pt)
  order(5.4, [A B C])
  order(3.9, [C B A])
  order(2.4, [B A C])
  order(0.9, [three more, all legal])
  cdraw.line((6.4, 3.6), (8.4, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.6, 2.2), (15.4, 5.0), fill: luma(225), radius: 0.02)
  cdraw.content((12.0, 4.4), [the guarded row], size: 6pt)
  cdraw.content((12.0, 3.6), [version is a fact,], size: 6pt)
  cdraw.content((12.0, 2.9), [not a schedule artifact], size: 6pt)
  cdraw.line((15.6, 3.6), (17.6, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(17.8, 22.6, 4.6, [every order], [one bump, two refusals,], [identical verdict sets])
})

sources: rfc-editor.org for RFC 9110 section 13.1.1 If-Match and
section 13.1.2 If-None-Match with the strong validator semantics of
section 8.8.3, the 304 semantics of section 15.4.5, and the
idempotency method property of section 9.2.2, accessed 2026-09-27,
lua.org manual 5.5 sections 2.6 and 6.3 for coroutines, resume, and
yield, accessed 2026-09-27, the singleflight registration semantics
restated from the x/sync v0.22.0 source as the go lane's chapter 24
quotes it, and the c lane's unlocked-table lesson from this book's
c-os-cloud chapter 34. Verified by `books/lua/service/idem.lua`, 9
checks on the plain pin, and the duel and order matrix in
`books/lua/service/store_jit.lua`, 18 checks on the jit pin, both
gates green with zero sleeps.
