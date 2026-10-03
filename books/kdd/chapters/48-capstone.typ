#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to
#import "../manifest.typ": kddbook
#import "../coverage/topics.typ": topics
#import "../coverage/sources.typ": sources

// provenance: every behavioral claim below is one of the module's go
// test assertions, a line printed by the canonical seed-42 pipeline
// run (tools/run-kdd-capstone.ps1 leg 3, digest
// 34120a8fbe7ebaa21a885b898ae07357ba02dcf57003475ab5d4d4c21882f1fe,
// witnessed 2026-09-22), or a value from one of three disposable
// probes of 2026-09-22, all replaying seed 42: the gen probe (scatter
// subsample, responders 535 of 1224, hidden 54/41/1039), the store
// probe (global median age 43.246376 over the 41 masked), and the
// apriori probe (48 frequent singles, 3 frequent pairs, support 247).
// appendix counts recompute live from the coverage registries at
// compile time. no external page was fetched for this chapter.

= the capstone: a kdd pipeline on duckdb, with coverage appendices

== one module, two lanes

The dry run: the canonical run of the whole program prints fifteen
lines and exits zero, `seed=42` first and `digest=34120a...` last,
with 1224 customers, 9895 transactions, and 35340 basket items between
them. The same fifteen lines print again on the next run, and the
golden test fails if a single digit moves.

The capstone is one go module, `books/kdd/capstone`, module name
`kddcapstone`, with one external dependency: the duckdb go driver at
v2.10505.0, pinned in `go.mod`, driving the repo-built duckdb 1.5.5
dll the Makefile pins. Everything
else in the module is written by this book's waves. The module is the
production twin of the c spine: the four chapters the pipeline leans
on hardest, 4, 5, 18, and 31, live again in `internal/kddcore` as
pure go, and the pipeline
around them is the shape a real discovery project takes, a generator,
an embedded column store, miners, an evaluator, and a results panel.
The bridge from the c chapters is chapter #xref-to("kdd", "bridge");
the embedded-engine precedent is #xref-to("infrastructure", "duckdb"),
whose analytics store this chapter's store package follows on schema
stamping and the single-connection discipline.

#listing("kdd/capstone/go.mod", first: 1, last: 7, caption: [the whole external surface: one driver, one version])

The driver is cgo. A pure go lane and a duckdb lane share the same
sources through one build tag: every file that imports the driver, and
only those, sits behind `duckdb_use_lib`, and each package keeps an
untagged anchor so `go vet ./...` on the plain lane still compiles
every package, the chapter 11 pattern. The untagged lane runs vet,
test, and the race detector over pure go sources with no duckdb import
anywhere in it, which is also the gate that an untagged file can never
import the driver: an untagged import
would drag the driver's prebuilt static libraries into a plain build
and fail loudly.

#listing("kdd/capstone/internal/store/driver_use_lib.go", first: 1, last: 14, caption: [the tag seam in full: the tagged lane registers the driver, the pure lane refuses at the door])

