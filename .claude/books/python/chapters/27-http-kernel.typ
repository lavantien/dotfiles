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

Everything else in this service part sits on one small module: the
http kernel. Python's standard library ships no router, no error
envelope, no middleware, and that lack is why this part exists:
`http.server` parses one request off a socket and calls a method
named after the verb, everything above that is ours to build in the
open. This chapter builds `pyapi/kernel.py`: value shaped requests
and responses, the hand rolled route table as the spine, the
contract envelope with exactly one success writer and one failure
writer, the json codec configured so the frozen vector bytes match,
the request id on its contextvar, and a socket adapter thin enough
that everything above it tests as function calls.

== the handler shape on http.server

The platform's server is a composition of small classes, one job
each: `socketserver.BaseServer` drives the serve loop, `TCPServer`
owns the listening socket and the accept, `ThreadingHTTPServer` is
`socketserver.ThreadingMixIn` layered over `HTTPServer` so one
handler instance per request runs on its own daemon thread, and the
handler parses the request line and headers into an
`email.message.Message`. That last fact is worth pinning: the
platform's own header parsing is the email module, and this chapter
reuses the same machinery for media types instead of hand parsing.

`BaseHTTPRequestHandler` dispatches by name, it looks up `do_` plus
the verb, and a missing method answers a plain text 501 page. Both
defaults break the contract, which puts every non-2xx in the
envelope. The adapter owns them by shape rather than enumeration:
`__getattr__` returns the one `_handle` method for any `do_` name,
so TRACE reaches the router and gets the 405 envelope, and a test
pins that against a live socket. Above the adapter sits the kernel's
own contract: `dispatch` takes a `Request` of plain values and
returns a `Response` of plain values, handlers raise `APIError`
instead of writing a failure, and the adapter is the only code that
touches `rfile` or `wfile`:

#listing("python/api/pyapi/kernel.py", first: 377, last: 397, caption: [the adapter reads the wire into values and writes the response back])

The adapter caps its body read at one megabyte plus one byte, so a
lying content length never buffers past the cap before the decode
ladder rejects the body. The wire's own garbage gets its own answers:
a content length that does not parse, or parses negative, is a 400
with the connection closed rather than a blocked read or a thread
parked on `read(-1)`, the socket carries a five second read timeout
so an idle connection cannot hold its handler forever, and any
request that leaves input unread, an oversize body or a request
without a content length at all, closes the connection after its
answer, because a keep-alive socket with bytes still in it desyncs
the next request line. Responses carry `Content-Length` on every
body, which keeps the `HTTP/1.1` keep alive framing honest, and 204
with 304 send neither body nor length because the protocol forbids
both. The platform's `log_message` default writes plain lines to
stderr, and the adapter silences it: request logging belongs to the
access log layer in the next chapter.

