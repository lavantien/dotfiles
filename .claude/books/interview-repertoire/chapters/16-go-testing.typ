#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= go testing: mocks and dependency injection

"How do you test code that talks to a database" is answered by
architecture, not by a mocking library. The `ch16-go` module
builds the standard four layers, store, service, handler,
callback, each tested with the layer below it replaced by a fake,
and the whole stack exercised once against real sqlite. 8 tests
under `make verify`, engine 3.53 through the pinned driver.

== the four layers [TDD]

The store is sql and nothing else. The service holds the rules and
depends on two interfaces, the store and a notifier. The handler
decodes, calls, encodes, and depends on a narrow service
interface. The notifier is the callback layer, the email or queue
hook the service fires after a state change:

#listing("interview-repertoire/samples/ch16-go/store.go", first: 10, last: 55, caption: [the store interface is the seam, open asserts the pinned engine])

#listing("interview-repertoire/samples/ch16-go/service.go", first: 22, last: 58, caption: [validation, orchestration, domain errors, the callback fired on success only])

#diagram([four layers wired by constructor injection, no layer builds another], length: 13pt, {
  // handler over service over store, notifier beside the service that fires it
  let layer(x0, x1, y0, name, role) = {
    cdraw.rect((x0, y0), (x1, y0 + 1.7), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, y0 + 1.25), [#name], size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, y0 + 0.35), [#role], size: 6pt)
  }
  layer(3.5, 13.0, 9.0, "handler", "decode, call, encode")
  layer(3.5, 13.0, 5.8, "service", "rules, orchestration")
  layer(3.5, 13.0, 2.6, "store", "sql and nothing else")
  layer(17.0, 23.0, 5.8, "notifier", "email, queue")
  cdraw.line((8.75, 9.0), (8.75, 7.55), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.5, 8.25), [NewHandler(svc)], size: 6pt)
  cdraw.line((8.75, 5.8), (8.75, 4.35), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.4, 5.05), [NewService(store, notify)], size: 6pt)
  cdraw.line((13.0, 6.65), (17.0, 6.65), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.0, 7.1), [callback], size: 6pt)
  cdraw.content((11.5, 1.4), [no layer constructs the one below], size: 6pt)
  cdraw.content((11.5, 0.4), [function parameters are the container], size: 6pt)
})

The dependency injection is the constructors: `NewService(store,
notify)` takes interfaces, `NewHandler(svc)` takes another one,
and no layer constructs the layer below it. That is the entire di
pattern in go, and the honest answer to "do you need a di
framework" is no, function parameters are the container.

== mocks without a mocking framework [TDD]

The fakes file is the answer to "what do you mock": an in-memory
store with failure injection, a recording notifier, and a scripted
service:

#listing("interview-repertoire/samples/ch16-go/fakes.go", first: 8, last: 45, caption: [the mock store and its failure injection])

