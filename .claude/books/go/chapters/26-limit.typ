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
runaway client loop arrives as the same request ten thousand times, a
retry storm arrives the moment a deploy slows one route down. This
chapter builds the service's rate limiting in `goapi/internal/limit`:
the token bucket derived from first principles with an injected clock,
the production gate on `golang.org/x/time/rate` with one limiter per
key and idle sweeping, the 429 contract with its headers and envelope,
what to key a limit on and what never to trust, and the test
discipline that keeps every assertion off the wall clock.

== why limits exist

Capacity is finite and failure is nonlinear. Past some offered load a
service does not degrade gently, it falls off a cliff: queues grow,
latency climbs past every client timeout, memory fills with requests
waiting on answers that can no longer arrive, and the health check
itself starts timing out. A limit is the refusal to stand on that
cliff. It converts an overload that would take the whole service down
into a fast, honest rejection of the excess, and the client that
honors it gets a working service at one request per second instead of
a dead one at zero.

The two limited routes carry numbers chosen for what they protect.
Login allows a burst of five per address, then one per second, because
every login attempt pays the argon2 verification budget and a
credential guesser does not need more than five tries to be dangerous.
Register allows ten per client ip for the same reason plus its
idempotency bookkeeping. Both refill one token per second, so a client
that trips the limit is back to full capacity five and ten seconds
later, which is the difference between a limit and a lockout:

#listing("go/api/internal/limit/handler.go", first: 30, last: 41, caption: [the contract's two rules as one constant block, numbers and messages])

#diagram([offered load versus what the service can carry, the cliff between them], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [requests/s], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  cdraw.content((0.6, 7.8), [capacity used], size: 6pt)
  // carried load: linear, then flat at capacity
  cdraw.line((0.6, 0.7), (10.0, 5.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.0, 5.2), (23.2, 5.2), stroke: luma(60))
  cdraw.content((6.2, 3.4), [carried = offered], size: 6pt)
  cdraw.content((17.0, 5.9), [carried = capacity], size: 6pt)
  // latency: flat, then the cliff
  cdraw.line((0.6, 1.4), (10.0, 1.8), stroke: luma(140))
  cdraw.line((10.0, 1.8), (13.0, 4.6), stroke: luma(140))
  cdraw.line((13.0, 4.6), (16.2, 7.4), stroke: luma(140), mark: (end: ">"))
  cdraw.content((15.4, 7.9), [latency], size: 6pt)
  cdraw.content((4.0, 1.1), [latency flat], size: 6pt)
  cdraw.content((11.3, 3.1), [queues form], size: 6pt)
  cdraw.content((15.6, 5.6), [timeouts, then collapse], size: 6pt)
  pane(17.4, 23.2, 2.9, [the limit's line], [429 before the cliff], [excess refused in microseconds])
  cdraw.content((9.0, -0.5), [past capacity the service does not slow down, it stops answering], size: 6pt)
})

== the token bucket from first principles

A token bucket holds a float, a capacity, and a refill rate. It starts
full, every allowed request removes one token, and time adds tokens
continuously at the configured rate until the capacity caps them. That
is the entire algorithm, and its two knobs split the two jobs cleanly:
capacity is the burst allowance, how much may arrive at once, and the
refill rate is the sustained allowance, how much may arrive per second
forever. The contract's login rule, capacity five at one per second,
permits five requests in the first instant, a sixth at the one second
mark, and then one per second for as long as the client cares to wait.

The arithmetic of a denial is the part worth deriving rather than
reciting. After the sixth same-second draw the level is exactly zero,
so the next token exists one full second in the future, and that
instant is both the `Reset` header and the `Retry-After`. Half a
second later the level is 0.5: still not spendable, and the next whole
token is now only half a second away. A whole level always waits a
full period, a fraction waits its complement, which is the
`nextTokenIn` rule: the wait is `1 - frac(level)` over the refill
rate, and a denial never spends anything:

#listing("go/api/internal/limit/bucket.go", first: 64, last: 86, caption: [Allow: one draw, one decision, and the wait computed from the fractional level])

