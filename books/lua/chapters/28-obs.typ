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
in `service/obs.lua`: one kv line assembler for every line the ops
family writes beside the kernel's json request log, a closed
redaction set, the W3C traceparent header parsed and formatted from
scratch with spans held as a tree, the fixed-table metrics registry
rendering the prometheus exposition the frozen vector pins.

== the access line

One function renders every line the ops family writes, so the field
order exists exactly once: timestamp, level, message, request id,
method, path, status, duration in milliseconds, remote. The
request-level access log is the middleware chain's lesson, a json
line its own layer writes. The two coexist by role: the chain's line
feeds the deployment, the kv line renders the family's own lines and
any access line wired to its sink. Each field
goes through one kv renderer with a mechanical quoting rule: a value
containing a space, a quote, or an equals sign is double quoted with
backslash and quote escaped, and every other value rides bare. A
lone backslash rides bare: quoting protects the separators.

Two defaults carry real meaning: an absent id renders as a dash, an
absent peer renders `remote=-` and the internal listener stamps no
peer, and a peer that exists comes from the seam, host only, one
stamp:

#listing("lua/service/obs.lua", first: 49, last: 66, caption: [the one access-line assembler, field order fixed by construction])

#diagram([the line's own stack: call site through the kv renderer to the sink], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(5.9, [handler code], [the request answers])
  cdraw.line((5.2, 5.8), (5.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(3.7, [the assembler], [one function, one order])
  cdraw.line((5.2, 3.6), (5.2, 3.0), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [the kv renderer], [bare or quoted, mechanical])
  cdraw.line((5.2, 1.4), (5.2, 0.8), stroke: luma(100), mark: (end: ">>"))
  stage(-0.7, [the sink], [stderr, or a test buffer])
  pane(11.4, 22.6, 5.9, [the defaults], [request_id=- when none], [remote=- when no peer])
  pane(11.4, 22.6, 3.2, [the seam], [peer ip, host only], [stamped once by the kernel])
  cdraw.content((17.0, 0.9), [every line the ops family writes renders here], size: 6pt)
})

== structured beats interpolated

An interpolated message packs data into prose, and prose is lossy:
`login failed for ada, attempt 3` cannot be grouped by email, counted
by attempt, or joined to its request id without a pattern match that
breaks the day the message rewords itself. The structured line
carries the same information as named fields that keep their names
and their places in an index. The rule is the one the kv line
already follows: the message names the event, the fields carry the
data, and no handler interpolates a value it could pass as a field.

Event lines and crash lines render through the same attribute
renderer, and the attribute list is an array of pairs rather than a
hash, because order is data. The request id rides along when there
is one, which is the whole correlation story, one id joining the
log line, any envelope the request produced, and the span tree the
next section builds:

#listing("lua/service/obs.lua", first: 68, last: 88, caption: [the attribute renderer: pairs in call order, the id carried when present])

#diagram([the same failure, line-oriented and structured], length: 13pt, {
  cdraw.content((6.0, 8.0), [interpolated], size: 6.5pt)
  cdraw.rect((0.4, 5.0), (11.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 6.6), [#"login failed for ada@example.org"], size: 6pt)
  cdraw.content((6.0, 5.7), [attempt 3, took 41ms], size: 6pt)
  pane(0.4, 11.6, 4.6, [what a machine sees], [one string], [groupable by nothing])
  cdraw.content((17.6, 8.0), [structured], size: 6.5pt)
  cdraw.rect((12.0, 3.6), (23.2, 7.4), fill: luma(228), radius: 0.02)
  cdraw.content((17.6, 6.7), [msg: login failed], size: 6pt)
  cdraw.content((17.6, 5.8), [email, attempts, duration_ms, request_id], size: 6pt)
  cdraw.content((17.6, 4.9), [password: masked before the sink], size: 6pt)
  pane(12.0, 23.2, 3.2, [what a machine sees], [named fields in order], [count, group, join])
  cdraw.content((11.8, 1.6), [the prose side exists for humans reading along, never for the query], size: 6pt)
})

== redaction as a closed set

Secrets ride in values, so the mask is by key. The redaction set is
closed, six keys, folded to lower case on comparison so a handler
that logs `Password` or `Set-Cookie` is caught just the same:
password, authorization, cookie, set-cookie, secret, token. A member
of the set has its value replaced with `[redacted]` before the
renderer ever sees it, and a key that is merely similar passes
through, because the policy is membership, not similarity. A handler
that logs its login body verbatim ships the password:

#listing("lua/service/obs.lua", first: 29, last: 47, caption: [the closed set folded to lower case, the mask applied by key])

