#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= concurrency control

The pool of chapter 19 runs up to 32 workers over one shared handler
and the engine of chapter 24 serializes every write behind one mutex,
and still nothing stops two requests from racing on the same resource:
two readers fetch the same version, both write back, and one overwrite
silently wins, the oldest bug in any concurrent system. This chapter
owns the service's answer in `rustapi::conc`, four mechanisms over one
new resource family: strong etags computed from the landed sha256
primitive, `If-None-Match` answered with a 304 and `If-Match` with a
412, idempotency keys that replay a stored response instead of
double-creating, and a version-gated compare-and-swap over the engine
whose commit refuses on version drift. The go book walked the same
territory over `golang.org/x/sync`, #xref-to("go", "conc"), the java
book over its virtual-thread executor, #xref-to("java", "conc"), and
this lane owns the same contracts with the std mutex, the std
condvar, and nothing else.

== the note, and the tag it carries

The user family is read-only at the wire, chapter 21 froze its port at
create, get, and list, so the update story needs a resource this
chapter owns outright. A note is the smallest thing that versions:
an id, a body of at most 512 characters, and a version that starts at
1 and moves only through the swap. The wire writer is deterministic,
the record under `n:rec:` in the engine is the same json, and the etag
is the strong sha256 of those bytes through the primitive chapter 22
already rode for hmac, promoted here to the one public constructor:

#listing("rust/api/src/conc.rs", first: 25, last: 51, caption: [strong_etag over the landed primitive, and the two rfc comparison functions, strong for If-Match, weak for If-None-Match])

The two comparators are the whole of rfc 9110's section 13.1 in code.
`If-Match` runs the strong comparison, the rfc's MUST: a star is true
when any current representation exists, a list is true when the etag
appears in it, and a `W/` form never matches, however close its
opaque bytes. `If-None-Match` runs the weak comparison, the same walk
with the `W/` prefix stripped before the compare, which is the one
word of difference between them and the reason a weak tag can serve a
304 but never guard a write. The test pins both ladders against
hand-built headers, star, list, weak, and stale, and the digest test
asserts the two published values, `e3b0c442...` over the empty input
and `ba7816bf...` over `abc`, re-derived from python 3 `hashlib` on
this machine, dated 2026-10-14, the same independent oracle chapter
21 used for the primitive itself.

