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

Concurrency control answers how much at once, admission answers how
long the rest may wait, and neither answers the client that asks too
fast forever. Rate limiting is the fairness layer: a budget per
client, spent one token per request, refilled as time passes, and
refused requests answered with the one status code built for them,
429, through the envelope the kernel already owns. This chapter
builds `javabook.limit`, a token bucket per key behind a filter,
with the buckets stored in the last chapter's sliding table so the
limiter's memory is bounded the moment it is born. The go book built
its limiter on `x/time/rate` and then owned the same contract
questions, #xref-to("go", "limit"), and this chapter owns them again
on nothing but `java.base`.

== why limits exist

Three reasons, and they rate differently. Fairness first: one
client's unbounded appetite is every other client's latency, a
shared server that does not budget its callers is arbitraged by
whoever asks fastest. Cost second: every request spends real money
in compute and in the downstream calls it fans out to, and a scraper
or a runaway retry loop can spend a day of budget in an hour. Abuse
third, the deliberate flood, where the limit is a defense and the
attacker's goal is exactly to be the loudest caller. The same
mechanism answers all three, which is why it lives as one layer at
the stack's edge rather than as per-handler counters, and why its
refusals must be cheap: a limiter that spends as much refusing as
the requests cost asking protects nothing.

The budget contract is client-visible, not internal policy. The 429
tells the client the shape of its budget, `Retry-After` tells it
when to come back, and a well-behaved client backs off and spaces
its work, which is the cheapest capacity upgrade a service ever
ships. A limiter that answers nothing, or answers 500, teaches
clients to retry harder, the exact opposite of the intent.

== the token bucket from first principles

One bucket per key: it holds at most `burst` tokens, starts full,
every request spends one, and one token accrues per
`refillPeriodNanos` of elapsed time, capped at the burst. The trick
worth naming is that no timer drips anything: refill is computed
lazily, from the nanos elapsed since the last refill point, at the
moment a take arrives, so a key nobody asks about costs exactly one
small object and zero wakeups. There is no borrowing, a take with
less than one token is refused and the balance stays put, and the
refusal names the wait for a whole token:

#listing("java/api/src/javabook/limit/TokenBucket.java", first: 62, last: 75, caption: [lazy refill by division, spend within an epsilon, refuse with the deficit rounded through microseconds])

One arithmetic decision is pinned by the boundary tests. The accrued
amount is elapsed divided by the period, not elapsed times a
precomputed rate, because a whole period divides back to exactly
1.0 in ieee doubles and the contract wants exactly that: one period
elapsed means exactly one token. Accrual spread across several takes
sums fractions, and a sum that is exactly one token in real
arithmetic can land a last ulp low in doubles, so the spend compares
within a tolerance and clamps at zero rather than refusing a token
the bucket holds. The refusal's deficit is rounded through whole
microseconds before the ceil to seconds, which strips the last-ulp
noise a non-binary period would otherwise inflate into a whole extra
second of `Retry-After`: at a three second period, two thirds of a
token answers 2, not 3. The take itself is `synchronized` on the
bucket, one monitor per key, so keys never contend each other and
the same-key race below is a monotone spend.

The boundary table, all under a frozen clock:

#diagram([the bucket's answers, every boundary exact under a frozen clock], length: 13pt, {
  pane(0.3, 10.3, 8.6, [burst 3, period 2 s], [takes 1, 2, 3: 200], [take 4: 429, retry after 2])
  cdraw.line((5.3, 6.2), (5.3, 5.4), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 10.3, 5.2, [advance exactly 2 s], [one token back: 200], [then 429 again])
  cdraw.line((10.5, 6.8), (11.3, 6.8), stroke: luma(100), mark: (end: ">>"))
  pane(11.5, 22.5, 8.6, [advance 60 s], [still only 3 tokens], [the burst is the cap])
  cdraw.line((5.3, 2.6), (5.3, 1.8), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 10.3, 1.6, [advance 1 s], [half a token: 429], [retry after 1, then 200])
})

At the burst, below it, above it, exactly one period later, far past
it, and half a period later: six cells across four tests, no sleeps,
the clock a hand-driven counter the filter and the buckets share,
and a third-period test walks accrual in thirds to pin the
floating-point tolerance and the uninflated header.

== the 429 contract

Rfc 6585 defines the status: "the user has sent too many requests in
a given amount of time". It says a response `MAY` include
`Retry-After`, and it says a 429 response `MUST NOT` be stored by a
cache, which chapter 26's table satisfies by construction, a 429 is
an answer about the request, never a stored value. The filter writes
the envelope itself through the kernel's one failure writer, with
the deficit rounded up to whole seconds, the delay-seconds form rfc
9110 defines for the header:

#listing("java/api/src/javabook/limit/RateLimit.java", first: 65, last: 78, caption: [one take per request, refusal written by the filter with the header riding the envelope])

The header is set before the envelope is written because the
exchange keeps its own response headers and the kernel writer sends
what is there, and the answer is written, never thrown, the chain
fact chapter 22 established: the kernel's `ApiError` adapter wraps
the route handler at the bottom of the filter chain, so a filter
exception would climb past it unanswered and drop the connection.
The refused request costs the handler nothing, which the tests
assert with a hit counter, and the envelope carries the request id
like every other failure, so a rate-limited client can correlate
the refusal in its own logs.

== what to key on