#diagram([one field's trip through the mask], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [the call], [the key, the value])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [fold the key], [#"PASSWORD" is password"])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [the closed set], [member: the value is replaced])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [the line], [#"password=[redacted]"])
  pane(0.3, 11.4, 3.2, [the six keys], [password, authorization], [cookie, set-cookie, secret, token])
  pane(12.0, 23.2, 3.2, [membership only], [#"passwords" passes through], [similarity is not policy])
  cdraw.content((11.5, 1.4), [the mask runs before the renderer, the secret never reaches the sink], size: 6pt)
})

== traceparent from scratch

A trace is the shape of one request's time, joined across services by
one shared header. The W3C trace context format is deliberately
small, four lowercase hex fields, `version-traceid-spanid-flags`, 2,
32, 16, and 2 digits, and small enough to parse and format by hand,
which is what this module does: no sdk, no collector, no span leaves
the process. The parser is strict where the spec allows a choice:
exact field lengths, version `ff` reserved and refused, all-zero
trace or span ids refused, uppercase hex refused because the
lowercase rendering is the canonical one, and only the sampled bit of
the flags byte kept. The spec's processing model says the rest: an
invalid header means the vendor creates a new traceparent, and
unknown flag bits are set to 0 on outgoing requests, which is exactly
what this module does.

The server side is one function. A good header continues the inbound
trace: the same trace id, a fresh span id of our own, the parent set
to the remote span, the sampling bit inherited. An absent or
malformed header mints a fresh trace and reports that it did, because
one bad header must never kill a request. Children opened beneath a
span inherit its trace id and its sampling bit, which is the
propagation the format exists for, and the tree renders one line per
span with two-space indent. Every id comes from the injected source
and every instant from the injected clock, so a test pins the
rendered tree byte for byte:

#listing("lua/service/obs.lua", first: 163, last: 179, caption: [continue: a good header joins the inbound trace, anything else mints fresh])

