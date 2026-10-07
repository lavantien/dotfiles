#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= concurrency patterns

The primitives compose into a small set of recurring structures, and
code that feels idiomatic in a language is code using those
structures instead of inventing per-file choreography. This chapter
builds the five that carry most production load, generator, pipeline
stage, fan-in, worker pool, and bounded parallel map, plus the
racing-first shape with a deadline, all threaded through a
cancellation carrier, all proven leak free by each tree's own
instrument.

== cancellation first

Every pattern in this chapter takes a stop signal as its first
argument, and the reason is structural: a worker that cannot be told
to stop is a worker that will, someday, be a leak. Go gives the
signal a tree shape, cancel a parent and the children observe it, and
the observation point is the same select everywhere:

#snippet(
  "select {\n"
  + "case out <- v: // hand off\n"
  + "case <-ctx.Done(): // stop everything\n"
  + "}",
  lang: "go",
)

Since go 1.20 a canceled context carries a cause,
`WithCancelCause` plus `context.Cause`, so pipeline stages can
distinguish "user hung up" from "deadline exceeded" from "shutting
down", and `AfterFunc` registers post-cancellation work without a
goroutine parked in select. The sample sticks to plain cancellation,
which is the common case.

The six sibling lanes thread their own carrier as the first
parameter, each the native spelling of the same contract:

#table(
  columns: (auto, 1fr),
  inset: 4pt,
  table.header([*lane*], [*the stop signal*]),
  [c], [a `cancel_ctx`, an atomic done flag plus the channels registered with it, cancel broadcasts into every blocked send],
  [java], [a `CancelCtx`, an atomic done flag plus a watch list of channels, cancel pokes every blocked send awake],
  [c\#], [`CancellationToken`, accepted by every `WriteAsync` and `ReadAllAsync`, cancellation throws out of the wait],
  [javascript], [a `CancelToken`, a canceled flag with a waiter list, checked between yields],
  [python], [a `Cancel` wrapper over an `asyncio.Event`, polled at loop heads],
  [lua], [a ctx table whose cancel aborts every parked channel operation at once],
)

Javascript's native carrier is `AbortSignal`, the signal fetch,
timers, and streams already accept, #xref-to("javascript", "async")
tours the loop it rides, and the sample's `CancelToken` hand-spells
the same contract so the waiter list stays inspectable. Java
hand-spells its carrier too, an `AtomicBoolean` done flag whose
cancel walks a watch list of channels and wakes every blocked send.
Python's row
is the flag-plus-Event carrier in these samples and asyncio task
cancellation in production shape, #xref-to("python", "asyncio")
covers the family. C's lane is the one that builds the whole
mechanism by hand, and its broadcast-on-cancel is the same discipline
the condition variables of chapter 7 enforce.

