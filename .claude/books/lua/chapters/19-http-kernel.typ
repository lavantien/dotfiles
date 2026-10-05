#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= the http kernel

The game backend part of this book stands on one small module set:
the http kernel. The go book built its kernel over `net/http`, a
server the platform hands over, and lua has no such platform. What
it has is the c host from the capstone's own pattern: winsock owns
the listening socket and one server thread, everything past the wire
is lua. The host owns sockets, the kernel owns bytes: the request
line, the headers, the body, the route table, the error envelope,
the one json codec, the one response writer, and the composition
root each later family splices into.

== the seam and the handler shape

The seam between c and lua is five functions on a global table.
`net.recv` pulls up to 4096 bytes and answers an empty string both
for a closed peer and for an error, the one honest simplification a
blocking edge allows, and the kernel treats that empty string as
connection end. `net.send` pushes bytes and answers how many went,
`net.close` returns the socket to the os, and `net.addr` reads the
listen address. The fifth call grew with the part: `net.peer`
answers the connection's remote ip once per connection, and the
kernel stamps it on the request so the register route's rate key
reads an address without lua touching a socket. The host accepts one
connection at a time on its single server thread, so the service is
sequential by construction: one vm, no locks anywhere in the part,
stated once here and never defended again.

The handler shape follows from the seam. A handler is one function
of a request value returning a response value, and both are plain
tables. Because the response is a value, everything downstream reads
exactly what goes on the wire, and the go lane's status-capturing
writer wrapper, the trick an `http.ResponseWriter` architecture
needs, has no lua counterpart to get wrong. Handlers and layers
return responses or fail values, and the dispatch base renders fail
values through the one envelope writer, so outcomes ride values and
only bugs raise:

#listing("lua/service/main.lua", first: 80, last: 96, caption: [dispatch folds the layers over a base that renders failures inside the fold])

