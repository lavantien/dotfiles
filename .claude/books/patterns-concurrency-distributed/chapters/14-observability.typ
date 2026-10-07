#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= observability

Monitoring tells you the system is down, observability lets you ask
why. The difference is structure: logs that carry attributes, metrics
that carry labels, traces that carry causality, all attached while
the code runs, never reconstructed after it fails. The go lane
reads its three signals off the stdlib, `log/slog` and `expvar` and
the raw material for spans, and the other six trees hand-roll the
same shapes in their own grain, so this chapter builds all three
twice over in testable form: a capture handler per language, a
labeled counter registry per language, a span tree per language,
all asserting the same fixtures.

== structured logging, the capture handler

Slog ships handlers for text and json and, more useful for this
book, an interface of four methods a test can implement. The other
lanes cut the same shape by hand: a level gate, an in-memory record
list, attributes as a map. The gate placement is the lesson that
survives translation, the check runs before the record exists, so a
dropped line never pays for its arguments.

The dry run: all seven lanes assert the same capture contract.

- info and warn recorded, 2 records, attrs readable as a map
- debug below min dropped before evaluation, the probe's side
  effect count stays 0
- the frozen go test pins the 2 records and the attr map, the probe
  literal is pinned by the 6 new trees

#listing("patterns-concurrency-distributed/samples-c/src/Ch14/capture.c", first: 74, last: 103, caption: [C, the emit path serializes one json line, the LOG macro is the gate the variadic signature buys elsewhere])

#listing("patterns-concurrency-distributed/samples/ch14/observe.go", first: 19, last: 58, caption: [Go, capture handler: records in memory, level filter, attrs as a map])

#listing("patterns-concurrency-distributed/samples-java/src/Ch14/Capture.java", first: 41, last: 75, caption: [Java, the message arrives as a Supplier, the gate runs before it, the emit path builds one json line])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch14/Capture.cs", first: 30, last: 66, caption: [C\#, the in-memory handler resolves ILogValue attributes the way built-ins unwrap LogValuer])

#listing("patterns-concurrency-distributed/samples-js/src/ch14-capture.mjs", first: 12, last: 53, caption: [JavaScript, attrs may be a function, evaluated only after the gate passes])

#listing("patterns-concurrency-distributed/samples-py/src/Ch14/capture.py", first: 31, last: 70, caption: [Python, the logger checks enabled before any attr value resolves, callables included])

#listing("patterns-concurrency-distributed/samples-lua/ch14_capture.lua", first: 29, last: 57, caption: [Lua, log takes a thunk, a dropped level never calls it])

`Capture` satisfies `slog.Handler`, the compile-time assertion
present as always, and every log line a test emits becomes an
assertable value: message, level, and attributes. The laziness idiom
is where the languages spend differently. Go gets it from the
variadic signature, `Enabled` is called early and the arguments of a
dropped line are never built. C has no variadic evaluation to lean
on, so the LOG macro is the gate, the only mechanism in the seven
that hides the evaluation behind a branch. C\# gives `Debug` a
`Func<Attr[]>` supplier that stays uncalled below the level, java
gates the whole message behind a `Supplier<String>`, the same trick
without the macro. Javascript and python accept attrs as a function
and call it only after the gate. Lua takes a whole thunk that
builds the message and
the attrs, so the dropped record is never constructed at all. This
same shape is how production code tests its logging, assertions on
what was said, not on log files.

