#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= capstone: ingest and analysis pipeline, part 2

Part 1, #xref-to("python", "capstone1"), ended with a list of validated
`Reading` objects and a sorted list of dead letters. This chapter turns
records into numbers, numbers into one canonical document, the document
into a cli, and the cli's payload into a served api. The modules are
`analytics.py`, `cpu.py`, `report.py`, `cli.py`, and `api.py`, and
their share of the suite is 30 of the 78 tests: `test_analytics` 8,
`test_cpu` 3, `test_golden` 5, `test_api` 10, `test_versions` 4. The
through-line is the one part 1 set up: every artifact downstream is
byte-stable, typed, and pinned, so the golden file, the response
models, and the version table can all be checked by machine.

== analytics and the pool

Aggregation is one function with a typed return:

#listing("python/capstone/analytics.py", first: 23, last: 49, caption: [summarize: pandas groupby feeding numpy callables, results cast back to plain python numbers])

Records are materialized once through `model_dump`, so lists and
generators are equally welcome, and the frame goes through the
`groupby`/`agg` core that #xref-to("python", "pandas") taught. The
aggregators are explicit numpy callables, `numpy.mean`, `numpy.min`,
`numpy.max`, `numpy.median`, the numeric engine of
#xref-to("python", "numpy") named rather than implied. Two details are
contract rather than style. The stats are cast with `int()` and
`float()` on the way out, because a numpy scalar that survived into the
json report would poison it, and a test asserts every mean and median
is a plain `float`. And the sensors mapping is sorted after the
`groupby`, which sorts already, so the report order is pinned by the
code itself instead of by pandas' current defaults. The module keeps
full precision, rounding to 3 decimals belongs to `report.py` alone,
and the analytics tests choose values as binary fractions, halves and
quarters, so every mean and median is exact in float arithmetic and
the assertions carry no rounding story at all.

The pool variant exists for the reason #xref-to("python",
"multiprocessing") gave: pandas work on the loop thread freezes every
other coroutine, and the escape is a process.

#listing("python/capstone/cpu.py", first: 1, last: 27, caption: [the whole pool module: a module-level worker, plain dict payloads, one submit])

`run_pooled` is spawn-safe by construction, which on windows is the
only construction that works: the worker is a module-level function,
the payload and the result are plain dicts, and importing this module
executes nothing. The `__main__` guard the spawn rules require lives
where an entry point belongs, at the bottom of `cli.py`. The single
submit is a documented choice, and the module's own header states the
arithmetic: count, mean, min, and max would merge cleanly across
shards, but a median of medians is a lie, so the whole frame goes to
one worker and the pool buys the event loop its freedom rather than a
speedup. The parity tests pin the contract on spawned windows workers:
the pooled summary equals the inline summary to the last float, the
return is a typed `Summary`, and empty input skips the pool entirely.
The data boundary is pickle: rows cross as dicts, and on this
interpreter the default protocol is 5, probed, the protocol PEP 574
introduced for out-of-band buffers. Payloads here are json-shaped and
small, so the buffer machinery never enters the picture, and returning
`model_dump` data rather than numpy structures keeps it that way.

#callout("note", "the pool is freedom, not throughput", [
  With one submit, the aggregation is not parallel at all: a single
  spawned worker does the whole `groupby`. What the pool buys is the
  loop thread back, so a slow frame delays heartbeats and queue traffic
  by a pickle round trip instead of by the full aggregation time. The
  cli uses the inline path, because at fixture scale serializing the
  rows costs more than aggregating them, and `run_pooled` stands as the
  tested offload pattern for the frames where that trade flips.
])

