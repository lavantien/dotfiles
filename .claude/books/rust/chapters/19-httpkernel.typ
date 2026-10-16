#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= http kernel

The service part of this book builds one api across thirteen
chapters, and everything in it sits on the module this chapter builds:
`rustapi::httpx` under `books/rust/api`. Rust's standard library
ships no http server at all, no router, no codec, no uuid, so where
the go book started from `net/http` and a mux, #xref-to("go",
"httpkernel"), and the java book from `jdk.httpserver`,
#xref-to("java", "httpkernel"), this book starts from a socket and
builds every layer above it: the http/1.1 parser, the route table,
the error envelope, the json, the thread pool, and the drain. The
contract is the one those chapters froze, the eleven-code envelope
and the 415 413 400 400 decode ladder, and the 16 frozen vectors
under `contract/testdata` measure parity for the whole service part.

== the socket is the whole server

`std::net::TcpListener` offers bind, accept, and local_addr, and
that is the entire server surface std gives. One accepted
`TcpStream` is one connection, one connection carries a sequence of
requests under keep-alive, and everything above the socket is this
module's own code. The handler contract is one type alias, and the
request and response are plain values rather than live objects: a
handler receives a `&mut Request` and returns a `Response` or an
`ApiError`, nothing streams, nothing commits early:

#listing("rust/api/src/httpx.rs", first: 114, last: 125, caption: [the handler type and the request value: handlers read and return, they never hold the socket])

The value-shaped response is the load-bearing difference from both
siblings. A go handler writes into a `ResponseWriter` it does not
own, and the access log had to wrap it to learn the status, while a
java handler drives an exchange whose header commit is
irreversible. Here the response is built, returned, and written by
one function at the bottom of the connection loop, which is why the
envelope cannot drift and why the middleware of chapter 20 needs no
wrapper types at all. The `extras` map is the request-scoped state
the middleware layers publish into, the java attributes map's
counterpart. The kernel's share of `main.rs` is two slices, the
head that binds and registers, and the tail that serves and parks,
with the resource chapters' wiring growing between them:

#listing("rust/api/src/main.rs", first: 49, last: 58, caption: [bind the configured address, build the kernel routes])

#listing("rust/api/src/main.rs", first: 176, last: 195, caption: [serve, park: signal-driven drain is chapter 29's scope])

The version in the health body comes from `env!("CARGO_PKG_VERSION")`,
a compile-time constant cargo injects, so the deployment check answers
what the manifest says without an environment variable the go and java
lanes needed.

#diagram([both siblings hand this chapter a server, rust hands it a socket], length: 13pt, {
  cdraw.rect((0.3, 4.0), (10.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.3, 6.45), [go and java], size: 6.5pt)
  cdraw.content((5.3, 5.5), [server, mux, codec given], size: 6pt)
  cdraw.content((5.3, 4.6), [the kernel fills the gaps], size: 6pt)
  cdraw.line((10.7, 5.5), (11.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((11.9, 4.0), (21.9, 7.0), fill: luma(228), radius: 0.02)
  cdraw.content((16.9, 6.45), [rust std], size: 6.5pt)
  cdraw.content((16.9, 5.5), [TcpListener, TcpStream, threads], size: 6pt)
  cdraw.content((16.9, 4.6), [the kernel is the whole server], size: 6pt)
  cdraw.content((11.0, 2.6), [parser, router, envelope, json, pool, drain:], size: 6pt)
  cdraw.content((11.0, 1.7), [all six built in this one module], size: 6pt)
})

== the parser: request line, headers, bodies

`read_request` reads from any `Read`, which is what lets the fuzz
test feed it garbage through a `Cursor` with no socket anywhere. It
accumulates bytes until a `\r\n\r\n` lands, caps the header block at
16 KiB, and hands the head text plus the leftover bytes to the line
parser:

#listing("rust/api/src/httpx.rs", first: 813, last: 840, caption: [buffer until the double crlf, cap the block, split head from body bytes])

