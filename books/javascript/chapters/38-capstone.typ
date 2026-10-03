#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw, xref-to
#import "@preview/fletcher:0.5.8" as fletcher: node, edge

= capstone: the query engine, microfrontend

The book's claim, stated once in chapter 1 and repeated since, is
that javascript runs and typescript describes. The capstone is that
claim as one program: a document query engine split into a plain
layer under `capstone/core`, three `.mjs` files with no compiler
anywhere in their path, and a typed layer under `capstone/typed`
that adds the checker's guarantees on top without re-implementing
any behavior. The 4.0 edition adds a third face to the same engine,
`capstone/web`, a microfrontend: a hand written html shell, an
import map, and two independently built islands, react and svelte,
both running against one shared engine instance at runtime.
Sixty-three tests drive it red to green, 28 against the plain
layer, 14 against the typed one, and 21 against the web, and
`npm run verify` runs the plain suite first, the web builds and
suite second, the compiler last, so a regression in any face fails
the same gate.

#diagram([the two layers, who runs and who checks], length: 13pt, {
  cdraw.content((11.6, 9.6), [one engine, two layers], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 5.2), (22.8, 9.1), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 8.6), [layer two, checked], size: 6pt)
  cdraw.content((4.0, 7.6), [`query.ts`], size: 6pt)
  cdraw.content((11.6, 7.6), [`typed-store.ts`], size: 6pt)
  cdraw.content((19.0, 7.6), [`typed.test.ts`], size: 6pt)
  cdraw.content((4.0, 6.6), [mapped types], size: 6pt)
  cdraw.content((11.6, 6.6), [the facade], size: 6pt)
  cdraw.content((19.0, 6.6), [14 tests], size: 6pt)
  cdraw.content((11.6, 5.7), [typed through `store.d.mts`], size: 6pt)
  cdraw.line((11.6, 5.2), (11.6, 4.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.2, 4.75), [imports `../core/store.mjs`], size: 6pt)
  cdraw.rect((0.4, 0.5), (22.8, 4.1), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 3.6), [layer one, runs as written], size: 6pt)
  cdraw.content((4.0, 2.6), [`engine.mjs`], size: 6pt)
  cdraw.content((11.6, 2.6), [`store.mjs`], size: 6pt)
  cdraw.content((19.0, 2.6), [`persist.mjs`], size: 6pt)
  cdraw.content((4.0, 1.7), [brand and match], size: 6pt)
  cdraw.content((11.6, 1.7), [lazy chain], size: 6pt)
  cdraw.content((19.0, 1.7), [sqlite snapshots], size: 6pt)
  cdraw.content((11.6, 0.85), [28 tests, `node --test`, no compiler], size: 6pt)
})

== layer one: conditions without a compiler

A condition is a small object, a field, an operator, and a value.
In the plain layer the only way to make one is `build`, which
validates the shape it can check without a document, non-empty
string field, known operator, an array for `in`, a number for `gt`
and `lt`, then freezes the object with a symbol brand. `matches`
re-checks the brand first, then re-checks the field and the domain
against every document it sees:

#listing("javascript/capstone/core/engine.mjs", first: 7, last: 53, caption: [the builder and the evaluator, one brand between them])

