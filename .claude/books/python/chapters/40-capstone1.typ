#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= capstone: ingest and analysis pipeline, part 1

Chapters 1 through 26 taught pieces. This chapter and the next assemble
them into one working program under `books/python/capstone/`: 9 modules
and a unittest suite of 78 tests that the verify gate runs as its
capstone leg, the same gate that has counted ok lines for every sample
since chapter 1. The program ingests sensor readings in jsonl form.
Named async line iterators go in, and two lists come out: records
validated at a pydantic boundary, and dead letters carrying a reason
from a closed three-word vocabulary. Part 1 owns ingest and validation,
`sources.py`, `fetch.py`, `models.py`, `pipeline.py`, with 48 of the 78
tests. Part 2, #xref-to("python", "capstone2"), owns aggregation, the
canonical report, the cli, and the served api.

== the capstone contract

The contract is one sentence: every raw line that enters the pipeline
leaves as either a validated `Reading` in `records` or a `DeadLetter`
in `dead`, and the only other outcome is `PipelineTimeout`, which is
the pipeline refusing to hang. A malformed line is a payload with a
destination, never a crash. The entry point states the whole surface:

#listing("python/capstone/pipeline.py", first: 52, last: 73, caption: [the run signature: sources in, defaults for the queue, the consumers, and the join budget])

Three numbers are load bearing. `queue_size` bounds the raw queue at 8
by default, so memory is bounded by construction and a slow consumer
slows producers down instead of being buried. `consumers` sets 2
validation workers. `join_timeout` caps the graceful drain at 30
seconds, and exceeding it cancels every task and raises. The records
list needs no lock because only consumers append to it, and every
consumer runs on the one event-loop thread.

Every module is a pillar chapter assembled. The adapters read files the
way #xref-to("python", "files") taught, `encoding=` named on every
open. The fetch adapter runs blocking stdlib urllib inside worker
threads through `asyncio.to_thread`, the offload of
#xref-to("python", "asyncio") meeting the thread discipline of
#xref-to("python", "threads"). The boundary models are the pydantic of
#xref-to("python", "pydantic"). The queue choreography is the asyncio
queue machinery from the same asyncio chapter, with the sentinel
arithmetic this section of the capstone had to get right on its own.
Part 2 aggregates with the pandas of #xref-to("python", "pandas") and
the numpy of #xref-to("python", "numpy"), offloads through the process
pool patterns of #xref-to("python", "multiprocessing"), parses its
command line with the argparse and logging of #xref-to("python",
"plumbing"), and serves with #xref-to("python", "fastapi").

#callout("note", "built test first, module by module", [
  The order of work followed #xref-to("python", "testing"): the
  failing test existed before the module it names, and each commit
  carried the red test and the green implementation together. The
  closing callout of this chapter is the resulting ledger, module by
  module with its count, so a reader can check the inventory against
  the suite output the way every chapter's ok count is checked against
  the gate.
])

