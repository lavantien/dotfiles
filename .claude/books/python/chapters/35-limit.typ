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

A service that answers every request it receives eventually answers
none of them: password guessing arrives as a flood of logins, a
runaway client loop arrives as the same request ten thousand times.
This chapter builds the service's rate limiting in `pyapi/limit.py`.
The
standard library ships no rate limiter, so the token bucket built
here over an injected clock is the production gate, not a teaching
mock, with `threading.BoundedSemaphore` and `queue.Queue` decomposed
along the way as the admission and handoff primitives they are, and
the 429 contract, the keying, and the sleepless test discipline
close the chapter.

== why limits exist

Capacity is finite and failure is nonlinear. Past some offered load a
service does not degrade gently, it falls off a cliff: queues grow,
latency climbs past every client timeout, memory fills with requests
waiting on answers. A limit is the refusal
to stand on that cliff. It converts an overload that would take the
whole service down into a fast, honest rejection of the excess, and
the client that honors it gets a working service at one request per
second instead of a dead one at zero.

The two limited routes carry numbers chosen for what they protect.
Login allows a burst of five per address, then one per second,
because every login attempt pays the pbkdf2 verification budget,
210000 iterations of hmac-sha256, and a credential guesser does not
need more than five tries to be dangerous. Register allows ten per
client ip for the same reason plus its idempotency bookkeeping. Both
refill one token per second, so a tripped client is back to full
capacity five and ten seconds later, the difference between a limit
and a lockout:

#listing("python/api/pyapi/limit.py", first: 29, last: 42, caption: [the contract's two rules as one constant block, numbers and messages])

#diagram([offered load versus what the service can carry, the cliff between them], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [requests/s], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  cdraw.content((0.6, 7.8), [capacity used], size: 6pt)
  // carried load: linear, then flat at capacity
  cdraw.line((0.6, 0.7), (10.0, 5.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.0, 5.2), (23.2, 5.2), stroke: luma(60))
  cdraw.content((5.8, 3.2), [carried = offered, then capacity], size: 6pt)
  // latency: flat, then the cliff
  cdraw.line((0.6, 1.4), (10.0, 1.8), stroke: luma(140))
  cdraw.line((10.0, 1.8), (16.2, 7.4), stroke: luma(140), mark: (end: ">"))
  cdraw.content((15.4, 7.9), [latency], size: 6pt)
  cdraw.content((4.0, 1.1), [latency flat, then the cliff], size: 6pt)
  pane(17.4, 23.2, 2.9, [the limit's line], [429 before the cliff], [excess refused fast])
})

== the token bucket from first principles

A token bucket holds a float, a capacity, and a refill rate. It
starts full, every allowed request removes one token, and time adds
tokens continuously at the configured rate until the capacity caps
them. The two knobs split the two jobs cleanly: capacity is the
burst allowance, how much may arrive at once, and the refill rate is
the sustained allowance, how much may arrive per second forever. The
login rule, capacity five at one per second, permits five in the
first instant, a sixth at the one second mark, then one per second
forever.

The arithmetic of a denial is the part worth deriving rather than
reciting. After the sixth same-second draw the level is exactly zero,
so the next token exists one full second in the future, and that
instant is both the reset header and the retry hint. Half a second
later the level is 0.5, still not spendable, and the next whole
token only half a second away: a whole level waits a full period, a
fraction waits its complement, and a denial spends nothing:

#listing("python/api/pyapi/limit.py", first: 87, last: 107, caption: [Allow: one draw, one decision, and the wait computed from the fractional level])