#flow(
  [one record's path: enabled gates, handle resolves, attrs land as values],
  node((0, 0), [log call,#linebreak()attrs as args]),
  node((2.2, 0), [Enabled?]),
  node((2.2, -1.4), [dropped,#linebreak()args never evaluated]),
  node((4.4, 0), [Handle,#linebreak()Value.Resolve]),
  node((6.8, 0), [captured record,#linebreak()attrs as a map]),
  edge((0, 0), (2.2, 0), "-|>"),
  edge((2.2, 0), (2.2, -1.4), "-|>", label: [below min]),
  edge((2.2, 0), (4.4, 0), "-|>", label: [pass]),
  edge((4.4, 0), (6.8, 0), "-|>"),
)

Redaction rides on values that know how to sanitize themselves, one
wrapper type per language whose render is its length and never its
bytes.

The dry run: `Secret("hunter2token")` renders `secret(12 bytes)`,
`Secret("api-key-0123456789")` renders `secret(18 bytes)`, and the
raw token appears nowhere in the capture. The exact lengths are
pinned by the 6 new trees, the frozen go test asserts the
`secret(` prefix and the token's absence.

#listing("patterns-concurrency-distributed/samples-c/src/Ch14/capture.c", first: 68, last: 72, caption: [C, the render the serializer calls, length only])

#listing("patterns-concurrency-distributed/samples/ch14/observe.go", first: 62, last: 70, caption: [Go, a secret that logs its length, never its bytes])

#listing("patterns-concurrency-distributed/samples-java/src/Ch14/Capture.java", first: 34, last: 39, caption: [Java, the Attr record carries the secret flag, its render is the length, never the bytes])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch14/Capture.cs", first: 15, last: 26, caption: [C\#, ILogValue is the LogValuer analog, Secret implements it as a struct])

#listing("patterns-concurrency-distributed/samples-js/src/ch14-capture.mjs", first: 55, last: 65, caption: [JavaScript, toJSON is the hook, JSON.stringify resolves it at serialization time])

#listing("patterns-concurrency-distributed/samples-py/src/Ch14/capture.py", first: 23, last: 28, caption: [Python, log_value is the duck-typed hook the emit path probes for])

#listing("patterns-concurrency-distributed/samples-lua/ch14_capture.lua", first: 13, last: 27, caption: [Lua, the metatable identity is the tag, redact is the handler's obligation])

And the finding that makes the example worth keeping: the first
version of the go handler read `a.Value.Any()` in `Handle` and the
token leaked, because resolving `LogValuer` is the handler's job.
The built-in handlers call `Value.Resolve()`, and a custom handler
that skips it publishes raw secrets while appearing to respect the
pattern. Every lane carries the same obligation at the same spot:
C's serializer must call `secret_render`, C\#'s emit must check
`ILogValue`, java's emit must go through the attr's own `render`,
the one place the secret flag lives, javascript must go through
`JSON.stringify` for `toJSON` to fire, python must probe for
`log_value`, lua must run `redact` over the attrs. The fix is one
call on the emit path, and the tests now guard
it permanently.

== the counter registry, and the one-line mount

`expvar` publishes variables on the default HTTP mux at
`/debug/vars` with zero configuration, and `expvar.NewInt` is the
whole integration:

#listing("patterns-concurrency-distributed/samples/ch14/observe.go", first: 166, last: 166, caption: [Go, one line and the counter is on the wire])

One fragility of that one line is recorded, not fixed: `Published`
registers a fresh `expvar.Int` on every call, a second publish of
the same name panics, so a `go test -count 2` re-run of the chapter
dies in the expvar test and verify-go keeps `count=1`. Go is also
the only tree whose stdlib ships a metrics mount at all. The
siblings own the registry code below and would mount it behind
`node:http` in javascript, an `http.server` handler in python, the
jdk's own `com.sun.net.httpserver` in java, and nothing stdlib in
C, C\#, or lua, where the nearest BCL surface is
`System.Diagnostics.Metrics` with its `MeterListener`, a row for
prose, not for this book's samples.

For labeled counters beyond expvar's flat set, the registry pattern
is small enough to own:

The dry run: 20 writers x 100 incs, every 10th inc also errors.

- hits 2000, errors 200, exact under concurrency
- render is `"errors 200\nhits 2000\n"`, sorted by name, the exact
  string pinned by the 6 new trees while the frozen go test checks
  both lines
- the writers are real threads in C, C\#, go, and python, 20
  interleaved coroutines in lua, 20 async writers through the
  microtask queue in javascript, a cooperative round-robin in
  25-inc quanta on one thread in java, all asserting the same
  totals

#listing("patterns-concurrency-distributed/samples-c/src/Ch14/registry.c", first: 39, last: 78, caption: [C, counters by name behind one mutex, the render walks the sorted name array])

#listing("patterns-concurrency-distributed/samples/ch14/observe.go", first: 73, last: 116, caption: [Go, counters by name, snapshot under lock, sorted text render])

#listing("patterns-concurrency-distributed/samples-java/src/Ch14/Registry.java", first: 28, last: 49, caption: [Java, counters by name in a HashMap, every inc indivisible on the one thread, render sorts and joins])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch14/Registry.cs", first: 9, last: 44, caption: [C\#, counters by name under one lock, render sorts and joins])

#listing("patterns-concurrency-distributed/samples-js/src/ch14-registry.mjs", first: 6, last: 22, caption: [JavaScript, a Map of counters, render sorts the keys])

#listing("patterns-concurrency-distributed/samples-py/src/Ch14/registry.py", first: 17, last: 35, caption: [Python, a dict behind a lock, render joins the sorted lines])

#listing("patterns-concurrency-distributed/samples-lua/ch14_registry.lua", first: 30, last: 68, caption: [Lua, counters as tables in a map, one Inc is indivisible inside a resume])

The storage idiom splits three ways. C keeps a fixed array of
counters walked in name order, so sorted render is the walk order
and the registry never allocates. The map languages, go, java,
C\#, javascript, python, and lua alike, key counters by name and
sort at render time. The serialization boundary is where the
chapter's concurrency lesson cashes out: one mutex or lock around
the increment is all the exact totals need, chapter 7 earning its
keep again, and two lanes need no lock at all, lua because one
`Inc` runs inside a single scheduler resume, java because its 20
writers run as one cooperative round-robin and each `inc` is
indivisible on the single thread. The render format is deliberately
the
`name value` exposition style, so a dashboard swap from this
registry to a real metrics system is a formatting change, not an
architecture change.

#diagram([the registry under one lock, and the one-line stdlib mount beside it], length: 13pt, {
  cdraw.rect((0.4, 1.2), (13.0, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.7, 5.85), [Metrics], size: 6.5pt)
  cdraw.content((6.7, 4.75), [mu Mutex], size: 6pt)
  cdraw.content((6.7, 3.65), [counters map\[string\]\*int64], size: 6pt)
  cdraw.content((6.7, 2.55), [Inc and Snapshot under one lock], size: 6pt)
  cdraw.content((6.7, 1.45), [Render: sorted name value lines], size: 6pt)
  cdraw.rect((13.8, 1.2), (23.4, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((18.6, 5.85), [expvar.NewInt], size: 6.5pt)
  cdraw.content((18.6, 4.65), [one line registers the counter], size: 6pt)
  cdraw.content((18.6, 3.45), [served at /debug/vars], size: 6pt)
  cdraw.content((11.9, 0.35), [the render is exposition style, a dashboard swap is formatting, not architecture], size: 6pt)
})

== traces as context propagation

A trace is a tree of spans, and the tree grows through whatever
carries context in each language, `context.Context` in go being the
reference. `Start` reads the parent out of the context, appends the
new span as its child, and returns a context carrying the child, so
a function that receives `ctx` and calls `Start` lands in the right
place in the tree without knowing its caller. The clock is a
parameter, not `time.Now()`, so the test builds a tree with
hand-stamped timestamps, asserts the durations and the child order,
and never waits.

The dry run: hand-stamped stamps, no clock read anywhere.

- request 3ms, db 1ms, render 1ms, scan 1ms, durations exact
- child order follows creation, db then render then scan
- a span started from a bare context joins no tree
- the go lane's frozen test stamps its own tree with its own names,
  both walks verified against the same implementation

#listing("patterns-concurrency-distributed/samples-c/src/Ch14/traces.c", first: 41, last: 76, caption: [C, the parent is an explicit pointer parameter, the stamps are longs the caller hands in])

#listing("patterns-concurrency-distributed/samples/ch14/observe.go", first: 122, last: 158, caption: [Go, span in the context, children attach to their parent, durations from an injectable clock])

#listing("patterns-concurrency-distributed/samples-java/src/Ch14/Traces.java", first: 20, last: 55, caption: [Java, the parent a plain parameter, stamps handed in, an open span renders zero])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch14/Traces.cs", first: 9, last: 44, caption: [C\#, AsyncLocal carries the current span, Dispose pops it, Begin attaches to the parent])

#listing("patterns-concurrency-distributed/samples-js/src/ch14-traces.mjs", first: 7, last: 32, caption: [JavaScript, the parent reference is an explicit first parameter, said plainly])

#listing("patterns-concurrency-distributed/samples-py/src/Ch14/traces.py", first: 24, last: 51, caption: [Python, a ctx dict threads the parent through, start returns the child ctx])

#listing("patterns-concurrency-distributed/samples-lua/ch14_traces.lua", first: 20, last: 45, caption: [Lua, ctx is a table carrying span, Start attaches and returns a fresh ctx])

The context carrier is the idiom row. Go's `context.Value` is the
one the chapter's pipeline chapters already threaded, C\#'s
`AsyncLocal<Span>` flows with the async chain and needs no
parameter at all, and the other five are honest explicit threads: a
parent pointer in C, the parent as a plain parameter in java, the
first parameter in javascript, a ctx dict in python, a ctx table in
lua. The render contract is identical
everywhere, indented lines, deepest last, durations from the stamps
the caller supplied. The one-millisecond query in the walks is
deterministic, and the same property is what makes real span trees
testable: durations are values, chapter 9's synctest lesson in a
different costume.

#diagram([the span tree grows through the context, one child per start], length: 13pt, {
  let span(x, y, txt) = {
    cdraw.rect((x - 2.6, y - 0.6), (x + 2.6, y + 0.6), fill: luma(235), radius: 0.02)
    cdraw.content((x, y), txt, size: 6pt)
  }
  span(12.0, 5.4, [request, 3ms])
  span(5.5, 3.2, [db query, 1ms])
  span(18.5, 3.2, [render, 1ms])
  span(5.5, 1.0, [scan rows, 1ms])
  cdraw.line((12.0, 4.8), (5.5, 3.8), stroke: luma(100))
  cdraw.line((12.0, 4.8), (18.5, 3.8), stroke: luma(100))
  cdraw.line((5.5, 2.6), (5.5, 1.6), stroke: luma(100))
  cdraw.content((12.0, -0.6), [start reads the parent from ctx, appends the child, returns ctx carrying it], size: 6pt)
  cdraw.content((12.0, -1.8), [durations from the injected clock, never time.now in tests], size: 6pt)
})

#callout("note", "the three questions", [
  Logs answer "what happened here", metrics answer "how often and
  how much", traces answer "which path did this request take". A
  system with only one of the three answers is debugging by
  archaeology. The raft capstone wires all three: slog with a
  capture handler in tests, counters for terms and commits, and a
  span tree around election and replication rounds.
])

#diagram([three signals, three questions, each carrying its structure], length: 13pt, {
  cdraw.content((3.2, 7.0), [signal], size: 6.5pt)
  cdraw.content((10.9, 7.0), [its question], size: 6.5pt)
  cdraw.content((19.6, 7.0), [its structure], size: 6.5pt)
  let cols = ((0.4, 6.0), (6.4, 15.4), (15.8, 23.4))
  let rows = (
    ([logs], [what happened here], [attributes]),
    ([metrics], [how often, how much], [labels]),
    ([traces], [which path], [causality]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.2 - i * 1.5
    for (j, cell) in row.enumerate() {
      let c = cols.at(j)
      cdraw.rect((c.at(0), y), (c.at(1), y + 1.3), fill: luma(235), radius: 0.02)
      cdraw.content(((c.at(0) + c.at(1)) / 2, y + 0.65), cell, size: 6pt)
    }
  }
  cdraw.content((11.9, 0.5), [one signal alone means debugging by archaeology], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [336], [libc plus threads.h],
  [the registry under one mutex, the span parent an explicit pointer parameter],
  [go], [121], [stdlib],
  [a slog.Handler over capture, expvar's one-line mount, spans ride context.Value],
  [java], [239], [jdk 27 stdlib],
  [Supplier gates the message, hand-built json lines, the registry a one-thread round-robin],
  [c\#], [204], [bcl],
  [AsyncLocal carries the current span, secrets redact as ILogValue at emit time],
  [javascript], [78], [node stdlib],
  [lazy attrs as functions, secrets via toJSON, the parent the first parameter],
  [python], [209], [stdlib only],
  [a ctx dict threads the parent, the registry behind a lock, render through json],
  [lua], [296], [lib.lua harness],
  [string.format registry, coroutine lanes prove the totals, ctx a table],
)

sources: go.dev/pkg/log/slog for the Handler contract, `Enabled`
timing, `LogValuer`, and `Value.Resolve`, go.dev/pkg/expvar for
`NewInt` and the `/debug/vars` mount, go.dev/pkg/runtime/pprof for
the profiles available alongside, accessed 2026-09-08. Verified by
the seven chapter legs: 3 Ch14 C programs with 82 embedded checks,
`go test` at 5 tests in `patternsbook/ch14`, the java runner's 37
checks across 3 programs in `samples-java/src/Ch14`, 10 xunit
facts, node's 4 cases in `test/ch14.test.mjs`, 3 python modules
with 34 embedded checks, and the lua runner's 14 ch14 rows.
