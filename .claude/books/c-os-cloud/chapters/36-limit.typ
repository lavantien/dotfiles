#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= rate limiting

A service that accepts every request it is offered eventually answers
none of them. Password guessing arrives as a flood of logins, a
runaway client loop arrives as one request ten thousand times, and a
retry storm arrives the moment a deploy slows a single route. This
chapter builds the service's rate limiting in `c-os-cloud/api/src`: the
token bucket from first principles with the clock as a plain
parameter, the fixed table and its idle sweep, the 429 wire contract,
what to key a limit on, and the tests off the wall clock.

== why limits exist

Capacity is finite and failure is nonlinear. Past some offered load a
service does not degrade gently, it falls off a cliff: queues grow,
latency climbs past every client timeout, memory fills with requests
waiting on answers that cannot arrive, and the health check itself
starts timing out. A limit is the refusal to stand on that cliff: it
converts an overload that would take the whole service down into a
fast honest rejection of the excess, and the client that honors it
gets a working service at 1 request per second instead of a dead one
at zero.

The two limited routes carry numbers chosen for what they protect.
Login allows a burst of 5 per address, then 1 per second, because
every login attempt pays the password verification budget and a
credential guesser does not need more than 5 tries to be dangerous.
Register allows 10 per client ip for the same reason plus its
idempotency bookkeeping. Both refill 1 token per second, so a client
that trips the limit is back to full capacity 5 and 10 seconds later,
the difference between a limit and a lockout:

#listing("c-os-cloud/api/src/wire_ops.c", first: 21, last: 27, caption: [the contract's two rules as one constant table, numbers and messages verbatim])

#diagram([offered load versus what the service can carry, the cliff between them], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [requests/s], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  cdraw.content((0.6, 7.8), [capacity used], size: 6pt)
  cdraw.line((0.6, 0.7), (10.0, 5.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.0, 5.2), (23.2, 5.2), stroke: luma(60))
  cdraw.content((5.6, 3.2), [carried = offered], size: 6pt)
  cdraw.content((17.4, 5.9), [carried = capacity], size: 6pt)
  cdraw.line((0.6, 1.4), (10.0, 1.8), stroke: luma(140))
  cdraw.line((10.0, 1.8), (13.0, 4.6), stroke: luma(140))
  cdraw.line((13.0, 4.6), (16.2, 7.4), stroke: luma(140), mark: (end: ">"))
  cdraw.content((15.2, 7.9), [latency], size: 6pt)
  cdraw.content((11.0, 3.0), [queues form], size: 6pt)
  cdraw.content((15.2, 5.4), [timeouts, then collapse], size: 6pt)
  pane(17.4, 23.2, 2.9, [the limit's line], [429 before the cliff], [excess refused in microseconds])
  cdraw.content((9.0, -0.5), [past capacity the service does not slow down, it stops answering], size: 6pt)
})

== the token bucket from first principles

A token bucket holds a floating level, a capacity, and a refill rate.
It starts full, every allowed draw removes one token, and time adds
tokens continuously at the configured rate until the capacity caps
them. The two knobs split the two jobs cleanly: capacity is the burst
allowance, how much may arrive at once, and the refill rate is the
sustained allowance, how much may arrive per second forever. The
contract's login rule, capacity 5 at 1 per second, permits 5 requests
in the first instant, a 6th at the 1 second mark, and then 1 per
second forever. The level is a double stamped with the instant of the
last refill, so time becomes tokens lazily on every call and a caller
that hands the same instant twice observes no passage at all.

The arithmetic of a denial is the part worth deriving rather than
reciting. After the 6th same-second draw the level is exactly 0, so
the next token exists 1 full second in the future, and that instant is
both the reset header and the retry hint. Half a second later the
level is 0.5, still not spendable, and the next whole token is only
half a second away. A whole level always waits a full period, a
fraction waits its complement, which is the rule the draw computes:
the wait is `1 - frac(level)` over the refill rate, and a denial never
spends anything:

#listing("c-os-cloud/api/src/limit_bucket.c", first: 37, last: 52, caption: [one draw: refill, spend if a whole token exists, and the wait from the fractional level])