#diagram([the platform stack, and the adapter owns the answers the platform would get wrong], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(6.2, [BaseServer over TCPServer], [#"serve_forever, socket, accept"])
  cdraw.line((5.2, 6.1), (5.2, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(4.6, [ThreadingMixIn over HTTPServer], [a thread per request, headers parsed])
  cdraw.line((5.2, 4.5), (5.2, 3.9), stroke: luma(100), mark: (end: ">>"))
  stage(3.0, [#"_Handler"], [#"do_* by getattr, rfile to values"])
  cdraw.line((5.2, 2.9), (5.2, 2.3), stroke: luma(100), mark: (end: ">>"))
  stage(1.4, [App.dispatch], [values in, values out])
  pane(11.5, 23.0, 5.6, [the owned answer], [TRACE: envelope 405,], [not the plain 501 page])
})

== the route table, hand rolled

Go's standard mux grew method patterns and precedence in 1.22, and
python's `http.server` never had a router at all, so the table is
hand rolled and its decomposition is the chapter's spine. A pattern
is a path with whole segment parameters, `/api/users/{id}`. Compile
splits it into a tuple of segments, each a literal or a parameter
name, and rejects a brace anywhere else in a segment, so parameters
are segments or nothing. Matching walks the compiled tuple against
the path's segments: lengths agree, a literal equals its part, and
a parameter takes exactly one non empty segment, never an empty
one, which is why `/api/users/` with its trailing slash is a 404
rather than a user lookup with a blank id.

Precedence is one rule: when two same method patterns fit one path,
the one with more literal segments wins. Two patterns that tie,
equal shape with equal literal counts, can never disambiguate a
request, so `route` raises `ValueError` at registration and an
ambiguous table never ships, the ruling the go lane gets from its
mux panicking at registration. The 404 and 405 split falls out of
the same lookup: a path no pattern fits is `not_found` at 404, a
path other methods fit is `not_found` at 405 plus `Allow`, because
the code set is closed at eleven and the message plus `Allow` carry
the distinction:

#listing("python/api/pyapi/kernel.py", first: 295, last: 314, caption: [the lookup: most specific wins, other methods yield the allow set])

The table has one property worth more than any example, matching
never depends on registration order. The suite pins it with a
seeded `random.Random(2026)` loop, two hundred shuffles of one five
pattern table, asserting the same handler answers the same paths
every time, and the tie check is what makes the property hold.

#diagram([literals beat parameters, ties raise at registration, leftovers split into 405 and 404], length: 13pt, {
  cdraw.rect((0.3, 5.6), (7.2, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((3.75, 6.7), [#"/api/users/{id}"], size: 6pt)
  cdraw.content((3.75, 5.95), [#"/api/users/me"], size: 6pt)
  cdraw.content((3.75, 5.15), [both fit, the literal wins], size: 6pt)
  cdraw.line((7.4, 6.3), (8.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.6, 5.6), (15.5, 7.1), fill: luma(225), radius: 0.02)
  cdraw.content((12.05, 6.7), [more literals, more specific], size: 6pt)
  cdraw.content((12.05, 5.95), [a tie is a conflict], size: 6pt)
  cdraw.content((12.05, 5.15), [and raises at registration], size: 6pt)
  pane(0.3, 9.6, 2.6, [other methods fit], [405, envelope plus Allow], [#"Allow: GET, POST"])
  pane(12.6, 21.9, 2.6, [nothing fits], [404, envelope], [route not found])
})

== the error envelope

The contract freezes one failure shape for the whole api: an error
object carrying a code from a closed set of eleven, one human
sentence, an optional `details` array on `validation_failed` only,
and the request id. Every non-2xx rides it, including the 404 and
405 the lookup owns, the 422 the user chapter adds, the 429 and 503
the rate and load chapters add. The codes are declared once as
module constants and `CODE_STATUS` is the single table mapping each
to the status it carries everywhere, so the day a status needs to
move the code does not.

Two codes are split across statuses and each split site passes its
status explicitly: `invalid_json` rides 400 on a malformed body and
415 on a wrong media type, `not_found` rides 404 and 405. `at` is
the one sanctioned override, it returns the same error carrying the
explicit status. `fail` also enforces the details rule at
construction, it raises `ValueError` when details ride any code but
`validation_failed`, so the one exception to their absence cannot
happen by accident. One failure writer builds the envelope, and the
dict literal orders `code`, `message`, then `details` when present,
then `request_id`, the member order the go lane's struct fields
freeze:

#listing("python/api/pyapi/kernel.py", first: 155, last: 165, caption: [the one failure writer: nested two levels, details between message and request_id])

Handlers raise `APIError` rather than writing a failure, and
`dispatch` catches it at the innermost layer, which is where go had
two channels python has one: a returned error and a panic are both
exceptions here, so the mapping is by class. `APIError` is the
handled failure with contract shape, any other exception is a bug,
and converting bugs into envelopes is the recover layer's job in
the next chapter. The kernel tests pin the boundary: an `APIError`
becomes the envelope, a `RuntimeError` propagates untouched.

#diagram([eleven codes, eleven statuses in the table, thirteen on the wire], length: 13pt, {
  let cell(xc, ytop, code, status, hot) = {
    cdraw.rect((xc - 3.5, ytop - 1.7), (xc + 3.5, ytop), fill: hot, radius: 0.02)
    cdraw.content((xc, ytop - 0.6), [#code], size: 6pt)
    cdraw.content((xc, ytop - 1.4), [#status], size: 6pt)
  }
  cell(3.9, 7.4, [invalid_json], [400, and 415], luma(225))
  cell(11.9, 7.4, [validation_failed], [422], luma(235))
  cell(19.9, 7.4, [payload_too_large], [413], luma(235))
  cell(3.9, 5.2, [unauthorized], [401], luma(235))
  cell(11.9, 5.2, [forbidden], [403], luma(235))
  cell(19.9, 5.2, [not_found], [404, and 405], luma(225))
  cell(3.9, 3.0, [conflict], [409], luma(235))
  cell(11.9, 3.0, [precondition_failed], [412], luma(235))
  cell(19.9, 3.0, [rate_limited], [429], luma(235))
  cell(3.9, 0.8, [overload], [503], luma(235))
  cell(11.9, 0.8, [internal], [500], luma(235))
})

== json in and out

Bodies go out through one success writer whose three settings are
the whole byte contract. `json.dumps` with `separators` of comma
and colon emits no spaces, `ensure_ascii=False` lets non ascii text
ride as utf8 instead of `\\u` escapes, and `.encode()` fixes the
wire as bytes. Dict literal order is insertion order, so the
literal mirrors the go struct field order the vectors were cut
from, and the vectors are byte authoritative: this chapter's tests
pin the healthz body and a non ascii payload as exact bytes, so any
drift in writer settings is a red test here.

Reading is stricter than writing, because request bodies are input.
`read_json` is the one decode path, three rules in a fixed order.
The media type comes from `email.message.Message` with the header
value installed on it, the same parser the platform's own header
reading uses, and `get_content_type` strips parameters, so
`application/json; charset=utf-8` passes while anything else,
including a missing header which falls to the parser's text/plain
default, is 415 `invalid_json`. The body is then checked against
the one megabyte cap, and oversize is always `payload_too_large` at
413, never `invalid_json`, the binding ruling. What survives goes
to `json.loads`, which accepts bytes and detects the encoding
itself, and a malformed body is 400 `invalid_json`. Field
validation is the user chapter's concern, this ladder only decides
whether the body is json at all:

#listing("python/api/pyapi/kernel.py", first: 177, last: 188, caption: [the decode ladder: 415 wrong type, 413 past one mib, 400 malformed])

#diagram([two writers, one decode path, four contract statuses], length: 13pt, {
  pane(0.3, 6.6, 7.2, [handler value], [dict, list, int], [marshal safe by design])
  cdraw.line((3.45, 4.6), (3.45, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 6.6, 3.4, [success], [compact, utf8,], [content type set])
  pane(8.0, 14.3, 7.2, [request body], [bytes off the wire], [untrusted input])
  cdraw.line((11.15, 4.6), (11.15, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.0, 1.7), (14.3, 3.4), fill: luma(225), radius: 0.02)
  cdraw.content((11.15, 2.8), [media type check], size: 6pt)
  cdraw.content((11.15, 1.95), [else 415 invalid_json], size: 6pt)
  cdraw.content((18.9, 5.9), [then the one mib cap], size: 6pt)
  cdraw.content((18.9, 4.8), [past it: 413 too large], size: 6pt)
  cdraw.content((18.9, 3.7), [then json.loads: 400], size: 6pt)
  cdraw.content((3.45, 2.4), [the one failure writer], size: 6pt)
  cdraw.content((3.45, 1.3), [failure, always the envelope], size: 6pt)
})

== the request id

Every request needs one id that every artifact agrees on: the access
log line, the error envelope, the panic log. The ruling carrier is
`contextvars`, one `ContextVar` with a default of `None`, set and
reset through its token by the request id layer in the next chapter.
A thread local would not do, because the deadline layer runs the
handler on a worker thread, and a thread local set on the serving
thread would read empty there, where a context copied into the
thread carries the value through.

Resolution happens once, in a fixed order: the contextvar when the
middleware has run, else the client's `X-Request-ID` when the value
parses as a uuid, else a fresh id from the injected source. Parsing
is contract, not politeness: the envelope promises `request_id` is a
uuid, and a free text header echoed into logs is log injection.
`uuid.UUID` accepts the braced, urn, and bare hex spellings and
`str` normalizes them to the dashed form, and garbage raises
`ValueError` and is replaced by the mint, never echoed. The mint is
`uuid.uuid7`, time ordered the way the store chapter's ids are, and
it is a parameter, so the vector replays in later chapters inject
their fixed ids through the request id layer rather than reaching
into the kernel. The token pair is the hygiene rule:
`reset_request_id` puts the context back exactly as it was, the
layer's `finally` owns the reset, and a test pins the leak, after a
dispatched request `current_request_id` is `None` again:

#listing("python/api/pyapi/kernel.py", first: 138, last: 152, caption: [resolve once: contextvar, then a parseable header, then the mint])

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
  step(11.5, [contextvar plus header], [one value, two surfaces])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [downstream], [handler, logs, envelope])
  pane(9.9, 18.4, 3.4, [error envelope], [request_id member], [a uuid, always])
  cdraw.content((11.5, 3.3), [garbage headers are replaced, never echoed], size: 6pt)
})

== testing the kernel without a socket

Go has `httptest` and this lane has something better for most of the
suite: responses are values. A test builds a `Request` the way the
adapter would, calls `app.dispatch`, and asserts on the `Response`
it gets back, status, headers, exact body bytes. Nothing listens,
so there is no port to collide with and no timing, the round trip
is a function call in the test's own thread.

The adapter is the only code that touches a socket, and it earns
six tests over a real loopback listener: `make_server` binds
`127.0.0.1` on port 0, the operating system picks a free port, a
thread runs `serve_forever`, and the test's `urllib` call blocks on
the response, never on a sleep. The round trip proves the HTTP/1.1
framing, the post test the read path, the 404 and 405 tests the
envelope on the wire with `Allow`, and the TRACE test the every
method rule. Cleanup is ordered, stop the loop, close the listener,
join the thread, and cleanups run last in first out:

#listing("python/api/tests/test_kernel.py", first: 312, last: 333, caption: [values in, values out: exact bytes asserted, no listener involved])

The property loop is the suite's own mechanism, a seeded
`random.Random` over a named invariant, no property library. The
router's invariant is order independence, two hundred shuffled
registrations of the same five patterns answer the same paths with
the same handlers. Zero tests are skipped and zero sleep, the two
rules the whole lane runs under.

#diagram([build, dispatch, assert: one function call, and the adapter's five socket tests], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [build a Request], [method, path, headers, body])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [app.dispatch], [route, layers, handler])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [assert on Response], [status, headers, exact bytes])
  pane(0.3, 11.0, 3.4, [adapter tests], [loopback port 0,], [six round trips])
  pane(12.0, 22.8, 3.4, [the property loop], [#"random.Random(2026), 200"], [shuffles, one invariant])
})

== the app skeleton and its wiring table

The kernel also ships the program skeleton. `Config` is the config
hub, listen address, build version, and a readiness probe, and
`from_env` reads `GOAPI_ADDR` with `GOAPI_VERSION`, names kept for
compose parity with the go and c\# lanes running the same contract.
The two kernel routes are the deployment contract: `GET /healthz`
answers liveness with the version from config so a deployment can
prove what it is running, and `GET /readyz` answers readiness, 200
while the probe agrees and the envelope's `overload` code at 503 the
moment it does not, the hook the load chapter's drain wiring flips.
`route` registers with the tie check every family inherits, `use`
appends a middleware layer first used outermost, and `serve` runs
`serve_forever` on a `ThreadingHTTPServer` subclass that carries
the app to its handler instances:

#listing("python/api/pyapi/kernel.py", first: 253, last: 272, caption: [the app registers its two routes with the tie check every family inherits])

`main.py` is the composition root, one `build_app` function the
integrator owns and every family appends its wiring to, mirroring
the go lane's `main.go` and `wire.go` split: a construction, the
middleware stack in wiring order, then one registration block per
family. Each later chapter lands as a few lines inside `build_app`
and nothing in this module changes.

The framework story is one sentence, said the way every chapter of
this part says it: the stdlib primitive comes first, the framework
family is composition over those primitives plus dated meta,
#xref-to("python", "fastapi") being the teaching home for fastapi
with flask and django beside it. Nothing here imports any of them,
the maintenance risk rationale runs in the suite chapter, and the
platform surface already carries the weight: the router, the
envelope, and the codec above are the primitives those frameworks
would wrap.

#diagram([the part as six rows: every chapter adds routes or layers, none rewrites the kernel], length: 13pt, {
  let row(y, l1, l2) = {
    cdraw.rect((0.6, y), (22.6, y + 1.5), fill: luma(235), radius: 0.02)
    cdraw.content((11.6, y + 1.0), [#l1], size: 6pt)
    cdraw.content((11.6, y + 0.25), [#l2], size: 6pt)
  }
  row(6.8, [ch27 kernel, done], [envelope, route table, codec, request id, adapter])
  row(5.1, [ch28 middleware], [chain, ids, access log, deadline, recover])
  row(3.4, [ch29-31 the resource and its gates], [users, pbkdf2, sessions, jwt, roles])
  row(1.7, [ch32-34 the data plane], [sqlite store, transactions, etags, cache])
  row(0.0, [ch35-37 the operations plane], [token buckets, logs and traces, load, drain])
  row(-1.7, [ch38-39 ship and suite, the contract throughout], [image, compose, ci, 16 frozen vectors])
})

sources: docs.python.org for http.server, socketserver, contextvars,
email.message, json, uuid, urllib.parse, and unittest, accessed
2026-09-27, with the `ThreadingHTTPServer` composition read off its
method resolution order in the pinned 3.14 interpreter and the
`get_content_type` default probed there the same day. Verified by
`pyapi` tests, 42 of them over `kernel.py` in `tests/test_kernel.py`,
plus the verify-pyapi gates: unittest discovery, compileall over the
vehicle, and ruff under the book's frozen config.
