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
chapters, and everything in it sits on the package this chapter
builds: `javabook.httpx` under `java/api/src`. The jdk's own server,
`jdk.httpserver`, gives us a listener, an exchange object, and not
much else, so the kernel owns the rest: the route table with methods
and path parameters, the constant error envelope every non-2xx
response answers with, the json the jdk never shipped, the decode
ladder every request body climbs, and the skeleton that later
chapters wire their families into. The go book built the same layer
on its standard mux, #xref-to("go", "httpkernel"), and the contrasts
with that chapter are the point of this one: where go's library hands
you a router and a codec, java hands you a socket and a choice.

== the server and the exchange

`com.sun.net.httpserver.HttpServer` lives in the `jdk.httpserver`
module, which is a jdk module outside `java.se`, so the first line of
the service is a module declaration that requires it by name:

#listing("java/api/src/module-info.java", first: 1, last: 13, caption: [the service module: jdk.httpserver by name, transitive because the kernel's api speaks its types, exports grow one line per family])

The server itself is three calls. `HttpServer.create` binds the
listening socket at construction, an `InetSocketAddress` of port 0
asks the kernel for an ephemeral port, which is what every test in
this part boots on. `setExecutor` must run before `start`, and the
executor is the whole concurrency story: `Executors.newVirtualThreadPerTaskExecutor()`
means one virtual thread per request, the chapter 10 material doing
real work, so a handler may block freely and a thousand slow clients
cost a thousand cheap threads. `start` returns immediately, it does
not block the caller the way go's `ListenAndServe` does, which is why
`Main` ends by joining its own thread forever:

#listing("java/api/src/javabook/httpx/App.java", first: 54, last: 61, caption: [create binds at construction, port 0 is the ephemeral port the tests ride])

The request side of the server is one object, the `HttpExchange`. It
is both the request and the response at once: request method, uri,
and headers on the way in, `sendResponseHeaders` and one response
`OutputStream` on the way out, an attributes map the filters use for
per-request state, and a `close` that ends the exchange. Nothing
buffers, nothing is parsed beyond the request line and headers, and
the response length contract is exact: a positive `long` is a fixed
content length the handler must write to the byte, zero means chunked
and the handler closes the stream to terminate, and since java 26 the
constants `RSPBODY_EMPTY` and `RSPBODY_CHUNKED` name the two special
values instead of leaving bare `-1` and `0` in the code.