#diagram([bucket level over one draw timeline, the refill climbing between bursts], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [t, seconds], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.2), stroke: luma(120))
  cdraw.content((1.0, 7.35), [5], size: 6pt)
  cdraw.line((0.6, 6.4), (23.2, 6.4), stroke: luma(200), dash: "dashed")
  cdraw.content((23.8, 6.4), [capacity], size: 6pt)
  for i in range(5) {
    let x = 1.2 + i * 0.55
    cdraw.line((x, 6.4 - i * 1.05), (x + 0.5, 6.4 - (i + 1) * 1.05), stroke: luma(60))
  }
  cdraw.content((2.6, 3.0), [5 draws, level 0], size: 6pt)
  cdraw.content((4.4, 1.1), [x], size: 7pt)
  cdraw.content((5.4, 1.1), [denied, retry after 1s], size: 6pt)
  cdraw.line((4.5, 1.15), (10.0, 6.4), stroke: luma(60))
  cdraw.content((8.0, 2.2), [refill 1/s], size: 6pt)
  cdraw.line((10.0, 6.4), (10.5, 5.35), stroke: luma(60))
  cdraw.content((10.9, 5.35), [6th allowed at t=1], size: 6pt)
  cdraw.line((10.5, 5.35), (16.5, 6.4), stroke: luma(60))
  cdraw.line((16.5, 6.4), (23.0, 6.4), stroke: luma(60))
  cdraw.content((20.0, 5.6), [full, idle time earns nothing], size: 6pt)
  pane(17.6, 23.2, 2.4, [the two knobs], [burst 5: instant allowance], [1/s: forever allowance])
})

== the fixed table and the sweep

The bucket needs a home per key, and the go book's map is the one
design this vehicle refuses: every distinct key is an allocation, and
an attacker who mints keys mints heap. The c gate is a fixed table of
256 preallocated slots that exists at link time, lookup is a linear
scan over 96-byte keys, and no request in the steady path allocates.
A slot is stamped with the rule's numbers at first use, touched on
every draw, and retired when idle longer than the ttl.

The sweep is amortized into the decision itself. Every call checks the
clock against the last sweep, and when an idle ttl has passed the
retire pass runs inside the same call: no timer, no thread, no janitor
to leak. The whole pass holds one table lock, because the composed
service draws from every worker thread and two concurrent misses on
one key must not claim two slots or lose each other's draw. A table
that is full after a forced sweep answers a new key
with the bounded refusal, 1 retry second and
the rule's limit, rather than allocating its way out: finiteness as a
stated policy, not a hidden cliff:

#listing("c-os-cloud/api/src/limit_gate.c", first: 71, last: 101, caption: [decide: sweep on the ttl boundary, find or create the slot, refuse new keys when the table is full])

#diagram([one key through the fixed table: scan, create, or the bounded refusal], length: 13pt, {
  cdraw.content((11.5, 8.0), [key arrives], size: 6.5pt)
  cdraw.line((11.5, 7.7), (11.5, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.7, 5.6), (15.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.3), [linear scan, 256 slots], size: 6pt)
  cdraw.line((8.5, 5.5), (5.2, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.5, 5.5), (17.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 4.4, [found], [touch, draw one token], [last_touch = now])
  pane(13.8, 21.8, 4.4, [not found], [first free slot], [bucket starts full])
  cdraw.line((17.8, 2.9), (17.8, 1.9), stroke: luma(100), mark: (end: ">>"))
  pane(13.8, 21.8, 1.4, [no free slot], [forced sweep, still full], [the bounded refusal: retry 1])
  cdraw.line((5.2, 4.3), (5.2, 3.3), stroke: luma(150), dash: "dashed")
  pane(1.2, 9.2, 3.0, [the ttl clock], [every idle ttl, retire idle keys], [inside the same call])
})

== the 429 contract

The wire shape is pinned by the contract and the frozen vector, and
every number in it is computed by the draw. A limited route answers
with 3 headers on every response, allowed or denied: the limit is the
burst capacity, the remaining is whole tokens left after this draw,
and the reset is the unix second at which the next token arrives. A
denial adds `Retry-After` in whole seconds, the ceiling of the
fractional wait, and the body is the standard error envelope with code
`rate_limited`, written through the kernel's one failure writer so the
request id matches the one the access log recorded. The middleware
layer rides that writer directly: a denied login renders the vector's
envelope byte for byte, and every rate header is stamped after the
answer because the kernel's response begin resets the header table.