The request line must be three space-separated tokens, the method
all token bytes, the target origin-form, all bytes visible ascii,
and the version exactly 1.1 or 1.0, so an `OPTIONS *` or a control
byte in the path dies here. Header names lowercase on the way in,
obs-fold continuation lines refused, control bytes in values
refused, and repeated lines kept so `header_joined` can rebuild the
rfc's comma-joined union. The body framing follows RFC 9112
section 6.3: transfer-encoding wins over content-length when both
appear, chunked must be the final coding:

#listing("rust/api/src/httpx.rs", first: 919, last: 941, caption: [the framing decision: chunked by transfer-encoding, else content-length under the 8 MiB transport cap, else empty])

#listing("rust/api/src/httpx.rs", first: 961, last: 991, caption: [chunked decode: hex size lines with extensions, crlf after every chunk, trailer lines after the zero chunk])

Two boundaries the parser owns honestly. The transport cap is 8 MiB
and a content-length past it answers a plain-text 413 and closes,
because below dispatch there is no envelope writer yet, the same
front-door rule the java chapter measured from its own server: what
the transport rejects never reaches the contract shape. And a
keep-alive connection whose next read times out or hits eof simply
closes, no response, since an idle peer that left owes nobody
bytes. The strict-crlf rule is deliberate, RFC 9112 lets a recipient
accept a bare lf and this parser does not, and the test pins the
refusal.

#callout("pitfall", "accepted sockets inherit the listener mode, measured", [
  The listener is set non-blocking so the accept loop can poll it,
  and on windows the accepted socket inherits that mode: the first
  keep-alive test died with `ErrorKind::WouldBlock` on the second
  request's read, because the connection reader saw a non-blocking
  socket where a blocking one was expected. The fix is one line,
  `set_nonblocking(false)` on every accepted stream, and the
  keep-alive test is the one that caught it, which is why the
  kernel tests always drive real sockets.
])

== the route table

The router is a registration-order list of method, pattern, handler
rows. A pattern is slash-separated segments, `{name}` binds one
segment, and dispatch walks the list, so the first matching row
wins and a literal path registers before a wildcard that would also
match it, the rule the java table kept and the go mux hides behind
specificity ranking. Routing runs on the raw path and the bound
parameter is percent-decoded, so `/items/a%2Fb` binds `{id}` once
and the handler reads `a/b`:

#listing("rust/api/src/httpx.rs", first: 1074, last: 1113, caption: [dispatch: bind wildcards, or collect the allowed methods for 405, or answer the 404 envelope])

The 405 keeps an `Allow` header built from every method the path
serves, sorted and deduplicated, and rides the `not_found` code the
contract chose because the closed code set has no method member.
One honest omission carried over from the java table: `HEAD` is not
auto-served for `GET` routes, so a head request answers 405 until
someone teaches the table otherwise.

== the error envelope

The envelope is the contract the go chapter froze, member for
member: an error object with a code from the closed set of eleven,
one human sentence, `details` on validation failures only, and the
request id. Codes are an enum carrying their wire name and default
status, and the two split codes are explicit: `invalid_json` rides
400 and 415, `not_found` rides 404 and 405, both through
`at_status`:

#listing("rust/api/src/httpx.rs", first: 221, last: 240, caption: [the one envelope writer: member order fixed, details only when present, request id resolved by the caller])

Every failure path builds through that function, and one sink
writes every response: `write_response` emits the status line, the
handler's headers in order, `content-length` unless the status is
bodyless, and the connection header the connection loop decided.

#listing("rust/api/src/httpx.rs", first: 268, last: 296, caption: [the single socket writer: framing cannot drift because nothing else writes])

The 204 and 304 statuses are bodyless by construction, and a
programmer error like a 304 carrying bytes is a write-time
`Err`, not silent truncation. The test pins the exact wire bytes
of a 201 with json and the empty frame of a 204.

== json by hand