#diagram([one hash, two comparison rules], length: 13pt, {
  pane(0.3, 7.3, 7.8, [the representation], [deterministic wire bytes], [sha256 through ch22])
  cdraw.line((7.5, 6.2), (7.9, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(8.1, 15.3, 7.8, [If-Match], [strong: star, list], [W/ never matches])
  cdraw.line((15.5, 6.2), (15.9, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(16.1, 22.9, 7.8, [If-None-Match], [weak: W/ stripped], [a hit answers 304])
})

== the conditional read

The read is one engine get, one etag computation, and one comparison
against the request's `If-None-Match`. A hit answers 304 with the etag
stamped and an empty body, the kernel's own bodyless law from chapter
19 refusing to write a content-length onto the status, and a miss or a
stale header runs the full 200:

#listing("rust/api/src/conc.rs", first: 400, last: 412, caption: [the conditional read: one read, one hash, one weak comparison, 304 bodyless on the hit])

The etag is computed, never stored, which is the property the cache
chapter inherits next: the same record produces the same bytes and the
same digest forever, so nothing can drift between a representation and
its validator. Chapter 21's user route answers the same 304 with the
same construction, and the note route exists because a family with a
writer is needed before the write side of the contract can be pinned.
The test walks the exact lane, the weak lane, the stale lane, and the
unknown id, and the exact lane asserts the 304 carries the etag header
and zero body bytes.

== the guarded write

The write order is the contract: existence first, so an unknown id
answers 404 before any precondition work, then the header requirement,
then the strong comparison, and only then the decode. The missing
`If-Match` answers 412 rather than the 428 rfc 6585 suggests for
repeat-demanding clients, the same choice both sibling lanes made,
because a 412 is the status the precondition rules already speak and
the stricter code would police client behavior rather than resource
state:

#listing("rust/api/src/conc.rs", first: 414, last: 445, caption: [existence, the required header, the strong compare, only then the decode, and the swap at the bottom])

Three refusals live in that order and each costs less than the work it
skips. The missing header refuses before the body is parsed. The stale
etag refuses after one engine read and before the decode. And the
version drift at the bottom is the one refusal no ordering of checks
can eliminate, which is the next section's whole subject. The rfc's
evaluation order in section 13.2.2 is honored exactly: `If-Match` is
tested before the request method runs, false answers 412, and the
star's truth is evaluated at the read, so a writer landing between the
read and the swap still meets the swap's own refusal.

#diagram([three refusals, each cheaper than the work it skips], length: 13pt, {
  pane(0.3, 7.0, 7.8, [existence], [unknown id], [404, one map lookup])
  cdraw.line((7.2, 6.2), (7.6, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(7.8, 14.8, 7.8, [precondition], [header missing or stale], [412, before the decode])
  cdraw.line((15.0, 6.2), (15.4, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(15.6, 22.9, 7.8, [the swap], [version drifted], [412, the only atomic one])
})

== compare-and-swap over the engine

The engine's `put` is atomic on its own, one frame under one lock, but
read-then-put is two lock acquisitions with a window between them, and
the lost update lives exactly in that window. The fix is one gate, a
mutex in `Notes` held across the read, the version check, and the
write, so the compare and the swap become one critical section. The
caller's half is optimistic: read the version, prepare the mutation,
commit against the version read, and refuse on drift:

#listing("rust/api/src/conc.rs", first: 318, last: 334, caption: [the swap under one gate: read the version, refuse the drift, write version plus one, the wal append before the map mutate is the engine's own order])

The proof is the duel. Two writers carrying the same valid etag are
released together by one barrier through the real pool, and every run
answers exactly one 200 and one 412 with version 2 standing after,
five consecutive runs on the pinned build, dated 2026-10-14. Which 412
the loser collects depends on where it was when the winner landed:
the precondition's `etag mismatch` if its read happened after, the
swap's `version drifted under the write, reread and retry` if it
passed the check before, and the test accepts both because both are
honest refusals, the precondition is a gate and never a reservation.
The engine under the gate is the chapter 24 one untouched, and the
restart test reopens the wal to find version 2 survived with its
drift check intact, a stale expect still refused after the process
died between them.

== idempotency keys, the stored response window

A retried post is the client's most ordinary race: the timeout that
hides a 201, the retry that creates twice. The keyed layer answers it
for `POST /api/notes`. A request carrying `Idempotency-Key` has its
exact body bytes hashed, the row looked up under the composite of
route, caller identity, and key, and a stored match replays the
snapshot byte for byte, status, headers, and body. A different body
under the same key is refused with the 422 both siblings chose, and
the window is 24 hours, expired lazily by the read that notices:

#listing("rust/api/src/conc.rs", first: 116, last: 155, caption: [lookup and save: the composite key, the lazy expiry that deletes on the noticing read, the hash carried beside the snapshot])

The flight settles who runs the handler under a key. The first caller
inserts the composite into the flight map and owns a `Releaser` whose
drop removes the entry and wakes the condvar, and a second caller
under the same key while the first runs parks on the condvar instead
of racing the handler into its own conflict:

#listing("rust/api/src/conc.rs", first: 90, last: 104, caption: [the releaser: drop removes the flight and wakes every waiter])

#listing("rust/api/src/conc.rs", first: 157, last: 170, caption: [claim: present means wait until absent, absent means insert and run])

The loop is the settle semantics the go lane taught: a waiter that
woke re-reads the table before it computes, so the stored response the
first caller saved is found and replayed, and only a waiter whose row
is still absent, because the first run failed and stored nothing,
runs the handler itself. Failures are never stored, a status of 400 or
more passes through unstored so a retry after a validation error
deserves a fresh run, and the test drives an invalid body under a key
and then the fixed body under the same key to a fresh 201:

#listing("rust/api/src/conc.rs", first: 188, last: 226, caption: [run_keyed: the loop, replay or refuse or claim, the store before the release])

The concurrent test is counted, not timed: 8 posts under one key
through the real pool all answer 200 with the identical body
`{"run":1}`, and the handler's counter reads exactly 1, because
whoever arrives first claims the flight and every later arrival
either waits and replays or finds the stored row directly. The replay
test adds the composition fact: the keyed layer sits inside the
request-id layer, so the snapshot carries the handler's headers and
never the request id, and one byte-equal replay shows two different
`x-request-id` values, two real requests answered by one execution.

#diagram([the flight: the first runs, the later arrivals wait, then re-read], length: 13pt, {
  pane(0.3, 7.3, 7.8, [caller 1], [claims the flight], [runs, stores, releases])
  cdraw.line((7.5, 6.2), (7.9, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(8.1, 15.3, 7.8, [caller 2], [parks on the condvar], [wakes, re-reads, replays])
  cdraw.line((15.5, 6.2), (15.9, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(16.1, 22.9, 7.8, [the window], [24 h, lazily expired], [a failure stores nothing])
})

== the count

The module is 445 lines and its test file 534, and the 14 tests land
green five consecutive runs under the full gate, fmt, clippy at
`-D warnings`, and the locked offline build, dated 2026-10-14: the two
published digests, the two comparison ladders, the store's replay,
mismatch, and exact window boundary, the swap's read, commit, drift,
and reopen, the post and get etag contract, the conditional lanes,
every `If-Match` lane including the star and the carried list, the
duel, the byte-equal replay over two request ids, the conflicting
body, the unstored failure, the expired window, and the counted
single execution under 8 concurrent posts. The crate holds 116 tests
this wave, the 102 landed ones green unchanged, which is the point of
adding a family instead of touching a landed one.

sources: RFC 9110 sections 13.1.1 and 13.1.2 at rfc-editor.org, the
strong comparison MUST, the two star rules, the list membership rule,
and the weak comparison for `If-None-Match`, plus section 13.2.2's
evaluation order and section 15.5.13's 412 definition, accessed
2026-10-14. RFC 6585 section 3 for status 428, the alternative this
lane declined with both siblings, accessed 2026-10-14. The two sha256
digests re-derived from python 3 `hashlib` on this machine as the
independent oracle, dated 2026-10-14, the same method chapter 21 used.
The 24 hour window, the 422 refusal, the flight settle semantics, and
the stored-snapshot replay follow the go book's concurrency chapter,
book 4 chapter 24 of this corpus, and the strong-comparison edge lanes
follow the java book's chapter 25, read for the parallel contracts.
The duel and the counted single execution produced by `cargo test
--locked` under `CARGO_NET_OFFLINE=true` on the pinned 1.99.0 build,
five consecutive green runs, dated 2026-10-14.
