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

Everything else in this service part sits on one small folder: the
api kernel. This chapter builds it in `CsharpBook.Api/Kernel`: the
request delegate and result contract, the route table with the
fallback that keeps the platform's two miss answers inside the
contract, the constant error envelope every non-2xx response answers
with, the System.Text.Json codec whose bytes match the go lane's
exactly, the in-process test server, and the composition root the
part appends to.

== the request delegate contract

An aspnet handler is one delegate, `RequestDelegate`, a function from
`HttpContext` to `Task`, and that shape is the whole server: the
pipeline `WebApplication` builds is a chain of these delegates folded
over each other, and an endpoint registered with `MapGet` is a
terminal one. The kernel routes do not return plain values, they
return `IResult`, the deferred response, an object with one
`ExecuteAsync` method that writes status, headers, and body into the
context when the framework executes it, with `TypedResults` as the
typed factory over the built-ins. Deferring instead of writing inline
is what keeps the failure path uniform: one result type owns every
failure body.

The kernel keeps the shape and adds one convention on top, the
exception channel. A handler that fails throws `ApiError` instead of
writing a failure, and the exception middleware of the next chapter
turns the throw into the contract envelope, so no route formats a
failure body by hand and no route can answer a 500 with the wrong
shape. Go returns errors, c\# throws, and the two idioms land on the
same contract. Until the middleware exists, the kernel's own
`EnvelopeResult` is the one result that renders an `ApiError`:

#listing("csharp-net/api/src/CsharpBook.Api/Kernel/EnvelopeResult.cs", first: 10, last: 19, caption: [the kernel's one IResult: execute resolves the request id and writes the envelope])

