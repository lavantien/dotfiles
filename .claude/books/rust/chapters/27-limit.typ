#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= rate limiting

Concurrency control answered how much at once and the cache answered
how long a representation may stand, and neither answers the client that asks
too fast forever. Rate limiting is the fairness layer: a budget per
caller, spent one token per request, refilled as time passes, and a
refused request answered with the one status code built for it, 429,
through the envelope the kernel already owns. This chapter builds
`rustapi::limit`, a token bucket per key behind one middleware layer,
the state swept out after an idle window so the limiter's memory is
bounded the moment it is born. The go book built its limiter on
`golang.org/x/time/rate` and then owned the same header questions,
#xref-to("go", "limit"), the java book built the bucket on nanos and
doubles, #xref-to("java", "limit"), and this lane builds it on
integer microtokens, where one period elapsed is exactly one token by
construction and no float ever rounds.

== why limits exist

Three reasons, and they rate differently. Fairness first: one
client's unbounded appetite is every other client's latency, a shared
server that does not budget its callers is arbitraged by whoever asks
fastest. Cost second: every request spends real compute and real
downstream work, and a scraper or a runaway retry loop can spend a
day of budget in an hour. Abuse third, the deliberate flood, where
the limit is a defense and the attacker's goal is exactly to be the
loudest caller. One mechanism answers all three, which is why it
lives as one layer at the stack's edge rather than as per-handler
counters, and why its refusals must be cheap: a limiter that spends
as much refusing as the requests cost asking protects nothing. The
budget is client-visible, not internal policy. The 429 carries the
shape of the budget in its headers and `Retry-After` carries the
wait, and a well-behaved client backs off and spaces its work, the
cheapest capacity upgrade a service ever ships.

== the token bucket, all integer

One bucket per key. It holds at most `burst` tokens, starts full,
every request spends one, and one whole token accrues per
`refill_period_millis` of elapsed time, capped at the burst. No timer
drips anything: refill is computed lazily at the moment a take
arrives, from the time elapsed since the last conversion, so a key
nobody asks about costs one map entry and zero wakeups. The level
lives in microtokens, `1_000_000` per whole token, and the refill
converts only whole periods, leaving the sub-period remainder banked
in the clock rather than the level:

#listing("rust/api/src/limit.rs", first: 50, last: 65, caption: [refill: whole periods convert to exactly one token each, the remainder stays in last_us, a full bucket snaps and wastes its idle time])

Two rules deserve their sentence each. The remainder-in-clock rule:
`last_us` advances only by the whole periods converted, so four
half-period advances accrue to exactly one token at the fourth, the
banking java needed epsilon tolerances for in doubles falls out of
the integers here, and the boundary test walks the waits `2, 1, 1`
across the halves and lands the token on the fourth tick exactly.
The cap rule: a full bucket snaps `last_us` forward and discards the
elapsed time, because tokens that could have accrued while the bucket
stood full are gone, and the test pins the consequence, after a
2.5-period idle on a 2-burst the next token arrives one full period
after the read, not 0.5 periods after it, the exact spot an
implementation that banks through the cap would over-admit.

#listing("rust/api/src/limit.rs", first: 72, last: 92, caption: [allow: spend within the level, the denial names the next whole token's arrival, the deficit rounded up to whole seconds])

The denial's arithmetic is one line: the wait is the distance from
now to `last_us + period`, the instant the next whole token arrives,
and `Retry-After` carries it rounded up to whole seconds, the
delay-seconds form rfc 9110 defines as a non-negative decimal
integer. The boundary table is the whole contract, measured under a
frozen clock:

#diagram([the bucket's answers, every boundary exact under a frozen clock], length: 13pt, {
  pane(0.3, 10.3, 8.6, [burst 3, period 2 s], [takes 1, 2, 3: allowed], [take 4: 429, retry after 2])
  cdraw.line((5.3, 6.2), (5.3, 5.4), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 10.3, 5.2, [advance exactly 2 s], [one token back: allowed], [then 429 again])
  cdraw.line((10.5, 6.8), (11.3, 6.8), stroke: luma(100), mark: (end: ">>"))
  pane(11.5, 22.5, 8.6, [advance 60 s], [still only 3 tokens], [the burst is the cap])
  cdraw.line((5.3, 2.6), (5.3, 1.8), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 10.3, 1.6, [advance 1 s], [half a period: 429], [retry after 1, then allowed])
})

At the burst, below it, far past it, exactly one period later, half a
period later, and one millisecond before the boundary, where the
refusal names one second because 1 ms of deficit rounds up and the
next tick lands it. The race test closes the section: 10 threads
against a burst of 5 at one frozen instant, and exactly 5 are
admitted no matter the interleaving, the mutex making the spend
monotone while the frozen clock makes refill a no-op, arithmetic
where a wall-clock test would have proven nothing on a loaded
machine.

== the 429 contract through the ch19 writer

Rfc 6585 defines the status, the user "has sent too many requests in
a given amount of time", says a response MAY carry `Retry-After`, and
says a 429 MUST NOT be stored by a cache, which chapter 26's table
satisfies by construction, a 429 is an answer about the request,
never a stored value. The layer writes the envelope itself through
the kernel's one failure writer, `ApiError` with the rate-limited
code, so the 429 rides the same body shape as every other failure
and carries the request id like them all:

#listing("rust/api/src/limit.rs", first: 187, last: 223, caption: [the layer: denial answers the envelope with all four headers, every allowed or failed response carries the three budget headers])

The three budget headers ride every limited response, allowed,
denied, or failed deeper in the stack, and `retry-after` rides only
the denial, exactly the asymmetry the rfc's MAY permits and the tests
pin: `x-ratelimit-limit`, `x-ratelimit-remaining`,
`x-ratelimit-reset` beside a 200, and the same three plus
`retry-after: 60` beside the 429 whose body is the envelope, code
`rate_limited`, the message, and a parseable request id. The refused
request costs the handler nothing, asserted with a counter that
reads exactly the admitted count after the flood.

== what to key on, and the address seam

The keyer is an injected function, the same construction every layer
in this service takes, and the choice is policy. Keying on the
resolved actor gives per-account budgets that follow the token,
keying on the client address gives one budget per machine that an
authenticated abuser cannot dodge by dropping their token, and
routes can be folded into the key to budget an expensive family
apart from a cheap one. Both siblings keyed on the remote address,
and here the honest fact is a seam: chapter 19's `Request` carries
no peer address, the wave's rule is wiring-only at the kernel, so
the shipped keyer budgets per actor with one shared pool for the
anonymous, and the address lane is the one-line `httpx` change a
later wave owes, stated here rather than papered over:

#listing("rust/api/src/limit.rs", first: 179, last: 185, caption: [the shipped keyer: the actor when authn has run, one shared pool before it])

The tests key on a header for the same reason production keys on an
identity, one server serving many independent budgets, and the
isolation test is the contract: address A exhausted to the last
token leaves address B's bucket untouched, two seats held, the
denial of one never spends the other.

== bounded per-key state

Every key that asks once gets a bucket, so the limiter is a memory
leak unless something reaps. Each seat carries its last-use
millis, and the sweep that retires idle keys runs amortized inside
the allow path, one retain when the window has elapsed since the
last sweep, the same trick the go lane used to delete the janitor
goroutine, with `held` exposed for the tests and for operators
probing memory:

#listing("rust/api/src/limit.rs", first: 139, last: 155, caption: [allow: the amortized sweep, the seat created on first use, the touch, then the take])

#listing("rust/api/src/limit.rs", first: 168, last: 175, caption: [the sweep: one retain, idle keys out, the sweep clock moved])

