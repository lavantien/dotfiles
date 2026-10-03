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

A service that cannot be watched cannot be operated. When login
traffic triples at 3 in the morning the question is not what the code
does, it is what the code did: which requests arrived, how long each
took, where each one spent its time, and which one broke first. This
chapter builds the service's observability in `c-os-cloud/api/src`: an
access log whose one line per request is anchored on the request id,
the w3c traceparent header parsed and propagated by hand, a metrics
registry that renders the prometheus text exposition byte-pinned by a
frozen vector, and the redaction rule that decides what never gets
written down.

== the access log over the request id

Every signal this service emits quotes one identifier: the request id
the kernel mints when a request arrives. The access log line carries
it, the error envelope in a 429 body carries it, and a support
conversation reduces to "give me the id" because one id names one
request across every surface. The line is fixed-field key=value, the
shape an operator greps and a shell splits: timestamp, level, message,
request id, method, path, status, duration in milliseconds, remote
address. Nothing on the line is computed from a clock the function
reads itself, every field arrives as an argument, so a test renders
the exact line with literals and the chapter's tests do exactly that:

#listing("c-os-cloud/api/src/obs_log.c", first: 93, last: 104, caption: [the access line: fixed fields in fixed order, every member caller-supplied])

#diagram([one request id quoted by every signal the service emits], length: 13pt, {
  cdraw.content((11.5, 8.0), [request arrives], size: 6.5pt)
  cdraw.line((11.5, 7.7), (11.5, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.7, 5.6), (15.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.3), [the kernel mints the request id], size: 6pt)
  cdraw.line((9.0, 5.5), (4.5, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 5.5), (11.5, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.0, 5.5), (18.5, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(1.0, 8.0, 4.4, [access log], [one line, id field], [grep and found])
  pane(8.5, 14.5, 4.4, [error envelope], [#"request_id\": id"], [the 429 body quotes it])
  pane(15.0, 22.0, 4.4, [the span], [trace and parent ids], [the trace story joins])
  cdraw.content((11.5, 1.2), [one id, one request, every surface agrees], size: 6pt)
})

The chapter's tests are not this renderer's only caller, and that is
the point of the shape. The middleware chapter's access layer builds
this record after its stack returns and renders it through this
family's function, so the line an operator greps from a running
service is these bytes and the vehicle holds exactly one assembler.
The lane's composition round caught the gap while it still existed:
the access layer hand-built its own line with a private format call
and this renderer ran only inside the tests, both families green in
isolation, the seam between them untested. The fix is this section's
rule made real, and the crash line follows it too, rendering through
the same family's attribute renderer with level error and the
exception code as a kv pair.

== one writer and fixed fields

A log line in c is assembled, and the assembly is where correctness
lives or dies. This family has exactly one field renderer, `msg=` and
`request_id=` and `remote=` all pass through it, and its rule is
mechanical: a value containing a space, a quote, or an equals sign is
wrapped in double quotes with backslash and quote escaped, everything
else rides bare. One renderer means one quoting decision, not one per
callsite, and the destination is a single function pointer the wiring
points at the real sink while every test points at its own buffer.
Structured beats interpolated here in the c sense: the fields have
fixed names and a fixed order, a value never leaks into the line
unquoted, and no caller ever builds a line with its own `snprintf`,
because a second assembler is a second chance to forget the escaping:

#listing("c-os-cloud/api/src/obs_log.c", first: 35, last: 57, caption: [the one field renderer: quote when needed, escape inside, refuse truncation])

#diagram([the writer stack: every line through one renderer to one seam], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(5.9, [handler code], [fields as arguments, never a format])
  cdraw.line((5.2, 5.8), (5.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(3.7, [one field renderer], [quote and escape rule, once])
  cdraw.line((5.2, 3.6), (5.2, 3.0), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [the line buffer], [fixed order, length accounting])
  cdraw.line((5.2, 1.4), (5.2, 0.8), stroke: luma(100), mark: (end: ">>"))
  stage(-0.7, [writer seam], [one pointer, wiring or test])
  pane(11.4, 22.6, 5.9, [why one renderer], [a second assembler forgets], [the escaping somewhere])
  cdraw.content((17.0, 0.9), [no caller builds its own line], size: 6pt)
})

== traceparent parse and propagate

The `traceparent` header is the w3c trace context wire format, 55
characters in 4 dash-separated fields: a 2 digit version, a 32 digit
trace id, a 16 digit parent span id, and a 2 digit flags byte, all
lowercase hex. The parser is strict on every axis the spec names:
exact field lengths, lowercase only because the spec defines the
lowercase rendering as canonical, version `ff` reserved and refused,
and all-zero ids refused because the all-zero id means "no id". A
version other than 00 parses under the 00 layout, the spec's additive
rule for newer versions, and only the sampled bit of the flags byte
survives into the span because the rest is undefined.

Propagation is one function with two exits. A valid header joins the
inbound trace: the service's span keeps the inbound trace id, names
the remote span its parent, and carries the sampling bit down. An
absent or malformed header mints a fresh trace and reports that it
did, so one bad header costs a trace, never a request. The tracer's
two inputs are seams, the clock and the id randomness, which is why a
test renders the same span tree twice and gets identical bytes:

#listing("c-os-cloud/api/src/obs_trace.c", first: 116, last: 133, caption: [propagation: join the inbound trace, or mint fresh and report it])

#diagram([traceparent anatomy and the two exits of propagation], length: 13pt, {
  cdraw.line((0.6, 6.0), (23.4, 6.0), stroke: luma(120))
  cdraw.line((3.4, 6.0), (3.4, 7.0), stroke: luma(120))
  cdraw.line((13.6, 6.0), (13.6, 7.0), stroke: luma(120))
  cdraw.line((20.6, 6.0), (20.6, 7.0), stroke: luma(120))
  cdraw.content((2.0, 7.3), [version], size: 6pt)
  cdraw.content((8.5, 7.3), [trace id, 32 hex], size: 6pt)
  cdraw.content((17.1, 7.3), [parent, 16 hex], size: 6pt)
  cdraw.content((22.0, 7.3), [flags], size: 6pt)
  cdraw.content((0.6, 5.2), [#"00-4bf9...4736-00f0...02b7-01"], size: 6pt)
  cdraw.line((11.5, 4.6), (11.5, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.85), [the strict parser], size: 6.5pt)
  cdraw.line((8.0, 3.8), (5.0, 2.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((15.0, 3.8), (18.0, 2.9), stroke: luma(100), mark: (end: ">>"))
  pane(1.0, 9.0, 2.9, [valid], [join the trace], [remote span is parent, bit carried])
  pane(14.0, 22.0, 2.9, [absent or malformed], [mint fresh, report 0], [ff, uppercase, zero ids, bad lengths])
  cdraw.content((11.5, 0.6), [one bad header costs a trace, never a request], size: 6pt)
})

== the text exposition format

The metrics registry is 2 fixed tables: one counter row per route and
status code, one histogram row per route with 12 cumulative buckets,
the contract's 11 finite bounds plus the implicit +Inf. Observing a
duration increments every bucket whose bound it sits under and the
+Inf entry always, which makes the buckets cumulative exactly as the
format requires, and the histogram keeps its own sum and count.

Every series is labeled by the route the router matched, not the path
the client typed: two requests against two different user ids land in
one `/api/users/{id}` series, because a label per raw path is an
unbounded set and the router already owns the pattern. An unmatched
path renders an empty label and still counts. The go lane labels the
same way, asking its mux for the match, and the lane pins the
two-uuids-one-series fact directly. The tables carry one process-wide
lock the family owns, because the composed service observes from all
8 worker threads and an unlocked miss could lose increments or push
the counter row count past its fixed cap mid-render, a duel the tests
run under concurrent fire.

The rendering rules come from the prometheus text exposition format
and are frozen byte for byte by vector 15: the counter family first,
series sorted by label tuple within a family, bucket lines ascending
with zero buckets elided, +Inf always last, and sums in the shortest
fixed decimal that reads back equal, so 3 renders `3`, half a second
renders `0.5`, and the 2.5 bound renders `2.5`. That sum formatting is
a loop over precisions, not a formatting library, and it is the one
place a hand-rolled renderer most easily ships the wrong bytes, which
is why the vector pins it:

#listing("c-os-cloud/api/src/obs_metrics.c", first: 63, last: 78, caption: [the shortest fixed decimal that round trips, and the buffer that accounts for it])

#diagram([one duration through the histogram and out as exposition lines], length: 13pt, {
  cdraw.content((4.0, 8.0), [observe 3.0s on /healthz], size: 6pt)
  cdraw.line((4.0, 7.7), (4.0, 7.0), stroke: luma(100), mark: (end: ">>"))
  pane(0.6, 7.4, 7.0, [the bounds walk], [above every finite bound: nothing], [above 2.5, so all 11 stay 0])
  cdraw.line((4.0, 4.4), (4.0, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(0.6, 7.4, 3.5, [what the row holds], [cum: 11 zeros then 1], [sum 3, count 1])
  cdraw.line((7.6, 5.8), (11.0, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((14.5, 8.0), [render], size: 6.5pt)
  pane(11.2, 23.4, 7.6, [the exposition lines], [zero buckets elided], [+Inf 1, sum 3, count 1])
  cdraw.content((11.5, 2.6), [#"goapi_request_duration_seconds_bucket{...le=\"+Inf\"} 1"], size: 6pt)
  cdraw.content((11.5, 1.6), [#"..._sum{...} 3   ..._count{...} 1"], size: 6pt)
  cdraw.content((4.0, 1.2), [the names are the contract's, frozen lane-wide], size: 6pt)
})

== the internal listener

Metrics are an operations surface, and an operations surface is not a
public one. The contract splits the two addresses: the public
listener serves the api's routes, the internal listener serves
`/metrics` on a loopback port, and the one-table ruling states the
trade plainly, both listeners answer from the same route table, so
the public port serves `/metrics` too and the loopback bind is the
ops address, a convenience for the scraper, not a wall. The same
render function backs both placements, which is the
point of keeping the bytes in one function with no socket knowledge in
it, and in tests the exposition rides the main listener because a test
process has no separate internal network to bind. The registry itself
is one preallocated instance the wiring initializes, and the handler
that serves it renders through the kernel's response api, no socket
knowledge anywhere in the family, so the bytes are the same whichever
listener carries them:

#listing("c-os-cloud/api/src/wire_ops.c", first: 42, last: 44, caption: [the registry instance and its accessor, waiting on the kernel's listener])

#diagram([two listeners, one render function, the split the contract pins], length: 13pt, {
  pane(0.6, 10.6, 6.6, [public listener], [the api routes], [users, login, reports])
  pane(13.4, 23.4, 6.6, [internal listener], [#"/metrics"], [production: unreachable address])
  cdraw.line((5.6, 3.6), (5.6, 2.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.4, 3.6), (18.4, 2.9), stroke: luma(100), mark: (end: ">>"))
  pane(10.4, 13.6, 2.9, [one registry], [one render function], [no socket code inside])
  cdraw.line((5.6, 1.9), (10.2, 1.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.4, 1.9), (13.8, 1.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 0.4), [tests ride the main listener, production does not], size: 6pt)
})

== redaction

Logs are written for strangers to read eventually, so the rule about
what never gets written down comes before any line is assembled. The
closed set names the keys that carry secrets: `password`,
`authorization`, `cookie`, `set-cookie`, `secret`, `token`. The
comparison folds case, because `Password` and `AUTHORIZATION` arrive
at the least convenient moment, and the mask replaces the value with
the literal `[redacted]` while the key itself stays visible, which is
what an operator scanning a line wants: the fact that a password was
logged, without the password. The set is closed on purpose. An open
set, any key matching a pattern like `token`, masks `total_tokens` and
teaches everyone to ignore the mask, and a value-shape scanner that
sniffs secrets by regex quietly misses the next encoding, so the
closed list plus a code review is the honest mechanism:

#listing("c-os-cloud/api/src/obs_log.c", first: 14, last: 29, caption: [the closed redaction set and its case-folded membership test])

#diagram([attribute pairs through the mask before any line exists], length: 13pt, {
  cdraw.content((11.5, 7.6), [attribute pairs from a handler], size: 6pt)
  cdraw.line((11.5, 7.3), (11.5, 6.6), stroke: luma(100), mark: (end: ">>"))
  pane(7.3, 15.7, 6.6, [the mask], [fold the key, check the set], [value becomes [redacted]])
  cdraw.line((9.0, 4.0), (6.0, 3.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.0, 4.0), (17.0, 3.1), stroke: luma(100), mark: (end: ">>"))
  pane(2.0, 10.0, 3.1, [password=...], [#"Password=[redacted]"], [the key stays, the value goes])
  pane(13.0, 21.0, 3.1, [email=ada@...], [passes through whole], [not in the set, not a secret])
  cdraw.content((11.5, 1.0), [closed set plus review, never a pattern match], size: 6pt)
})

== one request fully observed

One login request rides every mechanism in this chapter, and the
chapter's tests replay the pieces so the bytes are pinned. The kernel
mints the request id. The access line records the arrival: method,
path, the id, the 401, 3 milliseconds, the remote address. The tracer
joins the inbound traceparent or mints a trace, stamps the span open,
and closes it when the handler returns, so the duration in the span
and the duration in the log line describe the same interval through
the same clock seam. The counter records `/api/auth/login` at 401, the
histogram observes the seconds, and a scrape renders the family sorted
and elided exactly as vector 15 freezes it. Nothing in the chain read
a wall clock on its own, nothing allocated, and every seam a test
needed is a parameter, which is the chapter's whole test discipline:
72 checks over literals, vectors, and seams, zero sleeps:

#listing("c-os-cloud/api/tests/test_obs.c", first: 339, last: 360, caption: [the vector 15 replay: placeholder resolved, one observation, bytes compared])

#diagram([one request through every signal, one id quoted everywhere], length: 13pt, {
  cdraw.line((0.6, 4.0), (23.4, 4.0), stroke: luma(120))
  cdraw.content((23.6, 4.0), [time], size: 6pt)
  let hit(x, label) = {
    cdraw.circle((x, 4.0), radius: 0.28, fill: luma(160))
    cdraw.content((x, 4.9), [#label], size: 6pt)
  }
  hit(1.6, [id minted])
  hit(5.2, [span open])
  hit(10.4, [401 written])
  hit(14.0, [span end])
  hit(17.6, [counter, histogram])
  hit(21.2, [scrape renders])
  pane(0.6, 8.2, 2.2, [the log line], [id, status, 3 ms], [written at span end])
  pane(15.2, 23.4, 2.2, [the exposition], [route 401, one observe], [frozen bytes on scrape])
  cdraw.content((11.5, 1.2), [same id, same interval, same clock seam, no wall reads], size: 6pt)
})

sources: the w3c trace context recommendation at w3c.org/TR/trace-context,
section 3.2.2 for the traceparent field values, the lowercase canonical
form, the reserved ff version, and the invalid-id rules, accessed
2026-09-27, prometheus.io's exposition formats page for the text format's
help and type lines, histogram bucket semantics, and the +Inf requirement,
accessed 2026-09-27, and learn.microsoft.com's winsock2 bind and listen
pages for the listener surface the internal metrics endpoint rides once
the kernel owns sockets, accessed 2026-09-27. Verified by the obs
family's 72 checks, run from its one entry in the lane's test runner
under the pinned clang 23, including the byte-exact vector 15 replay
from `contract/testdata/15-metrics.txt`, plus clang-format over every
file touched.
