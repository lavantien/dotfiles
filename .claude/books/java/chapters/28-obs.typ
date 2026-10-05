#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= observability

The spine has logs, one line per exchange with its request id, and
logs answer who did what. Nothing yet answers how much and how slow,
and those are the questions a pager asks at three in the morning.
This chapter builds `javabook.obs` on nothing outside the jdk: the 2
series a service actually reads, one counter per route and status and
one latency histogram per route, both on `LongAdder` and rendered
straight into the prometheus text format, the ops listener that serves
the exposition on its own port beside the api port, the module's one
custom JFR event that is free the moment no recording runs, and the
percentile arithmetic the next chapter's load reports quote. The go
book built the same layer with slog's redaction and a hand-rolled
traceparent on top, #xref-to("go", "obs"), and this chapter owns the
same contracts where they differ on java: the filter stack owns the
tick, the exchange remembers its own status, and the runtime owns the
profiling surface.

== the two series

A counter only ever goes up and a histogram only ever answers which
bucket, and both are registry types here rather than library imports.
`javabook.requests_total` is one row per route and status code, the
route label taken from the pattern table itself, and
`javabook_request_duration_seconds` is one per route with the sum and
count a scraper needs beside the buckets. Every observation is one
method:

#listing("java/api/src/javabook/obs/Metrics.java", first: 77, last: 91, caption: [one observation: the counter row, the route's histogram, and the bucket walk])

Three decisions in that walk earn their sentences. The buckets are
cumulative, an observation fills every bound at or above it, which is
the prometheus shape and what makes the counts monotone in the bound.
The bounds live in whole nanoseconds and compare in whole nanoseconds,
so no double conversion ever decides which bucket a latency lands in,
the same arithmetic discipline the token bucket chapter kept for its
refill. And the per-bucket cells are eager `LongAdder`s, one per bound
per route, a few dozen bytes each, because a lazily created cell is a
check-then-act race under a route's first concurrent observations:
the adversarial round measured lost increments exactly there, a fresh
route's first 8 simultaneous observations could sum 7 in a bucket
against 8 in the count, and the cumulative property would stay broken
forever after. Zero buckets are still elided, the render simply skips
cells whose sum is zero, and monotone counts keep the zeros a prefix
below the smallest observation.

#diagram([cumulative buckets: one observation fills every bound above it], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [the bound, seconds], size: 6pt)
  let b = (0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5)
  for (i, bound) in b.enumerate() {
    let x = 1.2 + i * 1.85
    cdraw.line((x, 0.7), (x, 1.3), stroke: luma(150))
    cdraw.content((x, 0.2), [#str(bound)], size: 5pt)
  }
  cdraw.line((22.0, 0.7), (22.0, 1.3), stroke: luma(150))
  cdraw.content((22.0, 0.2), [#("+Inf")], size: 5pt)
  cdraw.content((3.0, 6.9), [observed 3 ms], size: 6pt)
  cdraw.line((3.0, 6.5), (3.0, 5.6), stroke: luma(100), mark: (end: ">>"))
  for i in range(2, 11) {
    cdraw.circle((1.2 + i * 1.85, 5.2), radius: 0.26, fill: luma(160))
  }
  cdraw.circle((22.0, 5.2), radius: 0.26, fill: luma(160))
  cdraw.content((10.5, 5.2), [+1 to every bound at or above 5 ms], size: 6pt)
  pane(0.4, 10.4, 2.4, [the ladder], [tight low, geometric tail], [11 finite bounds plus Inf])
  pane(12.4, 23.2, 2.4, [the cells], [LongAdder, null until touched], [counts only grow])
})

The ladder itself is a policy statement: tight at 1, 2.5, and 5
milliseconds where service latencies live, geometric through 50, 100,
250, 500 and the seconds, because a bucket ladder spends its
resolution where the tail questions are asked and nowhere else.

== the text exposition

The registry renders the prometheus text format directly, `#` comment
lines carrying the types, series sorted by label tuple so byte-for-byte
comparisons work in tests, bucket lines ascending with `+Inf` last,
then the sum and the count:

#listing("java/api/src/javabook/obs/Metrics.java", first: 97, last: 128, caption: [the whole writer: sorted rows, elided zero buckets, seconds as exact decimals])

Two render decisions are pinned by tests. The seconds are
`BigDecimal` over whole nanoseconds with trailing zeros stripped, so
`903400000` nanoseconds prints `0.9034` and never a float artifact,
and every histogram line carries the route as its one label because
the code label already lives on the counter rows, two series that
answer two different questions. The frozen vector test drives 3
observations of 3 ms, 0.4 ms, and 900 ms through a bare registry and
pins the exact 17 lines, the 2 type comments and 15 series lines,
including the `0.001` bucket the 0.4 ms observation fills. The
elision has its own test, the divergence from the client libraries,
which print every finite bucket at zero as well: a registry whose
smallest observation is 3 ms renders no `0.001` or `0.0025` line at
all, and a scraper reading `+Inf` and `_count` still gets the totals,
so the exposition stays honest about what was observed rather than
loud about what was not.

== the ops port

Where the exposition serves from is a placement decision the contract
forces. The metrics route is unauthenticated by convention, a scraper
carries no bearer token, and chapter 23's guard denies by default,
every registered route needs a policy row. So the exposition belongs
on a listener the guard never wraps: `jdk.httpserver` has no second
mux on one server, the answer is a second server, bound to
`JBAPI_METRICS_PORT` beside the api port, serving one exact path:

#listing("java/api/src/javabook/obs/OpsServer.java", first: 28, last: 46, caption: [the ops listener: one path, the exposition's content type, prefix matches refused])

The context matches by prefix, `/metrics/anything` would match
`/metrics`, and the handler refuses that on purpose, one exact path
is the whole surface. The exactness check reads the raw path, because
the decoded one would accept `/met%72ics` as the same path it spells,
and the contract is bytes here, not spellings. The content type is
the format's own `text/plain; version=0.0.4; charset=utf-8`, scrapers
read it before the body. In production the port publishes inside the
deployment only, chapter 30's compose file maps it to host 19390
beside the api's 19380, and nothing about the api listener changes:
same routes, same guard, same envelope, one more process-local
listener answering `docker compose`'s probe questions.

#diagram([two listeners, one process: the api port behind the guard, the ops port beside it], length: 13pt, {
  cdraw.rect((0.6, 4.6), (10.6, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.6, 7.2), [api listener, JBAPI_PORT], size: 6.5pt)
  cdraw.content((5.6, 6.3), [the filter stack, guard inside], size: 6pt)
  cdraw.content((5.6, 5.4), [routes, envelope, request ids], size: 6pt)
  cdraw.rect((12.4, 4.6), (22.4, 7.8), fill: luma(215), radius: 0.02)
  cdraw.content((17.4, 7.2), [ops listener, JBAPI_METRICS_PORT], size: 6.5pt)
  cdraw.content((17.4, 6.3), [one path, /metrics], size: 6pt)
  cdraw.content((17.4, 5.4), [the same registry, scraped], size: 6pt)
  cdraw.content((5.6, 3.7), [clients, tokens, 401 and 403 answers], size: 6pt)
  cdraw.content((17.4, 3.7), [the scraper, no token, no guard], size: 6pt)
  cdraw.content((11.5, 2.4), [one Metrics object feeds both: the filter ticks it, the ops port renders it], size: 6pt)
})