#diagram([bucket level over one draw timeline, the refill climbing between bursts], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [t, seconds], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.2), stroke: luma(120))
  cdraw.line((0.6, 6.4), (23.2, 6.4), stroke: luma(200), dash: "dashed")
  cdraw.content((23.8, 6.4), [capacity], size: 6pt)
  // burst of five at t0
  for i in range(5) {
    let x = 1.2 + i * 0.55
    cdraw.line((x, 6.4 - i * 1.05), (x + 0.5, 6.4 - (i + 1) * 1.05), stroke: luma(60))
  }
  cdraw.content((2.6, 3.0), [five draws, level 0], size: 6pt)
  // denied at t0
  cdraw.content((6.0, 1.1), [x denied, retry after 1s], size: 6pt)
  // refill climb
  cdraw.line((4.5, 1.15), (10.0, 6.4), stroke: luma(60))
  cdraw.content((8.0, 2.2), [refill 1/s], size: 6pt)
  // one spend at t=1, then climb to full
  cdraw.line((10.0, 6.4), (10.5, 5.35), stroke: luma(60))
  cdraw.content((10.9, 5.35), [sixth allowed at t=1], size: 6pt)
  cdraw.line((10.5, 5.35), (23.0, 6.4), stroke: luma(60))
  cdraw.content((19.5, 5.5), [full, idle earns nothing], size: 6pt)
  pane(17.6, 23.2, 2.4, [the two knobs], [burst 5: instant allowance], [1/s: forever allowance])
})

== the stdlib has no rate limiter

Said plainly: the python standard library has no rate limiting
anywhere in it, no token bucket, no sliding window, no throttling
helper. The go lane reached for `golang.org/x/time/rate` and the
c sharp lane for `System.Threading.RateLimiting`'s
`TokenBucketRateLimiter`, both platform-official, and this lane has
no counterpart to reach for, so the bucket from the previous section
ships. What the stdlib does ship is the two primitives a limiter is
built from.

`threading.BoundedSemaphore` is capacity without time: whole slots,
a fixed count, and `acquire(blocking=False)` is an immediate yes or
no, the exact admission move a gate needs. The docs give the bound
check in one line, releasing past the initial value raises
`ValueError`, and that loudness is a feature: an unbalanced release
is a bug, not a slot to invent. `queue.Queue` is a handoff without a
rate: the docs open with "The `queue` module implements
multi-producer, multi-consumer queues", locking semantics included,
and its `maxsize` blocks the producer
when full, which is backpressure, not refusal. A semaphore counts
what is inside, a queue moves work between threads, and neither
knows what the clock said. The token bucket is the third structure:
the semaphore's capacity plus the clock, as a float level time
refills.

The production gate wraps that bucket in a map policy: one bucket
per key, created on first use, retired after an idle ttl, with the
sweep amortized into the request path, every `idle_ttl` of clock
time a request sweeps inside the lock it already holds, which
deletes the sweeper thread entirely. The lock is one
`threading.Lock` held for the lookup and the draw, because
ThreadingHTTPServer dispatches each request on its own thread and
python threads interleave at every bytecode, so the map and the
levels share one mutex the way the go lane's limiter shares one:

#listing("python/api/pyapi/limit.py", first: 232, last: 249, caption: [per-key buckets, created on first use, swept on the lock the path already holds])

#diagram([semaphore, queue, bucket: what each primitive actually carries], length: 13pt, {
  pane(0.4, 7.6, 7.4, [BoundedSemaphore], [whole slots, a count], [acquire(False): yes or no], [over-release: ValueError])
  pane(8.2, 15.4, 7.4, [queue.Queue], [handoff, locking included], [maxsize blocks, never refuses], [time plays no part])
  pane(16.0, 23.2, 7.4, [the token bucket], [semaphore capacity], [plus the clock as a float], [refill 1/s, capped])
  cdraw.content((11.8, 3.0), [capacity without time], size: 6pt)
  cdraw.content((19.9, 3.0), [capacity plus time], size: 6pt)
})

== the 429 contract

The wire shape is pinned by the contract and the frozen vector, and
the layer writes it in one place. Every response from a limited route
carries three headers: `X-RateLimit-Limit` is the burst capacity,
`X-RateLimit-Remaining` is whole tokens left after this draw,
`X-RateLimit-Reset` is the unix second at which the next token
arrives. A denial adds `Retry-After` in seconds, the ceiling of the
wait, and answers the standard envelope with code `rate_limited`
through the kernel's one failure writer, never a bare status or a
bespoke body, so the request id in the denial matches every other
signal of the request.

