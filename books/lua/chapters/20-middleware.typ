#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= the middleware chain

Cross-cutting behavior does not belong inside handlers, and lua does
not make anyone put it there. This chapter composes the service's
middleware stack over the kernel: the chain fold that turns layers
into one handler, the request id born once at the edge and quoted
everywhere, the access log that reads the answer off the response
value, the deadline whose whole authority is owning the resume, and
recover, which keeps a handler bug from killing the connection. The
wiring order at the end is contract, and the stack test is the
property that enforces it.

== the chain fold

One layer is one function: given the next handler, return the
handler that wraps it. That is the whole shape, and because it is a
plain function contract, anything written against it composes with
anything else. The fold runs right to left so the first argument
ends up outermost, sees the request first and the response last,
the onion picture every middleware chapter draws because it is the
true one. A chain is itself a layer, chains compose into bigger
chains, and the kernel's `app:use` appends onto the same fold, first
used outermost. The loop direction is worth one sentence out loud:
folding left to right would put the last layer outside, and the
wiring order in this chapter's sixth section is a contract, not an
accident:

#listing("lua/service/middleware.lua", first: 17, last: 26, caption: [chain: one layer wraps the next, first argument outermost])

#diagram([the onion: first argument outside, request falls in, response climbs out], length: 13pt, {
  cdraw.rect((0.4, 4.6), (8.6, 8.0), fill: luma(235), radius: 0.05)
  cdraw.content((4.5, 7.5), [request id], size: 6pt)
  cdraw.rect((1.6, 5.6), (7.4, 7.0), fill: luma(228), radius: 0.05)
  cdraw.content((4.5, 6.3), [access log], size: 6pt)
  cdraw.rect((2.8, 6.6), (6.2, 7.6), fill: luma(222), radius: 0.05)
  cdraw.content((4.5, 7.1), [deadline], size: 6pt)
  cdraw.rect((3.6, 7.4), (5.4, 8.4), fill: luma(215), radius: 0.05)
  cdraw.content((4.5, 7.9), [recover], size: 6pt)
  cdraw.content((4.5, 5.1), [handler], size: 6pt)
  cdraw.line((-0.6, 4.9), (0.2, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((-0.9, 5.5), [request], size: 6pt)
  cdraw.content((-0.9, 4.3), [falls in], size: 6pt)
  cdraw.line((8.8, 3.9), (9.6, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.6, 4.5), [response], size: 6pt)
  cdraw.content((10.6, 3.3), [climbs out], size: 6pt)
  pane(12.4, 22.8, 7.8, [the fold], [chain(a, b, c)(h): a wraps], [b wraps c wraps h, first is outer])
})

== request id

Every request needs one id every artifact agrees on: the access log
line, the error envelope, the recover line, and later the metrics.
The layer resolves it exactly once, at the edge, using the kernel's
three-way order: a value already carried wins, else a client header
that parses as a uuid echoes canonicalized to lower case, else the
injected source mints a fresh v7. Parsing is not politeness, it is
contract: the envelope promises the member is a uuid, and a client
supplied free-text header echoed into logs is log injection.
Garbage is replaced, never echoed.

The layer then does two small things with the value. It sets
`req.request_id`, and lua's answer to a context is right there: the
request is a table the whole stack already passes by reference, so
an id carried on it needs no context library and no closure tricks.
And it appends the id to the response headers, after whatever the
inner stack built, so a client can correlate its own logs with the
server's. The dispatch base resolves an id too when this layer has
not run, which is why every envelope in the kernel tests carries one
even without the stack:

#listing("lua/service/middleware.lua", first: 31, last: 44, caption: [request_id: resolve at the edge, carry on the request, echo on the response])

#diagram([one id, born at the edge, quoted by everything downstream], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [request arrives], [with or without an id])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [the edge resolves], [carried, header uuid, mint])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [one value, two surfaces], [the request table, the header])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [downstream], [log, envelope, metrics])
  pane(0.3, 9.4, 3.2, [garbage header], [replaced, never echoed], [a uuid always])
})

== the access log

The go lane's access log wraps the `ResponseWriter` in a capturing
proxy because a go handler writes the answer instead of returning
it, and that wrapper costs: first-write rules, forwarded optional
interfaces, the double-write trap. The lua kernel returns the
answer as a value, so the layer reads it directly, and every one of
those costs evaporates before it exists. Method, path, status,
bytes, duration, and the request id go out as one json line through
the service's own codec, which is the discipline doing double duty:
the log line is built exactly the way a wire body is, ordered
members by construction.

