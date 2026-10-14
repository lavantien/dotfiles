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

Cross-cutting behavior does not belong inside handlers, and rust's
lack of a server makes the composition cheap: a layer is one
function from handler to handler, exactly the go shape,
#xref-to("go", "middleware"), with none of the writer-wrapping the
go layer needed. This chapter composes the service's stack in
`rustapi::middleware`, four layers over the chapter 19 kernel:
request ids born once and quoted everywhere, the access log reading
the status straight off the returned value, timing published for
the log outside it, panic recovery into the contract envelope, and
the wiring order that makes the stack correct rather than merely
present. The java book built the same four as `Filter` classes,
#xref-to("java", "middleware"), and the contrast that matters here
is the one its chapter kept too: where the response is a value, the
wrapper problem cannot exist.

== layers are functions, the chain composes them

One layer is a function that takes the next handler and returns the
handler that wraps it, and `chain` folds them inside out so the
first argument is the outermost layer and sees the request first
and the response last:

#listing("rust/api/src/middleware.rs", first: 11, last: 21, caption: [the layer type and the fold: first layer in, outermost at request time])

The per-request state the layers share is the `extras` map the
kernel put on the request, the counterpart of go's context values
and java's exchange attributes: the id layer publishes under
`request.id`, the timing layer under `request.micros`, and the log
outside both reads what it needs without any layer touching a
header after the fact. Everything a layer needs to observe about
the answer is either on the request it still holds or on the
`Result` the inner call returned, which is the whole reason no
wrapper type appears in this module.

#diagram([one request through the stack: order in, unwind out], length: 13pt, {
  let row(y, title, l1) = {
    cdraw.rect((2.6, y), (21.0, y + 1.5), fill: luma(235), radius: 0.02)
    cdraw.content((11.8, y + 1.0), [#title], size: 6pt)
    cdraw.content((11.8, y + 0.25), l1, size: 6pt)
  }
  row(8.8, [request id], [outermost: resolve, publish, echo])
  cdraw.line((11.8, 8.7), (11.8, 8.1), stroke: luma(100), mark: (end: ">>"))
  row(6.5, [access log], [logs the returned result, both lanes])
  cdraw.line((11.8, 6.4), (11.8, 5.8), stroke: luma(100), mark: (end: ">>"))
  row(4.2, [timing], [instant around the inner span, publishes micros])
  cdraw.line((11.8, 4.1), (11.8, 3.5), stroke: luma(100), mark: (end: ">>"))
  row(1.9, [recover, then handler], [innermost: owns the panic lane])
  cdraw.content((17.4, 0.6), [extras: request.id, request.micros], size: 6pt)
})

== request id, minted and quoted once

Every request needs one id that every artifact agrees on: the log
line, the error envelope, the panic log. The layer resolves it once
at the edge through the kernel's order from chapter 19, an id
already resolved, else the client's `X-Request-ID` when it parses
as a uuid, else a fresh v7 the kernel mints, and it both publishes
the value into `extras` and echoes it on the response of both
lanes:

#listing("rust/api/src/middleware.rs", first: 39, last: 54, caption: [resolve once, publish, and echo on the ok lane and the error lane alike])

Parsing the client header is not politeness, it is contract: the
envelope promises `request_id` is a uuid, and a free-text header
echoed into logs is log injection. Garbage is replaced, never
echoed, and the three births are pinned by test: a client uuid
comes back verbatim, garbage is replaced by a 36-character v7 with
the version nibble at position 14, and an absent header mints one.
On the error lane the header rides the `ApiError` itself, and the
kernel's one envelope writer appends it after the body members, so
the id on the wire and the id in the log are the same string by
construction.

== recover, the panic lane

Rust has two failure lanes and chapter 19 split them the way the
java chapter did. The declared lane is the `Err(ApiError)` every
handler may return, rendered by the kernel adapter into the
envelope. The undeclared lane is a panic, and the recover layer
turns it into the contract's internal envelope before it can cross
the stack:

#listing("rust/api/src/middleware.rs", first: 102, last: 121, caption: [catch_unwind around the inner call, log id and payload, answer internal])

The mechanism is `std::panic::catch_unwind`, which requires an
`AssertUnwindSafe` wrapper because a closure capturing `&mut`
references is not unwind-safe by default and the escape hatch is
deliberate: the request value is not read again on the panic path,
so accepting the assert is sound here. Three rules live in those
lines. The log line carries the request id and the panic payload,
extracted by downcast to `&str` or `String`, with anything else
reported as an opaque payload rather than guessed at. The envelope
says `internal error` and nothing else, so a panic message never
reaches a client. And the logged backtrace is honest about what it
is: rust unwinds before the catch sees the stack, so
`Backtrace::force_capture` records the recovery frame, and the
panic origin is what the default panic hook prints to stderr when
`RUST_BACKTRACE` is set. Go's deferred `debug.Stack` shows the
panicking frames because its recover runs on them, and the
difference is worth knowing rather than papering over.

