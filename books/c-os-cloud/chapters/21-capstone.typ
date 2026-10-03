#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow

= capstone: particle kernel and row cruncher

The capstone runs the two workloads this book spent twenty chapters
building tools for: a million particles stepped behind the chapter 19
allocators, and ten million database rows through each corpus engine,
sqlite 3.53.4 and duckdb 1.5.5, both dlls loaded at runtime. The gate
run stays a smoke, 10 thousand particles and 1236 rows per engine with
every checksum asserted, and the measured ladder is opt-in through
`argv`, quoted here from real runs dated 2026-09-13, 2026-09-14, and
2026-09-20. The one-offs at 100 million ran alone, sequential, and
were deleted after. Nothing in this chapter is extrapolated except the
billion-row arithmetic, which says so out loud.

== the kernel behind three allocators

One particle is 8 `double` fields, position, velocity, mass, and
charge, and one step is pure arithmetic: charge pushes velocity in a
constant field, mass weighs the pull, drag slows everything, position
advances. The same seed fills both layouts, so the array-of-structs and
struct-of-arrays kernels carry identical values, and after 16 steps the
two checksums still match to the last bit. That equality is the
capstone's spine, asserted at every scale including 100 million, where
both layouts print checksum 15067410024.160217.

#listing("c-os-cloud/samples/src/Ch21/kernel.c", first: 17, last: 43, caption: [the step kernel twice: one struct of 8 doubles per particle, or 8 arrays of one double each])

The setup question is chapter 19's, asked at scale: what does it cost
to put a million 64-byte particles behind each allocator? Bump is not
slower per particle at a million than at a thousand, because it is one
carve, O(1) in the particle count, and prints 0.00 ns per particle,
under half a millisecond total. The freelist carve pays a header write
and a payload touch per particle, sequential and prefetch friendly,
13.3 to 14.3 ns per particle at 1 million. The slab pays a pointer
chase, its free list is threaded through slots the allocator has not
warmed, 22.9 to 26.9 ns per particle, and at 100 million the gap
narrows to 19.3 to 33.3 for both as the last cache levels stop
absorbing the streams.

#listing("c-os-cloud/samples/src/Ch21/kernel.c", first: 96, last: 125, caption: [the same million particles allocated behind bump, slab, and the chapter 14 freelist])

#diagram([setup cost per particle behind the three chapter 19 allocators, measured at 1m], length: 13pt, {
  let bar(y, w, t, note) = {
    cdraw.rect((6.6, y), (6.6 + w, y + 0.85), fill: luma(205), radius: 0.02)
    cdraw.content((6.85 + w, y + 0.42), t, wrap: text.with(size: 6pt), anchor: "west")
    cdraw.content((6.6, y + 0.42), note, wrap: text.with(size: 6pt, fill: luma(100)), anchor: "east")
  }
  bar(6.8, 0.2, [~0 ns, one carve, O(1) in N], [bump])
  bar(5.3, 5.4, [13.3 to 14.3 ns, header plus touch], [freelist])
  bar(3.8, 9.6, [22.9 to 26.9 ns, the pointer chase], [slab])
  cdraw.content((11.5, 2.5), [measured 2026-09-13 and 2026-09-14 on this machine, min of 3, printed never checked], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.5, 1.6), [at 100m: freelist 19.3 to 25.6, slab 31.3 to 33.3 ns, the caches stop absorbing], wrap: text.with(size: 6pt))
})

== array of structs against struct of arrays, measured

Chapter 13 predicted the layout difference as a cache decision and
measured near parity on its 4-field particles. The capstone's 8-field
particle sharpens the question, and the answer depends entirely on the
optimization level, which is itself the finding. Under the gate's `-O0`
build the two layouts land within noise of each other, aos 8.05 to
8.49 and soa 7.24 to 7.43 ns per particle per step, 1.07x to 1.14x,
because the interpreter-shaped inner loop dominates both. At `-O2` the
same source separates: aos 6.15 to 6.75, soa 4.53 to 4.91,
1.35x to 1.38x, the soa kernel's six streaming arrays against the aos
kernel's stride-64 walk through all eight fields. The numbers are
quoted per optimization level because a layout claim that does not name
its `-O` level is not a claim.

