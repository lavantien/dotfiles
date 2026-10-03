#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= observability

A service no one can see is a service no one can fix, and a service
that logs prose no machine can query is seen only by whoever is
reading along live. This chapter builds the service's observability
in `goapi/internal/obs`: the real slog setup with json lines, source
locations, context loggers, and redaction of secret-bearing fields,
the W3C traceparent header parsed and formatted from scratch with
spans held in context and rendered as a tree, the metrics registry
and its prometheus text exposition with the counter and latency
histogram the contract pins, p99 done honestly by nearest rank with
the bucket approximation labeled as the upper bound it is, pprof
mounted on the internal listener, and one login request followed
through every signal at once.

== slog the real setup

The production logger is one constructor, not a pattern study: json
lines to a writer, a level, source locations on demand, and one
`ReplaceAttr` hook that does two jobs. The first job is redaction,
installed once at the top so every line the service ever writes
passes through it, top-level attrs and group members alike: a closed
set of keys, folded to lower case, string values swapped for
`[redacted]`, because a login handler that logs its request body
verbatim logs a password, and grep never forgets. The second job is
the fixed clock: when the option's `Now` is set, the hook replaces
the time attr with it, which is how the golden test pins bytes
without touching the wall, and how a log line can be replayed in a
test the way a response body can:

#listing("go/api/internal/obs/logger.go", first: 42, last: 62, caption: [one constructor: json, level, source, and the hook that redacts and fixes time])

The golden test pins the whole line, and the line earns a sentence of
reading: the time member is the injected clock, the level and msg
come from the call, attrs land in call order, and the password attr
is the masked value, never the secret. With source on, the same
constructor adds a `source` member carrying the file and function of
the log call, which is why the level exists at all: debug lines are
compiled in but silent until the level drops.

#snippet("{\"time\":\"2026-10-01T05:00:00Z\",\"level\":\"INFO\",\"msg\":\"login failed\",\"email\":\"ada@example.org\",\"password\":\"[redacted]\",\"attempts\":3}", lang: "json")

#diagram([the logger's own stack: call site through handler to writer], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(5.9, [handler code], [#"log.Info(.., \"password\", pw)"])
  cdraw.line((5.2, 5.8), (5.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(3.7, [ReplaceAttr], [redact keys, fix time])
  cdraw.line((5.2, 3.6), (5.2, 3.0), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [json handler], [one line, attrs in call order])
  cdraw.line((5.2, 1.4), (5.2, 0.8), stroke: luma(100), mark: (end: ">>"))
  stage(-0.7, [writer], [stdout, or a test buffer])
  pane(11.4, 22.6, 5.9, [redaction rules], [closed key set, lower cased], [string values only])
  pane(11.4, 22.6, 3.2, [the golden lever], [Now set: time is pinned], [Now nil: wall clock])
  cdraw.content((17.0, 0.9), [installed once, applied to every line], size: 6pt)
})

== structured beats interpolated

An interpolated message packs data into prose, and prose is lossy:
`login failed for ada, attempt 3` cannot be grouped by email, counted
by attempt, or joined to its request id without a regex that breaks
the day the message rewords itself. The structured line carries the
same information as fields, and every field keeps its name, its type,
and its place in an index. The service's rule is the one the access
log already follows: messages name the event, attrs carry the data,
and no handler interpolates a value it could pass as an attr.

Handlers never touch a global to do it. The context carries the
configured logger, `FromContext` resolves it with a fallback to
`slog.Default` so a missing logger can never panic a request, and
`RequestLogger` attaches the request id the kernel minted at the
edge, the same value the access log line and any error envelope
carry. One id, one line of grep, every artifact of one request:

#listing("go/api/internal/obs/logger.go", first: 81, last: 95, caption: [the context logger and the request logger that attaches the id])

#diagram([the same failure, line-oriented and structured], length: 13pt, {
  cdraw.content((6.0, 8.0), [interpolated], size: 6.5pt)
  cdraw.rect((0.4, 5.0), (11.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 6.6), [#("login failed for ada@example.org")], size: 6pt)
  cdraw.content((6.0, 5.7), [attempt 3, took 41ms], size: 6pt)
  pane(0.4, 11.6, 4.6, [what a machine sees], [one string], [groupable by nothing])
  cdraw.content((17.6, 8.0), [structured], size: 6.5pt)
  cdraw.rect((12.0, 3.6), (23.2, 7.4), fill: luma(228), radius: 0.02)
  cdraw.content((17.6, 6.7), [msg: login failed], size: 6pt)
  cdraw.content((17.6, 5.8), [email, attempts, duration, request_id], size: 6pt)
  cdraw.content((17.6, 4.9), [password: masked before the writer], size: 6pt)
  pane(12.0, 23.2, 3.2, [what a machine sees], [named, typed fields], [count, group, join])
  cdraw.content((11.8, 1.6), [the prose side exists for humans reading along, never for the query], size: 6pt)
})