#diagram([the module's layers, arrows are compile-time imports, the dashed seam is the one build tag], length: 13pt, {
  let box(x, y, w, label, fillv) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fillv, stroke: luma(120), radius: 0.12)
    cdraw.content((x + w / 2, y + 0.5), label, size: 7pt)
  }
  box(1.2, 8.4, 4.2, [web, htmx panel], luma(235))
  box(6.4, 8.4, 4.2, [cmd/pipeline], luma(235))
  box(1.2, 6.6, 9.4, [pipeline, seed to digest], luma(245))
  box(1.2, 4.8, 4.2, [mine, chi2 cart som apriori lof], luma(235))
  box(6.4, 4.8, 4.2, [eval, recovery and digest], luma(235))
  box(1.2, 3.0, 4.2, [kddcore, ch 4 5 18 31], luma(235))
  box(6.4, 3.0, 4.2, [store, sql views results], luma(245))
  box(1.2, 1.2, 9.4, [gen, seeded corpus and planted truth], luma(235))
  cdraw.line((5.9, 8.9), (6.4, 8.9), stroke: luma(120))
  cdraw.line((3.3, 8.4), (3.3, 7.6), stroke: luma(120), mark: (end: ">"))
  cdraw.line((8.5, 8.4), (8.5, 7.6), stroke: luma(120), mark: (end: ">"))
  cdraw.line((5.9, 7.1), (6.4, 5.8), stroke: luma(120))
  cdraw.line((3.3, 6.6), (3.3, 5.8), stroke: luma(120), mark: (end: ">"))
  cdraw.line((5.9, 5.3), (6.4, 5.3), stroke: luma(120))
  cdraw.line((3.3, 4.8), (3.3, 4.0), stroke: luma(120), mark: (end: ">"))
  cdraw.line((8.5, 4.8), (8.5, 4.0), stroke: luma(120), mark: (end: ">"))
  cdraw.line((5.9, 3.5), (6.4, 3.5), stroke: luma(120))
  cdraw.line((3.3, 3.0), (3.3, 2.2), stroke: luma(120), mark: (end: ">"))
  cdraw.line((8.5, 3.0), (8.5, 2.2), stroke: luma(120), mark: (end: ">"))
  cdraw.rect((6.2, 2.7), (11.0, 3.9), stroke: (dash: "dashed", thickness: 0.6pt, paint: luma(100)), fill: none, radius: 0.1)
  cdraw.content((8.6, 2.35), [the duckdb_use_lib seam], size: 6pt)
})

== the generator plants its own truth

The dry run: for seed 42 the generator emits 1224 customers in four
groups, 400 per planted segment and 24 outliers, and 43.7 percent of
customers respond. The masks it plants on the way out are 54 hidden
incomes, 41 hidden ages, and 1039 hidden sale prices, each remembered
in the truth block, so the cleaning stage is graded against what it
never saw.

Every number the pipeline later reports is a function of one int64.
The generator keeps a splitmix64 stream seeded from it, no math/rand,
no clock, no file system: the stream advances by the golden ratio
constant and every draw consumes it in a fixed order, clusters first,
then outliers, then missing masks, then baskets. The corpus is shaped
like retail: 8 categories of 6 products, customers carrying age,
income, a spending score, tenure in months, and visit counts,
transactions of 1 to 5 ordinary items each, plus both members of
one of three planted product pairs with 35 percent probability. The planted structure is the
point: three gaussian clusters far apart in the income-spend plane for
k-means and the som, a response rule `spend >= 55 and tenure >= 24`
with 4 percent label flips for the tree, boosted co-occurrences for
apriori, and a uniform sparse box of 24 customers for lof.

#listing("kdd/capstone/internal/gen/rng.go", first: 15, last: 26, caption: [the whole stochastic surface: one state, the splitmix64 step])

#listing("kdd/capstone/internal/gen/customers.go", first: 20, last: 41, caption: [one planted customer: three gaussian draws, one uniform tenure, the rule, the flip])