#diagram([the request climbs the pipeline, the result executes into the response], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(5.9, [WebApplication], [#"builder.Build() folds the chain"])
  cdraw.line((5.2, 5.8), (5.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(3.7, [RequestDelegate pipeline], [middleware layers, next chapter])
  cdraw.line((5.2, 3.6), (5.2, 3.0), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [endpoint delegate, throws ApiError], [#"MapGet route"])
  cdraw.line((5.2, 1.4), (5.2, 0.8), stroke: luma(100), mark: (end: ">>"))
  stage(-0.7, [IResult.ExecuteAsync], [#"status, headers, body, once"])
})

== endpoint routing as the route table

Endpoint routing is a real router. A route registers with `MapGet`,
`MapPost`, and siblings, one method per pattern, wildcards like `{id}`
come from the template, and matching runs in phases over the whole
candidate set, the documentation's wording, so the more specific
pattern beats the looser one the way go's ServeMux precedence does.
Two of the platform's answers violate the contract. An unknown path
gets a bare 404 from the routing middleware, a known path with the
wrong method gets a bare 405 plus an `Allow` header from a sentinel
endpoint the matcher selects, and the contract demands the envelope on
both.

The fallback registers above `UseRouting`, which the composition root
pins explicitly, because the platform's documented behavior is that
routes added directly to `WebApplication` execute at the end of the
pipeline, so middleware registered before the explicit `UseRouting`
wraps the router and every miss unwinds into the fallback before
anything is flushed. A 404 with no endpoint selected is a route miss,
a bare 405 with no content length is a method miss, and anything a
handler answered with a body of its own is left untouched. The 405
keeps the `Allow` header the router computed, and both statuses carry
the `not_found` code, the closed code set having no
`method_not_allowed` member, with the message carrying the
distinction:

#listing("csharp-net/api/src/CsharpBook.Api/Kernel/EnvelopeFallback.cs", first: 21, last: 42, caption: [the fallback owns the two answers the router would emit bare])

#callout("note", "head does not ride a get pattern", [
  Go's ServeMux serves HEAD on a `GET` pattern by design. Endpoint
  routing does not: HEAD against a get-only route is a method miss,
  405 with `Allow`, the same envelope, pinned by a test, a platform
  ruling this lane inherits.
])

#diagram([one router, two misses, both rewritten into the envelope], length: 13pt, {
  cdraw.content((5.5, 7.7), [the request], size: 6.5pt)
  cdraw.rect((0.9, 5.2), (10.1, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 6.2), [endpoint routing], size: 6pt)
  cdraw.content((5.5, 5.5), [#"matching phases over candidates"], size: 6pt)
  cdraw.line((3.0, 5.1), (3.0, 4.3), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 8.4, 4.2, [no path matches], [404, endpoint null])
  pane(6.0, 14.1, 4.2, [path, wrong method], [405 sentinel, plus Allow])
  cdraw.line((12.5, 3.0), (16.5, 3.0), stroke: luma(100), mark: (end: ">>"))
  pane(16.7, 23.4, 4.2, [the fallback], [envelope, not_found code], [405 keeps Allow])
})

== the error envelope

The contract freezes one failure shape for the whole api, smaller
than most: an error object carrying a code from a closed set of
eleven, one human sentence, optional `details` on `validation_failed`
only, and the request id. Every non-2xx rides it, including the 404
and 405 the fallback owns, the 422 the user chapter adds, and the 429
and 503 the rate and load chapters add. A constant envelope beats bare
status codes because a client writes one error path instead of
thirteen, the statuses the wire actually serves, a grep for the code
string works across every endpoint, and
the day a status needs to move the code does not.

The codes are declared once, an `ErrorCode` enum with eleven members,
and one table maps each code to the status it carries everywhere, the
grid below. The two split codes each have exactly one sanctioned
override site, expressed as `At(status)` on the error:
`invalid_json` rides 415 on a wrong media type and `not_found` rides
405 on a method miss, while the map supplies every other status. The
record is two levels deep so the wire shape stays nested the way the
vectors freeze it, property order is declaration order, and `details`
carries a `JsonIgnore` condition that keeps the member absent
everywhere except validation, the c\# spelling of go's omitzero:

#listing("csharp-net/api/src/CsharpBook.Api/Kernel/Envelope.cs", first: 11, last: 32, caption: [the envelope: one shape, closed codes, details off the wire unless present])

#diagram([eleven codes, eleven statuses in the table, thirteen on the wire, two sanctioned splits], length: 13pt, {
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

Bodies go out through System.Text.Json behind one options instance,
`KernelJson.Wire`, and every property the api writes rides it. Three
settings do the contract's work. `SnakeCaseLower`, the built-in naming
policy shipped in .NET 8, maps each c\# property to the snake case
name the wire freezes, `RequestId` to `request_id`. The enum converter
writes codes as their snake case strings rather than numbers. The
relaxed encoder leaves non-ascii text raw instead of escaping it to
`\u` sequences, which is what go's encoder does, so accented text
serializes identically in both lanes. Declaration order is
serialization order, so the dto property order mirrors the go struct
order, and the vector bytes match lane for lane.

The write helper commits the status and the content type before the
body serializes, the same ordering tradeoff the go kernel makes, safe
for the kernel's marshal-by-construction records and wrong for
anything that can fail to marshal, and the content type is
`application/json` exactly, no charset parameter, because the vectors
freeze that header too. Reading is stricter, because request bodies
are input. `BindAsync<T>` is the one decode path, generic over the
target dto, and it enforces three rungs in a fixed order: the media
type must parse as `application/json`, so a charset parameter still
passes and anything else is 415 `invalid_json`, the body runs through
a stream capped at 1 MiB whose overflow surfaces as a distinct
exception type and answers 413 `payload_too_large`, and what survives
must parse, a malformed body answering 400 `invalid_json`. A body of
the literal `null` is ruled malformed rather than zero-valued, this
lane's ruling:

#listing("csharp-net/api/src/CsharpBook.Api/Kernel/KernelJson.cs", first: 16, last: 32, caption: [the wire options and the caps: one settings object behind every byte])

#diagram([two write sites, one decode ladder, four contract statuses], length: 13pt, {
  pane(0.3, 7.3, 7.2, [handler record], [#"typed dto, by construction"], [marshals or throws nowhere])
  cdraw.line((3.8, 5.3), (3.8, 4.3), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 7.3, 3.1, [WriteJsonAsync], [status and type first, then body])
  pane(0.3, 7.3, 0.5, [EnvelopeResult, failures])
  pane(8.0, 15.3, 7.3, [request body], [bytes from the wire], [untrusted input])
  cdraw.line((11.65, 5.3), (11.65, 4.3), stroke: luma(100), mark: (end: ">>"))
  let step(y, l1, l2, fill) = {
    cdraw.rect((8.0, y - 1.7), (15.3, y), fill: fill, radius: 0.02)
    cdraw.content((11.65, y - 0.6), [#l1], size: 6pt)
    cdraw.content((11.65, y - 1.4), [#l2], size: 6pt)
  }
  step(4.1, [media type parses], [else 415 invalid_json], luma(225))
  cdraw.line((11.65, 2.3), (11.65, 1.6), stroke: luma(100), mark: (end: ">>"))
  step(0.8, [1 MiB capped stream], [past it 413 too large], luma(225))
  cdraw.content((18.2, 1.8), [then parse: 400 malformed, null ruled], size: 6pt)
})

== the in-process test server

`WebApplicationFactory<Program>` gives the kernel its whole test story
without a socket. The factory boots the real composition root on an
in-memory TestServer, hands back an `HttpClient`, and the round trip
is a function call. Nothing listens, so there is no port to collide,
no firewall prompt, and no timing, and `public partial class Program`
is the one accessibility line the factory needs to see the entry
point, the migration documentation's own recipe.

The pattern the whole suite copies is three steps, build a factory,
make one client, assert on exact values. Exact bytes are asserted
where the contract freezes them, the health body as a whole string,
and structural assertions elsewhere, the envelope's code and message
and a parseable `request_id` guid. Unit level, `DefaultHttpContext` is
the recorder, a memory stream standing in for the body while the same
delegates the server would run are invoked directly, which is how the
bind ladder, the id resolution, and the fallback run without a host.
One platform gap needs a double: no server sits behind
`DefaultHttpContext`, nothing ever starts the response, so a strict
feature double pins `HasStarted` to true and the started branches run
under test too:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Kernel/KernelEndpointTests.cs", first: 32, last: 43, caption: [the factory round trip: exact frozen bytes on the deployment contract])

#diagram([the factory boots the real root on an in-memory server], length: 13pt, {
  let step(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  step(0.3, [the test], [#"WebApplicationFactory<Program>"])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [TestServer, the real root], [same Program.cs])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [assert], [exact bytes, shapes])
})

== the app skeleton and its wiring table

The kernel also ships the program skeleton, and the skeleton is a
file, `Program.cs`, with a discipline attached: a wiring table with
one writer. This chapter pins the root at its smallest, the kernel's
own registrations behind one call, and the ship chapter later lands
`Deploy/Wire.cs` as the single table every family composes through,
the c\# mirror of go's `wire.go`, so the root never grows a line per
family and every family's wiring lives in one reviewable place. Each
family registers services through one extension beside its code, and
the table reads top to bottom as the request flows.

The kernel's registrations are the clock and the config hub.
`TimeProvider.System` registers once and every family resolves it,
the seam the tests swap for the stepped fake. `ApiOptions` carries the
build version from `GOAPI_VERSION` and the request budget from
`GOAPI_REQUEST_TIMEOUT`, the `GOAPI_` names kept for compose parity
with the go lane. The two kernel routes are the deployment contract.
`GET /healthz` answers liveness, 200 with the status and version, so a
deployment proves what it is running. `GET /readyz` answers readiness,
200 while the probe passes and the envelope's `overload` code at 503
the moment it does not, the hook the drain wiring flips:

#listing("csharp-net/api/src/CsharpBook.Api/Program.cs", first: 11, last: 23, caption: [the root at its smallest: the probe line, two table calls, run])

#diagram([the part's families stack on the kernel, the wiring table owns the order], length: 13pt, {
  let row(y, title, l1) = {
    cdraw.rect((2.6, y), (21.0, y + 1.5), fill: luma(235), radius: 0.02)
    cdraw.content((11.8, y + 1.0), [#title], size: 6pt)
    cdraw.content((11.8, y + 0.25), [#l1], size: 6pt)
  }
  row(6.6, [Program.cs, the wiring table], [one line per family, insertion rule in file])
  cdraw.line((11.8, 6.5), (11.8, 5.9), stroke: luma(100), mark: (end: ">>"))
  row(4.3, [middleware ch23], [ids, access log, deadline, exceptions])
  cdraw.line((11.8, 4.2), (11.8, 3.6), stroke: luma(100), mark: (end: ">>"))
  row(2.0, [users authn authz ch24-26], [resource, sessions, roles, policies])
  cdraw.line((11.8, 1.9), (11.8, 1.3), stroke: luma(100), mark: (end: ">>"))
  row(-0.3, [store conc cache, then limit obs load ship], [sqlite and etags, then buckets, metrics, drain])
  cdraw.content((7.5, -4.2), [Kernel, this chapter: envelope, routes, codec], size: 6pt)
})

== what the kernel proves

The kernel is small on purpose, 10 files and a test folder, and it
proves the part's shape is already fixed. The envelope
exists, so every later failure is a `Fail` call and never a handbuilt
body, and a test builds the vector 05 body from the frozen file and
compares the serialization byte for byte. The decode ladder exists, so
every write route inherits the 415, the 413, and the 400 without
repeating them, and the route table exists with the fallback that
keeps the contract on the two answers the router gets wrong. The
composition root exists with its insertion rule, so the roadmap from
here is additive, every chapter adding routes or layers, none
rewriting the kernel:

#listing("csharp-net/api/src/CsharpBook.Api/Kernel/KernelRoutes.cs", first: 13, last: 29, caption: [the kernel's two routes, the deployment contract in full])

#diagram([the part as six rows: every chapter adds routes or layers, none rewrites the kernel], length: 13pt, {
  let row(y, l1, l2) = {
    cdraw.rect((0.6, y), (22.6, y + 1.5), fill: luma(235), radius: 0.02)
    cdraw.content((11.6, y + 1.0), [#l1], size: 6pt)
    cdraw.content((11.6, y + 0.25), [#l2], size: 6pt)
  }
  row(6.8, [ch22 kernel, done], [envelope, fallback, codec, ladder, skeleton])
  row(5.1, [ch23 middleware], [layer type, exceptions, ids, access log, deadline])
  row(3.4, [ch24-26 the resource and its gates], [users, pbkdf2 sessions, jwt, roles])
  row(1.7, [ch27-29 the data plane], [sqlite store, transactions, etags, lru cache])
  row(0.0, [ch30-33 the operations plane and the contract held], [buckets, metrics, load, 16 frozen vectors])
})

sources: learn.microsoft.com/aspnet/core/fundamentals/routing for the
matching phases and the end-of-pipeline execution of routes added to
WebApplication, learn.microsoft.com/aspnet/core/test/integration-tests
for WebApplicationFactory and the TestServer hosting model, and
learn.microsoft.com/dotnet/api/system.text.json.jsonnamingpolicy.snakecaselower
for the naming policy, all accessed 2026-09-26. Verified by
`CsharpBook.Api.Tests.Kernel` under `dotnet test Api.slnx`, 47 tests,
plus dotnet build and dotnet format over the touched projects.