#diagram([the host hands over an fd, the kernel turns bytes into a value and back], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(6.2, [the c host, one thread], [#"accept, then handle(fd)"])
  cdraw.line((5.2, 6.1), (5.2, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(4.0, [read_request], [#"net.recv, request line, body"])
  cdraw.line((5.2, 3.9), (5.2, 3.3), stroke: luma(100), mark: (end: ">>"))
  stage(1.8, [dispatch], [layers over the route table])
  cdraw.content((17.6, 5.2), [one way in, one value out], size: 6pt)
  cdraw.content((17.6, 4.1), [#"net.send, net.close"], size: 6pt)
})

== bytes into a request

The parser reads from a callable, not a socket: `read_request(read)`
takes any function answering the next chunk, which is what makes the
whole kernel testable without a port, and the connection loop is the
only place that hands it the real seam. The grammar it accepts is a
deliberate subset. The request line must spell method, target, and an
`HTTP/1.0` or `HTTP/1.1` version, uppercase method letters, a target
that starts with a slash or is the asterisk, anything else answered
as a 400 envelope and a closed connection. Headers lowercase their
names and trim their whitespace.

Two rulings inside the head are worth their own sentences. A
repeated `Content-Length` or `Transfer-Encoding` is refused on
sight, agreeing or not, because a pair that disagrees is a request
smuggling attempt. And `Transfer-Encoding` present at all is
refused: this service speaks content-length bodies only, and a 400
envelope with a clear message beats a half implemented chunked
decoder. The body ladder then runs in a fixed order: an unparsable
length is a 400, a length past the contract's 1 MiB cap is a 413
answered without draining a byte, because reading a body you already
refused is work for the attacker, and a connection that ends
mid-body closes silently, a truncated request has no answer worth
sending:

#listing("lua/service/main.lua", first: 168, last: 186, caption: [the framing ladder: chunked refused, lengths validated, oversize never drained])

#diagram([the framing decision tree, every leaf an envelope or a closed connection], length: 13pt, {
  pane(0.4, 9.0, 7.6, [head arrives], [64 KiB cap, then parse], [request line grammar])
  cdraw.line((9.2, 6.9), (10.0, 6.9), stroke: luma(100), mark: (end: ">>"))
  pane(10.2, 17.2, 7.6, [line, version, header bad], [400 envelope, close], [one length, no encoding])
  cdraw.line((9.2, 5.2), (10.0, 5.2), stroke: luma(100), mark: (end: ">>"))
  pane(10.2, 17.2, 5.0, [duplicate or chunked], [400 envelope, close], [transfer-encoding refused])
  cdraw.line((9.2, 3.3), (10.0, 3.3), stroke: luma(100), mark: (end: ">>"))
  pane(10.2, 17.2, 3.1, [content-length], [unparsable: 400 close], [past 1 MiB: 413, no drain])
  cdraw.content((4.7, 1.9), [read exactly length bytes, eof early closes silently], size: 6pt)
})

== the route table

The router is hand rolled because lua has no mux to wrap, and the
decomposition is the lesson. A pattern compiles into a list of
segments, each a literal or a named param, whole segments only: a
param takes exactly one non-empty path segment, so a trailing slash
never reads as a blank id and `/a/b` never matches `/a/b/`. Percent
escapes decode after the split, per segment, so an encoded slash
cannot manufacture a separator the router never saw. Registration
time is where ambiguity dies: two same-method patterns of equal
length with equal per-side literal counts can both match some
request with neither strictly more specific, and that pair is
refused the moment it registers, exact duplicates included.

Matching walks the table once. Every entry whose segments fit the
path contributes, the fittest same-method entry wins, most literals
first, and the methods that fit the path but not the request collect
into the sorted allow set the 405 answer carries. The winning entry
stamps the request with its own pattern string and its params, the
part the authz family needs later: policies key on
`/api/users/{id}`, not on whatever path shape arrived. The 404 and
the 405 are values returned, never errors raised:

#listing("lua/service/router.lua", first: 34, last: 48, caption: [compile: patterns decompose into literal and param segments])

#diagram([compile once at registration, fit every request, refuse the ties], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 5.0), (x0 + 6.4, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 3.2, 6.6), [#title], size: 6pt)
    cdraw.content((x0 + 3.2, 5.6), [#l1], size: 6pt)
  }
  step(0.3, [pattern], [#"GET /api/users/{id}"])
  cdraw.line((6.9, 6.1), (7.3, 6.1), stroke: luma(100), mark: (end: ">>"))
  step(7.3, [compile, register], [ties refused on the spot])
  cdraw.line((6.0, 4.9), (6.0, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(1.0, 11.2, 4.1, [fit at request time], [same length, non-empty parts], [literals equal, params fill])
  pane(13.0, 23.6, 1.2, [the three answers], [a route, 405 with allow], [or a plain 404])
})

== the error envelope

The contract freezes one failure shape for the whole api, two levels
deep: an error object with a code from a closed set of eleven, one
human sentence, optional details on `validation_failed` only, and
the request id. The kernel owns the set and the mapping in one
table, code to status, and the two split codes pass their status
explicitly at the split site: `invalid_json` rides 400 for a
malformed body and 415 for a wrong media type, `not_found` rides 404
and 405. The `fail` constructor refuses an unknown code and refuses
details off `validation_failed`, both at construction, so a bad fail
cannot reach the wire. Unknown failures are coerced to `internal`
with the detail kept for the log, because a leaked store error tells
a client more than it should know.

One writer renders every failure body, member order fixed by
construction: code, message, details when present, request_id. The
request id resolves once at the edge: a value already carried wins,
else a client header that parses as a uuid echoes canonicalized to
lower case, else the injected source mints one. Garbage is replaced,
never echoed:

#listing("lua/service/envelope.lua", first: 68, last: 79, caption: [render: the one envelope writer, member order fixed by construction])

#diagram([eleven codes, one table, two split sites pass their status explicitly], length: 13pt, {
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

Book 8 at 4.0 owns no json encoder, so the service rolls its own and
this chapter is the book's home for encoding discipline. The decoder
is a position scanner, recursive descent over the string, strict the
way input deserves: duplicate members, trailing garbage, control
bytes, and lone surrogates all refused, a depth cap at 100 nesting
levels, every error carrying its byte offset. Numbers keep lua's
integer subtype, `1790830800` decodes as an integer and `1e3` as a
float, and integers that overflow int64 land as floats, the only
honest reading.

The encoder's discipline is construction. A lua table's string keys
carry no iteration order, so bodies are built as ordered member
lists, `json.object` with a flat name value sequence, and the
encoder renders exactly that order. The same metatable that carries
the order marks decoded objects, so re-encoding a decoded body is a
fixed point, the canonical idempotence the vector tests run: encode
of decode of encode is byte stable. A plain string keyed table is
refused at the encoder, not silently reordered, and the empty plain
table is refused as ambiguous. Stock 5.5 ships no `string.buffer`,
that is the luajit extension, so both directions build over
`table.concat`, one join:

#listing("lua/service/json.lua", first: 24, last: 37, caption: [object: ordered members by construction, duplicates refused here too])

#diagram([decode tags what it builds, encode renders only what construction ordered], length: 13pt, {
  pane(0.3, 7.0, 7.4, [wire bytes in], [#"{'code':'conflict',...}"], [untrusted input])
  cdraw.line((3.65, 5.3), (3.65, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 7.0, 4.2, [decode], [position scanner], [order kept in the metatable])
  cdraw.line((3.65, 2.3), (3.65, 1.4), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 7.0, 1.2, [value out], [tables that know], [their member order])
  pane(12.4, 19.4, 7.4, [construction in], [#"json.object flat list"], [order is the call's order])
  cdraw.line((15.9, 5.3), (15.9, 4.4), stroke: luma(100), mark: (end: ">>"))
  pane(12.4, 19.4, 4.2, [encode], [integers without a dot], [refuses unordered tables])
  cdraw.content((15.9, 1.6), [canonical out, one join], size: 6pt)
})

== writing the response

One site writes every response. `render_response` takes the response
value and the connection's keep decision and answers bytes: a status
line with the standard reason phrase, the response's own headers in
construction order, a content length except on the two bodyless
statuses, and an explicit `Connection` line on every answer so the
lifecycle is stated, never implied. The 204 and the 304 carry no
body and no length, and the byte shape of a whole answer is asserted
exactly in the tests:

#listing("lua/service/main.lua", first: 215, last: 230, caption: [render_response: the single write site, the lifecycle always stated])

#diagram([a response value becomes bytes once, in one place], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.6), (x0 + 7.4, 6.8), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 3.7, 6.2), [#title], size: 6pt)
    cdraw.content((x0 + 3.7, 5.2), [#l1], size: 6pt)
  }
  step(0.3, [response value], [status, headers, body])
  cdraw.line((7.9, 5.7), (8.3, 5.7), stroke: luma(100), mark: (end: ">>"))
  step(8.3, [status line], [#"HTTP/1.1 201 Created"])
  cdraw.line((15.9, 5.7), (16.3, 5.7), stroke: luma(100), mark: (end: ">>"))
  step(16.3, [headers, length, connection], [then the body bytes])
  cdraw.content((11.5, 2.2), [204 and 304 skip the length and the body], size: 6pt)
  cdraw.content((11.5, 1.1), [the fd closes in every path], size: 6pt)
})

== the kernel routes and the root

The kernel owns two routes. `GET /healthz` answers liveness with the
status and the build version, injected through the app config so a
deployment can prove what it runs. `GET /readyz` answers readiness,
ok while the injected probe says ready and the envelope's `overload`
code at 503 the moment it does not, the hook the drain wiring in the
load chapter flips.

The composition root is `main.lua`, and this chapter's commit is the
last time this file changes shape under this stream. It is the only
file in the service tree that reads the wall clock or draws
randomness: the clock is `os.time`, whole seconds, and the id mint
is a uuid v7 built from that clock times 1000 plus random bits, so a
minted timestamp ticks once a second and the random half carries the
uniqueness. Every module below the root receives clock and id
callables, and no test ever sleeps. The four middleware layers of
chapter 20 wire here in request order, and the families have been
landing below their markers as their chapters ship: the metrics
layer and the limiter sit between the access log and the deadline,
the identity layer and the resource families sit innermost with
their routes, and the rail closed at the ship marker, the drain
that flips the readyz probe and the reports pair among them:

#listing("lua/service/main.lua", first: 242, last: 253, caption: [the root: the builder over injected seams, the two edge layers inside it])

#diagram([the root as a wiring rail: the families land at their markers in request order], length: 13pt, {
  let row(y, l1, l2, hot) = {
    cdraw.rect((1.8, y), (21.6, y + 1.4), fill: hot, radius: 0.02)
    cdraw.content((11.7, y + 0.95), [#l1], size: 6pt)
    cdraw.content((11.7, y + 0.25), [#l2], size: 6pt)
  }
  row(6.8, [request id, access log], [ch20 layers, wired], luma(235))
  row(5.2, [metrics, the bucket], [metrics and limit landed, no admission layer], luma(245))
  row(3.6, [deadline, recover], [ch20 layers, wired], luma(235))
  row(2.0, [identity, store, conc, cache, authz, users], [the resource families landed at their markers], luma(245))
  row(0.4, [ship], [drain and compose, the reports pair over the oracle], luma(245))
  cdraw.rect((1.8, -1.4), (21.6, 0.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.7, -0.7), [the kernel: seams, routes, envelope, json, the write site], size: 6pt)
})

== what the kernel proves

The numbers first, from the tree this chapter landed on: 12 module
tests in `main.lua`, 9 in json, 9 in envelope, 10 in router, and 29
checks in the wire driver against the compiled host, every lane
green. What the kernel proves is that the part's shape is fixed: the
envelope renders every failure, the decode ladder hands every write
route its refusals, the route table refuses its own ambiguities and
carries its patterns, and the root's markers say where every family
lands. From here the part is additive, and the driver is the proof
that runs on every commit:

#listing("lua/service/tests/drivers/kernel.lua", first: 32, last: 41, caption: [the wire driver: exact status, exact bytes, over the real host])

#diagram([every later chapter adds routes or layers, none rewrites the kernel], length: 13pt, {
  let row(y, l1, l2) = {
    cdraw.rect((0.6, y), (22.6, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((11.6, y + 0.95), [#l1], size: 6pt)
    cdraw.content((11.6, y + 0.25), [#l2], size: 6pt)
  }
  row(6.8, [ch19 kernel, done], [bytes, routes, envelope, json, the write site, the root])
  row(5.1, [ch20 middleware], [chain, request id, access log, the resume gate, recover])
  row(3.4, [ch21 to ch23 the resource and its gates], [users, passwords, sessions, tokens, roles])
  row(1.7, [ch24 to ch31], [store, interleaves, cache, buckets, metrics, load, ship, suite])
  cdraw.rect((0.6, -0.2), (22.6, 1.2), fill: luma(225), radius: 0.02)
  cdraw.content((11.6, 0.3), [the contract, held throughout], size: 6pt)
  cdraw.content((11.6, -0.5), [16 frozen vectors, the driver asserts the kernel slice], size: 6pt)
})

sources: the lua 5.5 manual at lua.org/manual/5.5, sections 3.1 on
the integer and float subtypes, 6.1 on tostring number formatting,
6.4.1 on string patterns, 6.5 on utf8.char, 6.7 on math.random, and
6.9 on os.time, accessed 2026-09-27. RFC 9112 sections 2.2, 2.3, and
6.3 on the request line, message parsing, and content length,
RFC 9110 section 15.5.5 on 405 and the allow header, RFC 8259 on the
json grammar, and RFC 9562 section 5.7 on the v7 layout, accessed
2026-09-27. Verified against `go/api/internal/httpx/kernel.go`,
`python/api/pyapi/kernel.py`, and `c-os-cloud/api/api.h`, and by the
kernel family's own gates: 40 module tests across json, envelope,
router, and main, and 44 host lane checks across the kernel, mw, and
smoke drivers, both lua lanes green.
