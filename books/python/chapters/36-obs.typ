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
in `pyapi/obs.py`: `logging` with a hand rolled json handler that
redacts a closed key set and takes its clock by injection, the
request context carried in `contextvars`, the W3C traceparent header
parsed and formatted from scratch, the metrics registry and its
prometheus text exposition with the contract's series and buckets,
p99 done honestly by nearest rank, the exposition on its own listener
per the contract, and one request followed through every signal.

== logging the real setup

The production logger is one constructor plus one handler subclass,
not a pattern study: json lines to a stream, a level, and redaction
installed once so every line the service ever writes passes through
it. The handler is a `logging.Handler` whose `emit` writes one line
built by `format_line`: the time from the injected clock rendered as
RFC 3339 UTC, the level lower cased, the message, the request id
when the context carries one, then every `extra` field the call
passed, in call order, with the redact set masked. The extras fall
out of `record.__dict__` by subtraction: every LogRecord carries the
same closed set of standard attributes, 21 measured on the pinned
3.14.7, and whatever remains is exactly what the caller passed, in
the order it was written. A handler that raises goes to
`handleError`, the platform's contract, never into the request:

#listing("python/api/pyapi/obs.py", first: 83, last: 103, caption: [Emit and format_line: one json line, extras by subtraction, redaction on the way out])

#diagram([the handler's own stack: call site through the handler to the stream], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(5.9, [handler code], [#"logger.info(.., extra={..})"])
  cdraw.line((5.2, 5.8), (5.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(3.7, [format_line], [redact, extras, json])
  cdraw.line((5.2, 3.6), (5.2, 3.0), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [JsonHandler.emit], [one line per record])
  cdraw.line((5.2, 1.4), (5.2, 0.8), stroke: luma(100), mark: (end: ">>"))
  stage(-0.7, [the stream], [stdout, or a test buffer])
  pane(11.4, 22.6, 5.9, [redaction rules], [closed key set, lower cased], [string values only])
  pane(11.4, 22.6, 3.2, [the golden lever], [now injected: time pinned], [now default: wall clock])
  cdraw.content((17.0, 0.9), [installed once, applied to every line], size: 6pt)
})

== structured beats interpolated

An interpolated message packs data into prose, and prose is lossy:
`login failed for ada, attempt 3` cannot be grouped by email, counted
by attempt, or joined to its request id without a regex that breaks
the day the message rewords itself. The structured line carries the
same information as fields, and every field keeps its name, its
type, and its place in an index. The service's rule: messages name
the event, `extra` carries the data, and no handler interpolates a
value it could pass as a field.

The golden test pins the whole line: the time member is the
injected clock, the level and msg come from the call, the fields
land in call order, and the password field is the masked value,
never the secret. With the clock injected, a log line replays in a
test the way a response body can, which is why the handler takes
`now` at construction:

#listing("python/api/tests/test_obs.py", first: 28, last: 44, caption: [the golden line pinned byte for byte, password masked, time from the injected clock])

#diagram([the same failure, line oriented and structured], length: 13pt, {
  cdraw.content((6.0, 8.0), [interpolated], size: 6.5pt)
  cdraw.rect((0.4, 5.0), (11.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 6.6), [#("login failed for ada@example.org")], size: 6pt)
  cdraw.content((6.0, 5.7), [attempt 3, took 41ms], size: 6pt)
  pane(0.4, 11.6, 4.6, [what a machine sees], [one string], [groupable by nothing])
  cdraw.content((17.6, 8.0), [structured], size: 6.5pt)
  cdraw.rect((12.0, 3.6), (23.2, 7.4), fill: luma(228), radius: 0.02)
  cdraw.content((17.6, 6.7), [msg: login failed], size: 6pt)
  cdraw.content((17.6, 5.8), [email, attempts, duration, request_id], size: 6pt)
  cdraw.content((17.6, 4.9), [password: masked before the stream], size: 6pt)
  pane(12.0, 23.2, 3.2, [what a machine sees], [named, typed fields], [count, group, join])
})

== the request context in contextvars

Every signal of one request needs to agree on whose request it was,
and the carrier is `contextvars`. The module's page states the
thread behavior in one sentence: "Since each thread has its own
context stack, `ContextVar` objects behave in a similar fashion to
`threading.local()` when values are assigned in different threads."
Measured on the pinned interpreter, a thread started after the
spawner set a value reads the variable's default, which is exactly
what ThreadingHTTPServer wants: each request arrives on its own
thread that begins clean, the middleware sets the id and the trace
at request start, and isolation is free.