#diagram([bucket level over one draw timeline, the refill climbing between bursts], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [t, seconds], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.2), stroke: luma(120))
  cdraw.content((1.0, 7.35), [5], size: 6pt)
  cdraw.line((0.6, 6.4), (23.2, 6.4), stroke: luma(200), dash: "dashed")
  cdraw.content((23.8, 6.4), [capacity], size: 6pt)
  // burst of five at t0
  for i in range(5) {
    let x = 1.2 + i * 0.55
    cdraw.line((x, 6.4 - i * 1.05), (x + 0.5, 6.4 - (i + 1) * 1.05), stroke: luma(60))
  }
  cdraw.content((2.6, 3.0), [five draws, level 0], size: 6pt)
  // denied at t0
  cdraw.content((4.4, 1.1), [x], size: 7pt)
  cdraw.content((5.4, 1.1), [denied, retry after 1s], size: 6pt)
  // refill climb
  cdraw.line((4.5, 1.15), (10.0, 6.4), stroke: luma(60))
  cdraw.content((8.0, 2.2), [refill 1/s], size: 6pt)
  // one spend at t=1, then climb again
  cdraw.line((10.0, 6.4), (10.5, 5.35), stroke: luma(60))
  cdraw.content((10.9, 5.35), [sixth allowed at t=1], size: 6pt)
  cdraw.line((10.5, 5.35), (16.5, 6.4), stroke: luma(60))
  cdraw.content((14.0, 4.4), [level 0 again], size: 6pt)
  cdraw.line((16.5, 6.4), (23.0, 6.4), stroke: luma(60))
  cdraw.content((20.0, 5.6), [full, idle time earns nothing], size: 6pt)
  pane(17.6, 23.2, 2.4, [the two knobs], [burst 5: instant allowance], [1/s: forever allowance])
})

== x/time/rate in production

The teaching bucket is inspectable and stays in the chapter, the
shipped gate runs on `golang.org/x/time/rate`, which implements the
same bucket with reservations and a `Wait` mode behind one mutex. One
limiter per key lives in a map, created on first use, and
the map is the piece that needs a policy: every distinct key is a
goroutine-cheap but unbounded allocation, so an idle ttl retires keys
nobody has touched. The sweep is amortized into the request path,
every `idleTTL` of clock time a request sweeps inside the lock it
already holds, which deletes the janitor goroutine entirely, no
ticker, no stop method, no leak to chase in the load chapter.

Read as primitives, the shipped limiter is the teaching bucket with
the refill moved into the clock. The v0.15.0 struct is one
`sync.Mutex`, the limit, the burst, and the token level stamped with
the time it was last read: there is no goroutine and no ticker
anywhere in the file, `advance` converts elapsed time into tokens
lazily on every call, so the passage of time is the refill.
Reservations are the one move the teaching bucket does not make: a
grant for a future token lets the level go negative, and `Wait` is
that reservation plus a timer armed at the delay, cancellable by
context. One mutex, one float, one clock read, and a timer carry the
whole production gate, which is why this chapter could build a
faithful one first.

The third admission mode deserves its sentence. `Allow` rejects,
`Wait` blocks until a token exists or the context dies, and a queue
that wants to shed load rejects while a background worker that must
not drop work waits. `Wait` is not used on this api's routes because
an http handler that blocks on a limiter holds its connection and its
goroutine, which is precisely the resource the limit exists to
protect. The gate wiring is three lines in the program's table, and
its position in the onion is deliberate, between the access log and
the timeout, so every 429 is logged with its status and id and no
denial ever burns handler deadline budget:

#snippet("limiter := limit.NewLimiter(nil, 0)\nlimiter.Rule(\"/api/auth/login\", limit.LoginRule())\nlimiter.Rule(\"/api/users\", limit.RegisterRule())\napp.Use(limiter.Middleware)", lang: "go")

#listing("go/api/internal/limit/handler.go", first: 191, last: 212, caption: [per-key limiters, created on first use, swept on the same lock])

