#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= capstone: concurrent crawler, indexer, and web ui

The capstone is a small search engine front half: a crawler walks a
link graph under a concurrency cap, the indexer folds fetched pages
into an inverted index with uuid stamped documents, the store
writes documents and postings into sqlite through a pure Go
driver, and a web ui serves search and crawl control over htmx
fragments that templ components render. It lives
in this repo at
`go/capstone/`, its own go module, 32 tests, zero skipped, runnable
from that folder with `go test`, stable across repeated runs because
nothing in it sleeps, the ui's tests included: they wait on the
crawl's done channel, never on a clock. Every chapter's material
appears once, for
real: the walkers are goroutines under a semaphore and a WaitGroup,
the fetch transport is an interface, the errors wrap, the documents
carry v7 uuids, the snapshots are deterministic, the result type
uses a generic method, and the ui is the fragment contract chapters
16 and 17 taught, answered over the real pipeline.

#flow(
  [capstone pipeline],
  node((0, 0), [crawler: goroutines, semaphore cap]),
  edge("-|>"),
  node((1.3, 0), [pages: map[url]body]),
  edge("-|>"),
  node((2.6, 0), [indexer: tokenize, uuid v7]),
  edge((2.6, 0), (2.6, -1.2), "-|>"),
  node((2.6, -1.2), [inverted index]),
  edge((2.6, -1.2), (1.3, -1.2), "-|>"),
  node((1.3, -1.2), [json v2 snapshot]),
  edge((1.3, -1.2), (0.0, -2.4), "-|>"),
  node((0.0, -2.4), [store: sqlite, postings, fts5]),
  edge((1.3, 0), (2.6, -2.4), "-|>"),
  node((2.6, -2.4), [web ui: htmx fragments, templ]),
)

== the fetch boundary

Transport is an interface with one method, so the test suite drives
the crawler over an in-memory web with fetch counters and a
concurrency gauge, and production plugs in net/http without touching
the walker:

#listing("go/capstone/crawler/crawler.go", first: 14, last: 24, caption: [page, fetcher, the whole boundary])