#listing("c-os-cloud/samples/src/Ch21/kernel.c", first: 191, last: 220, caption: [both layouts from one seed, and the bitwise agreement asserted before and after 16 steps])

#diagram([the same kernel at two optimization levels: the layout gap is born in the optimizer], length: 13pt, {
  let col(x, label, y0, h, t) = {
    cdraw.rect((x, y0), (x + 3.0, y0 + h), fill: luma(205), radius: 0.02)
    cdraw.content((x + 1.5, y0 - 0.45), label, wrap: text.with(size: 6pt))
    cdraw.content((x + 4.0, y0 + h / 2), t, wrap: text.with(size: 6pt), anchor: "west")
  }
  col(2.0, [aos -O0], 3.0, 4.4, [8.05 to 8.49 ns])
  col(7.0, [soa -O0], 3.0, 3.9, [7.24 to 7.43, 1.07x to 1.14x])
  col(13.0, [aos -O2], 3.0, 3.3, [6.15 to 6.75 ns])
  col(18.0, [soa -O2], 3.0, 2.5, [4.53 to 4.91, 1.35x to 1.38x])
  cdraw.content((11.5, 1.4), [ns per particle per step at 1m, checksums bitwise equal at every bar], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the row cruncher

The second workload is the corpus's own database engine, loaded the way
the machine facts prescribe: `LoadLibraryA("sqlite3.dll")` from beside
the exe, every function pointer typedefed and resolved with a direct
cast, and the first check pins the version, 3.53.4, the same dll the
lua book's ffi chapter links. The gate stages the dll into the run
directory exactly the way its asan leg stages the sanitizer runtime,
and the gate's preflight names the missing piece and its build command
when a worktree lacks it.

#listing("c-os-cloud/samples/src/Ch21/rowcrunch.c", first: 48, last: 69, caption: [the load: one dll, thirteen function pointers, direct single casts])

The ingestion is the workload kit's contract: 412 stations, 8 `REAL`
columns, prepared inserts bound per row, 10k-row transactions. One
sentence of the bind contract is load-bearing enough to quote from the
vendored header: `SQLITE_TRANSIENT` "may be passed to indicate that the
object is to be copied prior to the return from" the bind call, and
a null destructor instead means the pointer "must remain valid until
either the prepared statement is finalized or the same SQL parameter is
bound to something else". This sample learned that the hard way, a
stack buffer bound as static read after the stack frame died, all 1236
rows collapsing into one garbage station, and the fix is the
`(void *)-1` transient sentinel in the listing.

#listing("c-os-cloud/samples/src/Ch21/rowcrunch.c", first: 75, last: 83, caption: [the bind: a stack buffer must be copied, the transient sentinel says so])

The aggregation runs twice over identical rows: one `GROUP BY` carrying
min, max, and avg for all 8 columns, and a manual cursor walk with
per-station accumulators, the shape of the one billion rows challenge. The
smoke asserts they agree,
station set, min and max bitwise on all 8 columns, averages inside
float addition-order effects.

#listing("c-os-cloud/samples/src/Ch21/rowcrunch.c", first: 120, last: 127, caption: [aggregation (a): 24 aggregates over one group by])

#diagram([the cruncher: one dll, prepared inserts in 10k batches, two aggregations over the same rows], length: 13pt, {
  let box(x, w, y, t, f) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: f, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, wrap: text.with(size: 6pt))
  }
  box(0.8, 3.2, 6.6, [LoadLibraryA], luma(235))
  box(4.6, 3.2, 6.6, [prepare insert], luma(235))
  box(8.4, 4.4, 6.6, [bind + step, 10k per BEGIN...COMMIT], luma(205))
  box(13.4, 3.6, 6.6, [readings], luma(238))
  box(17.6, 3.4, 5.0, [GROUP BY x24], luma(235))
  box(17.6, 3.4, 3.7, [manual walk], luma(235))
  cdraw.line((4.0, 7.05), (4.6, 7.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.8, 7.05), (8.4, 7.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.8, 7.05), (13.4, 7.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.2, 6.6), (17.6, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.2, 6.9), (17.6, 4.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.5, 2.6), [the smoke asserts both walks agree: stations, bitwise min and max, avg within float order], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.5, 1.7), [412 stations, 8 REAL columns, splitmix64-seeded values, one dll, version pinned 3.53.4], wrap: text.with(size: 6pt))
})

