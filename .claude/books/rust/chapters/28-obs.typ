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

The access log answers who did what, one line per exchange with its
request id, and nothing answers how much and how slow. This chapter
builds `rustapi::obs` on nothing outside the crate: the 2 series a
service actually reads, one counter row per route and status and one
latency histogram per route, a bounded ring of request events, the
percentile arithmetic the next chapter's load reports quote, and a
second listener on `RUSTAPI_DEBUG_ADDR` that serves the prometheus
text exposition beside the api port. The go book built the same layer
with client floats and a hand-rolled traceparent, #xref-to("go",
"obs"), the java book over `LongAdder` and `BigDecimal`,
#xref-to("java", "obs"), and this lane builds it over whole
microseconds in `u64`, the same integer discipline the token bucket
chapter kept for its refill, where no float ever decides which bucket
a latency lands in and no float ever rounds a percentile's rank.

== the two series

A counter only ever goes up and a histogram only ever answers which
bucket. `rustapi_requests_total` is one row per route and status code
and `rustapi_request_duration_seconds` is one per route with the sum
and count a scraper needs beside the buckets, both held in one
registry under one mutex:

#listing("rust/api/src/obs.rs", first: 106, last: 126, caption: [one observation: the counter row, the route's histogram, and the bucket walk over integer micros])

Three decisions in that walk earn their sentences. The buckets are
cumulative, an observation fills every bound at or above it, which is
the prometheus shape and what makes the counts monotone in the bound.
The bounds live and compare in whole microseconds, so the 2.5
millisecond bound is the integer 2500 and a 2500 microsecond
observation fills it exactly, the boundary java needed a comparison
rule to state and go needed a float to almost get right. And the
per-route cells are a fixed array inside the map entry, created with
the entry itself, because a lazily created cell is a check-then-act
race under a route's first concurrent observations, the hole java's
adversarial round measured at 7 of 8 first observations counted. Here
one mutex owns the whole registry, so the eager array is enough, and
the contention test pins it: 10 threads, 8000 observations, the count
and the `+Inf` cell both exactly 8000.

The ladder itself is the same policy statement both siblings made,
tight at 1, 2.5, and 5 milliseconds where service latencies live,
geometric through the seconds:

#listing("rust/api/src/obs.rs", first: 30, last: 32, caption: [11 finite bounds in micros, plus Inf implicit as the last cell])

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
  pane(0.4, 10.4, 2.4, [the ladder], [integer micros, u64], [11 finite bounds plus Inf])
  pane(12.4, 23.2, 2.4, [the cells], [a fixed array per route], [created with the entry])
})

== the text exposition

The registry renders the prometheus text format directly, `#` comment
lines carrying the types, series sorted by label tuple, bucket lines
ascending with `+Inf` last, then the sum and the count. The sort is
not a sort: the registry holds `BTreeMap` keyed on the label tuple,
so the iteration order is the sorted order, the ordering go and java
paid for at render time is paid here once at insert. Both families
elide entirely when empty, and zero buckets elide their lines, the
one divergence from the client libraries, which print every finite
bucket at zero as well:

#listing("rust/api/src/obs.rs", first: 136, last: 148, caption: [the counter family: BTreeMap order is the label tuple order, the family absent when nothing was counted])

#listing("rust/api/src/obs.rs", first: 150, last: 176, caption: [the histogram family: zero cells elided, +Inf always present, the sum and count after the buckets])

The seconds render without a float anywhere. The sum is microseconds
in a `u64`, the renderer divides once for the whole part, formats the
remainder as 6 digits, and pops trailing zeros:

#listing("rust/api/src/obs.rs", first: 63, last: 74, caption: [the shortest round trip from u64 micros: 903400 prints 0.9034, 2500000 prints 2.5, 1000000 prints 1])

Go reached the same bytes through `strconv.FormatFloat` and java
through `BigDecimal`, both correct, and this lane reaches them through
integer division, which cannot be anything else. The frozen vector
test drives 3 observations of 3 ms, 0.4 ms, and 900 ms through a bare
registry and pins the exact 16 lines, the 2 type comments and 14
series lines, including the `0.001` bucket the 0.4 ms observation
fills and the `0.9034` sum. The elision has its own test: a registry
whose smallest observation is 3 ms renders no `0.001` or `0.0025`
line at all, and a scraper reading `+Inf` and `_count` still gets the
totals.

