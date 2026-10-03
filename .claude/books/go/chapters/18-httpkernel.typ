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

Everything else in this service part sits on one small package: the
http kernel. This chapter builds it in `goapi/internal/httpx`: the
handler contract every route shares, the ServeMux route table with
method patterns, the constant error envelope every non-2xx response
answers with, the json/v2 read and write helpers, the httptest
discipline that tests all of it without a socket, and the app skeleton
that later chapters wire their families into.

== the handler contract

A go handler is one function of a writer and a request, and that shape
is the whole server: `http.Handler` is an interface with one method,
`http.HandlerFunc` adapts a plain function to it, and anything that
implements it can serve. The kernel keeps the shape and adds one
convention on top, the error-returning adapter. A kernel handler
returns an error instead of writing a failure, and the adapter turns
the error into the contract envelope, so no route formats a failure
body by hand and no route can answer a 500 with the wrong shape.

The adapter's rule is two branches. An `*httpx.E`, built by `Fail`,
renders as its own code, message, and status. Anything else is an
unknown failure, and unknown failures are answered as `internal` with
the detail kept for the logs, because a leaked `sql: no rows` tells a
client more than it should know. The two-line happy path is the point:
handlers read like functions, and every failure in the part flows
through one `if`:

#listing("go/api/internal/httpx/kernel.go", first: 103, last: 116, caption: [the adapter: handlers return errors, the kernel writes failures])