== tracing from scratch

A trace is the shape of one request's time: nested spans, each with a
name, an id, a parent, and a start and end, joined across services by
one shared header. The W3C trace context format is deliberately
small, four lowercase hex fields, `version-traceid-spanid-flags`, 2,
32, 16, and 2 digits, and small enough to parse and format by hand,
which is what this package does: no sdk, no collector, no spans leave
the process, the point is to know the format and the tree, because
every vendor's tracing story is this header plus a place to send the
spans.

The parser is strict where the spec allows a choice. Four fields of
the exact lengths, version `ff` reserved and rejected, all-zero trace
or span ids rejected, uppercase hex rejected because lowercase is the
canonical rendering and this parser takes the strict side, and only
the sampled bit of the flags byte kept, the bit the spec says
propagates, everything else masked to zero exactly as the wire writes
it back. On the server side one call continues an inbound trace:
parse, then a root span whose trace id is the inbound trace and whose
parent is the remote span, sampling bit inherited. A header that is
absent or malformed starts a fresh trace and reports false, because
one bad header must never kill a request:

#listing("go/api/internal/obs/trace.go", first: 45, last: 59, caption: [parse: four fields, exact lengths, reserved version and case rejected])

#listing("go/api/internal/obs/trace.go", first: 148, last: 168, caption: [continue an inbound trace, or root a fresh one when the header fails])