#diagram([the seed-42 corpus in the income-spend plane, every eighth inlier and all 24 outliers, crosses mark the planted centroids], length: 13pt, {
  let px(v) = 1.0 + (v - 10.0) * 0.115
  let py(v) = 0.8 + v * 0.058
  let seg0 = ((38.3,22.3),(38.7,26.4),(30.8,23.2),(36.3,22.9),(35.3,19.7),(29.3,32.7),(40.8,19.1),(25.0,26.2),(25.7,22.5),(26.6,28.0),(30.8,27.8),(28.9,29.4),(28.2,21.9),(26.8,33.7),(37.3,21.1),(42.4,17.9),(31.0,26.0),(38.6,16.0),(25.1,25.1),(32.0,36.2),(32.5,19.0),(24.1,33.3),(30.7,29.4),(29.0,19.6),(15.6,35.0),(22.9,18.4),(31.9,26.4),(23.2,23.8),(34.5,23.7),(38.1,26.5),(37.5,23.1),(19.3,19.5),(29.1,21.2),(31.5,21.3),(29.0,16.4),(30.3,18.4),(32.5,33.6),(24.3,19.3),(40.1,27.7),(29.3,22.0),(32.8,23.3),(28.5,30.3),(29.3,28.6),(29.8,19.0),(40.4,20.1),(27.1,24.6),(18.8,27.9),(20.1,19.9))
  let seg1 = ((58.3,46.1),(64.2,46.9),(58.8,46.0),(61.9,51.8),(63.3,60.3),(53.3,55.0),(69.6,47.6),(59.6,39.5),(58.8,53.7),(66.3,53.5),(64.8,55.5),(52.1,50.2),(57.1,51.4),(61.1,57.8),(67.6,55.8),(61.6,50.3),(52.0,44.7),(53.3,46.6),(62.2,58.8),(43.4,50.9),(60.5,47.0),(66.8,53.1),(57.0,51.5),(54.9,60.0),(66.4,43.0),(56.9,53.6),(57.2,50.4),(57.2,56.6),(59.2,53.1),(56.1,53.9),(62.3,49.3),(59.8,52.2),(61.1,54.3),(65.0,46.1),(62.5,56.4),(54.8,49.9),(61.4,60.4),(64.0,55.3),(63.5,55.5),(59.2,55.6),(60.7,54.0),(62.0,59.9),(49.0,53.8),(56.2,40.2),(56.9,47.9),(61.7,49.1),(65.0,50.2),(63.3,47.2))
  let seg2 = ((97.0,82.2),(109.9,74.1),(105.3,88.9),(100.5,79.1),(98.3,77.1),(108.4,81.2),(100.7,81.4),(105.4,78.8),(108.4,82.2),(113.0,83.3),(107.2,84.8),(108.2,83.7),(111.6,83.2),(89.3,78.1),(110.3,76.2),(101.5,93.5),(101.3,79.9),(98.1,74.6),(113.7,87.3),(114.5,76.1),(107.9,80.9),(104.7,87.1),(104.8,88.8),(104.9,79.4),(106.6,86.4),(100.5,72.6),(115.3,76.9),(100.9,83.0),(102.9,82.9),(101.1,83.2),(100.5,84.8),(110.7,86.1),(109.2,80.9),(92.1,87.1),(104.3,76.6),(101.8,81.9),(116.6,80.5),(98.5,82.7),(111.9,99.6),(99.2,87.3),(108.9,90.5),(104.0,93.1),(105.5,77.6),(105.2,83.4),(105.2,86.9),(104.9,83.0),(99.1,77.6),(97.1,73.7))
  let outliers = ((100.0,94.3),(82.0,82.5),(84.2,78.1),(159.5,32.4),(23.6,62.8),(16.4,111.9),(116.8,97.6),(141.4,106.4),(110.2,36.4),(50.2,13.4),(158.4,12.0),(68.4,117.5),(157.7,62.4),(58.0,92.6),(139.6,86.7),(144.2,68.9),(100.0,89.5),(124.9,48.3),(29.0,116.8),(130.8,79.3),(82.3,75.4),(30.6,49.3),(144.8,75.0),(131.9,35.1))
  for p in seg0 { cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.07, fill: luma(200), stroke: none) }
  for p in seg1 { cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.07, fill: luma(140), stroke: none) }
  for p in seg2 { cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.07, fill: luma(80), stroke: none) }
  for p in outliers { cdraw.circle((px(p.at(0)), py(p.at(1))), radius: 0.1, stroke: luma(60), fill: none) }
  for c in ((30.0, 25.0), (60.0, 52.0), (105.0, 82.0)) {
    cdraw.line((px(c.at(0)) - 0.22, py(c.at(1)) - 0.22), (px(c.at(0)) + 0.22, py(c.at(1)) + 0.22), stroke: 0.8pt + luma(30))
    cdraw.line((px(c.at(0)) - 0.22, py(c.at(1)) + 0.22), (px(c.at(0)) + 0.22, py(c.at(1)) - 0.22), stroke: 0.8pt + luma(30))
  }
  cdraw.line((1.0, 0.8), (19.6, 0.8), stroke: luma(100))
  cdraw.line((1.0, 0.8), (1.0, 9.8), stroke: luma(100))
  cdraw.content((px(100.0), 0.35), [income, thousands per year], size: 6pt)
  cdraw.content((0.3, py(60.0)), [spend], size: 6pt)
  cdraw.content((px(33.0), 8.3), [planted segments shaded, outliers hollow], size: 6pt)
})