#diagram([layer one, conditions without a compiler], length: 13pt, {
  cdraw.content((11.6, 11.4), [the builder and the brand], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 9.4), (5.6, 10.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 9.9), [the caller], size: 6pt)
  cdraw.line((5.6, 9.9), (6.4, 9.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.4, 9.4), (13.2, 10.4), fill: luma(205), radius: 0.02)
  cdraw.content((9.8, 9.9), [`build(field, op, value)`], size: 6pt)
  cdraw.line((13.2, 9.9), (14.0, 9.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.0, 9.4), (22.8, 10.4), fill: luma(235), radius: 0.02)
  cdraw.content((18.4, 9.9), [validates the shape it can check #linebreak() without a document], size: 6pt)
  cdraw.rect((0.4, 8.0), (22.8, 9.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 8.5), [non-empty string field, known operator, #linebreak() an array for `in`, a number for `gt` and `lt`], size: 6pt)
  cdraw.line((11.6, 8.0), (11.6, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((4.4, 6.0), (18.8, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 6.6), [then freezes the object with a symbol brand, #linebreak() and only `build` ever constructs one], size: 6pt)
  cdraw.line((11.6, 6.0), (11.6, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((4.4, 4.2), (18.8, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 4.8), [`matches(doc, cond)`, the two trust gates meeting], size: 6pt)
  cdraw.line((7.0, 4.2), (6.0, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 2.4), (11.2, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 3.0), [a hand written literal: `forged condition`, #linebreak() dead before any comparison], size: 6pt)
  cdraw.line((16.2, 4.2), (17.2, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.8, 2.4), (22.8, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 3.0), [an honest condition still dies on `unknown field` #linebreak() or `cannot apply` when a document disagrees], size: 6pt)
  cdraw.content((11.6, 1.3), [no type survives to runtime, so the runtime owns its own validity], size: 6.5pt)
  cdraw.content((11.6, 0.3), [the brand is the cheapest proof of provenance], size: 6.5pt)
})

Nothing else in the layer ever constructs a condition, so a
hand-written object literal with the same members is rejected with
`forged condition` before any comparison runs. This is chapter 11's
erasure rule turned into a design decision: since no type survives
to runtime anyway, the runtime owns its own validity, and the brand
is the cheapest proof of provenance. The two trust gates meet in
`matches`: an honest condition from the builder still dies on
`unknown field` or `cannot apply` when a document disagrees with it,
which is what the evaluator owes a store that accepts documents of
any shape.

The comparator at the bottom of the file is deliberately dull.
Numbers subtract, everything else compares through `String`, and
that single rule covers `Temporal.Instant`, whose string form is a
fixed width iso 8601 utc text that orders lexicographically the same
way it orders in time.

== the lazy chain

The store is a private array with one entry point. `query()` makes
one shallow copy and hands back a `Query` over it, and every stage
of a chain wraps the previous iterator without pulling from it.
Work starts when a terminal operation iterates, `toArray`, `count`,
or a `for..of`, and a fresh `Symbol.iterator` call replays the whole
chain, the protocol rule chapter 5 pinned when it built iterators
by hand:

#listing("javascript/capstone/core/store.mjs", first: 9, last: 55, caption: [the stage pattern, each helper wraps the previous iterator])

#listing("javascript/capstone/core/store.mjs", first: 57, last: 104, caption: [terminals, pagination, and the store itself])

#flow(
  [one pull through the chain],
  node((0, 0), [array snapshot]), edge(),
  node((1.7, 0), [`filter` re-checks]), edge(),
  node((3.4, 0), [`take`, `drop` bound]), edge(),
  node((5.1, 0), [`toArray` materializes]),
)

The stages are the iterator helpers chapter 5 introduced, and they
run on iterators, chapter 5's own rule, so `where` is `filter`, `select` is
`map`, and pagination composes `take` with `drop`. Two details earn
their comments. `sortBy` cannot stay pull based one item at a time,
so its stage drains the source on first pull, sorts the copy with
`toSorted`, and replays from it. And `limit` takes `count + offset`
before dropping `offset`, because `take(2).drop(1)` over a sorted
list would hand back one element when the page asked for two.
`dedupe` is chapter 5's `Map.getOrInsert` doing lazy interning: the
first document per field value is kept, later ones are dropped as
they arrive, and no set of distinct values is ever materialized.

The laziness is load bearing, not decorative. A chain over an
unbounded generator runs in bounded memory because `take` stops the
pull, and the test that proves it counts every yield:

#listing("javascript/capstone/core/store.test.mjs", first: 81, last: 96, caption: [an infinite source, three pulls, two results])

== snapshots that outlive the process

The document set saves to a real sqlite file through `node:sqlite`,
which node 26 ships built in, so the layer adds no dependency. The
section is short because the code carries three measured decisions.
First, `DatabaseSync` on node 26.3.0 implements `Symbol.dispose`,
probed on this machine, so `#open` uses a `using` declaration and
the handle closes at scope exit even on throw, and no method needs a
`close` call. Second, timestamps follow chapter 8's boundary rule,
`Temporal.Instant` in memory and iso text in the rows, `.toString()`
on the way in and `Temporal.Instant.from` on the way back. Third,
the checksum:

#listing("javascript/capstone/core/persist.mjs", first: 29, last: 59, caption: [the checksum payload and the one place a database opens])

#listing("javascript/capstone/core/persist.mjs", first: 61, last: 113, caption: [transactional save, checksum verified load])

#diagram([snapshots that outlive the process, the persistence decisions], length: 13pt, {
  cdraw.content((11.6, 11.4), [three measured decisions], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 9.6), (22.8, 10.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 10.1), [`DatabaseSync` implements `Symbol.dispose`, probed on node 26.3.0: #linebreak() a `using` declaration closes the handle at scope exit, even on throw], size: 6pt)
  cdraw.rect((0.4, 8.0), (22.8, 9.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 8.6), [the boundary rule: `Temporal.Instant` in memory, iso text in the rows, #linebreak() `.toString()` on the way in, `Temporal.Instant.from` on the way back], size: 6pt)
  cdraw.rect((0.4, 6.2), (22.8, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 6.8), [the checksum: each instant as exact `epochNanoseconds` digits through `JSON.rawJSON`, #linebreak() hashed as text with `toBase64`, stored in a `meta` table, `load` recomputes and compares], size: 6pt)
  cdraw.rect((0.4, 4.6), (22.8, 5.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 5.2), [never parsed back: `JSON.parse` of the same text returns the double, and two instants #linebreak() one nanosecond apart share `epochMilliseconds` yet produce different checksums], size: 6pt)
  cdraw.content((11.6, 3.4), [save is one transaction, delete then reinsert: a throw mid-transaction rolls back to the previous snapshot], size: 6.5pt)
  cdraw.content((11.6, 2.4), [a row edited behind the engine's back fails with `checksum mismatch`], size: 6.5pt)
})

The payload serializes each instant as its exact
`epochNanoseconds` digits through `JSON.rawJSON`. That is an emit
exact use and only that: `stringify` keeps every digit, but
`JSON.parse` of the same text returns the double, measured in the
suite, so the payload is hashed and compared as text and never
parsed back. The payoff is in the test: two instants one nanosecond
apart share `epochMilliseconds` yet produce different checksums,
because the digits differ. The hash itself is
`Uint8Array.prototype.toBase64` over the encoded payload, stored in
a `meta` table, and `load` recomputes and compares before returning,
so a row edited behind the engine's back fails with `checksum
mismatch`. Saving is one transaction, delete then reinsert, and a
throw mid-transaction rolls back to the previous snapshot, which the
rollback test exercises by deleting a document's instant.

The engine underneath is node's own build. `node:sqlite` embeds
its sqlite inside the node binary. The corpus pins 3.53.4 for the
c, go, and lua toolchains, and node 26.3.0 here reports exactly
3.53.1, which the suite asserts as an exact string, never a floor,
since in this one book the version is a property of the runtime.
Test files are created under the system temp directory through
`mkdtempSync`, never inside the repo, and cleaned in an `after`
hook. The snapshots stay on `node:sqlite` because a save is one
transaction that rolls back whole, and the engine choice it would be
weighed against is measured in
#xref-to("infrastructure", "duckdb-sqlite").

== layer two: the typed facade

The typed layer adds what the plain layer refuses to have: a
compile time account of which conditions make sense. The mapped type
is unchanged from the single-package capstone, because it was
already the whole policy:

#listing("javascript/capstone/typed/query.ts", caption: [conditions distributed over the document keys])

`OpsFor` admits `eq` and `in` for strings, adds `gt` and `lt` for
numbers, gives `has` to string arrays, and maps everything else to
`never`. That last branch now does visible work: `Book.added` is a
`Temporal.Instant`, so no condition can mention it. It stays
sortable through the comparator's string branch and unqueryable in
conditions, which is the honest outcome, since no operator in the
set applies to an instant. The proof that the
binding holds is mechanical, from a probe compiled outside the
suite:

#snippet(
  "store.query().where({ field: \"title\", op: \"gt\", value: 5 });\n"
  + "// error TS2345: Type '\"gt\"' is not assignable to\n"
  + "//                 type '\"eq\" | \"in\"'.\n",
  lang: "ts",
)

The same expression with `op: "eq"` and a string value, or with
`pages` and `gt`, compiles clean. Chapter 19 drew the declaration
boundary in miniature with a five line `store.d.mts` beside a
`store.mjs`. The capstone scales that exact shape up, one hand
written `core/store.d.mts` describing the whole plain layer, the
`.d.mts` spelling because nodenext maps an `.mjs` to a `.d.mts`:

#listing("javascript/capstone/core/store.d.mts", caption: [the checker's whole knowledge of the plain layer, hand written])

Nothing in the file emits and nothing in it runs. Conditions stay
opaque, `where` takes `unknown`, because the declaration's job is to
type the surface, and the brand has no type side worth faking. The
facade on top translates between the two accounts:

#listing("javascript/capstone/typed/typed-store.ts", first: 29, last: 73, caption: [the typed facade, delegation with a type attached])

#flow(
  [one condition, two gates],
  node((0, 0), [typed literal]), edge(),
  node((1.9, 0), [checker admits it]), edge(),
  node((3.8, 0), [facade rebuilds it]), edge(),
  node((5.7, 0), [brand at runtime]),
)

`BookQuery.where` does one thing the plain layer cannot: it takes a
`Condition<Book>` and rebuilds it through the core `build`, so every
typed condition crosses the brand boundary by construction and no
facade method ever trusts a caller's object. A cast over the
checker, the test does it on purpose, still dies at the `where()`
call with `unknown operator`, because the builder validates shape
before the chain stores anything. `select` carries the one honest
cast in the layer, justified because the field list came from
`keyof Book`, so `Pick<Book, K>` is the shape the plain `map` stage
really produces.

== the third face: one engine, two islands

The web layer asks the question the framework chapters set up: two
frameworks, one domain, no federation machinery. The answer is the
platform's own. A static shell carries one import map that binds the
bare specifier `domain` to exactly one module url, each island is
built separately by vite with `domain` marked external, and at
runtime both bundles resolve `domain` through the map to the same
module instance, so the react panel and the svelte panel read one
`Store`, seeded once, and their document counts cannot disagree:

#listing("javascript/capstone/web/shell/index.html", first: 21, last: 27, caption: [the import map, the whole architecture in four lines of json])

The machine checks are part of the suite, not prose: a test greps
both built bundles for the bare specifier import, another asserts
the map binds `domain` exactly once, and a third proves module
identity the honest way, the same url imports to the same
`library`, a cache busted second specifier makes a second instance,
which is precisely why the single binding matters.

#diagram([one shell, one map, two islands, one engine], length: 13pt, {
  cdraw.content((11.6, 9.6), [the shell, hand written, never built], size: 6.5pt, fill: luma(100))
  cdraw.content((5.0, 8.3), [import map: #linebreak() `"domain"` resolves to one url], size: 6pt)
  cdraw.content((18.2, 8.3), [boot module, #linebreak() imports both islands], size: 6pt)
  cdraw.rect((0.4, 4.9), (10.4, 7.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 6.9), [react island, ch 21], size: 6pt)
  cdraw.content((5.4, 5.7), [vite build, #linebreak() `domain` external], size: 6pt)
  cdraw.rect((13.2, 4.9), (22.8, 7.5), fill: luma(235), radius: 0.02)
  cdraw.content((18.0, 6.9), [svelte island, ch 22], size: 6pt)
  cdraw.content((18.0, 5.7), [vite build, #linebreak() `domain` external], size: 6pt)
  cdraw.rect((7.4, 1.2), (16.0, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.7, 3.4), [domain bundle, one instance], size: 6pt)
  cdraw.content((11.7, 2.2), [`engine.mjs` + `store.mjs` #linebreak() plus the seeded library], size: 6pt)
  cdraw.line((5.4, 4.9), (9.0, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.0, 4.9), (14.4, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 0.3), [both arrows are the map resolving one specifier to one url], size: 6pt)
})

== the domain and the two islands

The domain entry is a re-export plus a seed, and the one decision
worth teaching sits in its comment: the documents carry `added` as
iso text, not `Temporal.Instant`, because this module also runs in
browsers, chapter 8's boundary rule applied to a wire. The server
converts back to instants at the persist layer's edge, and the
comparator's string branch sorts the text correctly everywhere else:

#listing("javascript/capstone/web/domain/domain.ts", first: 8, last: 36, caption: [the domain bundle's whole source, re-exports, seed, singleton])

The islands are deliberately boring, each framework doing what its
chapter taught with the same shared documents. React mounts through
the chapter 21 wrapper, svelte through the compiler's
`svelte:options` custom element, and both keep `domain` external so
the map stays in charge:

#listing("javascript/capstone/web/react-island/island.tsx", first: 1, last: 15, caption: [the react island entry, injectable wrapper, external domain])

#listing("javascript/capstone/web/svelte-island/main.ts", first: 1, last: 9, caption: [the svelte island entry, one registration line, 9 lines in all])

Both islands also build an ssr barrel with `domain` aliased to its
source entry, because node has no import map, and the render smokes
assert both panels produce the same five titles out of their own
built output.

== the server, plain node:http

One file serves everything: the shell and the three built bundles
as static routes with mime types, and two apis over the same core
modules the islands import. Node 26's own type stripping runs the
domain's `.ts` source directly here, the erasable subset chapter 19
pinned, so the server and the browser read one seed from one file:

#listing("javascript/capstone/web/server.mjs", first: 20, last: 40, caption: [the static routes and the json seam])

#listing("javascript/capstone/web/server.mjs", first: 40, last: 75, caption: [the persist boundary, the search api through the builder, the snapshot round trip])

The search endpoint reaches the engine exactly the way chapter 21
reached react internals, through the public surface: it validates
the field, coerces the value, and calls `build`, so a bad operator
answers 400 with the builder's own `unknown operator` message
rather than a stack trace. The snapshot endpoint is chapter 8's
boundary rule end to end, iso text on the wire,
`Temporal.Instant.from` at the persist layer's edge, one
transactional save, and a checksum-verified load back out, through
the same `node:sqlite` the core suite pins at 3.53.1.

#flow(
  [one request through the server],
  node((0, 0), [request]),
  edge(),
  node((1.6, 0), [route]),
  edge(),
  node((3.2, 0), [static or api]),
  edge(),
  node((5.4, 0), [core modules, #linebreak() the same ones]),
  edge(),
  node((8.0, 0), [json out]),
)

== profiled, and why

#diagram([profiled, and why, the four paths at 200,000 documents], length: 13pt, {
  cdraw.content((3.0, 12.4), [path], size: 6.5pt, fill: luma(100))
  cdraw.content((10.5, 12.4), [measured, this machine], size: 6.5pt, fill: luma(100))
  cdraw.content((18.8, 12.4), [the why], size: 6.5pt, fill: luma(100))

  let row(y, p, m, w, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.5), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((3.0, y + 0.75), p, size: 6pt)
    cdraw.content((10.5, y + 0.75), m, size: 6pt)
    cdraw.content((18.8, y + 0.75), w, size: 6pt)
  }
  row(10.5, [parse], [0.04 us per condition], [validation and one frozen literal, #linebreak() cheap enough to ignore forever], false)
  row(8.9, [plan], [stages 0.008 us each, #linebreak() entry copy 0.3 to 0.4 ns per doc], [the plan is closures, the entry a snapshot, #linebreak() the price of replay safety], true)
  row(7.3, [scan], [29.4 ns per document #linebreak() per round], [69 of 93 samples in anonymous #linebreak() iterator closures, the collector through ch 9], false)
  row(5.7, [the reads], [limited queries: p50 0.059, #linebreak() p99 0.23, p99.9 0.46 ms], [corpus-shaped until `take` closes, #linebreak() the sqlite step the indexed alternative], true)

  for x in (6.4, 15.0) { cdraw.line((x, 5.7), (x, 12.0), stroke: luma(220)) }
  cdraw.rect((0.4, 4.1), (22.8, 5.1), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 4.6), [the loop tail mirrors one round of synchronous work: #linebreak() p50 5.706 ms, p99 7.143 ms over 7 samples], size: 6pt)
  cdraw.content((11.6, 3.0), [200,000 documents, 8 rounds in 47.04 ms, all measured 2026-09-13], size: 6.5pt)
  cdraw.content((11.6, 2.0), [best save of 5,000 documents 30.35 ms, best load 11.56 ms, against engine 3.53.1], size: 6.5pt)
})

The engine's own runtime, profiled by its own book: chapter 10's
tools turned on this engine, and the opt-in `capstone/bench/profile.mjs`
walks the four paths of a query at 200,000 documents, all measured
on this machine, 2026-09-13. Parse, building the condition, is
validation and one frozen literal: 200,000 `build` calls in 8.01 ms,
0.04 microseconds per condition, cheap enough to ignore forever.
Plan splits in two, and the split is the finding: staging is free,
2,000-entry runs measured the stages at 0.008 microseconds each
over 200,000 three-stage chains with nothing pulled, but entering
`query()` copies the document array, 0.3 to 0.4 nanoseconds per
document, about 70 microseconds for this corpus on every chain that
starts at the store. The plan is cheap because it is closures. The
entry is not, because it is a snapshot, and the snapshot is the
price of replay safety, the rule chapter 5 pinned.

#listing("javascript/capstone/bench/profile.mjs", first: 51, last: 83, caption: [the scan path profiled in-process, the histogram live between rounds])

Scan is where the time goes: 8 rounds over 200,000 documents in
47.04 ms, 29.4 nanoseconds per document per round, 39.63 to 47.04 ms
across three runs. The in-process profile of that loop at a 100
microsecond sampling interval: 20 nodes, top frames `(anon)` with 69
of 93 hits, `matches` 15, `(garbage collector)` 4, `query` 3,
`(program)` 2. The why reads through both new chapters. In a lazy
chain the named functions are a minority of samples because the
pull itself lives inside the iterator helpers' anonymous closures,
so the hottest code in this engine has no name a sampler can show,
and the profile is honest about that rather than renaming closures
for the tool's sake. Chapter 9's lens reads the collector frame:
four samples of garbage collection against 1.6 million condition
checks is the scavenger amortizing the iterator state each pull
creates and drops. And the event-loop histogram around the same
loop, enabled between rounds, reads p50 5.706 ms and p99 7.143 ms
over 7 samples, because the loop cannot yield inside a round: the
tail mirrors one round of synchronous work, chapter 10's rule that
delay is born where a long callback holds the thread.

The server-shaped read, 2,000 limited queries, lands at p50 0.059
ms, p99 0.23 ms, p99.9 0.46 ms. A limited query is still a full
scan until `take` closes the pull, so its latency is corpus-shaped
rather than page-shaped, and the honest fix at scale is a store
with an index, which is what the sqlite step is for: the best save
of 5,000 documents measured 30.35 ms and the best load 11.56 ms
against engine 3.53.1, persistence that costs about one scan of a
fortieth of the corpus.

#listing("javascript/capstone/core/profile.test.mjs", first: 14, last: 45, caption: [the in-suite smokes, a parsed child profile and an ordered histogram])

The suite carries two deterministic smokes from this section, a
child `--cpu-prof` run of the scan child parsed for the engine's own
frames, and the histogram's ordered positive percentiles, both under
half a second; the numbers above stay in the opt-in bench where a
measurement belongs.

== the suite and the gate

The counts moved from 18 tests in one package to 42 in two layers
and 63 with the web face: 7 in `engine.test.mjs`, 11 in
`store.test.mjs`, 8 in `persist.test.mjs`, 2 in `profile.test.mjs`,
28 plain, 14 in `typed.test.ts`, and 21 across five web suites, 8
driving the server over real http on an ephemeral port, 4 reading
the shell as a contract, 4 rendering both islands through their ssr
barrels, 3 on the wrapper's lifecycle contract, and 2 on the shared
instance itself. The typed
suite covers the same surface as the core suite plus the parts only
the facade has, the `Pick` projection that typechecks without a
cast, iteration through the facade's own `Symbol.iterator`, and the
two-layer trust story:

#listing("javascript/capstone/typed/typed.test.ts", first: 103, last: 127, caption: [the distribution proof and the forged condition])

#diagram([the suite and the gate, 63 tests in ten suites], length: 13pt, {
  cdraw.content((11.6, 11.2), [63 tests, ten suites], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 9.8), (11.2, 10.7), fill: luma(205), radius: 0.02)
  cdraw.content((5.8, 10.25), [the plain layer, 28], size: 6pt)
  cdraw.rect((0.4, 8.5), (11.2, 9.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 9.0), [7, `engine.test.mjs`], size: 6pt)
  cdraw.rect((0.4, 7.3), (11.2, 8.3), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 7.8), [11, `store.test.mjs`], size: 6pt)
  cdraw.rect((0.4, 6.1), (11.2, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.6), [8, `persist.test.mjs`], size: 6pt)
  cdraw.rect((0.4, 4.9), (11.2, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 5.4), [2, `profile.test.mjs`], size: 6pt)

  cdraw.rect((11.8, 9.8), (22.8, 10.7), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 10.25), [the typed suite, 14], size: 6pt)
  cdraw.rect((11.8, 8.5), (22.8, 9.5), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 9.0), [`typed.test.ts`, the facade's own surface], size: 6pt)
  cdraw.rect((11.8, 7.3), (22.8, 8.3), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 7.8), [the web face, 21 across five suites], size: 6pt)
  cdraw.rect((11.8, 6.1), (22.8, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 6.6), [8 server over real http, #linebreak() 4 shell as a contract], size: 6pt)
  cdraw.rect((11.8, 4.9), (22.8, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 5.4), [4 render both islands, 3 wrap, #linebreak() 2 shared instance], size: 6pt)

  cdraw.rect((0.4, 3.3), (7.2, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 3.85), [1. the plain suite], size: 6pt)
  cdraw.line((7.2, 3.85), (7.6, 3.85), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.6, 3.3), (15.0, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.3, 3.85), [2. the vite builds #linebreak() and the web suite], size: 6pt)
  cdraw.line((15.0, 3.85), (15.4, 3.85), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.4, 3.3), (22.8, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((19.1, 3.85), [3. the compiler, #linebreak() then the dist tests], size: 6pt)
  cdraw.content((11.6, 2.2), [`npm run verify`, one line: a regression in any face fails the same gate], size: 6.5pt)
})

The verify script is the whole gate in one line, plain suite first,
the five vite builds and the web suite second, the compiler last:

#snippet(
  "\"verify\": \"... rmSync dist and the web dists ...\"\n"
  + "  + \" && node --test \\\"core/**/*.test.mjs\\\"\"\n"
  + "  + \" && vite build -c web/domain/vite.config.ts\"\n"
  + "  + \" && ... four more vite builds ...\"\n"
  + "  + \" && node --test \\\"web/**/*.test.mjs\\\"\"\n"
  + "  + \" && tsc -p tsconfig.json\"\n"
  + "  + \" && node --test \\\"dist/**/*.test.js\\\"\"",
  lang: "json",
)

The glob form is not cosmetic. `node --test` on node 26 accepts
globs and fails on bare directory arguments, and the compiled tests
import `../core/store.mjs`, which resolves because `rootDir` is
`typed` and the compiled files land in `dist` beside the untouched
`core` directory, no copy step, no path rewriting. The suite passed
on three consecutive `npm run verify` runs as on the first, and the
project verifies through the repo's `make verify-ts` alongside the
samples.

#callout("note", "what the capstone exercises", [
  Chapter 5 carries the whole chain, the protocol, the helpers, and
  the replay rule, plus `Map.getOrInsert` for interning and
  `Uint8Array.prototype.toBase64` for the checksum, chapter 8
  carries the edition APIs the persistence leans on,
  `Temporal.Instant` at the string boundary and `JSON.rawJSON` for
  emit exact digits, and chapter 19 carries the declaration boundary
  the typed layer stands on. Chapter 16's narrowing runs the
  evaluator's switch, chapter 11's erasure explains why the brand
  exists at all, and the closed set of
  condition shapes is the same discipline
  #xref-to("csharp-net", "patterns") enforces with matching. The
  profiled section is chapters 9 and 10 turned inward, the collector
  frame in a real capture and the profiler tools the engine runs on
  itself. The web face is chapters 21 and 22 made structural, both
  islands over one seam, and chapter 7's module graph is what the
  import map resolves. One small program, most of the book.
])

== the service part

The service part built on the same book after this capstone is the
next evidence layer: the 6.0 wave's 13 chapters at 23 through 35
ride `books/javascript/api`, one package mounting twelve families
at slots 23 through 34 behind the kernel, and the wave 3b typed
vehicle mirrors the js spine into a typed source tree beside it.
The lane gates through `make verify-ts` in the repo chain. The
audit records the js spine at 317 of 317 green at the 6.0 closeout,
2026-09-27, the typed mirror at 319 ts tests beside the js 317, and
the docker lane 6 of 6 over the real image.

sources: nodejs.org node:test, node:sqlite, and iterator helpers
documentation, developer.mozilla.org Temporal, Map.getOrInsert,
Uint8Array toBase64, and JSON.rawJSON pages, and the typescriptlang
handbook mapped types page, accessed 2026-09-13, the whatwg import
maps specification for the web face, accessed 2026-09-21. Verified
live with tsc 7.0.2, vite 8.3.0, react 19.3.0, and svelte 5.57.1 on
node 26.3.0 on windows, 63 tests green through `npm run verify`,
28 plain, 21 web, and 14 typed, clean consecutive runs, plus one
compile probe confirming operator rejection at the
type level, one runtime probe confirming `DatabaseSync` implements
`Symbol.dispose`, and the profiling bench runs quoted in the
profiled section, measured 2026-09-13 on this machine.