There is no rethrown sentinel. Go's layer rethrows
`http.ErrAbortHandler` because the go server speaks it, and the
java chapter stated its server has no equivalent. Rust's server is
this book's own kernel, and its backstop is the `catch_unwind` in
the connection loop from chapter 19: without the recover layer a
panic crosses the middleware entire, the backstop closes the
connection with no bytes, and the test pins exactly that crossing.
With the layer, the panic dies inside, every outer layer's
post-call code still runs, and the access log outside records the
500 the client saw.

== the access log needs no wrapper

Go's access log had to wrap the `ResponseWriter` in a
status-capturing type because a go handler writes a status and
never returns it. The rust handler returns the response, so the
status and the byte count are fields on the value the log already
holds, and the first-status-wins trap of the go chapter cannot
exist here because there is no second write to miscount:

#listing("rust/api/src/middleware.rs", first: 56, last: 78, caption: [both lanes answered from the returned result, the dur field from the timing layer inside it])

The error lane reconstructs the envelope through the kernel's one
writer to count the bytes it will become, which costs a second
serialization of a small body and keeps the count exact. The line
carries method, path, status, bytes, `dur`, and the request id, and
the path is client input: `one_line` spells the two
line-breaking characters and every other control byte as their
escaped forms before anything is concatenated, so a path carrying a
real crlf forges no second line. The test builds exactly such a
path and asserts the captured line carries `\r` and `\n` spelled,
not the bytes they name.

== timing on the unwind

The timing layer is an `Instant` around the inner span, published
after it returns, five lines with no library clock:

#listing("rust/api/src/middleware.rs", first: 89, last: 100, caption: [instant around the inner call, micros published for the log outside])

One rust-specific observation the java chapter could not make:
because the response is a value and nothing is on the wire until
the connection loop writes it, a timing layer could add a duration
header by mutating the returned response, the lane java lost to
`sendResponseHeaders` committing early. This book keeps the
contract the siblings froze, timing travels outward through
`extras` into the log line, and notes the open lane rather than
using it, because a `Server-Timing` header is an observability
chapter decision, not a middleware one.

== wiring order, and the tests that pin it

The order of the four layers is contract. Request id outermost,
because every other artifact quotes it. Access log second, outside
recover, so a recovered 500 is logged as the 500 the client saw.
Timing third, inside the log, so the log can carry the number.
Recover innermost, next to the handler, where every other layer's
post-call code still runs on its answer:

#listing("rust/api/src/middleware.rs", first: 122, last: 129, caption: [the contract stack in wiring order, one vec entry per layer])

The counterexample test is the order's own: it wires recover
outside the access log on purpose, panics a route, and asserts the
client still sees the 500 while the access log stayed silent, the
precise failure mode the order exists to prevent. The socket test
drives the full stack over a real listener and asserts the id
header on both lanes, the envelope quoting the same id, and both
log lines landing, with the poll the harness needs because a log
line written after the inner call returns can land moments after
the client already has its bytes, the same race the java chapter
met. On the pinned 1.99.0 build, dated 2026-10-13, the
middleware's test file carries 12 green tests: the chain order, the
three id births, the id on the error lane, the recovered envelope
with the cause hidden and logged, string and opaque payloads, the
panic crossing without the layer, the access log on both lanes, the
timing pickup, the crlf spelling, the stack order with the
recovered 500 logged, the wrong-order counterexample, and the
socket run.

#diagram([wrong order versus right: where the log sits decides what it sees], length: 13pt, {
  cdraw.content((6.4, 8.2), [wrong: log inside recover], size: 6.5pt)
  cdraw.content((6.4, 7.5), [id, recover, log, handler], size: 6pt)
  cdraw.content((6.4, 6.8), [the unwind crosses the log line entirely], size: 6pt)
  pane(0.4, 12.4, 5.4, [the log records], [nothing at all], [for the panicked route])
  cdraw.content((6.4, 1.1), [the client still sees the 500], size: 6pt)
  cdraw.line((12.6, 4.9), (13.4, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((18.4, 8.2), [right: log outside recover], size: 6.5pt)
  cdraw.content((18.4, 7.5), [id, log, timing, recover, handler], size: 6pt)
  cdraw.content((18.4, 6.8), [recover answers inside, log sees the answer], size: 6pt)
  pane(12.6, 24.2, 5.4, [the log records], [status=500 plus id], [plus dur])
})

sources: `std::panic` with `catch_unwind`, `AssertUnwindSafe`, and
`panic_any`, `std::any::Any` downcasting, `std::backtrace`
`Backtrace` and `force_capture`, and `std::time::Instant`, read
from the offline 1.99.0 html share under
`~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html`,
accessed 2026-10-13. The layer contract, the id resolution order,
the access log fields, the recover discipline, and the wiring order
from the sibling middleware chapters, go book 4 chapter 20 and java
book 4 chapter 20 of this corpus, including the java chapter's
logged race and the go chapter's statusWriter wrapper this module
does not need. All measurements, 12 tests, the three id births, the
envelope hiding, the crlf spelling, and the counterexample silence,
produced by `cargo test --locked` under `CARGO_NET_OFFLINE=true` on
the pinned build, dated 2026-10-13.
