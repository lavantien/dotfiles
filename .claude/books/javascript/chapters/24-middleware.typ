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

Cross-cutting behavior does not belong inside the handlers, and node
does not make anyone put it there. This chapter composes the service's
middleware stack over the previous chapter's kernel, in
`books/javascript/api/src/middleware/`: the chain type that folds
layers into one handler, the access log with its byte counting, the
handler deadline raced over an injected timer, the adapter that turns
exceptions into the contract envelope, and the wiring order that makes
the stack correct rather than merely present.

== the chain type

One layer is one function: given the next handler, return the handler
that wraps it. `chain` folds a list of layers by wrapping right to
left, so the first argument ends up outermost, sees the request first
and the response last, which is the onion picture every middleware
chapter draws because it is the true one. A chain is itself a layer,
so chains compose into bigger chains, and the kernel's `use` seam
appends onto the same fold, first used outermost:

#listing("javascript/api/src/middleware/chain.mjs", first: 5, last: 11, caption: [chain: one layer type, folded so the first argument is outermost])

The loop runs backwards for a reason worth saying out loud: folding
left to right would make the last layer outermost, and the wiring
order in this chapter's fifth section is a contract, not an accident.
A test pins it, asserting the pass order `outer, middle, inner,
handler` and the return order back out, from a context object the
layers share:

#diagram([the onion: first argument outermost, request in, response out], length: 13pt, {
  cdraw.rect((0.4, 4.6), (8.6, 8.0), fill: luma(235), radius: 0.05)
  cdraw.content((4.5, 7.5), [access log], size: 6pt)
  cdraw.rect((1.6, 5.6), (7.4, 7.0), fill: luma(228), radius: 0.05)
  cdraw.content((4.5, 6.3), [deadline], size: 6pt)
  cdraw.rect((2.8, 6.6), (6.2, 7.6), fill: luma(222), radius: 0.05)
  cdraw.content((4.5, 7.1), [adapter], size: 6pt)
  cdraw.content((4.5, 5.1), [router and handler], size: 6pt)
  cdraw.line((-0.6, 4.9), (0.2, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((-0.9, 5.5), [request], size: 6pt)
  cdraw.content((-0.9, 4.3), [falls in], size: 6pt)
  cdraw.line((8.8, 3.9), (9.6, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.6, 4.5), [response], size: 6pt)
  cdraw.content((10.6, 3.3), [climbs out], size: 6pt)
  pane(12.4, 22.8, 7.8, [the fold], [#"chain(a, b, c)(h): a wraps"], [b wraps c wraps h, first outer])
  pane(12.4, 22.8, 4.0, [on the app], [#"app.use(layer) appends"], [first used, outermost served])
})

== the access log

The access log writes one structured line per request: method, path,
the status the wire actually served, the byte count, the duration,
the request id. Node keeps the served status on the response object,
so the layer reads `res.statusCode` after the stack below answered,
and that difference from go is worth a sentence: go handlers write a
status the wrapper must intercept because nothing reports it back,
while node's response is a readable object. The double-write trap also
differs, and the probes on 26.3.0 say how: the first `writeHead`
commits immediately, a second throws `ERR_HTTP_HEADERS_SENT`, a
`statusCode` assignment after commit is a silent no-op, and a second
`end` before the stream finishes emits `ERR_STREAM_WRITE_AFTER_END`
asynchronously while one after `finish` is silently ignored. Loudness
varies trap by trap, so the capture happens after the answer, not
during it.

Byte counting wraps the `write` and `end` methods on the response
instance, holding the originals and restoring them in a `finally`
block, which is also what guarantees the line lands when the stack
below throws. The count is wire bytes, `Buffer.byteLength` on each
chunk, true for multi-byte bodies: a register whose display name is
all umlauts logs the same number the client measured, and the
regression test pins exactly that:

#listing("javascript/api/src/middleware/accesslog.mjs", first: 26, last: 38, caption: [counting wrappers on the instance, wire bytes, originals restored in the finally])

The sink is a dependency, one function per line, defaulting to a
hand-rolled JSON line on stdout because node ships no structured
logger and the ruling is zero packages. The clock is a dependency too,
so tests inject two timestamps and assert the exact `duration_ms`, and
`mock.fn` is the counting spy that proves one line per request:

#diagram([status read after the answer, bytes counted at the writes, one line per request], length: 13pt, {
  cdraw.rect((0.4, 3.6), (10.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 6.9), [access log layer], size: 6.5pt)
  cdraw.content((5.5, 5.9), [wraps write and end, counts bytes], size: 6pt)
  cdraw.content((5.5, 4.9), [reads statusCode after the answer], size: 6pt)
  cdraw.content((5.5, 3.9), [finally restores and logs], size: 6pt)
  let cell(xc, l1, l2, fill) = {
    cdraw.rect((xc - 2.9, 0.6), (xc + 2.9, 2.6), fill: fill, radius: 0.02)
    cdraw.content((xc, 2.0), [#l1], size: 6pt)
    cdraw.content((xc, 1.1), [#l2], size: 6pt)
  }
  cell(3.6, [second writeHead], [throws, loud], luma(225))
  cell(9.4, [statusCode late], [silent no-op], luma(205))
  cell(15.2, [second end], [emits or ignored], luma(215))
  cell(21.0, [the log line], [level, method, path], luma(235))
  cdraw.content((11.8, -0.4), [loud or silent per trap, the capture reads back], size: 6pt)
})

== the handler deadline

A service needs timeouts at two layers because the layers fail
differently. The transport layer is node's own server clock, probed
defaults on 26.3.0: `headersTimeout` 60 seconds, `requestTimeout` 300
seconds, `keepAliveTimeout` 5 seconds. These are coarse, they protect
the process from slow clients, and when one fires the connection just
dies, plain by design. The handler layer is finer: one request's
handler time, after which the client deserves the contract's
`overload` envelope rather than a dropped connection, and that is this
layer.

The mechanism is a race the language gives directly:
`Promise.race` between the handler's promise and a timer promise. The
handler wins, its answer stands and the unused timer is cleared. The
deadline wins, the layer answers the overload envelope and the
abandoned handler keeps running, its later writes refused by the
writers' already-answered guard from the kernel chapter, the cousin of
go's detached writer whose buffer is dropped. The abandoned handler's
failure is observed through a `catch` on the run promise, because an
unobserved rejection is an `unhandledRejection` and kills the process
no matter how late it lands:

#listing("javascript/api/src/middleware/deadline.mjs", first: 15, last: 29, caption: [the race: handler or timer, overload on expiry, the late failure observed])

#diagram([two clocks: transport deadlines kill connections, the handler deadline answers], length: 13pt, {
  cdraw.content((3.2, 8.1), [transport layer], size: 6.5pt)
  cdraw.line((0.6, 7.4), (12.2, 7.4), stroke: luma(120))
  cdraw.content((2.2, 6.8), [headers 60s], size: 6pt)
  cdraw.content((6.2, 6.8), [request 300s], size: 6pt)
  cdraw.content((10.4, 6.8), [keep-alive 5s], size: 6pt)
  cdraw.content((3.2, 5.6), [expiry drops the connection, plain], size: 6pt)
  cdraw.content((3.2, 4.5), [protects the process from slow clients], size: 6pt)
  cdraw.content((17.6, 8.1), [handler layer], size: 6.5pt)
  cdraw.rect((13.4, 4.4), (21.8, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.6, 5.9), [one request's handler], size: 6pt)
  cdraw.content((17.6, 5.0), [raced against the timer], size: 6pt)
  cdraw.line((17.6, 4.3), (17.6, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(13.4, 21.8, 3.6, [on expiry], [503 overload envelope], [late writes refused])
  cdraw.content((17.6, 0.2), [protects the client from a stuck handler], size: 6pt)
})

== the exception-to-envelope adapter

The kernel's backstop already converts any rejection that escapes the
stack. The adapter is the same conversion done properly, innermost,
with the log line the backstop cannot write: a thrown `ApiError`
renders as its own code, message, and status, and anything else
answers `internal` with the stack and the request id logged and the
detail kept off the wire. Known failures are not error-level noise, so
a 404 or a validation failure converts silently and only an unknown
exception produces an error line:

#listing("javascript/api/src/middleware/adapter.mjs", first: 10, last: 26, caption: [the adapter: known failures render, unknown ones log then render])

Placement carries one cross-language truth. The go lane had to put its
recover inside the timeout layer because a go panic never crosses a
goroutine boundary, and the timeout moved the handler onto another
goroutine. Node has no such rule: a rejection climbs the awaited chain
no matter which layer scheduled the work, so the adapter's innermost
position is about the deadline race, not about reachability. Innermost,
every handler failure settles the race as a resolved promise and the
deadline never answers over a failure the adapter already answered.
Go also rethrows one sentinel, `http.ErrAbortHandler`, the server's
own connection-drop signal, and node has no counterpart to rethrow:
socket teardown is not an exception here, so the adapter catches
everything:

#diagram([one path to the log, one to the envelope, nothing rethrown], length: 13pt, {
  pane(0.3, 7.0, 7.6, [handler throws], [#"fail(..) or new Error(..)"])
  cdraw.line((3.65, 5.5), (3.65, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 3.0), (7.0, 4.4), fill: luma(225), radius: 0.02)
  cdraw.content((3.65, 3.95), [the adapter's catch], size: 6pt)
  cdraw.content((3.65, 3.25), [instanceof ApiError splits the paths], size: 6pt)
  cdraw.line((7.2, 3.7), (8.2, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(8.4, 15.2, 5.4, [error line], [stack, request id], [unknown throws only])
  cdraw.line((15.4, 3.7), (16.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(16.6, 23.2, 5.4, [envelope], [its own code, or internal], [detail stays off the wire])
  cdraw.content((12.0, 0.9), [a rejection never crosses a goroutine in go, but it never needs to here], size: 6pt)
})

== wiring order and why

The order of the three layers is contract, and each position is a
sentence. The access log outermost, so it sees the answer everything
below produced: a recovered 500 is logged as the 500 the client saw,
not the status a wrapper never observed. The deadline inside the log,
so the envelope the deadline writes is also logged. The adapter
innermost, so the race always settles and handler failures never
become deadline failures. There is no request-id layer in this stack
because the kernel resolves the id at the edge, before any layer runs,
and the echo header is already set by then, so the stack starts at the
log. `wireMiddleware` is the family's one call in the composition
file, mounting the three layers in that order, with the operations
families' layers interleaved at their canonical positions through the
optional mounts:

#listing("javascript/api/src/middleware/wire-middleware.mjs", first: 13, last: 22, caption: [the wiring: log, deadline, adapter, the ch31-33 layers interleaved at their positions])

#diagram([wrong order versus right: where the log sits decides what it sees], length: 13pt, {
  cdraw.content((6.4, 8.2), [wrong: log inside the adapter], size: 6.5pt)
  cdraw.content((6.4, 7.5), [deadline, adapter, log, handler], size: 6pt)
  cdraw.content((6.4, 6.8), [the adapter answers above the log], size: 6pt)
  pane(0.4, 12.4, 5.4, [the log records], [no status at all], [the adapter answered first])
  pane(0.4, 12.4, 2.4, [the client sees], [500 internal], [from the adapter above])
  cdraw.line((12.6, 4.9), (13.4, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.4, 8.2), [right: log outside everything], size: 6.5pt)
  cdraw.content((18.4, 7.5), [log, deadline, adapter, handler], size: 6pt)
  cdraw.content((18.4, 6.8), [the log sees every answer below], size: 6pt)
  pane(12.6, 24.2, 5.4, [the log records], [status 500, the recovered], [envelope, request id and all])
  pane(12.6, 24.2, 2.4, [the client sees], [the same 500], [one answer, everywhere])
})

== testing middleware

Middleware tests run at two levels, and the clock discipline differs
at each. The layer level drives everything through `mock.timers`:
`enable` with the `setTimeout` api, `tick` to fire the deadline,
`reset` in a `finally`, and no test ever sleeps. The handler that must
not finish is a promise that never settles, the handler that finishes
late is held on a gate the test releases after the assertions, and the
late-failure test awaits the gate's rejection so nothing is left
dangling. The sink is `mock.fn`, the counting spy: zero calls asserted
on the quiet paths, exactly one line and its exact fields on the loud
ones.

The socket level exists because the wired stack should answer over the
wire once, and there the timer is a hand-rolled double injected
through the layer's dependency rather than mock.timers, because
mock.timers patches the global `setTimeout` and the fetch pipeline
shares that global. The test's double captures the deadline callback,
the handler signals when it is provably inside the route, and the test
fires the captured callback at that moment: deterministic, zero wall
time. The stack test is the one that fails when anyone reorders the
wiring, and it is the same test that proves log and envelope agree on
the request id:

#listing("javascript/api/test/middleware/stack.test.mjs", first: 23, last: 32, caption: [the stack test: the log saw the 500 the adapter answered])

#diagram([two clock styles: mock.timers at the layer, an injected double at the socket], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [enable, tick, reset], [mock.timers, layer level])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [gates hold handlers], [released after asserts])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [injected double], [the socket level fires it])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [no sleeps], [anywhere in the file])
  pane(0.3, 11.0, 3.4, [the sink], [mock.fn, counting spy], [zero calls, or exactly one])
  pane(12.0, 22.8, 3.4, [after() closes], [every server], [no orphans at exit])
})

sources: nodejs.org/api/test.html for the runner, mock.fn, and
mock.timers, nodejs.org/api/http.html for ServerResponse, the commit
semantics of writeHead and end, and the server timeout clocks, and
developer.mozilla.org for Promise.race and Function.prototype.apply,
all accessed 2026-09-26, with the writeHead, end, and timeout facts
probed on node 26.3.0 before being written here. Verified by
`books/javascript/api/test/middleware` tests, 16 of them, plus
node --test and prettier.