== the store: load, clean, transform

The dry run: the store opens a fresh duckdb file, stamps schema
version 1, and answers `v1.5.5` to `SELECT version()`. The appender
loads all 46507 rows (four tables) without one sql string, and the
cleaning view fills every planted hole: 41 ages become 43.246376, the
global median, and all 1039 hidden sale prices come back within the
12.5 percent bound, which is why the run's metric block ends its
cleaning line at `price_within=1.000000`.

The store owns every duckdb touch. It opens one file behind one
connection with `threads=1`, the determinism choice: a single
aggregation order keeps the floating point sums a pure function of the
rows, which the digest discipline needs. Loading goes through the
driver's appender, one row per call, NaN masked values crossed to sql
NULL on the way in. A file stamped with a newer schema version is
refused rather than guessed at, the analytics precedent from
#xref-to("infrastructure", "duckdb"). The transform stage is three
views: `v_customers_clean` imputes age and income with the global
median, `v_items_clean` joins each masked price to its product's
median sale price, and `v_features` and `v_bins` min-max normalize and
equal-width bin the cleaned columns. The miners never mutate the
loaded corpus, they read views.

#listing("kdd/capstone/internal/store/load.go", first: 84, last: 94, caption: [the appender loop: one row per call, NaN to NULL at the boundary])

#listing("kdd/capstone/internal/store/views.go", first: 23, last: 30, caption: [the price imputation view: each masked row joins its product's median sale price])

#diagram([the data path, wide boxes are tables and views, the appender is the only writer], length: 13pt, {
  let box(x, y, w, label, fillv) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: fillv, stroke: luma(120), radius: 0.12)
    cdraw.content((x + w / 2, y + 0.45), label, size: 7pt)
  }
  box(0.6, 8.0, 3.0, [gen corpus], luma(235))
  box(5.0, 8.0, 3.2, [appender, tagged], luma(220))
  box(9.6, 8.0, 3.4, [4 raw tables], luma(235))
  box(9.6, 6.0, 3.4, [v_customers_clean], luma(245))
  box(5.0, 6.0, 3.2, [v_items_clean], luma(245))
  box(0.6, 6.0, 3.0, [v_features], luma(245))
  box(0.6, 4.0, 3.0, [v_bins], luma(245))
  box(5.0, 4.0, 3.2, [miners, pure go], luma(235))
  box(9.6, 4.0, 3.4, [results tables], luma(235))
  box(5.0, 2.0, 3.2, [panel queries], luma(235))
  cdraw.line((3.6, 8.45), (5.0, 8.45), stroke: luma(120), mark: (end: ">"))
  cdraw.line((8.2, 8.45), (9.6, 8.45), stroke: luma(120), mark: (end: ">"))
  cdraw.line((11.3, 8.0), (11.3, 6.9), stroke: luma(120), mark: (end: ">"))
  cdraw.line((9.6, 7.6), (8.2, 6.6), stroke: luma(120), mark: (end: ">"))
  cdraw.line((9.6, 7.2), (2.1, 6.9), stroke: luma(140))
  cdraw.line((2.1, 6.0), (2.1, 4.9), stroke: luma(120), mark: (end: ">"))
  cdraw.line((3.6, 4.45), (5.0, 4.45), stroke: luma(120), mark: (end: ">"))
  cdraw.line((2.1, 4.0), (5.0, 3.6), stroke: luma(140))
  cdraw.line((8.2, 4.45), (9.6, 4.45), stroke: luma(120), mark: (end: ">"))
  cdraw.line((11.3, 4.0), (7.0, 2.9), stroke: luma(120), mark: (end: ">"))
  cdraw.content((7.0, 1.2), [the only writer is the load, the only reader path is views and result tables], size: 6pt)
})