#diagram([the nine modules and the pillar chapter each one assembles], length: 13pt, {
  let box(x, y, w, h, t, sub, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h - 0.45), t, wrap: text.with(size: 6pt))
    cdraw.content((x + w / 2, y + 0.45), sub, wrap: text.with(size: 6pt, fill: luma(100)))
  }
  cdraw.content((4.0, 9.4), [part 1, this chapter], wrap: text.with(size: 6.5pt, weight: 700))
  box(0.4, 7.6, 4.6, 1.5, [sources.py], [files, ch 15])
  box(5.4, 7.6, 4.6, 1.5, [fetch.py], [asyncio + threads])
  box(10.4, 7.6, 4.6, 1.5, [models.py], [pydantic, ch 26])
  box(15.4, 7.6, 4.6, 1.5, [pipeline.py], [asyncio queues])
  cdraw.content((4.0, 6.6), [part 2, next chapter], wrap: text.with(size: 6.5pt, weight: 700))
  box(0.4, 4.8, 3.4, 1.5, [analytics.py], [pandas + numpy])
  box(4.2, 4.8, 3.4, 1.5, [cpu.py], [multiprocessing])
  box(8.0, 4.8, 3.4, 1.5, [report.py], [json canonical])
  box(11.8, 4.8, 3.4, 1.5, [cli.py], [plumbing, ch 19])
  box(15.6, 4.8, 4.4, 1.5, [api.py], [fastapi, ch 22])
  cdraw.rect((0.4, 2.4), (20.0, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((10.2, 3.0), [tests: 10 files, 78 tests, the gate's capstone leg under make verify-py], wrap: text.with(size: 6pt))
  cdraw.content((10.2, 1.2), [the toolchain of chapter 1 underneath everything: pinned interpreter, venv, -X utf8, red on any failure], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== sources and fetch

Two adapters turn the outside world into lines, and both keep their
promises small enough to test. `tail` is a snapshot: it yields every
complete line present and stops, and a trailing partial line is held
back rather than completed with an invented newline. `follow` is watch
mode: catch up, then poll for appends until the stop event is set, with
one final read draining lines that landed before stop won. A partial
line stays buffered across polls until more bytes finish it. Rotation
is out of scope, stated in the module header, and the shrink bound
stands in for it: if the file becomes shorter than what was already
consumed, the stream ends instead of reading from a stale offset.

#listing("python/capstone/sources.py", first: 19, last: 38, caption: [complete-line splitting and the tail snapshot, a partial line never delivered])

The splitting helper is the whole line discipline: split on `\n`, keep
the tail without a newline as the new buffer, strip a lone trailing
`\r` so crlf logs and lf logs agree. The open uses `newline=""` so the
 `\r` survives to be stripped here rather than being translated
underneath, the chapter 15 habit. Reads run in 4096-character chunks
with `asyncio.sleep(0)` between them, so a large file cannot monopolize
the loop.

The network sibling is `fetch.py`, and it starts from a boundary the
fastapi chapter stated: the book teaches no http client library, so the
client side is stdlib `urllib.request`. Blocking socket work belongs
off the event loop, so the actual call runs inside a worker thread via
`asyncio.to_thread`, and every failure crosses back as one of four
typed exceptions:

#listing("python/capstone/fetch.py", first: 13, last: 37, caption: [the typed exception taxonomy: timeout, status, decode, unreachable, over one base])

#listing("python/capstone/fetch.py", first: 48, last: 66, caption: [the adapter body: to\_thread for the blocking call, every urllib error rewritten])

The mapping has one subtlety per branch. `HTTPError` is response-like,
so it is closed before being rewritten, and its status code rides into
`FetchStatus`. Connect timeouts arrive wrapped in `URLError` while read
timeouts surface bare, and both become `FetchTimeout`. A non-200 status
that reached the return without raising still fails, and a body that is
not utf-8 becomes `FetchDecode` instead of a decode traceback. Nothing
in this module ever leaks a raw urllib error into the pipeline.

The proof that the adapter works against real network io is exactly one
suite in the capstone, and it says so in its first line:

#listing("python/capstone/tests/test_fetch.py", first: 54, last: 97, caption: [the real-socket proof: a threaded http.server on an ephemeral loopback port, six checks])

The server is a `ThreadingHTTPServer` bound to `127.0.0.1` on port 0 in
a daemon thread, started once per class in `setUpClass` and shut down
in `tearDownClass`. Six checks run against it: the fixture bytes round
trip as text, the document splits into lines, the async source adapter
yields them, a handler that sleeps a full second against a 0.3 second
client timeout proves `FetchTimeout` on a genuine stalled socket, a
404 proves `FetchStatus`, and a body of raw non-utf-8 bytes proves
`FetchDecode`. The suite's other six checks never open a socket at all:
they monkeypatch `urllib.request.urlopen` with side effects and assert
the same taxonomy, the mock seam of chapter 20 aimed at the one
boundary worth faking.

#callout("pitfall", "a loopback listener still pops the windows firewall dialog", [
  Measured on this box and recorded in this repo's `tools/net-quiet.ps1`:
  with the firewall's notify-on-listen setting on, even a listener bound
  to 127.0.0.1 on an ephemeral port raises the allow-access dialog, and
  a popped dialog stalls an unattended gate run until someone clicks it.
  `make verify` therefore runs its network preflight before any suite,
  `tools/test-net-preflight.ps1`, asserting `NotifyOnListen` is off on
  every profile, the setting microsoft documents as
  `Set-NetFirewallProfile -NotifyOnListen False`. Loopback traffic was
  never filtered, so the suite keeps working with the setting off, and
  the one real-socket test runs unattended or the gate reports the
  drift loudly.
])

#diagram([two adapters, one contract: lines tagged with a source name, and where the thread hop happens], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 7.2, 4.0, 1.6, [a jsonl file, #linebreak() utf-8 text])
  box(0.4, 4.6, 4.0, 1.6, [a url, #linebreak() one http document])
  box(5.6, 7.2, 4.4, 1.6, [sources.tail, #linebreak() snapshot of complete lines], fill: luma(220))
  box(5.6, 4.6, 4.4, 1.6, [fetch.fetch\_source, #linebreak() lines from the network])
  box(11.6, 4.6, 5.2, 1.6, [asyncio.to\_thread, #linebreak() worker thread], fill: luma(205))
  box(17.6, 4.6, 3.6, 1.6, [urllib, #linebreak() the real socket])
  box(5.6, 2.2, 8.0, 1.4, [both yield (source, line) or plain lines #linebreak() into the pipeline], fill: luma(220))
  cdraw.line((4.4, 8.0), (5.6, 8.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.4, 5.4), (5.6, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.0, 5.4), (11.6, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.8, 5.4), (17.6, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.8, 4.6), (7.8, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.4, 7.6), [the only blocking work in the capstone, #linebreak() and the only real sockets in the suite], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((10.9, 0.9), [failures cross the thread boundary as typed exceptions, never as raw urllib errors], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== pydantic at the boundary

Every raw line meets pydantic exactly once, in `parse_line`, and the
good payload that survives is one small model:

#listing("python/capstone/models.py", first: 16, last: 27, caption: [the Reading contract and the DeadLetter shape, the pipeline's two currencies])

The constraints are the pipeline's data contract. A sensor name matches
`^[a-z][a-z0-9_]{0,31}$`, so names are lowercase, bounded, and safe as
report keys. A timestamp is an integer between 0 and 4102444800, unix
seconds bounded at the start of 2100, so a garbage clock cannot smuggle
in an arbitrary int. A value is a float with `allow_inf_nan=False`, and
that last flag carries weight: `json.loads` happily parses the `NaN`
literal as valid json, so the poison float can arrive through a
perfectly legal document, and the boundary is where it stops. Extra
fields are ignored, an int value coerces to float, both pinned by
tests. A reject is data too: a `DeadLetter` carries the source name,
one reason from the closed tuple `("schema", "field", "source")`, a
detail string, and the offending line verbatim. The vocabulary is
closed by an explicit test, so adding a fourth reason means changing
the contract test first, never silently.

#listing("python/capstone/models.py", first: 43, last: 63, caption: [parse\_line: three schema rejects, then pydantic, then one field reject])

Three ways to fail before pydantic even runs: an empty line, a line
that is not json, and json that is not an object, all reason `schema`.
Then `Reading.model_validate` gets its chance, and a `ValidationError`
becomes reason `field` with a detail built from `loc:type` pairs joined
by bars, `ts:int_parsing`, `value:missing`. The consumers see none of
this machinery: rejection travels as `RecordRejected`, an exception
carrying the `DeadLetter`, so a raw pydantic error never escapes the
boundary.

#callout("pitfall", "pydantic's prose error messages are not stable data", [
  A `ValidationError` message embeds the input value's repr, so the
  dead-letter detail for a bad timestamp would contain whatever the
  broken line happened to say. Part 2 commits the report to a golden
  file diffed byte for byte, and input reprs would make that diff
  unstable against fixture edits. The `loc:type` pairs keep the detail
  a closed-form summary of what was rejected and why, stable enough to
  pin, informative enough to debug from.
])

#diagram([one line through the boundary: the checks in order and the three reject slots], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 6.2, 3.4, 1.4, [raw line, #linebreak() stripped])
  box(4.6, 6.2, 3.6, 1.4, [json.loads])
  box(8.8, 6.2, 3.6, 1.4, [is it an object?])
  box(13.0, 6.2, 4.0, 1.4, [Reading.model\_validate, #linebreak() three constrained fields], fill: luma(220))
  box(17.8, 6.2, 3.4, 1.4, [a Reading, #linebreak() records.append], fill: luma(205))
  cdraw.line((3.8, 6.9), (4.6, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.2, 6.9), (8.8, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.4, 6.9), (13.0, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.0, 6.9), (17.8, 6.9), stroke: luma(100), mark: (end: ">"))
  box(4.6, 3.4, 3.6, 1.4, [empty or not json], fill: luma(215))
  box(8.8, 3.4, 3.6, 1.4, [a list, a number, #linebreak() a string], fill: luma(215))
  box(13.0, 3.4, 4.0, 1.4, [pattern, bounds, #linebreak() nan refused], fill: luma(215))
  cdraw.line((6.4, 6.2), (6.4, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.6, 6.2), (10.6, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 6.2), (15.0, 4.8), stroke: luma(100), mark: (end: ">"))
  box(4.6, 1.2, 12.4, 1.3, [dead letter: reason schema, schema, or field, detail as loc:type pairs, the line verbatim], fill: luma(215))
  cdraw.line((6.4, 3.4), (6.4, 2.5), stroke: luma(140))
  cdraw.line((10.6, 3.4), (10.6, 2.5), stroke: luma(140))
  cdraw.line((15.0, 3.4), (15.0, 2.5), stroke: luma(140))
  cdraw.content((18.8, 4.3), [the third reason, source, #linebreak() belongs to the adapter, #linebreak() part 4 shows it], wrap: text.with(size: 6pt, fill: luma(100)))
})

== the queue pipeline

The middle of the capstone is the part asyncio chapters warn about:
producers, consumers, a bounded queue between them, and a shutdown that
must drain everything exactly once.

#listing("python/capstone/pipeline.py", first: 25, last: 49, caption: [a producer per source and the consumer loop, rejects routed to the dead-letter queue])

A producer iterates its adapter and puts `(name, line)` pairs on the
raw queue. When the adapter itself fails, a fetch timeout, an
unreadable file, the failure becomes one dead letter with reason
`source` and the exception's type name as its detail, the producer
ends, and the pipeline lives on. A consumer takes an item, runs
`parse_line`, and appends either a `Reading` or, when `RecordRejected`
arrives, its dead letter to the dlq. The bounded queue is
backpressure: `await raw.put(...)` suspends the producer when the queue
is full, so a slow consumer slows ingestion down, and no line is ever
dropped or buffered without bound. The tight-queue test pins the
extreme:

#listing("python/capstone/tests/test_pipeline.py", first: 56, last: 63, caption: [queue\_size 1 is maximal backpressure, and all 8 lines still arrive])

Shutdown is where the naive design dies, so the capstone does it in two
phases with sentinels counted against consumers:

#listing("python/capstone/pipeline.py", first: 75, last: 101, caption: [the two-phase drain, the bounded join, and the stable dead-letter order])

Phase one joins the producers, which means every line is already on the
queue or the producers are dead. Only then does the main task put
exactly one `_DONE` sentinel per consumer, and each consumer drains
what precedes its own stop and exits. The whole `phases()` coroutine
runs under `asyncio.wait_for` with the join budget, and a timeout
cancels every task, gathers them with `return_exceptions=True` so
cancellation does not itself raise, and raises `PipelineTimeout` from
`None`, a clean failure with no misleading cause chain. After a clean
drain, the dlq is emptied into the result and the dead letters are
sorted by `(source, reason, detail, line)`, the same key part 2's
report will use, so the output order is a contract rather than
whichever consumer happened to reject first.

#callout("pitfall", "one sentinel per producer starves a consumer", [
  The common shutdown puts a sentinel on the queue for each producer
  and lets each consumer exit on the first sentinel it draws. With 2
  producers and 2 consumers, nothing stops consumer A from drawing both
  sentinels: A exits, B blocks on `get()` forever, and the join on B
  never returns. The bug is arithmetic, not timing, so no test
  interleaving reliably catches it. Counting sentinels against
  consumers instead, after the producers have joined, makes it
  structurally impossible: every consumer is guaranteed exactly one
  stop, and every item ahead of that stop is real work.
])

#listing("python/capstone/tests/test_pipeline.py", first: 141, last: 150, caption: [a producer that never ends: the bounded join cancels and raises instead of hanging])

The stuck generator never yields, the join budget of 0.2 seconds
expires, and the test asserts `PipelineTimeout` rather than a hang.
Cancellation is the last resort behind the graceful path, and the
watch-mode shutdown test exercises the graceful path end to end: a
`follow` source drains its late append, the stop event ends the
producer, and `run()` returns with both records.

#diagram([the drain as a state machine: join, sentinel per consumer, exit, and the budget over all of it], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 6.4, 4.4, 1.5, [producers running, #linebreak() bounded queue between], fill: luma(220))
  box(6.0, 6.4, 4.4, 1.5, [producers joined, #linebreak() every line enqueued])
  box(11.6, 6.4, 4.4, 1.5, [one \_DONE, #linebreak() per consumer])
  box(17.2, 6.4, 4.0, 1.5, [consumers drain, #linebreak() exit on their stop])
  cdraw.line((4.8, 7.15), (6.0, 7.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.4, 7.15), (11.6, 7.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.0, 7.15), (17.2, 7.15), stroke: luma(100), mark: (end: ">"))
  box(0.4, 3.8, 8.4, 1.4, [dlq emptied, dead letters sorted, #linebreak() PipelineResult returns], fill: luma(205))
  cdraw.line((19.2, 6.4), (19.2, 5.2), stroke: luma(100))
  cdraw.line((19.2, 5.2), (8.8, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.4, 3.8), (21.2, 2.4), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((15.8, 3.1), [join budget, default 30 s, #linebreak() over all four states], wrap: text.with(size: 6pt, fill: luma(140)))
  cdraw.line((15.8, 3.8), (8.8, 4.1), stroke: luma(140), mark: (end: ">"))
  cdraw.content((15.8, 1.4), [budget expiry: cancel every task, gather quietly, raise PipelineTimeout], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((4.6, 2.2), [the naive design skips the middle two states: #linebreak() sentinels per producer, one consumer starves], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== profiled: the ingest pipeline

The pipeline now measures itself. The in-suite check runs 3000
synthetic lines through `run()` under `cProfile` and asserts the shape
of the profile rather than any timing: the top capstone-owned row by
`tottime` is `_consume`, the consumer loop every line passes through,
and `parse_line`'s `cumtime` is more than twice its own `tottime`,
because the boundary function's time is really json decoding and
pydantic validation underneath it. The tracemalloc check holds the
same fixed input to a bounded peak, between 1 and 6 MB, tight enough
that a leak would break it and loose enough that a scheduling hiccup
cannot.

#listing("python/capstone/tests/test_profiled.py", first: 34, last: 50, caption: [the deterministic legs: top of tottime by name, the boundary names present, cumtime against tottime])

The opt-in bench, `samples/bench/capstone_profile.py --n 30000`,
carries the dated capture the two capstone chapters quote, and part
2's closing section reads it through the profiling chapters' lens.

#diagram([the ingest profile as three owners: the consumer loop, the json decode under every line, the pydantic validation under every line], length: 13pt, {
  let bar(y, label, tot, cum, scale) = {
    cdraw.content((7.0, y), [label], wrap: text.with(size: 6pt), anchor: "east")
    cdraw.rect((7.4, y - 0.26), (7.4 + tot / scale * 13.4, y + 0.26), fill: luma(160), radius: 0.0)
    cdraw.rect((7.4, y + 0.30), (7.4 + cum / scale * 13.4, y + 0.82), fill: luma(220), radius: 0.0)
  }
  bar(7.6, [\_consume], 0.036, 0.340, 0.6)
  bar(5.6, [parse\_line], 0.035, 0.211, 0.6)
  bar(3.6, [json decode], 0.067, 0.221, 0.6)
  bar(1.6, [validate\_python], 0.034, 0.034, 0.6)
  cdraw.content((13.5, 9.0), [dark tottime, light cumtime, seconds over 30000 lines], wrap: text.with(size: 6.5pt))
  cdraw.content((13.5, 0.6), [the suite asserts the names and the cum over tot split, the bench quotes the seconds], wrap: text.with(size: 6pt, fill: luma(100)))
})

== what part 1 proves

The end-to-end tests run the real pipeline over committed fixtures and
check the split by hand:

#listing("python/capstone/tests/test_pipeline.py", first: 30, last: 49, caption: [the fixture arithmetic: 11 records, 3 dead letters, exact reasons and sources])

`events-a.jsonl` holds 8 valid lines. `events-b.jsonl` holds 3 valid
lines and 3 rejects, one not json at all, one missing its value, one
with a string timestamp. The pipeline returns 11 records and 3 dead
letters, the schema reject carrying `JSONDecodeError` as its detail and
the two field rejects carrying `value:missing` and `ts:int_parsing`,
all from `events-b`. The sort test then requires the dead letters in
`(source, reason, detail, line)` order, whatever order the consumers
rejected in. The failure tests close the loop: an adapter that dies
mid-stream after two good lines leaves those records intact and files
one `source` dead letter, a dead neighbor does not take the good source
down with it, and a stuck producer ends in `PipelineTimeout`, never a
hang.

The part 1 inventory, from the suite output: `test_sources` 7 tests,
4 over the snapshot adapter and 3 over watch mode, `test_fetch` 12,
the 6 real-socket proofs and the 6 monkeypatched taxonomy checks,
`test_models` 15, the accept table, the reject table, and the closed
vocabulary, `test_pipeline` 10, 5 end to end, 3 source-failure,
and 2 shutdown, and `test_profiled` 4, the profile-shape and bounded
peak checks of the section above. That is 48 of the suite's 78. The
boundaries are the
ones stated along the way: records leave at full precision as pydantic
objects with no aggregation yet, the only real network in the entire
capstone is one loopback listener in one suite, one event loop and a
worker thread per blocking call carry all the concurrency, and nothing
is persisted anywhere.

#diagram([what a naive ingest loop does and what part 1 does, side by side], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((4.0, 9.2), [the naive loop], wrap: text.with(size: 6.5pt, weight: 700))
  cdraw.content((15.0, 9.2), [part 1], wrap: text.with(size: 6.5pt, weight: 700))
  box(0.4, 7.4, 7.2, 1.2, [unbounded buffering, #linebreak() memory rides the input rate])
  box(8.8, 7.4, 7.2, 1.2, [a bad line raises, #linebreak() the loop dies mid-stream])
  box(0.4, 5.8, 7.2, 1.2, [a stuck source hangs, #linebreak() no budget anywhere])
  box(8.8, 5.8, 7.2, 1.2, [rejects logged by eyeball, #linebreak() if anyone looks])
  box(16.8, 7.4, 4.4, 1.2, [bounded queue, #linebreak() backpressure], fill: luma(205))
  box(16.8, 5.8, 4.4, 1.2, [dead letters, #linebreak() a closed vocabulary], fill: luma(205))
  box(16.8, 4.2, 4.4, 1.2, [join budget, #linebreak() PipelineTimeout], fill: luma(205))
  box(16.8, 2.6, 4.4, 1.2, [counts asserted, #linebreak() 11 and 3 by hand], fill: luma(205))
  cdraw.line((8.0, 8.0), (16.8, 8.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.0, 6.4), (16.8, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.4, 4.4), (16.8, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.4, 2.8), (16.8, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.6, 1.2), [each right-hand box is a test, and the tests are the difference], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "part 1 in the gate", [
  From `books/python/capstone`, the gate's own invocation under the
  book venv, `python -X utf8 -m unittest discover -s tests -t .`,
  reports 78 tests and OK. Part 1 owns 48 of them: `test_sources` 7,
  `test_fetch` 12, `test_models` 15, `test_pipeline` 10,
  `test_profiled` 4. The remaining
  30 belong to part 2, and that chapter quotes its own inventory. The
  fixture arithmetic is pinned by hand: 14 committed input lines split
  into 11 records and 3 dead letters across 4 sensors, and the
  real-socket suite binds, serves, and shuts down one loopback listener
  without the gate ever stalling on a firewall dialog.
])

sources: docs.python.org/3.14/library/asyncio-queue.html (the Queue
class, maxsize, put and get), docs.python.org/3.14/library/asyncio-
task.html (to\_thread for blocking calls), docs.python.org/3.14/library/
urllib.request.html (urlopen, HTTPError as a response-like exception,
URLError wrapping reasons), docs.python.org/3.14/library/http.server
(ThreadingHTTPServer), docs.python.org/3.14/library/json.html (the
NaN literal json.loads accepts), pydantic.dev/docs/validation/latest/
concepts/fields (Field constraints), pydantic.dev/docs/validation/
latest/errors/errors (ErrorDetails dictionaries with loc and type),
learn.microsoft.com/windows/security/operating-system-security/
network-security/windows-firewall/configure-with-command-line
(Set-NetFirewallProfile, NotifyOnListen), all accessed 2026-09-12.
The 78-test count, the 11-and-3 fixture split, and the loopback
firewall popup behavior probed on this machine the same day, the
profiled legs and their dated capture added 2026-09-13. Verified
by the capstone leg of `make verify-py`, 48 of 78 tests in this
chapter's modules.
