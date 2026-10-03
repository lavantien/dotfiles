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
in `CsharpBook.Api.Observability`: the real ILogger setup with json
lines, source contexts, scopes, and redaction, the W3C traceparent
header parsed and rendered by hand and carried by the platform's
ActivitySource spans, the metrics hub over System.Diagnostics.Meters
with its prometheus exposition pinned byte for byte by the frozen
vector, p99 done honestly, the diagnostics surface, and one request
through every signal at once.

== ILogger the real setup

The production logger is one factory, not a pattern study: json lines
to the console, a level, scopes included, utc timestamps, and every
category wrapped once at the hub by the redaction decorator of the
next section, so no handler can log around it. The category is the
source context, free: a logger created for a type answers that type's
full name, which is why one line can be filtered by the layer that
wrote it, and the level is why debug lines are compiled in but silent
until the level drops:

#listing("csharp-net/api/src/CsharpBook.Api/Observability/LogSetup.cs", first: 16, last: 30, caption: [one factory: json console, utc timestamps, scopes, and a level])

The golden test pins the line through the real pipeline, the json
console provider writing to a captured console, and reads it back as
json: Category is the source context, Message the formatted text,
State the structured members by name. One platform difference from
the go lane is stated rather than hidden: the go logger's hook could
pin the timestamp for the test, this formatter's clock is the wall,
so the timestamp is asserted by shape and every other member by
value:

#snippet("{\"Timestamp\":\"2026-09-26T02:41:07.1098765Z\",\"LogLevel\":\"Information\",\"Category\":\"CsharpBook.Api.Authn.LoginHandler\",\"Message\":\"login failed for ada@example.org with [redacted] on attempt 3\",\"State\":{\"Email\":\"ada@example.org\",\"Password\":\"[redacted]\",\"Attempts\":3,\"{OriginalMessage}\":\"login failed for ada@example.org with [redacted] on attempt 3\"}}", lang: "json")

#diagram([the logger's own stack: call site through provider to console], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(5.9, [handler code], [#"LogInformation(\"{Password}\", pw)"])
  cdraw.line((5.2, 5.8), (5.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(3.7, [redaction decorator], [mask the state, mask the message])
  cdraw.line((5.2, 3.6), (5.2, 3.0), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [json console], [one line, members by name])
  cdraw.line((5.2, 1.4), (5.2, 0.8), stroke: luma(100), mark: (end: ">>"))
  stage(-0.7, [console], [stdout, captured in tests])
  pane(11.4, 22.6, 5.9, [the category], [the type name, filterable], [scopes on: the id rides every line])
  cdraw.content((17.0, 0.9), [wrapped once at the hub, never at call sites], size: 6pt)
})

== structured beats interpolated

An interpolated message packs data into prose, and prose is lossy:
`login failed for ada, attempt 3` cannot be grouped by email, counted
by attempt, or joined to its request id without a regex that breaks
the day the message rewords itself. The structured line carries the
same information as named members, and every member keeps its name,
its type, and its place in an index. The service's rule is the one
the access log follows: messages name the event, members carry the
data, and no handler interpolates what it could pass as a member.

Redaction is where structure pays for itself. A closed set of keys,
password, authorization, cookie, set-cookie, secret, token, is
checked case blindly against every member, and a string value under
one of them is swapped for [redacted] in the rebuilt state and
replaced in the formatted message, so neither State nor Message can
carry the secret. Non string values pass through, because the mask
is for values a grep can find:

#listing("csharp-net/api/src/CsharpBook.Api/Observability/RedactingLogger.cs", first: 43, last: 66, caption: [the mask loop: state rebuilt with [redacted], the message replaced member by member])

The scope middleware is the second half of the rule. One scope per
request carries the request id the edge resolved in chapter 23, so
every structured line any handler writes inside the request names
the same id the access log and any error envelope quote. One id, one
line of grep, every artifact of one request.