== selection, mining, and the planted-truth evaluation

The dry run: chi-square ranks `chi2_top=spend>income`, lof flags 17 of
the 24 planted outliers exactly, k-means over the surviving 1200
inliers reaches `cluster_purity=0.984167`, the som folds the same
plane at `quant_err=0.054221`, the tree scores `tree_accuracy=0.946721`
and `tree_auc=0.958421` on the every-fifth-row holdout, and apriori at
support 247 (2.5 percent of 9895 baskets) finds exactly 48 frequent
singles and 3 frequent pairs, the three planted ones, so
`rule_recovery=1.000000`.

The mining layer runs the book's techniques over the store's views,
and every engine is the chapter's own mathematics: chi-square
selection over the four-bin contingency tables, the `kddcore` lloyd
engine for segmentation with the som organizing the same plane on a
2x3 lattice, a depth-4 gini cart over the five normalized features
with the causal pair first in the column order, levelwise apriori over
the basket sets with rules from the maximal frequent itemsets, and lof
with ten neighbors over the normalized income-spend plane. The
anomaly stage feeds the segmentation: clustering runs on the
lof-filtered inliers, which is why the purity line grades 1200 rows,
not 1224. The evaluation reads the generator's truth block, not
re-derived expectations: majority-cluster purity against the planted
segments, top-24 recall against the planted outlier ids, and rule
recovery against the planted pairs, each direction accepted, lift
above one required.

#listing("kdd/capstone/internal/pipeline/pipeline.go", first: 96, last: 120, caption: [the anomaly-to-segmentation handoff: lof flags, the inliers cluster, purity grades against the planted segments])

#listing("kdd/capstone/internal/pipeline/pipeline.go", first: 143, last: 156, caption: [the support threshold and its margin: planted pairs near 12 percent, incidental triples under 2])