== the filter at the edge

The layer seats outermost in the wiring, before the request id filter,
so its numbers cover the whole stack and its counter ticks at the
status that really went out. The route label comes from the app's own
pattern resolution, the same `resolvePattern` call the authn and authz
layers make, and the observation lands in a `finally`:

#listing("java/api/src/javabook/obs/Metrics.java", first: 136, last: 152, caption: [the tick: pattern asked of the app, status read off the exchange, finally so nothing escapes])

Reading the status off the exchange is the quiet gift of this server
api: chapter 20's access log already relied on it, go had to wrap the
writer to learn the same fact. A request the limiter refused ticks a
429 row, a path nobody routed ticks `unmatched` with a 404, and an
exchange that died before any header went out reads `getResponseCode`
as the documented -1 and records code 0, because a dropped connection
is a fact about the service too. The pattern is stripped to its path
half so the label reads `/healthz`, not `GET /healthz`, one row per
route across methods that share it. The label's one blind spot is
named rather than hidden: `resolvePattern` matches the method too, so
a known path under the wrong method answers 405 and lands under
`unmatched` beside the 404s, the code dimension separates them, and
the honest reading of that row is requests the router did not serve.

== the custom jfr event

Metrics answer aggregates, and the aggregate says the tail moved
without saying which request moved it. The jdk's answer is JFR, the
flight recorder already inside the runtime, and the module's whole
commitment to it is one event class:

#listing("java/api/src/javabook/obs/RequestEvent.java", first: 17, last: 32, caption: [the one custom event: name, category, 2 fields, and the duration every event carries])

The filter allocates one, calls `begin` before the chain and `commit`
after, and with no recording running that is the entire cost, one
small allocation and 2 calls that return immediately. Nothing buffers,
nothing spawns, nothing ships. A recording changes that: started from
outside the process with `jcmd <pid> JFR.start` or at boot with
`-XX:StartFlightRecording`, it begins consuming events, ours beside
the runtime's own, and the measurement is a capture, never a promise:

#listing("java/api/captures/2026-10-05-jfr.txt", first: 8, last: 21, caption: [measured 2026-10-05 on this machine: jcmd started a recording on the running server, one closed loop ran through it, the dump answered])

1204 events for 1204 fires, 28898 bytes in all, every one naming its
route, its status, its duration, and the virtual thread that served
it, the stack trace arriving for free because the event was committed
on that thread. Everything wider, allocation profiles, gc pauses,
safepoint stalls, method sampling, the runtime's own event set
records, which is why the module defines exactly one custom event and
stops: the custom part is the 2 fields the business knows and the
runtime does not.

