#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= the offline engine and its js twin

Every number the previous two chapters mined had to arrive from somewhere
and had to reach a browser somehow. This chapter builds both ends as one
program, the offline engine in `go/data/internal/engine`: a client-side rate
limiter and an http client that survives a hostile remote, a resumable
backfill whose ledger outlives crashes, a reflection emitter that renders Go
structs as javascript literals, and a browser-side twin that rescores the
generated artifact in the page. The design adapts a real production engine,
the dota-helper pool guide, whose ingest, emit, and picker layers this
chapter reworks idea by idea rather than copying, and the honest debts are
stated as they come. The package is 7 source files and 1177 lines, stdlib
only, and its proof is 47 tests across 12 test files plus 8 node tests over
the twin.

== the offline frame

The engine runs as a pipeline with a hard wall in the middle. Everything
before the wall happens offline, on a schedule, in a terminal: the crawl
walks a graphql api one query at a time, every response is committed to a
raw cache before anything is derived from it, the mine reads only committed
files, and the emitter renders the mined tables into generated javascript.
Everything after the wall is a static page: no server, no database, no
runtime query, just the artifact plus a linear scorer and the authored gate
rules, both small enough to read in one sitting. The wall is the point.
Because the artifact is committed bytes, the whole product is reproducible
from git, and because the browser only ever sums precomputed cells, the
expensive parts cannot fail in front of a user:

#listing("go/data/internal/engine/doc.go", first: 1, last: 7, caption: [the package doc: one paragraph naming every stage the chapter builds])