== chunked ingestion and the p99 of a commit

Throughput is an average, and a commit is not an average, so every
10k-row transaction lands its whole latency in the chapter 20 harness.
At 10 million rows, 1000 chunks, the insertion sustains 468,803 rows
per second and the commit distribution prints p50 21.4 ms, p95 24.1
ms, p99 28.3 ms, p99.9 105.4 ms, max 127.2 ms: the median chunk is
tight, but one commit in a thousand waits four to five medians, and the
max waits six, the file system flushing behind the log. At 100 million
rows the shape holds, p50 21.5, p95 24.8, p99 29.8, p99.9 129.4, max
158.2 ms over 8192 chunks, the tail thinning by count but never
disappearing. A service quoting only its 469k rows per second is
quoting the p50 and hiding the p99.9.

#listing("c-os-cloud/samples/src/Ch21/rowcrunch.c", first: 89, last: 111, caption: [ingestion: batched transactions, every chunk latency pushed into the harness])

The aggregation split is the other honest number. At 10 million rows
the group by sustains 584,696 rows per second and the manual walk
2,242,885, 3.84x; at 100 million the walk holds 2,269,078 while the
group by drops to 454,377, 4.99x, the sort spilling at a scale the
linear scan never feels.

#diagram([the commit tail at 10m and 100m rows: medians tight, one in a thousand wide], length: 13pt, {
  let bar(y, w, t) = {
    cdraw.rect((4.4, y), (4.4 + w, y + 0.8), fill: luma(205), radius: 0.02)
    cdraw.content((4.65 + w, y + 0.4), t, wrap: text.with(size: 6pt), anchor: "west")
  }
  cdraw.content((4.2, 8.2), [10m], wrap: text.with(size: 6pt), anchor: "east")
  bar(7.9, 2.4, [p50 21.4])
  bar(6.9, 2.7, [p95 24.1])
  bar(5.9, 3.2, [p99 28.3])
  bar(4.9, 8.4, [p99.9 105.4])
  bar(3.9, 9.8, [max 127.2 ms])
  cdraw.content((4.2, 2.9), [100m], wrap: text.with(size: 6pt), anchor: "east")
  bar(2.6, 2.4, [p50 21.5])
  bar(1.6, 8.9, [p99.9 129.4])
  cdraw.content((11.5, 0.6), [ms per 10k-row commit, 1000 and 8192 chunks, measured 2026-09-13 and 2026-09-14], wrap: text.with(size: 6pt, fill: luma(100)))
})

== the duckdb twin, measured

The row cruncher has a twin, the same workload pointed at a columnar
engine. Same contract, 412 stations and 8 value columns, the identical
splitmix64 row stream, the same two aggregations over identical rows
asserted to agree, and the same load discipline,
`LoadLibraryA("duckdb.dll")` from beside the exe, every function
pointer typedefed and resolved by a direct cast, the version pinned
first, v1.5.5. Two details of the contract differ and both bite.
Duckdb's `REAL` is 4 bytes where sqlite's is 8, so the twin's table
stores `DOUBLE` or the rows stop being bit-identical to the sqlite
cruncher's, min and max included. And where sqlite needed only two
opaque pointers, duckdb's types cross the boundary by value,
`duckdb_result` is a 48-byte struct the engine fills through
`duckdb_query`, so the twin includes the engine's own `duckdb.h` and
never hand-rolls a layout.

#listing("c-os-cloud/samples/src/Ch21/rowcrunch_duckdb.c", first: 67, last: 93, caption: [the load: same discipline, one new rule, the handles close by pointer])

