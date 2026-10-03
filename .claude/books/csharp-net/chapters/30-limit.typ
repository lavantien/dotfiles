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
none of them: password guessing arrives as a flood of logins, a retry
storm arrives the moment a deploy slows one route down. This chapter
builds the service's rate limiting in `CsharpBook.Api.Limiting`: the
token bucket from first principles over the injected TimeProvider, the
production gate on System.Threading.RateLimiting with one bucket per
key and idle retirement, the 429 contract, what to key a limit on and
what never to trust, and the test discipline that keeps every
assertion off the wall clock.

== why limits exist

Capacity is finite and failure is nonlinear. Past some offered load a
service does not degrade gently, it falls off a cliff: queues grow,
latency climbs past every client timeout, memory fills with requests
waiting on answers that can no longer arrive. A limit is the refusal
to stand on that cliff. It converts an overload that would take the
whole service down into a fast rejection of the excess, and the client
that honors it gets a working service at one request per second
instead of a dead one at zero.

The two limited routes carry numbers chosen for what they protect.
Login allows a burst of five per address, then one per second, because
every login attempt pays the pbkdf2 verification budget and a guesser
does not need more than five tries to be dangerous. Register allows
ten per client ip for the same reason plus its idempotency
bookkeeping. Both refill one token per second, so a client that trips
the limit is back to full capacity five and ten seconds later, the
difference between a limit and a lockout:

#listing("csharp-net/api/src/CsharpBook.Api/Limiting/RateRule.cs", first: 23, last: 34, caption: [the contract's two rules as one constant block, numbers and messages])

#diagram([offered load versus what the service can carry, the cliff between them], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [requests/s], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  // carried load: linear, then flat at capacity
  cdraw.line((0.6, 0.7), (10.0, 5.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.0, 5.2), (23.2, 5.2), stroke: luma(60))
  cdraw.content((6.4, 3.2), [carried = offered, then capacity], size: 6pt)
  // latency: flat, then the cliff
  cdraw.line((0.6, 1.4), (10.0, 1.8), stroke: luma(140))
  cdraw.line((10.0, 1.8), (13.0, 4.6), stroke: luma(140))
  cdraw.line((13.0, 4.6), (16.2, 7.4), stroke: luma(140), mark: (end: ">"))
  cdraw.content((15.2, 7.8), [latency], size: 6pt)
  pane(17.4, 23.2, 2.4, [the limit's line], [429 before the cliff])
  cdraw.content((9.0, -0.5), [past capacity the service does not slow down, it stops answering], size: 6pt)
})

== the token bucket from first principles

A token bucket holds a double, a capacity, and a refill rate. It
starts full, every allowed request removes one token, and time adds
tokens continuously at the configured rate until the capacity caps
them. Its two knobs split the two jobs: capacity is the burst
allowance, how much may arrive at once, and the refill rate is the
sustained allowance, how much may arrive per second forever. The
login rule, capacity five at one per second, permits five requests in
the first instant, a sixth at the one second mark, then one per second
for as long as the client cares to wait.

The arithmetic of a denial is the part worth deriving rather than
reciting. After the fifth same-second draw the level is exactly zero,
so the next token exists one full second in the future, and that
instant is both the Reset header and the Retry-After. Half a second
later the level is 0.5: still not spendable, and the next whole token
is only half a second away. A whole level waits a full period, a
fraction waits its complement, the NextTokenIn rule: the wait is
`1 - frac(level)` over the refill rate, and a denial never spends:

#listing("csharp-net/api/src/CsharpBook.Api/Limiting/TokenBucket.cs", first: 41, last: 59, caption: [Allow: one draw, one decision, and the wait folded into the answer])