#diagram([the offline frame: everything left of the wall runs in a terminal, the browser only scores committed bytes], length: 13pt, {
  let stage(x0, w, title, sub) = {
    cdraw.rect((x0, 4.2), (x0 + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.3), [#title], size: 6.5pt)
    cdraw.content((x0 + w / 2, 5.2), [#sub], size: 6pt)
  }
  stage(0.3, 4.0, [crawl], [one query in flight])
  cdraw.line((4.5, 5.6), (4.9, 5.6), stroke: luma(100), mark: (end: ">>"))
  stage(4.9, 4.0, [raw caches], [committed to git])
  cdraw.line((9.1, 5.6), (9.5, 5.6), stroke: luma(100), mark: (end: ">>"))
  stage(9.5, 4.0, [ingest + mine], [reads files only])
  cdraw.line((13.7, 5.6), (14.1, 5.6), stroke: luma(100), mark: (end: ">>"))
  stage(14.1, 4.6, [emit], [generated js artifact])
  cdraw.line((18.9, 5.6), (19.6, 5.6), stroke: luma(60), mark: (end: ">>"))
  cdraw.content((19.25, 6.6), [the wall], size: 6.5pt)
  cdraw.line((19.25, 6.3), (19.25, 4.9), stroke: luma(60), dash: "dashed")
  stage(19.8, 4.2, [static page], [twin scores, no server])
  pane(0.3, 11.2, 3.4, [before the wall], [rate limits, retries, resume], [crash-safe appends])
  pane(12.6, 23.6, 3.4, [after the wall], [one artifact, one scorer], [parity-tested in node])
  cdraw.content((11.5, 1.2), [reproducible from git, and nothing expensive can fail in a user's tab], size: 6pt)
})

The second design decision is the one that reads as heresy after chapter 6:
the engine is serial. Zero goroutine statements across the 7 source files,
zero mutexes, zero channels, and the only `sync.Mutex` in the package lives
in the test fake's request recorder, guarding the httptest handler's slice.
That is not ignorance of the concurrency chapters, it is their cost accounting
applied honestly. A crawl that must respect a rate limit of a few requests
per second has no parallel speedup to buy: the wall clock belongs to the
remote api, not the local cpu, and the mine is a batch job over committed
files that finishes in seconds. Concurrency here would add a leak surface, a
race surface, and a resume story that has to reason about interleaved
appends, and it would buy nothing measurable. Chapter 6's lesson was when
goroutines pay; this chapter is the counterexample that completes it, and
the crawl is never run with a parallel jobs flag on purpose.

One more honest note before the machinery. This module ships no fuzz
targets, and neither does the dota-helper engine it adapts. The corpus's
own fuzz culture, six stdlib fuzz targets over the api module's invariants
in chapter 30, stops at the service part's border, and the reasoning is
scope, not oversight: the engine's parseable inputs are files it wrote
itself plus remote bytes that all flow through bounded, loud failure paths,
and the property that matters most here, cross-language score parity, is
already machine-checked every verify by the fixture contract at the end of
this chapter.

== spacing plus a bucket

The client-side limiter answers a different problem than chapter 26's
service-side one. There, the bucket protected a server from its callers.
Here, the caller protects itself from the remote's limits, which arrive in
two shapes at once: a minimum spacing between requests and a burst
allowance per second. A client that respects only the spacing trips the
burst cap the moment it runs long enough, and a client that respects only
the bucket hammers the spacing floor, so the limiter enforces both and
waits the larger of the two debts:

#listing("go/data/internal/engine/ratelimit.go", first: 46, last: 70, caption: [Wait: the spacing debt and the whole-token debt compared, the larger one slept, the token charged once after])

The arithmetic is chapter 26's bucket with the refill moved into the clock:
`refill` converts elapsed time into tokens lazily on every call, capped at
the capacity, so idle time earns at most one burst and there is no ticker
and no background loop anywhere. The one new rule is the comparison. The
spacing debt is `interval - elapsed`, the token debt is `(1 - level) / rate`
seconds when the level sits under one token, and a caller that cannot pay
spends nothing: the decrement happens once, after the sleep, which is why a
denied request can never push the level negative.

Every time-dependent behavior in the package runs on an injected clock, the
two-method `Clock` interface at the top of the file. Production passes the
real clock, tests pass a fake pinned at unix zero that records each sleep
and advances instantly, so the suite asserts a 7 second Retry-After backoff
as one recorded duration instead of waiting seven seconds, and no test in
the package sleeps on wall time:

#diagram([one wait under both constraints: the bucket is empty and the spacing floor has 100ms left, the larger debt wins], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [t, seconds], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.4), stroke: luma(120))
  cdraw.content((0.4, 7.7), [tokens], size: 6pt)
  cdraw.line((0.6, 6.6), (23.2, 6.6), stroke: luma(200), dash: "dashed")
  cdraw.content((23.8, 6.6), [capacity], size: 6pt)
  // burst of five at t0, level to zero
  for i in range(5) {
    let x = 1.2 + i * 0.55
    cdraw.line((x, 6.6 - i * 1.16), (x + 0.5, 6.6 - (i + 1) * 1.16), stroke: luma(60))
  }
  cdraw.content((2.8, 3.2), [five draws, level 0], size: 6pt)
  // the next request: token debt 1s, spacing debt 0.1s
  cdraw.content((5.2, 1.15), [wait], size: 6pt)
  cdraw.line((4.6, 1.15), (10.2, 1.15), stroke: luma(60))
  cdraw.line((4.6, 0.95), (5.3, 0.95), stroke: luma(140))
  cdraw.line((5.3, 0.95), (5.6, 0.7), stroke: luma(140))
  cdraw.content((7.4, 2.1), [token debt 1s at 1/s refill], size: 6pt)
  cdraw.content((4.9, 0.35), [spacing 0.1s, the smaller debt], size: 6pt)
  // refill climb after the sleep
  cdraw.line((10.2, 1.15), (10.4, 1.3), stroke: luma(60))
  cdraw.line((10.4, 1.3), (11.0, 6.6), stroke: luma(60))
  cdraw.content((12.9, 4.6), [sleep advanced the clock, refill happened], size: 6pt)
  cdraw.line((11.0, 6.6), (11.4, 5.5), stroke: luma(60))
  cdraw.content((12.2, 5.5), [sixth allowed, charged once], size: 6pt)
  pane(15.4, 23.2, 2.6, [the injected clock], [fake sleeps are recorded], [no test waits on wall time])
  cdraw.content((11.5, -0.6), [the larger debt wins, and a caller that cannot pay spends nothing], size: 6pt)
})

== the client and its retries

The http client is deliberately plain: `net/http`, one POST per query, a
json envelope, a 30 second timeout. Two production facts shape everything
else in the file. First, the plain client is answered 403 at the edge,
because the remote fronts a bot filter that fingerprints headers, so the
browser-like headers from the options ride on every attempt, set before the
authorization header so nothing about the auth surface is ever the varying
part. Second, the failures a crawl can outlive are not the failures a
browser can: a 429 with a long Retry-After, a 502 from a dying edge, a
connection killed before any response byte, a body that dies halfway
through. All four retry. A 403 does not, because no number of attempts
fixes a forbidden client, and failing fast costs one request instead of
four:

#listing("go/data/internal/engine/client.go", first: 121, last: 158, caption: [Query: one classification switch, retryable statuses back off, wire faults wait a second, everything else fails fast])

The classification is three error types. A `statusError` carries the code,
the bounded body excerpt, and the honored Retry-After in seconds when the
status deserves one; zero seconds means final, and the switch returns it
immediately. A `transientError` wraps a transport failure or a mid-body
read failure, the two ways a remote dies that no status code can express.
Anything else, a request construction error, is a programming bug and comes
back unretried. The backoff itself honors the header but never trusts it,
because the remote's hour and day rate buckets answer Retry-After 3600 and
a crawl that slept an hour per attempt would look exactly like a hung one:

#listing("go/data/internal/engine/client.go", first: 189, last: 208, caption: [the Retry-After read: floored at 1, clamped at the cap, the clamp said out loud])

The clamp is the interesting contract. Honoring the header verbatim is
correct per the spec and catastrophic per the crawl, so the client clamps
to a configurable cap, 60 seconds by default, logs the clamp, and lets the
retries exhaust. An hour-bucketed 429 then fails visibly within minutes
with the attempt count in the error, which is the honest outcome: the
operator reads that the budget is spent today, the code never silently
parks. One more rule closes the file's security surface: the bearer token
is set on the request and appears nowhere else. Every diagnostic flows
through one logf, every error carries at most a code and a 200 byte
excerpt, and a test walks every failure arm asserting the token appears in
no log line and no error in the chain.

#diagram([the retry ladder: where each failure class lands], length: 13pt, {
  cdraw.content((11.5, 8.3), [attempt returns], size: 6.5pt)
  cdraw.line((11.5, 8.0), (11.5, 7.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.4, 5.9), (15.6, 7.3), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.6), [which failure], size: 6pt)
  cdraw.line((8.6, 5.8), (3.4, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 5.8), (11.5, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.4, 5.8), (19.8, 4.6), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 6.5, 4.4, [429 or 5xx], [honor Retry-After], [floored 1s, clamped at the cap])
  pane(8.5, 14.5, 4.4, [wire fault], [transport or mid-body], [wait 1s, retry])
  pane(16.8, 23.2, 4.4, [any other status], [403, 404, ...], [fail now, one request spent])
  cdraw.line((3.4, 1.9), (3.4, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 6.5, 1.0, [attempts left], [next attempt pays the limiter], [spacing composes with backoff])
  cdraw.line((11.5, 1.9), (11.5, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(8.5, 14.5, 1.0, [attempts left], [same ladder], [wire faults are equal citizens])
  cdraw.line((19.8, 1.9), (19.8, 1.2), stroke: luma(100), mark: (end: ">>"))
  pane(16.8, 23.2, 1.0, [exhausted], [#"after N attempts: ..." error], [the count named, the token absent])
  cdraw.content((11.5, -0.4), [a 429 with Retry-After 3600 clamps to 60s, logs it, and fails visibly if it persists], size: 6pt)
})

== fault-injecting fakes

Testing that ladder against the real api would spend the token, burn the
rate budget, and still never reproduce a mid-body disconnect on demand. The
suite instead runs every wire test against an httptest server on loopback
whose handler answers from a responder callback keyed by the request index,
so a sequencing arm is a three-line closure and needs no counters of its
own. The responder returns one canned reply per hit, and two flags on that
reply manufacture the failures a status code cannot express:

#listing("go/data/internal/engine/server_test.go", first: 107, last: 137, caption: [the responder: the hit index, the hijack arm that kills the connection pre-response, the abort arm that flushes half a body then panics])

The hijack arm takes the connection back from the http server before any
response byte and closes it, which the client observes as a plain transport
error, exactly what a blocked port or a hard reset looks like. The abort
arm writes half the body, flushes it down the wire, then panics with
`http.ErrAbortHandler`, the documented way to abort a handler without
taking the server down: the client's `io.ReadAll` receives real bytes and
then an unexpected eof, which is the mid-body read error path no mock body
can produce. Both arms are asserted through the same `Query` call as the
happy path, and both retry to success because the ladder classifies them as
wire faults.

The exported entry points construct their own client around the product
endpoint constant, which is the right production shape and the wrong test
shape, so the seam is the transport itself. A `roundTripFunc` swap replaces
`http.DefaultTransport` with a function that rewrites only scheme and host
toward the loopback server and delegates to the old transport for the real
connection, restored in a test cleanup. `Fetch` then runs its exact
production construction path, its constant endpoint included, and not one
byte leaves the machine:

#listing("go/data/internal/engine/server_test.go", first: 184, last: 207, caption: [the DefaultTransport swap: the exported entry point's traffic rewritten to loopback, scheme and host only])

#diagram([the fault arm matrix: four ways a remote answers, one responder callback], length: 13pt, {
  cdraw.rect((0.4, 4.4), (9.4, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.9, 8.1), [the fake server], size: 6.5pt)
  cdraw.content((4.9, 7.2), [responder(q, hit, req)], size: 6pt)
  cdraw.content((4.9, 6.3), [one stubReply per hit], size: 6pt)
  cdraw.content((4.9, 5.3), [loopback only, ever], size: 6pt)
  let arm(x0, title, l1, l2) = {
    cdraw.rect((x0, 4.4), (x0 + 4.6, 8.6), fill: luma(245), radius: 0.02)
    cdraw.content((x0 + 2.3, 8.1), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.3, 7.0), [#l1], size: 6pt)
    cdraw.content((x0 + 2.3, 6.0), [#l2], size: 6pt)
  }
  cdraw.line((9.6, 6.5), (10.0, 6.5), stroke: luma(100), mark: (end: ">>"))
  arm(10.0, [ok], [200 + envelope], [returns the body])
  cdraw.line((14.8, 6.5), (15.2, 6.5), stroke: luma(100), mark: (end: ">>"))
  arm(15.2, [429 / 5xx], [Retry-After header], [backoff, clamped])
  cdraw.line((9.6, 3.6), (10.0, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(10.0, 14.6, 3.8, [hijack], [conn closed pre-response], [client sees a transport error])
  cdraw.line((14.8, 3.6), (15.2, 3.6), stroke: luma(100), mark: (end: ">>"))
  pane(15.2, 19.8, 3.8, [abort], [half body flushed, then], [panic(http.ErrAbortHandler)])
  pane(20.0, 23.6, 3.8, [the seam], [exported entries ride], [the DefaultTransport swap])
  cdraw.content((11.5, 0.9), [every arm exercises the same Query call the happy path runs], size: 6pt)
  cdraw.content((11.5, 0.1), [nothing leaves loopback: the transport itself forgets the real endpoint], size: 6pt)
})

== the resumable backfill

A crawl over thousands of remote pages will be interrupted, by a rate
budget, a network death, or an operator, and the only sane answer is that
restarting costs the work not yet done and nothing else. The backfill keeps
two files in one directory: an append-only ndjson ledger, one json object
per line keyed by id, and a manifest, the resume record that names how far
the walk got, what it kept and dropped and why, how many requests it spent,
and whether the window is exhausted. Committed lines are never rewritten,
so the ledger is safe to append across crashes, and the dedupe set is
rebuilt from the committed bytes on every run, so a page the previous run
already landed can never land twice.

The one crash case that needs actual repair is the torn tail. A process
killed mid-append can leave a last line with no newline, either because the
bytes never finished arriving or because the newline itself was the byte
that did not land. The loader distinguishes the two: a complete row missing
only its newline is kept and terminated, a torn fragment is dropped, and
either way the file is rewritten once so later appends never glue onto a
half line. The line it refuses to cross is just as deliberate: a corrupt
line with committed lines after it is corruption, not a crash tail, and
resuming from a silently shrunken set would rewalk pages the ledger already
owns, so that fails loudly with the line number and the bytes:

#listing("go/data/internal/engine/backfill.go", first: 38, last: 83, caption: [LoadSeen: the torn-tail repair, keep-and-terminate or drop, then the loud walk over committed lines])

The walk itself is a loop with three exits, the target row count, the end
of the window, and the per-run request budget, and the checkpoint lands
after every page. A fetch error returns with the manifest already saved and
the cursor parked at the failed page, so the rerun retries exactly that
page and the ledger dedupes anything a half-written page left behind. The
budget exit is what makes the crawl polite by construction: two pages now,
the rest tomorrow, and the manifest is the whole conversation between the
two runs:

#listing("go/data/internal/engine/backfill.go", first: 164, last: 204, caption: [Run: three exits, one checkpoint per page, the cursor never moves past a page it did not survive])

#diagram([crash mid-append, the repair, and the resume: what each run redoes], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 5.0), (x0 + w, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.7), [#title], size: 6.5pt)
    cdraw.content((x0 + w / 2, 5.7), [#l1], size: 6pt)
  }
  step(0.3, 5.4, [run one], [page 0, 1 done, budget spent])
  cdraw.line((5.9, 6.2), (6.3, 6.2), stroke: luma(100), mark: (end: ">>"))
  step(6.3, 5.4, [crash mid-append], [#"{"id":3,"payl"])
  cdraw.line((11.9, 6.2), (12.3, 6.2), stroke: luma(100), mark: (end: ">>"))
  step(12.3, 5.2, [loadSeen repairs], [fragment dropped, tail terminated])
  cdraw.line((17.7, 6.2), (18.1, 6.2), stroke: luma(100), mark: (end: ">>"))
  step(18.1, 5.5, [run two resumes], [page 2, ids dedupe, done])
  pane(0.3, 11.2, 3.6, [the ledger], [append only, ids unique], [committed lines never rewritten])
  pane(12.3, 23.6, 3.6, [the manifest], [cursor, kept, dropped, reasons], [requests, done flag, checkpointed per page])
  cdraw.content((11.5, 1.4), [a torn fragment is dropped, a complete row missing its newline is kept], size: 6pt)
  cdraw.content((11.5, 0.5), [a corrupt line mid-file fails loudly with its number, never a silent rewalk], size: 6pt)
})

== the store decision

The mine needs somewhere to land its tables, and this module's ruling is
the plainest one that tells the truth: an in-memory store with provenance
rows, rebuilt from the committed raw layer on every run, stdlib only. The
store keeps one cell per key with the source that last wrote it and an
audit trail of provenance rows, one per recorded fact, because every mined
number eventually faces the question that is not what it is but where it
came from:

#listing("go/data/internal/engine/store.go", first: 12, last: 35, caption: [provenance rows and the in-memory landing zone, rebuilt per run, no lock because no second client exists])

The ruling is scoped, not global. The dota-helper engine this chapter
adapts mines through real analytics instead: duckdb behind the duckdb-go
driver, imported unconditionally there and kept off the windows dev box
by running every build and test inside a linux docker image. The corpus
takes the build-tag road on its own duckdb lane, the `duckdb_use_lib`
tag behind make verify-go, and teaches it where the workload justifies
it, in
#xref-to("kdd", "capstone"), whose capstone runs the whole discovery
pipeline on duckdb. This book's other storage posture is chapter 23's wal
engine, where durability is the product being taught. Here, neither
applies: the data part's tables are roster-sized, tens of thousands of
cells at most, the
store is a cache in front of committed files, and a map plus a slice plus a
sorted snapshot costs less than any of the honest alternatives would cost
to justify. The `Cells` snapshot sorts by key so two runs over the same raw
layer produce byte-identical snapshots regardless of Go's map iteration
order, which is the same determinism discipline the emitter enforces one
section later.

#diagram([three storage postures, one per workload], length: 13pt, {
  let cellf(x0, w, title, l1, l2, l3) = {
    cdraw.rect((x0, 2.2), (x0 + w, 8.6), fill: luma(238), radius: 0.02)
    cdraw.content((x0 + w / 2, 8.1), [#title], size: 6.5pt)
    cdraw.content((x0 + w / 2, 7.0), [#l1], size: 6pt)
    cdraw.content((x0 + w / 2, 6.1), [#l2], size: 6pt)
    cdraw.content((x0 + w / 2, 5.2), [#l3], size: 6pt)
  }
  cellf(0.3, 7.2, [this module], [in-memory map], [provenance rows], [rebuilt per run])
  cellf(8.2, 7.2, [dota-helper], [duckdb via duckdb-go], [unconditional import], [columnar scans])
  cellf(16.1, 7.4, [chapter 23], [the wal engine], [durability taught], [snapshot compaction])
  cdraw.content((4.0, 3.6), [roster-sized tables], size: 6pt)
  cdraw.content((4.0, 2.8), [stdlib-only ruling], size: 6pt)
  cdraw.content((11.8, 3.6), [real aggregates to mine], size: 6pt)
  cdraw.content((11.8, 2.8), [the kdd lane owns it], size: 6pt)
  cdraw.content((19.8, 3.6), [a service's database], size: 6pt)
  cdraw.content((19.8, 2.8), [recovery is the point], size: 6pt)
  cdraw.content((11.8, 1.0), [the store is a cache in front of committed files: pick per workload, say the trade out loud], size: 6pt)
})

== the go-to-js emitter

The artifact is a javascript file, and rendering it through `encoding/json`
would be almost right, which is worse than wrong: json quotes with double
quotes and escapes the wrong things for a script tag, map iteration order
would leak Go's randomized map order into committed bytes, and the float
formatter json picks is not the one the twin rescores against. So the
emitter is 155 lines of reflection that walks any json-shaped value and
renders the literal the artifact actually wants. Struct fields render in
declaration order honoring json names, `omitempty` drops zero values,
unexported fields and dash tags skip exactly what `encoding/json` skips,
map keys sort ascending so the bytes out are a pure function of the value
in, and NaN and both infinities render as null because the artifact is a
script tag and none of the three has a literal:

#listing("go/data/internal/engine/js.go", first: 117, last: 153, caption: [the struct arm: declaration order, json names, omitempty, the dash tag and unexported fields skipped like the standard encoder])

The one function the whole parity contract rests on is smaller than its
consequences. `RoundFixed` rounds a float by printing it at a fixed number
of decimals and parsing the printed string back, which sounds circular
until the artifact enters the picture: the packed cells the twin reads were
printed at 4 decimals, so the engine rescores against the digits the
artifact ships, not the unrounded doubles that produced them. Without this
function the Go side would average values the browser never saw, and the
two scores would drift in the fourth decimal forever:

#listing("go/data/internal/engine/js.go", first: 54, last: 61, caption: [RoundFixed: parse back exactly what fmtFixed printed, the artifact's digits are the truth])

#diagram([the type walk: one switch, six shapes, one panic], length: 13pt, {
  cdraw.content((11.5, 8.8), [jsValue(v)], size: 6.5pt)
  cdraw.line((11.5, 8.5), (11.5, 7.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((6.9, 6.5), (16.1, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 7.2), [reflect.ValueOf(v).Kind()], size: 6pt)
  let leaf(x0, x1, y, label) = {
    cdraw.rect((x0, y - 0.55), (x1, y + 0.55), fill: luma(245), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, y), [#label], size: 6pt)
  }
  cdraw.line((8.4, 6.4), (3.6, 5.4), stroke: luma(100), mark: (end: ">>"))
  leaf(0.3, 6.9, 4.9, [string: quoteJS, single quotes])
  leaf(0.3, 6.9, 3.6, [bool, int, uint: formatted])
  leaf(0.3, 6.9, 2.3, [float: short, NaN/Inf are null])
  cdraw.line((11.5, 6.4), (11.5, 5.6), stroke: luma(100), mark: (end: ">>"))
  leaf(8.6, 14.6, 4.9, [slice/array: [a, b, c]])
  leaf(8.6, 14.6, 3.6, [nil pointer/interface: null])
  cdraw.line((14.6, 6.4), (19.6, 5.4), stroke: luma(100), mark: (end: ">>"))
  leaf(16.2, 23.2, 4.9, [map: keys sorted ascending])
  leaf(16.2, 23.2, 3.6, [struct: json tags, omitempty])
  cdraw.line((19.8, 3.0), (19.8, 1.9), stroke: luma(100), mark: (end: ">>"))
  pane(16.2, 23.2, 1.4, [anything else], [panic, the kind named], [never a silent literal])
  cdraw.content((5.5, 1.2), [deterministic bytes: same value in, same bytes out, any number of runs], size: 6pt)
  cdraw.content((5.5, 0.4), [RoundFixed pins every packed cell at 4 decimals on its way through], size: 6pt)
})

== golden tests

An emitter whose output is committed bytes needs a test that reads those
bytes, and the corpus pattern is the update flag: a plain `flag.Bool`
parsed by `go test`, false by default, true under
`go test ./internal/engine -update`, and one check function that either
compares or rewrites. The committed golden is the contract. Nobody edits it
by hand, and a change to the payload, the emitter, or the fixture generator
shows up as a one-line diff instead of two walls of generated bytes,
because the failure path prints `firstDivergence`, the first line where
want and got disagree, both lines quoted:

#listing("go/data/internal/engine/golden_test.go", first: 12, last: 38, caption: [checkGolden: the update flag, the compare path, the drift named by its first divergent line])

Two disciplines keep the pattern honest. The first is the cache: Go's
test cache keys on the files a test reads at runtime, the recorded opens
hashed into the key, so a golden edited with no code change busts the
cache and the plain run fails honestly. A run about to trust a golden
still passes `-count=1` when it wants execution rather than recall: the
flag makes the run prove the suite ran on the tree in front of it, warm
cache or not, the discipline the dota-helper emit suite adopted for its
own note. The second is the generator's determinism,
asserted directly: the parity fixture is built twice from one seed pair
and the two artifacts must be byte-identical, which holds because the
seeded PCG stream is stable by construction and the emitter sorts every
map it walks. A golden over a nondeterministic generator would be a
flaky test wearing a contract's clothes.

The generated artifact in this package is one file, `testdata/parity-data.js`,
1380 bytes, and its golden gate is what makes the next section's parity
contract work: because the Go emitter's bytes and the committed file are
proven identical, the node suite can read that file as the shared truth
without any Go runtime in the room.

#diagram([the golden gate: emit, compare, and the one line a drift costs], length: 13pt, {
  let step(x0, w, title, l1) = {
    cdraw.rect((x0, 5.0), (x0 + w, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.7), [#title], size: 6.5pt)
    cdraw.content((x0 + w / 2, 5.7), [#l1], size: 6pt)
  }
  step(0.3, 5.6, [build the fixture], [seeded PCG, one seed pair])
  cdraw.line((6.1, 6.2), (6.5, 6.2), stroke: luma(100), mark: (end: ">>"))
  step(6.5, 5.6, [emit the bytes], [reflection, sorted keys, 4dp cells])
  cdraw.line((12.3, 6.2), (12.7, 6.2), stroke: luma(100), mark: (end: ">>"))
  step(12.7, 5.6, [compare], [testdata/parity-data.js])
  cdraw.line((18.5, 6.2), (18.9, 6.2), stroke: luma(100), mark: (end: ">>"))
  step(18.9, 4.7, [verdict], [green or line N])
  pane(0.3, 11.2, 3.8, [-update], [rewrites the golden], [never edited by hand])
  pane(12.7, 23.6, 3.8, [a drift], [firstDivergence names], [line, want, got, quoted])
  cdraw.content((11.5, 3.7), [the cache keys on runtime reads too: -count=1 keeps every verify run an execution], size: 6pt)
  cdraw.content((11.5, 2.8), [determinism is asserted too: two builds, one seed pair, identical bytes], size: 6pt)
})

== the twin and the parity contract

The browser side of the frame is a 156-line javascript twin of the Go
scorer, written as a dual-use module: the same file is a plain `<script>`
that hangs `PoolScore` off the global object for the static page, and a
CommonJS export the node suite imports, the one pattern that serves both
hosts without a bundler. It reads only the artifact's shape, and it fails
loud on a corrupt payload rather than scoring on a duplicated stale copy of
the constants: missing or nonpositive score constants throw, a role the
synergy weights do not know throws, an unknown condition kind throws
instead of quietly answering false and disarming a rule, and so does an
unknown action. The Go side returns errors on exactly the same arms, which
is the parity discipline applied to failure too:

#listing("go/data/internal/engine/twin/score.js", first: 58, last: 103, caption: [the twin's scoreCandidate: same terms, same order, same operations, throws where the Go side errors])

The accumulation is the heart of it. Both sides sum six terms in one fixed
order, known matchup weighted by visible enemies, known synergy weighted by
the role and visible allies, the prior, the generic fit over unseen heroes
weighted by the unseen share, the exposure overhang weighted by the empty
enemy share, then the gate delta, and every sub-expression matches
operation for operation: the means sum ascending then divide, the
popularity weighting interleaves numerator and denominator per element, and
the Go line `score -= w * frac * exposure` is the twin's `score -= W.exposure * frac * exposure`
with the operands in the same tree. IEEE 754 arithmetic is deterministic
per operation, so identical operation sequences give identical doubles,
which is why the contract can demand bit-identical scores rather than
scores within an epsilon:

#listing("go/data/internal/engine/score.go", first: 212, last: 223, caption: [the Go accumulation the twin mirrors line for line])

None of that is worth anything unless something checks it, so the parity
contract is machine-checked through one committed fixture. The Go test
builds the payload from a seeded PCG, one fixed seed pair, renders it
through the emitter, and golden-gates the bytes as `testdata/parity-data.js`.
It then scores a frozen draft board against that payload and asserts two
exact constants. The node test reads the same committed file, evaluates it
under a `window` shim exactly as a browser would, scores the same frozen
board through the twin, and asserts the same two constants with plain
`===` equality. Parity is transitive: Go equals the artifact, the artifact
equals what node reads, and both suites pin the same 17 significant digits,
`1.2223335616139586` for charlie with the nudge applied and
`0.71824239654427635` for alpha under the hard gate, digits that round-trip
a float64 exactly, so both literals parse to the same double:

#listing("go/data/internal/engine/twin/score.test.mjs", first: 34, last: 48, caption: [the node side of the contract: the committed artifact, the frozen board, plain equality on both constants])

The twin suite is plain `node:test` plus `node:assert/strict`, zero
dependencies, deterministic, and it runs inside `make verify` through the
`verify-data-twin` lane right after the companion gate, so the parity
contract is checked on every verify of the corpus. A hand-computed fixture
rides beside the generated one in both suites, every value a quarter or an
eighth so the expected scores, `1.21875` for the gated alpha and `0.875`
for charlie, are exact doubles a human can verify with pencil and paper,
which is what keeps the frozen constants honest: the pencil arithmetic and
the seeded generator agree, in two languages, on every verify.

#diagram([the parity contract: one committed fixture, two suites, one constant], length: 13pt, {
  cdraw.rect((7.6, 5.2), (15.4, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.1), [testdata/parity-data.js], size: 6.5pt)
  cdraw.content((11.5, 7.1), [committed bytes, 1380], size: 6pt)
  cdraw.content((11.5, 6.1), [seeded PCG, 4dp packed cells], size: 6pt)
  cdraw.line((8.6, 5.1), (5.4, 4.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.4, 5.1), (17.6, 4.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.4, 1.6), (10.4, 4.0), fill: luma(245), radius: 0.02)
  cdraw.content((5.4, 3.5), [go test], size: 6.5pt)
  cdraw.content((5.4, 2.6), [emits the bytes, gates the golden], size: 6pt)
  cdraw.content((5.4, 1.9), [scores the frozen board], size: 6pt)
  cdraw.rect((13.0, 1.6), (23.0, 4.0), fill: luma(245), radius: 0.02)
  cdraw.content((18.0, 3.5), [node --test], size: 6.5pt)
  cdraw.content((18.0, 2.6), [evals the file under window], size: 6pt)
  cdraw.content((18.0, 1.9), [scores the same frozen board], size: 6pt)
  cdraw.line((5.4, 1.5), (5.4, 0.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.0, 1.5), (18.0, 0.8), stroke: luma(100), mark: (end: ">>"))
  pane(7.8, 15.2, 0.4, [one constant], [#"1.2223335616139586"], [plain === on both sides])
  cdraw.content((11.5, -0.7), [transitive: go equals the artifact, the artifact equals what node reads, parity is machine-checked per verify], size: 6pt)
})

sources: pkg.go.dev for net/http including the DefaultTransport swap and
http.ErrAbortHandler semantics, encoding/json for the struct tag rules the
emitter honors, reflect for the value walk, and testing for the flag
pattern inside go test, nodejs.org for node:test and node:assert/strict,
plus the dota-helper repository's engine (internal/ingest, internal/emit,
internal/order) and picker layer this chapter adapts, read at
`C:\Users\lavantien\dev\github\dota-helper`, all accessed 2026-10-05.
Verified by `go/data/internal/engine` tests, 47 of them across 12 files,
under `go vet`, `go test`, and the race detector, and the twin, 8 node
tests, under `make verify-data-twin`, with the parity artifact pinned
byte for byte in `testdata/parity-data.js`.
