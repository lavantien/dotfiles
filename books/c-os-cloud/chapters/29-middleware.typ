#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= middleware

Cross-cutting behavior does not belong inside the handlers, and this
chapter composes it over the previous chapter's kernel in
`c-os-cloud/api/src/middleware.c`: the chain type that folds layers
through an explicit continuation, request ids born once and quoted
everywhere, the access log, the structured-exception crash guard that
stands in for the go lane's recover, timeouts at two layers, and the
wiring order that makes the stack correct rather than merely present.
Two of the go chapter's lessons do not survive the translation and the
prose says so where they fall: a c response is a struct the logger
reads, so the status-capturing writer problem is structurally absent,
and a thread cannot unwind a running handler, so the deadline is
cooperative where the go lane abandoned a goroutine.

== the chain type

One layer is one function that receives the request, the response, a
fail slot, and a continuation, and either calls down or answers
instead of calling down. The continuation is a two-field struct, the
stack and an index, and calling it runs the next layer or, past the
end, the route dispatch. That is the whole mechanism, four lines, and
it replaces the closure the go lane's `Func` builds with data any
reader can follow: the stack is an array of function pointers in
wiring order, and the fold is the call stack itself doing the work.

A layer that answers without calling down short-circuits everything
below it, the rate limiter's 429 shape, and a layer that wants to
observe the answer calls down first and reads the response on the way
back out. The pass order the tests pin is the honest spec: outer in,
inner in, dispatch, inner out, outer out, and a short circuit leaves
the markers below it unwritten:

#listing("c-os-cloud/api/src/middleware.c", first: 18, last: 28, caption: [the fold: the continuation is the stack and an index, dispatch at the bottom])