#diagram([key to limiter map, first use creates, idle age retires], length: 13pt, {
  cdraw.rect((0.4, 3.2), (11.0, 7.6), fill: luma(235), radius: 0.05)
  cdraw.content((5.7, 7.1), [the buckets map], size: 6.5pt)
  cdraw.content((3.4, 6.0), [#"login:ada@example.org"], size: 6pt)
  cdraw.content((3.4, 5.0), [#"login:grace@example.org"], size: 6pt)
  cdraw.content((3.4, 4.0), [#"ip:203.0.113.7"], size: 6pt)
  cdraw.line((11.2, 5.5), (12.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((5.7, 3.6), [one entry per key], size: 6pt)
  pane(12.8, 19.4, 7.6, [entry], [#"rate.Limiter burst 5"], [last touched: now])
  cdraw.line((19.6, 5.5), (21.0, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(21.2, 23.4, 7.6, [sweep], [idle past ttl], [delete, next use recreates])
  cdraw.line((5.7, 3.1), (5.7, 2.3), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 11.0, 2.1, [amortized], [one sweep per idleTTL], [on the lock the path holds anyway])
  cdraw.content((17.0, 1.2), [no ticker, no janitor goroutine, no leak], size: 6pt)
})

== the 429 contract

The wire shape is pinned by the contract and the frozen vector, and
the middleware writes it in one place. Every response from a limited
route carries three headers: `X-RateLimit-Limit` is the burst
capacity, `X-RateLimit-Remaining` is whole tokens left after this
draw, `X-RateLimit-Reset` is the unix second at which the next token
arrives. A denial adds `Retry-After` in seconds, the ceiling of the
wait, and answers the standard envelope with code `rate_limited`,
never a bare status or a bespoke error body.

The sixth login vector pins every byte. The clock sits at the frozen
`t0` plus twelve seconds, five earlier logins at the same instant left
the bucket reporting remaining 4, 3, 2, 1, 0, and the sixth draw finds
an empty bucket: status 429, `Limit` 5, `Remaining` 0, `Reset`
1790830813 which is exactly `t0` plus thirteen seconds, `Retry-After`
1, and the envelope's message the frozen `too many login attempts`.
The middleware writes the three headers before the handler runs, so
they ride on successes too, and the denial path writes the envelope
through the kernel's one failure writer, which is why the request id
in the body matches the one the access log just recorded:

#listing("go/api/internal/limit/handler.go", first: 138, last: 158, caption: [the middleware: three headers always, Retry-After and the envelope on denial])

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
  cdraw.content((3.0, 2.1), [burst five, each 401], size: 6pt)
  cdraw.rect((6.2, 3.1), (7.0, 3.7), fill: luma(60), radius: 0.02)
  cdraw.content((6.6, 2.1), [6th: 429], size: 6pt)
  cdraw.content((6.6, 1.2), [#"Retry-After: 1"], size: 6pt)
  cdraw.line((7.4, 1.6), (12.6, 1.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.0, 2.1), [client waits, does not hammer], size: 6pt)
  hit(12.8, 3.4, [7th ok])
  cdraw.content((12.8, 2.1), [at the reset instant], size: 6pt)
  hit(14.6, 3.4, [8th 429])
  hit(17.6, 3.4, [9th ok])
  cdraw.content((16.2, 2.1), [one per second, forever], size: 6pt)
  pane(0.6, 11.2, 0.4, [headers on every response], [limit 5, remaining, reset unix s], [the client can pace itself])
  cdraw.content((17.0, -0.4), [a client that ignores Retry-After gets 429s, not capacity], size: 6pt)
})

== what to key on

A limit is only as good as its key, and the two routes key on
different things for opposite reasons. Login keys on `lower(email)`:
the attack the rule exists for is guessing one account's password, so
the bucket belongs to the account, and the casing normalization means
`ADA@Example.ORG` and `ada@example.org` are one bucket. The key lives
in the request body, so the middleware reads the body once, bounded by
the kernel's one mebibyte cap, and hands it back unchanged for the
handler to decode again, a re-read that costs a copy of a body that is
by construction tiny. Register keys on the client ip from the remote
address, and the proxy headers stay unread on purpose:
`X-Forwarded-For` is a header any client can write, so a limiter that
keys on it verbatim sells a fresh bucket of ten registrations per
forged address, one per request, forever.

Two shared buckets close the dodge holes. A body the email key cannot
parse lands in one `login:unparsed` bucket, so garbage cannot orbit
the limit by being invalid, and a remote address that fails to split
lands in its own fallback. The test for the spoof is the contract
said out loud: eleven register posts from one address with a different
forged `X-Forwarded-For` on the last one, and the eleventh is still
the 429:

#listing("go/api/internal/limit/handler.go", first: 62, last: 79, caption: [KeyEmail: a bounded read, the body handed back, garbage into one shared bucket])

#diagram([key choice: the route decides what the bucket belongs to], length: 13pt, {
  cdraw.content((11.5, 8.0), [request arrives], size: 6.5pt)
  cdraw.line((11.5, 7.7), (11.5, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.7, 5.6), (15.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.3), [which path is this], size: 6pt)
  cdraw.line((8.5, 5.5), (5.2, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.5, 5.5), (17.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 4.4, [login], [body: lower(email)], [per account, burst 5])
  pane(13.8, 21.8, 4.4, [register], [remote addr host], [per address, burst 10])
  cdraw.line((5.2, 1.9), (5.2, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 1.0, [unparseable body], [one shared bucket], [invalid input still limited])
  cdraw.line((17.8, 1.9), (17.8, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(13.8, 21.8, 1.0, [forwarded-for], [ignored, client written], [trust needs a proxy contract])
  cdraw.content((11.5, -0.3), [an authenticated caller is a better key, and this api limits only its two unauthenticated routes], size: 6pt)
})

== limits under test

Every time-dependent behavior in this chapter is arithmetic on a fixed
clock, because a rate limiter tested against the wall clock is tested
against a scheduler. The injected clock moves in explicit offsets, the
fixed-draw vectors walk the bucket through its whole grammar, burst,
cap, sustained rate, half-token denial, and the vector replay runs the
production middleware against the frozen file: five setup draws assert
the remaining sequence 4 through 0, the sixth asserts the vector's
status, every header byte, and the envelope's code and message, with
the request id checked for uuid v7 shape only since this layer mints
it fresh. The `Wait` path runs inside a `testing/synctest` bubble,
where the fake clock jumps the moment every goroutine is durably
blocked, so the limiter's one-second wait costs no real time and the
test still asserts the bubble advanced by a full refill period. The
race detector runs over the package because the buckets map is
concurrent state, and no test anywhere in it sleeps:

#listing("go/api/internal/limit/limit_test.go", first: 125, last: 142, caption: [the vector replay: frozen clock at t0+12s, five draws, then the frozen sixth])

#diagram([the fixed-vector pipeline: file in, draws through the gate, bytes out], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [vector file], [frozen status, headers])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [clock pinned], [#"t0 + 12s, no wall time"])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [five draws], [remaining 4, 3, 2, 1, 0])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [assert bytes], [429, headers, envelope])
  pane(0.3, 11.2, 3.2, [the Wait test], [synctest bubble, fake clock], [one second costs nothing])
  pane(12.0, 23.0, 3.2, [the race lane], [CGO_ENABLED=1 -race], [over the per-key map])
  cdraw.content((11.5, 1.4), [drift means the code is wrong, the bytes never renegotiate], size: 6pt)
})

== admission preview

A rate limit refuses requests over time, an admission gate refuses
them over concurrency, and the two compose because they bound
different axes of the same cliff. Little's law states the trade in one
line: the average number of requests inside the system equals the
arrival rate times the time each spends there, `L = lambda W`. Offered
load raises the right side two ways, more arrivals or slower service,
and past the point where every arriving request finds all workers
busy, latency rises steeply while throughput stops moving, the hockey
stick the load chapter measures. A rate limit caps lambda at the edge.
An admission gate caps L directly with an in-flight semaphore, holds
one slot per admitted request, and answers the contract's `overload`
envelope the instant the slots run out, which converts a queue of
waiting requests, each holding memory and a goroutine, into a cheap
refusal. The semaphore and its 503 are the load chapter's to build,
along with the drain it protects:

#diagram([latency versus concurrency: the hockey stick the admission cap cuts off], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [in-flight, L], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  cdraw.content((0.6, 7.8), [latency, W], size: 6pt)
  cdraw.line((0.6, 1.3), (12.0, 1.9), stroke: luma(60))
  cdraw.line((12.0, 1.9), (16.0, 5.6), stroke: luma(60))
  cdraw.line((16.0, 5.6), (18.6, 7.5), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.0, 1.0), [workers busy below capacity], size: 6pt)
  cdraw.content((14.6, 3.4), [queueing begins], size: 6pt)
  cdraw.content((18.2, 6.4), [saturation], size: 6pt)
  cdraw.line((13.4, 0.7), (13.4, 6.9), stroke: luma(150), dash: "dashed")
  cdraw.content((13.4, 7.3), [admission cap], size: 6pt)
  pane(14.6, 23.2, 2.6, [past the cap], [every arrival waits, none serves], [the gate answers 503 overload])
  cdraw.content((7.5, 6.2), [L = lambda x W: the rate limit caps lambda], size: 6pt)
  cdraw.content((7.5, 5.1), [the admission gate caps L itself], size: 6pt)
})

sources: pkg.go.dev for golang.org/x/time/rate, read against the
go 1.27 module cache source for Allow, Wait, and TokensAt, plus the
testing/synctest package doc for the bubble and durable blocking
rules, and RFC 6585 for status 429 with RFC 9110 for the Retry-After
field semantics, all accessed 2026-09-25. Verified by
`go/api/internal/limit` tests, 11 of them, under `go test -race`,
plus gofmt and go vet over the module, with the sixth-login vector
replayed byte for byte from `contract/testdata/06-login-429.json`.
