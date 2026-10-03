#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= api kernel

Everything else in this service part sits on one small package, the same
position the go book's `httpx` holds there. This chapter builds it in
`books/javascript/api/src/kernel/`: the handler contract every route
shares, the hand-rolled route table with method plus `:param` patterns,
the constant error envelope every non-2xx response answers with, the
`JSON.stringify` wire codec and its one decode path, request ids born
once at the edge, and the composition file later chapters wire into.
The vehicle is bare `node:http` on node 26 with zero packages, every
ruling below probed on 26.3.0 first.

== the handler contract

A kernel handler is one async function of one context object, plain
data: `req`, `res`, the `params` the router fills, the `query` as a
`URLSearchParams`, the request `id`. A handler that fails throws an
`ApiError` instead of writing a failure body, so no route formats an
envelope by hand and no route can answer a 500 with the wrong shape.
That is the go contract, but the mechanics differ because the error
channel differs: go handlers return an error value
and an adapter converts it, while an escaped rejection in node is an
`unhandledRejection`, which kills the process. The kernel's root
handler therefore owns a try/catch at the dispatch boundary, part
contract conversion, part survival guarantee:

#listing("javascript/api/src/kernel/kernel.mjs", first: 30, last: 46, caption: [the root handler: ctx birth, the fold, the backstop conversion])

The backstop renders through the one failure writer everything else
uses, so a stack without the next chapter's adapter still answers in
shape. It cannot log, the kernel holds no logger: conversion with
logging is the middleware layer's job, the backstop is the net.

