#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= http kernel

Everything else in this service part sits on one small kernel, and this
chapter builds it in `c-os-cloud/api/src`: the handler contract every
route shares, an HTTP/1.1 parser read straight off RFC 9112, a fixed
route table that owns the 404 and 405 split, the one error envelope
writer, the one json codec, and a winsock2 listener over a fixed thread
pool. The go book built the same spine on `net/http` and `ServeMux` and
the standard library. This vehicle has none of that, so the kernel is
the standard library: every piece the go lane imported is a file here,
and the tests drive all of it without a single socket.

== the handler contract

A handler is one function that takes a request and either commits a
response or describes a failure. That is the whole contract, and it is
the go lane's error-returning adapter said in c: return true with the
response struct filled, or return false with the fail struct filled and
let the kernel render it. No route formats a failure body by hand, and
no route can answer a 500 with the wrong shape, because the response a
handler writes and the envelope the kernel writes both pass through one
writer.

The fail struct carries a code from the closed set of 11, an optional
status override for the two split codes, a message, and an optional
preformatted details array that only `validation_failed` ever carries.
The status field exists because the code set is closed while the
statuses are not: `invalid_json` rides 400 on a malformed body and 415
on the wrong media type, `not_found` rides 404 on an unknown route and
405 on a method mismatch, and the caller picks the side. Everything
else takes the code's default status from the table a later section
pins:

#listing("c-os-cloud/api/api.h", first: 521, last: 539, caption: [the contract: a fail value or a committed response, nothing else])

#diagram([the two exits every handler has], length: 13pt, {
  cdraw.rect((0.4, 4.4), (10.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.1), [handler], size: 6.5pt)
  cdraw.content((5.5, 6.2), [#"return true: res is the answer"], size: 6pt)
  cdraw.content((5.5, 5.2), [#"return false: fail describes it"], size: 6pt)
  cdraw.line((3.0, 4.3), (3.0, 3.1), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 6.4, 2.9, [wire], [status line, headers], [body bytes])
  cdraw.line((8.0, 4.3), (8.0, 3.1), stroke: luma(100), mark: (end: ">>"))
  pane(6.6, 14.6, 2.9, [envelope writer], [code, message, request id], [the one failure body])
  cdraw.content((12.0, 4.9), [kernel renders this side], size: 6pt)
})

== parsing http/1.1 requests

The parser is one pure function over a receive buffer, and RFC 9112 is
its contract. The request line is method, target, and the exact string
`HTTP/1.1`, single spaces, target in origin form with the query split
at the first question mark. Headers are name, colon, value with the
surrounding whitespace folded away, at most 32 of them in the vehicle's
fixed table. A bare line feed is not a line ending, obs-fold
continuations are refused, and every one of those refusals is a plain
400 with an empty body and a closed connection, because a request that
never parsed has no route and no request id to envelope with.

The framing decision is where the security story lives. Content-Length
and Transfer-Encoding are mutually exclusive, each appears at most
once, and Transfer-Encoding must name `chunked` exactly. Every one of
those rules closes a request-smuggling shape that RFC 9112 section 6
spells out, and the parser refuses rather than tolerates: a duplicate
length field is refused whatever its value, and a body past the 1 MiB
cap is the contract's 413. The function returns three answers, a
complete request with the bytes it consumed, a request for more bytes,
or a refusal, and the consumed count is what makes pipelining work,
because the next request on a kept-alive connection starts exactly
there:

#listing("c-os-cloud/api/src/http_parse.c", first: 240, last: 262, caption: [the framing decision: one length, or chunked, never both])

#diagram([one buffer, three answers], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 5.2), (x0 + 5.0, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.6), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.7), [#l1], size: 6pt)
  }
  stage(0.3, [request line], [method, target, version])
  stage(6.1, [header block], [32 rows, folded values])
  stage(11.9, [framing], [length or chunked])
  cdraw.line((5.5, 6.2), (5.9, 6.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.3, 6.2), (11.7, 6.2), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 6.2, 3.2, [complete], [request filled], [consumed bytes named])
  pane(7.0, 13.2, 3.2, [need more], [recv again], [no error yet])
  pane(13.6, 20.2, 3.2, [refusal], [400 plain, close], [or the 413])
  cdraw.content((10.0, 1.0), [consumed is where the next pipelined request starts], size: 6pt)
})

