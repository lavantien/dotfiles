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
runaway client loop arrives as the same request thousands of times,
and a retry storm arrives the moment a slow route teaches every
caller to resend. This chapter builds the service's rate limiting in
`service/limit.lua`: the token bucket derived from first principles
with the clock injected, one keyed table whose idle sweep is
amortized into the draw, the 429 contract with its headers and
envelope, what to key a limit on and what the host seam actually
provides, and the fixed-clock test discipline that keeps every
assertion off the wall clock.

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
every login attempt pays the password verification budget, the
pbkdf2 ladder the authentication chapter measures, and a credential
guesser does not need more than five tries to be dangerous. Register
allows ten per client ip for the same reason plus its idempotency
bookkeeping. Both refill one token per second, so a client that trips
the limit is back to full capacity five and ten seconds later, which
is the difference between a limit and a lockout:

#listing("lua/service/limit.lua", first: 11, last: 24, caption: [the contract's two rules as one constant block, numbers and messages frozen by the vectors])

#diagram([offered load versus what the service can carry, the cliff between them], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [requests/s], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.6), stroke: luma(120))
  cdraw.content((0.6, 7.8), [capacity used], size: 6pt)
  cdraw.line((0.6, 0.7), (10.0, 5.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((10.0, 5.2), (23.2, 5.2), stroke: luma(60))
  cdraw.content((6.2, 3.4), [carried = offered], size: 6pt)
  cdraw.content((17.0, 5.9), [carried = capacity], size: 6pt)
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

A token bucket holds a floating level, a capacity, and a refill rate.
It starts full, every allowed request removes one token, and time adds
tokens continuously at the configured rate until the capacity caps
them, one `math.min` call. That is the entire algorithm, and its two
knobs split the two jobs cleanly: capacity is the burst allowance, how
much may arrive at once, and the refill rate is the sustained
allowance, how much may arrive per second forever. The contract's
login rule, capacity five at one per second, permits five requests in
the first instant, a sixth at the one-second mark, and then one per
second for as long as the client cares to wait.

The arithmetic of a denial is the part worth deriving rather than
reciting. After the sixth same-second draw the level is exactly zero,
so the next token exists one full second in the future, and that
instant is both the `X-RateLimit-Reset` stamp and the `Retry-After`
value. Half a second later the level is 0.5: still not spendable, and
the next whole token is now only half a second away. A whole level
waits a full period, a fraction waits its complement over the refill
rate, and a denial never spends anything:

#listing("lua/service/limit.lua", first: 45, last: 65, caption: [allow: one draw, one decision, the wait computed from the fractional level])

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
  cdraw.content((2.6, 3.0), [five draws, level 0], size: 6pt)
  cdraw.content((4.4, 1.1), [x], size: 7pt)
  cdraw.content((5.4, 1.1), [denied, retry after 1s], size: 6pt)
  cdraw.line((4.5, 1.15), (10.0, 6.4), stroke: luma(60))
  cdraw.content((8.0, 2.2), [refill 1/s], size: 6pt)
  cdraw.line((10.0, 6.4), (10.5, 5.35), stroke: luma(60))
  cdraw.content((10.9, 5.35), [sixth allowed at t=1], size: 6pt)
  cdraw.line((10.5, 5.35), (16.5, 6.4), stroke: luma(60))
  cdraw.content((14.0, 4.4), [level 0 again], size: 6pt)
  cdraw.line((16.5, 6.4), (23.0, 6.4), stroke: luma(60))
  cdraw.content((20.0, 5.6), [full, idle time earns nothing], size: 6pt)
  pane(17.6, 23.2, 2.4, [the two knobs], [burst 5: instant allowance], [1/s: forever allowance])
})

== the keyed table and its sweep

The go lane builds the teaching bucket and then reads the production
limiter out of a library. This lane has no second implementation to
read: the first-principles bucket is the production gate, so the
lesson moves to the table that keys it. One limiter owns a rules table
keyed by route path and a buckets table keyed by limit key, each entry
created on first use, and the entry is exactly the bucket of the
previous section plus a last-touch stamp. The constructor refuses to
run without an injected clock, an `assert` in the constructor, so a
wiring that reaches for `os.time` fails at startup instead of
silently testing against the wall.