#diagram([three fakes behind the three interfaces the code already owns], length: 13pt, {
  // one column per boundary: interface label, dashed implements arrow, the fake and its internals
  let col(cx, iface, fake, l1, l2) = {
    cdraw.content((cx, 8.6), [#iface], size: 6.5pt)
    cdraw.line((cx, 8.3), (cx, 7.5), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
    cdraw.rect((cx - 3.4, 6.3), (cx + 3.4, 7.5), fill: luma(205), stroke: luma(120), radius: 0.02)
    cdraw.content((cx, 6.9), [#fake], size: 6pt)
    cdraw.content((cx, 5.4), [#l1], size: 6pt)
    cdraw.content((cx, 4.4), [#l2], size: 6pt)
  }
  col(3.8, "Store", "MockStore", "items in memory", "GetErr, WriteErr inject")
  col(11.7, "Notifier", "RecordingNotifier", "calls: item, from, to", "FailOn fails the nth")
  col(19.6, "ServiceAPI", "FakeService", "AddItemFn, RepriceFn,", "ListingFn: scripted")
  cdraw.content((11.6, 3.2), [mock the boundary you own an interface for], size: 6pt)
  cdraw.content((11.6, 2.2), [never the database driver], size: 6pt)
})

The rules the tests encode. Mock the boundary you own an
interface for, never the database driver. Assert interactions that
are part of the contract, the callback's from and to values, and
not incidental call counts. Inject failures, `GetErr` and
`WriteErr`, because the error paths are the ones production finds
and hand-rolled tests skip.

== what each layer's suite proves [TDD]

The store tests run against a real file in a temp dir, reopen it,
and demand the same rows back, because a store test against a fake
proves nothing about persistence. The service tests use the mock
store and prove validation, the missing-row translation to
`ErrNotFound`, and that a failing callback propagates instead of
vanishing. The handler tests script the service and prove routing,
encoding, and the error-to-status mapping, 400 for rules, 404 for
missing, no database anywhere:

#listing("interview-repertoire/samples/ch16-go/handler.go", first: 11, last: 46, caption: [one ServeHTTP, three routes, encoding at the edges])

#diagram([what each suite proves, and which fake stands in below], length: 13pt, {
  // four rows: layer, what its tests assert, what replaces the layer below
  let row(y, layer, a1, a2, below) = {
    cdraw.content((2.4, y), [#layer], size: 6.5pt)
    cdraw.content((9.5, y + 0.4), [#a1], size: 6pt)
    cdraw.content((9.5, y - 0.65), [#a2], size: 6pt)
    cdraw.content((18.9, y), [#below], size: 6pt)
  }
  cdraw.content((2.4, 9.0), [layer], size: 6pt)
  cdraw.content((9.5, 9.0), [its suite asserts], size: 6pt)
  cdraw.content((18.9, 9.0), [stands in below], size: 6pt)
  cdraw.line((0.8, 8.55), (22.8, 8.55), stroke: luma(120))
  row(7.4, "store", "reopen the file,", "the same rows back", "real sqlite, temp dir")
  row(5.3, "service", "rules, ErrNotFound,", "callback errors propagate", "MockStore")
  row(3.2, "handler", "routing, encoding,", "errors map to status", "FakeService")
  row(1.1, "full stack", "one price change", "over http, end to end", "no fakes at all")
})

The domain-error mapping is the piece worth narrating: the store
returns `sql.ErrNoRows`, the service translates it to `ErrNotFound`,
the handler maps that to 404, and `database/sql` never appears
above the service layer. Layer-locked imports are what make the
layers testable apart.

#callout("verify", "the full stack test", [
  The last test wires real sqlite, the service, the notifier, and
  the handler together and drives a price change over http. The
  notifier receives one event with the new total, which is the
  end-to-end claim the isolated suites cannot make alone.
])

== the golden master, ported small [EWC]

The behavioral chapter's migration card captures a legacy service's
outputs as golden masters, ports, and diffs, and this section is
that harness shrunk until one file holds it. A golden master is
committed bytes: the generator runs, its output is compared against
a file in `testdata`, and a change in either surfaces as the first
line that moved. The port renders a catalog report from a map and
gates it against `testdata/catalog.golden`, three tab-separated
lines in sorted sku order, hat-01, map-00, sword-01:

#listing("interview-repertoire/samples/ch16-go/golden_test.go", first: 13, last: 50, caption: [the update flag, the map fixture that forces the sort, the renderer])

The walk, line by line. The flag is a plain `flag.Bool` parsed by go
test itself, false in every normal run, true only when the suite is
invoked with `-update`. `goldenCatalog` returns a map on purpose,
because go randomizes map iteration order and a renderer that walked
the map as given would commit bytes that flake run to run. The sort
inside `renderCatalog` is what makes the bytes out a pure function
of the value in, rule one of the determinism drill below. The format
is deliberately boring, one line per item, sku, id, cents,
tab-separated, because a golden nobody can read is a golden nobody
trusts.

#listing("interview-repertoire/samples/ch16-go/golden_test.go", first: 52, last: 75, caption: [compare by default, rewrite through the flag, the drift named])

The test body is two branches. Under `-update` it makes `testdata`
and writes the bytes, and that is the only way the golden ever
changes, a golden edited by hand being a contract nobody signed. The
default branch reads the committed file, and the missing-file error
names the regeneration command, because a golden test that fails
with "no such file" and no remedy is a speed bump, not a gate. The
comparison is plain inequality on the whole string, bytes for bytes,
and the failure message is `firstDivergence`, never a dump:

#listing("interview-repertoire/samples/ch16-go/golden_test.go", first: 77, last: 98, caption: [the first differing line, want and got quoted, one short diff])

`firstDivergence` walks both texts line by line, stops at the first
pair that disagrees, and quotes both through `strconv.Quote` so tabs
and trailing spaces are visible. A wall of generated bytes helps
nobody, the first divergent line is the diagnosis.

#diagram([two branches: compare by default, rewrite through the flag], length: 13pt, {
  // the flag picks the branch, the committed file is the contract
  cdraw.content((11.5, 9.4), [renderCatalog, the map in], size: 6.5pt)
  cdraw.line((11.5, 9.1), (11.5, 8.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.6, 7.1), (14.4, 8.3), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((11.5, 7.7), [generated bytes], size: 6pt)
  cdraw.line((10.0, 7.1), (6.6, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.0, 6.9), [-update], size: 6pt)
  cdraw.line((13.0, 7.1), (16.4, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.2, 6.9), [default], size: 6pt)
  cdraw.rect((2.4, 4.6), (6.6, 6.0), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((4.5, 5.6), [rewrite], size: 6pt)
  cdraw.content((4.5, 4.9), [testdata], size: 6pt)
  cdraw.rect((16.4, 4.6), (21.0, 6.0), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((18.7, 5.6), [compare], size: 6pt)
  cdraw.content((18.7, 4.9), [bytes for bytes], size: 6pt)
  cdraw.line((18.7, 4.6), (18.7, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.4, 2.8), (21.0, 4.2), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((18.7, 3.5), [first divergence], size: 6pt)
  cdraw.content((11.5, 1.8), [the committed golden is the contract, never edited by hand], size: 6pt)
  cdraw.content((11.5, 0.9), [the cache keys on runtime reads too: -count=1 forces execution], size: 6pt)
})

#callout("verify", "the cache and why -count=1", [
  Go's test cache keys on the files a test reads: the runtime records
  every open and hashes it into the key, so a golden edited with no
  code change busts the cache and plain `go test` re-runs and fails.
  What a warm cache will still answer is a run whose binary and inputs
  are all unchanged, and a run about to trust a golden wants execution,
  not recall: `-count=1` makes the run prove the suite actually ran on
  the tree in front of it, warm cache or not.
])

This is the same shape the go book's offline engine gates its parity
artifact with, one flag, one compare, one divergence report, one
committed fixture two suites in two languages assert,
#xref-to("go", "enginetwin") for the full-size version.

== determinism discipline for cross-language twins [DRILL]

The spoken answer, when the follow-up is "a go engine and its
javascript twin, how do you know they agree": one committed fixture,
two suites, bit-identical output, and three rules that make the bits
line up. Sorted keys first: go randomizes map iteration order, so
every rendered artifact sorts its keys and the bytes out become a
pure function of the value in, the same sort the golden port above
leans on. Fixed term ordering second: a float sum depends on the
order of its terms, so both languages evaluate one written
expression tree, the same terms in the same order with the same
operations, the accumulation mirrored line for line rather than
formula for formula. One committed fixture third: the go side emits
the payload and golden-gates its bytes, the twin reads the same
committed file and asserts the same constants with plain `===`, and
parity is transitive, go equals the artifact, the artifact equals
what the twin reads.

Why bit-identical rather than close-enough: IEEE 754 arithmetic is
deterministic per operation, so identical operation sequences give
identical doubles, and an epsilon in the assertion can only widen
the blind spot, a tolerance passes two scores that differ, and a
differing bit means the operation trees diverged somewhere real.
Close-enough hides exactly the bug the twin exists to catch. The
keep-it-honest half is a hand-computed fixture riding beside the
generated one, every value a quarter or an eighth, so the expected
scores are doubles a pencil can verify in both languages. The
material is mined from dota-helper's emit and picker layers and
taught full size in #xref-to("go", "enginetwin").

#diagram([the three rules, one fixture, two suites, plain equality on both sides], length: 13pt, {
  // rules left, the committed fixture middle, the two suites right
  let rule(y, t) = {
    cdraw.rect((0.4, y), (7.8, y + 1.5), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((4.1, y + 0.75), [#t], size: 6.5pt)
  }
  rule(7.4, [sorted keys])
  rule(5.4, [fixed term order])
  rule(3.4, [one fixture, two suites])
  cdraw.rect((9.0, 4.4), (14.4, 8.4), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((11.7, 7.6), [the committed fixture], size: 6.5pt)
  cdraw.content((11.7, 6.5), [emitted bytes, gated], size: 6pt)
  cdraw.content((11.7, 5.5), [read as the truth], size: 6pt)
  cdraw.line((14.4, 7.0), (16.4, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.4, 5.9), (16.4, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.4, 7.0), (22.8, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((19.6, 8.0), [go test], size: 6.5pt)
  cdraw.content((19.6, 7.2), [exact constants], size: 6pt)
  cdraw.rect((16.4, 4.0), (22.8, 5.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((19.6, 5.0), [node --test], size: 6.5pt)
  cdraw.content((19.6, 4.2), [plain ===], size: 6pt)
  cdraw.content((11.5, 2.5), [bit-identical beats close-enough: a differing bit is a diverged operation tree], size: 6pt)
  cdraw.content((11.5, 1.6), [the traps: float sum order, locale, map iteration order], size: 6pt, fill: luma(100))
})

The traps to have ready. Float sum order: reordering the terms
changes the double, `(a + b) + c` and `a + (b + c)` can disagree in
the last bits, which is why the twin mirrors the tree, not the
formula. Locale: number formatting is pinned, never delegated to
whatever the runtime's formatter picks, the engine rounds its packed
cells at 4 decimals by printing and parsing back so both sides
rescore against the artifact's digits, and a locale that swaps
separators would fork the bytes silently. Map iteration order: the
trap the golden port above already carries, go hands map entries
over in a new order every run, and the sort is the whole defense.
All three traps share one shape, a value that depends on an order
nobody wrote down.

sources: verified by `go vet` and `go test` through `make verify`,
8 tests in `ch16-go` over sqlite 3.53 through modernc.org/sqlite
v1.58.0, the golden run passed `-count=1` so it executes rather than
recalls, and regenerated only through
`go test -update`. Deeper testing doctrine floors to
#xref-to("infrastructure", "testing") and its mocks chapter.
