#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= profiling and the event-loop tail

Chapter 9 asked where the bytes live. This chapter asks where the time
goes. Node ships two sampling profilers, a cpu profiler and an
allocation profiler, both writable from a flag and both readable as
plain json, and a histogram that measures the event loop's own
lateness. The chapter runs all of them on this machine, 2026-09-13,
node v26.3.0, parses what they wrote, and closes on the corpus row
kernel, ten million sqlite rows inserted, aggregated in SQL, and
walked by hand, with the commit tail read as percentiles. The
distinction that organizes everything: a profiler explains where
cpu or allocation went, a latency histogram explains when the loop
was late, and they answer different questions.

== the profile file, parsed

`node --cpu-prof` starts V8's sampling profiler at boot and writes a
`.cpuprofile` before exit. The file is json: a tree of `nodes`, each
carrying a `callFrame` with `functionName`, `url`, and line, plus a
`hitCount`, and two parallel arrays, `samples`, the node id sampled
at each tick, and `timeDeltas`, the microseconds between ticks. The
default sampling interval is 1000 us. Parsing it is ordinary file
work, so the suite does exactly that, against a child whose workload
lives in a named function, because an anonymous top-level loop
carries no frame name worth asserting on:

#listing("javascript/samples/src/ch10-busy.mjs", caption: [the child target, a named function the samplers can find])

#listing("javascript/samples/src/ch10-profiling.mjs", first: 27, last: 53, caption: [spawn the child, read the file, fold hits by frame name])

One measured run of that capture, on this machine: 41 nodes, one
`grind` frame, 22 of the run's 27 total hits on that frame, the
summed `timeDeltas` 52.27 ms. That is the whole attribution story in
one number, the profiler did not measure the program, it sampled it,
and 22 samples out of 27 landed inside one function because that
function held the thread.

#diagram([one profile, two views], length: 13pt, {
  cdraw.content((11.6, 8.6), [the same file read as a tree or as a timeline], size: 6.5pt, fill: luma(100))
  cdraw.content((5.8, 7.4), [the node tree], size: 6pt)
  cdraw.rect((0.4, 5.2), (11.2, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.3), [`callFrame`, a name, a url, a line], size: 6pt)
  cdraw.content((5.8, 5.4), [`hitCount`, samples that landed here], size: 6pt)
  cdraw.content((17.3, 7.4), [the sample log], size: 6pt)
  cdraw.rect((11.8, 5.2), (22.8, 6.9), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 6.3), [`samples`, node ids over time], size: 6pt)
  cdraw.content((17.3, 5.4), [`timeDeltas`, the gaps between them], size: 6pt)
  cdraw.content((11.6, 4.2), [measured: 41 nodes, 27 hits, 22 on `grind`, 52.27 ms of deltas], size: 6pt)
})

== the heap profile, sampled

`--heap-prof` writes a `.heapprof` file, and it is a different
instrument: a sampling allocation profiler. It records one tree of
call frames where every node carries a `selfSize`, the bytes
allocated by that frame that were still live when the profile was
taken, and a `samples` array of `{size, nodeId, ordinal}` records.
The default sampling interval is 512 KiB, one recorded allocation
per half megabyte allocated, and it can be lowered for finer
attribution. Measured on this machine at a 16 KiB interval against
the same busy child: 42 samples, 514224 total sampled bytes, and the
top frames are the runtime's own bootstrap, `createContext` at
230400 bytes and `compileForInternalLoader` at 115512, with `(IDLE)`
at 69104. The honest reading: a sampling heap profile attributes by
allocation site, and on a short-lived child the startup dominates
the retained set, so the workload's own allocations have to outlive
or outweigh bootstrap to rise to the top. For a leak hunt the
comparison of two captures, same code path run twice, is the signal,
not one capture's absolute numbers.

#listing("javascript/samples/src/ch10-profiling.mjs", first: 54, last: 76, caption: [the heap capture, parsed, self sizes summed over the frame tree])