One value has one carrier, and the request id is the kernel's, so
this module reads it through the kernel's getter and never mints a
second variable for the same fact. The trace context is
observability's own, set by the span layer and read by anything that
wants the current trace:

#listing("python/api/pyapi/obs.py", first: 44, last: 63, caption: [the carrier: the kernel's request id read, never duplicated, and the trace var beside it])

#diagram([one variable per request thread, the fresh thread starts clean], length: 13pt, {
  cdraw.rect((0.6, 5.0), (7.4, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 7.1), [accept thread], size: 6pt)
  cdraw.content((4.0, 6.1), [sets id, sets trace], size: 6pt)
  cdraw.content((4.0, 5.2), [context stack A], size: 6pt)
  cdraw.line((7.6, 6.3), (11.0, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((11.2, 7.0), (18.0, 8.2), fill: luma(228), radius: 0.02)
  cdraw.content((14.6, 7.6), [request thread 1], size: 6pt)
  cdraw.content((14.6, 5.9), [clean stack, own values], size: 6pt)
  cdraw.rect((11.2, 4.2), (18.0, 5.4), fill: luma(228), radius: 0.02)
  cdraw.content((14.6, 4.8), [request thread 2], size: 6pt)
  pane(18.6, 23.2, 7.8, [what the docs promise], [per-thread context stacks], [threading.local-like behavior])
})

== tracing from scratch

A trace is the shape of one request's time: nested spans, each with
a name, an id, a parent, and a start and end, joined across services
by one shared header. The W3C trace context format is deliberately
small, four lowercase hex fields, `version-traceid-spanid-flags`, 2,
32, 16, and 2 digits, and small enough to parse and format by hand,
which is what this module does: no sdk, no collector, no span leaves
the process, the point is to know the format and the tree.

The parser is strict where the spec allows a choice. Four fields of
the exact lengths, version `ff` reserved and rejected, all-zero
trace or span ids rejected, uppercase hex rejected because lowercase
is the canonical rendering, and only the sampled bit of the flags
byte kept, the bit the spec says propagates, everything else masked
away exactly as the wire writes it back. On the server side one call
continues an inbound trace: parse, then a context whose trace id is
the inbound trace and whose span is a fresh id, sampling inherited.
A header that is absent or malformed answes None, and the caller
roots fresh, because one bad header must never kill a request:

#listing("python/api/pyapi/obs.py", first: 136, last: 154, caption: [parse: four fields, exact lengths, reserved version and case rejected])

