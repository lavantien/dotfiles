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

Cross-cutting behavior does not belong inside the handlers, and go
does not make anyone put it there. This chapter composes the service's
middleware stack over the previous chapter's kernel, in
`goapi/internal/middleware`: the chain type that folds layers into
one handler, panic recovery into the contract envelope, request ids
born once and quoted everywhere, the access log with its
status-capturing writer, timeouts at two layers, and the wiring order
that makes the whole stack correct rather than merely present.

== the chain type

One layer is one function: given the next handler, return the handler
that wraps it. That is the whole `Func` type, and it is the same shape
the standard library's own middleware uses, so anything written
against it composes with anything else. `Chain` folds a list of layers
into one by wrapping right to left, so the first argument ends up
outermost: it sees the request first and the response last, which is
the onion picture every middleware chapter draws because it is the
true one. A chain is itself a `Func`, so chains compose into bigger
chains, and the kernel's `App.Use` appends onto the same fold, first
used outermost.

The loop runs backwards for a reason worth saying out loud: folding
left to right would make the last layer outermost, and the wiring
order in this chapter's sixth section is a contract, not an accident.
A test pins it, asserting the pass order `outer,middle,inner,handler`
from a recorder:

#listing("go/api/internal/middleware/chain.go", first: 11, last: 25, caption: [Func is one layer, Chain folds them outermost first])