Std has no json, the zero-dependency law of this lane forbids
serde, so the kernel is the codec, the same corner the java book
was pushed into. The value model is an enum whose object is a
`Vec` of pairs in insertion order, the chapter 15 lesson that
deterministic wire bytes come from the container that keeps
insertion order, and the writer walks it with the grammar's
escapes:

#listing("rust/api/src/httpx.rs", first: 307, last: 316, caption: [seven variants behind a clone derive, objects keep insertion order, ints and floats split by shape])

The reader is a byte-position recursive descent over the source,
strict RFC 8259: whitespace only where allowed, no leading zeros,
no trailing content, control bytes rejected inside strings, every
escape including `\uXXXX` with surrogate pairs validated, a nesting
cap of 128 so a hostile body cannot recurse the stack, and offsets
in every failure message. Numbers split by shape, integral texts
that fit an `i64` become `Int`, everything else parses as `f64` and
a non-finite result such as `1e400` is refused rather than stored:

#listing("rust/api/src/httpx.rs", first: 618, last: 666, caption: [the number reader: grammar-checked digits, fraction, exponent, then the int or float split with finiteness enforced])

The fixed-point property the tests assert is byte level: for every
input the suite holds, parse, write, parse again, write again, and
the two written forms are identical strings. The cursor the user
chapter will freeze is one of those inputs.

== the decode ladder

Reading a request body is stricter than writing one, because
request bodies are input. `bind_json` is the one decode path and
its four rungs are the contract's, in the contract's order: the
media type must be `application/json` before the semicolon, the
body must fit the 1 MiB cap, the json must parse, and every member
must be one the route accepts:

#listing("rust/api/src/httpx.rs", first: 669, last: 701, caption: [the ladder: 415, 413, 400, 400, then the member map is the caller's])

The unknown-member rung is where go got `RejectUnknownMembers` from
its json/v2 option and java got an explicit allowed set, and the
rust lane keeps the java shape because the allowed set is the
caller's statement of what the route means. The typed member read
on top, a number or bool answering 400 while null rides the missing
lane to 422, belongs to the resource chapters.

#diagram([each rung rejects a class of bad input before the next runs], length: 13pt, {
  let rung(y, q, bad) = {
    cdraw.rect((1.5, y - 0.9), (9.8, y + 0.35), fill: luma(235), radius: 0.02)
    cdraw.content((5.6, y - 0.25), q, size: 6pt)
    cdraw.line((10.2, y - 0.25), (13.0, y - 0.25), stroke: luma(100), mark: (end: ">>"))
    cdraw.content((16.4, y - 0.25), bad, size: 6pt)
    cdraw.line((5.6, y - 1.15), (5.6, y - 1.7), stroke: luma(100))
  }
  rung(7.6, [content type json?], [415 invalid_json])
  rung(5.7, [body under 1 MiB?], [413 payload_too_large])
  rung(3.8, [parses as json?], [400 invalid_json])
  rung(1.9, [known members only?], [400 invalid_json])
  rung(0.0, [field rules hold?], [422, else 201 or 409])
})

== the bounded pool and the drain

The server is a thread-per-connection pool with bounded growth, the
chapter 13 primitives doing the whole job. The accept loop polls
the non-blocking listener every 2 ms, a cadence that exists because
neither closing a cloned listener nor dropping it elsewhere is a
portable way to break a blocked accept on windows. Every accepted
stream is pushed into a queue under one mutex and one condvar, and
the growth rule is a single expression: no idle worker and headroom
under `max_workers` means spawn one, otherwise the connection waits
in the queue, so a burst bounds threads at the configured ceiling
and queues the rest:

#listing("rust/api/src/httpx.rs", first: 1282, last: 1313, caption: [the accept loop: queue first, grow only when no worker is idle, 2 ms poll to observe shutdown])

Workers wait with `wait_timeout` rather than a bare wait, 50 ms per
round, so a lost wakeup costs a tick instead of a hung worker, and
the busy counter is the drain's whole observability:

#listing("rust/api/src/httpx.rs", first: 1353, last: 1372, caption: [the worker wait: pop a job, or park 50 ms at a time until work or shutdown])

