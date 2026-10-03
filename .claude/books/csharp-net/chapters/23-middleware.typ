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

Cross-cutting behavior does not belong inside the handlers, and
aspnet does not make anyone put it there. This chapter composes the
service's middleware stack over the previous chapter's kernel, in
`CsharpBook.Api/Middleware`: the layer type that folds delegates into
one pipeline, exceptions into the contract envelope, request ids born
once and quoted everywhere, the access log with its status-capture
problem, the handler deadline on a linked token, and the wiring order
that makes the stack correct rather than merely present.

== the layer type

One layer is one function: given the next delegate, return the
delegate that wraps it. That is the whole `Layer` type, a delegate
from `RequestDelegate` to `RequestDelegate`, and it is the same shape
the framework's own `IApplicationBuilder` stores, so anything written
against it composes with anything else. `Chain.Compose` folds a list
of layers into one by wrapping right to left, so the first layer ends
up outermost: it sees the request first and the response last, the
onion picture every middleware chapter draws because it is the true
one. A composed chain is itself invocable, so chains compose into
bigger chains.

The loop runs backwards for a reason worth saying out loud: the
framework's own pipeline build is this fold, `builder.Build()` walks
the registered components in reverse and folds each over the next,
which is why middleware registered first runs first, and why the
composition root's list reads top to bottom as the request flows. The
stack test pins the order `id, log, timeout, exceptions, handler` and
a reorder anywhere fails it:

#listing("csharp-net/api/src/CsharpBook.Api/Middleware/Chain.cs", first: 20, last: 27, caption: [one layer is a function over the next delegate, the fold wraps the first outermost])