#diagram([the same failure, line-oriented and structured], length: 13pt, {
  cdraw.content((6.0, 8.0), [interpolated], size: 6.5pt)
  cdraw.rect((0.4, 5.0), (11.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 6.6), [#("login failed for ada@example.org")], size: 6pt)
  cdraw.content((6.0, 5.8), [attempt 3, took 41ms], size: 6pt)
  pane(0.4, 11.6, 4.6, [what a machine sees], [one string, groupable by nothing])
  cdraw.content((17.6, 8.0), [structured], size: 6.5pt)
  cdraw.rect((12.0, 3.6), (23.2, 7.4), fill: luma(228), radius: 0.02)
  cdraw.content((17.6, 6.7), [Message: login failed], size: 6pt)
  cdraw.content((17.6, 5.8), [Email, Attempts, DurationMs], size: 6pt)
  cdraw.content((17.6, 4.9), [Password: masked before the provider], size: 6pt)
  pane(12.0, 23.2, 3.2, [what a machine sees], [named, typed members], [count, group, join])
  cdraw.content((11.8, 1.6), [the prose side exists for humans reading along, never for the query], size: 6pt)
})

== tracing from scratch

A trace is the shape of one request's time: nested spans, each with a
name, an id, a parent, and a start and end, joined across services by
one shared header. The W3C trace context format is deliberately
small, four lowercase hex fields, version-traceid-spanid-flags, of 2,
32, 16, and 2 digits, small enough to parse and render by hand, which
is what this package does, no sdk and no spans leaving the process.
The parser is strict where the spec allows a choice: exact
field lengths, version ff reserved and rejected, all-zero ids
rejected, uppercase hex rejected because lowercase is canonical, and
only the sampled bit of the flags kept, everything else masked to
zero exactly as the wire writes it back. The parsed ids are the
platform's own ActivityTraceId and ActivitySpanId, the same values
the spans below put on the wire, so a parsed header feeds the span
without a copy:

#listing("csharp-net/api/src/CsharpBook.Api/Observability/Traceparent.cs", first: 28, last: 50, caption: [TryParse: four fields, exact lengths, lowercase hex only])

The spans themselves run on ActivitySource, the platform's tracing
api, whose native id format is this same W3C format. One middleware
opens a server span per request: an inbound header that parses
becomes the span's trace id and remote parent with the sampling bit
carried, a header absent or malformed starts a fresh trace, because
one bad header must never kill a request, and with no listener
attached StartActivity answers null and the request is untraced. The
collector is the in-process listener: it samples every activity of
the service's source and renders the tree, one line per span,
children indented two spaces, the same role a collector process
plays in production minus the network.