#diagram([the onion: first argument outermost, request in, response out], length: 13pt, {
  cdraw.rect((0.4, 4.6), (8.6, 8.0), fill: luma(235), radius: 0.05)
  cdraw.content((4.5, 7.5), [request id], size: 6pt)
  cdraw.rect((1.6, 5.6), (7.4, 7.0), fill: luma(228), radius: 0.05)
  cdraw.content((4.5, 6.3), [access log], size: 6pt)
  cdraw.rect((2.8, 6.6), (6.2, 7.6), fill: luma(222), radius: 0.05)
  cdraw.content((4.5, 7.1), [timeout], size: 6pt)
  cdraw.rect((3.6, 7.4), (5.4, 8.4), fill: luma(215), radius: 0.05)
  cdraw.content((4.5, 7.9), [recover], size: 6pt)
  cdraw.content((4.5, 5.1), [handler], size: 6pt)
  cdraw.line((-0.6, 4.9), (0.2, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((-0.9, 5.5), [request], size: 6pt)
  cdraw.content((-0.9, 4.3), [falls in], size: 6pt)
  cdraw.line((8.8, 3.9), (9.6, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.6, 4.5), [response], size: 6pt)
  cdraw.content((10.6, 3.3), [climbs out], size: 6pt)
  pane(12.4, 22.8, 7.8, [the fold], [Chain(a, b, c)(h): a wraps], [b wraps c wraps h, first is outer])
  pane(12.4, 22.8, 4.0, [on the app], [#"app.Use(layer) appends"], [first used, outermost served])
})

== recover

A panicking handler must not take the process down, and the client
must still get the contract envelope, and a bare `http.Handler` has
no way to promise either on its own. The recover layer installs one
deferred function: if the handler returns normally the deferred call
sees a nil recover and costs nothing, if it panics the layer logs the
value and the stack with the request id and answers 500 `internal`
through the kernel's one failure writer, so the shape on the wire is
the envelope even for the failures nobody planned.

One panic is deliberately let through. `http.ErrAbortHandler` is the
server's own signal, the sentinel a handler panics with to make the
connection drop, and a middleware that converts it into a 500 changes
what the server was told to do. The layer rethrows it verbatim, and
the test for that asserts the exact sentinel crosses the boundary.
The other rule is placement: a `recover` only sees panics on its own
goroutine, and this stack's timeout layer moves the handler onto
another goroutine, so recover sits inside it, innermost, a
restriction the sixth section turns into the wiring order:

#listing("go/api/internal/middleware/recover.go", first: 18, last: 38, caption: [recover: nil costs nothing, abort rethrows, the rest becomes the envelope])

#diagram([panic unwind: one path to the log, one to the envelope, one rethrown], length: 13pt, {
  pane(0.3, 7.0, 7.6, [handler panics], [#"panic(\"boom\") or"], [#"http.ErrAbortHandler"])
  cdraw.line((3.65, 5.5), (3.65, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 3.0), (7.0, 4.4), fill: luma(225), radius: 0.02)
  cdraw.content((3.65, 3.95), [deferred recover], size: 6pt)
  cdraw.content((3.65, 3.25), [same goroutine or never], size: 6pt)
  cdraw.line((7.2, 3.7), (8.2, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(8.4, 15.2, 5.4, [log], [stack, request id], [panic value])
  cdraw.line((15.4, 3.7), (16.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(16.6, 23.2, 5.4, [envelope], [500 internal,], [message hidden])
  cdraw.line((3.65, 2.8), (3.65, 1.9), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 7.0, 1.6, [rethrown], [ErrAbortHandler], [drops the connection])
  cdraw.content((15.0, 0.5), [the double-write trap cannot fire here: a panicking handler wrote nothing], size: 6pt)
})

== request-id

Every request needs one id that every artifact agrees on: the access
log line, the error envelope, the panic log, and later the trace. The
layer resolves it exactly once, at the edge, using the kernel's
`RequestID` order: the context value if some outer layer already set
one, else the client's `X-Request-ID` when it parses as a uuid, else a
fresh uuid v7. Parsing is not politeness, it is contract: the envelope
promises `request_id` is a uuid, and a client-supplied free-text
header echoed into logs is log injection. Garbage is replaced, not
echoed, and the v7 choice keeps ids time-ordered the way the store
chapter's ids are.

The layer then does two small things with the value: it sets the
response header, so a client can correlate its own logs with the
server's, and it installs the id in the request context with the
kernel's `WithRequestID`, so everything downstream reads one value
without touching headers again. The test for it checks all three
births: a client uuid echoes, garbage does not, and the envelope
written far downstream carries the id the edge resolved:

#listing("go/api/internal/middleware/requestid.go", first: 9, last: 21, caption: [resolve once at the edge, echo it, put it in the context])

#diagram([one id, born at the edge, quoted by everything downstream], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [request arrives], [with or without an id])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [the edge resolves], [header uuid or new v7])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [context plus header], [one value, two surfaces])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [downstream], [handler, logs, envelope])
  pane(0.3, 8.8, 3.4, [access log], [request_id attr], [stable across retries])
  pane(9.9, 18.4, 3.4, [error envelope], [#"request_id member"], [a uuid, always])
  pane(0.3, 8.8, 0.6, [panic log], [#"request_id attr"], [same value])
  cdraw.content((15.9, -0.6), [garbage headers are replaced, never echoed], size: 6pt)
})

== the access log

Handlers write a status and never return it, so a middleware that
wants to log what actually went out has to watch it go. The access log
wraps the `ResponseWriter` in a `statusWriter` that records the first
status and counts body bytes, then writes one `slog` line after the
handler returns: method, path, status, bytes, duration, request id.
First status is the load-bearing phrase, because the double
`WriteHeader` trap is real: a handler that writes 201 then 500 has
already committed 201, the server logs a superfluous-write warning,
and a logger that recorded the second call would report a status the
client never saw. The wrapper applies the same first-wins rule the
wire does, and a body write with no explicit status counts as an
implicit 200, exactly as the server itself treats it.

Wrapping a `ResponseWriter` has a second, quieter cost: the wrapper is
a new type, and the type assertions that power the optional interfaces
now fail. `Flush` is forwarded by hand and `Unwrap` lets
`http.NewResponseController` walk to the real writer, which is the
modern fix. `Hijacker` and `io.ReaderFrom` are not forwarded here, and
prose says so honestly: a stack that needs websockets or sendfile must
forward them or use `ResponseController` throughout:

#listing("go/api/internal/middleware/accesslog.go", first: 38, last: 58, caption: [the status-capturing writer: first status wins, bytes counted])

#diagram([the wrapper forwards what it names, loses what it does not], length: 13pt, {
  cdraw.rect((0.4, 3.6), (10.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 6.9), [statusWriter], size: 6.5pt)
  cdraw.content((5.5, 5.9), [embeds ResponseWriter], size: 6pt)
  cdraw.content((5.5, 4.9), [records status, counts bytes], size: 6pt)
  cdraw.content((5.5, 3.9), [first WriteHeader wins], size: 6pt)
  let cell(xc, l1, l2, fill) = {
    cdraw.rect((xc - 2.9, 0.6), (xc + 2.9, 2.6), fill: fill, radius: 0.02)
    cdraw.content((xc, 2.0), [#l1], size: 6pt)
    cdraw.content((xc, 1.1), [#l2], size: 6pt)
  }
  cell(3.6, [Flush], [forwarded by hand], luma(225))
  cell(9.4, [Unwrap], [ResponseController walks it], luma(225))
  cell(15.2, [Hijacker], [lost, websockets need it], luma(205))
  cell(21.0, [ReaderFrom], [lost, sendfile needs it], luma(205))
  cdraw.content((11.8, -0.4), [a wrapper that forwards nothing silently breaks streaming], size: 6pt)
})

== timeouts at two layers

A service needs timeouts at two layers because the two layers fail
differently. The transport layer is the `http.Server`'s own clock:
`ReadHeaderTimeout` bounds how long a client may take to finish
sending headers, `ReadTimeout` the request including its body,
`WriteTimeout` the response, `IdleTimeout` a kept-alive connection.
These are coarse, they protect the process from slow clients, and when
one fires the connection just dies, plain by design. The handler layer
is finer: one request's handler time, after which the client deserves
the contract's `overload` envelope rather than a dropped connection,
and that is a middleware.

The standard `http.TimeoutHandler` already bounds handler time and is
the right answer when plain text is acceptable, but its expiry body is
a bare message string, and this api's every non-2xx is the envelope,
so the layer is hand-rolled on the same skeleton the standard one
uses. The handler runs on a new goroutine with a deadline context and
a `detachedWriter`: its own header map, status, and body buffer, with
a mutex so a handler that outlives its deadline races against nothing.
The outer select waits on the handler's return or the context: on
return the captured response commits to the real writer untouched, on
deadline expiry the envelope answers and the abandoned handler's
buffer is dropped unread, and on a canceled parent, a client that
left, nothing is written at all because there is no one to read it:

#listing("go/api/internal/middleware/timeout.go", first: 20, last: 44, caption: [the handler deadline: detached writer, envelope on expiry, silence on cancel])

#diagram([two clocks: transport deadlines kill connections, the handler deadline answers], length: 13pt, {
  cdraw.content((3.2, 8.1), [transport layer], size: 6.5pt)
  cdraw.line((0.6, 7.4), (12.2, 7.4), stroke: luma(120))
  cdraw.content((2.2, 6.8), [headers], size: 6pt)
  cdraw.content((5.8, 6.8), [body], size: 6pt)
  cdraw.content((10.4, 6.8), [response], size: 6pt)
  cdraw.line((3.6, 6.1), (3.6, 5.7), stroke: luma(100))
  cdraw.content((3.6, 5.1), [ReadHeaderTimeout], size: 6pt)
  cdraw.line((7.9, 6.1), (7.9, 5.7), stroke: luma(100))
  cdraw.content((7.9, 5.1), [ReadTimeout], size: 6pt)
  cdraw.line((11.6, 6.1), (11.6, 5.7), stroke: luma(100))
  cdraw.content((11.6, 5.1), [WriteTimeout], size: 6pt)
  cdraw.content((3.2, 3.9), [expiry drops the connection, plain], size: 6pt)
  cdraw.content((3.2, 2.8), [protects the process from slow clients], size: 6pt)
  cdraw.content((17.6, 8.1), [handler layer], size: 6.5pt)
  cdraw.rect((13.4, 4.4), (21.8, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.6, 5.9), [one request's handler], size: 6pt)
  cdraw.content((17.6, 5.0), [deadline from the middleware], size: 6pt)
  cdraw.line((17.6, 4.3), (17.6, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(13.4, 21.8, 3.6, [on expiry], [503 overload envelope], [late writes dropped])
  cdraw.content((17.6, 0.2), [protects the client from a stuck handler], size: 6pt)
})

== wiring order and why

The order of the four layers is contract, and each position is a
sentence. Request id outermost, because every other artifact quotes
it: the access log attribute, the panic log, the envelope, all of it.
Access log second, outside recovery, so a recovered 500 is logged as
the 500 the client saw rather than the 200 a wrapper never observed.
Timeout third. Recover innermost, and this one is mechanical rather
than aesthetic: the timeout layer runs the handler on another
goroutine, and a panic never crosses a goroutine boundary, so a
recover placed outside the timeout would not catch the handler's
panic, the process would die, and the whole point of the layer would
be gone. The wiring applied by the integrator lives in the program's
append-only table, `cmd/api/wire.go`, and reads top to bottom as the
request flows:

#snippet("log := slog.New(slog.NewJSONHandler(os.Stdout, nil))\napp.Use(middleware.RequestID())\napp.Use(middleware.AccessLog(log))\napp.Use(middleware.Timeout(5 * time.Second))\napp.Use(middleware.Recover(log))", lang: "go")

#diagram([wrong order versus right: where the log sits decides what it sees], length: 13pt, {
  cdraw.content((6.4, 8.2), [wrong: log inside recover], size: 6.5pt)
  cdraw.content((6.4, 7.5), [id, timeout, recover, log, handler], size: 6pt)
  cdraw.content((6.4, 6.8), [panic unwinds past the log first], size: 6pt)
  pane(0.4, 12.4, 5.4, [the log records], [status 0, or the 200], [a fresh wrapper held])
  pane(0.4, 12.4, 2.4, [the client sees], [500 internal], [from the recover outside])
  cdraw.content((6.4, 1.1), [two answers for one request], size: 6pt)
  cdraw.line((12.6, 4.9), (13.4, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.4, 8.2), [right: log outside recover], size: 6.5pt)
  cdraw.content((18.4, 7.5), [id, log, timeout, recover, handler], size: 6pt)
  cdraw.content((18.4, 6.8), [recover answers inside, log sees the answer], size: 6pt)
  pane(12.6, 24.2, 5.4, [the log records], [status 500, the recovered], [envelope, request id and all])
  pane(12.6, 24.2, 2.4, [the client sees], [the same 500], [one answer, everywhere])
  cdraw.content((18.4, 1.1), [and recover inside timeout: panics stay on their goroutine], size: 6pt)
})

== testing middleware

Middleware is tested like handlers, mostly. The fast paths go through
the recorder exactly as the kernel chapter's tests do: serve a layer
wrapped around a tiny handler, read back the status, the headers, the
body, and for the logging layers the captured `slog` text, one buffer
per assertion. The blocking paths are the addition: a layer whose
handler never returns cannot be tested through a function call that
never returns, so the timeout tests use a real `httptest.NewServer`
with a channel-gated handler, the gate held closed while the client
blocks on its request, closed after the assertions so the abandoned
goroutine can finish and join the test through a second channel. The
client-gone path needs no server at all: a request built with an
already-canceled context distinguishes a client leaving from a
deadline expiring without any timing dependence.

Nothing sleeps. The deadline fires because the test waits on the
response, not on the clock, the race detector runs over the whole
package because this is the module's first genuinely concurrent code,
and the stack test at the end is the one that fails when anyone
reorders the wiring, which is the property the whole chapter exists to
keep:

#listing("go/api/internal/middleware/middleware_test.go", first: 245, last: 269, caption: [the stack test: wrong order fails here, log and envelope agree on the 500])

#diagram([the harness: gates hold handlers closed, channels join them back], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [gate held], [handler blocked, no clock])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [client blocks], [on the response, not sleep])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [deadline answers], [the envelope, 503 overload])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [assert, then open], [close gate, join returned])
  pane(0.3, 11.0, 3.4, [fast paths], [recorder, captured slog])
  pane(12.0, 22.8, 3.4, [the gates], [#"close(gate), <-returned"], [no goroutine outlives the test])
  cdraw.content((11.5, 1.6), [the race detector runs the whole package], size: 6pt)
  cdraw.content((11.5, 0.5), [the client-gone case: pre-canceled context, no server], size: 6pt)
})

sources: pkg.go.dev for net/http, TimeoutHandler, ResponseController,
log/slog, and net/http/httptest, accessed 2026-09-25, with the
transport timeout semantics and the goroutine-local rule for recover
read from the go 1.27 source in GOROOT. Verified by
`go/api/internal/middleware` tests, 12 of them, under
`go test -race`, plus gofmt and go vet over the module.