#diagram([the onion: first layer outermost, request in, response out], length: 13pt, {
  cdraw.rect((0.4, 4.6), (8.6, 8.0), fill: luma(235), radius: 0.05)
  cdraw.rect((1.6, 5.6), (7.4, 7.0), fill: luma(228), radius: 0.05)
  cdraw.content((4.5, 6.3), [access log], size: 6pt)
  cdraw.rect((2.8, 6.6), (6.2, 7.6), fill: luma(222), radius: 0.05)
  cdraw.content((4.5, 7.1), [deadline], size: 6pt)
  cdraw.rect((3.6, 7.4), (5.4, 8.4), fill: luma(215), radius: 0.05)
  cdraw.content((4.5, 7.9), [exceptions], size: 6pt)
  cdraw.content((4.5, 5.1), [handler], size: 6pt)
  cdraw.line((-0.6, 4.9), (0.2, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((-0.9, 5.5), [request], size: 6pt)
  cdraw.line((8.8, 3.9), (9.6, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.6, 4.5), [response], size: 6pt)
  pane(12.4, 22.8, 7.8, [the fold], [#"Compose(a, b, c)(h)"], [a wraps b wraps c wraps h])
  pane(12.4, 22.8, 4.0, [in the root], [the build folds in reverse])
})

== exception to envelope

A throwing handler must not take the process down, and the client
must still get the contract envelope, and a bare delegate pipeline
promises neither on its own. The exception layer wraps `next` in one
`try`: an `ApiError` renders as its own code, message, and status
through the kernel's one failure shape, and anything else is answered
as `internal` with the detail kept for the logs, because a leaked
store exception tells a client more than it should know. This layer is
the adapter the kernel chapter deferred, go's error-returning handler
contract transposed into the exception channel.

Two rethrows are deliberate. `OperationCanceledException` while the
request's abort token is canceled means the client is gone, the
server will drop the connection, and writing a 500 nobody reads would
log a lie, so it propagates untouched, the aspnet counterpart of go's
rethrown `ErrAbortHandler`. The same filter covers a cancellation
raised by the deadline layer's linked token, so an abandoned pipeline
never answers over the deadline's envelope. And a failure after the
response started cannot be answered at all: half a body is already on
the wire, the platform's own guidance says headers and status are
immutable once the body has begun, so that exception is logged and
rethrown, the one case where the envelope stays unwritten:

#listing("csharp-net/api/src/CsharpBook.Api/Middleware/ExceptionMiddleware.cs", first: 29, last: 42, caption: [ApiError renders, cancellation rethrows, a started response is left alone])

#diagram([one throw, four paths: envelope, rethrow, rethrow, log and rethrow], length: 13pt, {
  pane(0.3, 7.0, 7.6, [the inner pipeline], [#"ApiError, unknown, cancel,"], [#"or mid-stream"])
  cdraw.line((3.65, 5.5), (3.65, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 3.0), (7.0, 4.4), fill: luma(225), radius: 0.02)
  cdraw.content((3.65, 3.95), [the one try], size: 6pt)
  cdraw.content((3.65, 3.25), [filters in catch order], size: 6pt)
  cdraw.line((7.2, 3.7), (8.2, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(8.4, 15.2, 5.4, [ApiError], [envelope at its status])
  cdraw.line((15.4, 3.7), (16.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(16.6, 23.2, 5.4, [unknown], [logged, answered internal])
})

== request id

Every request needs one id that every artifact agrees on: the access
log line, the error envelope, the exception log, and later the trace.
The layer resolves it exactly once, at the edge, using the kernel's
`RequestId.Resolve` order: the stored value when some layer already
installed one, else the client's `X-Request-ID` when it parses as a
guid, else a fresh version 7 guid. Parsing is not politeness, it is
contract: the envelope promises `request_id` is a guid, and a
client-supplied free-text header echoed into logs is log injection.
Garbage is replaced, never echoed, and the version 7 choice keeps ids
time-ordered the way the store chapter's ids are.

The layer then does two small things with the value: it sets the
response header, so a client correlates its own logs with the
server's, and it installs the id in `HttpContext.Items` through the
kernel's `RequestId.Set`, so everything downstream resolves one value
without touching headers again. The tests check all three births: a
client guid echoes, garbage becomes a fresh version 7, and a handler
that wipes the incoming header still resolves the stored id:

#listing("csharp-net/api/src/CsharpBook.Api/Middleware/RequestIdMiddleware.cs", first: 15, last: 21, caption: [resolve once at the edge, echo it, store it for downstream])

#diagram([one id, born at the edge, quoted by everything downstream], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [request arrives], [with or without an id])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [the edge resolves], [header guid or new v7])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [header plus items], [one value, two surfaces])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [downstream], [handler, log, envelope])
  pane(0.3, 8.8, 3.4, [access log], [request id value], [stable across retries])
  pane(9.9, 18.4, 3.4, [error envelope], [#"request_id member"], [a guid, always])
  pane(0.3, 8.8, 0.6, [exception log], [the same value, garbage replaced])
})

== the access log

Handlers set a status and never return it, and a layer that wants to
log what actually went out has to watch it go. AspNet answers the
go chapter's status-capturing writer differently: `HttpResponse`
exposes `StatusCode` as a readable property, so no wrapper is needed
to learn the status, and the load-bearing question is when to read
it. The log layer registers a witness through `OnStarting`, the
platform's hook for work that must run just before headers flush, and
the callback snapshots the status at the exact moment of commit. The
documentation calls that callback the last chance to modify headers,
status, and reason phrase, which also makes it the only truthful
witness of the status the client saw, and registering it after the
response started throws, so the layer guards on `HasStarted` first.
When no commit ever happens, a unit context with no server, the log
falls back to the final property, and both paths are pinned by tests.

Bytes are counted by wrapping the body stream in a `CountingStream`
installed before the inner pipeline runs and removed after it
returns, the one place every byte of the body flows through in this
stack. The line written afterwards carries method, path, status,
bytes, duration, and request id, with the duration measured off the
injected `TimeProvider`, never a wall clock. The write happens in a
`finally`, so a handler that throws is still logged, the fact the
wiring order section depends on:

#listing("csharp-net/api/src/CsharpBook.Api/Middleware/AccessLogMiddleware.cs", first: 31, last: 47, caption: [the witness at commit, the counting wrap, before the inner pipeline runs])

#diagram([status read at commit through OnStarting, bytes counted at the body], length: 13pt, {
  cdraw.rect((0.4, 3.6), (10.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 6.9), [the log layer], size: 6.5pt)
  cdraw.content((5.5, 5.9), [registers the witness], size: 6pt)
  cdraw.content((5.5, 4.9), [wraps the body stream], size: 6pt)
  cdraw.content((5.5, 3.9), [logs in a finally], size: 6pt)
  let cell(xc, l1, l2, fill) = {
    cdraw.rect((xc - 2.9, 0.6), (xc + 2.9, 2.6), fill: fill, radius: 0.02)
    cdraw.content((xc, 2.0), [#l1], size: 6pt)
    cdraw.content((xc, 1.1), [#l2], size: 6pt)
  }
  cell(3.6, [OnStarting], [status at commit], luma(225))
  cell(9.4, [HasStarted], [guards the register], luma(225))
  cell(15.2, [CountingStream], [bytes through the body], luma(225))
  cell(21.0, [TimeProvider], [duration, no clock], luma(225))
})

== the handler deadline

A service needs a deadline at two layers because the two layers fail
differently. The transport layer is the server's own configuration,
kestrel's keep-alive and header timeouts, coarse knobs that protect
the process from slow clients and drop the connection when they fire.
The handler layer is finer, one request's pipeline time, after which
the client deserves the contract's `overload` envelope rather than a
dropped connection, and that is a middleware.

The deadline layer builds a `CancellationTokenSource` linked to the
request's abort token and replaces `context.RequestAborted` with the
linked token, so a well-behaved handler observes the deadline the same
way it observes a client leaving. A timer from `TimeProvider.CreateTimer`,
one callback, one due time, signals a completion source, and the layer
awaits the race and then resolves it on the facts, not the winner: a
pipeline that ran to completion passes its response through untouched,
a fault with the deadline unfired propagates to the layers outside,
and everything else is expiry, because the linked token's cancellation
can tear the pipeline down before the signal task is observed and the
deadline firing is the truth either way. The expiry path answers the
envelope only when the response never started and the original client
token is still alive, because a client that left has nobody to read a
body. The abandoned pipeline keeps running against the canceled token,
and its eventual fault is observed by a continuation that logs it with
the request id when it is not the expected cancellation, never left
unobserved. The clock comes from `TimeProvider` throughout, which is
why the tests drive expiry by stepping a fake clock, no sleeps
anywhere:

#listing("csharp-net/api/src/CsharpBook.Api/Middleware/TimeoutMiddleware.cs", first: 43, last: 78, caption: [the race resolved: success passes through, a fault without the deadline propagates, the fact read from the linked source, the cancel fenced against a source the success path already disposed])

#diagram([two clocks: transport deadlines drop connections, the handler deadline answers], length: 13pt, {
  cdraw.content((3.2, 8.1), [transport layer], size: 6.5pt)
  cdraw.line((0.6, 7.4), (12.2, 7.4), stroke: luma(120))
  cdraw.content((3.2, 4.5), [limits, expiry drops the connection], size: 6pt)
  cdraw.content((17.6, 8.1), [handler layer], size: 6.5pt)
  cdraw.rect((13.4, 4.4), (21.8, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.6, 5.9), [one request's pipeline], size: 6pt)
  cdraw.content((17.6, 5.0), [timer from TimeProvider], size: 6pt)
  cdraw.line((17.6, 4.3), (17.6, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(13.4, 21.8, 3.6, [on expiry], [503 overload envelope], [abandoned pipeline logged])
  cdraw.content((17.6, 0.2), [protects the client from a stuck handler], size: 6pt)
})

== wiring order and why

The order of the four layers is contract, and each position is a
sentence. Request id outermost, because every other artifact quotes
it: the access log value, the exception log, the envelope, all of it.
Access log second, outside the exception layer, so a converted 500 is
logged as the 500 the client saw rather than a status a wrapper never
observed, and because the log line lives in a finally, the request
that throws is still logged. Deadline third. Exceptions innermost,
and this one is worth the argument: aspnet's conventional placement
for an exception handler is outermost, first registered, so it catches
failures from every layer including the middleware itself, but this
stack's deadline does not move the pipeline onto another thread the
way go's timeout moved its handler onto another goroutine, so an
inner placement catches everything the handlers throw, and the log
sees the answer it wrote. The go chapter's mechanical goroutine rule
and this lane's log-visibility rule land on the same order:

#listing("csharp-net/api/src/CsharpBook.Api/Deploy/Wire.cs", first: 84, last: 93, caption: [the four ch23 lines in the shipped stack, outermost first, later families interleaved between them])

#diagram([wrong order versus right: where the log sits decides what it sees], length: 13pt, {
  cdraw.content((6.4, 8.2), [wrong: log inside exceptions], size: 6.5pt)
  cdraw.content((6.4, 7.5), [id, deadline, exceptions, log, handler], size: 6pt)
  pane(0.4, 12.4, 5.4, [the log records], [nothing, the throw], [unwinds past it])
  cdraw.line((12.6, 4.9), (13.4, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.4, 8.2), [right: log outside exceptions], size: 6.5pt)
  cdraw.content((18.4, 7.5), [id, log, deadline, exceptions, handler], size: 6pt)
  cdraw.content((18.4, 6.8), [the catch answers inside, the log sees it], size: 6pt)
  pane(12.6, 24.2, 5.4, [the log records], [status 500, the envelope,], [request id and all])
  pane(12.6, 24.2, 2.4, [the client sees], [the same 500], [one answer, everywhere])
})

== testing the stack

Middleware is tested like handlers, mostly. The fast paths run through
`DefaultHttpContext`, the unit recorder from the kernel chapter, with
each layer constructed directly over a tiny handler and every
dependency injected: a recording logger asserts on the structured
values that were logged, never on console output, and a stepped
`TimeProvider` moves time only when the test says so, its timers
firing synchronously inside `Advance`. The blocking path is the
addition: a handler that never returns until its token cancels, an
infinite delay with no wall clock, and the test steps the fake clock
past the budget, awaits the middleware, and joins the abandoned
pipeline back through a completion source the way the go chapter
joins its abandoned goroutine through a channel. The client-gone path
needs no clock at all: a pre-canceled request token distinguishes a
client leaving from a deadline expiring with zero timing dependence.

The stepped provider is hand-rolled on purpose. The platform ships
`Microsoft.Extensions.TimeProvider.Testing` with its own
`FakeTimeProvider`, a Microsoft-official package that is this same
fake, and the vehicle declines it for the same reason it declines
assertion libraries: the fake is a hundred and forty lines, the learning is in those
lines, and a test project that stays dependency-free is one whose
doubles can be read in a sitting. The stack test at the end composes
all four layers over a throwing handler and asserts the property the
whole chapter exists to keep: the log and the envelope agree on the
500, and both quote the id the edge resolved:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Middleware/StackTests.cs", first: 128, last: 141, caption: [the stack test: log and envelope agree on the 500 and the id])

#diagram([the harness: gates hold handlers, clocks step, channels join], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [handler blocked], [#"infinite delay on the token"])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [clock steps], [#"Advance past the budget"])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [the envelope answers], [503 overload, no sleep])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [assert, then join], [completion source])
  pane(0.3, 11.0, 3.4, [fast paths], [recorder, recording logger])
  pane(12.0, 22.8, 3.4, [the doubles], [stepped clock, pinned feature], [client gone: no clock])
})

sources: learn.microsoft.com/aspnet/core/fundamentals/middleware for
the pipeline and order rules, learn.microsoft.com/aspnet/core/
fundamentals/routing for the UseRouting placement, the best-practices
page and learn.microsoft.com/dotnet/api/microsoft.aspnetcore.http.
httpresponse.onstarting for the HasStarted guard and the commit
callback, and learn.microsoft.com/dotnet/api/system.timeprovider.
createtimer for the timer surface, all accessed 2026-09-26. Verified
by `CsharpBook.Api.Tests.Middleware` under `dotnet test Api.slnx`, 22
tests beside the kernel suite, plus dotnet build and dotnet format.