Two honesty notes ride with the layer. The sink and the clock are
injected: tests collect lines into a table and step time by hand,
and the production sink writes to stderr because the host owns the
process. And the duration comes from the injected clock, which in
production is `os.time` in whole seconds, so a fast request logs a
duration of 0 and that reading is honest, not a bug: the stdlib has
no monotonic clock, the profiling chapter measured that boundary,
and finer timing is a c seam question, not a lua one:

#listing("lua/service/middleware.lua", first: 51, last: 67, caption: [access_log: the value goes on the wire, so the log reads it directly])

#diagram([no capture wrapper exists to get wrong: the value is the record], length: 13pt, {
  pane(0.3, 7.4, 7.4, [go lane], [handler writes into], [a proxy that captures])
  cdraw.content((3.85, 5.2), [first-write rule, forwarded], size: 6pt)
  cdraw.content((3.85, 4.3), [interfaces, double-write trap], size: 6pt)
  cdraw.line((7.8, 6.2), (8.6, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(8.8, 15.8, 7.4, [lua lane], [handler returns], [the response value])
  cdraw.line((12.3, 5.2), (12.3, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(8.8, 15.8, 4.2, [the log line], [status, bytes, duration], [read straight off the value])
  cdraw.content((18.2, 6.4), [one json line], size: 6pt)
  cdraw.content((18.2, 5.5), [through the one codec], size: 6pt)
  cdraw.content((18.2, 4.6), [to the injected sink], size: 6pt)
})

== the deadline owns the resume

A deadline in go runs the handler on another goroutine and abandons
it on expiry. A lua vm cannot do that: nothing preempts running lua
code, and pretending otherwise would be the dishonest sentence this
chapter refuses to write. What the layer owns instead is every
resume. The inner stack runs inside a coroutine, and a coroutine
only continues when someone resumes it, so the layer turns each
yield into a checkpoint: resume, check the injected clock against
the budget, resume again while time is left. On expiry it abandons
the coroutine unresumed, answers the overload envelope, and the
suspended routine becomes garbage the collector reclaims.

The boundary is stated as a fact and tested as one. A handler that
never yields cannot be interrupted, and the test proves it by
burning three times the budget with no yield and getting its answer.
The blocking half of the story lives below lua: a client that
stalls mid-body holds the connection inside `net.recv`, and the
answer there is a socket timeout at the c seam, taught as a host
concern. Errors do cross the coroutine boundary, resume reports
them as a false return, and the layer rethrows for whoever guards
it, the one place the go lane's goroutine rule inverts:

#listing("lua/service/middleware.lua", first: 78, last: 95, caption: [deadline: the resume is the checkpoint, expiry abandons the coroutine])

#diagram([each yield is a checkpoint, expiry is a refusal to resume], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.6), (x0 + 5.4, 6.8), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.7, 6.2), [#title], size: 6pt)
    cdraw.content((x0 + 2.7, 5.2), [#l1], size: 6pt)
  }
  step(0.3, [handler yields], [store io, more bytes])
  cdraw.line((5.9, 5.7), (6.3, 5.7), stroke: luma(100), mark: (end: ">>"))
  step(6.3, [the layer checks], [clock against budget])
  cdraw.line((11.9, 5.7), (12.3, 5.7), stroke: luma(100), mark: (end: ">>"))
  step(12.3, [time left], [resume, the loop repeats])
  cdraw.line((5.0, 4.4), (5.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(1.4, 10.6, 3.4, [budget spent], [never resumed again], [overload envelope answers])
  cdraw.content((17.6, 3.5), [no yield means no checkpoint], size: 6pt)
  cdraw.content((17.6, 2.4), [blocking recv is the c seam's half], size: 6pt)
})

== recover

A handler bug must not kill the connection, and the host makes that
doubly true: a lua error escaping `handle` is fatal for the whole
process, the c host exits on it by design. The recover layer stands
innermost and converts the failure instead. `xpcall` runs the inner
stack with `debug.traceback` as the handler, so the captured value
is the error and its stack in one string, one json line goes to the
sink with the request id, and the client sees the internal envelope
through the one writer, message hidden because a leaked `attempt to
index a nil value` tells a client more than it should know.

The go lane rethrows one sentinel, `ErrAbortHandler`, the server's
own drop-the-connection signal. There is no lua counterpart to
rethrow: the host's fatal errors live outside `handle` entirely, and
the kernel's outer pcall is the last resort under this layer, which
is also why recover can sit inside the deadline without a
goroutine rule. Placement is still mechanical: the deadline runs the
stack in a coroutine, and recover inside it catches handler bugs
where they happen, the rethrow only ever carrying a bug in a layer
itself:

#listing("lua/service/middleware.lua", first: 103, last: 117, caption: [recover: xpcall captures the traceback, the envelope hides the detail])

#diagram([a bug becomes one log line and one envelope, never a dead host], length: 13pt, {
  pane(0.3, 7.0, 7.6, [handler raises], [index a nil value], [a bug, not an outcome])
  cdraw.line((3.65, 5.5), (3.65, 4.6), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 7.0, 4.4, [xpcall, traceback], [error plus stack, one string])
  cdraw.line((7.2, 3.6), (8.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(8.2, 15.0, 4.4, [the sink], [one json line], [with the request id])
  cdraw.line((15.2, 3.6), (16.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(16.2, 23.2, 4.4, [the client], [500 internal envelope], [detail kept out])
  cdraw.content((11.5, 1.8), [the host never sees the error, the process lives], size: 6pt)
})

== wiring order and what it proves

The order is contract, and each position is a sentence. Request id
outermost, because every other artifact quotes it: the access log
line, the recover line, the envelope. Access log second, outside
recover, so a recovered 500 is logged as the 500 the client saw
rather than a status no one answered. Then the families that have
landed, in the order the request meets them: the metrics layer,
outside the bucket so a refused request still counts, then the
limiter, which rejects a 429 before the deadline budget spends
anything. The deadline is next, recover innermost beside the
handlers it guards, and the identity layer sits below recover with
the concurrency chapter's idempotency guard inside it, the innermost
family layer. No admission gate ever joined this chain: the
sequential vm and the readiness gate at the ship seam own overload,
the bucket is the per-route budget, and a hypothetical gate would
slot between the metrics counter and the bucket so a refusal still
counts. The composition root reads
top to bottom as the request flows, and the wrong-order failure mode
is exactly the go lane's: a log inside recover records nothing on a
panic while the client still gets its 500, two artifacts
disagreeing about one request:

#listing("lua/service/main.lua", first: 287, last: 304, caption: [the real order on disk: the rules seam naming what attaches, the budget, recover innermost])

#diagram([wrong order versus right: where the log sits decides what it sees], length: 13pt, {
  cdraw.content((6.4, 8.2), [wrong: log inside recover], size: 6.5pt)
  cdraw.content((6.4, 7.5), [id, deadline, recover, log, handler], size: 6pt)
  cdraw.content((6.4, 6.8), [the panic unwinds past the log first], size: 6pt)
  pane(0.4, 12.4, 5.4, [two artifacts], [the log records nothing], [the client still gets a 500])
  cdraw.line((12.6, 4.9), (13.4, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.4, 8.2), [right: log outside recover], size: 6.5pt)
  cdraw.content((18.4, 7.5), [id, log, metrics, limit, deadline, recover], size: 6pt)
  cdraw.content((18.4, 6.8), [recover answers inside, the log sees it], size: 6pt)
  pane(12.6, 24.2, 5.4, [one artifact], [the log records the 500], [with the id, like the envelope])
  cdraw.content((18.4, 1.1), [identity innermost below recover, load and ship still open], size: 6pt)
})

== testing the chain

Every clock in this chapter's tests is a stepped callable: it
advances when the test says so, a fixed increment per call, and no
test sleeps anywhere in the part. The fast paths compose recording
layers around tiny handlers and read the pass order off the recorded
table, the log layers capture their lines into a table and decode
them with the service's own codec before asserting, and the deadline
tests script the yield sequence so expiry lands on a named resume.
The stack test is the one that fails when anyone reorders the
wiring: a handler that raises runs under the full four-layer chain,
and the assertions demand one recover line, one access line
recording the 500, and the id on both the header and the envelope:

#listing("lua/service/middleware.lua", first: 277, last: 297, caption: [the stack test: wrong order fails here, log and envelope agree on the 500])

#diagram([stepped clocks, recording layers, captured sinks: the harness has no timers], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [stepped clock], [advances on call])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [recording layers], [the order in a table])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [captured sink], [lines decoded and read])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [assert, then done], [no sleeps, no timers])
  pane(6.0, 16.2, 3.0, [the wire leg], [the mw driver over the host], [echo, replace, uniqueness])
})

sources: the lua 5.5 manual at lua.org/manual/5.5, sections 2.6 on
coroutines and symmetric control transfer, 6.2 on the coroutine
library's resume and status semantics, 6.1 on xpcall message
handlers, 6.10 on debug.traceback, and 6.9 on os.time, accessed
2026-09-27. Verified against the go lane's
`go/api/internal/middleware/chain.go`, `timeout.go`, and
`middleware_test.go`, the python lane's `python/api/pyapi/middleware.py`
worker-thread deadline, and the c lane's four-layer continuation
stack in `c-os-cloud/api/api.h`, and by the service suites: the 10
middleware module tests, 12 kernel module tests, and the 10 wire
checks in the mw driver.