#diagram([one capture against two, the delta as the signal], length: 13pt, {
  cdraw.content((5.5, 8.4), [one capture, absolute], size: 6.5pt, fill: luma(100))
  cdraw.content((17.5, 8.4), [two captures, the delta], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.9), (10.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 7.45), [42 samples at a 16 KiB interval, #linebreak() 514224 total sampled bytes], size: 6pt)
  cdraw.rect((12.4, 6.9), (22.6, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 7.45), [the same code path, run twice, #linebreak() the comparison is the signal], size: 6pt)
  cdraw.rect((0.4, 5.1), (10.6, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 5.8), [the top frames are bootstrap: `createContext` #linebreak() 230400 bytes, `compileForInternalLoader` 115512, #linebreak() `(IDLE)` 69104], size: 6pt)
  cdraw.rect((12.4, 5.1), (22.6, 6.5), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.8), [the workload's own allocations, #linebreak() outliving or outweighing bootstrap], size: 6pt)
  cdraw.rect((0.4, 3.3), (22.8, 4.5), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 3.9), [a sampling allocation profiler: every node's `selfSize`, bytes still live #linebreak() when the profile was taken, `samples` as `{size, nodeId, ordinal}` records], size: 6pt)
  cdraw.content((11.6, 2.3), [the default interval 512 KiB, one recorded allocation per half megabyte, lowerable], size: 6.5pt)
  cdraw.content((11.6, 1.3), [on a short-lived child, startup dominates the retained set], size: 6.5pt)
})

== the inspector, from inside the process

The flags write files at exit. The inspector writes the same
profiles from inside a running process: `node:inspector` exposes a
`Session` connected to the V8 back-end on the same thread, `post`
sends a Chrome DevTools Protocol method, and the `Profiler` domain
does enable, set sampling interval, start, stop. The session is
callback shaped, so the sample wraps `post` in a promise and awaits
the stops:

#listing("javascript/samples/src/ch10-profiling.mjs", first: 78, last: 105, caption: [the in-process session, the frame name stated because a closure samples anonymously])

#diagram([the session, a pipeline from connect to the awaited stop], length: 13pt, {
  cdraw.content((11.6, 9.4), [the same profiles, from inside the running process], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 7.2), (6.4, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.4, 7.9), [a `Session`, connected to the v8 #linebreak() back end on the same thread], size: 6pt)
  cdraw.line((6.4, 7.9), (7.4, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.4, 7.2), (15.0, 8.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.2, 7.9), [promisified `post`, the `Profiler` domain: #linebreak() enable, interval, start, stop], size: 6pt)
  cdraw.line((15.0, 7.9), (16.0, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.0, 7.2), (22.8, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((19.4, 7.9), [the window the program chooses, #linebreak() one request or one batch], size: 6pt)
  cdraw.rect((0.4, 5.4), (22.8, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 6.0), [measured at a 100 us interval: the 5e6 sqrt loop, 7 nodes, #linebreak() 68 samples with 68 `timeDeltas`, 65 hits on the named `grind` frame], size: 6pt)
  cdraw.content((11.6, 4.6), [what the flags cannot do: a chosen window, and no child process at all], size: 6pt)
  cdraw.rect((0.4, 2.8), (22.8, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 3.4), [the flags write files at exit, the session writes from inside the running process, #linebreak() the same channel carries `HeapProfiler.takeHeapSnapshot`, streamed in chunks], size: 6pt)
  cdraw.content((11.6, 1.8), [the session is callback shaped, `post` wrapped in a promise, the stops awaited], size: 6.5pt)
})

Measured on this machine at a 100 us interval: the 5e6 sqrt loop
produced 7 nodes and 68 samples with 68 `timeDeltas`, 65 of the hits
on the named `grind` frame. The in-process session costs a little
setup and buys two things the flags cannot do: a profile of a window
the program chooses, started and stopped around one request or one
batch, and no child process at all. The same channel carries
`HeapProfiler.takeHeapSnapshot`, streamed out in chunks, for the
full snapshot graphs the devtools draw.

== the loop, and where delay is born

Between timers and the next turn sits the loop itself, and node
runs it through libuv in phases: timers, pending callbacks, idle and
prepare, poll, check, and close callbacks, one turn through all of
them per iteration. Since libuv 1.45, the version node 20 raised the
floor to, timers run after the poll phase of the same iteration. The
poll phase is where the loop waits for io, and it is also where
delay is born: a timer is a threshold, not an appointment, the
guide's own example is a 100 ms timer made to fire at 105 ms because
a file callback held the thread for 10 ms past the poll wait. When
the poll queue is empty and immediates are scheduled the loop leaves
poll for the check phase, otherwise it blocks for more io.

`monitorEventLoopDelay` from `node:perf_hooks` measures exactly
that lateness. A timer of the stated resolution fires every tick,
and each sample is how late it ran, in nanoseconds, so the histogram
is the loop's own tail. The sample alternates roughly one
millisecond of busy work with a `setImmediate` yield:

#listing("javascript/samples/src/ch10-profiling.mjs", first: 107, last: 127, caption: [the histogram run over a busy and yield pattern])

Measured over a 0.4 s window with 1 ms resolution on this machine:
400 samples, p50 1.07 ms, p99 1.26 ms, mean 1.00 ms, max 1.46 ms.
The mean matches the busy budget, the p50 sits just above it, and
the p99 is where a gc pause or an os scheduling hiccup landed. On an
idle loop the same histogram reads near zero, the loop is never late
when nothing holds it.

#diagram([the loop's phases, one turn], length: 13pt, {
  cdraw.content((11.6, 8.6), [where a callback runs decides when it runs], size: 6.5pt, fill: luma(100))
  let phase(x, y, w, label, note, dark) = {
    cdraw.rect((x, y), (x + w, y + 1.6), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w / 2, y + 1.1), label, size: 6pt)
    cdraw.content((x + w / 2, y + 0.45), note, size: 6pt)
  }
  phase(0.4, 6.0, 3.4, [timers], [`setTimeout`, `setInterval`], false)
  phase(4.2, 6.0, 3.4, [pending], [deferred io errors], true)
  phase(8.0, 6.0, 3.4, [idle, prepare], [internal], false)
  phase(11.8, 6.0, 4.6, [poll], [io, and the wait], true)
  phase(16.8, 6.0, 3.4, [check], [`setImmediate`], false)
  phase(20.6, 6.0, 2.2, [close], [`'close'`], true)
  cdraw.line((0.4, 5.6), (22.8, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 4.8), [one turn, then the next: timers run after poll since libuv 1.45], size: 6pt)
  cdraw.content((11.6, 3.6), [delay is born in poll: a long callback pushes every timer back], size: 6pt)
})

== percentiles for a handler loop

Averages hide the tail, so this book reads latency as percentiles,
nearest rank: sort the samples, take the value at the ceiling of the
quantile times the count. The sample runs an async handler loop,
one thousand chunks, each chunk an awaited `setImmediate` turn plus
a bounded piece of work, and records the per-chunk latency:

#listing("javascript/samples/src/ch10-profiling.mjs", first: 13, last: 18, caption: [nearest rank, the one percentile rule this book quotes])

#listing("javascript/samples/src/ch10-profiling.mjs", first: 129, last: 149, caption: [the handler loop, one latency per chunk over a thousand chunks])

#diagram([the sorted thousand, read by rank], length: 13pt, {
  cdraw.content((11.6, 9.2), [averages hide the tail, the samples read by rank], size: 6.5pt, fill: luma(100))
  cdraw.content((11.6, 8.1), [one thousand chunks, each an awaited `setImmediate` turn plus a bounded piece of work], size: 6pt)
  cdraw.line((1.0, 6.6), (22.4, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.0, 6.1), [the thousand latencies, sorted], size: 6pt)
  for x in (4.0, 9.5, 14.0, 18.5, 22.2) { cdraw.line((x, 6.4), (x, 6.8), stroke: luma(100)) }
  cdraw.content((4.0, 7.3), [p50 0.01 ms], size: 6pt)
  cdraw.content((9.5, 7.3), [p95 0.04 ms], size: 6pt)
  cdraw.content((14.0, 7.3), [p99 0.08 ms], size: 6pt)
  cdraw.content((18.5, 7.3), [p99.9 0.25 ms], size: 6pt)
  cdraw.content((22.2, 7.3), [max 0.25], size: 6pt)
  cdraw.rect((0.4, 4.2), (22.8, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 4.8), [nearest rank: sort the samples, take the value at the ceiling #linebreak() of the quantile times the count], size: 6pt)
  cdraw.rect((0.4, 2.7), (22.8, 3.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 3.25), [the suite asserts the shape, count, ordering, and finiteness, #linebreak() never the absolute numbers, latency belongs to the machine and the moment], size: 6pt)
  cdraw.content((11.6, 1.9), [`AsyncLocalStorage`: `req-7` before the await, `req-7` after it, `undefined` at the edge], size: 6pt)
  cdraw.content((11.6, 1.0), [context flows with the async chain and stops at its edge], size: 6.5pt)
})

Measured on this machine: p50 0.01 ms, p95 0.04 ms, p99 0.08 ms,
p99.9 0.25 ms, max 0.25 ms. The suite asserts the shape, count,
ordering, and finiteness, never the absolute numbers, because
latency is a property of the machine and the moment. The same turn
structure carries request attribution: `AsyncLocalStorage` from
`node:async_hooks` gives every callback a store without threading a
parameter, and the store survives `await`:

#listing("javascript/samples/src/ch10-profiling.mjs", first: 151, last: 164, caption: [one request id, readable across awaits, absent at the boundary])

The measured trace is `req-7` before the await, `req-7` after it,
and `undefined` once the run's scope ends, which is the whole
contract: context flows with the async chain and stops at its edge.
The lower-level `async_hooks` module underneath it, with its
init, before, after, and destroy callbacks, can build the same thing
by hand, at the cost of a callback per promise job, and the chapter
uses the storage abstraction because the callback form is the
instrument you reach for only when the storage is not enough.

== the row kernel at ten million rows

The corpus-wide row kernel gives the database side of the
measurement: one table, `station TEXT NOT NULL` plus eight `REAL`
columns, 412 stations `st000` through `st411`, seeded values, 10k
rows per transaction through one prepared statement, then the same
aggregation twice, SQL `GROUP BY` against a manual cursor walk. The
engine is node's own `node:sqlite`, measured at exactly 3.53.1 on
node 26.3.0, asserted as a string by the suite the way the capstone
pins it.

#listing("javascript/samples/src/ch10-rows.mjs", first: 38, last: 70, caption: [the seeded insert, one prepared statement, the commit timed per 10k chunk])

#listing("javascript/samples/src/ch10-rows.mjs", first: 85, last: 109, caption: [the manual walk, per station accumulators behind one cursor])

Measured on this machine, 2026-09-13, through the opt-in
`samples/bench/rows.mjs`: the insert of ten million rows took
18.85 s, 530.42k rows per second, in one thousand transactions, and
the db file weighed 829.77 MB. The commit tail over those thousand
chunks: p50 11.595 ms, p95 13.628 ms, p99 17.914 ms, p99.9
111.236 ms, max 111.236 ms, the tail being where sqlite flushed a
full transaction's pages at once. The aggregation passes: SQL
`GROUP BY` in 11.75 s, 851k rows per second, the manual cursor walk
in 17.78 s, 562.3k rows per second, SQL ahead by a third on this
workload because the engine aggregates inside its own scan while
the walk pays for a javascript object per row. Both passes agree
exactly on min and max and to a float epsilon on the average, and
the suite checks that agreement at 1k rows in memory, under the one
second kit budget.

The one-off above this scale was run once, alone, and deleted
after: one hundred million rows, a 8330.77 MB db file, insert
197.05 s at 507.5k rows per second, commit tail p50 11.831 ms, p99
21.665 ms, p99.9 107.442 ms over ten thousand chunks, the manual
walk 197.83 s at 505.47k rows per second, and the SQL pass 334.56 s
at 298.9k rows per second, slower than at ten million by more than
the row count explains: an 8.3 GB table does not fit this machine's
free memory, so the scan rate is a property of what the os cached,
and an earlier run of the same kernel with a warmer cache measured
the same pass in 134.82 s. One billion rows is arithmetic only, on
the order of 85 GB at this row shape, not measured on this machine.

#diagram([the commit tail of the ten million row insert], length: 13pt, {
  cdraw.content((11.6, 8.6), [one thousand 10k-row transactions, percentiles of the commit], size: 6.5pt, fill: luma(100))
  let bar(y, label, w, cap) = {
    cdraw.rect((6.6, y), (6.6 + w, y + 1.1), fill: luma(205), radius: 0.02)
    cdraw.content((3.4, y + 0.55), label, size: 6pt)
    cdraw.content((6.6 + w / 2, y + 0.55), cap, size: 6pt)
  }
  bar(6.8, [p50], 2.0, [11.6 ms])
  bar(5.1, [p95], 2.4, [13.6 ms])
  bar(3.4, [p99], 3.2, [17.9 ms])
  bar(1.7, [p99.9], 13.0, [111.2 ms])
  cdraw.content((11.6, 0.2), [the p99.9 tail is sqlite flushing a full transaction's pages at once], size: 6pt)
})

=== the same kernel on duckdb

The corpus also ran this kernel on duckdb, from c and from go, and
those two chapters hold the engine-side numbers. The c twin, same 412
stations and rows bit-identical to its sqlite lane, measured the
appender at 1.05 to 1.12 million rows a second against sqlite's
batched 464,047, the group by at 79.6 to 83.3 million against
555,402, 143x to 150x, and the same rows stored in 449.8 to 450.8 MB
against this chapter's 829.77, while the go lane appended 774,437
rows a second with its group by at 124,918,491 over the engine's own
thread pool, all 2026-09-20 on duckdb 1.5.5. `node:sqlite` stays
right for this book's kernel anyway: the tail read here is a commit,
the p99 of one 10k-row transaction, and the capstone's snapshots are
one transaction each, lanes the appender does not offer because it
opens no transaction and hands the batch boundary to the engine.
Which engine a workload wants is measured in
#xref-to("infrastructure", "duckdb") and chosen in
#xref-to("infrastructure", "duckdb-sqlite").

== which tool when

Each instrument answers one question, and the cheapest one that
answers it wins. For "which function is hot", `--cpu-prof` on a
child, no code changes, sampled attribution. For "which call path
allocates", `--heap-prof`, read as a delta between two captures. For
"this one batch, right now", the inspector session, started and
stopped around the window. For "is the loop late", the histogram,
and for "which request did this", the storage. For the store
itself, timings and the aggregation comparison above. The row
kernel's own numbers land in each tool's terms: the insert rate is
throughput, the commit tail is latency, and the two aggregation
passes are an algorithm choice measured, not argued.

#diagram([one symptom, one instrument], length: 13pt, {
  cdraw.content((6.2, 8.6), [the question], size: 6.5pt, fill: luma(100))
  cdraw.content((17.0, 8.6), [the instrument], size: 6.5pt, fill: luma(100))
  let row(y, q, i, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((6.2, y + 0.7), q, size: 6pt)
    cdraw.content((17.0, y + 0.7), i, size: 6pt)
  }
  row(6.6, [which function holds the thread], [`--cpu-prof`, parsed by name], false)
  row(4.9, [which path allocates], [`--heap-prof`, two captures diffed], true)
  row(3.2, [this one batch, in process], [the inspector session], false)
  row(1.5, [is the loop late, how late], [`monitorEventLoopDelay`], true)
  row(-0.2, [which request did this], [`AsyncLocalStorage`], false)
})

sources: nodejs.org inspector, perf_hooks, async_hooks, and cli
profiling options pages, the nodejs.org event loop timers and
nexttick guide, and the nodejs.org sqlite page, accessed 2026-09-13.
Behavior verified live with node v26.3.0 on windows: 133 tests green
through `npm run verify` in `javascript/samples`, 8 of them this
chapter's, three consecutive clean runs, and every quoted number
above is from a child, session, histogram, or bench run executed on
this machine, the opt-in benches under `samples/bench` never run by
`make verify`.

== across the six books

The same two kernels ran in all six language books under one
contract, N particles of 8 float64 fields stepped 16 times and 10
million readings rows of one station key plus 8 real columns, every
number below quoted from the chapter that measured it on this
machine, 2026-09-13. The first two columns are the particle step at
1m in each language's row-of-objects repr and its flat column repr,
and they disagree on purpose: the flat repr wins 1.4x in c, 2.6x in
javascript, and 21x in python, the object repr wins 2.3x in c\# and
3.8x in go because the step touches all eight fields of every
particle and one cache line per particle beats eight streams in
flight, and lua's ffi cdata wins 11.5x over boxed tables. The last
four columns are the shared sqlite contract at 10m rows, insert
through 10k-row batched transactions, the sql group by, the manual
cursor walk, and the p99 of one 10k-row commit. Lua's p99 cell sits
empty on purpose: its os.clock ticks at 1 ms and the chapter refuses
to quote a percentile it cannot read, the boundary every book states
in its own clock.

#figure(
  table(
    columns: (auto, auto, auto, auto, auto, auto, auto),
    inset: 4pt,
    align: (auto, right, right, right, right, right, right),
    table.header([*book*], [*objects ns*], [*flat ns*], [*insert/s*], [*group/s*], [*walk/s*], [*p99 ms*]),
    [c, clang -O2], [6.15 to 6.75], [4.53 to 4.91], [468,803], [584,696], [2,242,885], [28.3],
    [c\#, .net 11], [5.7], [13.1], [339,091], [723,248], [501,820], [48.5],
    [go 1.27], [8.2], [30.9], [267,942], [324,614], [610,720], [67.957],
    [javascript, node 26], [12.4], [4.72], [530.42k], [851k], [562.3k], [17.914],
    [python 3.14], [345.7], [16.18], [327,703], [536,378], [307,199], [39.60],
    [lua 5.5 + luajit], [114.1], [9.9], [504,765], [573,915], [580,353], [],
  ),
  caption: [the two kernels across the six language books: particle step ns at 1m in each book's object and flat repr, then the 10m row kernel with insert, group by, and walk in rows per second and p99 in milliseconds per 10k-row commit, every cell quoted from the chapter that measured it],
)

The ladder above the table stays in its own book: the 100m particle
one-off measured 5.768 ns flat and 7.229 ns object in c, 21.815 ns
flat in c\# (memory bound, soa only), 8.898 ns flat in go, 4.63 ns
flat in javascript, 16.88 ns flat in python, and 8.2 ns ffi in lua,
with the boxed 100m priced at 13.9 GB and refused. The 100m row
one-off held its 10m insert rate within 5 percent in c, javascript,
and lua, gained 4 percent in python, and paid 8 percent in go and 21
percent in c\#. One billion is arithmetic in every book, 64 GB of
particle state and roughly 81 to 87 GB of rows, not measured on this
machine.
