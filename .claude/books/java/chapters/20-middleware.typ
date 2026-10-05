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

Cross-cutting behavior does not belong inside handlers, and the jdk's
server already agrees: `com.sun.net.httpserver.Filter` is a chain
type built into the same module as the kernel. This chapter composes
the service's filter stack in `javabook.middleware`, four layers over
the chapter 19 kernel: request ids born once and quoted everywhere,
panic recovery into the contract envelope, the access log that reads
the status off the exchange after the fact, timing measured on the
unwind, and the wiring order that makes the stack correct rather
than merely present. The go book built the same stack as
handler-wrapping functions, #xref-to("go", "middleware"), and where
its shapes differ from java's, the differences are the chapter.

== filters are the chain

A filter is an abstract class with two methods. `doFilter` receives
the exchange and a `Chain`, and the chain is the entire middleware
contract: call `chain.doFilter(ex)` to run everything inside you,
decline to call it and you have answered the request yourself. The
chain object is a `ListIterator` over the context's filter list plus
the handler at the end, so the list order is the runtime order, the
first filter in the list is the outermost layer, it sees the request
first and the response last, and a filter's code after its
`chain.doFilter` call runs on the unwind. One filter is one class
here rather than one function value as in go, and one abstract
method beyond `doFilter`, a `description` string the javadoc asks
for. Nothing in the server ever calls it, a grep across the pinned
build's sources finds no caller, so it is documentation in code and
the four layers here state their jobs in it.

The second built-in is the request-scoped state go put in a context.
`HttpExchange` carries an attributes map, `setAttribute` and
`getAttribute`, documented for exactly this use, and it is how the
layers talk without touching headers: the router's path parameters
already live there under `path.`, this chapter's id lives under
`request.id`, and the timing layer publishes its measurement the
same way for the log outside it.