The sixth login vector pins every byte. The clock sits at the frozen
`t0` plus twelve seconds, five earlier logins at the same instant
left the bucket reporting remaining 4, 3, 2, 1, 0, and the sixth
draw finds an empty bucket: status 429, limit 5, remaining 0, reset
1790830813, exactly `t0` plus thirteen seconds, retry after 1, and
the envelope's message the frozen `too many login attempts`.
The layer writes the three headers before the inner handler runs, so
they ride on successes too:

#listing("python/api/pyapi/limit.py", first: 251, last: 276, caption: [the layer: three headers always, Retry-After and the envelope on denial])

#diagram([a client that honors Retry-After: five through, one refused, the next at the reset instant], length: 13pt, {
  cdraw.line((0.6, 3.4), (23.2, 3.4), stroke: luma(120))
  cdraw.content((23.4, 3.4), [t, seconds], size: 6pt)
  let hit(x, y, label) = {
    cdraw.circle((x, y), radius: 0.28, fill: luma(160))
    cdraw.content((x, y + 0.8), [#label], size: 6pt)
  }
  hit(1.4, 3.4, [1])
  hit(2.2, 3.4, [2])
  hit(3.0, 3.4, [3])
  hit(3.8, 3.4, [4])
  hit(4.6, 3.4, [5])
  cdraw.rect((6.2, 3.1), (7.0, 3.7), fill: luma(60), radius: 0.02)
  cdraw.content((6.6, 2.1), [6th: 429], size: 6pt)
  cdraw.content((6.6, 1.2), [#"Retry-After: 1"], size: 6pt)
  cdraw.line((7.4, 1.6), (12.6, 1.6), stroke: luma(100), mark: (end: ">"))
  hit(12.8, 3.4, [7th ok])
  cdraw.content((12.8, 2.1), [at the reset instant], size: 6pt)
  hit(17.6, 3.4, [9th ok])
  cdraw.content((16.2, 2.1), [one per second, forever], size: 6pt)
  cdraw.content((17.0, -0.4), [a client that ignores Retry-After gets 429s, not capacity], size: 6pt)
})

== what to key on

A limit is only as good as its key, and the two routes key on
different things for opposite reasons. Login keys on
`lower(email)`: the attack the rule exists for is guessing one
account's password, so the bucket belongs to the account, and the
casing normalization means `ADA@Example.ORG` and `ada@example.org`
are one bucket. The key lives in the request body, which the kernel
has already read into `Request.body` as bytes, so the key function
parses what is there, bounded at one mebibyte. Register keys on the
client address the socket reported, carried into the request by the
kernel's adapter, and the proxy headers stay unread on purpose:
`X-Forwarded-For` is a header any client can write, and a limiter
that keys on it verbatim sells a fresh bucket of ten registrations
per forged address, one per request, forever.

The shared bucket closes the dodge hole. A body the email key cannot
parse lands in one `login:unparsed` bucket, so garbage cannot orbit
the limit by being invalid, and the suite drives that path with four
shapes of unusable body, non-json, a list, an empty or non-string
email:

#listing("python/api/pyapi/limit.py", first: 147, last: 165, caption: [KeyEmail: a bounded parse, garbage into one shared bucket])

#diagram([key choice: the route decides what the bucket belongs to], length: 13pt, {
  cdraw.content((11.5, 8.0), [request arrives], size: 6.5pt)
  cdraw.line((11.5, 7.7), (11.5, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.7, 5.6), (15.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.3), [which path is this], size: 6pt)
  cdraw.line((8.5, 5.5), (5.2, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.5, 5.5), (17.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 4.4, [login], [body: lower(email)], [garbage: one shared bucket])
  pane(13.8, 21.8, 4.4, [register], [socket client address], [forwarded-for ignored])
  cdraw.content((11.5, 3.0), [an authenticated caller is a better key, and this api limits only its two unauthenticated routes], size: 6pt)
})

== limits under test

Every time-dependent behavior in this chapter is arithmetic on a
fixed clock, because a rate limiter tested against the wall clock is
tested against a scheduler. The injected clock is a two-line fake
whose `advance` is the only way time moves, and the fixed-draw tests
walk the bucket through its whole grammar: burst, cap, sustained
rate, half-token denial, denial that spends nothing. The property
loop is a seeded `random.Random` over the one invariant a bucket
must hold, across two hundred trials of five hundred draws at random
gaps, the allowed count never exceeds capacity plus elapsed seconds
times the refill rate. The vector replay runs the layer against the
frozen file over a real `App`: five setup dispatches, then the sixth
asserts the vector's status, every header byte, the envelope's code
and message, and the request id checked for uuid v7 shape only,
since this layer mints it fresh. No test sleeps, and the twenty tests
run in milliseconds:

#listing("python/api/tests/test_limit.py", first: 239, last: 257, caption: [the vector replay: frozen clock at t0+12s, five draws, then the frozen sixth over the app])

#diagram([the fixed-vector pipeline: file in, draws through the layer, bytes out], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [vector file], [frozen status, headers])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [clock pinned], [#"t0 + 12s, no wall time"])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [five dispatches], [remaining 4, 3, 2, 1, 0])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [assert bytes], [429, headers, envelope])
  pane(0.3, 11.2, 3.2, [the property lane], [seeded random.Random], [spent <= capacity + elapsed])
})