#diagram([one object is the whole transaction: request in, response out, close at the end], length: 13pt, {
  cdraw.rect((0.3, 5.2), (10.7, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.7), [HttpExchange], size: 6.5pt)
  cdraw.content((5.5, 6.8), [#"getRequestMethod, getRequestURI"], size: 6pt)
  cdraw.content((5.5, 5.9), [#"getRequestHeaders, getRequestBody"], size: 6pt)
  cdraw.line((11.1, 6.7), (12.1, 6.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((12.3, 5.2), (22.7, 8.2), fill: luma(228), radius: 0.02)
  cdraw.content((17.5, 7.7), [the same object], size: 6.5pt)
  cdraw.content((17.5, 6.8), [#"sendResponseHeaders(200, len)"], size: 6pt)
  cdraw.content((17.5, 5.9), [#"getResponseBody, close"], size: 6pt)
  cdraw.content((5.5, 4.3), [positive length: exactly that many bytes, then close], size: 6pt)
  cdraw.content((5.5, 3.2), [chunked: arbitrary bytes, close terminates], size: 6pt)
  cdraw.content((5.5, 2.1), [RSPBODY_EMPTY since 26 names the no body case], size: 6pt)
})

== the route table

The server's own dispatch is prefix matching: the context whose path
is the longest matching prefix of the request path wins, matched
literally, and a context of `/api/users` will also see `/api/users/anything`.
That rule buys nothing for an api with methods and path parameters,
so the kernel registers exactly one context, the root, and owns the
table itself. A pattern is segment-exact with `{name}` wildcards that
match one segment, a route is a method plus a pattern plus a handler,
and dispatch walks the list:

#listing("java/api/src/javabook/httpx/App.java", first: 116, last: 148, caption: [the whole router: segment match, wildcard bind, 405 with Allow, else the 404 envelope])

Three answers fall out of the walk. A path that matches no pattern
answers 404 with the envelope. A path that matches a pattern but not
the method answers 405, keeps an `Allow` header built from the
methods the path does serve, and rides the same `not_found` code the
go book chose, because the closed code set has no method member. And
a matched route binds its wildcards as exchange attributes under
`path.`, decoded, so the user chapter's handlers read
`Kernel.pathValue(ex, "id")` the way go handlers read `r.PathValue`.

Segment exactness is two decisions, both measured before they were
kept. The table matches the raw path, not the decoded one, so a
percent-encoded slash stays inside one segment: `/items/a%2Fb`
matches `{id}` once and the handler reads the decoded `a/b`, where
routing the decoded path would have collapsed the segments and sent
the request to a different route. And an interior or trailing empty
segment, a double slash or a trailing slash, matches nothing: the
pattern `/healthz` is not `/healthz/`, and the strictness test pins
both. The boundary is the server's own front door: a request target
the server rejects before dispatch, `//healthz`, `OPTIONS *`, a bad
percent escape in the query, is answered by the server's own plain
error page and never reaches the kernel's envelope. Everything the
server dispatches gets the contract shape.

One honest omission: the go mux serves `HEAD` for every `GET` pattern
automatically, this table does not, and a `HEAD` to a `GET` route
answers 405 until someone teaches it otherwise.

#diagram([prefix matching versus the kernel's table: methods and wildcards are ours either way], length: 13pt, {
  cdraw.content((5.2, 8.6), [the server's rule], size: 6.5pt)
  cdraw.rect((0.4, 6.4), (10.0, 8.1), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 7.6), [longest prefix wins], size: 6pt)
  cdraw.content((5.2, 6.7), [#"/api/users" also sees /api/users/7"], size: 6pt)
  cdraw.line((10.4, 7.2), (11.4, 7.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((16.6, 8.6), [the kernel's table], size: 6.5pt)
  cdraw.rect((11.6, 6.4), (21.4, 8.1), fill: luma(228), radius: 0.02)
  cdraw.content((16.5, 7.6), [one root context], size: 6pt)
  cdraw.content((16.5, 6.7), [#"GET /api/users/{id} is a row"], size: 6pt)
  cdraw.line((5.2, 6.2), (5.2, 5.6), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 10.0, 5.4, [no method notion], [wrong verb, same handler])
  cdraw.line((16.5, 6.2), (16.5, 5.6), stroke: luma(100), mark: (end: ">>"))
  pane(11.6, 21.4, 5.4, [405 with Allow], [envelope, both 404 and 405])
})

== the error envelope

The contract freezes one failure shape for the whole api, and it is
the go book's shape member for member: an error object carrying a
code from a closed set of eleven, one human sentence, `details` on
`validation_failed` only, and the request id. Every non-2xx rides it,
including the 404 and 405 the router owns, the 422 the user chapter
adds, and the 429 and 503 the rate and load chapters add. A constant
envelope beats bare statuses because a client writes one error path
instead of one per status, and the day a status needs to move the
code does not.

Java's version of the taxonomy is an enum whose constants carry
their own wire name and default status, which is the single table
the go book needed a map for:

#listing("java/api/src/javabook/httpx/Code.java", first: 10, last: 21, caption: [eleven codes, eleven distinct default statuses, and the split pair adds 415 and 405 on top])

The failure carrier is a checked exception. `Handler` declares
`throws ApiError, IOException`, so a handler's signature states its
failures the way a go handler's error return does, and the compiler
keeps the list honest:

#listing("java/api/src/javabook/httpx/Handler.java", first: 10, last: 15, caption: [the handler contract: write successes, throw failures])

The adapter that turns a `Handler` into the server's `HttpHandler`
has two catch lanes. An `ApiError` renders as its own envelope. An
`IOException` means the client hung up mid-response and there is
nobody left to answer. Anything unchecked is deliberately not caught
here: that is the panic lane, and chapter 20's filter owns it, which
is also why the measured behavior without that filter is a closed
connection and a client holding an `IOException`, stated as a test:

#listing("java/api/src/javabook/httpx/Kernel.java", first: 39, last: 49, caption: [the adapter: declared failures become the envelope, the client gone is let go])

The envelope writer itself is one method, and it is the only place a
failure body is written. It builds the exact bytes by hand, member
order fixed, `details` present only when nonempty, and the request id
resolved at write time. The committed-response guard at the top uses
the sentinel the class documents: `getResponseCode` answers `-1`
while nothing has been sent, so any other value means the handler
already answered and a late failure can only be logged and the
exchange closed:

#listing("java/api/src/javabook/httpx/Kernel.java", first: 69, last: 82, caption: [the one failure writer, guarded by the unsent sentinel])

#callout("note", "the -1 sentinel, measured", [
  The class documentation of `HttpExchange.getResponseCode` promises
  `-1` if the response code is not available yet. The first version
  of this kernel tested `!= 0` and every failure path answered
  nothing, which the kernel tests caught on their first run: of 21
  tests, 13 held `EOF` where an envelope belonged. The sentinel is
  now a named constant and the tests pin it end to end.
])

#diagram([eleven codes, eleven default statuses, thirteen on the wire], length: 13pt, {
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
  pane(15.9, 23.4, 0.8, [shaded cells], [the split codes: failAt], [passes the status explicitly])
})

== json by hand

The jdk has no json. There is a `JSON-P` api in jakarta and a
`JSON-B` binding in jakarta, and the flight recorder ships a json
writer for `jfr print --json`, but a grep across the pinned build's
own sources finds no json parser anywhere in the jdk, and nothing in
`java.se` a service can call. The corpus bans external dependencies,
so the kernel is the json, and being the json is smaller than it
sounds: one writer, one reader, and a value model that is just the
maps and lists the language already has.

The value model is `null`, `Boolean`, `String`, `Long`, `Double`,
`List`, and `LinkedHashMap` in insertion order. The map type is the
load-bearing choice: a `LinkedHashMap` serializes its members in the
order they were put, so wire bytes are deterministic without a
reflection layer or an annotation, and the health route's body is the
same string on every machine that runs it. Numbers split by shape,
integers without a fraction or exponent parse as `Long`, everything
else as `Double`, because the resources this api moves carry ids and
counts, not decimal money.

The writer is a switch over the value's runtime type, with strings
escaped per the grammar and every other type appended. The whole
thing:

#listing("java/api/src/javabook/httpx/Json.java", first: 31, last: 79, caption: [the writer: insertion order is the byte order, strings escaped, non-finite numbers and other types rejected])

The reader is a recursive descent parser over the source string, one
position, strict RFC 8259: whitespace only where allowed, no leading
zeros, no trailing content, control characters rejected inside
strings, every escape including `\uXXXX` honored with surrogate
pairs validated, non-finite numbers rejected so the reader never
accepts a `1e400` the writer would have to refuse, and a nesting cap
so a hostile body cannot recurse the stack. Objects build the same
`LinkedHashMap` the writer consumes, which is what makes round trips
a property the tests can assert:

#listing("java/api/src/javabook/httpx/Json.java", first: 108, last: 116, caption: [parse: one document, nothing after it, offsets in every failure])

#callout("verify", "the ternary that unboxed our numbers", [
  The number reader first returned
  `integral ? Long.valueOf(text) : Double.valueOf(text)`, and every
  number came back a `Double`, `42` as `42.0`. That is correct java:
  a conditional with two numeric operand types applies binary
  numeric promotion, unboxes both sides to `double`, and boxes the
  result. The fix is branches, which the source now carries with a
  comment, and the typing test pins `42` as a `Long` forever.
])

== the decode ladder

Reading a request body is stricter than writing one, because request
bodies are input. `Kernel.bindJson` is the one decode path, and it
enforces the same four rungs the go kernel enforced, in the same
order. The media type must be `application/json` before the `;`,
anything else is 415. The body must fit the 1 MiB cap, checked while
reading, so the 413 fires without parsing a byte past the cap. The
json must parse, 400. And every member must be one the route accepts,
because a typed struct in go got that from `RejectUnknownMembers` and
a map gets it from an explicit allowed set the caller passes:

#listing("java/api/src/javabook/httpx/Kernel.java", first: 135, last: 160, caption: [the ladder: 415, 413, 400, 400, then the member map is the caller's])

The capped read is its own helper, and the cap check runs per chunk
with the total accumulated, so the failure throws before the buffer
ever holds the oversized body. There is no `MaxBytesReader`
equivalent in the jdk, there is just an `InputStream` and arithmetic:

#listing("java/api/src/javabook/httpx/Kernel.java", first: 162, last: 175, caption: [no library helper: read, count, refuse past the cap])

#diagram([the decode ladder: each rung rejects a class of bad input before the next runs], length: 13pt, {
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

== the skeleton and its lifecycle

`App` is the service skeleton the whole part wires into. A `Config`
record carries the port, the build version, and a readiness probe,
`Config.fromEnv` reads `JBAPI_PORT` and `JBAPI_VERSION` so one module
runs anywhere, and port 0 is the ephemeral port every test boots on.
The kernel's two routes are the deployment contract: `GET /healthz`
answers 200 with the status and the version, so a deployment can
prove what it is running, and `GET /readyz` answers 200 while the
probe says ready and the envelope's `overload` code at 503 the moment
it does not, the hook the load chapter's drain wiring flips:

#listing("java/api/src/javabook/httpx/App.java", first: 75, last: 90, caption: [the two deployment routes, the pattern every later family copies])

`start` wires the one root context with the filter stack attached,
installs the virtual thread executor, and starts serving. `stop` is
the graceful drain, and its semantics come straight from the class
documentation: the listening socket closes immediately, in-flight
exchanges get up to the grace argument in seconds to finish, then
open connections close, and a stopped server cannot be reused:

#listing("java/api/src/javabook/httpx/App.java", first: 92, last: 113, caption: [start wires context, filters, executor. stop drains then shuts the pool down])

#diagram([the stop order: listener first, drain second, connections last], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (13.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((7.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((7.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(6.6, [stop(grace) called], [the operator or a signal path])
  cdraw.line((7.2, 6.5), (7.2, 5.9), stroke: luma(100), mark: (end: ">>"))
  stage(4.4, [listening socket closes], [new connections refused from here on])
  cdraw.line((7.2, 4.3), (7.2, 3.7), stroke: luma(100), mark: (end: ">>"))
  stage(2.2, [in-flight drains], [up to grace seconds, then tcp closes])
  cdraw.content((17.6, 5.1), [a stopped server cannot], size: 6pt)
  cdraw.content((17.6, 4.0), [be reused: one App per run], size: 6pt)
  cdraw.content((17.6, 2.9), [tests boot fresh on port 0], size: 6pt)
})

== testing through a real socket

Go's kernel chapter tested handlers through `httptest` recorders with
no socket anywhere. The jdk has no recorder, and this kernel's
honesty lives one layer down anyway: the route table, the exchange
lifecycle, and the drain all belong to the server, so the tests boot
the real thing. Every test constructs an `App` on port 0, starts it,
and drives it with the standard `HttpClient`, which means the bytes
on the wire are the bytes asserted:

#listing("java/api/test/javabook/httpx/HttpServerKernelTests.java", first: 24, last: 41, caption: [the harness: boot on an ephemeral port, one shared client, small send helpers])

The assertions are exact where the contract freezes bytes, the health
body for instance, and structural everywhere else, decoding the
envelope back through the kernel's own reader to check codes, details
arrays, and that `request_id` always parses as a uuid v4. The drain
test is the one that proves the lifecycle story: a slow handler holds
a request open, `stop(2)` runs while it sleeps, the in-flight
response still arrives complete, and the next connection is refused:

#listing("java/api/test/javabook/httpx/HttpServerKernelTests.java", first: 248, last: 272, caption: [the drain proof: in-flight completes, new arrivals refused])

The lane is the one chapter 18 vendored. `javac -Xlint:all -Werror`
compiles `src` and `test` separately, the test compile carrying
`build/classes` and the junit jar on its classpath, and the console
launcher's `execute --scan-classpath` runs every `*Tests` class
against both class directories. On this machine, dated 2026-10-04,
the classes this chapter owns carry 24 green tests between them, 14
over the socket and 10 on the json reader, and every claim in this
chapter that can be executed is one of them or one of their
assertions.

#diagram([the test lane: two compiles, one console run, exit 0 green], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [src compile], [-Xlint:all -Werror])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [test compile], [classes plus junit jar])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [console execute], [--scan-classpath])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [exit 0], [21 green, 0 red])
  cdraw.content((11.5, 3.5), [the same vendored 6.1.3 jar chapter 18 pinned], size: 6pt)
  cdraw.content((11.5, 2.4), [real sockets, ephemeral ports, no sleeps except the drain], size: 6pt)
})

sources: the jdk.httpserver api read from the pinned build's own
sources (`tools/jdk27/build/jdk-27/lib/src.zip`, oracle jdk 27 ga
build 27+35-2325): the longest-matching-prefix and path-prefix
matching notes plus the `sun.net.httpserver.pathMatcher` property
from `HttpServer.java`, the `stop(int)` drain contract and the
executor-before-start rule from the same file, `RSPBODY_EMPTY` and
`RSPBODY_CHUNKED` marked since 26 and the `-1` sentinel documented in
`HttpExchange.java`, and `Filter.Chain` from `Filter.java`. RFC 8259
for the json grammar. The go contrasts against
the standard mux chapter of book 3 of this corpus. Accessed and
verified live 2026-10-04 by the `javabook.httpx` and json tests over
the kernel and json classes of the module at `books/java/api`, 24
tests green under the vendored junit 6.1.3 lane, covering the exact
health body, the 503 flip, the
404 and 405 envelopes with Allow, the uuid request ids, the 415 413
400 400 ladder, path parameters, the strict raw-path routing with
encoded slashes and rejected double slashes, virtual thread
handlers, 64 concurrent requests, the drain and refusal after stop,
and the json round trips, escapes, finiteness, surrogates, and
rejections.