#diagram([the chain is a list iterator: list order is runtime order, code after the call runs on the unwind], length: 13pt, {
  cdraw.content((11.8, 8.5), [one request], size: 6.5pt)
  let row(y, title, l1) = {
    cdraw.rect((2.6, y), (21.0, y + 1.5), fill: luma(235), radius: 0.02)
    cdraw.content((11.8, y + 1.0), [#title], size: 6pt)
    cdraw.content((11.8, y + 0.25), [#l1], size: 6pt)
  }
  row(6.6, [request id], [outermost: resolve, publish, then])
  cdraw.line((11.8, 6.5), (11.8, 5.9), stroke: luma(100), mark: (end: ">>"))
  row(4.3, [access log], [logs after the chain returns])
  cdraw.line((11.8, 4.2), (11.8, 3.6), stroke: luma(100), mark: (end: ">>"))
  row(2.0, [timing], [measures on the unwind, publishes micros])
  cdraw.line((11.8, 1.9), (11.8, 1.3), stroke: luma(100), mark: (end: ">>"))
  row(-0.3, [recover, then handler], [innermost: owns the panic lane])
  cdraw.content((17.4, -1.6), [attributes: request.id, request.micros], size: 6pt)
})

== request id

Every request needs one id that every artifact agrees on: the access
log line, the error envelope, the panic log. The layer resolves it
exactly once, at the edge, using the kernel's order from chapter 19:
an id already resolved, else the client's `X-Request-ID` when it
parses as a uuid, else a fresh `UUID.randomUUID`, which is version
4. The jdk's other generator, `nameUUIDFromBytes`, builds version 3
names, so time-ordered v7 ids like the go book's would have to be
hand-rolled. Parsing is not
politeness, it is contract: the envelope promises `request_id` is a
uuid, and a client-supplied free-text header echoed into logs is log
injection. Garbage is replaced, never echoed.

The layer then does two small things with the value: it sets the
response header so a client correlates its own logs with the
server's, and it installs the id as an exchange attribute so
everything downstream reads one value without touching headers
again:

#listing("java/api/src/javabook/middleware/RequestId.java", first: 19, last: 29, caption: [resolve once at the edge, echo it, publish it as the attribute])

Three births, two tests: a client uuid echoes verbatim, garbage is
replaced by a v4, and an absent header generates one. The uuid
version nibble is asserted, so the day someone swaps in a hand-rolled
v7 the tests ask whether that was intended.

== recover, the panic lane

Java has two failure lanes and chapter 19 split them. The declared
lane is `ApiError` plus the `IOException` of a departed client, both
caught by the kernel adapter. The undeclared lane is everything
else, any `RuntimeException` from anywhere inside a handler, and a
bare exchange has no way to promise a client anything when one
fires. Measured on the pinned build: an unhandled
`IllegalStateException` in a handler closes the connection, and the
client's `HttpClient` throws `IOException` with `HTTP/1.1 header
parser received no bytes`. The recover filter exists so that never
happens to a real caller:

#listing("java/api/src/javabook/middleware/Recover.java", first: 30, last: 46, caption: [catch Throwable, log stack and id, answer the internal envelope])

Three rules live in those lines. The log line carries the stack and
the request id, because a panic without a stack is a mystery and one
without an id is an orphan. The envelope says `internal error` and
nothing else, so the `IllegalStateException`'s message never reaches
the client, the same information discipline the go layer kept. And
the envelope write itself can fail, because a throw often means a
half-written response and a client that already gave up, so the
inner catch acknowledges the client-gone case instead of throwing
from inside a catch. A response the handler already committed is
left alone, the kernel's writer checks the `-1` sentinel and only
logs, and the test for that pins a handler that writes a 201 and
then throws: the client keeps its 201, the log records the late
throw.

There is no rethrown sentinel here. Go's middleware rethrows
`http.ErrAbortHandler` because the server itself speaks it, and java's
server has no equivalent signal, so the catch is total, `Throwable`
and all. The tradeoff is honest: an `Error` in the stack is caught,
answered, and logged, on the theory that a service that tells the
client `internal error` while it dies is better than one that
answers nothing. That is a policy this book owns, not a library
default.

#diagram([panic unwind: one path to the log, one to the envelope], length: 13pt, {
  pane(0.3, 7.0, 7.6, [handler throws], [#"RuntimeException(\"boom\")"], [declared nowhere])
  cdraw.line((3.65, 5.5), (3.65, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 3.0), (7.0, 4.4), fill: luma(225), radius: 0.02)
  cdraw.content((3.65, 3.95), [recover, innermost], size: 6pt)
  cdraw.content((3.65, 3.25), [same thread, same stack], size: 6pt)
  cdraw.line((7.2, 3.7), (8.2, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(8.4, 15.2, 5.4, [log], [stack trace, request id], [ERROR level])
  cdraw.line((15.4, 3.7), (16.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(16.6, 23.2, 5.4, [envelope], [500 internal,], [message hidden])
  cdraw.content((11.5, 1.4), [measured without the filter: client holds an IOException, no bytes], size: 6pt)
})

== the access log, no wrapper needed

Go's access log had to wrap the `ResponseWriter` in a
status-capturing type, because a go writer does not tell you what
went out, and the wrapper then broke every optional interface it did
not forward. The jdk exchange does tell you: `getResponseCode`
answers the status after the chain returns, so the java access log
is five lines with no wrapper and no forwarding problem, and the
first-status-wins trap of the go chapter cannot exist here because
the exchange is one object remembering its own commit. Body byte
counts are not exposed, so the line carries what is: method, path,
status, request id, and the duration when a timing layer ran inside
this one:

#listing("java/api/src/javabook/middleware/AccessLog.java", first: 25, last: 35, caption: [after the chain: the status is on the exchange, the duration is an attribute, the path is sanitized])

The path in that line is client input that arrives percent-decoded,
so a request to `/ok/x%0D%0Ainjected` would otherwise carry a real
crlf into the log and forge a second line. The id lane refuses this
by parsing, a garbage header never reaches the log, and the path
lane refuses it by escaping: `Logs.oneLine` turns the three
line-breaking characters into their two-character spelled forms
before anything is concatenated, and the test that pins it requests
exactly such a path and asserts the captured line carries the
spelled `\r` and `\n` rather than the bytes they name.

== timing on the unwind

The timing layer is `System.nanoTime` around the chain and a
published attribute. What it cannot do is put the duration in a
response header, and the reason is the jdk's own commit discipline:
`sendResponseHeaders` sends the headers the moment it runs, which is
before the handler's work is done, so by the time a duration exists
the header block is gone. A duration header would have to be a
trailer, the exchange api has no trailers, and the honest answer is
that timing travels outward through the stack, as an attribute and a
log line, where the access log outside it picks the number up for
its own line:

#listing("java/api/src/javabook/middleware/Timing.java", first: 27, last: 35, caption: [nanoTime around the chain, micros published as the attribute and logged])

#diagram([two ways a duration can travel: the header lane is closed at commit, the attribute lane is open], length: 13pt, {
  cdraw.content((6.4, 8.2), [the header lane], size: 6.5pt)
  cdraw.rect((0.4, 5.8), (12.4, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 7.3), [handler work measured], size: 6pt)
  cdraw.content((6.4, 6.4), [duration exists here], size: 6pt)
  cdraw.line((6.4, 5.7), (6.4, 5.1), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 12.4, 5.0, [headers], [committed before the], [measurement exists])
  cdraw.content((18.4, 8.2), [the attribute lane], size: 6.5pt)
  cdraw.rect((13.4, 5.8), (23.4, 7.9), fill: luma(228), radius: 0.02)
  cdraw.content((18.4, 7.3), [setAttribute on unwind], size: 6pt)
  cdraw.content((18.4, 6.4), [#"request.micros"], size: 6pt)
  cdraw.line((18.4, 5.7), (18.4, 5.1), stroke: luma(100), mark: (end: ">>"))
  pane(13.4, 23.4, 5.0, [outer access log], [reads it, appends], [the duration to its line])
  cdraw.content((11.8, 3.4), [no trailers in the exchange api: timing rides the stack outward], size: 6pt)
})

== wiring order and why

The order of the four layers is contract, and each position is a
sentence. Request id outermost, because every other artifact quotes
it: the access log line, the panic log, the envelope. Access log
second, outside recover, so a recovered 500 is logged as the 500 the
client saw. This is not aesthetic, it is mechanical: an access log's
line runs after its `chain.doFilter` returns normally, and a throw
unwinds past that line entirely, so a recover placed outside the log
means panics never get logged at all. Timing third, inside the log,
so the log can carry the number. Recover innermost, next to the
handler, where every other layer's post-chain code still runs on its
answer. The wiring is four `use` calls in list order, and the
program's own `Main` wires the same four in the same order before
any route registers:

#listing("java/api/test/javabook/middleware/MiddlewareTests.java", first: 61, last: 78, caption: [the contract stack: id, log, timing, recover, then the routes])

#diagram([wrong order versus right: where the log sits decides what it sees], length: 13pt, {
  cdraw.content((6.4, 8.2), [wrong: log inside recover], size: 6.5pt)
  cdraw.content((6.4, 7.5), [id, recover, log, handler], size: 6pt)
  cdraw.content((6.4, 6.8), [the throw unwinds past the log line], size: 6pt)
  pane(0.4, 12.4, 5.4, [the log records], [nothing at all], [for the panicked route])
  cdraw.content((6.4, 1.1), [the client still sees the 500], size: 6pt)
  cdraw.line((12.6, 4.9), (13.4, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.4, 8.2), [right: log outside recover], size: 6.5pt)
  cdraw.content((18.4, 7.5), [id, log, timing, recover, handler], size: 6pt)
  cdraw.content((18.4, 6.8), [recover answers inside, log sees the answer], size: 6pt)
  pane(12.6, 24.2, 5.4, [the log records], [GET /boom 500 plus id], [plus the duration])
  cdraw.content((18.4, 1.1), [one answer, everywhere, all attributed], size: 6pt)
})

== testing the stack

The tests boot the real stack on an ephemeral port and capture the
logs through the seam the jdk already ships: `System.Logger`, the
logging facade of `java.base` since java 9, which the logging layers
take as a constructor argument and the tests implement with a
capturing class. No global logger is configured, nothing is parsed
back out of a console, and the assertion reads the same lines
production would hand a real backend.

One race had to be owned rather than hidden. The body bytes flush to
the client before the filter stack finishes unwinding, so a log line
written after `chain.doFilter` can land moments after the client
already has its response. A test that asserts the line immediately
after `send` passes in isolation and fails under a full-suite run,
which is exactly how it was found. The honest harness polls for its
line with a deadline, and the polling helper carries the comment
explaining why:

#listing("java/api/test/javabook/middleware/MiddlewareTests.java", first: 94, last: 110, caption: [the polling helper: log lines race the client's receipt, so assertions wait])

The marquee test is the wiring's own: the counterexample app wires
recover outside the access log on purpose, panics a route, and
asserts the access log stayed silent, the precise failure mode the
order contract exists to prevent:

#listing("java/api/test/javabook/middleware/MiddlewareTests.java", first: 226, last: 243, caption: [the counterexample: wrong order, the 500 reaches the client and no line records it])

sources: `Filter`, `Filter.Chain`, and the exchange attributes read
from the pinned build's own sources
(`tools/jdk27/build/jdk-27/lib/src.zip`, oracle jdk 27 ga build
27+35-2325), the chain-as-iterator contract and the
must-answer-if-you-stop-the-chain rule from `Filter.java`.
`System.Logger` from `java.lang` of the same build. The go
contrasts, the statusWriter wrapper, `ErrAbortHandler`, and the
timeout layer's goroutine rule, against book 3, chapter 19.
Accessed and verified live 2026-10-04 by the `javabook.middleware`
tests under the vendored junit 6.1.3 lane, 9 tests, run green three
times consecutively as a stability check: the three id births, the
envelope answer with the throw logged and the detail hidden, the
committed-201 case left alone, the status-carrying access lines, the
duration attribute and its pickup, the crlf-forcing path escaped in
the log, the outside-in filter order, and the wrong-order
counterexample.