#diagram([one login request's spans over time, the tree the render prints], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [t], size: 6pt)
  cdraw.rect((2.0, 5.6), (16.0, 6.6), fill: luma(200), radius: 0.02)
  cdraw.content((9.0, 6.1), [POST /api/auth/login], size: 6pt)
  cdraw.rect((3.2, 3.9), (10.4, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((6.8, 4.4), [store: user by email], size: 6pt)
  cdraw.rect((10.8, 3.9), (14.6, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((12.7, 4.4), [pbkdf2 verify], size: 6pt)
  cdraw.rect((14.8, 2.2), (19.2, 3.2), fill: luma(222), radius: 0.02)
  cdraw.content((17.0, 2.7), [session create], size: 6pt)
  cdraw.line((6.8, 3.8), (6.8, 3.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((19.6, 3.9), (22.6, 4.9), fill: luma(215), radius: 0.02)
  cdraw.content((21.1, 4.4), [jwt sign], size: 6pt)
  pane(0.4, 11.2, 1.6, [the render], [name, duration, span id], [two spaces per depth])
  pane(13.0, 23.2, 1.6, [the inheritance], [trace id, sampled bit], [every child carries both])
  cdraw.content((9.0, 1.2), [a bad inbound header starts a fresh root, the request always proceeds], size: 6pt)
})

== the fixed-table metrics registry

Two series carry the load story, and both live in one registry of
fixed tables, the c lane's shape carried into lua. The counter is one
series per route and status code, `goapi_requests_total{route,code}`,
incremented once per request. The histogram is one per route,
`goapi_request_duration_seconds`, with the contract's eleven finite
bounds tight at the low end where service latencies live and
geometric through the tail plus the implicit `+Inf`. An observation
increments every bound the seconds fit under, which is what makes the
counts cumulative, plus `+Inf`, the sum, and the count.

Two policies differ from the threaded lanes. The tables are bounded:
sixty-four counter series
and thirty-two routes by default, a full table answers nothing new,
the bounded policy stated where the go lane's map grows and the c
lane states the same bound, because the lua alternative is an
unbounded table the composition root keeps alive forever, which is
exactly the leak the load chapter counts. And there is no lock
anywhere: the c lane guards the same registry with a process-wide
srw lock because its worker threads draw concurrently, while this vm
is single threaded, one request at a time by construction, so the
registry needs no guard at all, the host's serialization doing the
work, a stated truth and not a free lunch:

#listing("lua/service/obs.lua", first: 279, last: 294, caption: [count: find-and-bump through the index, the bounded policy on the miss])

#diagram([the registry: fixed tables, one index, no lock], length: 13pt, {
  cdraw.rect((0.4, 3.4), (11.2, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 7.1), [the registry], size: 6.5pt)
  cdraw.content((5.8, 6.1), [counters, bounded 64], size: 6pt)
  cdraw.content((5.8, 5.1), [histograms, bounded 32], size: 6pt)
  cdraw.content((5.8, 4.1), [index maps beside them], size: 6pt)
  cdraw.line((11.4, 5.5), (12.8, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(13.0, 19.6, 7.6, [count], [find-and-bump], [a miss appends if a slot is free])
  cdraw.line((19.8, 5.5), (21.2, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(21.4, 23.4, 7.6, [full], [the increment drops], [the bound, stated])
  pane(0.4, 11.2, 2.2, [no lock], [single-threaded vm], [the c lane needs the srw])
  cdraw.content((17.0, 1.4), [bounded tables and no lock: two platform truths in one registry], size: 6pt)
})

== the exposition, byte for byte

The exposition writer renders the prometheus text format directly:
help and type lines per family, the counter family first, series
sorted by label tuple within a family, bucket lines ascending with
`+Inf` last, and every number in the shortest fixed decimal that
rounds back to the same value, so 3 renders 3, 0.5 renders 0.5, and
0.0025 renders 0.0025. Zero buckets are elided, the one deliberate
divergence from client_golang, which prints every finite bucket at
zero as well. The format's own requirements are fewer than a reader
might fear: the +Inf bucket must exist and equal the count, buckets
must ascend by their `le` label, and each family's lines must ride
together under their help and type lines. This writer does all three
and freezes the rest by test. One slow `/healthz` observation, past
every finite bound, renders exactly the eight lines
the contract froze: the counter family, then the histogram with only
the `+Inf` bucket, the sum, and the count. The vector carries
`<observed>` where the sum sits, and the test substitutes its own
observation before the byte comparison, pinning both the fixed lines
and the sum's rendering:

#listing("lua/service/contract/testdata/15-metrics.txt", first: 1, last: 8, caption: [the frozen vector the exposition renders against, byte for byte])

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
  cdraw.content((10.5, 4.1), [counts only grow, so bucket i includes all smaller], size: 6pt)
  pane(0.4, 10.4, 2.4, [the ladder], [tight low, geometric tail], [11 finite bounds plus Inf])
  pane(12.4, 23.2, 2.4, [the four members], [bucket lines, +Inf, sum, count], [zero buckets elided])
})

== one request fully observed

Wire the signals around one request and a login tells the whole
story. The metrics layer wraps the stack one layer out, so the
counter ticks at the status the inner response really carries and the
histogram at the duration two clock reads measured around it, and the
registry sits behind this layer, so a 429 from the limit layer inside
counts like any other status. The route label comes from the router's
matched pattern, never
the raw path, because a raw path would mint one series per concrete
user id and fill the bounded table with uuids nobody graphs, and an
unmatched path carries the empty label, the router's own answer,
never a standing literal for it. The chain's json log line and the
span open at the same request, the id joins them, and the label
agrees with the line's path because both read the same match.

Reading it back is what the tests do, separately and without
ceremony: the assembler test pins the whole line's bytes, the
redaction test pins the mask, the parser test walks every refusal,
the exposition test renders the frozen vector, and the layer test
drives the layer over an injected label function and asserts the
series that come out. The composed walkthrough drives one request
through the same layer order the root splices, the id on the line and
the response, both series by the matched pattern, the scrape adding
its own series for the next scrape to see, the denial counted:

#listing("lua/service/obs.lua", first: 398, last: 416, caption: [the metrics layer: matched pattern label, status captured, both series ticked])

#diagram([one request id through every signal], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [id minted], [the kernel resolves one])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [span opened], [continues or mints])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [handler runs], [log line with the id])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [series tick], [counter, histogram])
  pane(0.3, 11.4, 2.6, [the log line], [request_id field], [correlates client and server])
  pane(12.0, 23.2, 2.6, [the exposition], [route and code labels], [scraped on the internal port])
  cdraw.content((11.7, 1.3), [grep the id: log line, span tree, envelope, all one request], size: 6pt)
})

sources: the W3C trace context level 1 recommendation at
w3c.github.io/trace-context, sections 3.2.2.2 through 3.2.2.5 for the
traceparent field grammar and sections 4.2 and 4.3 for the processing
model whose invalid-header and zeroed-flags rules this chapter
quotes, the prometheus text exposition format documentation at
prometheus.io, and lua.org manual 5.5 sections 6.5 (string
manipulation), 6.7 (table manipulation, concat), 6.2 (tonumber with
a base), and 3.4.2 (bitwise operators, the sampled-bit mask), all
accessed 2026-09-27, with client_golang's zero-bucket behavior as the
go chapter verified it 2026-09-25. Verified by the service plain lane
under the pinned lua 5.5, `run.lua` green with this module's 14
among them (the whole-lane census chapter 31 states once), the
exposition replayed byte for byte from
`contract/testdata/15-metrics.txt`.
