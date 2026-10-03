#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= go build part 1: fetchers and rest apis

The go build round is "build this small service, live". The
`ch20-go` module carries three builds: the parallel url fetcher
with a bounded worker pool, a stdlib-only rest api over sqlite
with caching and rate limiting, and a schema parser with a code
generator. 15 tests under `make verify`, sqlite 3.53 through the
pinned driver.

== the parallel fetcher, five workers [TDD]

Fixed pool, one jobs channel, results in input order because each
worker writes its own slot:

#listing("interview-repertoire/samples/ch20-go/fetcher.go", first: 14, last: 51, caption: [the pool, the ordered results, the sequential baseline])

The concurrency gauge is the piece that turns the claim into a
measurement: the get seam calls `Enter` and `Leave`, and the test
asserts observed concurrency never exceeded the pool of five and
never collapsed below two, against a real `httptest` server with
30 millisecond responses:

#listing("interview-repertoire/samples/ch20-go/fetcher.go", first: 72, last: 108, caption: [the gauge, and the error sentinel])

#diagram([indexed slots keep input order across any completion order], length: 13pt, {
  // urls in, unordered workers, results back in input order
  cdraw.content((12.4, 9.65), [input urls], size: 6.5pt)
  for i in range(5) {
    let x0 = 3.2 + i * 3.8
    cdraw.rect((x0, 8.2), (x0 + 3.4, 9.0), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 1.7, 8.6), [url #(i + 1)], size: 6pt)
  }
  cdraw.line((12.4, 8.2), (12.4, 7.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.0, 5.5), (16.8, 7.5), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((12.4, 6.9), [five workers,], size: 6pt)
  cdraw.content((12.4, 5.9), [completion in any order], size: 6pt)
  cdraw.content((19.8, 6.9), [gauge bounds], size: 6pt)
  cdraw.content((19.8, 5.9), [2 to 5 seen], size: 6pt)
  cdraw.line((12.4, 5.5), (12.4, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.4, 3.9), [results, input order kept], size: 6.5pt)
  for i in range(5) {
    let x0 = 3.2 + i * 3.8
    cdraw.rect((x0, 2.4), (x0 + 3.4, 3.2), fill: luma(205), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 1.7, 2.8), [slot #(i + 1)], size: 6pt)
  }
  cdraw.content((12.4, 1.5), [each worker writes its own slot], size: 6pt)
  cdraw.content((12.4, 0.5), [total time is the slowest response], size: 6pt)
})

The two narrations that score: total time of the pool is the
slowest request, not the sum, and errors flow through the same
slots as data, so a failing url does not cancel the batch unless
you decide it should, which the worker pool of
#xref-to("repertoire", "go-runtime") does with a context.

== the rest api: stdlib, sqlite, cache, rate limit [TDD]

One `http.HandlerFunc`, three routes, and the two cross-cutting
policies in front of them, the limiter and the cache:

#listing("interview-repertoire/samples/ch20-go/api.go", first: 57, last: 88, caption: [rate limit per ip, cache GETs only, route, store the snapshot])

#diagram([limiter and cache in front, GETs only cached], length: 13pt, {
  // the request path: bucket, cache, router, three routes, the store
  cdraw.rect((0.8, 6.6), (3.6, 7.6), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((2.2, 7.1), [request], size: 6pt)
  cdraw.line((3.6, 7.1), (4.4, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((4.4, 6.1), (7.8, 7.8), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((6.1, 7.4), [token bucket,], size: 6pt)
  cdraw.content((6.1, 6.45), [per ip], size: 6pt)
  cdraw.line((7.8, 7.1), (8.6, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.6, 6.1), (11.8, 7.8), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((10.2, 7.4), [cache:], size: 6pt)
  cdraw.content((10.2, 6.45), [GETs only], size: 6pt)
  cdraw.line((11.8, 7.1), (12.6, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.6, 6.1), (15.4, 7.8), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((14.0, 7.4), [router], size: 6pt)
  cdraw.content((14.0, 6.45), [3 routes], size: 6pt)
  let route(y, t) = {
    cdraw.rect((16.6, y), (22.6, y + 0.7), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((19.6, y + 0.35), [#t], size: 6pt)
  }
  route(7.0, "GET /items")
  route(5.9, "POST /items")
  route(4.8, "GET /items/{id}")
  cdraw.line((15.4, 7.3), (16.6, 7.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.4, 7.0), (16.6, 6.25), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.4, 6.6), (16.6, 5.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.6, 4.8), (19.6, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.6, 3.4), (22.6, 4.2), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((19.6, 3.8), [sqlite store], size: 6pt)
  cdraw.content((11.9, 2.4), [a cached POST would answer a duplicate create], size: 6pt)
  cdraw.content((11.9, 1.4), [with the first 201: GETs only], size: 6pt)
})

The design lesson baked into that listing: only GETs are cached.
The first draft cached every method and answered a duplicate
create with the first create's 201, which the conflict test caught
immediately, a real bug the tests still pin. The token bucket is
the rate limiter to be able to draw:

#listing("interview-repertoire/samples/ch20-go/api.go", first: 208, last: 247, caption: [capacity, refill per interval, one bucket per ip])

The suite covers the crud cycle, the duplicate-sku 409, the cache
hit and miss headers, invalidation, the fourth-burst 429 with
`Retry-After`, and the bucket's refill over time, all over real
http against a temp-file database that asserts its engine version
at open.

== the client-side limiter: a fake clock, no sleeps [TDD]

The server half of this module refuses the fourth burst with 429 and
a `Retry-After`. The client half is the other side of that
conversation: wait for your own token before the call, honor the
server's `Retry-After` after a refusal, and cap the honoring so a
hostile header cannot park the caller. The clock is the seam,
constructor injection again, the testing chapter's whole thesis
#xref-to("repertoire", "go-testing"), and it is what holds this
suite at zero real sleeps where the server's own refill test sleeps
60 milliseconds:

#listing("interview-repertoire/samples/ch20-go/clientlimit_test.go", first: 13, last: 55, caption: [the fake clock: Sleep advances a recorded now, and the bucket test that goes red first])

Written test first: with no limiter in the module the suite's red is
the missing constructor and the missing `Wait`, go's failing test
being a failing build, and once it compiles the assertions are what
bite, the first wait free, the second sleeping exactly one interval,
the third free again because two seconds of recorded time passed on
the fake. `fakeClock.Sleep` never blocks, it advances `now` and
appends the duration, so the assertions read the waits a client
would have taken rather than the wall clock's patience:

#listing("interview-repertoire/samples/ch20-go/clientlimit.go", first: 18, last: 49, caption: [the clock seam, the 60-second cap, the bounded attempts, the sentinel])

The declarations carry the policy. `MaxRetryAfter` is 60 seconds, so
a `Retry-After` of any size collapses to one minute.
`clientAttempts` bounds the loop at three refusals, and
`ErrStillLimited` is the sentinel that ends a retry instead of a
spin that hopes.

#listing("interview-repertoire/samples/ch20-go/clientlimit.go", first: 76, last: 128, caption: [Wait sleeps the exact deficit, Do honors the capped Retry-After])

`Wait` is the server bucket's arithmetic with the opposite refusal
policy: refill by elapsed time, and when the bucket is empty compute
the deficit, sleep exactly it, and let the sleep be the refill. `Do`
spends a token, makes the call, and on a 429 sleeps the smaller of
the header and the cap before the next pass. The second test
scripts the three scenarios: a 120-second `Retry-After` collapses to
exactly one recorded 60-second sleep and the retried call succeeds,
a 2-second header is honored uncapped, and refusals that never end
stop at three calls with the sentinel error, one honored wait per
refusal.

#diagram([the capped retry: one 429, one minute, the retry lands], length: 13pt, {
  // five beats left to right, the cap called out under the sleep
  let beat(x0, t, sub) = {
    cdraw.rect((x0, 5.6), (x0 + 4.2, 7.4), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 2.1, 6.9), [#t], size: 6.5pt)
    cdraw.content((x0 + 2.1, 6.0), sub, size: 6pt)
  }
  beat(0.4, [wait], [a token spent, 0s])
  beat(5.0, [call], [the request out])
  beat(9.6, [refusal], [429, retry-after 120s])
  beat(14.2, [honor, capped], [sleep min(120s, 60s)])
  beat(18.8, [retry], [token refilled, 200])
  cdraw.line((4.6, 6.5), (5.0, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.2, 6.5), (9.6, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.8, 6.5), (14.2, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.4, 6.5), (18.8, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.3, 4.7), [a hostile header cannot park the caller], size: 6pt)
  cdraw.content((11.6, 3.7), [three refusals end at ErrStillLimited, never a spin], size: 6pt)
  cdraw.content((11.6, 2.7), [the suite reads the recorded sleeps, one 60s entry, zero really slept], size: 6pt)
})

== the schema generator/parser [TDD]

Parse `CREATE TABLE` into a table model, generate go structs from
it. The parser handles the sqlite core, names, types, not null,
single-column primary keys, comma-safe parenthesized types, and
rejects table-level constraints loudly instead of half
understanding them:

#listing("interview-repertoire/samples/ch20-go/schema.go", first: 32, last: 62, caption: [statement splitting, the create table shape, loud rejection])

#listing("interview-repertoire/samples/ch20-go/schema.go", first: 126, last: 143, caption: [type mapping and the struct emitter])

#diagram([split, parse, map, emit, with loud rejection], length: 13pt, {
  // the generator pipeline, the reject branch, the exact-text check
  let stage(x0, name, role) = {
    cdraw.rect((x0, 5.8), (x0 + 3.8, 7.6), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 1.9, 7.2), [#name], size: 6.5pt)
    cdraw.content((x0 + 1.9, 6.2), [#role], size: 6pt)
  }
  stage(0.8, "schema.sql", "one string")
  stage(5.3, "split", "statements")
  stage(9.8, "parse", "create table")
  stage(14.3, "map", "type map")
  stage(18.8, "emit", "struct + tags")
  cdraw.line((4.6, 6.7), (5.3, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.1, 6.7), (9.8, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.6, 6.7), (14.3, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.1, 6.7), (18.8, 6.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.7, 5.8), (11.7, 4.6), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.rect((7.2, 3.8), (16.2, 4.6), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((11.7, 4.2), [reject, never half parse], size: 6pt)
  cdraw.line((20.7, 5.8), (20.7, 5.1), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.rect((18.0, 3.3), (23.0, 5.1), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((20.5, 4.55), [checked as], size: 6pt)
  cdraw.content((20.5, 3.6), [exact text], size: 6pt)
  cdraw.content((11.7, 1.6), [the failure mode it guards against is silent misparse], size: 6pt)
})

The generated-struct test asserts exact source text, tags
included, which is the discipline this repo's own listings
enforce: generated output is checked like any other output. Say
the boundary honestly: this is a teaching parser, the production
version is a proper dialect grammar, and the failure mode it
guards against is silent misparse.

sources: verified by `go vet` and `go test` through `make verify`,
15 tests in `ch20-go` over sqlite 3.53 through modernc.org/sqlite
v1.58.0, http served by net/http/httptest, the client limiter
exercised through an injected fake clock with zero real sleeps.