#diagram([the six recovery numbers of the canonical run, bar length is the value, one is perfect], length: 13pt, {
  let rows = (
    ("cluster purity", 0.984167, "0.984167"), ("outlier recall", 0.708333, "0.708333"),
    ("rule recovery", 1.0, "1.000000"), ("price within 12.5 pct", 1.0, "1.000000"),
    ("tree accuracy", 0.946721, "0.946721"), ("tree auc", 0.958421, "0.958421"),
  )
  let y = 8.2
  for row in rows {
    let w = row.at(1) * 9.4
    cdraw.rect((5.0, y - 0.28), (5.0 + w, y + 0.28), fill: luma(205), radius: 0.0)
    cdraw.content((2.3, y), [#row.at(0)], size: 6pt)
    cdraw.content((5.0 + w + 0.5, y), [#row.at(2)], size: 6pt)
    y -= 1.15
  }
  cdraw.line((5.0, 8.9), (5.0, 0.7), stroke: luma(100))
  for v in (0.0, 0.5, 1.0) {
    cdraw.line((5.0 + v * 9.4, 0.7), (5.0 + v * 9.4, 0.82), stroke: luma(100))
    cdraw.content((5.0 + v * 9.4, 0.25), [#v], size: 6pt)
  }
})

== the results panel

The dry run: after the run persists its results, the panel reads back
three segment rows, six rule rows (the six directions of the three
planted pairs), twelve anomaly ranks, and the roc corners, and renders
one html document that carries the vendored htmx under its
subresource integrity digest `sha384-BvJpBiO8...`.

The web tier is an html/template site with htmx refreshing five
fragments, the segment table, the som grid, the rule table, the
anomaly ranking, and the roc curve drawn as an inline svg polyline.
The index server-renders every fragment, so the page reads without
scripting and htmx only freshens it. The script is vendored
byte-identical from the infrastructure capstone's copy, pinned by an
sri constant the test re-derives from the embedded bytes, and the
whole tier is smoke tested through httptest inside `go test`, no
browser, no server left running, the same recipe as
#xref-to("infrastructure", "capstone2").

#listing("kdd/capstone/internal/web/page.go", first: 15, last: 18, caption: [the sri pin: the vendored script never changes under this digest])
#listing("kdd/capstone/internal/web/page.go", first: 93, last: 99, caption: [the template carries the digest into the served document])

#diagram([the panel's routes: the index server-renders the fragments, htmx polls them every ten seconds], length: 13pt, {
  let box(x, y, w, label, fillv) = {
    cdraw.rect((x, y), (x + w, y + 0.85), fill: fillv, stroke: luma(120), radius: 0.12)
    cdraw.content((x + w / 2, y + 0.42), label, size: 7pt)
  }
  box(4.2, 7.6, 4.0, [GET /, the index], luma(235))
  box(0.6, 5.4, 2.9, [/fragment/segments], luma(245))
  box(3.9, 5.4, 2.9, [/fragment/som], luma(245))
  box(7.2, 5.4, 2.9, [/fragment/rules], luma(245))
  box(10.5, 5.4, 2.9, [/fragment/anomalies], luma(245))
  box(3.9, 3.6, 2.9, [/fragment/roc], luma(245))
  box(7.2, 3.6, 2.9, [/static/htmx.min.js], luma(220))
  box(0.6, 3.6, 2.9, [/healthz], luma(245))
  cdraw.line((5.0, 7.6), (2.0, 6.25), stroke: luma(120), mark: (end: ">"))
  cdraw.line((5.6, 7.6), (5.35, 6.25), stroke: luma(120), mark: (end: ">"))
  cdraw.line((6.8, 7.6), (8.6, 6.25), stroke: luma(120), mark: (end: ">"))
  cdraw.line((7.6, 7.6), (11.9, 6.25), stroke: luma(120), mark: (end: ">"))
  cdraw.line((5.35, 5.4), (5.35, 4.45), stroke: luma(120), mark: (end: ">"))
  cdraw.line((6.8, 7.2), (8.6, 4.45), stroke: luma(140))
  cdraw.content((6.6, 2.4), [every fragment is also a duckdb query away: the panel reads the persisted tables], size: 6pt)
})

== verification: the golden digest

The dry run: the golden test runs the whole pipeline twice on fresh
temp files for seed 42, both runs print
`digest=34120a8fbe7ebaa21a885b898ae07357ba02dcf57003475ab5d4d4c21882f1fe`,
and the pinned constant must match or the test dies with the whole
metric block in the failure message.

The digest is the sha256 of fourteen canonical lines: the seed, the
three corpus counts, the chi-square top two, seven quality floats at
six decimals (six recovery numbers and the som's quantization error),
and the two imputation errors. Nothing about the format is
free: counts print as integers, floats at fixed precision, so a
behavioral drift anywhere in the chain, generator draw order, duckdb
view arithmetic, engine tie rules, evaluation, or formatting, moves
the digest and the test names the drifted lines. The floors under the
pin keep the recovery honest rather than merely stable: accuracy at
0.85, auc at 0.90, purity at 0.90, outlier recall at 0.70, rule and
price recovery at 0.99, and the som's quantization error under 0.25.
Re-witnessing is a discipline, not an edit: when a fixture or
algorithm legitimately changes, the run prints the new digest, the
constant is re-pinned, and the runner's pin moves in the same commit.

#listing("kdd/capstone/internal/pipeline/golden_test.go", first: 21, last: 32, caption: [the pin: same run, same fourteen lines, same sha256, or the failure carries the drift])

The gate chain lives in `tools/run-kdd-capstone.ps1`, red on any
failure with one loud scaffold skip before the module exists. Leg 1
runs the pure go lane, vet, test, and race, no c compiler in the
loop. Leg 2 repeats vet and test behind `duckdb_use_lib` with zig as
the c compiler against the pinned duckdb.dll, the documented windows
recipe. Leg 3 builds the actual binary both ways: the tagged build
must print the pinned digest and render the panel html, and the pure
build must refuse with exit 1 naming the missing tag. The counts this
chapter owns: 48 tests on the pure lane, 56 on the tagged lane, 58
distinct, zero skipped, run green on 2026-09-22.

#diagram([the three gate legs of tools/run-kdd-capstone.ps1, each red on failure, the digest pin stands at the end], length: 13pt, {
  let box(x, y, w, h, label, fillv) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fillv, stroke: luma(120), radius: 0.12)
    cdraw.content((x + w / 2, y + h / 2), label, size: 7pt)
  }
  box(0.6, 5.4, 3.6, 2.4, [leg 1, pure go: vet, test, race], luma(235))
  box(4.8, 5.4, 3.6, 2.4, [leg 2, tagged: zig cc, duckdb.dll], luma(230))
  box(9.0, 5.4, 4.4, 2.4, [leg 3, binary e2e: digest and panel], luma(225))
  box(3.0, 1.6, 8.0, 1.6, [the pinned digest, 34120a8f..., matched by leg 3 and by the golden test], luma(245))
  cdraw.line((4.2, 6.6), (4.8, 6.6), stroke: luma(120), mark: (end: ">"))
  cdraw.line((8.4, 6.6), (9.0, 6.6), stroke: luma(120), mark: (end: ">"))
  cdraw.line((11.2, 5.4), (8.0, 3.2), stroke: luma(120), mark: (end: ">"))
  cdraw.line((7.0, 3.2), (6.0, 2.4), stroke: luma(140))
  cdraw.content((7.0, 0.9), [the pure binary refuses, exit 1, naming the tag], size: 6pt)
})

