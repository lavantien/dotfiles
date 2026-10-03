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
none of them: password guessing arrives as a flood of logins, a runaway
client loop arrives as the same request ten thousand times, a retry
storm arrives the moment a deploy slows one route down. This chapter
builds the service's rate limiting in `api/src/limit`: the token bucket
derived from first principles over an injected clock, the gate that
keeps one bucket per key and sweeps the idle ones, the 429 contract
with its headers and the one envelope writer, what to key a limit on
and what never to trust, and the test discipline that keeps every
refill and every reset second off the wall clock.

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
every login attempt pays the scrypt verification budget and a
credential guesser does not need more than five tries to be dangerous.
Register allows ten per client ip for the same reason plus its
idempotency bookkeeping. Both refill one token per second, so a client
that trips the limit is back to full capacity five and ten seconds
later, which is the difference between a limit and a lockout:

#listing("javascript/api/src/limit/limiter.mjs", first: 10, last: 22, caption: [the contract's two rules as one constant block, numbers and messages])

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
them. That is the entire algorithm, and its two knobs split the two
jobs cleanly: capacity is the burst allowance, how much may arrive at
once, and the refill rate is the sustained allowance, how much may
arrive per second forever. The contract's login rule, capacity five at
one per second, permits five requests in the first instant, a sixth at
the one second mark, and then one per second for as long as the client
cares to wait.

The arithmetic of a denial is the part worth deriving rather than
reciting. After the fifth same-instant draw the level is exactly zero,
so the next token exists one full second in the future, and that
instant is both the reset header and the retry hint. Half a second
later the level is 0.5: still not spendable, and the next whole token
is now only half a second away. A whole level always waits a full
period, a fraction waits its complement, which is the wait rule in the
listing: the wait is `1 - fraction(level)` over the refill rate, and a
denial never spends anything. The level never leaves this module as a
float: the wire sees whole remaining tokens, a unix second for reset,
and a ceiling of seconds for retry:

#listing("javascript/api/src/limit/bucket.mjs", first: 30, last: 49, caption: [allow: one draw, one decision, the wait computed from the fractional level])

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

== one bucket per key

One bucket for the whole service would let one attacker spend every
other client's tokens, so the gate keeps one bucket per key in a plain
`Map`, created on first use and stamped with the instant it was last
touched. Every distinct key is a cheap but unbounded allocation, so an
idle ttl retires keys nobody has touched. The sweep is amortized into
the request path: whenever a full ttl has passed, the lookup sweeps
inside the same call, which deletes the sweeper timer entirely, no
ticker to leak in the load chapter.

The go lane reached for `golang.org/x/time/rate` here and spent its
section reading that library as primitives. The javascript lane has no
sanctioned equivalent to adopt, and the npm convention, `bottleneck`
and `rate-limiter-flexible`, is dated meta this vehicle deliberately
fails to meet: both are community-owned behavioral boxes over exactly
the arithmetic this chapter already built, one float, one clock read,
one comparison, and adopting one would buy a dependency where the
platform needs none. The teaching bucket is the production gate.

Node also removes half the go lesson for free: there is no mutex
anywhere in this file. The gate runs on one thread, the only
interleaving point between two requests is the `await` between the key
derivation and the decision, and the decision itself is computed
without yielding, so the buckets map cannot observe a torn state:

#listing("javascript/api/src/limit/limiter.mjs", first: 125, last: 143, caption: [entryFor: per-key buckets, created on first use, swept on the same call])

#snippet("const { limiter, layer } = wireLimit({ fail: envelopeWriter })\napp.use(layer)", lang: "javascript")