#diagram([one login request's spans over time, the tree the render prints], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [t], size: 6pt)
  // root span
  cdraw.rect((2.0, 5.6), (16.0, 6.6), fill: luma(200), radius: 0.02)
  cdraw.content((9.0, 6.1), [POST /api/auth/login], size: 6pt)
  // db child
  cdraw.rect((3.2, 3.9), (10.4, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((6.8, 4.4), [db: user by email], size: 6pt)
  // argon2 child
  cdraw.rect((10.8, 3.9), (14.6, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((12.7, 4.4), [argon2 verify], size: 6pt)
  // session child
  cdraw.rect((14.8, 2.2), (19.2, 3.2), fill: luma(222), radius: 0.02)
  cdraw.content((17.0, 2.7), [session create], size: 6pt)
  cdraw.line((6.8, 3.8), (6.8, 3.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((4.4, 2.7), [jwt sign], size: 6pt)
  cdraw.rect((19.6, 3.9), (22.6, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((21.1, 4.4), [jwt sign], size: 6pt)
  pane(0.4, 11.2, 1.6, [the render], [name, duration, span id], [two spaces per depth])
  cdraw.content((17.0, 1.2), [children inherit the trace id and the sampling bit], size: 6pt)
})

== metrics and the prometheus text format

Two series carry the load story, and both are registry types, not
libraries. The counter is one series per route and status code,
`goapi_requests_total{route,code}`, incremented once per request by
the middleware. The histogram is one per route,
`goapi_request_duration_seconds`, with the contract's bucket ladder
tight at the low end where service latencies live and geometric
through the tail: one, two and a half, five, ten, twenty five, fifty
milliseconds, then the hundreds, seconds, and `+Inf`. Each
observation increments every bucket whose bound it fits under, which
is what makes the counts cumulative, plus the `+Inf` bucket, the sum,
and the count, the four members a scraper needs.

The exposition writer renders the prometheus text format directly,
help and type lines, series sorted by label tuple, bucket lines
ascending with `+Inf` last, and the frozen metrics vector pins it
byte for byte: one slow `/healthz` observation renders exactly the
eight lines the contract froze, because the writer elides zero
buckets, the one deliberate divergence from `client_golang`, which
prints every finite bucket at zero as well. The route label is the
matched pattern minus its method, so the label reads `/healthz`, not
`GET /healthz`, and the middleware asks the mux for the match itself,
the same `mux.Handler` call the authz guard and the preconditions
layers use, because reading `r.Pattern` after the inner handler
returns is a trap: the timeout layer beneath binds its deadline with
`r.WithContext`, which hands the mux a copy of the request, and the
pattern the mux fills in on that copy never travels back out to the
layers above, so the label would read empty on every series over the
real wiring. Each recorded observation then lands in the route's
histogram:

#listing("go/api/internal/obs/metrics.go", first: 66, last: 83, caption: [one observation: cumulative buckets, sum, count])

#listing("go/api/contract/testdata/15-metrics.txt", first: 1, last: 8, caption: [the frozen vector the exposition is checked against, byte for byte])

The endpoint itself binds on the internal listener in production,
next to the pprof surface of the sixth section, and for two reasons:
the contract says the metrics route is unauthenticated, and the authz
guard wraps the public mux deny by default, so a route with no policy
row belongs on the mux the guard never touches.

#diagram([cumulative buckets: each observation fills every bound above it], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  let b = (0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5)
  for (i, bound) in b.enumerate() {
    let x = 1.2 + i * 1.85
    cdraw.line((x, 0.7), (x, 1.3), stroke: luma(150))
    cdraw.content((x, 0.2), [#str(bound)], size: 5pt)
  }
  cdraw.line((22.0, 0.7), (22.0, 1.3), stroke: luma(150))
  cdraw.content((22.0, 0.2), [#("+Inf")], size: 5pt)
  // a 3ms observation fills the .005 and above
  cdraw.content((3.0, 6.9), [observed 3 ms], size: 6pt)
  cdraw.line((3.0, 6.5), (3.0, 5.6), stroke: luma(100), mark: (end: ">>"))
  for i in range(2, 11) {
    cdraw.circle((1.2 + i * 1.85, 5.2), radius: 0.26, fill: luma(160))
  }
  cdraw.circle((22.0, 5.2), radius: 0.26, fill: luma(160))
  cdraw.content((10.5, 5.2), [+1 to every bound at or above 5 ms], size: 6pt)
  cdraw.content((10.5, 4.1), [counts only grow, so bucket c_i includes all smaller], size: 6pt)
  pane(0.4, 10.4, 2.4, [the ladder], [tight low, geometric tail], [11 finite bounds plus Inf])
  pane(12.4, 23.2, 2.4, [the four members], [bucket lines, +Inf, sum, count], [a scraper needs nothing else])
})

== p99 done honestly

The percentile definition is nearest rank: sort the latencies, take
the ceil of `p` over 100 times n as the rank, answer that rank's
value. One generic function over any ordered type is the whole
definition, the same one the profiling chapter pinned and the load
chapter reports from, and its honesty is in the details it refuses to
hide: p99 of one hundred values is the ninety-ninth smallest, not an
interpolation between the ninety-ninth and hundredth, and p99.9 of
ten samples clamps to the largest, because a percentile past the data
is a bound, not a measurement.

The bucket approximation is the second half of honesty. A scraped
histogram cannot answer nearest rank, it can only say which bucket
the rank lands in, so `FromCumulative` answers the smallest bound
whose cumulative count reaches the rank, which is an upper bound on
the true value, never the value itself, and answers not-knowable when
the rank falls into `+Inf`. The test pins the contrast with fixed
vectors: ninety-nine samples at 0.9 milliseconds and one at 1.1 gives
an exact p99 of 0.9 and a bucket p99 of 1.0, the bound. One caveat
carries forward from the profiling chapter: this machine's monotonic
clock steps in roughly half milliseconds, so timing sub-tick work
with `time.Now` mostly returns zero, and the latency numbers worth
quoting are either sums over many iterations or observations bigger
than the tick:

#listing("go/api/internal/obs/quantile.go", first: 15, last: 28, caption: [nearest rank: ceil the rank, clamp the ends, no interpolation anywhere])

#diagram([the tail ladder: where p50, p90, p99, p99.9 sit in one sorted sample], length: 13pt, {
  cdraw.line((1.0, 4.6), (23.0, 4.6), stroke: luma(120))
  cdraw.content((23.2, 4.6), [sorted latencies], size: 6pt)
  for i in range(20) {
    cdraw.line((1.4 + i * 1.08, 4.3), (1.4 + i * 1.08, 4.9), stroke: luma(160))
  }
  let mark(x, label) = {
    cdraw.line((x, 4.6), (x, 6.2), stroke: luma(100))
    cdraw.content((x, 6.8), [#label], size: 6pt)
  }
  mark(11.6, [p50: rank 10 of 20])
  mark(19.1, [p90: rank 18])
  mark(21.0, [p99: clamped 20])
  cdraw.content((11.5, 2.9), [rank = ceil(p/100 x n)], size: 6pt)
  cdraw.content((11.5, 1.8), [p99 of 20 asks for rank 19.8, ceil 20, the largest], size: 6pt)
  pane(0.6, 10.2, 0.6, [buckets answer bounds], [rank lands in a bucket], [the bound is the answer])
  cdraw.content((17.4, -0.3), [interpolated percentiles invent digits the samples never had], size: 6pt)
})

== pprof on the live server

The profiling surface ships with the binary, mounted by one call, and
where it is mounted is the whole security story. The index serves
every named profile, `/debug/pprof/heap`, `goroutine`, `block`,
`mutex`, `threadcreate`, and `allocs`, and the four fixed endpoints
cover the special ones: `profile` takes a cpu sample for the seconds
you ask, `trace` records an execution trace, `symbol` and `cmdline`
serve the tooling. A profile is an oracle: `cmdline` reads the
process arguments, the heap reads object sizes, a cpu profile reads
where the work happens. So the mux it lands on is the internal
listener, the one bound next to the public port and reachable only
from inside the deployment, never the public one, and the wiring is
one goroutine with its own address:

#listing("go/api/internal/obs/pprof.go", first: 7, last: 20, caption: [one call mounts the whole standard surface, listener placement is the policy])

#diagram([which profile answers which question], length: 13pt, {
  let cell(xc, ytop, l1, fill) = {
    cdraw.rect((xc - 3.5, ytop - 1.1), (xc + 3.5, ytop), fill: fill, radius: 0.02)
    cdraw.content((xc, ytop - 0.55), [#l1], size: 6pt)
  }
  cdraw.content((5.4, 8.2), [the question], size: 6.5pt)
  cdraw.content((16.6, 8.2), [the profile], size: 6.5pt)
  cdraw.content((5.4, 7.4), [why is it slow], size: 6pt)
  cdraw.line((9.2, 7.4), (12.4, 7.4), stroke: luma(100), mark: (end: ">>"))
  cell(16.6, 7.8, [profile: cpu seconds by stack], luma(235))
  cdraw.content((5.4, 6.2), [why is memory high], size: 6pt)
  cdraw.line((9.2, 6.2), (12.4, 6.2), stroke: luma(100), mark: (end: ">>"))
  cell(16.6, 6.6, [heap: live by allocation site], luma(235))
  cdraw.content((5.4, 5.0), [where do allocations come from], size: 6pt)
  cdraw.line((9.2, 5.0), (12.4, 5.0), stroke: luma(100), mark: (end: ">>"))
  cell(16.6, 5.4, [allocs: allocs by site], luma(235))
  cdraw.content((5.4, 3.8), [what is blocked on what], size: 6pt)
  cdraw.line((9.2, 3.8), (12.4, 3.8), stroke: luma(100), mark: (end: ">>"))
  cell(16.6, 4.2, [block, mutex: wait by site], luma(235))
  cdraw.content((5.4, 2.6), [what leaked], size: 6pt)
  cdraw.line((9.2, 2.6), (12.4, 2.6), stroke: luma(100), mark: (end: ">>"))
  cell(16.6, 3.0, [goroutine, and the 1.27 goroutineleak], luma(235))
  pane(0.4, 10.8, 1.0, [placement], [internal listener only], [a profile is an oracle])
})

== one request fully observed

Wire the signals in the order the request meets them and one login
tells the whole story. The middleware stack is the previous
chapters' onion with one layer added: the access log already records
method, path, status, bytes, duration, and the request id, and the
metrics middleware wraps the same stack one layer out, so the counter
ticks at the status the writer really wrote and the histogram at the
duration the access log also printed. The span wraps the handler, the
log line and the span agree on start and end because they are the
same request, and the metrics route label agrees with the access
log's path because both read the same matched request. Reading it
back is what the tests do, separately and without ceremony: the
middleware test drives a real mux and asserts the labels and counts
that come out, the logger test asserts the id on the line, the tracer
test pins the rendered tree bytes:

#listing("go/api/internal/obs/metrics.go", first: 167, last: 178, caption: [the metrics layer: pattern asked of the mux, status captured, both series ticked])

#snippet("metrics := obs.NewMetrics()\napp.Use(metrics.Middleware(app.Mux))\ndebugMux := http.NewServeMux()\ndebugMux.HandleFunc(\"GET /metrics\", func(w http.ResponseWriter, r *http.Request) {\n  metrics.WriteExposition(w)\n})\nobs.RegisterDebug(debugMux)\ngo func() {\n  log.Error(\"debug listener exited\", \"err\", http.ListenAndServe(debugAddr, debugMux))\n}()", lang: "go")

#diagram([one request id through every signal], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [id minted], [uuid v7 at the edge])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [span opened], [continues inbound trace])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [handler runs], [log line with the id])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [series tick], [counter, histogram])
  pane(0.3, 11.4, 2.6, [the log line], [request_id attr], [correlates client and server])
  pane(12.0, 23.2, 2.6, [the exposition], [route and code labels], [scraped every 15 s])
  cdraw.content((11.7, 1.3), [grep the id: log line, span tree, envelope, all one request], size: 6pt)
})

sources: pkg.go.dev for log/slog's HandlerOptions, ReplaceAttr, and
Attr kinds, net/http/pprof, and runtime/pprof including the go 1.27
goroutineleak profile, the W3C trace context format at
w3c.github.io/trace-context for the traceparent grammar and the
sampled flag, and the prometheus exposition format documentation with
the client_golang histogram behavior read from its source, all
accessed 2026-09-25. Verified by `go/api/internal/obs` tests, 17 of
them, under `go test -race`, plus gofmt and go vet over the module,
with the metrics exposition replayed line for line from
`contract/testdata/15-metrics.txt`.
