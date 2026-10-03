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
whose only story is a console log of prose is seen by whoever happens
to be reading along live. This chapter builds the service's
observability in `api/src/obs`: the metrics registry with the counter
and latency histogram the contract pins, the prometheus text
exposition rendered by hand and frozen byte for byte by a vector, the
recording layer that ticks both series at the status the writer really
wrote, the internal listener the exposition lives on, and the
inspector protocol, the platform's own profiling oracle, proven
reachable from inside the process.

== what a service owes its operators

Two numbers answer the first question every incident asks, is it up
and is it slow: how many requests, at what statuses, and how long did
they take. Both are series, not events, and both are registry types
here rather than library types. The counter is one series per route
and status code, `goapi_requests_total{route,code}`, incremented once
per request. The histogram is one per route,
`goapi_request_duration_seconds`, with the contract's bucket ladder
tight at the low end where service latencies live and geometric
through the tail: one, two and a half, five, ten, twenty five, fifty
milliseconds, then the hundreds, seconds, and `+Inf` implicit last.
The series names are frozen because the compose checks and the lane
parity tests grep for them:

#listing("javascript/api/src/obs/metrics.mjs", first: 7, last: 20, caption: [the contract's bounds and series names, one constant block])

#diagram([the questions the two series answer], length: 13pt, {
  cdraw.content((6.0, 8.0), [the counter], size: 6.5pt)
  cdraw.rect((0.4, 5.0), (11.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 6.6), [#"goapi_requests_total{route,code}"], size: 6pt)
  cdraw.content((6.0, 5.7), [how many, at which status, per route], size: 6pt)
  pane(0.4, 11.6, 4.6, [answers], [is it up], [is one route failing])
  cdraw.content((17.6, 8.0), [the histogram], size: 6.5pt)
  cdraw.rect((12.0, 3.6), (23.2, 7.4), fill: luma(228), radius: 0.02)
  cdraw.content((17.6, 6.7), [#"goapi_request_duration_seconds"], size: 6pt)
  cdraw.content((17.6, 5.8), [buckets, sum, count, per route], size: 6pt)
  cdraw.content((17.6, 4.9), [the load chapter reads p99 out of it], size: 6pt)
  pane(12.0, 23.2, 3.2, [answers], [is it slow], [since when, which quantile])
  cdraw.content((11.8, 1.6), [both live in one registry the single thread owns, no lock anywhere], size: 6pt)
})

== the metrics registry

The registry is two maps. The counter map is keyed by the route and
code pair, so incrementing is one `Map.set` of the prior value plus
one. The histogram map holds one entry per route: an array of
cumulative counts one longer than the bounds, the extra slot for
`+Inf`, plus the running sum and count. Recording one observation
increments every bound the value fits under, and that is the whole
trick of cumulative buckets: each bucket counts everything at or under
its bound, so a scraper can subtract neighbors to recover any window,
and the counts only ever grow.

One observation of three milliseconds fills `0.005` and every bound
above it, touches nothing below, and adds to the sum and the count.
The registry never stores individual samples, that is the resolution
the format trades for constant memory, and the load chapter is the one
that pays for the trade when it wants p99:

#listing("javascript/api/src/obs/metrics.mjs", first: 53, last: 68, caption: [observe: cumulative buckets, sum, count, one entry per route])

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

== the prometheus text format

The exposition format is text, line oriented, small enough to render
by hand, which is what this module does. Families come out counter
first then histogram, matching the frozen vector, series sorted by
label tuple within a family, bucket lines ascending with `+Inf` last.
Zero buckets are elided, the one deliberate divergence from the
reference client libraries, which print every finite bucket at zero as
well: one slow observation renders eight lines, not twenty. Numbers
render shortest round trip without exponents, and the one repair that
needs code is the tiny tail, where `String` switches to exponent
notation a fixed-point pass undoes, so a microsecond sum never appears
as `1.5e-7`:

#listing("javascript/api/src/obs/metrics.mjs", first: 92, last: 103, caption: [the counter family: sorted label tuples, one line per series])

The frozen vector pins the whole rendering. One `/healthz` observation
slower than the largest finite bucket elides every finite bucket line,
leaving `+Inf`, the sum marked as observed in the file, and the count,
and the test replays the file byte for byte with the observed value
substituted:

#listing("javascript/api/contract/testdata/15-metrics.txt", first: 1, last: 8, caption: [the frozen exposition the render is checked against, byte for byte])

#diagram([a scrape: registry state to exposition bytes], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.2), (x0 + 5.2, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 5.8), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 4.8), [#l1], size: 6pt)
  }
  stage(0.3, [two maps], [counter keys, histograms])
  cdraw.line((5.7, 5.3), (6.1, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [sort], [route then code, buckets up])
  cdraw.line((11.5, 5.3), (11.9, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [render], [help, type, series lines])
  cdraw.line((17.3, 5.3), (17.7, 5.3), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [the vector], [8 frozen lines, byte equal])
  pane(0.3, 11.4, 3.2, [zero buckets], [elided on purpose], [8 lines, not 20])
  pane(12.0, 23.2, 3.2, [the format], [text/plain 0.0.4], [help, type, then series])
  cdraw.content((11.5, 2.9), [drift means the code is wrong, never the file], size: 6pt)
})

== recording every request

The layer that feeds the registry is the outermost wrapper, so every
response including the kernel backstop's lands in both series. Two
node facts carry the whole design. First, durations come from
`process.hrtime.bigint()`, the monotonic clock that never moves for
wall-clock adjustments and reads in nanoseconds, one subtraction, one
division. Second, the status is read on the response's `finish` event,
which the http module emits when the last segment of headers and body
has been handed to the operating system, and that is the one hook that
runs after every writer: when a handler under this layer throws, the
backstop writes the error after this layer has already yielded, and a
status captured at yield time would record 200 for a request that
answered 401.

The consequence for a request that never finishes is honest by
omission: no response, no tick, and the counter never counts a request
the client never received. The route label is the pattern the router
matched, stamped on the context at dispatch, so `/api/users/42` and
`/api/users/43` share one `/api/users/:id` series instead of shredding
the label space into one series per id. The layer keeps a raw-pathname
fallback for contexts that reach it without a router, and the test
asserts both facts, the stamped pattern present and the raw path
absent:

#listing("javascript/api/src/obs/layer.mjs", first: 9, last: 25, caption: [the recording layer: monotonic start, the finish hook, both series ticked])

#diagram([where the finish hook sits: after every writer, including the backstop], length: 13pt, {
  cdraw.rect((0.6, 5.4), (23.0, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 6.1), [metrics layer: start the monotonic clock, register the hook], size: 6pt)
  cdraw.line((11.8, 5.3), (11.8, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.6, 3.2), (23.0, 4.6), fill: luma(218), radius: 0.02)
  cdraw.content((11.8, 3.9), [the rest of the stack, a handler may throw here], size: 6pt)
  cdraw.line((11.8, 3.1), (11.8, 2.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.6, 1.2), (23.0, 2.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.8, 1.8), [kernel backstop: the one failure writer], size: 6pt)
  cdraw.line((21.0, 1.8), (22.6, 1.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((22.6, 1.8), (22.6, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((23.8, 4.2), [finish], size: 6pt)
  cdraw.content((23.8, 3.4), [ticks], size: 6pt)
  pane(0.6, 10.4, 0.6, [at finish], [statusCode is final], [counter and histogram])
  cdraw.content((11.5, -0.2), [a thrown failure still records at its real status, the test pins 401 not 200], size: 6pt)
})

== the internal listener and the inspector

The endpoint binds on its own listener, not the public one, and the
placement is the policy. The contract says `GET /metrics` carries no
auth, and an unauthenticated route belongs on the socket the authz
layers never wrap, reachable only from inside the deployment, with the
prometheus content type carrying the format version. Everything else
on that listener answers 404, because a private port that answers
unknown routes is a public port that got lucky:

#listing("javascript/api/src/obs/internal.mjs", first: 11, last: 21, caption: [the internal listener: one route, one content type, 404 for the rest])

The listener is the production mode, and the contract names a second:
served on the main mux in tests, where one process answers everything.
The wiring returns both, the listener and a kernel route handler
rendering the same registry through the same content type, so the
composition registers the route on its mux and the deployment binds
the listener on its private port in production:

#snippet("const { metrics, layer, internal, route } = wireObs()\napp.route(\"GET\", \"/metrics\", route)", lang: "javascript")

The go lane mounts pprof handlers next to the metrics route and reads
its profiles over http. Node's profiling oracle is not a route: the
inspector protocol, the same chrome devtools protocol a debugger
speaks, served on its own wire, and reachable in-process through
`node:inspector/promises` with no flag at all. One session, three
posts, a cpu profile of the very process running the api, which is
the committed proof the surface exists where the chapter says it does.
An inspector endpoint is an oracle, it reads where the work happens,
so it stays inside the deployment exactly like the exposition:

#listing("javascript/api/src/obs/inspector.mjs", first: 9, last: 20, caption: [one session over the inspector protocol, a cpu profile of this process])

#diagram([two wires: the public stack and the private surface], length: 13pt, {
  cdraw.rect((0.4, 3.4), (13.6, 8.0), fill: luma(235), radius: 0.05)
  cdraw.content((7.0, 7.5), [public listener], size: 6.5pt)
  cdraw.content((7.0, 6.3), [metrics layer], size: 6pt)
  cdraw.content((7.0, 5.3), [authz, handlers, store], size: 6pt)
  cdraw.content((7.0, 4.2), [every request crosses every layer], size: 6pt)
  cdraw.rect((14.6, 3.4), (23.2, 8.0), fill: luma(218), radius: 0.05)
  cdraw.content((18.9, 7.5), [internal listener], size: 6.5pt)
  cdraw.content((18.9, 6.1), [#"GET /metrics"], size: 6pt)
  cdraw.content((18.9, 5.0), [no authz layers], size: 6pt)
  cdraw.content((18.9, 3.9), [deployment private], size: 6pt)
  cdraw.line((7.0, 3.3), (7.0, 2.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.9, 3.3), (18.9, 2.5), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 13.6, 2.2, [the scrape], [same origin as the api], [or a sidecar])
  pane(14.6, 23.2, 2.2, [the oracle], [inspector protocol], [its own wire, in-process])
  cdraw.content((11.5, 0.4), [an unauthenticated route never rides the public stack], size: 6pt)
})

== one request fully observed

Wire the signals in the order the request meets them and one login
tells the whole story. The metrics layer is the outermost wrapper, so
the clock starts before the request id middleware mints the id, and
the finish hook fires after the backstop or the handler has written.
The id ties the artifacts together: the envelope body carries it, any
access log line will carry it, and the counter's label tuple names the
route it answered. Reading it back is what the tests do, without
ceremony: the layer test drives the real kernel, asserts the 200 and
the thrown 401 land as two labeled series, the registry test replays
the frozen vector, and the internal test scrapes the listener over
real http:

#snippet("const { metrics, layer, internal, route } = wireObs()\nwireMiddleware(app, { outermostLayer: layer })\napp.route(\"GET\", \"/metrics\", route)", lang: "javascript")

#diagram([one request id through every signal], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [clock starts], [outermost layer])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [id minted], [the request context])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [handler runs], [answers or throws])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [finish], [status, duration, route])
  pane(0.3, 11.4, 2.6, [the registry], [two maps grow], [one thread, no lock])
  pane(12.0, 23.2, 2.6, [the scrape], [route and code labels], [read every 15 s])
  cdraw.content((11.7, 1.3), [one id: envelope, log line, series, all one request], size: 6pt)
})

sources: nodejs.org/api/http.html for the response `finish` event and
its handed-off-to-the-operating-system wording plus `statusCode`
semantics, nodejs.org/api/process.html for `process.hrtime.bigint` and
`process.getActiveResourcesInfo`, nodejs.org/api/inspector.html for
the promises session and the `Profiler` domain, all read 2026-09-26 on
node 26.3.0, the prometheus exposition format at
prometheus.io/docs/instrumenting/exposition_formats for the 0.0.4 text
format, help and type lines, histogram buckets, and `+Inf`, with the
client_golang zero-bucket behavior read from its source, accessed
2026-09-26. Verified by `javascript/api` tests, 14 of them under
`test/obs`, green under `npm run verify`, with the exposition replayed
line for line from `contract/testdata/15-metrics.txt`.