The constructor refuses an idle window shorter than one refill
period, because a window that tight would reap buckets between
their own refills, an assert the test drives with the
`should_panic` lane. The resurrection edge is owned rather than
hidden: a key evicted while quiet comes back to a fresh full burst,
an over-admission bounded by one burst per resurrection, and the
test walks it exactly, one address swept out mid-window, the holder
count at 1, and the returning address served from a full bucket.

== the wiring and the stack order

The stack order is contract. The rate decision runs first, a map
lookup and an integer take, so a flooding caller collects 429s
without ever being granted a cache fill, then the cache, then the
idempotency flight, all inside the access log so every refusal is a
logged line a client can be pointed at, the chapter 20 order rule
applied to three more layers:

#listing("rust/api/src/main.rs", first: 169, last: 175, caption: [the wiring: rate outside cache outside idempotency, all inside the log layer, the guard inside the whole stack])

The cache's janitor rides here too, one named thread sleeping 10
seconds between sweeps of the 512-entry, 30-second plane, and the
limiter runs burst 30 with one token per second and the default
10-minute idle window. The whole lane was driven through the real
binary, dated 2026-10-14: a fresh boot serves `POST /api/notes` with
the etag and the budget headers, `x-ratelimit-remaining` walking
down from 28 across the run, the second GET answers `x-cache: hit`,
a conditional GET answers the bodyless 304, a star `If-Match` PUT
lands version 2, and the same idempotency key replayed returns the
identical `location` in 29 microseconds without the handler running.

#diagram([the request path: the cheap integer refusal sits outside every expensive lane], length: 13pt, {
  pane(0.3, 5.1, 7.8, [request id, log], [every answer logged], [timing, recover])
  cdraw.line((5.3, 6.2), (5.7, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(5.9, 11.7, 7.8, [limit], [one integer take], [429 before any work])
  cdraw.line((11.9, 6.2), (12.3, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(12.5, 18.3, 7.8, [cache], [hit, or one fill], [the flight of ch26])
  cdraw.line((18.5, 6.2), (18.9, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(19.1, 24.3, 7.8, [idempotency], [replay or claim], [then authn, guard, router])
})

== the count

The module is 223 lines and its test file 265, and the 8 tests land
green three consecutive runs under the full gate, fmt, clippy at
`-D warnings`, the locked offline build, dated 2026-10-14: the
boundary table with its six cells and the millisecond-short cell,
the partial-advance banking at waits 2, 1, 1, the cap that wastes
its idle time, the isolation of two addresses' budgets, the refused
constructor lane, the idle sweep with the resurrection, the frozen
race admitting exactly 5 of 10, and the wire test's envelope,
headers, untouched handler, and second address. The crate holds 136
tests this wave, the 128 landed ones green unchanged, and the whole
gate, 85 sample files at 902 checks, the vectors hash, and the
zero-dep manifest, green end to end.

sources: RFC 6585 section 4 at rfc-editor.org, the 429 definition
quoted, the MAY on `Retry-After`, and the MUST NOT on storing 429
responses, accessed 2026-10-14. RFC 9110 section 10.2.3 at
rfc-editor.org, "The Retry-After field value can be either an
HTTP-date or a number of seconds to delay after receiving the
response" and the delay-seconds grammar as a non-negative decimal
integer, accessed 2026-10-14. The lazy refill, the burst ceiling,
the amortized idle sweep, and the header set follow the go book's
rate limiting chapter, book 4 chapter 26 of this corpus, and the
integer-exact accrual and the deficit rounding follow the java
book's chapter 27, read for the parallel contracts, with java's
floating-point tolerance discussion consulted for the divergence
this lane's microtokens avoid. The boundary table, the frozen race,
and the binary run produced by `cargo test --locked` under
`CARGO_NET_OFFLINE=true` and the built `rustapi.exe` on the pinned
1.99.0 build, three consecutive green runs, dated 2026-10-14.