#diagram([the request climbs down the stack, a failure climbs back as a rejection], length: 13pt, {
  cdraw.content((5.2, 7.7), [request path], size: 6.5pt)
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(5.9, [root handler], [#"id, ctx, try/catch"])
  cdraw.line((5.2, 5.8), (5.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(3.7, [middleware stack], [ch24, folded outermost first])
  cdraw.line((5.2, 3.6), (5.2, 3.0), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [router], [pattern match, params])
  cdraw.line((5.2, 1.4), (5.2, 0.8), stroke: luma(100), mark: (end: ">>"))
  stage(-0.7, [route handler], [#"writes 2xx, or throws"])
  cdraw.content((17.5, 7.7), [failure path], size: 6.5pt)
  cdraw.line((19.5, 0.3), (19.5, 2.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((16.2, 1.2), [#"throw fail(..)"], size: 6pt)
  cdraw.content((17.5, 3.6), [the rejection climbs as a value,], size: 6pt)
  cdraw.content((17.5, 2.5), [the first catcher answers in shape], size: 6pt)
})

== the route table

Node ships no router, only `createServer` with one request callback,
and the platform ruling is that the gap is filled bottom-up rather than
by adopting express. `createRouter` holds one flat array of routes,
each pattern compiled once into segments where a `:name` segment
becomes a parameter slot. Dispatch splits the percent-decoded path,
filters the table, then picks the most specific method match.
Specificity is one bit per segment, static beats param, compared left
to right, and that vector totally orders any candidate set matching
one path: two patterns with equal scores on the same path have the
same statics everywhere, the same pattern twice. The go mux's
registration-time tie panic has no js counterpart because the tie is
unrepresentable:

#listing("javascript/api/src/kernel/router.mjs", first: 90, last: 110, caption: [dispatch: path candidates, the specific method match wins, 405 carries Allow])

Two unmatched answers stay inside the contract. An unknown path is 404
as the envelope, and a known path with the wrong method is 405, also as
the envelope, plus the `Allow` header the table computed with `HEAD`
added wherever `GET` lives. Both carry the code `not_found` because the
code set is closed at eleven, the message plus `Allow` carrying the
distinction, a ruling every lane inherits. A `HEAD` request dispatches
to the `GET` handler because node itself suppresses the body on `HEAD`,
verified on the probe server: the handler calls `end` with bytes and
the client reads zero. Trailing slashes and malformed percent escapes
answer 404 rather than redirecting or throwing.

#diagram([static beats param, ties are unrepresentable, leftovers split into 405 and 404], length: 13pt, {
  cdraw.rect((0.3, 5.6), (7.2, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((3.75, 6.7), [#"GET /api/users/:id"], size: 6pt)
  cdraw.content((3.75, 5.95), [#"GET /api/users/reports"], size: 6pt)
  cdraw.content((3.75, 5.15), [both match, static wins], size: 6pt)
  cdraw.line((7.4, 6.3), (8.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.6, 5.6), (15.5, 7.1), fill: luma(225), radius: 0.02)
  cdraw.content((12.05, 6.5), [one bit per segment], size: 6pt)
  cdraw.content((12.05, 5.7), [a tie means one pattern, no panic], size: 6pt)
  cdraw.line((15.7, 6.3), (16.7, 6.3), stroke: luma(100), mark: (end: ">>"))
  pane(16.9, 22.8, 7.1, [handler], [the most specific], [method match])
  cdraw.line((12.05, 5.0), (12.05, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.05, 3.7), [path matches, method does not], size: 6pt)
  pane(0.3, 9.6, 2.6, [405, envelope plus Allow], [#"Allow: GET, HEAD, PATCH"], [code stays not_found])
  pane(12.6, 21.9, 2.6, [404, envelope], [nothing matches], [malformed escape too])
})

== the error envelope

The contract freezes one failure shape for the whole api: an `error`
object with a `code` from a closed set of eleven, one human sentence,
an optional `details` array on `validation_failed` only, and the
request id. The set and the status table live in `codes.mjs`, the
table the source of truth, the code names derived from its keys. Two
codes are split: `invalid_json` rides 400 and 415, `not_found` rides
404 and 405, and each split site passes its own status the way the 405
site did.

The writer is one function and the member order is the contract's
order, `code`, `message`, `details` when present, `request_id`. That
order is the byte order the golden vectors freeze, and the tests pin it
against vector 05: the writer fed the vector's own code, message, and
frozen request id must emit the vector's exact body bytes. An unknown
thrown value renders as `internal` with the detail kept off the wire,
because a leaked `sqlite: database is locked` says too much:

#listing("javascript/api/src/kernel/envelope.mjs", first: 36, last: 47, caption: [the one failure writer: classify, order the members, delegate to the success writer])

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
  pane(15.9, 23.4, 0.8, [shaded cells], [the split codes: one code,], [two statuses, site passes it])
})

== the wire codec

The encoder is `JSON.stringify` and the dto discipline is the object
literal itself. Javascript specifies insertion order for string keys,
so a literal in the contract's member order serializes in that order,
keys hand-named in snake_case, timestamps preformatted as the RFC 3339
strings the vectors freeze.

Reading is stricter than writing because request bodies are input.
`readJson` is the one decode path and enforces three rules in a fixed
order, each a thrown `ApiError`: the media type must be
`application/json` with parameters allowed, so a charset suffix passes
and anything else is 415 `invalid_json` before a single body byte is
read, a fact the codec test proves with a request double whose
iterator fails the test if it runs. The body then streams through a
`for await` over the request, counted per chunk against the contract's
1 MiB cap, and a body past it is 413 `payload_too_large`, always, never
`invalid_json`. What survives goes to `JSON.parse`, and bytes that do
not parse are 400 `invalid_json`:

#listing("javascript/api/src/kernel/codec.mjs", first: 20, last: 42, caption: [readJson: 415 before the first byte, 413 past 1 MiB, 400 on parse, a keyed layer's stash reused])

#diagram([two write sites through one writer, one decode path, four contract statuses], length: 13pt, {
  pane(0.3, 6.6, 7.2, [handler value], [#"object literal"], [insertion order is the dto])
  cdraw.line((3.45, 4.6), (3.45, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 6.6, 3.4, [writeJson], [status, content type,], [stringify, end])
  pane(8.0, 14.3, 7.2, [request body], [bytes from the wire], [untrusted input])
  cdraw.line((11.15, 4.6), (11.15, 3.6), stroke: luma(100), mark: (end: ">>"))
  let step(y, l1, l2, fill) = {
    cdraw.rect((8.0, y - 1.7), (14.3, y), fill: fill, radius: 0.02)
    cdraw.content((11.15, y - 0.6), [#l1], size: 6pt)
    cdraw.content((11.15, y - 1.4), [#l2], size: 6pt)
  }
  step(3.4, [media type check], [else 415 invalid_json], luma(225))
  cdraw.line((11.15, 1.6), (11.15, 0.9), stroke: luma(100), mark: (end: ">>"))
  step(0.7, [count while streaming], [past 1 MiB: 413], luma(225))
  cdraw.content((18.9, 4.6), [then JSON.parse, else 400], size: 6pt)
  cdraw.content((3.45, 2.4), [the one failure writer], size: 6pt)
  cdraw.content((3.45, 1.3), [writeError, always the envelope], size: 6pt)
})

== request ids

Every request needs one id the log line, the error envelope, and
later the trace metrics all agree on. The kernel resolves it once, at
the edge: the client's `X-Request-ID` when it is uuid-shaped, else a
fresh v7. The uuid test is a plain regex, case-insensitive, any
version, the acceptance domain of the go lane's `uuid.Parse`. Parsing
is contract, not politeness: the envelope
promises `request_id` is a uuid, and a free-text header echoed into
logs is log injection. Garbage is replaced, never echoed.

The fresh id comes from `crypto.randomUUIDv7`, platform surface, so
this lane does not hand-roll a v7 constructor. The test asserts the
shape on a hundred draws, version nibble 7 and variant bits 10xx. The
root handler echoes the id as `X-Request-ID` so a client correlates
its own logs with the server's, and everything downstream reads
`ctx.id` without touching headers again:

#listing("javascript/api/src/kernel/requestid.mjs", first: 6, last: 16, caption: [the resolver: uuid header honored, garbage replaced, platform v7 as the fallback])

#diagram([one id, born at the edge, quoted by everything downstream], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.0, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.5, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.5, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [request arrives], [with or without an id])
  cdraw.line((5.5, 5.5), (5.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(5.9, [the edge resolves], [header uuid or fresh v7])
  cdraw.line((11.1, 5.5), (11.5, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.5, [ctx plus echo header], [one value, two surfaces])
  cdraw.line((16.7, 5.5), (17.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.1, [downstream], [handler, logs, envelope])
  pane(0.3, 8.8, 3.4, [access log], [request_id field], [stable across retries])
  pane(9.9, 18.4, 3.4, [error envelope], [#"request_id member"], [a uuid, always])
})

== the app skeleton and the composition file

`createKernel` returns the app object the whole part builds on:
`route` registers one handler, `use` appends one middleware layer,
first used outermost, `handler` folds the stack over dispatch once at
call time, and `listen` starts a server on an ephemeral port by
default. The kernel owns the two deployment routes. `GET /healthz`
answers liveness with exactly `{"status":"ok","version":".."}`, the
version an injected dependency so a deployment can prove what it runs.
`GET /readyz` answers 200 while the injected `ready` probe says ready
and throws `overload` at 503 the moment it does not, the hook the load
chapter's drain wiring flips and the handler contract from route one.

Configuration arrives as injected dependencies, the kernel never reads
ambient env, and the ship chapter passes env values in from the edge.
`src/server.mjs` is the composition file and has one writer, this
chapter: create the app, mount each family's stack, hand the app back.
Every later family lands as a `wire-<family>.mjs` function the file
calls, one import and one call, in chapter order with the operations
layers interleaved where the stack names. Nothing listens on import:

#listing("javascript/api/src/server.mjs", first: 20, last: 34, caption: [the composition file: path-aware single store, the keyed runner handed to register])

#diagram([every chapter lands as one import and one call, in chapter order], length: 13pt, {
  cdraw.content((11.8, 8.5), [composition file], size: 6.5pt)
  let row(y, title, l1, fill) = {
    cdraw.rect((2.6, y), (21.0, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((11.8, y + 1.0), [#title], size: 6pt)
    cdraw.content((11.8, y + 0.25), [#l1], size: 6pt)
  }
  row(6.6, [ch23 kernel, done], [routes, envelope, codec, ids, listen], luma(235))
  cdraw.line((11.8, 6.5), (11.8, 5.9), stroke: luma(100), mark: (end: ">>"))
  row(4.3, [ch24 middleware], [access log, deadline, adapter, order], luma(235))
  cdraw.line((11.8, 4.2), (11.8, 3.6), stroke: luma(100), mark: (end: ">>"))
  row(-0.3, [ch25-33 the rest of the part], [one wire call per family, ops layers interleaved], luma(235))
  cdraw.line((11.8, -0.4), (11.8, -1.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((2.6, -4.9), (12.4, -3.2), fill: luma(205), radius: 0.02)
  cdraw.content((7.5, -3.9), [node:http, this chapter], size: 6pt)
  cdraw.content((7.5, -4.6), [#"app.route, app.use: the seam"], size: 6pt)
})

== testing the kernel

Go's kernel had `httptest` and tested everything without a socket.
Node has no recorder type, and the lane answers with two paths. The
socketless path rolls a hand-rolled response double, `FakeRes` in
`test/kernel/helpers.mjs`: it records the status, the headers, and the
body chunks the kernel writes, and it refuses writes past an `end`,
so a double-write bug fails the assertion it was heading for. The
request side is a plain object with `method`, `url`, and lowercase
headers. Router matching,
envelope bytes, the codec ladder, and the id resolver all test through
these doubles, no listener, no port, no timing.

The socket path is for what only the wire proves: the platform's HEAD
body suppression, header casing, the id echo. Each such test calls
`app.listen()`, fetches against the returned port, and closes in
`t.after()`, the close calling `closeAllConnections` before
`server.close` because a kept-alive socket holds a bare close open,
the standing `node --test` orphan trap on this machine. The property
check is a seeded loop, fixed seed 20261001, node having no native
fuzzing: fifty rounds of random uuids under both registration orders,
asserting the static route answers and the param route never does, the
invariant named in the test title:

#listing("javascript/api/test/kernel/helpers.mjs", first: 22, last: 41, caption: [the response double: an event surface with finish on end, past which nothing writes])

#diagram([two test paths: doubles for logic, an ephemeral socket for the wire], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [FakeRes, FakeReq], [status, headers, bytes])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [handler call], [a function call, no port])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [assert], [exact bytes, shapes])
  pane(0.3, 11.0, 3.4, [the seeded loop], [seed 20261001], [static beats param, 50 rounds])
  pane(12.0, 22.8, 3.4, [the socket path], [port 0, fetch, after], [closeAllConnections])
  cdraw.content((11.5, 1.6), [a leaked handle fails node --test at exit], size: 6pt)
})

sources: nodejs.org/api/http.html for createServer, ServerResponse,
server.close and closeAllConnections, nodejs.org/api/crypto.html for
randomUUIDv7, nodejs.org/api/url.html for URL and URLSearchParams,
nodejs.org/api/test.html for the runner, and developer.mozilla.org for
JSON.parse, JSON.stringify, and the async iteration protocol, all
accessed 2026-09-26, re-verified by the probes cited in the text on
node 26.3.0. Verified by `books/javascript/api/test/kernel` tests, 33
of them, plus node --test and prettier.
