#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= middleware

Cross-cutting behavior does not belong inside the handlers, and the
stdlib does not make anyone put it there. This chapter composes the
service's middleware stack over the previous chapter's kernel, in
`pyapi/middleware.py`: the chain fold over the kernel's handler
shape, request ids born once at the edge, the access log over the
injected clock with its hand rolled json log handler, the deadline
as a worker thread plus an event wait, recover into the contract
envelope, and the wiring order that makes the stack correct rather
than merely present.

== the chain over the kernel's shape

The kernel's handler shape is one function, a `Request` in and a
`Response` out, and one layer is one function over exactly that:
given the next handler, return the handler that wraps it. `chain`
folds a list of layers into one by wrapping right to left, so the
first argument ends up outermost, it sees the request first and the
response last, the onion picture every middleware chapter draws
because it is the true one. A chain is itself a layer, so chains
compose into bigger chains, and the kernel's `App.use` appends onto
the same fold, first used outermost:

#listing("python/api/pyapi/middleware.py", first: 50, last: 60, caption: [one layer is a function over the next handler, the fold serves the first argument outermost])

The loop runs backwards for a reason worth saying out loud: folding
left to right would make the last layer outermost, and the wiring
order in this chapter's sixth section is a contract. A test pins
the fold directly, three recording layers around a terminal handler
assert the pass order `outer`, `inner`, `handler`, and a second
test nests one chain inside another to show composition:

#diagram([the onion: first argument outermost, request in, response out], length: 13pt, {
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
  cdraw.line((8.8, 3.9), (9.6, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.6, 4.5), [response], size: 6pt)
  pane(12.4, 22.8, 7.8, [the fold], [chain(a, b, c)(h): a wraps], [b wraps c wraps h, first is outer])
})

== recover

An exception out of a handler must not take the process down, and
the client must still get the contract envelope. The recover layer
is one `try` around the inner call: an `Exception` becomes one
error log line with the request id, the exception repr, and the
full traceback, then the internal envelope through the kernel's one
failure writer, with a generic message, because a leaked
`sqlite3.OperationalError` tells a client more than it should know.
The go lane had two failure channels, returned errors and panics,
where python has one, the exception, and the class does the split:
`APIError` is the handled failure the kernel already renders,
everything else is a bug, and this layer is where bugs become
answers:

#listing("python/api/pyapi/middleware.py", first: 163, last: 180, caption: [recover: signals rethrow, bugs become the envelope with the detail kept for the log])

Two exceptions are deliberately let through. `KeyboardInterrupt` is
the interpreter's own signal and `SystemExit` is a request to exit
the process, the closest stdlib kin of the go lane's
`ErrAbortHandler` sentinel, and middleware that converts either into
a 500 changes what the platform was told to do. The `except` clause
lists both without parentheses, a spelling python 3.14 allows for
the first time when the clause carries no `as`, and the pinned
interpreter accepts it while the format gate enforces it. Placement
is the one real rule: recover sits innermost, inside the deadline,
so a bug becomes a response on the worker thread and flows back
through the deadline's box as a value.