The keyer is an injected function, the same seam every layer in this
service takes, and the choice is policy. Keying on the bearer token
gives per-account budgets that die with logout. Keying on the remote
address, the production default here, gives one budget per client
machine that an authenticated abuser cannot dodge by dropping their
token, and shares the anonymous and authenticated traffic of one
address, the conservative reading. Routes can be keyed too, an
expensive family given a smaller budget than a cheap one, by folding
the resolved pattern into the key. The tests key on a header for the
same reason production keys on the address, one app serving many
independent budgets.

== burst and the sustained rate

The bucket's two numbers say different things and clients feel both.
The burst is the short-term allowance, a fresh or idle key may spend
`burst` requests back to back, which is what makes interactive
clients workable, a page load that fans into 6 requests should not
meet a limiter on its first second. The refill period is the
sustained rate, one token per 2 seconds in the tests, 30 per second
in the wiring, and past the burst the client is throttled to exactly
that pace, one refusal with a truthful `Retry-After` per step. The
alternative shape, a leaky bucket that smooths output to a constant
rate with no burst, protects a fragile downstream better and treats
clients worse, and a windowed counter that resets each second lets
2 times the budget through at the boundary, 30 at the end of one
second and 30 at the start of the next. The token bucket sits
between them, its burst explicit and its sustained rate exact, and
the boundary tests pin both edges: the burst is reachable in one
instant and never exceeded by any refill, however long the wait.
The wiring runs burst 30 with one token per second per address,
thirty back to back for a fresh caller, then a steady one per
second.

== bounded per-key state

Every key that asks once gets a bucket, so the limiter is a memory
leak unless something reaps. The buckets live in the cache chapter's
`TtlTable` under its sliding window: every request slides the key's
deadline, so a busy key keeps its bucket forever and an idle key's
bucket dies one window after its last request, reclaimed by the next
write that needs the slot. The table's cap is the hard bound, 10,000
keys in the wiring, and the constructor refuses an idle window
shorter than one refill period because a window that tight would
reap live buckets between requests:

#listing("java/api/src/javabook/limit/RateLimit.java", first: 84, last: 93, caption: [the production keyer: one bucket per client address, shared across its identities])

The flood test walks 12 keys past a cap of 2 and asserts 2 held at
the end, the same monotone claim the cache chapter's stress made,
reached here through the filter's own door.

The cap has a second edge the design owns rather than hides: when
every held bucket is live, the soonest-deadline eviction retires the
least recently touched key, and if that key comes back it returns to
a fresh bucket with a full burst. A key flood past the cap can
therefore reset a quiet client's budget, an over-admission bounded
by one burst per resurrection, and the honest account is that the
alternative is unbounded per-key memory. The resurrection test pins
exactly this behavior, one token spent, two livelier keys evicting
the victim inside its window, and the victim's next request served
from a fresh full bucket. The flood's other price is the scan: only
a new key at a full table pays the eviction walk, the hit path is
one per-key atomic step, so hot traffic never queues behind the
flood, the sharded-table escape the cache chapter named.

== the admission contrast

Chapter 25's admission layer and this one refuse requests from the
same stack, and keeping their meanings straight is the contract. The
429 says the client asked too fast, it is the client's budget and
the client's clock, the retry is warranted and `Retry-After` says
when. The 503 says the server is at capacity right now, it is the
server's state and not the client's fault, and a well-behaved
client backs off longer and does not count it against itself. The
two layers sit together because they protect different things,
fairness and capacity, and the order between them is the wiring's
sentence: rate outside admission, so the cheap arithmetic refusal
answers a flood before the flood is ever granted a wait, and a
client hammering a saturated server collects honest 429s, not
ambiguous 503s that look like the server's failure. Go's limiter
chapter closed on the same pairing, and the go book's admission
preview is this book's chapter 25, landed one chapter early because
java's executor story forced the question first.

== limits under test

The race is the one that matters: 10 concurrent requests against a
burst of 5, clock frozen so no refill can accrue no matter how the
scheduler interleaves, and exactly 5 answer 200 while 5 answer 429,
the take's monitor making the spend monotone under any ordering:

#listing("java/api/test/javabook/limit/RateLimitTests.java", first: 220, last: 251, caption: [twice the burst racing at one frozen instant: exactly the burst admitted, every other answer the 429])

That is the whole difference between a limiter tested against
wall-clock sleeps, which proves nothing on a loaded machine, and one
tested against arithmetic, which proves the contract. Ten tests:
four carrying the six boundary cells, the third-period accrual walk,
the live-key eviction and its fresh burst, the independence of two
keys' budgets, the request id riding the 429 envelope, the memory
bound under the key flood, and the race. The wiring seats the layer
outside admission,
so a flooding address collects 429s without ever being granted an
admission wait, and inside the access log, so every refusal is a
logged line a client can be pointed at.

sources: rfc 6585, additional http status codes, section 4, the 429
definition, the MAY on Retry-After and the MUST NOT on storing 429
responses, at rfc-editor.org, accessed 2026-10-05. The Retry-After
delay-seconds form from rfc 9110, section 10.2.3, same access date.
`Semaphore` and monitor semantics inherited from chapter 10's jep
444 and jep 491 verifications. The token bucket's lazy refill and
burst semantics follow the go book's rate limiting chapter, book 3,
chapter 26, read for the parallel contracts, and `x/time/rate`'s
behavior was not re-measured here because nothing in this chapter
depends on it. Verified live 2026-10-05 by the `javabook.limit`
tests under the vendored junit 6.1.3 lane, 10 tests green three
consecutive runs, boundaries asserted under a frozen clock on
tools/jdk27/build/jdk-27.