#diagram([one login request's spans over time, the tree the recorder prints], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [t], size: 6pt)
  // root span
  cdraw.rect((2.0, 5.6), (16.0, 6.6), fill: luma(200), radius: 0.02)
  cdraw.content((9.0, 6.1), [POST /api/auth/login], size: 6pt)
  // db child
  cdraw.rect((3.2, 3.9), (10.4, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((6.8, 4.4), [db: user by email], size: 6pt)
  // pbkdf2 child
  cdraw.rect((10.8, 3.9), (14.6, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((12.7, 4.4), [pbkdf2 verify], size: 6pt)
  // session child
  cdraw.rect((14.8, 2.2), (19.2, 3.2), fill: luma(222), radius: 0.02)
  cdraw.content((17.0, 2.7), [session create], size: 6pt)
  cdraw.rect((19.6, 3.9), (22.6, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((21.1, 4.4), [jwt sign], size: 6pt)
})

== metrics and the prometheus text format

Two series carry the load story, and both are registry types, not
libraries. The counter is one series per route and status code,
`goapi_requests_total{route,code}`, incremented once per request by
the recording layer. The histogram is one per route,
`goapi_request_duration_seconds`, with the contract's bucket ladder
tight at the low end where service latencies live and geometric
through the tail: one, two and a half, five, ten, twenty five, fifty
milliseconds, then the hundreds, seconds, and `+Inf`. Each
observation increments every bucket whose bound it fits under, which
is what makes the counts cumulative, plus the sum and the count. The
exposition rules are the format's own: a histogram must carry a
`+Inf` bucket whose value equals the count, and label values escape
backslash, quote, and newline.

The renderer writes the prometheus text directly, help and type
lines, counter family first then histogram, series sorted by label
tuple, bucket lines ascending with `+Inf` last. Zero buckets are
elided, the one deliberate divergence from client_golang, which
prints every finite bucket at zero as well, and the frozen metrics
vector pins the consequence byte for byte: one deliberately slow
healthz observation, past every finite bound, renders exactly the
eight lines the contract froze. `render()` is the one writer of
exposition bytes, and every listener that serves them delegates
here. The endpoint itself binds on its own listener in production,
`ThreadingHTTPServer` on the internal address with the socket bound
before the factory returns, and the same bytes serve on the main mux
in tests through the wiring's route member:

#listing("python/api/contract/testdata/15-metrics.txt", first: 1, last: 8, caption: [the frozen vector the exposition is checked against, byte for byte])

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
  pane(0.4, 10.4, 2.4, [the ladder], [tight low, geometric tail], [11 finite bounds plus Inf])
  pane(12.4, 23.2, 2.4, [the four members], [bucket lines, +Inf, sum, count], [a scraper needs nothing else])
})

== p99 done honestly

The percentile definition is nearest rank: sort the latencies, take
the ceil of `p` over 100 times n as the rank, answer that rank's
value. One function over the sorted list is the whole definition,
the same one the profiling chapter pinned and the load chapter
reports from, and its honesty is in what it refuses to hide:
p99 of one hundred values is the ninety-ninth smallest, not an
interpolation between the ninety-ninth and hundredth, and p99.9 of
ten samples clamps to the largest, because a percentile past the
data is a bound, not a measurement.

The bucket approximation is the second half of honesty. A scraped
histogram cannot answer nearest rank, it can only say which bucket
the rank lands in, so `from_cumulative` answers the smallest bound
whose cumulative count reaches the rank, an upper bound on the true
value, never the value itself, and not knowable when the rank falls
into `+Inf`. The test pins the contrast: ninety-nine samples at 0.9
milliseconds and one at 1.1 give an exact p99 of 0.9 milliseconds
and a bucket p99 of 1, the bound, and a rank past 2.5 seconds
renders as a dash in the load chapter's table:

#listing("python/api/pyapi/obs.py", first: 338, last: 348, caption: [nearest rank: ceil the rank, clamp the ends, no interpolation anywhere])

#diagram([the tail ladder: where p50, p90, p99 sit in one sorted sample], length: 13pt, {
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
  pane(0.6, 10.2, 0.6, [buckets answer bounds], [rank lands in a bucket], [the bound is the answer])
})

== one request, every signal

Wire the signals in the order the request meets them and one login
tells the whole story. The recording layer is mounted outermost, so
every response including the kernel backstop's lands in both series,
and it never sniffs a socket for the status: the kernel hands
middleware a `Response` value, so the layer reads the status
straight off it and the latency is the injected clock's arithmetic
around the inner handler. The span layer continues the inbound
traceparent or roots fresh, holds the trace in the contextvar, and
records one root span whose start and end come from the same clock.
The route label comes from the app's own table, the matched pattern
rather than the raw path, so param routes share one series and an
unmatched request lands in one bounded `unmatched` series instead of
the path's unbounded cardinality.

Reading it back is what the tests do, separately and without
ceremony: the golden line test asserts the id on the log line, the
traceparent tests pin the grammar's strict side, the exposition test
replays the frozen vector, and the listener test serves the
exposition over a loopback socket and asserts the body equals
`render()`. Grep the id and every artifact answers:

#listing("python/api/pyapi/obs.py", first: 426, last: 444, caption: [the recording layer: status off the Response value, both series ticked, the clock injected])

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
  pane(0.3, 11.4, 2.6, [the log line], [request_id field], [correlates client and server])
  pane(12.0, 23.2, 2.6, [the exposition], [route and code labels], [scraped every 15 s])
})

sources: docs.python.org, the 3.14 logging page for the Handler
contract and the LogRecord attribute table, and the 3.14 contextvars
page for the per-thread context stack and the threading.local
comparison, both accessed 2026-09-27, the W3C trace context format
at w3c.github.io/trace-context for the traceparent grammar and the
sampled flag, and the prometheus exposition format documentation for
the histogram members, the mandatory +Inf bucket, and the escaping
rules, both accessed 2026-09-27. Verified by
`python/api/tests/test_obs.py`, 21 tests under unittest discover on
the pinned cpython 3.14.7, with the exposition replayed line for
line from `python/api/contract/testdata/15-metrics.txt` and the
LogRecord attribute set measured on the interpreter itself.