The teardown rule is the one that costs an hour: `duckdb_close` and
`duckdb_disconnect` take `duckdb_database *` and `duckdb_connection *`,
the slot is nulled on the way out, and a handle passed by value
corrupts the heap on release. The read side has its own trap, found by
probing this exact dll: the chunk pair older docs carry,
`duckdb_result_chunk_count` plus `duckdb_result_get_chunk`, is
deprecated in 1.5.5 and hands back chunks whose doubles read as
garbage. The live columnar api is `duckdb_fetch_chunk`, pulled until
it returns null.

#listing("c-os-cloud/samples/src/Ch21/rowcrunch_duckdb.c", first: 152, last: 172, caption: [ingestion without statements: the appender buffers whole chunks, end_row closes a row])

Ingestion drops the statement machinery. Nothing to prepare, no bind
contract to get wrong: `duckdb_append_varchar` copies the station name
on the spot, eight `duckdb_append_double` calls stack the values,
`duckdb_appender_end_row` closes the row, and the appender buffers
2048-row chunks internally, flushing whole vectors. The sample never
opens a transaction, so the bench has no commit boundary to push into
the chapter 20 harness and prints no percentiles. The wal still lands,
and `duckdb_close` checkpoints it into the file, which is why the
bench reads the db size after close.

#listing("c-os-cloud/samples/src/Ch21/rowcrunch_duckdb.c", first: 189, last: 215, caption: [aggregation (a) read back columnar: one vector per column, 2048 rows per chunk, nullness a bitset])

The read side is the columnar lesson. A chunk is not a row set, it is
one vector per column with 2048 rows contiguous in memory, doubles
straight out of `duckdb_vector_get_data`, station names as
`duckdb_string_t`, 12 bytes inline for the 5-char names. Nullness
lives in a separate bitset, 64 rows per `uint64_t` word from
`duckdb_vector_get_validity`, a set bit meaning valid and a null
pointer meaning all valid, the walk checks it before it trusts any
slot. The group by returns 25 vectors, the walk's chunks carry 9.

#diagram([the twin at 10 million rows, both lanes run back to back], length: 13pt, {
  let bar(y, w, t, note) = {
    cdraw.rect((6.6, y), (6.6 + w, y + 0.85), fill: luma(205), radius: 0.02)
    cdraw.content((6.85 + w, y + 0.42), t, wrap: text.with(size: 6pt), anchor: "west")
    cdraw.content((6.6, y + 0.42), note, wrap: text.with(size: 6pt, fill: luma(100)), anchor: "east")
  }
  bar(7.3, 3.0, [464,047 rows/s], [sqlite insert])
  bar(6.4, 7.2, [1.05 to 1.12 million rows/s], [duckdb append])
  bar(5.5, 1.0, [555,402 rows/s], [sqlite group by])
  bar(4.6, 7.2, [79.6 to 83.3 million rows/s], [duckdb group by])
  bar(3.7, 0.9, [2.37 to 2.41 million rows/s], [sqlite walk])
  bar(2.8, 7.2, [18.1 to 19.4 million rows/s], [duckdb walk])
  cdraw.content((11.5, 1.7), [db file: 829.8 MB sqlite against 449.8 to 450.8 MB duckdb, bit-identical rows], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.5, 0.8), [measured 2026-09-20, back to back lanes, bars indicative, ratios live in the prose], wrap: text.with(size: 6pt))
})

The numbers, both 10m lanes run back to back on 2026-09-20. The
appender sustains 1,049,532 to 1,123,619 rows per second against
sqlite's batched 464,047, 2.3x to 2.4x, and the engine never asks the
caller to pick a batch size. The group by reads back at 79.6 to 83.3
million rows per second against sqlite's 555,402 in the same run, 143x
to 150x. The chunk walk runs at 18.1 to 19.4 million rows per second
against the sqlite cursor walk's 2,374,133, 7.6x to 8.2x, and the
duckdb number is the honest one, it starts at the query, because
duckdb materializes all 10 million rows before the first chunk exists
where sqlite's prepare touched nothing. The stored file is 449.8 to
450.8 MB against sqlite's 829.8 MB for the same rows, duckdb's
compression paying half the space.

