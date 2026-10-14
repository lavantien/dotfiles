#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= load and p99

A service whose p99 is a guess is a service shipped on faith. This
chapter builds the tool that replaces the guess, `rustapi::load`, and
points it at the real stack: the client on plain `std::net`, the
closed loop and the open loop over 3 injected seams, the report whose
every column renders from integers, and the dated captures this
machine produced, ladder and budget, committed beside the code. The
go book built the same harness around an `http.Client` seam with one
goroutine per arrival, #xref-to("go", "load"), the java book around
one virtual thread per worker, #xref-to("java", "load"), and this
lane builds it around one OS thread per fire and a zero-dependency
client, because the crate answers every want the same way: nothing
outside the standard library.

== the client, plain std::net

The whole client is one function. Resolve the authority, connect
with a timeout, write one `GET` with `connection: close`, read to the
end, parse the status out of the first line:

#listing("rust/api/src/load.rs", first: 67, last: 98, caption: [one fire: resolve every address, connect with a timeout, one request, read to the close, every failure an Outcome never a panic])

Three decisions earn their sentences. The connection asks to close,
rfc 9112 section 9.6, so the server's answer ends at the connection
close and `read_to_end` terminates without parsing lengths, the
cheapest correct body read a zero-dep client can make. Every failure
is a returned `Outcome::failed()`, never a panic and never a skipped
request, because a load tool that dies on the first refused
connection loses exactly the data the cliff produces. And the
resolver loop tries every address the name resolves to, a lesson the
compose healthcheck taught the hard way: inside the container
`localhost` resolves v6 first and the listener holds v4, and a
client that dials only the first answer reported a healthy service
as dead. And the trade is stated rather than hidden: one fresh
connection per fire, no pooling, so every latency in the report pays
the connect and the throughput ceiling measures the connect-plus-
serve path, not the served path alone. The go and java clients
pooled their connections and their ladders measured higher, and the
two sets of numbers are not comparable to each other, a fact the
capture header states by naming the client.

== the two loops

The closed loop holds concurrency constant: `workers` threads, each
firing one request at a time and starting the next only after the
previous response lands, so offered load never exceeds the worker
count no matter how slow the server gets. The open loop holds arrival
rate constant: arrival `i` is scheduled at `i` periods past the start
and fires on its own thread whether or not anything has come back,
which is the loop that measures the overload cliff, because offered
load stays fixed even as latency explodes:

#listing("rust/api/src/load.rs", first: 140, last: 175, caption: [the closed loop: one thread per worker, joined, warmup first and unrecorded])

#listing("rust/api/src/load.rs", first: 177, last: 211, caption: [the open loop: one thread per arrival, the deadline from absolute i, late tolerance])

Little's law, in flight equals arrival rate times service time,
predicts what the open loop shows: at fixed arrival rate, rising
latency turns directly into a rising in-flight count. The late
tolerance is one line, the wait computed as deadline minus now, so an
arrival whose deadline has passed fires immediately and never sleeps
backwards, and the test pins it with a clock that steps 10 seconds
per read: both arrivals of a 10-per-second schedule fire with zero
sleeps. A thread per arrival costs a real stack, some hundred
kilobytes against a goroutine's few, and the tool's totals stay in
the thousands, stated as the lane's own cost of the std-only ruling.