#diagram([the request climbs down the stack, the failure climbs back up as a value], length: 13pt, {
  cdraw.content((5.2, 7.7), [request path], size: 6.5pt)
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(5.9, [listener], [#"net, accept, read"])
  cdraw.line((5.2, 5.8), (5.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(3.7, [ServeMux], [pattern match, next section])
  cdraw.line((5.2, 3.6), (5.2, 3.0), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [Handler adapter], [runs the func, takes the error])
  cdraw.line((5.2, 1.4), (5.2, 0.8), stroke: luma(100), mark: (end: ">>"))
  stage(-0.7, [handler func], [#"writes 2xx json, or returns"])
  cdraw.content((17.5, 7.7), [failure path], size: 6.5pt)
  cdraw.line((19.5, 0.3), (19.5, 2.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((16.2, 1.2), [#"return Fail(..)"], size: 6pt)
  cdraw.content((17.5, 3.6), [the error returns as a value], size: 6pt)
  cdraw.content((17.5, 2.5), [the adapter answers once, in shape], size: 6pt)
})

== ServeMux as the route table

Since go 1.22 the standard mux is a real router. A pattern is
`METHOD HOST/PATH` with every part optional, wildcards are whole
segments like `{id}` and trailing `{path...}`, `{$}` matches only the
end, and a `GET` pattern also serves `HEAD`. Precedence falls out of
one sentence: when two patterns match, the more specific wins, where
more specific means matching a strict subset of the other's requests,
and two patterns that tie panic at registration time, so an ambiguous
table never ships. The kernel's table lives in `New` as method
patterns, `GET /healthz` and `GET /readyz` first, one `Register` call
per family appended as the part grows.

Two of the mux's answers violate the contract, so the kernel wraps it.
An unknown path gets plain text `404 page not found`, a known path
with the wrong method gets plain text `405` plus an `Allow` header,
and the contract demands the envelope on both. `Fallback` asks the mux
which pattern won: a non-empty pattern means a real route, and an
empty pattern means the default writer is about to answer, so the
kernel learns which status the default writer would pick, keeps the
mux's `Allow` header, and answers with the envelope itself:

#listing("go/api/internal/httpx/mux.go", first: 15, last: 33, caption: [the fallback owns the two answers the default mux would get wrong])

#callout("note", "mux.Handler does not fill in wildcards", [
  The wrapped dispatch serves matched requests through
  `mux.ServeHTTP`, not through the handler `mux.Handler` returns. The
  documented contract of `mux.Handler` is that it does not modify the
  request, so `r.PathValue` still returns the empty string and
  `r.Pattern` is unset. Only the mux's own `ServeHTTP` fills both in.
  The kernel's precedence test caught exactly this on its first run.
])

#diagram([pattern precedence: specific beats general, ties panic, leftovers split into 405 and 404], length: 13pt, {
  cdraw.rect((0.3, 5.6), (7.2, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((3.75, 6.7), [#"GET /users/{id}"], size: 6pt)
  cdraw.content((3.75, 5.95), [#"GET /users/reports"], size: 6pt)
  cdraw.content((3.75, 5.15), [both match, literal wins], size: 6pt)
  cdraw.line((7.4, 6.3), (8.4, 6.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.6, 5.6), (15.5, 7.1), fill: luma(225), radius: 0.02)
  cdraw.content((12.05, 6.7), [strict subset wins], size: 6pt)
  cdraw.content((12.05, 5.95), [a tie is a conflict], size: 6pt)
  cdraw.content((12.05, 5.15), [and panics at registration], size: 6pt)
  cdraw.line((15.7, 6.3), (16.7, 6.3), stroke: luma(100), mark: (end: ">>"))
  pane(16.9, 22.8, 7.1, [handler], [the most specific], [pattern registered])
  cdraw.line((12.05, 5.0), (12.05, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.05, 3.7), [no pattern matches the request], size: 6pt)
  pane(0.3, 9.6, 2.6, [path matches, method does not], [405, envelope plus Allow], [#"Allow: GET, HEAD"])
  cdraw.line((9.8, 1.3), (9.8, 0.6), stroke: luma(100))
  pane(12.6, 21.9, 2.6, [nothing matches], [404, envelope], [route not found])
})

== the error envelope

The contract freezes one failure shape for the whole api, and the
shape is smaller than most: an error object carrying a code from a
closed set of eleven, one human sentence, optional `details` on
`validation_failed` only, and the request id. Every non-2xx rides it,
including the 404 and 405 the fallback owns, the 422 the user chapter
adds, and the 429 and 503 the rate and load chapters add. A constant
envelope beats bare status codes because a client writes one error
path instead of twelve, the statuses the wire actually serves, a
grep for `code:"conflict"` works across
every endpoint, and the day a status needs to move the code does not.

The codes are declared once, as a `Code` string type with eleven
constants, and a single table maps each code to the status it carries
everywhere: `invalid_json` to 400, `validation_failed` to 422,
`payload_too_large` to 413, `unauthorized` 401, `forbidden` 403,
`not_found` 404, `conflict` 409, `precondition_failed` 412,
`rate_limited` 429, `overload` 503, `internal` 500. `invalid_json` and
`not_found` are the split codes, 400 for a malformed body and 415 for
a wrong media type on one, 404 and 405 through the fallback on the
other, and each split site passes its status explicitly. The struct
is two levels deep so the wire shape stays nested the way the vectors
freeze it, and `omitzero` keeps `details` absent everywhere except
validation:

#listing("go/api/internal/httpx/kernel.go", first: 71, last: 84, caption: [the envelope: one shape, closed codes, omitzero on details])

#diagram([eleven codes, ten statuses in the table, twelve on the wire], length: 13pt, {
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

== writing json responses with json/v2

Bodies go out through `encoding/json/v2`, the stable v2 the tour
chapter covered. `WriteJSON` is four lines: set the content type,
commit the status, `MarshalWrite` the value straight into the writer.
The ordering is a real tradeoff, not an oversight: the header commits
before the body serializes, which is fine for the kernel's types,
structs that marshal by construction, and wrong for anything that can
fail to marshal, where a half-committed response is the worst outcome.
`Error` is the same four lines pointed at the envelope, and it is the
only place a failure body is written, so the wire shape has one author.

Reading is stricter than writing, because request bodies are input.
`Bind` is the kernel's one decode path, generic over the target type
so each handler decodes into its own struct, and it enforces three
rules in a fixed order: the media type must parse as
`application/json` with `mime.ParseMediaType`, so a charset parameter
still passes, and anything else is 415 `invalid_json`. The body is
then wrapped in `http.MaxBytesReader` at the contract's 1 MiB cap, and
a read past it surfaces as `payload_too_large` 413 through
`errors.AsType`. What survives goes to `json.UnmarshalRead`, and a
malformed body is 400 `invalid_json`. The options parameter passes
json/v2 options through, which is how the user chapter layers
`RejectUnknownMembers` on without the kernel knowing about it:

#snippet("func Bind[T any](r *http.Request, opts ...json.Options) (T, error)\n// 415 wrong media type, 413 past 1 MiB, 400 malformed", lang: "go")

#listing("go/api/internal/httpx/kernel.go", first: 118, last: 137, caption: [the two write sites: WriteJSON for values, Error for failures])

#diagram([two write sites, one decode path, four contract statuses], length: 13pt, {
  pane(0.3, 6.6, 7.2, [handler value], [#"struct, map, slice"], [marshal safe by design])
  cdraw.line((3.45, 4.6), (3.45, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 6.6, 3.4, [WriteJSON], [content type, status,], [MarshalWrite])
  pane(8.0, 14.3, 7.2, [request body], [bytes from the wire], [untrusted input])
  cdraw.line((11.15, 4.6), (11.15, 3.6), stroke: luma(100), mark: (end: ">>"))
  let step(y, l1, l2, fill) = {
    cdraw.rect((8.0, y - 1.7), (14.3, y), fill: fill, radius: 0.02)
    cdraw.content((11.15, y - 0.6), [#l1], size: 6pt)
    cdraw.content((11.15, y - 1.4), [#l2], size: 6pt)
  }
  step(3.4, [media type check], [else 415 invalid_json], luma(225))
  cdraw.line((11.15, 1.6), (11.15, 0.9), stroke: luma(100), mark: (end: ">>"))
  step(0.7, [MaxBytesReader], [past 1 MiB: 413 too large], luma(225))
  cdraw.content((18.9, 5.9), [then UnmarshalRead], size: 6pt)
  cdraw.content((18.9, 4.8), [malformed: 400 invalid_json], size: 6pt)
  cdraw.content((18.9, 3.7), [into the handler's struct], size: 6pt)
  cdraw.content((18.9, 2.6), [v2 options pass through], size: 6pt)
  cdraw.content((3.45, 2.4), [the one failure writer], size: 6pt)
  cdraw.content((3.45, 1.3), [Error, always the envelope], size: 6pt)
})

== httptest the serverless server

`net/http/httptest` gives the kernel its whole test story without a
socket. `httptest.NewRequest` builds a request from a method, a
target, and an optional body, `httptest.NewRecorder` stands in for the
writer and records the status code, the header map, and the body
bytes, and a test serves the handler into the recorder and asserts on
exact values. Nothing listens, so there is no port to collide, no
firewall prompt, and no timing: the round trip is a function call.

The pattern the whole module copies is three lines, build, serve,
assert, and the helper every test in the package shares decodes the
recorded body back into an `Envelope` first, so a body that is not the
contract shape fails before the assertion it was heading for. Exact
bytes are asserted where the contract freezes them, the health body
for instance, and structural assertions elsewhere:

#listing("go/api/internal/httpx/kernel_test.go", first: 29, last: 39, caption: [the recorder round trip: serve the root handler, read everything back])

#diagram([request to handler to recorder to assertions, all one function call], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [NewRequest], [method, target, body])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [ServeHTTP], [into the recorder])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [recorder], [Code, Header, Body])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [assert], [exact bytes, shapes])
  cdraw.content((11.8, 3.5), [no listener, no port, no sleeps], size: 6pt)
  cdraw.content((11.8, 2.4), [the same handler the server would run], size: 6pt)
  cdraw.content((11.8, 1.3), [blocking layers get a real server in ch19], size: 6pt)
})

== the app skeleton and its wiring table

The kernel also ships the program skeleton, `httpx.App`, and the
single file that wires it. `Config` carries the listen address, the
build version, and a readiness probe, and `ConfigFromEnv` reads
`GOAPI_ADDR` and `GOAPI_VERSION` so one binary runs anywhere. `New`
builds the app and registers the kernel's two routes through the
adapter, `Mux` is exported because every family registers on it, and
`Use` appends a middleware layer, first used outermost, which is the
seam the next chapter plugs its stack into. `Handler` folds the layers
over the fallback-wrapped mux, and `ListenAndServe` is deliberately
plain: graceful drain is a load-chapter concern that will land as a
new file in this same package, not a change to this one.

The two kernel routes are the deployment contract. `GET /healthz`
answers liveness, 200 with `{"status":"ok","version":".."}`, where the
version comes from the environment so a deployment can prove what it
is running. `GET /readyz` answers readiness, 200 while the probe says
ready and the envelope's `overload` code at 503 the moment it does
not, which is the hook the drain wiring flips. `cmd/api/main.go` stays
twenty lines for the whole part, pinned here once and never again:
each later chapter's registration is two to five lines, a construction
and a `Register` call, and the integrator applies them inside
`wire.go`, the append-only wiring table the single `wire` call enters:

#listing("go/api/cmd/api/main.go", first: 1, last: 20, caption: [main.go, pinned once: the ch29 health dispatch and the single wiring call])

#diagram([the part's twelve packages stack on the kernel, the wiring table owns the order], length: 13pt, {
  cdraw.content((11.8, 8.5), [program map], size: 6.5pt)
  let row(y, title, l1, fill) = {
    cdraw.rect((2.6, y), (21.0, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((11.8, y + 1.0), [#title], size: 6pt)
    cdraw.content((11.8, y + 0.25), [#l1], size: 6pt)
  }
  row(6.6, [cmd/api, the wiring table], [construction plus Register, one family per chapter], luma(235))
  cdraw.line((11.8, 6.5), (11.8, 5.9), stroke: luma(100), mark: (end: ">>"))
  row(4.3, [middleware ch19], [request ids, access log, recover, timeouts], luma(235))
  cdraw.line((11.8, 4.2), (11.8, 3.6), stroke: luma(100), mark: (end: ">>"))
  row(2.0, [user authn authz ch20-22], [resources, sessions, roles, policies], luma(235))
  cdraw.line((11.8, 1.9), (11.8, 1.3), stroke: luma(100), mark: (end: ">>"))
  row(-0.3, [store analytics conc cache ch23-25], [engine, scans, etags, lru], luma(235))
  cdraw.line((11.8, -0.4), (11.8, -1.0), stroke: luma(100), mark: (end: ">>"))
  row(-2.6, [limit obs loadtest admission ch26-28], [429s, signals, p99, drain], luma(235))
  cdraw.rect((2.6, -4.9), (12.4, -3.2), fill: luma(205), radius: 0.02)
  cdraw.content((7.5, -3.9), [httpx, this chapter], size: 6pt)
  cdraw.content((7.5, -4.6), [envelope, routes, skeleton], size: 6pt)
  pane(13.2, 21.0, -3.2, [deploy ch29], [image, compose, ci,], [helm, terraform])
})

== what the kernel proves

The kernel is small on purpose, three files and a test file, and what
it proves is that the part's shape is already fixed. The envelope
exists, so every later failure is a `Fail` call and never a handbuilt
body. The decode ladder exists, so every write route inherits the
415, the 413, and the 400 without repeating them. The route table
exists with method patterns and a fallback that keeps the contract on
the two answers the default mux gets wrong. The skeleton exists, with
a public mux for registrations and a middleware seam for layers, and
the roadmap from here is additive:

#listing("go/api/internal/httpx/server.go", first: 45, last: 58, caption: [New registers the kernel routes, Use takes the next chapter's layers])

#diagram([the part as seven rows: every chapter adds routes or layers, none rewrites the kernel], length: 13pt, {
  let row(y, l1, l2) = {
    cdraw.rect((0.6, y), (22.6, y + 1.5), fill: luma(235), radius: 0.02)
    cdraw.content((11.6, y + 1.0), [#l1], size: 6pt)
    cdraw.content((11.6, y + 0.25), [#l2], size: 6pt)
  }
  row(6.8, [ch18 kernel, done], [envelope, patterns, fallback, json paths, skeleton])
  row(5.1, [ch19 middleware], [chain, ids, access log, recover, timeouts])
  row(3.4, [ch20-22 the resource and its gates], [users, argon2id sessions, jwt, roles, policies])
  row(1.7, [ch23-25 the data plane], [wal store, versioned schema, transactions, etags, cache])
  row(0.0, [ch26-28 the operations plane], [token buckets, slog and traces, load, drain])
  row(-1.7, [ch29 ship], [image, compose, ci, helm, terraform])
  cdraw.rect((0.6, -4.3), (22.6, -2.5), fill: luma(225), radius: 0.02)
  cdraw.content((11.6, -3.0), [the contract, held throughout], size: 6pt)
  cdraw.content((11.6, -3.9), [16 frozen vectors, 14 replayed in process, ch29 covers the last pair over compose], size: 6pt)
})

sources: pkg.go.dev for net/http, encoding/json/v2, net/http/httptest,
mime, and uuid, accessed 2026-09-25, the ServeMux pattern and
precedence rules quoted from the go 1.27 source in GOROOT, and
`mux.Handler`'s wildcard caveat read from the same source. Verified by
`go/api/internal/httpx` tests, 13 of them, plus the package gates:
gofmt, go vet, and go test over the whole goapi module.