== the route table

The route table is a fixed array compiled into the program, and it
grows by append only: one row per route, each row a method, a pattern,
and a handler. A pattern is literal path segments with a `{name}`
segment capturing any single nonempty segment into the request's
params, in pattern order. Matching is a walk down both strings one
slash-delimited segment at a time, with no allocation anywhere, and a
trailing slash is a different path because the walk says so: the
segment counts have to agree on both sides.

The 404 and 405 behavior lives here, not in the handlers. A path that
matches no row answers 404 with code `not_found`. A path that matches
a row whose method is wrong answers 405 carrying the same `not_found`
code plus an `Allow` header naming every method that does serve the
path, joined in table order. The closed code set has no
method-not-allowed member, so the message and the Allow header carry
the distinction, the same ruling the go lane froze:

#listing("c-os-cloud/api/src/router.c", first: 47, last: 59, caption: [the fixed table: method, pattern, handler, appended one row per family])

#diagram([the match walk and the two refusals], length: 13pt, {
  pane(0.3, 8.4, 7.6, [the request], [#"PATCH /api/users/x"], [three segments])
  cdraw.line((4.35, 5.5), (4.35, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 2.4), (8.4, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((4.35, 3.7), [the walk], size: 6pt)
  cdraw.content((4.35, 2.8), [segment by segment, wildcards capture], size: 6pt)
  cdraw.line((8.6, 3.3), (9.4, 3.3), stroke: luma(100), mark: (end: ">>"))
  pane(9.6, 15.8, 4.4, [path hits], [row methods compared], [Allow built in table order])
  cdraw.line((9.4, 2.2), (9.4, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 8.4, 1.0, [no path hit], [404 not_found], [the envelope])
  cdraw.content((13.0, 1.0), [405 is the same code with Allow riding along], size: 6pt)
})

== the error envelope

Every non-2xx response this api can emit is one byte shape, and one
function writes it. The envelope is an `error` object carrying `code`,
`message`, an optional `details` array on `validation_failed` only, and
`request_id`, in that member order, minified, with the exact bytes the
frozen vectors hold. The vectors in `contract/testdata` are the oracle:
vector 03's conflict body, vector 05's unauthorized body, vector 12's
precondition body, all three transcribed into the kernel tests as
string literals and compared byte for byte, so any drift in escaping,
member order, or spacing fails a check instead of shipping.

The code set is a table, one row per code with the status it carries
everywhere it is used. An unknown code renders as `internal` at 500,
the same unknown-failure rule the go kernel carries: a mistake is
answered with the envelope shape, never outside it, and the detail
stays in the logs. The two split rows say their rule in the comment
that pins them, because a split code is where every lane drifts if
nothing writes the rule down:

#listing("c-os-cloud/api/src/envelope.c", first: 14, last: 31, caption: [the code table: eleven rows, two of them split, one writer])

#diagram([one writer, every failure funnels through it], length: 13pt, {
  pane(0.3, 6.6, 7.8, [any handler], [#"return false, fail filled"])
  pane(0.3, 6.6, 5.2, [the router], [404 and 405 paths])
  pane(0.3, 6.6, 2.6, [the parser cap], [413 on a 1 MiB body])
  cdraw.line((7.0, 6.4), (7.0, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((3.5, 2.4), (3.5, 1.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, -0.4), (7.0, 1.4), fill: luma(225), radius: 0.02)
  cdraw.content((3.65, 0.9), [capi_write_fail], size: 6pt)
  cdraw.content((3.65, 0.0), [code table, builder, exact bytes], size: 6pt)
  cdraw.line((7.2, 0.5), (8.0, 0.5), stroke: luma(100), mark: (end: ">>"))
  pane(8.2, 16.0, 2.4, [the wire], [#"{"error":{..}}"], [no second writer exists])
})

== the json codec

One codec serves the whole vehicle, by ruling, and it is two halves in
one file. The writer is a builder over a caller's fixed buffer: it
tracks whether each open level is an object or an array and whether the
level has written a member yet, so the comma discipline cannot drift
and a value without a key refuses instead of producing broken bytes. A
refused append latches an oom flag the caller checks once at the end.
Strings escape the two mandatory quotes, the backslash, the five short
escapes, and `\u00xx` for the remaining control bytes, and every other
byte rides verbatim, which is what utf-8 payloads need.

The scanner is a recursive descent over slices of the input. String
values keep their escapes until a caller asks for them unescaped, and
the unescape pass is where `\uXXXX` decodes, surrogate pairs included,
into utf-8 on the way out. Two rulings shape it, both stated in the
file: numbers are integers, because every number the contract puts on
the wire is an integer, and duplicate member names are an error, the
strict reading of RFC 8259. The depth cap and the node pool are fixed
budgets, and a document past either refuses, because a bounded dom is
the whole point of hand-rolling one:

#listing("c-os-cloud/api/src/json.c", first: 112, last: 124, caption: [a key writes the comma it earned, a value slot opens once])

#diagram([the builder tracks level shape, the scanner keeps slices], length: 13pt, {
  cdraw.content((5.0, 8.1), [writer], size: 6.5pt)
  cdraw.rect((0.4, 4.4), (9.6, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 6.9), [one level, one kind bit], size: 6pt)
  cdraw.content((5.0, 5.9), [object waits for its key], size: 6pt)
  cdraw.content((5.0, 4.9), [array counts its items], size: 6pt)
  cdraw.content((16.0, 8.1), [scanner], size: 6.5pt)
  cdraw.rect((11.4, 4.4), (20.6, 7.4), fill: luma(228), radius: 0.02)
  cdraw.content((16.0, 6.9), [slices into the input], size: 6pt)
  cdraw.content((16.0, 5.9), [escapes intact until asked], size: 6pt)
  cdraw.content((16.0, 4.9), [fixed pool, depth capped], size: 6pt)
  cdraw.content((10.5, 3.4), [vector 01 and vector 03 bytes are exact, checked], size: 6pt)
})

== sockets and the thread pool

The listener is winsock2 and the decision this section owns is thread
per connection from a fixed pool, not an event loop. Every request in
this vehicle touches sqlite and the password tier of pbkdf2, work that
blocks a thread for milliseconds no matter what the io model says, so a
poller would buy nothing the pool does not already give. The chapter 18
event loop stays the right answer for timers and overlapped io the
vehicle does not run here. Eight workers, a 64-deep connection queue,
one SRWLOCK and one condition variable between them, and a full queue
closes the new socket because bounded is the policy, stated plainly.

The listen address comes from `CAPI_ADDR`, defaulting to port 8080, and
the read is `GetEnvironmentVariableA` rather than the crt's `getenv`
for a stated reason: the ucrt marks `getenv` a deprecated declaration
and this lane compiles with deprecations as errors, while kernel32's
own window onto the environment is already linked and warns nothing.
That is the platform-primitives answer this book prefers anyway, the
same reasoning that keeps the wall clock on `GetSystemTimeAsFileTime`.

Each worker owns one context for its whole life, allocated once on the
heap because it is megabytes: the request with its 1 MiB body, the
response, and the two wire buffers. Nothing in a request's path
allocates. The serve loop reads, parses, stamps a fresh request id,
dispatches, writes, and either keeps the connection alive with the
pipelined tail moved to the front of the buffer or closes it. Every
winsock call sits behind the io seam, a pair of function pointers for
recv and send, so the entire loop is tested with doubles and no socket
exists in any test. The condition-variable handoff is the chapter 16
lesson applied: the pusher wakes one waiter after the release, and the
lost-wake trap stays closed because the count is rechecked under the
lock:

#listing("c-os-cloud/api/src/http_server.c", first: 208, last: 228, caption: [the fixed queue: push under the lock, wake one, refuse when full])

#diagram([accept hands to the queue, a worker takes it], length: 13pt, {
  cdraw.rect((0.3, 5.0), (6.3, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 6.8), [listener], size: 6pt)
  cdraw.content((3.3, 5.8), [accept, forever], size: 6pt)
  cdraw.line((6.5, 6.2), (7.3, 6.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.5, 5.0), (13.5, 7.4), fill: luma(228), radius: 0.02)
  cdraw.content((10.5, 6.8), [the queue, 64 deep], size: 6pt)
  cdraw.content((10.5, 5.8), [one lock, one condvar], size: 6pt)
  cdraw.line((13.7, 6.2), (14.5, 6.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((14.7, 5.0), (21.3, 7.4), fill: luma(222), radius: 0.02)
  cdraw.content((18.0, 6.8), [8 workers], size: 6pt)
  cdraw.content((18.0, 5.8), [each owns one context], size: 6pt)
  cdraw.content((10.8, 4.0), [a full queue closes the socket: bounded is the policy], size: 6pt)
  cdraw.content((10.8, 2.9), [the io seam hides winsock from every test], size: 6pt)
})

== the composition root

The root is 18 lines and its shape is pinned for the rest of the part.
The seams come first, `capi_default_seams` installing the real wall
clock, the uuid v7 source, and the rand filler. Then `capi_wire_kernel`
fills any seam left null, validates the route table's patterns at
startup, and refuses to serve if a row is malformed, because a broken
table found at boot is a bug fixed in seconds and the same table found
at request time is an outage. Every family lands as one call between
the kernel wiring and the listener, in the order the middleware
chapter fixes, and `capi_run_tcp` is last so nothing can wire itself
after the server starts serving.

The seams themselves are function pointers with a context, the lane's
double mechanism, and the real sources are small enough to read whole.
The clock reads the system time once. The id source is uuid v7 over an
entropy pool seeded under an init-once gate from the performance
counter, the wall clock, and the process and thread ids, stepped by an
interlocked counter through splitmix64. That is an id source, not a
cryptographic one, and the authn chapter's tokens never draw from it:

#listing("c-os-cloud/api/src/main.c", first: 1, last: 18, caption: [the root: seams, kernel wiring, families, listener last])

#diagram([the pinned flow, families append in the middle], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.6, y), (10.0, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.3, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.3, y + 0.25), [#l1], size: 6pt)
  }
  stage(6.6, [default seams], [clock, ids, rand])
  stage(4.8, [wire kernel], [seam fill, table check])
  stage(3.0, [families append here], [outermost first, ch29 fixes order])
  stage(1.2, [run tcp], [listener last, always])
  cdraw.line((5.3, 6.5), (5.3, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((5.3, 4.7), (5.3, 4.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((5.3, 2.9), (5.3, 2.7), stroke: luma(100), mark: (end: ">>"))
  pane(12.4, 22.8, 6.0, [the seams], [#"fn pointer + context"], [tests inject fakes])
})

sources: RFC 9112 sections 2.2, 3, and 6 (request line and header
syntax, message body length, the content-length and transfer-encoding
rules), RFC 8259 (json grammar, string escapes, the duplicate-name
strictness), RFC 9562 section 5.7 (uuid v7 layout), RFC 7230 appendix
B (the tchar token alphabet), read 2026-09-27. winsock2 surface
verified against learn.microsoft.com windows sockets reference pages
for `accept`, `send`, `recv`, and `WSAStartup`, and the
`SleepConditionVariableSRW` and `InitOnceExecuteOnce` pages under
process and thread functions, all accessed 2026-09-27. Verified by the
kernel tests in `c-os-cloud/api/tests/test_kernel.c`, 74 checks over
the frozen vector bytes, the parser seeds, and the io doubles, under
`make verify-capi`.