The sweep is amortized into the draw. Every `idle_ttl` of clock time,
the pass a limited route already pays walks the table and retires keys
nobody touched, which deletes the janitor entirely: no timer, no
ticker, no janitor coroutine parked somewhere the load chapter has to
find. A retired entry becomes garbage the collector reclaims on its
own incremental schedule, the collector chapter's truth, where the go
lane's sweeper frees memory the moment it deletes. The third admission
mode the go lane taught, the reservation and its `Wait`, does not
exist here on purpose: the vm is single threaded, and a wait would
hold the only thread the service has, so an immediate refusal is the
only honest answer a limit on this platform can give:

#listing("lua/service/limit.lua", first: 157, last: 179, caption: [draw: the sweep amortized into the pass, the bucket created on first use])

#diagram([key to bucket table, first use creates, idle age retires], length: 13pt, {
  cdraw.rect((0.4, 3.2), (11.0, 7.6), fill: luma(235), radius: 0.05)
  cdraw.content((5.7, 7.1), [the buckets table], size: 6.5pt)
  cdraw.content((3.4, 6.0), [#"login:ada@example.org"], size: 6pt)
  cdraw.content((3.4, 5.0), [#"login:grace@example.org"], size: 6pt)
  cdraw.content((3.4, 4.0), [#"ip:203.0.113.7"], size: 6pt)
  cdraw.line((11.2, 5.5), (12.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((5.7, 3.6), [one entry per key], size: 6pt)
  pane(12.8, 19.4, 7.6, [entry], [level, last refill, last touch], [created on first use])
  cdraw.line((19.6, 5.5), (21.0, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(21.2, 23.4, 7.6, [sweep], [idle past ttl], [dropped, gc reclaims])
  cdraw.line((5.7, 3.1), (5.7, 2.3), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 11.0, 2.1, [amortized], [one sweep per idle_ttl], [on the draw the route pays anyway])
  cdraw.content((17.0, 1.2), [no timer, no janitor coroutine, nothing to leak], size: 6pt)
})

== the 429 contract

The wire shape is pinned by the contract and the frozen vector, and
one function writes it. Every response from a limited route carries
three headers: `X-RateLimit-Limit` is the burst capacity,
`X-RateLimit-Remaining` is whole tokens left after this draw, and
`X-RateLimit-Reset` is the unix second at which the next token
arrives, floored. A denial adds `Retry-After` in seconds, the ceiling
of the wait, and answers the standard envelope with code
`rate_limited`, never a bare status or a bespoke body.

The layer owns every draw. No handler draws a bucket, no handler
stamps a rate header, and the login key normalizes the email exactly
once inside the key function. The layer draws before it calls the
handler, stamps the three headers on the response the handler returns,
and on denial never calls the handler at all, answering through the
injected failure writer so the request id in the envelope is the same
id the access log records. One boundary is worth stating where the go
lane has none: a handler that raises produces no response value at
this layer at all, the error travels up and the kernel's recover
answers above, so that answer carries no rate headers, where the go
writer sets its headers before the handler runs and they ride every
later status. The refusal itself still carries the headers, because a
denial is answered here, inside the layer. One replay divergence is
ruled and stated: the frozen register vectors answer without rate
headers, so the replay attaches the login rule only, while the
production composition attaches both rules and stamps every limited
route:

#listing("lua/service/limit.lua", first: 181, last: 202, caption: [stamp: three headers appended in order, retry-after ceil on denial])

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
different things for opposite reasons. Login keys on the lower-cased
email: the attack the rule exists for is guessing one account's
password, so the bucket belongs to the account, and the fold happens
in exactly one place, the key function, so both casings of one
address are one bucket and no other layer re-normalizes. A body
without a usable email lands in one shared `login:unparsed` bucket,
because garbage must not orbit the limit by being invalid.

Register keys on the client ip, and here the platform tells the truth
about provenance: the c host's seam answers the connection's peer
through one call, host only, no port, and the kernel stamps it on the
request once, so the key function splits nothing it does not have to.
Proxy headers stay unread on purpose: `X-Forwarded-For` is a header
any client can write, so a limiter that keys on it verbatim sells a
fresh bucket of ten registrations per forged address, one per request,
forever. When no peer exists, the internal listener and the
in-process tests, the key falls to one shared `ip:unknown` bucket,
fail closed: unknown callers share capacity rather than each minting
their own:

#listing("lua/service/limit.lua", first: 79, last: 102, caption: [key_peer: port split, bracketed ipv6 kept bare, fail closed on no peer])

#diagram([key choice: the route decides what the bucket belongs to], length: 13pt, {
  cdraw.content((11.5, 8.0), [request arrives], size: 6.5pt)
  cdraw.line((11.5, 7.7), (11.5, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.7, 5.6), (15.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.3), [which path is this], size: 6pt)
  cdraw.line((8.5, 5.5), (5.2, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.5, 5.5), (17.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 4.4, [login], [body: lower(email)], [per account, burst 5])
  pane(13.8, 21.8, 4.4, [register], [peer ip from the seam], [per address, burst 10])
  cdraw.line((5.2, 1.9), (5.2, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 1.0, [unparseable body], [one shared bucket], [invalid input still limited])
  cdraw.line((17.8, 1.9), (17.8, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(13.8, 21.8, 1.0, [no peer], [one unknown bucket], [fail closed, shared capacity])
  cdraw.content((11.5, -0.3), [the seam answers the socket's peer, a header answers whoever wrote the header], size: 6pt)
})

== limits under test

Every time-dependent behavior in this chapter is arithmetic on a fixed
clock, because a rate limiter tested against the wall clock is tested
against a scheduler. The test list walks the bucket through its whole
grammar with literal numbers: the burst drain reporting remaining 4
through 0, the sixth same-instant draw denied with the exact one-second
wait, the half-second refill raising the level to an unspendable 0.5
and shrinking the wait to 0.5, the fractional level paying its
complement, the idle century capping at capacity, and the denial that
spends nothing. The frozen sixth-login vector pins the arithmetic to
the contract's bytes: the clock at `t0` plus twelve, the reset stamp
1790830813 which is exactly `t0` plus thirteen, `Retry-After` 1, and
the message the vector froze. The byte-exact replay runs in the
resource family's vector suite, five setup draws and the frozen sixth
through the composed stack with status, headers, and envelope
asserted. No test sleeps, and the module reads no clock at
all, the constructor refuses one:

#listing("lua/service/limit.lua", first: 300, last: 316, caption: [the vector's numbers as a fixed-clock test, t0 plus 12, reset t0 plus 13])

#diagram([the fixed-clock pipeline: constants in, draws through the bucket, literals out], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [the constants], [burst 5, refill 1/s])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [clock pinned], [#"t0 + 12, no wall time"])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [five draws], [remaining 4, 3, 2, 1, 0])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [assert literals], [reset, retry-after, message])
  pane(0.3, 11.2, 3.2, [the grammar], [burst, cap, sustained, fraction], [every case a literal])
  pane(12.0, 23.0, 3.2, [the replay, later], [through the composed stack], [bytes against the vector file])
  cdraw.content((11.5, 1.4), [drift means the code is wrong, the bytes never renegotiate], size: 6pt)
})

sources: lua.org manual 5.5 sections 6.2 (basic functions, the pairs
walk and tonumber used by the table and its tests), 6.5 (string
manipulation, the find and sub of the key split), and 6.8
(mathematical functions, min, floor, ceil), RFC 6585 section 4 for
status 429 and RFC 9110 section 10.2.3 for the Retry-After field, all
accessed 2026-09-27. Verified by the service plain lane under the
pinned lua 5.5 with this module's 14 tests among the suite's green
run, the frozen vector's numbers asserted from
`contract/testdata/06-login-429.json`, and the byte-exact composed
replay green in the resource family's vector suite.