#callout("note", "why not a flight recording always on", [
  A recording costs throughput even at default settings, and a service that ships with one always on is spending every client's latency on diagnostics nobody is reading. The lane's stance: the event classes compile into the module, the recording starts when a human asks, chapter 29's load runs are the moments worth asking.
])

== p99 done honestly

The percentile definition is nearest rank: sort the samples, take the
value at the rank that is the ceil of p over 100 times n, no
interpolation anywhere. The bucket approximation is the second half of
the honesty, a scraped histogram cannot answer nearest rank, it can
only say which bound the rank lands in:

#listing("java/api/src/javabook/obs/Quantile.java", first: 29, last: 46, caption: [nearest rank: sort a copy, ceil the rank, clamp both ends])

The rank is one arithmetic decision the adversarial round forced
honest. Computing `ceil(p * n / 100.0)` in doubles can sit an ulp
above the integer and ceil too far, measured concretely at p 1.1 over
3000 samples and p 4.4 over 750, both exactly integral ranks that the
double product rounded up, so the rank is computed in exact decimal
arithmetic on the percent value instead:

#listing("java/api/src/javabook/obs/Quantile.java", first: 72, last: 83, caption: [the rank: exact decimal arithmetic, ceiling at scale zero, no double product anywhere])

#listing("java/api/src/javabook/obs/Quantile.java", first: 49, last: 70, caption: [the bucket form: the smallest bound holding the rank, empty when only +Inf sees it])

The boundary tests pin the contrasts that matter. p50 of 1, 1, 2, 3,
5, 8 milliseconds is 2, the third smallest, and p99 of the same 6 is
8, the largest, because a percentile past the data is a bound, not a
measurement. Ninety-nine samples at 0.9 milliseconds plus one at 1.1
gives an exact p99 of 0.9 milliseconds and a bucket p99 of 1, the
bound the rank lands in, and both halves of that sentence are pinned,
the exact one by the vector and the bound one by the cumulative
counts. And a rank that falls past the last finite bound answers
empty rather than inventing the bound's value, because past the ladder
only `+Inf` sees the samples and infinity is not a latency. The load
chapter's reports read the exact form, its scrapes read the bound
form, and the difference between the 2 numbers is the resolution the
histogram traded away, stated in the report instead of hidden in a
footnote.

== one request fully observed

The wiring is 4 lines in the program's table. The metrics object is
built after the app and used before everything else, the ops server
boots after the api's `start` returns, and its close rides a shutdown
hook beside the engine's:

#listing("java/api/src/javabook/Main.java", first: 74, last: 75, caption: [outermost: the first filter used is the outermost at request time])

#listing("java/api/src/javabook/Main.java", first: 105, last: 108, caption: [the ops listener boots beside the api and closes with the process])

One request through the whole surface, read back: the access log
carries its line with the request id, the counter row for its route
and code ticks, its latency fills the histogram's tail cells, its jfr
event sits in the buffer waiting for a recording, and the envelope it
may have been answered with carries the same request id the log line
did. The observed surface is exactly what the wiring wires, pinned by
the tests: the filter test drives a real app and asserts the label and
the counts, the concurrency tests assert the bucket cells agree with
the count under contention and on a fresh route's first simultaneous
observations, the unsent test cuts a connection mid-exchange and
asserts the code 0 row, the ops test scrapes a real port and asserts
the content type and the one path, and the jfr test starts a real
`Recording` in process and reads the events back out of the dump file.

The lane's boundary is stated as plainly: distributed tracing is not
built here. That same go chapter parsed and rendered the W3C
traceparent format from scratch, spans in context and a tree printer,
and the java lane leaves the surface to it because this service has
one hop and no tree to print. The moment a second hop exists, the same
seam takes it, one more filter reading one header and one more field
on the request's jfr event.

sources: the prometheus exposition format documentation, the content
type line, the histogram bucket semantics and the optionality of HELP
lines, at prometheus.io/docs/instrumenting/exposition_formats,
accessed 2026-10-05. The jdk.jfr javadoc for Event, Name, Label,
Category, and Recording, and the jcmd and jfr tool pages, at
docs.oracle.com/en/java/javase/27, same access date, read against
tools/jdk27/build/jdk-27 build 27+35-2325. Verified live 2026-10-05 by
the javabook.obs tests, 17 green three consecutive runs under the
vendored junit 6.1.3 lane: the frozen 17-line exposition vector, the
bucket cells agreeing with the count under 8-thread contention at 8000
observations and on a fresh route's first 8 simultaneous observations,
the exact-decimal rank against the vectors where a double product
ceils wrong, the filter over a real app including the unmatched 404
and the cut connection's code 0, the ops port over a real socket
including the refused prefix, and the recording round trip. The jfr
capture is books/java/api/captures/2026-10-05-jfr.txt, dated,
committed.