#flow(
  [cancel the root, every select observes it, the one that cannot is the leak],
  node((0, 0), [root ctx,#linebreak()cancel()]),
  node((2.8, 1.1), [request a]),
  node((2.8, -1.1), [request b]),
  node((5.6, 1.1), [stage,#linebreak()select on Done]),
  node((5.6, -1.1), [stage,#linebreak()no select, leaks]),
  edge((0, 0), (2.8, 1.1), "-|>"),
  edge((0, 0), (2.8, -1.1), "-|>"),
  edge((2.8, 1.1), (5.6, 1.1), "-|>"),
  edge((2.8, -1.1), (5.6, -1.1), "-|>"),
)

== generator and stage

A generator converts a finite source into a stream, a stage
transforms one stream into another, and in go both are one goroutine
with a defer close:

The dry run: squares of 1 through 10 sum to 385, an empty generator
sums to 0, the first value off the chain is 1, and cancel mid-stream
stops the producer with every stage unwound. The six new trees pin
the first value 1, the go lane's frozen cancel test feeds an endless
counter from 0 and pins first square 0, both verified against the
same implementation.

#listing("patterns-concurrency-distributed/samples-c/src/Ch08/pipeline.c", first: 84, last: 124, caption: [C, the select analog as a strict rendezvous, the send completes when a receiver takes the value and cancel aborts it mid-handoff])

#listing("patterns-concurrency-distributed/samples/ch08/patterns.go", first: 12, last: 45, caption: [Go, generator and square stage, identical shape, select on both directions])

#listing("patterns-concurrency-distributed/samples-java/src/Ch08/Pipeline.java", first: 57, last: 96, caption: [Java, the select analog a strict one-slot rendezvous over two Conditions, cancel aborts mid-handoff and the sender retracts])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch08/Pipeline.cs", first: 20, last: 48, caption: [C\#, WriteAsync with the token is the select, cancellation throws out of the wait, finally completes the channel])

#listing("patterns-concurrency-distributed/samples-js/src/ch08-pipeline.mjs", first: 7, last: 57, caption: [JavaScript, async generators with a finally head count, the consumer's return propagates down the chain])

#listing("patterns-concurrency-distributed/samples-py/src/Ch08/pipeline.py", first: 22, last: 60, caption: [Python, async generators, cancellation checked at the loop head, aclose runs the finally])

#listing("patterns-concurrency-distributed/samples-lua/ch08_pipeline.lua", first: 170, last: 206, caption: [Lua, generator and stage lanes over hand channels, send and recv abort on a canceled ctx, close on exit])

The shape is the contract in every lane. The producer checks the
carrier or selects on it, so a consumer that quits unblocks it. The
close behind the producer means the stage downstream can drain its
input and terminate when the chain empties. Go writes it as one
select covering both directions. C builds the select by hand as a
strict rendezvous, the send parks until a receiver takes the value,
cancel wakes it, and a sender canceled while holding the slot retracts
its own value. Java's `XChan` is the same strict rendezvous over a
`ReentrantLock` and two conditions, its cancel broadcast retracting
the held slot exactly like C's. C\# writes the stages over
`System.Threading.Channels`,
`WriteAsync` and `ReadAllAsync` each taking the token, the channel
pipeline idiom the stdlib tour builds, #xref-to("csharp-net",
"stdlib2"). Javascript and python lean on async generators, where
exhaustion and the consumer's early return both run the finally, and
the js lane counts stage bodies alive to make unwinding assertable.
Lua spawns one lane per stage over its hand channels and teaches the
cancel watcher list, the same mechanism chapter 9's guard reuses.

#flow(
  [the pipeline spine],
  node((0, 0), [generator]),
  node((2, 0), [square stage]),
  node((4, 0), [consumer sum]),
  node((2, 1.1), [ctx.Done, cancel]),
  edge((0, 0), (2, 0), "-|>"),
  edge((2, 0), (4, 0), "-|>"),
  edge((2, 1.1), (0, 0), "-|>", bend: 25deg),
  edge((2, 1.1), (2, 0), "-|>", bend: 10deg),
)

== fan-in, merge

Fan-out is free, starting a consumer per producer is a loop. Fan-in,
merging many streams back into one, needs one forwarder per source
and a closer that waits:

The dry run: sources (1,2,3), (10,20), and (100) merge to exactly the
sorted six 1, 2, 3, 10, 20, 100, and an empty fan-in drains 0 values.
Interleaving is the one property the pattern does not promise, so
every lane sorts before asserting.

#listing("patterns-concurrency-distributed/samples-c/src/Ch08/fanin.c", first: 77, last: 94, caption: [C, the closer's predicate, one open source keeps the merge alive, scripted round-robin passes replace racing forwarders])

#listing("patterns-concurrency-distributed/samples/ch08/patterns.go", first: 47, last: 70, caption: [Go, forwarder per input, waitgroup, close after the last source closes])

#listing("patterns-concurrency-distributed/samples-java/src/Ch08/Fanin.java", first: 24, last: 67, caption: [Java, the scripted round-robin merge, allClosed the closer's predicate, the trace recorded instead of raced])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch08/Fanin.cs", first: 8, last: 43, caption: [C\#, one forwarder task per input, a WhenAll over them, the closer task completes the output last])

#listing("patterns-concurrency-distributed/samples-js/src/ch08-fanin.mjs", first: 41, last: 68, caption: [JavaScript, one forwarder per source pushing into a merge queue, close only after every source finished])

#listing("patterns-concurrency-distributed/samples-py/src/Ch08/fanin.py", first: 24, last: 45, caption: [Python, forwarders into one queue, a sentinel after the gather ends the drain])

#listing("patterns-concurrency-distributed/samples-lua/ch08_fanin.lua", first: 141, last: 164, caption: [Lua, one forwarder lane per input, a waitgroup, a closer lane that closes out after the last Done])

The closer after the barrier is the subtle part in every lane: the
merge's output must close only when every input has closed, and the
barrier is the cheapest edge that orders "all forwarders returned"
before close. Go and lua spend a waitgroup, C\# a `WhenAll`,
javascript a `Promise.all` before `q.close()`, python a sentinel
enqueued after the gather. The C and java lanes script the whole
interleave, round-robin passes with sources closing at chosen
points, so the pinned pass order 1, 10, 100, 2, 20, 3 is a fixture,
an interleaving the racer lanes leave free.

#flow(
  [one forwarder per source, the closer waits then closes out],
  node((0, 1.2), [src 1]),
  node((0, 0), [src 2]),
  node((0, -1.2), [src 3]),
  node((2.8, 0), [out, merged]),
  node((5.6, 0), [consumer,#linebreak()ranges until close]),
  node((2.8, -2.4), [closer,#linebreak()wg.Wait, then close]),
  edge((0, 1.2), (2.8, 0), "-|>"),
  edge((0, 0), (2.8, 0), "-|>"),
  edge((0, -1.2), (2.8, 0), "-|>"),
  edge((2.8, 0), (5.6, 0), "-|>"),
  edge((2.8, -2.4), (2.8, 0), "-|>"),
)

== worker pool

A pool fixes the concurrency count instead of the workload: n workers
share one job queue, which is a queue with no configuration:

The dry run: 50 jobs through 4 workers. Every job processed exactly
once, no more than 4 distinct worker ids ever appear, and each job
computes a positive sum. The java, javascript, python, and lua lanes
pin the sum itself, 147, the total of i modulo 7 over 50 ops, the go
and C\# lanes assert positivity, and C checks every result against
its own grind function.

#listing("patterns-concurrency-distributed/samples-c/src/Ch08/workerpool.c", first: 107, last: 140, caption: [C, 4 real threads ranging one queue, worker ids taken under the results lock, every job lands exactly once])

#listing("patterns-concurrency-distributed/samples/ch08/patterns.go", first: 83, last: 110, caption: [Go, n goroutines ranging one channel, results unordered])

#listing("patterns-concurrency-distributed/samples-java/src/Ch08/Workerpool.java", first: 44, last: 62, caption: [Java, the pool over a fixed ExecutorService, invokeAll hands futures back in submission order])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch08/Workerpool.cs", first: 11, last: 52, caption: [C\#, n tasks ranging one channel through ReadAllAsync, the closer task completes after WhenAll])

#listing("patterns-concurrency-distributed/samples-js/src/ch08-workerpool.mjs", first: 8, last: 33, caption: [JavaScript, n runners sharing one job list, the synchronous shift is the exactly-once guarantee])

#listing("patterns-concurrency-distributed/samples-py/src/Ch08/workerpool.py", first: 39, last: 61, caption: [Python, n laborers over one queue, stop sentinels drain the crew, results in completion order])

#listing("patterns-concurrency-distributed/samples-lua/ch08_workerpool.lua", first: 129, last: 155, caption: [Lua, n lanes pulling one channel, a yield inside the loop interleaves the work])

Ordering is explicitly not among the guarantees, results arrive in
completion order, and when the caller needs input order anyway the
cheaper shape is the next pattern. Java is the one lane that gets
order for free: `ExecutorService.invokeAll` hands futures back in
submission order, so its results are ordered without any indexing, a
real divergence from the siblings. The lanes differ only in what
enforces exactly-once: go, C, and lua share one channel or queue that
hands each job to one receiver, java's executor owns the queue, C\#
ranges one channel through `ReadAllAsync`, javascript relies on the
single-threaded `shift`, and python's queue plus sentinels keeps
every job with one laborer.

#flow(
  [n workers range one queue, exactly once each, results unordered],
  node((0, 0), [jobs chan,#linebreak()the queue]),
  node((2.8, 1.2), [worker 1]),
  node((2.8, 0), [worker 2]),
  node((2.8, -1.2), [worker n]),
  node((5.6, 0), [results,#linebreak()completion order]),
  edge((0, 0), (2.8, 1.2), "-|>"),
  edge((0, 0), (2.8, 0), "-|>"),
  edge((0, 0), (2.8, -1.2), "-|>"),
  edge((2.8, 1.2), (5.6, 0), "-|>"),
  edge((2.8, 0), (5.6, 0), "-|>"),
  edge((2.8, -1.2), (5.6, 0), "-|>"),
)

== bounded parallel map, ordered

Fan-out with a result array indexed by input position gives
parallelism with order preservation, and the gate bounds the
concurrency, chapter 6's counting semaphore at work:

The dry run: 8 inputs through a gate of 3, f maps each input to its
letter. The output reads back a through h in input order while
completion order scrambles by construction, and the peak in-flight
count never exceeds 3. The scrambles differ per lane: go sleeps real
60 minus v milliseconds, C and java drive a discrete-event scheduler
with a pinned completion order, C\# releases countdown events in
reverse input order, javascript scales the same shape to microtask
turns, python and lua run the sleeps on virtual clocks, the only real
milliseconds spent anywhere are the go lane's.

#listing("patterns-concurrency-distributed/samples-c/src/Ch08/orderedmap.c", first: 41, last: 79, caption: [C, admit in input order, always advance to the earliest finish, ties by admission order, no thread waits])

#listing("patterns-concurrency-distributed/samples/ch08/patterns.go", first: 112, last: 134, caption: [Go, no result channels: one slot per input, a gate for parallelism])

#listing("patterns-concurrency-distributed/samples-java/src/Ch08/Orderedmap.java", first: 49, last: 87, caption: [Java, C's discrete-event scheduler, admit in input order, advance to the earliest finish, ties by admission])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch08/Orderedmap.cs", first: 7, last: 34, caption: [C\#, a SemaphoreSlim of size parallelism, every task writes its own slot, WhenAll publishes])

#listing("patterns-concurrency-distributed/samples-js/src/ch08-orderedmap.mjs", first: 6, last: 43, caption: [JavaScript, a promise-count gate bounds the in-flight tasks, every slot writes itself])

#listing("patterns-concurrency-distributed/samples-py/src/Ch08/orderedmap.py", first: 64, last: 97, caption: [Python, an asyncio semaphore gates the fan-out, sleeps resolve through the heap clock, later slots finish first])

#listing("patterns-concurrency-distributed/samples-lua/ch08_orderedmap.lua", first: 59, last: 97, caption: [Lua, the gate parks waiters in arrival order, vsleep orders completions, slots fill in input order])

No mutex on the array: each worker writes exactly one distinct slot,
and the barrier is the happens-before edge that publishes them all,
`Wait` in go, the `join` over the virtual-thread crew in java's live
lane, `WhenAll` in C\#, the gather in python, the resolved
promise chain in javascript, the joined lanes in lua, the completed
loop in C's and java's scheduler. Java runs the fan-out twice, the
recorded scheduler beside a live `Semaphore`-gated crew whose
slot-indexed writes keep input order whatever the landing order.
The test makes later inputs finish first and
the output still comes back in input order. This is the shape to
reach for when someone reaches for an error group with an index map
on the side.

#diagram([every goroutine writes its own slot, wait publishes them all], length: 13pt, {
  cdraw.rect((8.6, 6.6), (15.4, 8.4), fill: luma(205), radius: 0.02)
  cdraw.content((12, 8.0), [gate channel], size: 6.5pt)
  cdraw.content((12, 7.1), [cap C, at most C at once], size: 6pt)
  for i in range(4) {
    let x = 0.6 + i * 2.2
    cdraw.rect((x, 5.2), (x + 1.8, 6.4), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.9, 5.8), [in #i], size: 6pt)
    cdraw.rect((x + 12.2, 1.4), (x + 14.0, 2.6), fill: luma(235), radius: 0.02)
    cdraw.content((x + 13.1, 2.0), [slot #i], size: 6pt)
    cdraw.line((x + 0.9, 5.2), (x + 13.1, 2.6), stroke: luma(220))
  }
  cdraw.content((2.4, 4.0), [inputs], size: 6.5pt)
  cdraw.content((17.2, 4.3), [outputs, input order], size: 6.5pt)
  cdraw.content((11.5, 0.4), [later inputs may finish first, the slice still reads back in order], size: 6pt)
})

== racing sources, first wins

Select over answers and deadline together gives hedged requests their
core:

The dry run: a source ready at 10ms races one at 1s inside a 2s
budget and the caller receives `fast: quick`. Two sources stalled
past 5s under a 30ms deadline produce the timeout error naming
neither source. The mechanism split is the honesty of this section:
the frozen go test sleeps real milliseconds with margins around 100x,
the six new trees inject the clock, so their runs spend no wall time
and C, java, javascript, python, and lua also assert where the clock
lands, 10 on the win and 30 on the timeout.

#listing("patterns-concurrency-distributed/samples-c/src/Ch08/first.c", first: 47, last: 75, caption: [C, both producers report a ready instant, the earliest edge wins unless the deadline is earlier still])

#listing("patterns-concurrency-distributed/samples/ch08/patterns.go", first: 136, last: 154, caption: [Go, first answer wins, loser writes discarded into a buffered channel])

#listing("patterns-concurrency-distributed/samples-java/src/Ch08/First.java", first: 26, last: 72, caption: [Java, the sources answer with their ready instants, the earliest edge wins unless the deadline is earlier still])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch08/First.cs", first: 10, last: 40, caption: [C\#, WhenAny over the read and a Task.Delay on the injected TimeProvider, no real interval slept])

#listing("patterns-concurrency-distributed/samples-js/src/ch08-first.mjs", first: 9, last: 52, caption: [JavaScript, the fake timer queue, sleep parks on a due instant, advance fires the due ones in order])

#listing("patterns-concurrency-distributed/samples-py/src/Ch08/first.py", first: 66, last: 87, caption: [Python, the deadline is one more timer on the heap, asyncio.wait takes the first completion, losers are canceled])

#listing("patterns-concurrency-distributed/samples-lua/ch08_first.lua", first: 88, last: 121, caption: [Lua, the deadline is one more racer, the first fire wins and cancels the sleeps still pending])

The answer channel is buffered to 2 in the go lane so the loser's
send never blocks after the winner is chosen, a small instance of the
general rule that every producer must tolerate an unread result. The
injected-clock lanes each rebuild that tolerance their own way: C
lets the loser's answer sit in the pick buffer unread, java does the
same and parks its native shape beside the clock, `anyOf` over two
`CompletableFuture`s answering from whichever future completed, C\#
writes into a bounded channel of 2, javascript's race drops the losing
branch, python cancels the losing tasks, lua aborts the pending
sleeps through the deadline's context. The winner is whichever edge
fires first, the names are labels, and the C, java, and lua lanes pin
the counter-lane where the slow source answers first and wins anyway.

#diagram([first answer wins, the loser drains into the buffer], length: 13pt, {
  cdraw.line((1, 1), (22, 1), stroke: luma(100))
  cdraw.line((10, -0.2), (10, 3.0), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((10, 3.5), [30ms deadline], size: 6.5pt)
  cdraw.circle((4, 1), radius: 0.14, fill: luma(30))
  cdraw.content((4, 2.0), [fast source, 10ms,#linebreak()the winner], size: 6pt)
  cdraw.circle((20, 1), radius: 0.14)
  cdraw.content((19.6, 2.0), [slow source, 1s,#linebreak()send absorbed by cap 2], size: 6pt)
  cdraw.content((11.5, -0.9), [both stalled: the deadline fires and the caller gets the timeout error], size: 6pt)
})

== the leak test

The chapter's last test is the one worth copying into real projects.
It runs the whole composite, generator into square into fan-in, 10
times, cancels, and asks each tree's own instrument whether anything
stayed behind:

The dry run: 10 rounds of build, consume, cancel, drain. The go lane
polls the goroutine count back to baseline after a GC. The six new
lanes read their instrument directly, C joins every thread and counts
the live ones back to 0, java reads its live-thread counter back to 0
each round, C\# reads the in-flight stage counter to 0
past the merged channel's completion, javascript reads the stage and
forwarder probes to 0, python reads the alive probe to 0, lua asserts
no lane stays parked. Only the go lane samples a runtime counter, so
only it needs a polling window, and none of the seven asserts a timing.

#listing("patterns-concurrency-distributed/samples-c/src/Ch08/pipeline.c", first: 279, last: 301, caption: [C, the check region: 10 rounds of build, cancel, drain, the live-thread count returns to 0 each round])

#listing("patterns-concurrency-distributed/samples/ch08/patterns_test.go", first: 148, last: 168, caption: [Go, goroutine count as a leak detector])

#listing("patterns-concurrency-distributed/samples-java/src/Ch08/Pipeline.java", first: 275, last: 297, caption: [Java, the check region: ten rounds of build, consume, cancel, drain, the live-thread counter returns to 0 each round])

#listing("patterns-concurrency-distributed/samples-cs/tests/Ch08/PipelineTests.cs", first: 81, last: 100, caption: [C\#, xunit: completion is the edge past which every stage ran its Exit, the counter reads true, not approximately])

#listing("patterns-concurrency-distributed/samples-js/test/ch08.test.mjs", first: 152, last: 170, caption: [JavaScript, node:test: stage and forwarder probes return to baseline after 10 cycles])

#listing("patterns-concurrency-distributed/samples-py/src/Ch08/pipeline.py", first: 87, last: 115, caption: [Python, the check region: 10 runs, the alive probe stays at 0 and each run computes the same total])

#listing("patterns-concurrency-distributed/samples-lua/ch08_pipeline.lua", first: 293, last: 316, caption: [Lua, the row table: cancel mid drain, no lane stays parked, the scheduler drains to live 0])

Two seconds of polling absorbs scheduler noise in the go lane, and a
count that never returns to baseline is a worker that ignored
cancellation, exactly the bug every select and every token check in
this chapter exists to prevent. Go 1.27 ships a sharper tool for the
same job, the `goroutineleak` profile in `runtime/pprof` flags
goroutines blocked on channels or mutexes that GC reachability says
can never wake, covered with the other detectors in chapter 9.

#diagram([goroutine count climbs, cancels, and returns to baseline], length: 13pt, {
  cdraw.line((2, 0), (2, 7.4), stroke: luma(100))
  cdraw.line((2, 0), (21, 0), stroke: luma(100))
  cdraw.content((1.1, 7.4), [count], size: 6pt)
  cdraw.content((21.6, 0), [time], size: 6pt)
  cdraw.line((2, 1), (7, 1), stroke: luma(100))
  cdraw.line((7, 1), (7, 4.4), stroke: luma(100))
  cdraw.line((7, 4.4), (10.5, 4.4), stroke: luma(100))
  cdraw.line((10.5, 4.4), (14.5, 1), stroke: luma(100))
  cdraw.line((14.5, 1), (20, 1), stroke: luma(100))
  cdraw.content((4.5, 1.6), [baseline], size: 6pt)
  cdraw.content((8.7, 5.0), [10 pipelines], size: 6pt)
  cdraw.content((12.5, 2.7), [cancel, gc], size: 6pt)
  cdraw.content((17.3, 1.6), [baseline again, inside the window], size: 6pt)
})

#callout("note", "pattern selection", [
  Need results in input order with bounded parallelism: the ordered
  map. Need unordered throughput on a stream: the worker pool. Need
  to converge many producers: fan-in. Need to stop everything from
  one place: the cancellation carrier, threaded into all of them
  from the start. Retrofitting cancellation onto a finished pipeline
  is a rewrite.
])

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [724], [libc plus threads.h, stdatomic.h],
  [the select analog a strict rendezvous, cancel broadcasts into blocked sends],
  [go], [129], [stdlib],
  [frozen reference lane, select on both directions, goroutine count as leak probe],
  [java], [599], [jdk 27 stdlib],
  [the XChan rendezvous and CancelCtx rolled by hand, the scripted fan-in trace, invokeAll handing back submission order],
  [c\#], [204], [bcl],
  [the token into every channel wait, WhenAll the barrier, WhenAny over Task.Delay],
  [javascript], [196], [node stdlib, one sibling module],
  [a hand-spelled CancelToken, the finally head count, the fake timer queue],
  [python], [351], [stdlib only],
  [a Cancel over an Event, the sentinel after the gather, the heap clock],
  [lua], [1150], [lib.lua harness],
  [cancel aborts every parked operation, lanes per stage, the deadline a racer],
)

sources: go.dev/pkg/context for cancellation trees, `Cause`,
`AfterFunc`, go.dev/blog/pipelines for the generator and stage
vocabulary, go.dev/doc/go1.27 for the goroutine leak profile,
accessed 2026-09-08. Verified by the seven chapter legs: 5 Ch08 C
programs with 270 embedded checks, `go test` at 8 tests in
`patternsbook/ch08`, 5 Ch08 java programs with 69 checks under
`run-java-samples`, 11 xunit facts, node's 8 cases in
`test/ch08.test.mjs`, 5 python modules with 33 embedded checks, and
the lua runner's 22 ch08 rows.