#diagram([the one method boundary: walker above, two transports below], length: 13pt, {
  cdraw.rect((0.3, 5.4), (11.3, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.7), [the walker], size: 6.5pt)
  cdraw.content((5.8, 5.8), [knows pages and rules,], size: 6pt)
  cdraw.line((5.8, 5.2), (5.8, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((3.4, 4.8), [asks for], size: 6pt)
  cdraw.rect((0.3, 3.0), (11.3, 4.4), fill: luma(222), radius: 0.02)
  cdraw.content((5.8, 3.7), [#"Fetcher: one method"], size: 6pt)
  cdraw.line((3.0, 2.8), (3.0, 2.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((8.6, 2.8), (8.6, 2.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 0.6), (5.9, 2.0), fill: luma(205), radius: 0.02)
  cdraw.content((3.1, 1.3), [the fake site], size: 6pt)
  cdraw.rect((6.5, 0.6), (11.3, 2.0), fill: luma(205), radius: 0.02)
  cdraw.content((8.9, 1.3), [net/http], size: 6pt)
  pane(12.7, 23.3, 7.2, [what the fake proves], [fetch counters: each url], [fetched exactly once, and], [a gauge: the cap holds])
  cdraw.content((18.0, 1.9), [production plugs in], size: 6pt)
  cdraw.content((18.0, 0.8), [without touching the], size: 6pt)
  cdraw.content((18.0, -0.3), [walker at all], size: 6pt)
})

The fake site in the test file is 34 lines and knows every page
visit, which is how the suite proves each url is fetched exactly
once even when two pages link it, and how it proves the concurrency
cap holds.

== result, the generic method

The walker's plumbing carries values-or-errors, and go 1.27 lets
that type be honest with a method that adds its own parameter:

#listing("go/capstone/crawler/crawler.go", first: 27, last: 51, caption: [result of t, mapped to result of u])

#diagram([result chains with the error riding along, map short circuits], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [#"Result[T]"], [value or error])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((5.9, 6.2), [#"Map[U]"], size: 6pt)
  stage(6.1, [#"Result[U]"], [f ran on the value])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.7, 7.3), [UnwrapOr], size: 6pt)
  stage(11.9, [the value], [or the fallback])
  cdraw.content((6.6, 3.4), [on error: f never runs, the error], size: 6pt)
  cdraw.content((6.6, 2.3), [rides to the end unchanged], size: 6pt)
  pane(17.7, 23.3, 4.4, [1.27], [a method with its], [own type param])
  cdraw.content((6.6, 0.6), [before 1.27 this was a package level function], size: 6pt)
})

`Map` transforms the value and short circuits the error, `UnwrapOr`
terminates the chain with a fallback, and the tests pin both
behaviors including that a failed result never invokes the mapping
function. Before 1.27 this type needed a package level `MapResult`
function, the workaround the release notes retired.

== the walk

Breadth first, depth limited, concurrency capped, cancellation
aware, dedup on enqueue:

#listing("go/capstone/crawler/crawler.go", first: 53, last: 92, caption: [the visit recursion under semaphore and waitgroup])

#diagram([one visit: dedup before fetch, cancel before select, spawn at lower depth], length: 13pt, {
  let step(y, label, fill) = {
    cdraw.rect((0.3, y - 0.5), (7.9, y + 0.7), fill: fill, radius: 0.02)
    cdraw.content((4.1, y + 0.1), [#label], size: 6pt)
  }
  step(7.3, [url from a parent], luma(235))
  cdraw.line((4.1, 6.6), (4.1, 6.0), stroke: luma(100), mark: (end: ">>"))
  step(5.4, [mark visited, mutex], luma(235))
  cdraw.content((11.2, 5.5), [dedup on enqueue:], size: 6pt)
  cdraw.content((11.2, 4.4), [one fetch per url even], size: 6pt)
  cdraw.content((11.2, 3.3), [when two pages link it], size: 6pt)
  cdraw.line((4.1, 4.7), (4.1, 4.1), stroke: luma(100), mark: (end: ">>"))
  step(3.5, [ctx.Err() first], luma(222))
  cdraw.content((11.2, 2.2), [select is random among], size: 6pt)
  cdraw.content((11.2, 1.1), [ready cases, so check], size: 6pt)
  cdraw.line((4.1, 2.8), (4.1, 2.2), stroke: luma(100), mark: (end: ">>"))
  step(1.6, [semaphore, fetch], luma(235))
  cdraw.line((4.1, 0.9), (4.1, 0.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, -0.9), (7.9, 0.3), fill: luma(205), radius: 0.02)
  cdraw.content((4.1, -0.3), [spawn: depth minus 1], size: 6pt)
  pane(16.4, 23.3, 7.3, [the closer], [one goroutine waits on], [the WaitGroup, then closes], [the results channel])
  cdraw.content((19.8, 2.4), [the consumer ranges until], size: 6pt)
  cdraw.content((19.8, 1.3), [that close arrives], size: 6pt)
})

Four rules interact. The semaphore caps simultaneous fetches, and
the test asserts the gauge never crosses the cap. The visited map is
marked when a url is enqueued, not when fetched, so two pages
linking the same target cause one fetch, and the mutex around the
mark is what makes the check-and-set atomic. The WaitGroup counts
outstanding visits, a closer goroutine converts `wg.Wait` into a
channel, and the outer select honors cancellation while draining.
Failures append to a slice and the walk continues, because one dead
link is not a dead crawl, while a cancelled context stops spawning
and surfaces `context.Canceled` in the returned errors.

#callout("pitfall", "select is random among ready cases", [
  The first draft guarded the fetch with a select over the
  semaphore slot and `ctx.Done()`. With a pre-cancelled context and
  a free slot both cases are ready, select picks randomly, and the
  test caught the crawler fetching pages it had no right to touch.
  The explicit `ctx.Err()` check before the select is the fix, a
  lesson the test suite wrote into this chapter.
])

== the index side

Documents tokenize on whitespace, lowercase, trim edge punctuation,
and take a v7 uuid so ids sort by creation:

#listing("go/capstone/index/index.go", first: 15, last: 34, caption: [doc and tokenizer, the lowered-body form the profiled section pays for])

#diagram([body to doc to postings to snapshot, one fold each way], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [tokenize], [split, lower, trim])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [stamp], [a v7 uuid, sorts])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [postings], [word to set of urls])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [snapshot], [json v2, sorted])
  cdraw.content((11.8, 3.4), [the snapshot is deterministic: url lists sorted], size: 6pt)
  cdraw.content((11.8, 2.3), [before encoding, Deterministic(true), so equal], size: 6pt)
  cdraw.content((11.8, 1.2), [indexes marshal to equal bytes], size: 6pt)
})