== admission preview

A rate limit refuses requests over time, an admission gate refuses
them over concurrency, and the two compose because they bound
different axes of the same cliff. Little's law states the trade in
one line: the average number of requests inside the system equals
the arrival rate times the time each spends there, `L = lambda W`.
Past the point where every arriving request finds all workers busy,
latency rises steeply while throughput stops moving, the hockey stick
chapter 37 measures. A rate limit caps lambda at the edge. An admission gate caps L directly with a `BoundedSemaphore`,
holds one slot per admitted request through the `try_acquire` move
the docs describe, returning false immediately rather than blocking,
and answers the contract's overload envelope the instant the slots
run out. The semaphore and its 503 are chapter 37's to build, along
with the drain it protects:

#listing("python/api/pyapi/load.py", first: 50, last: 66, caption: [the gate's take and give back: nonblocking acquire, bounded release])

#diagram([latency versus concurrency: the hockey stick the admission cap cuts off], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [in-flight, L], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  cdraw.content((0.6, 7.8), [latency, W], size: 6pt)
  cdraw.line((0.6, 1.3), (12.0, 1.9), stroke: luma(60))
  cdraw.line((12.0, 1.9), (16.0, 5.6), stroke: luma(60))
  cdraw.line((16.0, 5.6), (18.6, 7.5), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.0, 1.0), [workers busy below capacity], size: 6pt)
  cdraw.content((18.2, 6.4), [saturation], size: 6pt)
  cdraw.line((13.4, 0.7), (13.4, 6.9), stroke: luma(150), dash: "dashed")
  cdraw.content((13.4, 7.3), [admission cap], size: 6pt)
  pane(14.6, 23.2, 2.6, [past the cap], [every arrival waits, none serves], [the gate answers 503 overload])
  cdraw.content((7.5, 6.2), [L = lambda x W: the rate limit caps lambda], size: 6pt)
  cdraw.content((7.5, 5.1), [the admission gate caps L itself], size: 6pt)
})

sources: docs.python.org, the 3.14 threading page for
BoundedSemaphore's bound check, acquire(blocking=False), and the
absence of any rate limiting utility, and the 3.14 queue page for the
multi-producer multi-consumer description, plus RFC 6585 and RFC
9110 for 429 and Retry-After, all accessed 2026-09-27. Verified by
`python/api/tests/test_limit.py`, 21 tests under unittest discover on
the pinned cpython 3.14.7, the sixth-login vector replayed byte for
byte from `python/api/contract/testdata/06-login-429.json`.