#diagram([one login request's spans over time, the tree the collector prints], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [t], size: 6pt)
  cdraw.rect((2.0, 5.6), (16.0, 6.6), fill: luma(200), radius: 0.02)
  cdraw.content((9.0, 6.1), [HTTP POST /api/auth/login], size: 6pt)
  cdraw.rect((3.2, 3.9), (10.4, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((6.8, 4.4), [db: user by email], size: 6pt)
  cdraw.rect((10.8, 3.9), (14.6, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((12.7, 4.4), [pbkdf2 verify], size: 6pt)
  cdraw.rect((14.8, 2.2), (22.6, 3.2), fill: luma(222), radius: 0.02)
  cdraw.content((18.7, 2.7), [session create, jwt sign], size: 6pt)
  pane(0.4, 11.2, 1.6, [the render], [name, duration, span id], [two spaces per depth])
  cdraw.content((17.0, 1.2), [children inherit the trace id and the sampling bit], size: 6pt)
})

== metrics and the prometheus text format

Two series carry the load story, and both are System.Diagnostics.Metrics
instruments, the platform surface dotnet-counters also reads over
EventPipe. The counter is one series per route and status code,
`goapi_requests_total{route,code}`, incremented once per request. The
histogram is one per route, `goapi_request_duration_seconds`, with
the contract's ladder tight at the low end and geometric through the
tail: one, two and a half, five, ten, twenty five, fifty
milliseconds, then the hundreds, seconds, and +Inf. The ladder also
rides the instrument as histogram advice, the hint external
collectors read, while the in-process collector is a MeterListener
that buckets every observation itself.

The exposition writer renders the prometheus text format directly
from what the listener collected: help and type lines, series sorted
by label tuple, bucket lines ascending with +Inf last, zero buckets
elided, the one deliberate divergence from client libraries that
print every finite bucket at zero as well. The route label is the
matched endpoint's route pattern read after the inner pipeline
returns, because endpoint routing resolves the endpoint into the
context as the request passes through, and the pattern carries no
method prefix in this stack, so the label reads /healthz, empty for
an unrouted request. The frozen vector pins every byte, one slow
/healthz observation rendering exactly the eight lines froze:

#listing("csharp-net/api/src/CsharpBook.Api/Observability/MetricsRegistry.cs", first: 167, last: 181, caption: [the exposition: counter family first, series sorted by label tuple])

#listing("csharp-net/api/contract/testdata/15-metrics.txt", first: 1, last: 8, caption: [the frozen vector the exposition is checked against, byte for byte])

#diagram([cumulative buckets: each observation fills every bound above it], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  let b = (0.001, 0.0025, 0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1.0, 2.5)
  for (i, bound) in b.enumerate() {
    let x = 1.2 + i * 1.85
    cdraw.line((x, 0.7), (x, 1.3), stroke: luma(150))
    cdraw.content((x, 0.2), [#str(bound)], size: 5pt)
  }
  cdraw.content((22.2, 0.2), [#("+Inf")], size: 5pt)
  cdraw.content((3.0, 6.9), [observed 3 ms], size: 6pt)
  cdraw.line((3.0, 6.5), (3.0, 5.6), stroke: luma(100), mark: (end: ">>"))
  for i in range(2, 12) {
    cdraw.circle((1.2 + i * 1.85, 5.2), radius: 0.26, fill: luma(160))
  }
  cdraw.content((10.5, 5.2), [+1 to every bound at or above 5 ms], size: 6pt)
  pane(12.4, 23.2, 2.4, [the four members], [buckets, +Inf, sum, count], [a scraper needs nothing else])
})

== p99 done honestly

The percentile definition is nearest rank: sort the latencies, take
the ceil of p over 100 times n as the rank, answer that rank's value.
Its honesty is in the details it refuses to hide: p99 of one hundred
values is the ninety ninth smallest, not an interpolation between it
and the next, and p99.9 of ten samples clamps to the largest, because
a percentile past the data is a bound, not a measurement:

#listing("csharp-net/api/src/CsharpBook.Api/Observability/Quantile.cs", first: 14, last: 29, caption: [nearest rank: ceil the rank, clamp the ends, no interpolation anywhere])

The bucket approximation is the second half of honesty. A scraped
histogram cannot answer nearest rank, it can only say which bucket
the rank lands in, so FromCumulative answers the smallest bound whose
cumulative count reaches the rank, an upper bound on the true value,
never the value itself, and not knowable when the rank falls into
+Inf. The test pins the contrast: ninety nine samples at 0.9
milliseconds and one at 1.1 gives an exact p99 of 0.9 and a bucket
p99 of 1.0, the bound. The load chapter reports both, labeled.

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
  mark(20.0, [p90, p99: 18, clamped 20])
  cdraw.content((11.5, 2.7), [rank = ceil(p/100 x n), buckets answer bounds], size: 6pt)
  cdraw.content((17.4, 1.6), [interpolated percentiles invent digits the samples never had], size: 6pt)
})

== the diagnostics surface

Go mounts pprof on an internal listener and the profiling oracle is
an http route. The .net runtime answers the same questions through a
different door: the diagnostics ipc channel, the one dotnet-counters,
dotnet-trace, and dotnet-dump speak, armed by default in every
process. Which profile answers which question is unchanged, cpu by
stack through dotnet-trace, live objects by type through
dotnet-gcdump, the heap through dotnet-dump, and this service's own
meter instruments stream to dotnet-counters over the same channel
with no code beyond this chapter's instruments. The placement ruling
changes shape, not meaning: a profile is an oracle, so the channel
belongs to the operator, and DOTNET_EnableDiagnostics=0 closes it at
the runtime level before any code runs, the equivalent of never
mounting the profiling route publicly. The metrics exposition is the
one surface this service exposes on purpose, on the internal
listener only, its address on the same config hub:

#listing("csharp-net/api/src/CsharpBook.Api/Observability/DiagnosticsConfig.cs", first: 26, last: 44, caption: [the placement ruling as config: the ipc switch and the metrics bind address])

#diagram([which tool answers which question, all over one ipc channel], length: 13pt, {
  let cell(xc, ytop, l1) = {
    cdraw.rect((xc - 3.5, ytop - 1.1), (xc + 3.5, ytop), fill: luma(235), radius: 0.02)
    cdraw.content((xc, ytop - 0.55), [#l1], size: 6pt)
  }
  cdraw.content((5.4, 8.2), [the question], size: 6.5pt)
  cdraw.content((16.6, 8.2), [the tool], size: 6.5pt)
  cdraw.content((5.4, 7.4), [why is it slow], size: 6pt)
  cdraw.line((9.2, 7.4), (12.4, 7.4), stroke: luma(100), mark: (end: ">>"))
  cell(16.6, 7.8, [dotnet-trace: cpu])
  cdraw.content((5.4, 6.2), [why is memory high], size: 6pt)
  cdraw.line((9.2, 6.2), (12.4, 6.2), stroke: luma(100), mark: (end: ">>"))
  cell(16.6, 6.6, [gcdump, dump: the heap])
  cdraw.content((5.4, 3.8), [what is the load story], size: 6pt)
  cdraw.line((9.2, 3.8), (12.4, 3.8), stroke: luma(100), mark: (end: ">>"))
  cell(16.6, 4.2, [dotnet-counters: the meter instruments])
  pane(0.4, 10.8, 1.0, [placement], [operator only], [#"DOTNET_EnableDiagnostics=0"])
})

== one request fully observed

Wire the signals in the order the request meets them and one request
tells the whole story. The tracing layer wraps the stack outermost of
the family, so the span covers the scope, the handler, and the
metrics tick. The request id scope sits beneath the access log of
chapter 23, so the scope exists before any handler line is written.
The metrics layer wraps routing and ticks in a finally block, so the
counter records the status even when the handler throws. Reading it
back is what the tests do: the trace test asserts the span continued
the inbound header, the scope test asserts the id on the line, and
the one request test chains all three layers over a routed context
and asserts every signal observed the same request. The instruments
the diagnostics tools read are the ones the exposition renders, so
dotnet-counters and the scrape agree because they read one hub:

#listing("csharp-net/api/src/CsharpBook.Api/Observability/WireObservability.cs", first: 10, last: 22, caption: [the family's one registration: the metrics hub, the span and scope layers themselves installed at the stack's chapter order in wire])

#diagram([one request id through every signal], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [id resolved], [chapter 23, at the edge])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [span opened], [continues inbound trace])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [handler, scope, tick], [log carries the id, series tick])
  pane(12.0, 23.2, 2.6, [the exposition], [route and code labels], [scraped every 15 s])
  cdraw.content((11.7, 1.3), [grep the id: log line, span tree, envelope, all one request], size: 6pt)
})

sources: learn.microsoft.com for ILogger and the console log
formatting model with the json formatter and custom formatters,
ActivitySource and ActivityContext with the W3C id format and the
AllDataAndRecorded sampling result, System.Diagnostics.Metrics with
the MeterListener callbacks and histogram advice, and
dotnet-core-diagnostics for the ipc channel and the switch, all
accessed 2026-09-26, plus the W3C trace context format at
w3c.github.io/trace-context and the prometheus exposition format
documentation. Verified by the `CsharpBook.Api.Observability` tests,
35 of them under `dotnet test Api.slnx`, with the metrics exposition
replayed line for line from `contract/testdata/15-metrics.txt`.
