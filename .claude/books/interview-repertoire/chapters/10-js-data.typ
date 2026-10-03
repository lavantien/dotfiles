#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= data plumbing: csv to mongodb

The migration question is really three questions: parse the source
honestly, shape the rows into documents worth storing, and insert
in batches a real server will accept. The `ch10-js` workspace runs
the first two thirds under `npm run verify` against a recording
fake, 10 tests, and the last third is a mongosh script gated
behind a real server from #xref-to("infrastructure", "mongo"),
whose compose capstone starts one.

== parsing csv without lying about it [TDD]

Csv is a format with quoting rules, and the tests exercise them:
commas inside quotes, newlines inside quotes, doubled quotes as
escapes, CRLF tolerated, no trailing newline required:

#listing("interview-repertoire/samples/ch10-js/src/csv.mjs", first: 5, last: 55, caption: [the one-pass parser: quote state, delimiter, and the trailing row])

#diagram([the quote state machine: doubles escape, the trailing row still emits], length: 13pt, {
  // two states, the self-loop facts under each
  cdraw.rect((2.5, 4.6), (6.5, 5.8), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((4.5, 5.2), [in a field], size: 6pt)
  cdraw.rect((13.5, 4.6), (17.5, 5.8), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((15.5, 5.2), [in quotes], size: 6pt)
  cdraw.line((6.5, 5.6), (13.5, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.0, 6.1), [an opening quote], size: 6pt)
  cdraw.line((13.5, 4.8), (6.5, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.0, 4.3), [a closing quote], size: 6pt)
  cdraw.content((4.5, 3.15), [comma: next field], size: 6pt)
  cdraw.content((4.5, 2.05), [newline: next row, crlf ok], size: 6pt)
  cdraw.content((4.5, 0.95), [eof: emit the trailing row], size: 6pt)
  cdraw.content((19.6, 3.15), [a doubled quote is], size: 6pt)
  cdraw.content((19.6, 2.05), [one literal quote,], size: 6pt)
  cdraw.content((19.6, 0.95), [commas and newlines stay], size: 6pt)
})

The bug class this parser exists to avoid is the `split(",")`
opening gambit, which dies on the first quoted comma. The fixture
file under `csv/fixtures/products.csv` carries quoted tags so the
parse is never tested on toy rows alone.

== documents, batches, and the one-method interface [TDD]

The migration core codes against a collection interface with a
single method, `insertMany`, because that is exactly what the
mongodb driver exposes, which is why the same code runs against
the fake and against a real server:

#listing("interview-repertoire/samples/ch10-js/src/migrate.mjs", first: 5, last: 46, caption: [type coercion, the money reshape, stamped imports, batched inserts])

Three decisions worth narrating in the room. Csv values are all
strings, so coercion happens once at the boundary, with a schema
override for columns like a leading-zero sku. Money lands as an
integer cents field reshaped into a nested `{cents, currency}`
document, the same no-floats rule as
#xref-to("repertoire", "db-answers"). And every document carries an
import stamp, because a migration without provenance is a table
nobody trusts.

The fake records batches, assigns `_id` exactly the way the driver
does, and can fail on a chosen batch number:

#listing("interview-repertoire/samples/ch10-js/src/fake.mjs", first: 5, last: 24, caption: [the recording fake with failure injection])

#diagram([csv rows to reshaped documents to batched calls, one interface for the fake and the real driver], length: 13pt, {
  let stage(x, t, sub) = {
    cdraw.rect((x, 2.0), (x + 4.4, 3.9), fill: luma(235), stroke: luma(120), radius: 0.05)
    cdraw.content((x + 2.2, 3.3), [#t], size: 6.5pt)
    cdraw.content((x + 2.2, 2.5), [#sub], size: 6pt)
  }
  stage(0.5, "csv rows", "quotes, crlf")
  stage(6.2, "parse", "quote state")
  stage(11.9, "reshape", "cents, stamp")
  stage(17.6, "insertMany", "batched calls")
  cdraw.line((4.95, 2.95), (6.15, 2.95), mark: (end: ">"))
  cdraw.line((10.65, 2.95), (11.85, 2.95), mark: (end: ">"))
  cdraw.line((16.35, 2.95), (17.55, 2.95), mark: (end: ">"))
  // coercion happens once at the boundary, every document leaves stamped
  cdraw.content((14.1, 4.6), [strings leave, cents and an import stamp enter], size: 6pt)
  cdraw.content((11.2, 0.6), [one insertMany interface: the fake in verify, the driver against the compose stack], size: 6.5pt)
})

The failure test asserts the honest middle state: batch 1 landed,
batch 2 raised, and nothing was swallowed. A migration that hides
a failed batch has converted a data problem into a data mystery.

== the real run, docker gated [DRILL]

The real import is a mongosh script, listed from the workspace,
that mirrors the parser and coercer inline because mongosh runs
one standalone script rather than the package's ESM modules:

#listing("interview-repertoire/samples/ch10-js/real/import.mjs", first: 6, last: 20, caption: [the gated script: same fixture, same batches, counts printed at the end])

#diagram([the same migration inlined for mongosh, totals compared with the offline suite], length: 13pt, {
  // the gated path, one stage per command
  let stage(x, t, sub) = {
    cdraw.rect((x, 2.6), (x + 5.5, 4.5), fill: luma(235), stroke: luma(120), radius: 0.05)
    cdraw.content((x + 2.75, 3.9), [#t], size: 6.5pt)
    cdraw.content((x + 2.75, 3.15), [#sub], size: 6pt)
  }
  stage(0.2, "import.mjs", "parser inlined")
  stage(6.25, "mongosh", "--file")
  stage(12.3, "compose stack", "port 27017")
  stage(18.35, "the totals", "vs the suite")
  cdraw.line((5.75, 3.55), (6.2, 3.55), mark: (end: ">"))
  cdraw.line((11.8, 3.55), (12.25, 3.55), mark: (end: ">"))
  cdraw.line((17.85, 3.55), (18.3, 3.55), mark: (end: ">"))
  cdraw.content((12.0, 1.5), [outside npm run verify on purpose: the gate stays offline], size: 6.5pt)
})

Run it against the compose stack of book 11: `docker compose up
-d`, then `mongosh mongodb://localhost:27017 shop --file
real/import.mjs`, and compare the printed totals with the suite's.
It is deliberately outside `npm run verify`: the gate stays
offline and deterministic, and the network path is a separate,
named step, the same split book 11 uses for its docker-gated
suites.

sources: batch insert and driver behavior from the mongodb manual,
pinned in #xref-to("infrastructure", "mongo") and its sources.
Verified by `npm run verify` under node 26.3.0, 10 tests in
`ch10-js`.