== topic coverage

#let ids = kddbook.chapters.map(c => c.id)
#let topic-count(id) = topics.filter(r => r.chapter == id).len()
#let off-manifest = topics.filter(r => not ids.contains(r.chapter)).len()
#let bare = kddbook.chapters.filter(c => topic-count(c.id) == 0).map(c => c.id).join(", ")

The registries close the book. Every chapter wrote its topic rows into
the coverage matrix as it landed, each row naming the sample CHECK
that proves the claim, and this section reads the registry back the
only way that keeps it honest, by computing from it. The chapter ledger
below recomputes at compile time: #topics.len() topic rows over
#kddbook.chapters.len() chapters, #off-manifest rows off the manifest
out of #topics.len(), and the chapters still carrying no rows of their
own are #bare. A row added or retitled tomorrow shows up here without
editing this chapter, the same contract the math book's appendices
keep.

#table(
  columns: (auto, 3.2fr, auto),
  inset: 4pt,
  table.header([*ch*], [*chapter*], [*topics*]),
  ..kddbook.chapters.map(c => (
    [#c.num], [#c.title], [#topic-count(c.id)],
  )).flatten(),
  table.cell(colspan: 2, fill: luma(245))[*total over #kddbook.chapters.len() chapters*],
  table.cell(fill: luma(245))[*#topics.len()*],
)

#let counts = kddbook.chapters.map(c => topic-count(c.id))
#let max-rows = calc.max(..counts)
#let peak-n = kddbook.chapters.filter(c => topic-count(c.id) == max-rows).len()

#diagram([topic rows per chapter, computed from the registry at compile time, the capstone pair closes the book], length: 13pt, {
  let x = i => 0.9 + i * 0.42
  for (i, c) in kddbook.chapters.enumerate() {
    let n = topic-count(c.id)
    if n > 0 {
      cdraw.rect((x(i), 0.9), (x(i) + 0.3, 0.9 + n * 0.28), fill: luma(170), radius: 0.0)
    } else {
      cdraw.rect((x(i), 0.9), (x(i) + 0.3, 1.02), fill: luma(230), stroke: luma(180), radius: 0.0)
    }
  }
  cdraw.line((0.7, 0.9), (20.8, 0.9), stroke: luma(120))
  for n in (1, 10, 20, 30, 40) {
    cdraw.content((x(n - 1) + 0.15, 0.4), [#n], size: 6pt)
  }
  cdraw.content((10.5, 0.9 + max-rows * 0.28 + 0.7), [#topics.len() rows live, #off-manifest off-manifest, the tallest bar reaches #max-rows rows on #peak-n chapters], size: 6pt)
})

== pinned sources

#let src-class(u) = {
  if u.starts-with("https://") { "web" }
  else if u.starts-with("books/") or u.starts-with("playground/") or u.starts-with("tools/") { "corpus internal" }
  else { "papers by name" }
}
#let class-order = ("web", "papers by name", "corpus internal")
#let class-count(cl) = sources.filter(s => src-class(s.url) == cl).len()

Every external claim in the book carries a dated url or a named paper,
#sources.len() rows so far, and the classifier reads only url
prefixes, so the class counts are mechanical:

#table(
  columns: (1.6fr, auto, 2.6fr),
  inset: 4pt,
  table.header([*class*], [*rows*], [*rule*]),
  ..class-order.map(cl => (
    [#cl],
    [#class-count(cl)],
    if cl == "web" { [url starts `https://`] }
    else if cl == "corpus internal" { [url starts `books/`, `playground/`, or `tools/`] }
    else { [named papers and books, everything else] },
  )).flatten(),
)

#diagram([the source base by class, computed from the registry, bar length is row count], length: 13pt, {
  let y = 3.4
  for cl in class-order {
    let n = class-count(cl)
    cdraw.rect((4.8, y - 0.26), (4.8 + n * 0.35, y + 0.26), fill: luma(205), radius: 0.0)
    cdraw.content((2.4, y), [#cl], size: 6pt)
    cdraw.content((5.2 + n * 0.35, y), [#n], size: 6pt)
    y -= 1.0
  }
  cdraw.line((4.8, 4.0), (4.8, 1.8), stroke: luma(100))
  cdraw.content((7.5, 1.2), [#sources.len() pinned rows, every one dated], size: 6pt)
})

The full index:

#[
#set text(size: 7.5pt)
#table(
  columns: (1.7fr, 2.9fr, auto),
  inset: 3pt,
  table.header([*topic*], [*url or citation*], [*accessed*]),
  ..sources.map(s => ([#s.topic], [#s.url], [#s.accessed])).flatten(),
)
]

#callout("verify", "this chapter's own receipts", [
  The digest, the metric block, and the leg-3 behavior were printed by
  `tools/run-kdd-capstone.ps1` on 2026-09-22, and the 58 distinct go
  tests ran green the same day, 48 on the pure lane and 56 on the
  tagged lane. The scatter and the planted hidden counts come from a
  disposable gen probe replaying seed 42, and every appendix count
  recomputes from the registries at compile time.
])

sources: no external pages fetched for this chapter, none cited. The
driver and engine versions are read from the module's own `go.mod` and
the store's engine-version test, the htmx digest from the vendored
bytes, and the appendix counts from books/kdd/coverage/topics.typ,
#topics.len() rows, and books/kdd/coverage/sources.typ, #sources.len()
rows, at compile time.