#diagram([one layer, one continuation, the call stack is the onion], length: 13pt, {
  cdraw.rect((0.4, 4.6), (8.6, 8.0), fill: luma(235), radius: 0.05)
  cdraw.content((4.5, 7.5), [request id], size: 6pt)
  cdraw.rect((1.6, 5.6), (7.4, 7.0), fill: luma(228), radius: 0.05)
  cdraw.content((4.5, 6.3), [access log], size: 6pt)
  cdraw.rect((2.8, 6.6), (6.2, 7.6), fill: luma(222), radius: 0.05)
  cdraw.content((4.5, 7.1), [deadline], size: 6pt)
  cdraw.rect((3.6, 7.4), (5.4, 8.4), fill: luma(215), radius: 0.05)
  cdraw.content((4.5, 7.9), [crash guard], size: 6pt)
  cdraw.content((4.5, 5.1), [dispatch], size: 6pt)
  cdraw.line((-0.6, 4.9), (0.2, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((-0.9, 5.5), [request], size: 6pt)
  cdraw.content((-0.9, 4.3), [falls in], size: 6pt)
  cdraw.line((8.8, 3.9), (9.6, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.6, 4.5), [response], size: 6pt)
  cdraw.content((10.6, 3.3), [climbs out], size: 6pt)
  pane(12.4, 22.8, 7.8, [the continuation], [#"next = stack, i+1"], [no closure, no allocation])
  pane(12.4, 22.8, 4.0, [short circuit], [answer, never call down], [rate limiting lands here later])
})

== request-id at the edge

Every artifact that talks about a request agrees on one id: the access
log line, the crash log line, the error envelope. The kernel's serve
loop already stamps a fresh v7 into every request, the edge guarantee
that an id always exists, and this layer decides whose id it is. A
client `X-Request-ID` that parses as a uuid wins and is adopted
verbatim. Anything else is replaced, never echoed, because the
envelope promises a uuid and a free-text header quoted into a log is
log injection. The go chapter's three-way order collapses here into
two rules said plainly: the edge guarantees existence, the layer
decides identity.

The layer also writes the id into the response header, so a client can
correlate its own logs with the server's without parsing an error body.
The test pins all three births: no header, the stamped id stands and
is echoed. A valid client uuid replaces the stamped one everywhere
downstream, envelope included. Garbage is replaced and the envelope
still quotes the good id:

#listing("c-os-cloud/api/src/middleware.c", first: 43, last: 51, caption: [resolve identity at the edge, echo it back, quote it downstream])

#diagram([one id, born at the edge, quoted by everything downstream], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [serve loop], [fresh v7, existence])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [the id layer], [client uuid or keep])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [response header], [#"X-Request-ID echo"])
  pane(0.3, 8.8, 3.4, [access log], [first field], [stable across retries])
  pane(9.9, 18.4, 3.4, [error envelope], [#"request_id member"], [a uuid, always])
  pane(0.3, 8.8, 0.6, [crash log], [first field], [same value])
  cdraw.content((15.9, -0.6), [garbage headers are replaced, never echoed], size: 6pt)
})

== the access log

The go chapter needed a status-capturing writer because a handler
writes to an interface the middleware cannot see through. The c kernel
has no such interface: the response is a struct, the middleware holds
the same pointer the handler wrote through, and the status, the header
table, and the byte count are fields it reads after the stack returns.
The double-write trap is structurally absent, the first-wins rule is
the only rule because there is only ever one write, and the wrapper
type that costs go its optional interfaces does not exist here.

What remains is the line itself and the sink. The line is the
observability chapter's kv form, and this layer does not format it:
the layer builds the access record, ts, level, msg, the request id,
method, path, status, duration, and the kernel's peer stamp in the
remote field, then hands the record to that chapter's renderer, the
one assembler every log line in the vehicle goes through, so the
access line and the book's line shape can never drift apart. A
request that arrives without a peer stamp renders `remote=-`, which
is the internal listener's honest line. Every field is deterministic
at an injected clock, zero elapsed on a clock that never steps. The
sink is a function-pointer seam like the clock, so tests capture
lines into a buffer and assert bytes, and the wiring installs stderr
for production. The renderer bakes the trailing newline, so the sink
writes exactly the bytes it was handed. The log lands after the stack
returns, which is the whole reason it sits outside the crash guard in
the wiring order:

#listing("c-os-cloud/api/src/middleware.c", first: 56, last: 81, caption: [the response is data: build the access record, render through the one assembler])

#diagram([read the struct, write the line, no wrapper exists], length: 13pt, {
  cdraw.rect((0.4, 3.6), (10.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 6.9), [the response struct], size: 6.5pt)
  cdraw.content((5.5, 5.9), [status, body_len: plain fields], size: 6pt)
  cdraw.content((5.5, 4.9), [the layer reads after next returns], size: 6pt)
  cdraw.line((10.8, 5.5), (11.6, 5.5), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 19.0, 7.4, [one kv line], [#"ts=.. msg=request .. remote=.."], [one renderer, sink seam])
  cdraw.content((6.0, 2.6), [the go lane built a statusWriter for this: c never needed one], size: 6pt)
})

== the crash guard

The go lane recovered panics. C has no panics, and the equivalent
failure is a hardware or system exception: an access violation, a
divide by zero, an aligned read from a misaligned pointer. Windows
routes all of them through structured exception handling, and the
guard is one `__try` around the continuation with a filter that
executes the handler for everything except a stack overflow. The
filtered path renders the contract's 500 `internal` envelope through
the one writer and the crash line through the observability family's
attribute renderer, level error and the exception code as a kv pair,
so the process lives and the client still learns nothing it should
not.

Two honest limits come with the mechanism. A stack overflow passes the
exception on because the guard that tried to answer it would run on
the broken stack, so the process dies honestly instead of lying. And
the envelope answer after an arbitrary fault is best effort by nature:
whatever state the fault left is the state the renderer runs on. The
tests raise the exception in software, `RaiseException` with the
access violation status, which exercises the exact handler path
without tripping the sanitizer legs a real fault would poison:

#listing("c-os-cloud/api/src/middleware.c", first: 122, last: 141, caption: [seh recover: filter first, envelope and crash log second, best effort stated])

#diagram([fault unwind: one path to the log, one to the envelope, one rethrown], length: 13pt, {
  pane(0.3, 7.0, 7.6, [below the guard], [#"access violation, divide"], [by zero, alignment])
  cdraw.line((3.65, 5.5), (3.65, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 3.0), (7.0, 4.4), fill: luma(225), radius: 0.02)
  cdraw.content((3.65, 3.95), [the seh filter], size: 6pt)
  cdraw.content((3.65, 3.25), [stack overflow rethrown], size: 6pt)
  cdraw.line((7.2, 3.7), (8.2, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(8.4, 15.2, 5.4, [log], [#"id crash <code>"], [never the response])
  cdraw.line((15.4, 3.7), (16.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(16.6, 23.2, 5.4, [envelope], [500 internal], [message hidden])
  cdraw.line((3.65, 2.8), (3.65, 1.9), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 7.0, 1.6, [rethrown], [stack overflow], [the process dies honestly])
  cdraw.content((14.6, 0.5), [tests raise in software: the exact path, no sanitizer fault], size: 6pt)
})

== timeouts at two layers

The transport layer is coarse and belongs to the socket: the pool sets
`SO_RCVTIMEO` and `SO_SNDTIMEO` to 30 seconds on every accepted
connection, so a stalled peer loses the connection instead of holding
a worker forever. Nothing recovers the request. The connection dies,
which is the correct outcome for a client that stopped talking, and
the worker returns to the pool.

The handler layer is finer and belongs to the stack. The deadline
layer stamps `deadline_ms` into the request from the injected clock
plus the budget, and that stamp is the contract with every handler
that runs a long loop: the reports handler in a later chapter checks
it between pages of work, because a thread cannot unwind the code that
missed its own deadline. This is the honest difference from the go
lane, whose timeout ran the handler on a second goroutine and dropped
the whole goroutine on expiry. After the stack returns, the layer
refuses to vouch for an answer that arrived past budget and replaces
it with the 503 `overload` envelope. The work already ran, stated
plainly, and the client still gets the truth:

#listing("c-os-cloud/api/src/middleware.c", first: 85, last: 105, caption: [stamp the deadline, then refuse to vouch for a late answer])

#diagram([two clocks: transport kills the connection, the deadline refuses the answer], length: 13pt, {
  cdraw.content((3.2, 8.1), [transport layer], size: 6.5pt)
  cdraw.line((0.6, 7.4), (12.2, 7.4), stroke: luma(120))
  cdraw.content((2.4, 6.8), [recv timeout], size: 6pt)
  cdraw.content((8.6, 6.8), [send timeout], size: 6pt)
  cdraw.content((3.2, 5.6), [30 s, on every pool socket], size: 6pt)
  cdraw.content((3.2, 4.6), [a stalled peer loses the connection], size: 6pt)
  cdraw.content((17.6, 8.1), [handler layer], size: 6.5pt)
  cdraw.rect((13.4, 4.4), (21.8, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.6, 5.9), [the deadline stamp], size: 6pt)
  cdraw.content((17.6, 5.0), [handlers check it in loops], size: 6pt)
  cdraw.line((17.6, 4.3), (17.6, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(13.4, 21.8, 3.6, [past budget], [503 overload envelope], [the late answer is dropped])
  cdraw.content((17.6, 1.4), [cooperative, not abandonment: a thread cannot unwind], size: 6pt)
})

== wiring order and why

The order of the ten layers is contract and each position is a
sentence. Request id outermost, because every other artifact quotes
it: the access log line, the crash line, the envelope. The access log
second and outside the guard, so a crashed request is logged as the
500 the client saw and not as nothing at all, the go chapter's wrong
order picture with the c mechanism that makes it true. Metrics third
and outside the limit, so a refused request still counts. Admission
next, refusing overload before any per-route budget is spent, then
the limit, then the deadline under both, so a late answer is
measured, refused, and logged as the 503 that replaced it.

The three families after the deadline are where this stack departs
from the go lane's wire table, and the departure is the platform's
fault model arguing back. The conditional read, the idempotency
guard, and the cache layer sit above the crash guard, guard
innermost, the reverse of the go lane, which composes recover
outermost of the four because a go panic runs the deferred releases
on its way out. An seh unwind runs nothing: a fault caught below a
layer holding a singleflight slot would skip the flight's release and
park every later joiner on that key forever. The guard converts a
handler fault into a return, and a return unwinds each flight's
epilogue normally, so the two slot holders, the cache layer and the
idempotency guard, sit above it, and the conditional read sits above
both so a 304 short-circuits before the table or the snapshot is
asked. The order is not free, it is the price of ruling that a fault
must never strand a key, and the wiring comment carries the argument
so nobody reorders the array without meeting it.

The wiring file holds the array and two defaults, the log sink and
the budget, and it constructs the three families' state, the
admission gate, the cache table, the idem flight table, when no
earlier family did, every setup idempotent so the composition root's
own family order never double-builds any of them. The stack is
optional at runtime: the serve loop dispatches directly when no stack
is installed, so the order the wiring fixes is documentation the tests
enforce rather than a dependency the kernel cannot live without. The
stack test fails the moment anyone reorders the array, which is the
property the chapter exists to keep:

#listing("c-os-cloud/api/src/wire_middleware.c", first: 34, last: 56, caption: [the wiring: ten layers in the fixed order, the families' state constructed idempotently])

#diagram([wrong order versus right: where the log sits decides what it sees], length: 13pt, {
  cdraw.content((6.4, 8.2), [wrong: log inside the guard], size: 6.5pt)
  cdraw.content((6.4, 7.5), [id, guard, log, deadline, dispatch], size: 6pt)
  cdraw.content((6.4, 6.8), [the fault unwinds past the log first], size: 6pt)
  pane(0.4, 12.4, 5.4, [the log records], [nothing, or a half answer], [the fault skipped it])
  pane(0.4, 12.4, 2.4, [the client sees], [500 internal], [from the guard outside])
  cdraw.content((6.4, 1.1), [two stories for one request], size: 6pt)
  cdraw.line((12.6, 4.9), (13.4, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.4, 8.2), [right: log outside the guard], size: 6.5pt)
  cdraw.content((18.4, 7.6), [id, log, metrics, admission, limit, deadline, #linebreak() precond, idem, cache, guard, dispatch], size: 6pt)
  cdraw.content((18.4, 6.6), [the guard answers inside, the log sees the answer], size: 6pt)
  pane(12.6, 24.2, 5.4, [the log records], [500, the crash line too], [one story, everywhere])
  pane(12.6, 24.2, 2.4, [the client sees], [the same 500], [with the id quoted])
  cdraw.content((18.4, 1.1), [guard innermost, the flight holders above it: an seh unwind runs nothing], size: 6pt)
})

== testing middleware

Middleware is tested like the kernel, through the same fixtures, and
the double mechanism carries all of it: the clock is a counter the
tests step by hand, the log sink captures lines into a buffer the
checks read back, and the id source is a constant. The fold tests use
recorder layers that write markers around the descent and assert the
exact sequence. The id tests run the three births. The log test
asserts one exact line. The deadline tests step the clock inside and
outside the budget. Nothing sleeps anywhere, because nothing needs to:
every time-dependent behavior in the stack is arithmetic on the
injected counter.

The crash guard is the one place a test cannot just call the code, or
so it seems, because the honest way to fault is to fault. The lane's
answer is `RaiseException` with the access violation status: the
exception travels the same seh path, the filter sees the same code,
the handler renders the same envelope, and no sanitizer observes a
real fault, so the asan leg stays meaningful. The stack test at the
end reads the pass order and the two log lines together, one crash
line from the guard and one access line from the logger outside it,
which is the wiring order proving itself in output:

#listing("c-os-cloud/api/tests/test_middleware.c", first: 65, last: 75, caption: [a recorder layer: markers around the descent, the order is the assertion])

#diagram([every input is injected, every output is captured, no clock exists], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [clock], [stepped by hand])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [the stack], [recorders around it])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [captured lines], [bytes asserted])
  pane(0.3, 11.0, 3.4, [the fault], [#"RaiseException(AV)"], [same seh path, no crash])
  pane(12.0, 22.8, 3.4, [the order], [pass markers, log lines], [wrong wiring fails here])
  cdraw.content((11.5, 1.6), [zero sleeps: time is arithmetic on the counter], size: 6pt)
})

sources: learn.microsoft.com structured exception handling reference
pages for `__try` and `__except`, `GetExceptionCode`,
`GetExceptionInformation`, and `RaiseException`, the windows sockets
reference for `setsockopt` with `SO_RCVTIMEO` and `SO_SNDTIMEO`, and
the `SleepConditionVariableSRW` page again for the pool handoff,
all accessed 2026-09-27. The continuation-passing fold was checked
against the go book's chain type in `books/go/api/internal/middleware`
as a structural mirror only. Verified by the middleware tests in
`c-os-cloud/api/tests/test_middleware.c`, 18 checks over the fold,
the id rules, the exact log line, the raised-exception recovery, and
both sides of the deadline, under `make verify-capi`.