#diagram([the pool crossing: what is pickled, what is spawned, and what comes back], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 6.6, 4.4, 1.5, [records, #linebreak() pydantic objects, #linebreak() full precision])
  box(5.6, 6.6, 5.2, 1.5, [model\_dump, #linebreak() a list of plain dicts])
  box(12.0, 6.6, 5.6, 1.5, [one submit to one worker, #linebreak() ProcessPoolExecutor], fill: luma(220))
  box(18.4, 6.6, 3.2, 1.5, [spawned #linebreak() worker])
  cdraw.line((4.8, 7.35), (5.6, 7.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.8, 7.35), (12.0, 7.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.6, 7.35), (18.4, 7.35), stroke: luma(100), mark: (end: ">"))
  cdraw.content((20.0, 5.4), [the worker rebuilds Readings, #linebreak() aggregates, returns a dict], wrap: text.with(size: 6pt))
  box(12.0, 3.8, 9.6, 1.4, [Summary.model\_validate, #linebreak() typed again on this side], fill: luma(205))
  cdraw.line((20.0, 5.1), (20.0, 5.2), stroke: luma(100))
  cdraw.line((20.0, 5.2), (16.8, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.6, 3.6), (11.2, 5.2), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((8.4, 4.4), [pickle crossing, #linebreak() protocol 5 default, #linebreak() probed], wrap: text.with(size: 6pt, fill: luma(140)))
  cdraw.content((10.9, 2.0), [median does not merge across shards: one submit, the loop stays free, parity is the test], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the cli and logging

The command line is argparse subcommands, the pattern of
#xref-to("python", "plumbing"), and the exit-code table is the
module's first comment: 0 ok, 1 runtime failure, 2 usage from argparse
itself, 3 serve without uvicorn. Logging owns stderr and nothing else:

#listing("python/capstone/cli.py", first: 22, last: 28, caption: [setup\_logging: stderr for logs, stdout reserved for the report document])

`force=True` is there for the tests: `main()` is called repeatedly in
one process, and basicConfig would otherwise silently no-op after the
first call, leaving later runs logging into a stale stderr. The
verbosity flag flips between INFO and DEBUG, and the format is level,
logger name, message, with no timestamps because the gate compares
output, not vibes.

#listing("python/capstone/cli.py", first: 86, last: 103, caption: [the parser: required subcommands, a Path-valued output, host and port defaults])

The `serve` subcommand carries the capstone's most explicit boundary:

#listing("python/capstone/cli.py", first: 67, last: 83, caption: [command\_serve: the uvicorn import is the boundary, exit 3 explains itself])

`uvicorn` is imported inside the function, and an `ImportError` is a
stated condition with an exit code of its own, a logged hint naming
the fastapi standard extra, and no traceback. The pins suite asserts
the venv really is without uvicorn, so the branch is tested behavior,
not dead code. Before serving, `make_report` checks every path with
`is_file()`, so a missing source is a clean exit 1 with the name on
stderr, and source names are file stems, which is why the committed
report says `events-a` and never an absolute path. The written output
uses `newline=""` so windows does not translate the canonical
document's `\n` into `\r\n` on disk.

#listing("python/capstone/tests/test_golden.py", first: 60, last: 86, caption: [the cli edges: usage exits 2, a missing source exits 1, serve without uvicorn exits 3])

All three edges are asserted with stderr captured, including the
`SystemExit` argparse raises for the usage error, so the exit-code
table is test output rather than a comment.

#diagram([one argv through the cli, and every exit code it can produce], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 6.2, 4.6, 1.5, [argv, #linebreak() -v, subcommand, args])
  box(6.2, 6.2, 4.6, 1.5, [argparse, #linebreak() required subparsers])
  box(12.0, 6.2, 4.6, 1.5, [report or serve, #linebreak() make\_report runs])
  cdraw.line((5.0, 6.95), (6.2, 6.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.8, 6.95), (12.0, 6.95), stroke: luma(100), mark: (end: ">"))
  box(17.8, 8.0, 3.8, 1.2, [exit 0: the document, #linebreak() stdout or -o file], fill: luma(205))
  box(17.8, 6.2, 3.8, 1.2, [exit 1: oserror or #linebreak() pipelinetimeout], fill: luma(215))
  box(17.8, 4.4, 3.8, 1.2, [exit 2: usage, #linebreak() argparse raises], fill: luma(215))
  box(17.8, 2.6, 3.8, 1.2, [exit 3: no uvicorn, #linebreak() the logged hint], fill: luma(215))
  cdraw.line((16.6, 6.95), (17.8, 8.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.6, 6.95), (17.8, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.5, 6.2), (8.5, 5.0), stroke: luma(100))
  cdraw.line((8.5, 5.0), (17.8, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.3, 6.2), (14.3, 3.2), stroke: luma(100))
  cdraw.line((14.3, 3.2), (17.8, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.4, 3.8), [serve only:], wrap: text.with(size: 6pt))
  cdraw.content((10.9, 1.2), [logs ride stderr at every exit, the document alone rides stdout], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the golden report

The report module is 44 lines and owns two decisions: the document
shape and its byte-exact rendering.

#listing("python/capstone/report.py", first: 1, last: 44, caption: [the whole module: schema version, rounding, the stable sorts, and the canonical renderer])

`build_report` takes the pipeline result and the summary and produces
a dict with one schema version, the record and dead-letter counts, the
dead letters under the same sort key the pipeline already applied, and
the sensors name-sorted with every float rounded to 3 decimals.
`canonical` renders it: `json.dumps` with sorted keys, indent 2, and
one trailing newline so the file is posix-friendly. Those choices, plus
the `loc:type` detail format part 1 chose for exactly this moment, are
what make the document deterministic from fixed inputs.

The golden test then pins the whole chain, cli included:

#listing("python/capstone/tests/test_golden.py", first: 26, last: 58, caption: [the golden suite: the real cli over committed fixtures, diffed byte for byte])

The test calls `cli.main` with the two fixture paths and stdout
captured, and requires the printed text to equal
`tests/golden/report.json` byte for byte, a file committed alongside
the fixtures. The assertion's failure message carries a unified diff
between the golden file and the new output, so drift reads straight
out of the gate log with line numbers. The second check writes through
`-o` into a temp file and requires the same bytes on disk. The
committed document says 11 records, 3 dead letters, and 4 sensors:
alpha with a count of 4, beta 3, gamma 3, epsilon 1. Golden, not
eyeball: any change to a detail format, a rounding step, a sort order,
or the canonical renderer reddens this diff, and the number in this
paragraph is checkable against the file.

#callout("pitfall", "two newline traps sit between green and a false red", [
  The cli writes the canonical document with `newline=""` because a
  default text-mode write on windows translates every `\n` to `\r\n`,
  and the byte comparison would fail on an artifact of the platform
  rather than of the code. The golden reader uses ordinary
  `read_text`, whose universal newlines fold any `\r\n` back to `\n`,
  so an editor flipping the committed file's line endings cannot fake
  drift either. Both behaviors are load bearing and neither is visible
  in the diff when they go wrong, only in the test that catches them.
])

#diagram([the same behavior change, verified by eyeball and verified by bytes], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((4.6, 9.2), [verified by eyeball], wrap: text.with(size: 6.5pt, weight: 700))
  cdraw.content((15.4, 9.2), [verified by bytes], wrap: text.with(size: 6.5pt, weight: 700))
  box(0.4, 7.0, 8.4, 1.4, [a rounding change, #linebreak() a new detail format, a reordered key])
  box(0.4, 5.0, 8.4, 1.4, [a human skims the output, #linebreak() it still looks like a report])
  box(0.4, 3.0, 8.4, 1.4, [the drift ships, #linebreak() downstream diffs are someone else's], fill: luma(215))
  cdraw.line((4.6, 7.0), (4.6, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.6, 5.0), (4.6, 4.4), stroke: luma(100), mark: (end: ">"))
  box(11.2, 7.0, 8.4, 1.4, [the same change, #linebreak() committed fixtures in, cli runs])
  box(11.2, 5.0, 8.4, 1.4, [unequal bytes against #linebreak() tests/golden/report.json], fill: luma(220))
  box(11.2, 3.0, 8.4, 1.4, [red, with a unified diff #linebreak() naming the exact lines], fill: luma(215))
  cdraw.line((15.4, 7.0), (15.4, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.4, 5.0), (15.4, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.9, 1.2), [golden files turn formatting into a contract: the eyeball never sees the file at all], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the served api

The api module is a factory over the finished artifact:

#listing("python/capstone/api.py", first: 27, last: 36, caption: [the response model: schema is reserved vocabulary on BaseModel, so the field carries an alias])

`schema` is a pydantic reserved name on model classes, so the python
field is `schema_version` with `alias="schema"` and
`populate_by_name=True`, and the wire format stays the canonical
document's key. The factory wires the report in through a lifespan,
the pattern #xref-to("python", "fastapi") taught:

#listing("python/capstone/api.py", first: 46, last: 66, caption: [create\_app: lifespan state, the 503 guard, and the report endpoint])

`create_app` never imports `cli`, so the app constructs without any
argparse side effects, and the lifespan is what puts the report on
`app.state` between startup and shutdown, clearing it in a `finally`.
A request that slips outside the lifespan meets `current_report`, which
answers 503 rather than raising an `AttributeError` through the
framework. The two query-shaped endpoints finish the surface:

#listing("python/capstone/api.py", first: 68, last: 88, caption: [stats with a validated query parameter, and the sensor lookup with an honest 404])

`min_count` arrives through `Query(default=1, ge=1)`, so a zero is a
422 from the framework before any handler code runs, and the unknown
sensor name is a 404 with the name in the detail. Every response rides
a pydantic response model, so the serialized shape is a contract even
though the handler returns plain dicts.

The suite drives the app in-process with fastapi's `TestClient`, no
sockets anywhere, the engine under it on this starlette line being
httpx2, the test-only pin the versions section pins from the other
side. The report under test is not a fixture dict: `setUpClass` builds
it by running the real pipeline and analytics over the committed
fixtures, so the api numbers are the golden numbers. The lifespan
contract has its own pair of tests:

#listing("python/capstone/tests/test_api.py", first: 102, last: 112, caption: [entering the TestClient context runs the lifespan, and never entering it answers 503])

uvicorn appears in prose only, here and in the cli's serve branch: the
book's venv carries no server, the exit-3 contract says so out loud,
and installing the fastapi standard extra is the documented path from
prose to a running process.

#diagram([the served report's layer stack, and the status codes at the edges], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 7.0, 5.2, 1.6, [TestClient, #linebreak() httpx2 engine, #linebreak() in-process, no sockets], fill: luma(220))
  box(6.8, 7.0, 4.6, 1.6, [the asgi app, #linebreak() fastapi factory])
  box(12.6, 7.0, 4.6, 1.6, [lifespan state, #linebreak() app.state.report])
  box(18.0, 7.0, 3.6, 1.6, [response models, #linebreak() pydantic])
  cdraw.line((5.6, 7.8), (6.8, 7.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.4, 7.8), (12.6, 7.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.2, 7.8), (18.0, 7.8), stroke: luma(100), mark: (end: ">"))
  box(12.6, 4.6, 9.0, 1.4, [the report dict, built once by pipeline + analytics, #linebreak() the same numbers as the golden file], fill: luma(205))
  cdraw.line((14.9, 7.0), (14.9, 6.0), stroke: luma(100), mark: (end: ">"))
  box(0.4, 4.6, 9.0, 1.4, [outside lifespan: 503, #linebreak() unknown sensor: 404, min\_count 0: 422], fill: luma(215))
  cdraw.content((10.9, 2.8), [serve in prose: uvicorn.run(api.create\_app(document)) when the standard extra is installed, #linebreak() exit 3 with the hint when it is not, and the pins assert this venv has none], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== version pins asserted

The capstone runs on one toolchain, and the suite says which one
before any behavioral test trusts the api shapes underneath it:

#listing("python/capstone/tests/test_versions.py", first: 9, last: 42, caption: [the pins: the interpreter, the six library versions, and the two absence contracts])

The interpreter assert is the same 3.14.7 every sample pins since
#xref-to("python", "toolchain"). The six library pins are
`requirements.txt` verbatim, each under its own `subTest` so drift
names the library that moved: fastapi 0.141.1, starlette 1.6.0, httpx2
2.12.0, pydantic 2.13.4, pandas 3.0.5, numpy 2.5.3. The two absence
contracts are the interesting half. uvicorn must be missing, because
the cli's exit 3 is a tested promise that a quietly installed server
would break, and the comment says the assert and the contract change
together. httpx must be missing because starlette moved its TestClient
engine to httpx2, and if httpx ever sneaks back into the venv, the
machinery under the api tests silently changes with no test failing,
which is precisely when an assert should fire. The gate closes the
loop from the other side: the venv's directory name is derived from
the requirements sha256, so a changed pin builds a fresh venv, and
this table is what describes the inside of it.

#diagram([the pin families: what is taught, what is test-only, what is absent, what is transitive], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 7.0, 6.6, 1.5, [the interpreter, #linebreak() cpython 3.14.7 asserted], fill: luma(205))
  box(7.6, 7.0, 6.6, 1.5, [taught libraries, #linebreak() fastapi, pydantic, pandas, numpy])
  box(14.8, 7.0, 6.8, 1.5, [test-only pin, #linebreak() httpx2, the TestClient engine])
  box(0.4, 4.8, 6.6, 1.5, [absence contracts, #linebreak() uvicorn and httpx must be missing], fill: luma(215))
  box(7.6, 4.8, 6.6, 1.5, [tools-only, #linebreak() ruff, format and lint])
  box(14.8, 4.8, 6.8, 1.5, [transitive, pinned, #linebreak() starlette rides fastapi])
  box(0.4, 2.6, 21.2, 1.3, [every asserted row is subTest-ed: drift names the row that moved, and the venv directory is the requirements sha256], fill: luma(220))
  cdraw.content((11.0, 1.2), [a green row here is what lets every other test trust the shapes it is asserting against], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== profiled, and why

The bench behind part 1's profiled section runs the whole pipeline at
30000 lines and prints the deterministic profiler's table, committed
as the dated capture:

#listing("python/samples/bench/captures/2026-09-13-capstone-profile.txt", first: 1, last: 18, caption: [the capstone under cProfile: 1.5 million calls, 0.639 seconds, the boundary and the queue machinery on top])

Read through #xref-to("python", "profiling")'s lens, the first thing
the table says is which times are facts: the ranking is stable rerun
after rerun because the profiler is deterministic, so "json decode
and `parse_line` and `validate_python` own the top" is a statement
about code, not about a lucky afternoon. The second is what cumtime
is for: `parse_line` carries 0.211 s of cumulative time against
0.035 s of its own, so the boundary function is a toll booth, the
toll is paid underneath it in json and pydantic core, and optimizing
the Python body of `parse_line` would optimize the smallest number
on its row. `_run_once`, the event loop's own step function, carries
0.551 s cumulative of the 0.639 s total, which is the honest price
of the async design: most of the wall time is suspension and
resumption machinery, visible only because the profiler counts
calls, not because any of it is slow.

Read through #xref-to("python", "pymalloc")'s lens, the same run is
an allocator story. Thirty thousand lines each allocate a decoded
dict, a `Reading`, floats and strings that die on the spot, and the
freelists absorb the churn, which is why the tracemalloc column
reads 18154289 current against 26640564 peak: the surviving 18 MB is
the materialized records list the analytics phase needs, and the 8
MB above it at the crest is pandas building its frame, released when
`summarize` returns. Nothing grows per line; the peak tracks the
frame build, not the ingest.

#diagram([the 0.639 s capstone run split by owner: the event loop's cumulative shadow over everything, the boundary's third, the queue plumbing between], length: 13pt, {
  let band(y, label, frac, fill) = {
    cdraw.content((7.2, y), [label], wrap: text.with(size: 6pt), anchor: "east")
    cdraw.rect((7.6, y - 0.30), (7.6 + frac * 13.4, y + 0.30), fill: fill, radius: 0.0)
  }
  band(7.6, [\_run_once cumtime], 0.551 / 0.639, luma(215))
  band(5.6, [parse\_line cumtime], 0.211 / 0.639, luma(180))
  band(3.6, [json decode + loads], 0.222 / 0.639, luma(195))
  band(1.6, [queue put and get], 0.174 / 0.639, luma(205))
  cdraw.line((7.6, 0.9), (21.2, 0.9), stroke: 0.5pt + luma(180))
  cdraw.content((14.4, 0.45), [fractions of the 0.639 s total, cumtime over 30000 lines, capture of 2026-09-13], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== honest boundaries

What this capstone is not is part of its design, so it gets stated
with the same care as the pins. It is not a production ingestion
system: nothing is persisted beyond an optional file write, there are
no retries or backoff for a flaky source, no continuous metrics or
telemetry, no horizontal
scale, and one machine carries all of it. The served api is a snapshot,
not live queries: the report is built once before the server starts,
so a reading ingested after startup never appears in a response. The
analytics is one-shot batch over a materialized list, not streaming,
and the aggregation cost grows with the record count by design. The
security posture is a loopback bind with no auth, no tls, and no rate
limits, which is what a teaching artifact should be and what a
deployment is not.

The scale limits are equally concrete, and the metrics story split
when the profiled sections were added. The fixtures are 14 lines and the
golden numbers are hand-counted, so the arithmetic is checkable, and
what the capstone measures about itself is now real and named: the
in-suite profile-shape and bounded-peak checks of the two profiled
sections, the dated 30000-line capture above, and the kernel scales
in #xref-to("python", "profiling"), 1m and 10m measured, 100m as
deleted one-offs, 1b by math. What stays unmeasured is production
throughput: no number here claims how fast this pipeline ingests a
flaky real source over a real network, because the fixtures cannot
answer that and the book will not invent it. The raw queue bounds at 8
because backpressure is the lesson, not the tuning. The pool is one
submit for the median's sake, and the join budget is 30 seconds
because a stuck source must end in a raise, not because 30 was
measured. The next steps in a real system follow from the same
boundaries: rotation-aware source adapters where the shrink bound now
stands, a persistent dead-letter sink with replay, fetch retries with
exponential backoff and jitter, sharded aggregation where medians need
raw values or sketches on the workers, uvicorn or equivalent under the
factory with real process supervision, and a schema-versioning story
for the golden document the day its shape changes.

#diagram([each capstone layer, and what a production system would add beside it], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 8.6, 9.6, 1.0, [the capstone, as built], fill: luma(205))
  box(11.6, 8.6, 10.0, 1.0, [what production would add], fill: luma(215))
  box(0.4, 7.2, 9.6, 1.1, [sources: snapshot, follow, shrink bound])
  box(0.4, 5.8, 9.6, 1.1, [fetch: one attempt, typed failures])
  box(0.4, 4.4, 9.6, 1.1, [pipeline: one loop, in-memory queues])
  box(0.4, 3.0, 9.6, 1.1, [analytics: one-shot batch, one submit])
  box(0.4, 1.6, 9.6, 1.1, [api: a snapshot, loopback, no auth])
  box(11.6, 7.2, 10.0, 1.1, [rotation, checkpoints, a durable log])
  box(11.6, 5.8, 10.0, 1.1, [retries with jitter, circuit breaking])
  box(11.6, 4.4, 10.0, 1.1, [a broker, persistence, horizontal scale])
  box(11.6, 3.0, 10.0, 1.1, [streaming shards, sketches for medians])
  box(11.6, 1.6, 10.0, 1.1, [a supervised server, tls, auth, limits])
  cdraw.content((10.9, 0.5), [every left box is tested and pinned, every right box is deliberately absent and said so], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "the capstone in the gate", [
  The full suite, run the way the gate runs it from
  `books/python/capstone`, `python -X utf8 -m unittest discover -s
  tests -t .` under the book venv, reports 78 tests and OK. Part 2
  owns 30 of them: `test_analytics` 8, `test_cpu` 3, `test_golden` 5,
  `test_api` 10, `test_versions` 4, the profiled legs living in part
  1's inventory. The golden contract holds byte for
  byte on both paths, stdout and the `-o` file, and the pins table
  asserts the exact six library versions and the two absences the
  exit-3 contract depends on. Verified by `make verify-py`, 1103 checks
  and 78 capstone tests in chapters 1 through 28.
])

== the service part after the capstone

The capstone is this book's teaching artifact, and the next evidence
layer was built after it, on the same manual: the service part under
`books/python/api`, a stdlib-exclusive vehicle on http.server with a
hand-rolled route table, seven layers reading trace through recover,
and a sqlite store. The findings register dates the service-part wave
2026-09-27 and records the suite at 313 tests over 22 modules with the
16 frozen vectors as the spine, and the adversarial closeout grew it
to the 314 that stands. `make verify-pyapi` gates it, with the docker
lane and the opt-in pyapi-cover lane as the second and third gates
outside the plain verify chain.

sources: fastapi.tiangolo.com/advanced/events (lifespan as an async
context manager with yield), fastapi.tiangolo.com/tutorial/testing
(TestClient), pydantic.dev/docs/validation/latest/concepts/fields
(Field constraints), pydantic.dev/docs/validation/latest/errors/errors
(ErrorDetails with loc and type), pandas.pydata.org/docs/user\_guide/
groupby.html (groupby aggregation), numpy.org/doc/stable/reference/
generated/numpy.mean.html (the ufunc used as an aggregator),
peps.python.org/pep-0574 (pickle protocol 5 and out-of-band buffers),
docs.python.org/3.14/library/concurrent.futures.html
(ProcessPoolExecutor), docs.python.org/3.14/library/argparse.html
(subparsers, usage errors exiting 2), docs.python.org/3.14/library/
logging.html (basicConfig, force), all accessed 2026-09-12. The
78-test count, the pooled-versus-inline parity, the default pickle
protocol of 5, and the exit codes 0 through 3 probed on this machine
the same day, the profiled capture and its lens taken 2026-09-13.
Verified by `make verify-py`, 30 of 78 capstone tests in
this chapter's modules.