#diagram([workers, pacer, server, sink: one harness, two loops], length: 13pt, {
  let step(x0, title, l1, l2) = {
    cdraw.rect((x0, 3.8), (x0 + 5.6, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.8, 6.0), [#title], size: 6pt)
    cdraw.content((x0 + 2.8, 5.1), [#l1], size: 6pt)
    cdraw.content((x0 + 2.8, 4.2), [#l2], size: 6pt)
  }
  step(0.3, [closed loop], [workers wait for each], [offered = workers])
  cdraw.line((6.1, 5.2), (6.7, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(6.7, [open loop], [arrival i at i periods], [fires regardless])
  cdraw.line((12.5, 5.2), (13.1, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(13.1, [the fire], [injected: fake or socket], [status answers])
  cdraw.line((18.9, 5.2), (19.5, 5.2), stroke: luma(100), mark: (end: ">>"))
  step(19.5, [the sink], [latencies, statuses], [warmup excluded])
  pane(0.3, 11.0, 2.4, [little's law], [L = rate x W], [fixed rate, watch L climb])
  cdraw.content((17.2, 1.4), [a fire that never answers is data, not a crash], size: 6pt)
  cdraw.content((17.2, 0.3), [the errors row is where a run reads its own ceiling], size: 6pt)
})

== the schedule is pure integer math

Arrival `i` of `rate` per second fires at `i` seconds over `rate`,
computed in `u128` and returned as micros:

#listing("rust/api/src/load.rs", first: 56, last: 58, caption: [the deadline from absolute i: truncation error under one micro per arrival, never accumulated])

Two properties fall out of the integers. The deadline is computed
from the absolute arrival index, not by accumulating periods, so a
rate like 7 that divides no power of ten truncates each deadline by
less than one microsecond, `schedule_micros(1, 7)` is 142857, and the
error never compounds across arrivals. And the rate is a `u64`, so
the NaN rate go's adversarial round caught its harness accepting
cannot exist here, answered by the type rather than by a validation
branch, while the division by zero the type cannot keep out is
refused by the assert, `rate_per_sec > 0`, in the lane's
`should_panic`-testable style. The schedule table is pinned as pure
math, six cells including the non-dividing rate.

== warmup and the stop signal

Warmup fires first, unpaced and unrecorded, so the first measurement
does not pay for cold caches and the kernel's fresh connection setup,
and a warmup that cannot reach the server is counted in
`warmup_errors` rather than failing the run, because the run that
follows still measures what it measures:

#listing("rust/api/src/load.rs", first: 112, last: 119, caption: [warmup: fired, never recorded, failures counted apart])

The stop signal is the ctrl-c equivalent, an `Arc<AtomicBool>` every
loop consults before offering the next fire and never inside one. An
in-flight fire always completes, a worker blocks on its own fire by
construction, so setting the flag is a graceful drain: offering
stops, the pending land, the run reports `stopped`. The tests pin
both ends deterministically, a fire closure that sets the flag on its
third call leaves exactly 3 recorded fires out of 10 offered, and a
pre-set flag fires nothing at all, 0 fires, 0 latencies, `stopped`
true.

== the report, every number an integer

One run folds into one report, and the report renders without a float
anywhere. The rate is computed in milli-requests per second from a
`u128` product, the percentiles are chapter 28's nearest rank over a
sorted copy, and the cells print by integer division with 3 fraction
digits:

#listing("rust/api/src/load.rs", first: 242, last: 263, caption: [summarize: the exact form, percentiles by permille, the rate in milli from u128])

#listing("rust/api/src/load.rs", first: 265, last: 281, caption: [the buckets form: count and sum exact, percentiles as bounds, src names the approximation])

#listing("rust/api/src/load.rs", first: 283, last: 289, caption: [the cells: every column rendered by integer division, no float formatting in the table])

The golden test pins the bytes from a fixed vector, 6 latencies of
1, 1, 2, 3, 5, and 8 milliseconds over a 60 millisecond window, the
same window the go lane's golden pinned at 100.0 rps where the java
lane's 8 millisecond window read 750: here it renders 100.000 rps,
p50 of 2.000, p90, p99, and max all clamped to 8.000 because a
percentile past the data is a bound, and the bucket twin of the same
observations reads p50 2.500 and p99 10.000, the bounds the ranks
land in, never anything inside them. The test
asserts the ordering property between the 2 rows, the bucket p99 can
never undercut the exact one, which is the whole honesty of the src
column in one line of code.

== the ladder, measured

The capture is dated, machine-named, and committed at
`books/rust/api/captures/2026-10-14-load.txt`. The stack is the
spine's own, kernel routes, the notes resource, the wal engine, the
limiter raised to burst 100000 through the same rule constructor the
wiring uses, its default untouched, because the ladder's subject is
the stack, not the limiter:

#listing("rust/api/captures/2026-10-14-load.txt", first: 9, last: 14, caption: [the ladder: 3 closed loops and one open loop, this machine, 2026-10-14])

Reading it: 1 worker answers 398.643 rps at a p50 of 2.525 ms, and
the connect dominates, the client's stated trade, not a server
number. 8 workers reach 3140, 32 reach 9939, and the growth from 8
to 32 is where the pool earns its keep. The open loop at 5000
offered per second achieves 4993.333 with all 5000 arrivals served
and 0 errors, 99.87 percent of schedule, the unremarkable number
that is the point: below capacity the open loop confirms the closed
loop's story, and only above capacity do the 2 designs differ. The
tail tells it from the other end, p50 moves 2.525 to 3.158 ms across
the ladder while p99 moves 2.824 to 4.025 and max 3.467 to 4.463,
the queue grows and the percentile ladder is where it shows.

#diagram([the ladder's p50 and p99 against offered load, the tail is the story], length: 13pt, {
  cdraw.line((0.6, 0.7), (23.2, 0.7), stroke: luma(120))
  cdraw.content((23.4, 0.7), [workers], size: 6pt)
  cdraw.line((0.6, 0.7), (0.6, 7.4), stroke: luma(120))
  cdraw.content((0.6, 7.6), [ms], size: 6pt)
  cdraw.line((0.9, 5.2), (8.0, 5.2), stroke: luma(60))
  cdraw.line((8.0, 5.2), (15.0, 4.6), stroke: luma(60))
  cdraw.line((15.0, 4.6), (23.2, 4.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.0, 5.6), [p50, 2.5 to 3.2], size: 6pt)
  cdraw.line((0.9, 4.0), (8.0, 3.9), stroke: luma(120), dash: "dashed")
  cdraw.line((8.0, 3.9), (15.0, 3.0), stroke: luma(120), dash: "dashed")
  cdraw.line((15.0, 3.0), (23.2, 2.7), stroke: luma(120), dash: "dashed", mark: (end: ">"))
  cdraw.content((17.0, 3.4), [p99, 2.8 to 4.0], size: 6pt)
  cdraw.content((11.5, 1.6), [the connect rides every fire, the numbers name their own client], size: 6pt)
  pane(1.0, 9.6, 2.6, [what grew], [throughput: 399 to 9939], [then the tail moved])
})

== the budget, measured on the shipped binary

The ladder raised the budget through the rule's constructor, and the
wiring's default is unchanged from chapter 27, burst 30 with one
token per second in the shared anonymous pool. Against the shipped
binary itself, the one `main.rs` builds, booted on ephemeral ports
with its wal in a scratch directory, the same closed loop meets the
layer chapter 27 built and the layer chapter 28 seats outside it:

#listing("rust/api/captures/2026-10-14-load.txt", first: 16, last: 20, caption: [8 workers offer 200, the budget answers 29, one probe burns the thirtieth])

29 of 200 measured fires answered 200 and 171 answered 429, and the
exposition scraped off the binary's own ops port counts exactly 30
and 171, 201 requests in all, because the harness's readiness probe
was itself a `GET /healthz` the registry counted, one registry
observing every request including the tool's own. The pooled p99 of
3.925 ms covers both statuses together, the limiter's design claim
measured: refusing is cheap, the flood costs the handler nothing,
and the budget is spent exactly where the token bucket said it would
be. The `_count` of 201 and the `_sum` of 0.014603 are in the
committed capture, and the scrape's content type is the one chapter
28 pinned.

#callout("note", "the knob, not a bypass", [
  The ladder boot raises the budget through the same rule constructor the wiring calls, burst 100000 against the default 30, and nothing about the deployed service changes. The capture header names the stack and the client, so neither number can be mistaken for the default's behavior or a pooled client's throughput.
])

== what the run leaves behind

Two artifacts outlive the session, and they are the point of the
chapter. The capture, dated and committed, so the next run on the
next machine has a baseline to diff against and no one re-derives
today's numbers from memory. And the tool itself, 10 tests green
three consecutive runs, which is what makes next quarter's number
comparable to this one: a load report nobody can rebuild byte for
byte is a slide, not a measurement. The suite drives the loops under
tick clocks and fake sleepers, counts deterministic, zero wall-clock
assertions, and one test walks the real client against a real
in-process listener to prove the socket path, the only place the
wall clock appears is where it is the subject.

sources: rfc 9112 section 9.3, persistence, and section 9.6,
tear-down and the close option, at rfc-editor.org, accessed
2026-10-14, and rfc 9110 section 7.6.1 for the Connection field
itself, same date. Little's law as stated across the corpus,
#xref-to("go", "profiling") owns the profiling-side treatment, and
the loop pair, the warmup discipline, and the report columns follow
the go book's load chapter and the java book's chapter 29, read for
the parallel contracts, with the integer schedule and the u64 rate
being this lane's own divergence. The ladder and budget captures are
books/rust/api/captures/2026-10-14-load.txt, produced by
`cargo test --locked --test load -- --ignored --nocapture` under
`CARGO_NET_OFFLINE=true` on the pinned 1.99.0 build, dated
2026-10-14, and the load tests ran green 10 of 10 three consecutive
runs the same day.