The index itself is the classic inverted structure, word to set of
urls, built in one fold, queried in one lookup plus a sort:

#listing("go/capstone/index/index.go", first: 36, last: 67, caption: [build, search, vocabulary])

Snapshots go through json v2 with `Deterministic(true)` over url
lists sorted before encoding, so the test asserts byte equality
between two snapshots of equal indexes, and `Load` is the round trip
that must survive:

#listing("go/capstone/index/index.go", first: 69, last: 100, caption: [snapshot form, marshal, load])

== the store, sqlite without cgo

The index side lives in memory, and the store package makes the
results survive a restart: documents and postings written to
sqlite through `database/sql` over modernc.org/sqlite, a pure Go
driver, so the module needs no cgo toolchain. The schema is three
tables, documents keyed by the doc's uuid, the postings inverted
index as a `WITHOUT ROWID` pair keyed term first, and an fts5
virtual table holding each doc's joined words. `Open` applies it
idempotently, the dsn turns on foreign keys, a wal journal, and a
busy timeout, and the pool holds a single connection because
sqlite allows one writer, so `SaveDoc` transactions never meet the
busy handler:

#listing("go/capstone/store/store.go", first: 23, last: 58, caption: [schema and open, wal journal, one pooled connection])

#diagram([the store stack: one interface, one pooled connection of one, one file], length: 13pt, {
  let stage(y, title, l1) = {
    cdraw.rect((0.9, y), (9.5, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((5.2, y + 0.9), [#title], size: 6pt)
    cdraw.content((5.2, y + 0.25), [#l1], size: 6pt)
  }
  stage(5.9, [store: SaveDoc, Search, Match], [one transaction per doc, reads two ways])
  cdraw.line((5.2, 5.8), (5.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  stage(3.7, [database/sql], [one pooled connection, sqlite allows one writer])
  cdraw.line((5.2, 3.6), (5.2, 3.0), stroke: luma(100), mark: (end: ">>"))
  stage(1.5, [modernc.org/sqlite], [pure go, no cgo, fts5 built in])
  cdraw.line((5.2, 1.4), (5.2, 0.8), stroke: luma(100), mark: (end: ">>"))
  stage(-0.7, [the sqlite file], [wal journal, foreign keys, busy timeout])
  cdraw.content((17.5, 4.4), [the schema], size: 6.5pt)
  cdraw.content((17.5, 3.5), [documents by uuid], size: 6pt)
  cdraw.content((17.5, 2.6), [postings, word to url set], size: 6pt)
  cdraw.content((17.5, 1.7), [fts5 joined text, phrase match], size: 6pt)
})

`SaveDoc` writes one document as one transaction: the row upserts
on its uuid, a resave deletes the previous postings and fts row
before writing new ones so replacement never appends, the words
dedup into postings, and the joined text lands in the fts table,
commit or rollback as a unit:

#listing("go/capstone/store/store.go", first: 63, last: 107, caption: [savedoc, one transaction for document, postings, fts])

Reading goes two ways. `Search` is the persisted mirror of
`index.Search`, postings joined to documents and ordered by url,
the term lowercased first. `Match` runs text as an fts5 phrase
with inner quotes doubled, so arbitrary crawled input is always a
phrase and never fts5 syntax:

#listing("go/capstone/store/store.go", first: 109, last: 126, caption: [search over postings, match as a quoted phrase])

Six tests pin the package. One probes the driver, asserting
`sqlite_version()` is at least 3.53, and another that the pinned
modernc build accepts fts5 virtual tables at all. Reopen survival
closes the store and searches again from disk, a resave replaces
postings without duplicating the document row, `Match` agrees with
`Search` on single terms, and the phrase narrows past them, "go
notes" matching one page where "go" alone matches two.

== the web ui

The ui is chapter 16's contract answered with chapter 17's
components: one htmx page whose search box and status panel poll
fragments, every fragment a templ component rendered to the
response, htmx 4.0.0 vendored under `internal/web/static/` and
pinned by the same SRI digest recipe, the served bytes hashed by a
test. A `CrawlService` wraps the crawler behind a mutex, seeded
with a fake site in the style of the crawler package's own test
fixture, so the crawl endpoint needs no network. A finished crawl
folds its pages through `index.NewDoc` into the store, keeps the
json snapshot for serving, and closes a done channel the tests wait
on:

#listing("go/capstone/internal/web/crawl.go", first: 72, last: 88, caption: [the service: crawler, fetcher, and store behind one mutex])

The routes are six, method patterns again, so a wrong verb is a 405
from the mux itself. `cmd/serve` mounts this handler over a
database file and a port, the whole binary:

#listing("go/capstone/internal/web/web.go", first: 49, last: 59, caption: [six routes: page, search, status, crawl, snapshot, static])

Search splits by word count: one word goes through the postings
lookup, several through the fts5 phrase match, the store's two read
paths from the previous section, and a missing q is a 400 whose
body is the error row itself, swapped in 4.0 style:

#listing("go/capstone/internal/web/web.go", first: 65, last: 88, caption: [the fragment route, both store read paths, the 400])

The status panel is the polled fragment: a templ component carrying
its own id, the interval, and the outerHTML swap that keeps the id
stable across polls, exactly the shape chapter 16 hand built and
chapter 17 compiled:

#listing("go/capstone/internal/web/status.templ", first: 3, last: 16, caption: [the polled fragment as a component, every 2s, outerHTML])

The suite waits rather than sleeps. `Start` hands back nothing, but
`Wait` blocks on the done channel the run closes, so the test
starts a crawl, waits, then reads the fragment over the completed
state, deterministic and fast:

#listing("go/capstone/internal/web/web_test.go", first: 181, last: 197, caption: [wait on the channel, then assert the fragment over the result])

The remaining tests pin the contract end to end: the SRI tag and
the served digest, the seeded search fragment, the phrase narrowing
past the single term, the hostile query escaped in the fragment,
the crawl start's `HX-Trigger` header, the 409 for a second start
while one runs, observed through a gated fetcher that holds the
crawl mid flight, and the 405s. Twelve tests, all over real http
through `httptest`, no browser.

#diagram([the ui: fragments over the real pipeline, both taught chapters paying off], length: 13pt, {
  cdraw.rect((0.3, 4.6), (7.3, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 6.7), [the page], size: 6.5pt)
  cdraw.content((3.8, 5.7), [script with sri, panels], size: 6pt)
  cdraw.content((3.8, 4.9), [composed by templ], size: 6pt)
  cdraw.line((7.5, 5.9), (8.5, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.7, 4.6), (15.9, 7.2), fill: luma(222), radius: 0.02)
  cdraw.content((12.3, 6.7), [the fragments], size: 6.5pt)
  cdraw.content((12.3, 5.7), [search, status, crawl], size: 6pt)
  cdraw.content((12.3, 4.9), [every 2s poll, hx-trigger], size: 6pt)
  cdraw.line((16.1, 5.9), (17.1, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((17.3, 4.6), (23.3, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((20.3, 6.7), [the pipeline], size: 6.5pt)
  cdraw.content((20.3, 5.7), [crawl, newdoc, store], size: 6pt)
  cdraw.content((20.3, 4.9), [snapshot json kept], size: 6pt)
  cdraw.content((11.8, 3.2), [12 ui tests, httptest only, waits on the done], size: 6pt)
  cdraw.content((11.8, 2.1), [channel instead of sleeps, 405 from the mux,], size: 6pt)
  cdraw.content((11.8, 1.0), [409 through a gated fetcher holding the crawl], size: 6pt)
})

== profiled, and why

The module measures itself. Four benchmark functions in
`index/bench_test.go` run the real paths, tokenize, fold, lookup,
serialize, over a fixed seeded corpus of 200 documents of roughly 60
mixed-case words from a 400-word vocabulary, and one real change
went through the whole discipline the profiling chapter teaches:

#listing("go/capstone/index/benchstat.txt", first: 11, last: 17, caption: [the A/B: one change, three flat controls])

The change is in the tokenizer listing above:
`strings.ToLower` moved from each word to the whole body before
`Fields`, so one allocation replaces one per capitalized word. The
table says 19.34 percent faster with p=0.009 over ten runs each,
62 allocations down to 3 at p=0.000, and bytes unchanged at
p=1.000, the same 2.469 KiB reshaped from 62 small strings into 3
allocations, exactly the size class arithmetic chapter 10 predicts.
The three flat rows are the honest part: Build, Search, and
Snapshot do not touch NewDoc's body path, and benchstat reports
them statistically unchanged instead of letting a geomean imply the
whole engine improved. The suite pins the new count at exactly 3
with `testing.AllocsPerRun` over the same fixed body.

The next question is where the rest of the time goes, and the cpu
profile over `BenchmarkBuild` answers it:

#listing("go/capstone/index/pprof-flat.txt", first: 13, last: 20, caption: [build's flat top: the map is the machine])

Reading it through chapters 10 and 11: `mapassign_faststr` holds
39.90 percent cumulative, and the flat top is the swiss table's own
parts, `memHashAES` at 10.10 percent hashing every word key and
`matchH2` at 7.21 percent probing groups. Map growth and rehash
take another 15.38 percent cumulative, and the gc helpers,
`gcDrain` at 26.92 and `scanObject` at 11.54 percent cumulative,
exist because Build allocates 2814 objects per op, 952.9 KiB, the
postings sets themselves. The profile verdict: Build is not slow
code, it is the data structure, an inverted index over 12000 word
insertions is map work, and the remaining lever would be allocation
shape, not algorithm.

#diagram([where build's cpu goes, one profile, four buckets], length: 13pt, {
  cdraw.line((0.3, 0.6), (23.3, 0.6), stroke: luma(100))
  let bar(x0, w, y, label) = {
    cdraw.rect((x0, y - 0.45), (x0 + w, y + 0.45), fill: luma(160), radius: 0.02)
    cdraw.content((x0 + w + 0.4, y), [#label], size: 6pt)
  }
  bar(0.3, 8.6, 6.4, [map assign, 39.90% cum])
  bar(0.3, 5.8, 5.2, [gc mark, 26.92% cum])
  bar(0.3, 3.1, 4.0, [map access, 14.42% cum])
  bar(0.3, 3.3, 2.8, [table grow + rehash, 15.38% cum])
  cdraw.content((11.8, 1.4), [samples: 2.08s over a 1.39s window, 149.39%], size: 6pt)
  cdraw.content((11.8, 0.3), [all from one committed profile, 2026-09-13], size: 6pt)
})

== what the capstone proves

The toolchain chapter's build tags and modules shape the two-module
layout, one for samples, one for the capstone. Lexical rules show up
in the tokenizer's string handling. The type system carries the
maps and structs, generics carries `Result[T]` with its method, and
1.27's inference lets the result helpers instantiate at call sites.
Functions contribute defer, closures over the walk state, and
method sets at the Fetcher boundary. Concurrency is the crawler
itself, semaphore, WaitGroup, closer goroutine, mutex, cancellation.
Errors wrap with `%w` and never panic. The runtime chapter pays off
in the leak profile test, which writes the 1.27 `goroutineleak`
profile after a crawl to prove the walker leaves nothing behind.
The stdlib tours supply `slices.Sorted`, `maps.Keys`, json v2, and
uuid. The framework chapters pay off in the ui: htmx 4 supplies the
fragment contract the routes answer, polling, response headers,
error fragments, and templ renders every fragment as a typed
component with its codegen committed. The store was the one step
past the tours when this capstone closed, `database/sql`
against modernc's pure Go sqlite and then the only capstone ground no
chapter covered, and the service part's store chapter has since taken
that ground further, an owned wal engine registered under the same
`database/sql` interface. Its six tests pin reopen survival, resave
replacement, and the fts5 phrase query. The testing chapter's
discipline is the suite itself, and the idioms chapter is the
shape: accept interfaces, return structs, zero values usable,
errors as values.

#diagram([every chapter pays off once, in place], length: 13pt, {
  let pair(x0, y, ch, payoff) = {
    cdraw.line((x0, y - 0.45), (x0 + 10.6, y - 0.45), stroke: luma(220))
    cdraw.content((x0 + 1.9, y), [#ch], size: 6pt)
    cdraw.content((x0 + 7.2, y), [#payoff], size: 6pt)
  }
  cdraw.content((2.2, 7.5), [chapter], size: 6.5pt)
  cdraw.content((7.5, 7.5), [payoff], size: 6.5pt)
  pair(0.3, 6.5, [toolchain], [two modules])
  pair(0.3, 5.5, [lexical], [tokenizer strings])
  pair(0.3, 4.5, [types], [maps and structs])
  pair(0.3, 3.5, [generics], [#"Result[T].Map"])
  pair(0.3, 2.5, [functions], [defer, closures])
  pair(0.3, 1.5, [concurrency], [the walker])
  cdraw.content((13.1, 7.5), [chapter], size: 6.5pt)
  cdraw.content((18.4, 7.5), [payoff], size: 6.5pt)
  pair(12.5, 6.5, [errors], [%w, no panic])
  pair(12.5, 5.5, [runtime], [leak profile test])
  pair(12.5, 4.5, [stdlib], [json v2, uuid, sorted])
  pair(12.5, 3.5, [testing], [the suite itself])
  pair(12.5, 2.5, [idioms], [the whole shape])
  pair(12.5, 1.5, [the store], [past the tours])
  pair(12.5, 0.5, [frameworks], [the ui: htmx, templ])
  cdraw.content((11.8, -1.1), [32 tests, zero skipped, no sleeps anywhere], size: 6pt)
})

== the service part

This capstone closed at 32 tests, and the book then grew a service part
around it, chapters 18 through 30, the user REST api built as a second
go module at `books/go/api`, twelve chapters from the kernel to the ship
chapter plus the suite. That part took the store, this chapter's one
step past the tours: modernc's pure Go sqlite left, replaced by a wal
engine owned bottom up and registered as the `database/sql` driver, and
the module's go.mod now holds zero community requires. `make verify-go`
runs the part beside this capstone, vet, the plain suite, and the race
leg over every module, and its recorded closeout is 182 tests, 6 fuzz
targets, 1 example, and 2 benchmarks, closed 2026-09-26.

sources: the capstone module in this repo, `go/capstone/`, tested
with `go test` from its own directory and through `make verify-go`,
32 tests on go1.27.0, benchmarked and profiled with the chapter 11
toolchain, captures committed beside the numbers
(`index/bench-old.txt`, `bench-new.txt`, `benchstat.txt`,
`pprof-flat.txt`, `pprof-cum.txt`), all measured 2026-09-13 on this
machine. The ui rides htmx 4.0.0 and templ v0.3.1020, pinned and
sourced in chapters 16 and 17.