The 6th login vector pins every number. The clock sits at the frozen
t0 plus 12 seconds, 5 earlier logins at the same instant left the
bucket reporting remaining 4, 3, 2, 1, 0, and the 6th draw finds an
empty bucket: status 429, limit 5, remaining 0, reset 1790830813 which
is exactly t0 plus 13 seconds, retry after 1. The test reads those
values out of the vector file itself, so the file is the oracle:

#listing("c-os-cloud/api/tests/test_limit.c", first: 421, last: 443, caption: [the vector replay: the file drives the clock, the pins, and the 5 setup draws])

#diagram([a client that honors Retry-After: 5 through, 1 refused, the next at the reset instant], length: 13pt, {
  cdraw.line((0.6, 3.4), (23.2, 3.4), stroke: luma(120))
  cdraw.content((23.4, 3.4), [t, seconds], size: 6pt)
  let hit(x, label, dy) = {
    cdraw.circle((x, 3.4), radius: 0.28, fill: luma(160))
    cdraw.content((x, 3.4 + dy), [#label], size: 6pt)
  }
  hit(1.4, [1], 0.8)
  hit(2.2, [2], 0.8)
  hit(3.0, [3], 0.8)
  hit(3.8, [4], 0.8)
  hit(4.6, [5], 0.8)
  cdraw.content((3.0, 2.1), [burst 5, each 401], size: 6pt)
  cdraw.rect((6.2, 3.1), (7.0, 3.7), fill: luma(60), radius: 0.02)
  cdraw.content((6.6, 2.1), [6th: 429], size: 6pt)
  cdraw.content((6.6, 1.2), [#"Retry-After: 1"], size: 6pt)
  cdraw.line((7.4, 1.6), (12.6, 1.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.0, 2.1), [client waits, does not hammer], size: 6pt)
  hit(12.8, [7th ok], 0.8)
  cdraw.content((12.8, 2.1), [at the reset instant], size: 6pt)
  hit(14.6, [8th 429], 0.8)
  hit(17.6, [9th ok], 0.8)
  cdraw.content((16.4, 2.1), [1 per second, forever], size: 6pt)
  cdraw.content((17.0, -0.4), [a client that ignores Retry-After gets 429s, not capacity], size: 6pt)
})

== what to key on

A limit is only as good as its key, and the two routes key on
different things for opposite reasons. Login keys on the normalized
email: the attack the rule exists for is guessing one account's
password, so the bucket belongs to the account, and the normalization
trims and lowercases, so `ADA@Example.ORG` and `ada@example.org` are
one bucket. The key
lives in the request body, so the wiring reads it once through the
kernel's one json codec and hands the parsed email to this family,
which owns no second parser. Register keys on the client ip the
kernel stamps at accept, port stripped, and the proxy headers stay
unread on purpose: `X-Forwarded-For` is a header any client can write,
so a limiter that keys on it verbatim sells a fresh bucket of 10
registrations per forged address, 1 per request, forever. A request
that arrives with no stamp at all, the internal listener's own
traffic, lands in the one shared `ip:unparsed` bucket.

Two shared landing spots close the dodge holes. A body whose email
cannot be parsed lands in the one shared `login:unparsed` bucket, so
garbage cannot orbit the limit by being invalid, and a bracketed ipv6
remote address loses its brackets and port. An overlong key truncates
at 96 bytes rather than allocating:

#listing("c-os-cloud/api/src/limit_gate.c", first: 106, last: 120, caption: [the login key: lowercase the email, empty or null into the one shared unparsed bucket])

#diagram([key choice: the route decides what the bucket belongs to], length: 13pt, {
  cdraw.content((11.5, 8.0), [request arrives], size: 6.5pt)
  cdraw.line((11.5, 7.7), (11.5, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.7, 5.6), (15.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.3), [which rule owns this path], size: 6pt)
  cdraw.line((8.5, 5.5), (5.2, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.5, 5.5), (17.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 4.4, [login], [body: lower(email)], [per account, burst 5])
  pane(13.8, 21.8, 4.4, [register], [remote addr host], [per address, burst 10])
  cdraw.line((5.2, 1.9), (5.2, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 1.0, [unparseable body], [one shared bucket], [invalid input still limited])
  cdraw.line((17.8, 1.9), (17.8, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(13.8, 21.8, 1.0, [forwarded-for], [ignored, client written], [trust needs a proxy contract])
  cdraw.content((11.5, -0.3), [an authenticated caller is a better key, and this api limits only its 2 unauthenticated routes], size: 6pt)
})

== limits under test

Every time-dependent behavior in this family is arithmetic on a fixed
clock, because a rate limiter tested against the wall clock is tested
against a scheduler. The clock is not even a seam object here, it is a plain parameter in
unix seconds, so the fixed-draw tests step it by hand and the bucket
cannot observe anything the test did not state. The vector replay runs
the gate against the frozen file: the file's offset pins the clock,
its header values pin the expected decision, and the 5 setup draws
assert the remaining sequence 4 through 0 before the 6th asserts
everything at once. The family lands as its own test unit with 1
entry the wiring runner calls, no sleep in it:

#listing("c-os-cloud/api/tests/test_limit.c", first: 64, last: 83, caption: [the fixed-draw sequence: 5 allowed, the 6th denied, the half token, the refilled token])

#diagram([the fixed-vector pipeline: file in, draws through the gate, numbers out], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [vector file], [frozen status, headers])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [clock pinned], [#"t0 + 12s, no wall time"])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [5 draws], [remaining 4, 3, 2, 1, 0])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [assert numbers], [429, headers, envelope code])
  pane(0.3, 11.2, 3.2, [the clock is a parameter], [a double the test steps], [no scheduler in the loop])
  pane(12.0, 23.0, 3.2, [394 checks], [one family entry in the runner], [zero sleeps in the file])
})

== admission preview

A rate limit refuses requests over time, an admission gate refuses
them over concurrency, and the two compose because they bound
different axes of the same cliff. Little's law states the trade in
one line: the average number of requests inside the system equals the
arrival rate times the time each spends there. Past the point where
every arriving request finds all workers busy, latency rises steeply
while throughput stops moving, the hockey stick the load chapter
measures. A rate limit caps the arrival rate at the edge. An admission
gate caps the inside count directly with an in-flight counting
semaphore, holds 1 slot per admitted request, and answers the
contract's overload envelope the instant the slots run out.

The fixed table already carries the small version of that policy: a
full table refuses a new key with 1 retry second instead of queueing
it, bounded state answering unbounded demand. The load chapter builds
the real gate over kernel event handles with the drain it protects:
readiness flips first, in-flight requests join, the exit code is
reported from the drain. Threads follow the chapter 15 side-by-side
ruling, and the condition-variable seam carries the lost wake lesson
from chapter 16, which is exactly where a gate that sleeps workers
instead of refusing requests would go wrong:

#listing("c-os-cloud/api/src/limit_gate.c", first: 83, last: 90, caption: [the bounded refusal: a full table answers a new key instead of allocating or queueing])

#diagram([latency versus concurrency: the hockey stick the admission cap cuts off], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [in-flight count], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  cdraw.content((0.6, 7.8), [latency], size: 6pt)
  cdraw.line((0.6, 1.3), (12.0, 1.9), stroke: luma(60))
  cdraw.line((12.0, 1.9), (16.0, 5.6), stroke: luma(60))
  cdraw.line((16.0, 5.6), (18.6, 7.5), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.0, 1.0), [workers busy below capacity], size: 6pt)
  cdraw.line((13.4, 0.7), (13.4, 6.9), stroke: luma(150), dash: "dashed")
  cdraw.content((13.4, 7.3), [admission cap], size: 6pt)
  pane(14.6, 23.2, 2.6, [past the cap], [every arrival waits, none serves], [the gate answers 503 overload])
  cdraw.content((7.5, 6.2), [inside = arrival rate x time inside: the rate limit caps arrivals], size: 6pt)
  cdraw.content((7.5, 5.1), [the admission gate caps the inside count itself], size: 6pt)
})

sources: RFC 6585 section 4 for status 429 with its Retry-After
guidance and RFC 9110 section 10.2.3 for the field's delay-seconds
form, both accessed 2026-09-27, the frozen vector 06 at
`c-os-cloud/api/contract/testdata/06-login-429.json` as the byte
oracle for every header number, and Little's 1961 proof of the queuing
formula for the admission preview's trade. Verified by the limit
family's 394 checks under the pinned clang 23 through
`make verify-capi`, plus clang-format over every file touched.