#diagram([bug unwind: one path to the log, one to the envelope, signals rethrown], length: 13pt, {
  pane(0.3, 7.0, 7.6, [handler raises], [#"RuntimeError(\"bug\") or"], [#"KeyboardInterrupt"])
  cdraw.line((3.65, 5.5), (3.65, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 3.0), (7.0, 4.4), fill: luma(225), radius: 0.02)
  cdraw.content((3.65, 3.95), [the recover try], size: 6pt)
  cdraw.content((3.65, 3.25), [#"except Exception"], size: 6pt)
  cdraw.line((7.2, 3.7), (8.2, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(8.4, 15.2, 5.4, [log], [id, repr, traceback], [one error line])
  cdraw.line((15.4, 3.7), (16.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(16.6, 23.2, 5.4, [envelope], [500 internal,], [message hidden])
  pane(0.3, 7.0, 1.6, [rethrown], [KeyboardInterrupt,], [SystemExit])
})

== request id at the edge

Every request needs one id that every artifact agrees on, and this
layer is where it is born. Resolution is the kernel's order from the
previous chapter, the contextvar when set, else a client header that
parses as a uuid, else the mint, and the layer is the only writer:
it resolves once, echoes the id on the response header so a client
can correlate its own logs with the server's, and installs it in the
contextvar so everything downstream reads one value without touching
headers again. The reset is the hygiene half, the `finally` block
returns the token before the layer returns, so no id leaks onto the
next request the serving thread handles:

#listing("python/api/pyapi/middleware.py", first: 63, last: 82, caption: [resolve once at the edge, echo it, set the contextvar, reset in finally])

The mint is a factory parameter, and that is the vector seam: the
replay chapters inject their fixed ids by passing a callable here,
never by reaching into the kernel. The tests check all three
births, a client uuid echoes, garbage is replaced by the injected
mint rather than passed through, an absent header mints, and the
downstream envelope quotes whatever the edge resolved, which is the
property the whole stack depends on.

#diagram([one id, born at the edge, quoted by everything downstream], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [request arrives], [with or without an id])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [the edge resolves], [header uuid or the mint])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [contextvar set], [try, finally, token reset])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [downstream], [log, envelope, handler])
  pane(9.9, 18.4, 3.4, [the response], [#"X-Request-ID header"], [a uuid, always])
})

== the access log

Go's access log had to wrap the `ResponseWriter` and capture the
first status, because a go handler writes a response to a stream and
returns nothing. This kernel's handler returns the response as a
value, and that difference deletes the whole problem class: the log
layer calls the inner stack, holds the `Response` it gets back, and
reads `status` and the body length straight off it, so the line says
exactly what went on the wire, there is no first-write rule to get
wrong, and no optional interface silently lost to a wrapper. The one
cost is ordering, the line is written after the inner stack returns,
which is precisely what makes a recovered 500 loggable as a 500:

#listing("python/api/pyapi/middleware.py", first: 93, last: 108, caption: [the response is a value: the log reads status and bytes straight off it])

The duration comes from the injected clock, `monotonic` by default,
called once before and once after, so a test with a two value clock
asserts the exact `0.25` and no test ever reads a wall clock. The
line itself is json from the hand rolled `JsonLogHandler`, a
subclass of `logging.Handler` whose `emit` builds one dict per
record, level, message, and whichever request attrs the record
carries, compact separators and utf8 out, one object per line. It is
the same handler seam the observability chapter builds its full
story on, introduced here at the size the access log needs.

#diagram([fields off the response value, one json line, duration over the injected clock], length: 13pt, {
  pane(0.3, 7.0, 7.2, [inner stack returns], [a Response value], [status, headers, body])
  cdraw.line((3.65, 5.5), (3.65, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 3.0), (7.0, 4.4), fill: luma(225), radius: 0.02)
  cdraw.content((3.65, 3.95), [the log layer], size: 6pt)
  cdraw.content((3.65, 3.25), [reads fields, no capture], size: 6pt)
  cdraw.line((7.2, 3.7), (8.2, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(8.4, 15.6, 5.4, [JsonLogHandler], [level, msg, method, path], [status, bytes, duration, id])
  pane(8.4, 15.6, 2.4, [no wrapper traps], [no first-write rule], [no lost interfaces])
})

== the deadline over the injected clock

Python cannot preempt a running handler, and the honest deadline
admits it: the handler runs on a worker thread, the serving thread
waits on an `Event` for whatever remains of the budget, computed
from the injected clock, and the two never touch the same response.
`Event.wait` with a zero or negative remainder returns immediately,
so an expired budget answers at once with the `overload` envelope
while the abandoned handler keeps running on its daemon thread,
writing into a box nobody reads, the detached writer idea restated
as a dict. The worker is a copy of the caller's context running
`run`, which is how the request id reaches the handler thread, a
plain thread local set on the serving thread would read empty
there. An exception out of the handler is caught as `BaseException`
and delivered to the serving thread verbatim, where recover or the
platform sees it:

#listing("python/api/pyapi/middleware.py", first: 131, last: 149, caption: [the worker fills a box, the wait decides, expiry answers overload and drops the late response])

The expiry test is the lane's whole testing discipline in one
place. The handler gates on an `Event` the test holds closed, the
budget is zero over a constant clock, so the wait returns false
without any sleeping, the 503 envelope is asserted, the late
response is proven absent from the wire bytes, and only then does
the test open the gate and join the abandoned thread by waiting on
its own produced event. Nothing measures time, everything waits on
a gate.

#diagram([two threads, one box: the wait decides who answers], length: 13pt, {
  cdraw.rect((0.3, 4.6), (9.8, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.05, 6.1), [serving thread], size: 6pt)
  cdraw.content((5.05, 5.1), [computes the remainder, waits], size: 6pt)
  cdraw.rect((12.6, 4.6), (22.2, 6.6), fill: luma(228), radius: 0.02)
  cdraw.content((17.4, 6.1), [worker thread, daemon], size: 6pt)
  cdraw.content((17.4, 5.1), [copied context runs the handler], size: 6pt)
  cdraw.line((9.9, 5.6), (12.5, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.2, 6.1), [start], size: 6pt)
  cdraw.line((12.5, 4.2), (9.9, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.2, 3.6), [#"done.set()"], size: 6pt)
  pane(0.3, 9.8, 2.6, [in budget], [the box's response], [committed untouched])
  pane(12.6, 22.2, 2.6, [expired], [503 overload envelope], [the box is dropped])
})

== wiring order and why

The order of the four layers is contract, and each position is a
sentence. Request id outermost, because every other artifact quotes
it: the access log field, the panic log, the envelope, all of it.
Access log second, outside recovery, so a recovered 500 is logged
as the 500 the client saw rather than swallowed inside the layer
that produced it. Deadline third. Recover innermost, and in this
lane the reason is data flow rather than go's goroutine rule: the
bug becomes a response on the worker thread, flows back through the
deadline's box as a value, and the whole stack sees one answer. The
wiring is one `chain` call in the composition root, reading top to
bottom as the request flows, and a test pins it as the stack
builder every other test reuses:

#listing("python/api/tests/test_middleware.py", first: 240, last: 247, caption: [the stack, in wiring order, one chain call in the composition root])

The stack test is the one that fails when anyone reorders the
wiring. A handler that raises `RuntimeError` through the full stack
produces one answer everywhere: the client sees the 500 envelope,
the response header and the envelope's `request_id` are the same
value, and the log holds two lines that agree, the panic line with
the stack, then the request line with status 500 quoting the same
id. Two answers for one request is the failure mode the order
exists to prevent, and the go lane's wrong-order diagram shows
exactly how it happens there when the log sits inside recover:

#diagram([right order: the log outside recover sees the answer the client saw], length: 13pt, {
  let row(y, l1) = {
    cdraw.rect((0.6, y), (22.6, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((11.6, y + 0.55), [#l1], size: 6pt)
  }
  row(6.6, [request id, resolves once, echoes, sets the contextvar])
  row(4.9, [access log, holds the response value, writes one json line])
  row(3.2, [deadline, worker thread plus the event wait, overload on expiry])
  row(1.5, [recover, bugs become the envelope, signals rethrown])
  row(-0.2, [handler, or the kernel's route lookup])
  cdraw.line((-0.4, 7.3), (-0.4, 0.4), stroke: luma(120), mark: (end: ">>"))
  cdraw.content((-1.2, 3.9), [the], size: 6pt)
  cdraw.content((-1.2, 3.1), [flow], size: 6pt)
})

== testing the stack

The kernel's value shape pays its second dividend here: the whole
stack tests as plain function calls, no listener, no client, no
socket at all, because every layer is a function over a function
over a `Request`. The only real thread in the suite is the
deadline's own worker, and it joins through events, never through
time. The logging assertions read whole json lines back through a
logger wired to the json handler over a `StringIO`, one buffer per
test, so a wrong field is a failed assert on a parsed object rather
than a grep over prose. The clock is a two value iterable where the
duration matters and a constant where only the ordering matters:

#listing("python/api/tests/test_middleware.py", first: 200, last: 215, caption: [the expiry test: a held gate, a zero budget, a join, no sleeps])

The last test wraps the stack around a real `App` and dispatches
through it, 200 on the healthz route, 404 on an unknown path, and
asserts the log shows both statuses in order, which is the
integration proof that the layers and the kernel agree on one
request lifecycle. Eighteen tests cover the module, zero are
skipped, and none of them sleeps.

#diagram([function calls with gates: the only thread in the suite is the deadline's own], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [build the stack], [chain over a tiny handler])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [call it], [a Request, no socket])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [assert on values], [response, log lines, ids])
  pane(0.3, 11.0, 3.4, [the gates], [#"gate.wait(), produced.wait()"], [joins, never sleeps])
  pane(12.0, 22.8, 3.4, [the buffers], [StringIO per logger], [parsed json asserts])
})

sources: docs.python.org for logging, threading, contextvars, and
traceback, accessed 2026-09-27, with the paren-free except spelling
checked against the what's new for 3.14 and `Event.wait` semantics
against the threading page the same day. Verified by `pyapi` tests,
18 of them over `middleware.py` in `tests/test_middleware.py`, plus
the verify-pyapi gates over the whole vehicle.