== the ops port

Where the exposition serves from is a placement decision the guard
forces. The metrics route is unauthenticated by convention, a scraper
carries no bearer token, and chapter 23's guard denies by default,
every registered route needs a policy row. So the exposition belongs
on a listener the guard never wraps. The kernel's `serve` takes one
router, and the answer is a second `serve`, one route, on
`RUSTAPI_DEBUG_ADDR`, whose default is `127.0.0.1:19590` beside the
api's 19580:

#listing("rust/api/src/obs.rs", first: 287, last: 311, caption: [the ops listener: the kernel's own serve, one route, the exposition's content type])

The second listener reuses the chapter 19 server wholesale, worker
pool, keep-alive, envelope and all, so the exactness questions answer
themselves the router's way: `/metrics/anything` matches no route and
answers the 404 envelope, a `POST /metrics` answers 405 with
`allow: GET`, and the one route that exists serves the format's own
`text/plain; version=0.0.4; charset=utf-8` content type, which
scrapers read before the body. The test scrapes a real port and pins
all three answers.

#diagram([two listeners, one process: the api port behind the guard, the ops port beside it], length: 13pt, {
  cdraw.rect((0.6, 4.6), (10.6, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.6, 7.2), [api listener, 19580], size: 6.5pt)
  cdraw.content((5.6, 6.3), [identify, layers, guard], size: 6pt)
  cdraw.content((5.6, 5.4), [routes, envelope, request ids], size: 6pt)
  cdraw.rect((12.4, 4.6), (22.4, 7.8), fill: luma(215), radius: 0.02)
  cdraw.content((17.4, 7.2), [ops listener, 19590], size: 6.5pt)
  cdraw.content((17.4, 6.3), [one route, GET /metrics], size: 6pt)
  cdraw.content((17.4, 5.4), [the same registry, scraped], size: 6pt)
  cdraw.content((5.6, 3.7), [clients, tokens, 401 and 403 answers], size: 6pt)
  cdraw.content((17.4, 3.7), [the scraper, no token, no guard], size: 6pt)
  cdraw.content((11.5, 2.4), [one Metrics object feeds both: the layer ticks it, the ops port renders it], size: 6pt)
})

== the layer at the edge

The layer seats first in the stack vector, which the chain applies
outermost, so its numbers cover every layer below it and its counter
ticks at the status that really went out. The route label comes from
the app's own pattern table, the same `match_pattern` call the guard
makes, the method prefix stripped so the label reads `/healthz` and
not `GET /healthz`:

#listing("rust/api/src/obs.rs", first: 244, last: 253, caption: [the label: the guard's own matcher, method stripped, one honest unmatched bucket])

#listing("rust/api/src/obs.rs", first: 255, last: 285, caption: [the layer: label, outcome, status read off either arm of the Result, duration from the injected micros clock])

Reading the status off the `Result` is the quiet gift of this
kernel's shape: chapter 19's connection loop owns error rendering, so
a layer sees either a response or the `ApiError` that will become
one, and both arms carry the status. A request the limiter refused
ticks a 429 row, a path nobody routed ticks `unmatched` with a 404,
and a known path under the wrong method answers 405 and lands under
`unmatched` beside the 404s, because the label matcher honors the
method exactly as the guard does, and the code dimension separates
them. The honest reading of that row is requests the router did not
serve. The clock is the same injected seam every layer takes, here in
micros, and the duration clamps at zero so a clock that steps
backwards between the two reads records 0 rather than a `u64`
underflow panic.

== the ring and the exact tail

Metrics answer aggregates, and the aggregate says the tail moved
without saying which request moved it. Go answered with pprof and a
hand-rolled traceparent, java with one custom JFR event the runtime
records, and the rust runtime ships neither. The lane's answer is a
bounded ring of the last 1024 request events, each one route, code,
and micros, readable at any moment without a recording running and
forgetting by overwriting its own oldest slot:

#listing("rust/api/src/obs.rs", first: 209, last: 241, caption: [the ring: overwrite the oldest, read the window in age order, quantile by sorting a copy])

The ring is the exact half of the chapter's percentile story, the
latency window a human asks about at three in the morning, and its
cost is stated plainly: 1024 events of 3 fields, one mutex, no
background thread, no wakeup. The quantile over it sorts a copy and
takes the nearest rank:

#listing("rust/api/src/obs.rs", first: 34, last: 41, caption: [nearest rank: the rank is ceil of permille times n over 1000, in u64 division, clamped at both ends])

The percentile argument is a permille integer, 500, 990, 999, and the
rank is one integer ceiling. This is the boundary both siblings
learned the hard way: java's adversarial round measured a double
product sitting an ulp above an integral rank and ceiling one too far
at 2 vectors, forcing exact decimal arithmetic, and go's round caught
a harness accepting a NaN rate. The rust answer is the type. A `u64`
permille cannot be NaN, the product cannot round, `div_ceil` is
exact, and the boundary test pins the contrasts: p50 of 1, 1, 2, 3,
5, 8 milliseconds is 2, the third smallest, p99 of the same 6 is 8,
the largest, because a percentile past the data is a bound, and 99
samples at 0.9 ms plus one at 1.1 gives an exact p99 of 0.9.

== p99 from buckets

The scrape cannot answer nearest rank. A histogram only says which
bound holds the rank, and the honest answer is the bound itself,
never a value invented inside it:

#listing("rust/api/src/obs.rs", first: 43, last: 61, caption: [the bucket form: the smallest bound holding the rank, None when only +Inf sees it])

The `None` case is the honesty lever. Past the last finite bound only
`+Inf` sees the samples and infinity is not a latency, so the
function answers nothing rather than inventing the top bound's value,
and the caller states it. The 99-at-0.9-plus-one-at-1.1 vector pins
both halves: the exact p99 is 900 micros, the bucket p99 is the 1000
micros bound, and the bound form can never undercut the exact one,
the property the load chapter's report asserts between its 2 rows.

== one request fully observed

The wiring is 5 lines in the program's table. The policy rows are
built once and feed two consumers, the guard and the layer's label
table, the registry and ring are built beside them, the ops server
starts serving before the api does, and the layer is inserted at the
stack's position zero:

#listing("rust/api/src/main.rs", first: 148, last: 163, caption: [the wiring: pattern rows feed the guard and the label table, the ops listener binds beside the api's])

#listing("rust/api/src/main.rs", first: 178, last: 183, caption: [the layer at position zero, outermost in the stack, covering every layer below it])

One request through the whole surface, read back: the access log
carries its line, the counter row for its route and code ticks, its
latency fills the histogram's tail cells, its event sits in the ring,
and a scrape of 19590 renders all of it. The budget capture of
chapter 29 shows the same readback against the real binary, 200
fires offered plus the readiness probe as the 201st, the exposition
counting 30 twos hundreds and 171 fours, one registry observed from
both ports. The module is 311
lines and its test file 315, and the 11 tests land green three
consecutive runs under the full gate, fmt, clippy at `-D warnings`,
the locked offline build, dated 2026-10-14: the sorted counter
exposition, the frozen 16-line histogram vector, the elided zero
buckets, the shortest round trip at 5 vectors, the nearest rank and
bound tables with their clamps, the ring's overwrite and quantile,
the 10-thread contention, the label table, the layer over a real
listener with exact 100 micros durations under a tick clock, and the
ops port's three answers. The crate count after this wave is chapter
31's inventory, and the 135 landed tests stayed green unchanged
through it.

The lane's boundary is stated as plainly: distributed tracing is not
built here. The go chapter owns the W3C traceparent parse and the
span tree, and a rust copy would be the same arithmetic wearing a new
name, while this service still has one hop and no tree to print.

sources: the prometheus exposition format documentation, the content
type line, the histogram bucket semantics and the optionality of HELP
lines, at prometheus.io/docs/instrumenting/exposition_formats,
accessed 2026-10-14. The ladder, the cumulative cells, the elision
divergence, and the unmatched label follow the go book's
observability chapter, book 4 chapter 27 of this corpus, and the
integer bounds, the elided family comment, and the ulp-high rank
lesson follow the java book's chapter 28, read for the parallel
contracts. The div\_ceil rank, the permille type, and the micros
ladder verified live 2026-10-14 by the rustapi obs tests, 11 green
three consecutive runs under `cargo test --locked` with
`CARGO_NET_OFFLINE=true` on the pinned 1.99.0 build, and the crate at
157 tests the same three runs.