#diagram([bucket level over one draw timeline, the refill climbing between bursts], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [t, seconds], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.2), stroke: luma(120))
  cdraw.content((1.0, 7.35), [level 5], size: 6pt)
  cdraw.line((0.6, 6.4), (23.2, 6.4), stroke: luma(200), dash: "dashed")
  cdraw.content((23.8, 6.4), [capacity], size: 6pt)
  // burst of five at t0
  for i in range(5) {
    let x = 1.2 + i * 0.55
    cdraw.line((x, 6.4 - i * 1.05), (x + 0.5, 6.4 - (i + 1) * 1.05), stroke: luma(60))
  }
  cdraw.content((2.8, 2.9), [five draws, level 0], size: 6pt)
  cdraw.content((5.0, 1.1), [6th denied, retry after 1s], size: 6pt)
  cdraw.line((4.5, 1.15), (10.0, 6.4), stroke: luma(60))
  cdraw.content((8.0, 2.2), [refill 1/s], size: 6pt)
  cdraw.line((10.0, 6.4), (10.5, 5.35), stroke: luma(60))
  cdraw.content((11.4, 5.4), [spend at t=1], size: 6pt)
  cdraw.line((10.5, 5.35), (16.5, 6.4), stroke: luma(60))
  cdraw.content((13.6, 4.3), [level 0, then full], size: 6pt)
  cdraw.line((16.5, 6.4), (23.0, 6.4), stroke: luma(60))
  pane(17.6, 23.2, 2.4, [the two knobs], [burst 5: instant allowance], [1/s: forever allowance])
})

== System.Threading.RateLimiting in production

The teaching bucket stays in the chapter, the shipped gate runs on
`System.Threading.RateLimiting`, the platform's token bucket. Read as
primitives it is the teaching bucket with the refill moved into the
clock: one `lock` object, the level as a double, a fill rate of
TokensPerPeriod over ReplenishmentPeriod ticks, and the stopwatch
timestamp of the last replenish. There is no thread and no timer in
the lazy configuration: `AutoReplenishment = false` and one
`TryReplenish` per draw converts elapsed ticks into tokens under the
limiter's own lock, so the passage of time is the refill, the same
move the hand bucket makes with its injected clock.

The timer is the configuration this gate refuses:
`AutoReplenishment` defaulting to true arms one `Timer` per limiter,
and one limiter per key means a janitor per bucket. Queueing is
refused the same way, `QueueLimit = 0`, because a handler that queues
for a token holds its connection while it waits, which is precisely
the resource the limit exists to protect. What the platform gives the
gate besides enforcement is the denial's shape: `GetStatistics` floors
the level to whole permits, which is exactly the Remaining header, and
a failed lease carries `MetadataName.RetryAfter` in whole
replenishment periods, which is exactly the Retry-After the vector
pins. The fraction the hand bucket computes, the platform rounds up to
the next period, and at one token per second the two coincide.

One bucket per key lives in a dictionary, created on first use, and
the dictionary needs a policy: every distinct key is an unbounded
entry, so an idle ttl retires keys nobody has touched. The sweep is
amortized into the draw, every ttl of clock time a draw sweeps inside
the lock it already holds, which deletes the janitor entirely. The
whole decision, lookup, sweep, replenish, read, acquire, runs under
the gate's one lock because the platform's statistics are a separate
call from its acquire, and the header math must read the level this
draw spent:

#listing("csharp-net/api/src/CsharpBook.Api/Limiting/TokenBucketGate.cs", first: 74, last: 102, caption: [one lock over the decision: sweep, replenish, floor read, acquire, wait from the lease])