And the aggregate story inverts. Inside sqlite the manual walk beat
the group by 4.27x, a linear scan that never sorts against a group by
that must. Inside duckdb the group by finishes in 0.23x the walk's
time, about 4.3x the other way, because the engine aggregates vector
by vector inside its own operators while the C walk decodes station
names one row at a time out of materialized chunks. The 1BRC lesson is
engine-shaped: a hand-rolled scan wins when the engine hands you one
row at a time, and loses when it hands you vectors.

#listing("c-os-cloud/samples/src/Ch21/rowcrunch_duckdb.c", first: 324, last: 343, caption: [the same parity the sqlite smoke asserts: station set, bitwise min and max, float-order averages])

The smoke asserts the same parity on 1236 rows in `:memory:`, 13
checks where the sqlite smoke carries 12, the extra one is the
connection.

== profiled, and why

The chapter 20 sampler attaches to the kernel the way it attached to
its own worker: the kernel thread runs the measured ladder, the main
thread suspends it about a thousand times a second, and each rip
attributes to the nearest symbol at or below it. At `-O2`, 1 million
particles, the histogram reads step_aos 58.8 percent, step_soa 41.2,
kernel_thread 0.0, other 0.0, over 352 samples. Two whys. First, the
split mirrors time, not code size: the aos kernel costs 1.35x the soa
kernel, so it collects samples at 1.43x the rate, 207 against 145,
attribution arithmetic doing what it should. Second, zero samples
outside the two step functions means the loop plumbing, timers,
threading, harness pushes, costs nothing measurable, which is why the
per-particle numbers can be trusted as kernel numbers.

The first profiled run told a lie worth recording: 100 percent of
samples in one function, because at `-O2` both step kernels had been
inlined into the thread proc and every rip inside either attributed to
the nearest surviving symbol. The fix is in the source, both step
functions are `noinline`, and the lesson is chapter 20's attribution
section standing up: a symbol map that does not match the binary the
optimizer produced attributes confidently and wrongly. Sampling also
costs: the profiled run's step numbers land 3 to 5 percent above the
unprofiled ones, 6.50 to 6.56 against 6.15 to 6.38 ns for aos, and the
chapter quotes them separately.

#listing("c-os-cloud/samples/src/Ch21/kernel.c", first: 243, last: 275, caption: [the chapter 20 sampler attached to the kernel: suspend, read the rip, attribute, resume])

#diagram([the profiled histogram and what each bucket means], length: 13pt, {
  cdraw.rect((1.2, 5.4), (14.0, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((7.6, 5.9), [step_aos, 207 samples, 58.8 percent], wrap: text.with(size: 6pt))
  cdraw.rect((1.2, 4.2), (9.8, 5.2), fill: luma(225), radius: 0.02)
  cdraw.content((5.5, 4.7), [step_soa, 145 samples, 41.2 percent], wrap: text.with(size: 6pt))
  cdraw.content((15.5, 5.9), [mirrors the 1.35x cost ratio], wrap: text.with(size: 6pt, fill: luma(100)), anchor: "west")
  cdraw.content((15.5, 4.7), [plumbing: 0 samples, timers live outside], wrap: text.with(size: 6pt, fill: luma(100)), anchor: "west")
  cdraw.content((11.5, 3.0), [the first run lied: inlined steps, one bucket at 100 percent, fixed by noinline], wrap: text.with(size: 6pt))
  cdraw.content((11.5, 2.1), [sampling overhead: 3 to 5 percent on the step numbers, quoted separately], wrap: text.with(size: 6.5pt))
})

== the honest limits