#diagram([key to bucket map, first use creates, idle age retires], length: 13pt, {
  cdraw.rect((0.4, 3.2), (11.0, 7.6), fill: luma(235), radius: 0.05)
  cdraw.content((5.7, 7.1), [the buckets map], size: 6.5pt)
  cdraw.content((3.4, 6.0), [#"login:ada@example.org"], size: 6pt)
  cdraw.content((3.4, 5.0), [#"login:grace@example.org"], size: 6pt)
  cdraw.content((3.4, 4.0), [#"ip:203.0.113.7"], size: 6pt)
  cdraw.line((11.2, 5.5), (12.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((5.7, 3.6), [one entry per key], size: 6pt)
  pane(12.8, 19.4, 7.6, [entry], [bucket: level 4.0], [last touched: now])
  cdraw.line((19.6, 5.5), (21.0, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(21.2, 23.4, 7.6, [sweep], [idle past ttl], [delete, next use recreates])
  cdraw.line((5.7, 3.1), (5.7, 2.3), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 11.0, 2.1, [amortized], [one sweep per idle ttl], [on the call the path makes anyway])
  cdraw.content((17.0, 1.2), [no sweeper timer, no mutex, one thread], size: 6pt)
})

== the 429 contract

The wire shape is pinned by the contract and the frozen vector, and the
layer writes it in one place. Every response from a limited route
carries three headers: `X-RateLimit-Limit` is the burst capacity,
`X-RateLimit-Remaining` is whole tokens left after this draw,
`X-RateLimit-Reset` is the unix second at which the next token arrives.
A denial adds `Retry-After` in seconds, the ceiling of the wait, and
answers the standard envelope with code `rate_limited`, never a bare
status or a bespoke body.

The denial path is a throw, not a write. The layer sets the four
headers on the response object, then throws the kernel's one failure
value, `fail(CODES.rate_limited, rule.message)`, and the kernel's
backstop catches it and renders the envelope through the single writer
every other error already flows through. That is why the request id in
the 429 body is the same id the access log and the metrics series will
carry: one id minted once at the edge, one writer, one shape:

#listing("javascript/api/src/limit/layer.mjs", first: 14, last: 37, caption: [the layer: three headers always, Retry-After and the thrown failure on denial])

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
in the request body, and a node stream cannot be unread: the key
function takes the body the earlier middleware parsed when there is
one, reads bounded once when there is not, and stashes the parse on
the context so the handler below reuses it instead of waiting on a
consumed stream. Register keys on the client ip from the socket's
remote address, and the proxy headers stay unread on purpose:
`X-Forwarded-For` is a header any client can write, so a limiter that
keys on it verbatim sells a fresh bucket of ten registrations per
forged address, one per request, forever.

Two shared buckets close the dodge holes. A body the email key cannot
parse lands in one `login:unparsed` bucket, so garbage cannot orbit
the limit by being invalid, and a body the bounded reader cannot read
lands in `login:unreadable`. The test for the spoof is the contract
said out loud: eleven register posts from one real address with a
different forged forwarding header on the last one, and the eleventh
is still the 429, because the key read the socket, not the header:

#listing("javascript/api/src/limit/limiter.mjs", first: 56, last: 76, caption: [keyEmail: bounded read, the parse stashed, the over-cap 413 propagating])

#diagram([key choice: the route decides what the bucket belongs to], length: 13pt, {
  cdraw.content((11.5, 8.0), [request arrives], size: 6.5pt)
  cdraw.line((11.5, 7.7), (11.5, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.7, 5.6), (15.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.3), [which path is this], size: 6pt)
  cdraw.line((8.5, 5.5), (5.2, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.5, 5.5), (17.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 4.4, [login], [ctx.body: lower(email)], [per account, burst 5])
  pane(13.8, 21.8, 4.4, [register], [socket.remoteAddress], [per address, burst 10])
  cdraw.line((5.2, 1.9), (5.2, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(1.2, 9.2, 1.0, [unparseable body], [one shared bucket], [invalid input still limited])
  cdraw.line((17.8, 1.9), (17.8, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(13.8, 21.8, 1.0, [forwarded-for], [ignored, client written], [trust needs a proxy contract])
  cdraw.content((11.5, -0.3), [an authenticated caller is a better key, and this api limits only its two unauthenticated routes], size: 6pt)
})

== limits under test

Every time-dependent behavior in this chapter is arithmetic on a fixed
clock, because a rate limiter tested against the wall clock is tested
against a scheduler. The bucket tests walk the whole grammar of the
level in fixed draws, burst, cap, sustained rate, the half-token
denial, a backwards jump, plus a seeded prng loop over five thousand
random tick and draw steps asserting the named invariants: the level
stays in range, remaining is always its floor, and a denial's reset
instant is exactly now plus its wait.

The vector replay runs the real layer on the real kernel against the
frozen file. `mock.timers.enable` pins `Date.now` to the vector's
instant, t0 plus twelve seconds, all six requests fire at that same
frozen instant, and the sixth asserts every header byte and the body
through the kernel's writer. One platform fact earned its place in
this code the hard way: a default clock captured as the `Date.now`
reference still sees the real clock after the mock replaces the global
`Date`, because the capture happened first. The seam is a thunk,
`now = () => Date.now()`, which resolves the global on every call, and
that is the difference between a passing replay and a reset header
four days off:

#listing("javascript/api/test/limit/layer.test.mjs", first: 55, last: 72, caption: [the vector replay: fake clock at t0+12s, five draws, then the frozen sixth])

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
  pane(0.3, 11.2, 3.2, [the clock seam], [thunk, not a captured ref], [mock timers reach it])
  pane(12.0, 23.0, 3.2, [the refill test], [tick(1000), draw again], [reset moves one second])
  cdraw.content((11.5, 1.4), [drift means the code is wrong, the bytes never renegotiate], size: 6pt)
})

sources: nodejs.org/api/test.html for the mock timers, `enable`,
`tick`, `reset`, and `t.after`, including what the mock replaces, read
2026-09-26 and probed on node 26.3.0, nodejs.org/api/http.html for
`setHeader` and `IncomingMessage` url handling, nodejs.org/api/net.html
for `socket.remoteAddress` and its ipv6-mapped `::ffff:` form, plus
RFC 6585 for status 429 and the MDN `Retry-After` page for the delay
seconds semantics, all accessed 2026-09-26. Verified by
`javascript/api` tests, 21 of them under `test/limit`, green under
`npm run verify`, with the sixth-login vector replayed byte for byte
from `contract/testdata/06-login-429.json`.