`shutdown` runs the contract's order: readiness flips first, so
`/readyz` answers 503 while old requests still complete, then the
queue is dropped and the accept loop joined, then the busy count is
polled until zero or the grace expires. The honest rust limit is
stated rather than hidden: a thread cannot be killed from outside,
so a handler that never returns outlives any grace, shutdown
reports the count, and the socket read timeout is what bounds a
stuck connection:

#listing("rust/api/src/httpx.rs", first: 1229, last: 1254, caption: [drain: flip readiness, refuse new work, wait for busy to reach zero within the grace])

The default ceiling is 32 workers with a 5 s keep-alive timeout,
both fields of `ServerConfig`, and the tests override both: 64
concurrent clients green under the default, 12 sequential bursts
green under a ceiling of 2, and the drain test holding one request
open with a channel while shutdown runs.

== testing through a real socket

The test harness boots the real thing, a listener on
`127.0.0.1:0`, the ephemeral port, and drives it with a hand-rolled
client that writes raw request bytes and reads raw response bytes
back, so the assertions read the wire:

#listing("rust/api/tests/common/mod.rs", first: 49, last: 126, caption: [the client helper: raw bytes out, status line, headers, content-length body in])

The fuzz discipline is the kernel's own parser fuzzed by the
kernel's tests: a table of malformed shapes plus 2000 rounds of
xorshift garbage, some with a spliced `\r\n\r\n`, every round must
come back eof, a parsed head, malformed, or oversize, and never a
panic, a hang, or an io error:

#listing("rust/api/tests/httpx.rs", first: 210, last: 250, caption: [the fuzz loop: seeded garbage, spliced terminators, a closed set of acceptable outcomes])

The drain test is the lifecycle proof, the one that also caught the
windows inheritance trap above: a gated handler holds a request
open, shutdown runs concurrently, the release arrives mid-drain,
the in-flight response still completes byte-exact, and the next
connection is refused:

#listing("rust/api/tests/httpx.rs", first: 708, last: 746, caption: [the drain proof: in-flight completes, new arrivals refused])

On the pinned 1.99.0 build, dated 2026-10-13, the kernel's test
file carries 33 green tests: parser shape and framing, chunked
decode with trailers, strict crlf, the caps, the 2000-round fuzz,
json round trips and the strict reader, the eleven-pair code table,
404 and 405 with allow, path parameters decoded, the decode ladder,
request id resolution and v7 shape, wire bytes of a framed
response, keep-alive and connection close over one socket, garbage
at the front door with the server living on, 64 concurrent
requests, the small-pool burst, and the drain.

sources: RFC 9112, HTTP/1.1, section 2.2 on message parsing,
sections 5.1 and 5.2 on field line parsing and obsolete line
folding, section 6.3 on message body length and the
transfer-encoding precedence over content-length, and section 7.1
on the chunked transfer coding, and RFC 8259 for the json grammar,
both at rfc-editor.org, accessed 2026-10-13. The rust standard library
surface, `std::net` `TcpListener`, `TcpStream`, socket timeouts
and non-blocking mode, `std::thread` `Builder` and `JoinHandle`,
`std::sync` `Mutex`, `Condvar`, `wait_timeout`, and atomics, read
from the offline 1.99.0 html share under
`~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html`,
accessed 2026-10-13. The envelope contract, the code set, the
decode ladder, and the health and ready routes from the sibling
kernel chapters, go book 4 chapter 19 and java book 4 chapter 19 of
this corpus, and the frozen vectors under
`books/go/api/contract/testdata` hashed byte-exact into this lane's
`contract/testdata`. All measurements, 33 tests, 2000 fuzz rounds,
64 concurrent clients, the 2 ms poll and 50 ms wait cadences, the
16 KiB, 1 MiB, and 8 MiB caps, produced by `cargo test --locked`
under `CARGO_NET_OFFLINE=true` on the pinned build, dated
2026-10-13.