The 100 million particle one-off ran alone, sequential, one layout at
a time because both cannot fit in this machine's memory at once: soa
5.768 and aos 7.229 ns per particle per step, 1.25x, checksum
15067410024.160217 bitwise identical across layouts, process exited
and its 6.4 GiB freed. The 100 million row one-off ran the same
protocol: 451,209 rows per second inserted, the aggregate and p99
numbers in the sections above, an 8330.8 MB database deleted after the
run. One billion is arithmetic, not a measurement: 64 GiB of particles
or roughly 83 GB of database at the observed 8.3 KB per 1000 rows, not
measured on this machine, and the chapter will not pretend otherwise.
The gate's smoke stays 10 thousand particles and 1236 rows, under a
second, every checksum asserted, because the suite must stay fast and
the measurements must stay honest, and the only way to have both is to
keep them apart.

#listing("c-os-cloud/samples/src/Ch21/rowcrunch.c", first: 174, last: 195, caption: [aggregation (b): the manual walk that stays linear while the group by sorts])

#diagram([the scale ladder: measured now, one-off once, arithmetic at the top], length: 13pt, {
  let row(y, t, note, f) = {
    cdraw.rect((1.0, y), (20.6, y + 0.85), fill: f, radius: 0.02)
    cdraw.content((1.4, y + 0.42), t, wrap: text.with(size: 6pt))
    cdraw.content((20.2, y + 0.42), note, wrap: text.with(size: 6pt, fill: luma(100)), anchor: "east")
  }
  row(6.8, [1m particles, 64 MiB], [in the gate's reach, measured, ranges quoted], luma(235))
  row(5.4, [10m rows, 830 MB db], [measured, insert and aggregates, p99 over 1000 chunks], luma(235))
  row(4.0, [100m particles, 6.4 GiB], [one-off, alone, sequential, deleted after], luma(205))
  row(2.6, [100m rows, 8.3 GB db], [one-off, alone, sequential, deleted after], luma(205))
  row(1.2, [1b: 64 GiB particles, ~83 GB rows], [by math only, not measured on this machine], luma(238))
})

#callout("verify", "the capstone's contract", [
  The gate run asserts 29 checks at `-O0`: 4 in the kernel smoke, both
  layouts seeded identically and agreeing bitwise before and after 16
  steps, 12 in the sqlite row smoke, dll loaded, version pinned 3.53.4,
  1236 rows inserted in transactions, both aggregations agreeing
  station by station, min and max bitwise, and 13 in the duckdb row
  smoke, the same parity over the same rows through the appender and
  the chunk api, version pinned v1.5.5. The measured ladder is opt-in
  argv, the bench script under `samples/bench/` builds its own
  binaries and is never invoked by `make verify`, and every number
  quoted in this chapter is a printed line from a run dated 2026-09-13,
  2026-09-14, or 2026-09-20 on this machine, ranges where repeats
  exist, single lines where the run was a deliberate one-off.
])

== the service part

The book does not stop at this capstone. Its service part, chapters 28
through 40, builds the next evidence layer on the same machine facts, a
linked c23 service at `books/c-os-cloud/api`, one program plus one test
exe, ten middleware layers wired into one composition, sqlite 3.53.4
still loaded at runtime beside the exe the way this chapter loads it, the
composition serving 19380 with metrics on loopback 19390. The gate is
`make verify-capi` with its asan leg, and the recorded state is 1130
checks, verified 2026-09-27.

sources: sqlite.org, the c interface reference and the bind family page
(`SQLITE_TRANSIENT`, the destructor contract), accessed 2026-09-14,
duckdb.org's C API reference, the appender, data chunk, and vector
pages (`duckdb_appender`, `duckdb_fetch_chunk`, the validity bitset, at
https://duckdb.org/docs/current/clients/c/overview), accessed
2026-09-20, and the vendored amalgamation's own `sqlite3.h` at 3.53.4
plus the pinned `duckdb.h` at 1.5.5 for the struct and enum layouts;
learn.microsoft.com's loader pages carry the LoadLibraryA and
GetProcAddress contract this chapter leans on from earlier chapters.
Kernel, allocator, sampler, and ingestion timings measured on this
machine 2026-09-13, 2026-09-14, and 2026-09-20, the 100m one-offs
alone and sequential with their state deleted after. Sample behavior
verified by `make verify-c`, 29 checks in chapter 21 of the samples
suite.