#diagram([key to bucket map, first use creates, idle age retires], length: 13pt, {
  cdraw.rect((0.4, 3.2), (11.0, 7.6), fill: luma(235), radius: 0.05)
  cdraw.content((5.7, 7.1), [the entries map, one per key], size: 6.5pt)
  cdraw.content((3.4, 6.0), [#"login:ada@example.org"], size: 6pt)
  cdraw.content((3.4, 5.0), [#"ip:203.0.113.7"], size: 6pt)
  cdraw.line((11.2, 5.5), (12.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(12.8, 19.4, 7.6, [entry], [TokenBucketRateLimiter], [AutoReplenishment false])
  cdraw.line((19.6, 5.5), (21.0, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(21.2, 23.4, 7.6, [sweep], [idle past ttl], [dispose, recreate])
  pane(0.4, 11.0, 2.1, [amortized], [one sweep per ttl], [no timer, no janitor])
})

== the 429 contract

The wire shape is pinned by the contract and the frozen vector. Every
response from a limited route carries three headers: X-RateLimit-Limit
is the burst capacity, X-RateLimit-Remaining is whole tokens left
after this draw, X-RateLimit-Reset is the unix second at which the
next token arrives. A denial adds Retry-After in seconds, the ceiling
of the wait, and answers the envelope with code rate_limited through
the kernel's one failure writer, so the request id in the body is the
one the edge resolved in chapter 23, the value the access log carries.

The sixth login vector pins every byte. The clock sits at t0 plus 12
seconds, five earlier logins at the same instant left the bucket
reporting remaining 4, 3, 2, 1, 0, and the sixth draw finds an empty
bucket: status 429, Limit 5, Remaining 0, Reset 1790830813 which is
exactly t0 plus 13 seconds, Retry-After 1, and the envelope's message
the frozen too many login attempts. The three headers are written
before the handler runs, so they ride on successes too, and the
denial path never reaches the handler at all:

#listing("csharp-net/api/src/CsharpBook.Api/Limiting/RateLimitMiddleware.cs", first: 17, last: 64, caption: [the middleware: three headers always, Retry-After and the envelope on denial])

#diagram([a client that honors Retry-After: five through, one refused, the next at the reset instant], length: 13pt, {
  cdraw.line((0.6, 3.4), (23.2, 3.4), stroke: luma(120))
  cdraw.content((23.4, 3.4), [t, seconds], size: 6pt)
  let hit(x, y, label) = {
    cdraw.circle((x, y), radius: 0.28, fill: luma(160))
    cdraw.content((x, y + 0.8), [#label], size: 6pt)
  }
  for i in range(3) { hit(1.4 + i, 3.4, []) }
  cdraw.content((3.0, 2.1), [burst five, each 401], size: 6pt)
  cdraw.rect((6.2, 3.1), (7.0, 3.7), fill: luma(60), radius: 0.02)
  cdraw.content((6.6, 2.1), [6th: 429], size: 6pt)
  cdraw.content((6.6, 1.2), [#"Retry-After: 1"], size: 6pt)
  cdraw.content((10.2, 2.1), [client waits, then 7th ok at reset], size: 6pt)
  hit(12.8, 3.4, [ok])
  hit(15.6, 3.4, [429])
  cdraw.content((16.6, 2.1), [one per second, forever], size: 6pt)
  pane(0.6, 11.2, 0.4, [headers on every response], [limit 5, remaining, reset], [the client can pace itself])
  cdraw.content((17.0, -0.4), [a client that ignores Retry-After gets 429s, not capacity], size: 6pt)
})

== what to key on

A limit is only as good as its key, and the two routes key on
different things for opposite reasons. Login keys on lower(email): the
attack the rule exists for is guessing one account's password, so the
bucket belongs to the account, and the casing normalization means
`ADA@Example.ORG` and `ada@example.org` are one bucket. The key lives in
the request body, so the keying reads the body once, bounded by the
kernel's one mebibyte cap, and replaces it with a rewound copy for the
handler to bind again. Register keys on the connection's remote
address, and the proxy
headers stay unread on purpose: X-Forwarded-For is a header any client
can write, so a limiter that keys on it verbatim sells a fresh bucket
of ten registrations per forged address, one per request, forever.

Two shared buckets close the dodge holes. A body the email key cannot
parse lands in one login unparsed bucket, so garbage cannot orbit the
limit by being invalid, and a connection with no remote address lands
in its own fallback. The test for the spoof is the contract said out
loud: eleven register posts from one address, a different forged
X-Forwarded-For on the last one, and the eleventh is still the 429:

#listing("csharp-net/api/src/CsharpBook.Api/Limiting/LimitKeys.cs", first: 23, last: 51, caption: [KeyEmail: a bounded read, the body handed back, garbage into one shared bucket])

#diagram([key choice: the route decides what the bucket belongs to], length: 13pt, {
  cdraw.content((11.5, 8.0), [request arrives, which rule], size: 6.5pt)
  cdraw.line((11.5, 7.7), (11.5, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.7, 5.6), (15.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.line((8.5, 5.5), (5.2, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.5, 5.5), (17.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 4.4, [login], [body: lower(email)], [per account, burst 5])
  pane(13.8, 21.8, 4.4, [register], [Connection.RemoteIpAddress], [per address, burst 10])
  cdraw.line((5.2, 1.9), (5.2, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(0.8, 10.0, 1.0, [unparseable body], [one shared bucket])
  cdraw.line((17.8, 1.9), (17.8, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(14.0, 22.6, 1.0, [forwarded-for], [ignored, client written])
  cdraw.content((11.5, -0.3), [an authenticated caller is a better key, and this api limits only its two unauthenticated routes], size: 6pt)
})

== limits under test

Every time-dependent behavior in the hand bucket is arithmetic on a
fixed clock, because a rate limiter tested against the wall clock is
tested against a scheduler. The injected TestClock moves in explicit
offsets, the fixed-draw tests walk the bucket through its grammar,
burst, cap, sustained rate, half-token denial, and the vector replay
runs the production middleware against the frozen file: five setup
draws assert remaining 4 through 0, the sixth asserts the vector's
status, every header byte, and the envelope's code and message, the
request id checked for uuid v7 shape only since this layer mints it.

The platform limiter adds one wrinkle the tests state rather than
hide: its refill clock is the stopwatch it owns, not the injected
TimeProvider. The draw-grammar tests all fire at one instant, which is
why they stay deterministic, and the one refill test uses a coarse
rate so elapsed refill lands inside a bounded loop that polls the
limiter's real state and never sleeps:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Limiting/RateLimitMiddlewareTests.cs", first: 60, last: 84, caption: [the vector replay: frozen clock at t0+12s, five draws, then the frozen sixth])

#diagram([the fixed-vector pipeline: file in, draws through the gate, bytes out], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [vector file], [frozen status, headers])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [clock pinned], [#"t0 + 12s"])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [five draws], [remaining 4 to 0])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [assert], [429, headers, envelope])
  cdraw.content((11.5, 1.4), [the refill test: coarse rate, bounded loop over real state, never a sleep], size: 6pt)
})

== admission preview

A rate limit refuses requests over time, an admission gate refuses
them over concurrency, and the two compose because they bound
different axes of the same cliff. Little's law states the trade in one
line: the requests inside the system equal the arrival rate times the
time each spends there, L = lambda W. Past the point where every
arriving request finds all workers busy, latency rises steeply while
throughput stops moving, the hockey stick chapter 32 measures. A rate
limit caps lambda at the edge. An admission gate caps L directly with
an in-flight semaphore and answers the overload envelope the instant
the slots run out, converting a queue of waiting requests into a cheap
refusal. The gate, its 503, and the drain it protects are chapter
32's to build over the decision shape this limit answers with:

#listing("csharp-net/api/src/CsharpBook.Api/Limiting/RateDecision.cs", first: 3, last: 16, caption: [the decision both refusals share, time here, concurrency in chapter 32])

#diagram([latency versus concurrency: the hockey stick the admission cap cuts off], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [in-flight, L], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  cdraw.content((0.6, 7.8), [latency, W], size: 6pt)
  cdraw.line((0.6, 1.3), (12.0, 1.9), stroke: luma(60))
  cdraw.line((12.0, 1.9), (16.0, 5.6), stroke: luma(60))
  cdraw.line((16.0, 5.6), (18.6, 7.5), stroke: luma(60), mark: (end: ">"))
  cdraw.content((5.6, 1.0), [below capacity: no queue], size: 6pt)
  cdraw.content((16.4, 4.9), [queueing, saturation], size: 6pt)
  cdraw.line((13.4, 0.7), (13.4, 6.9), stroke: luma(150), dash: "dashed")
  cdraw.content((13.4, 7.3), [admission cap], size: 6pt)
  pane(14.6, 23.2, 2.6, [past the cap], [the gate answers 503 overload])
  cdraw.content((7.5, 6.0), [L = lambda x W: the rate limit caps lambda], size: 6pt)
  cdraw.content((7.5, 5.1), [the admission gate caps L itself], size: 6pt)
})

sources: learn.microsoft.com for System.Threading.RateLimiting, the
TokenBucketRateLimiter class with its options and TryReplenish, plus
the rate limiting page under aspnet/core/performance/rate-limit, read
2026-09-26 against the net 11 rc surface, the limiter source in
dotnet/runtime at the commit the api pages link for the state and
lease metadata claims, and RFC 6585 for status 429 with RFC 9110 for
Retry-After. Verified by the `CsharpBook.Api.Limiting` tests, 19 of
them under `dotnet test Api.slnx`, with the sixth login vector
replayed header for header from `contract/testdata/06-login-429.json`.
