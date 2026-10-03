#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= go runtime: scheduler, gc, patterns

The go systems half of the loop starts here. The `ch15-go` module
carries the runnable answers, 16 tests including one run under
`-race`, and the release facts are pinned to the go 1.26 notes in
the sources appendix, accessed 2026-09-09.

== parallelism is not concurrency [EWC]

Parallelism is two things at once, which needs cores. Concurrency
is a program structured as independently runnable pieces, which
needs nothing but the structure. `GOMAXPROCS` is where the two
meet, the number of OS threads the go scheduler keeps runnable
goroutines on:

#listing("interview-repertoire/samples/ch15-go/scheduler.go", first: 8, last: 34, caption: [the definition pair, and ten thousand goroutines rendezvousing inside a test])

#diagram([parallelism is cores, concurrency is structure], length: 13pt, {
  // the 2x2: rows are structure, columns are cores, lanes are tasks over time
  cdraw.content((10.0, 8.0), [not parallel], size: 6.5pt)
  cdraw.content((17.0, 8.0), [parallel], size: 6.5pt)
  cdraw.content((3.1, 6.05), [concurrent], size: 6.5pt)
  cdraw.content((3.1, 3.05), [not concurrent], size: 6.5pt)
  cdraw.rect((6.5, 1.6), (20.5, 7.4), stroke: luma(120), radius: 0.02)
  cdraw.line((13.5, 1.6), (13.5, 7.4), stroke: luma(120))
  cdraw.line((6.5, 4.8), (20.5, 4.8), stroke: luma(120))
  // top-left: one lane, interleaved segments; top-right: two lanes in counterphase
  for (x0, x1, tone) in ((7.3, 8.6, 60), (8.6, 9.9, 150), (9.9, 11.2, 60), (11.2, 12.5, 150)) {
    cdraw.line((x0, 7.45), (x1, 7.45), stroke: luma(tone))
    cdraw.line((x0 + 7.0, 7.45), (x1 + 7.0, 7.45), stroke: luma(tone))
    cdraw.line((x0 + 7.0, 6.9), (x1 + 7.0, 6.9), stroke: luma(if tone == 60 { 150 } else { 60 }))
  }
  cdraw.content((10.0, 6.4), [tasks interleave], size: 6pt)
  cdraw.content((10.0, 5.25), [on one core], size: 6pt)
  cdraw.content((17.0, 6.4), [tasks interleave], size: 6pt)
  cdraw.content((17.0, 5.25), [across cores], size: 6pt)
  // bottom row: one continuous task, and independent per-core tasks
  cdraw.line((7.3, 3.3), (12.7, 3.3), stroke: luma(60))
  cdraw.content((10.0, 2.4), [one task at a time], size: 6pt)
  cdraw.line((14.3, 3.6), (19.7, 3.6), stroke: luma(60))
  cdraw.line((14.3, 3.0), (19.7, 3.0), stroke: luma(150))
  cdraw.content((17.0, 2.4), [one task per core], size: 6pt)
  cdraw.content((11.5, 0.7), [GOMAXPROCS: how many cores the scheduler uses], size: 6pt)
})

The demo to narrate from the test: ten thousand goroutines spawn,
signal, and drain in milliseconds, because a goroutine is a few
kilobytes and a runtime scheduling decision, not an OS thread the
kernel allocates.

== the scheduler versus the os [EWC]

The model to say out loud: goroutines are M, OS threads are N, and
the go scheduler multiplexes M onto N with work stealing. The full
GMP walk is #xref-to("go", "runtime"). A goroutine blocking on a
channel or mutex parks in the runtime and its thread runs someone
else. A goroutine blocking in a syscall hands its thread to the
kernel and the runtime spins up or reuses another. That split,
runtime parking versus kernel blocking, is the answer to "why are
goroutines cheap" and the follow-up "when are they not", where the
honest list is cgo calls, file io, and anything that parks the
thread instead of the goroutine.

#diagram([M goroutines multiplexed onto N threads: park versus syscall], length: 13pt, {
  // runnable gs above, two threads with local queues, the two blocking stories below
  cdraw.content((8.2, 8.8), [runnable goroutines, many], size: 6pt)
  for i in range(6) {
    let x = 2.2 + i * 2.4
    cdraw.circle((x, 7.8), radius: 0.5, fill: luma(235), stroke: luma(120))
    cdraw.content((x, 7.8), [g#(i + 1)], size: 6pt)
  }
  cdraw.content((19.2, 7.8), [parked on channel send], size: 6pt)
  cdraw.line((4.6, 7.3), (5.0, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.8, 7.3), (13.5, 6.0), stroke: luma(100), mark: (end: ">"))
  let thread(x0, x1, run) = {
    cdraw.rect((x0, 5.0), (x1, 6.0), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 5.5), [#run], size: 6pt)
  }
  thread(2.0, 7.0, "thread 1: g3")
  cdraw.rect((7.2, 5.15), (8.8, 5.85), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((8.0, 5.5), [q1], size: 6pt)
  cdraw.line((9.0, 5.5), (10.0, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.2, 6.6), [steal], size: 6pt)
  cdraw.rect((10.0, 5.15), (11.6, 5.85), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((10.8, 5.5), [q2], size: 6pt)
  thread(11.8, 16.8, "thread 2: g5")
  cdraw.content((5.0, 4.05), [channel park: the g parks,], size: 6pt)
  cdraw.content((5.0, 2.85), [the thread runs another g], size: 6pt)
  cdraw.content((16.0, 4.05), [syscall: the thread enters], size: 6pt)
  cdraw.content((16.0, 2.85), [the kernel; the runtime], size: 6pt)
  cdraw.content((16.0, 1.65), [spins another], size: 6pt)
})

Go 1.26 added scheduler observability rather than a new policy:
`runtime/metrics` gained goroutine counts by state, threads known
to the runtime, and total goroutines created, which is what the
probes of #xref-to("go", "runtime") render live.

== the garbage collector, and 1.26's green tea [DRILL]

The baseline answer: go's gc is concurrent, tri-color mark and
sweep, non-generational, with sub-millisecond stop-the-world pauses
at both ends of the cycle. It tunes by pacing, `GOGC` and now
`GOMEMLIMIT`, rather than by generations, and escape analysis is
the compiler's part, keeping what it can on the stack.

The 1.26 fact worth citing: the green tea collector, experimental
in 1.25, is the default in 1.26, with the release notes claiming a
10 to 40 percent reduction in gc overhead for gc-heavy programs,
and about ten percent more on recent intel and amd cores because
small-object scanning uses vector instructions. The mechanism to
name when asked: green tea does its small-object scanning in
cache-friendly batches interleaved through the mark cycle, work
chosen for memory locality, which is where the overhead reduction
comes from. The opt-out is `GOEXPERIMENT=nogreenteagc`, and it is
scheduled for removal in 1.27, which is the sentence that makes it
real. The same notes add
an experimental goroutine leak detector under
`GOEXPERIMENT=goroutineleakprofile`, the gc-reachability idea: a
goroutine blocked on a channel nothing else can reach can never
wake.

#diagram([tri-color mark and sweep, the green tea default timeline], length: 13pt, {
  // above: one gc cycle; below: the 1.25 to 1.27 green tea timeline
  let cyc(x0, x1, t) = {
    cdraw.rect((x0, 6.4), (x1, 7.3), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 6.85), [#t], size: 6pt)
  }
  cyc(1.8, 8.0, "stw, mark begins")
  cyc(9.2, 15.4, "concurrent mark")
  cyc(16.6, 22.8, "sweep, stw <1ms")
  cdraw.line((8.0, 6.85), (9.2, 6.85), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.4, 6.85), (16.6, 6.85), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.7, 7.3), (19.7, 8.0), (4.9, 8.0), (4.9, 7.35), stroke: luma(160), mark: (end: ">"))
  cdraw.content((12.3, 8.45), [pacing: GOGC and GOMEMLIMIT], size: 6pt)
  cdraw.line((1.5, 3.6), (22.5, 3.6), stroke: luma(100), mark: (end: ">"))
  for x in (5.0, 12.0, 19.0) {
    cdraw.circle((x, 3.6), radius: 0.1, fill: luma(60))
  }
  cdraw.content((5.0, 4.15), [go 1.25], size: 6.5pt)
  cdraw.content((12.0, 4.15), [go 1.26], size: 6.5pt)
  cdraw.content((19.0, 4.15), [go 1.27], size: 6.5pt)
  cdraw.content((5.0, 2.95), [experimental], size: 6pt)
  cdraw.content((12.0, 2.95), [default; opt out via], size: 6pt)
  cdraw.content((12.0, 1.75), [GOEXPERIMENT=nogreenteagc], size: 6pt)
  cdraw.content((19.0, 2.95), [opt-out removed], size: 6pt)
  cdraw.content((12.0, 0.45), [10-40 percent less gc overhead for gc-heavy programs], size: 6pt)
})

== concurrent patterns: pool, pipeline, cancellation [EWC]

The worker pool with context cancellation and first-error-wins is
the pattern interviews mean by "how would you process a queue":

#listing("interview-repertoire/samples/ch15-go/patterns.go", first: 9, last: 60, caption: [fixed workers, a jobs channel, cancel on first error, wait, report])

#diagram([the pool: fixed workers, first error cancels, wait orders shutdown], length: 13pt, {
  // feed pushes into the jobs channel, three workers drain, ctx cancels on first error
  cdraw.rect((0.8, 4.2), (3.0, 5.2), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((1.9, 4.7), [feed], size: 6.5pt)
  cdraw.rect((3.4, 3.4), (4.8, 6.2), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((4.1, 6.55), [jobs], size: 6pt)
  for i in range(3) {
    let y = 5.4 - i * 1.1
    cdraw.rect((5.6, y), (9.0, y + 0.8), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((7.3, y + 0.4), [worker #(i + 1)], size: 6.5pt)
    cdraw.line((4.8, y + 0.4), (5.6, y + 0.4), stroke: luma(100), mark: (end: ">"))
    cdraw.line((9.0, y + 0.4), (11.2, y + 0.4), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.line((3.0, 4.7), (3.4, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.2, 3.4), (14.2, 6.2), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((12.7, 4.8), [results], size: 6.5pt)
  // the error path: first failure drops out the bottom, becomes the only error
  cdraw.line((7.3, 3.2), (7.3, 2.2), (10.8, 2.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.8, 1.8), (16.4, 2.6), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((13.6, 2.2), [first error wins], size: 6pt)
  // the cancellation spine
  cdraw.rect((4.8, 6.9), (10.2, 7.6), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((7.5, 7.25), [ctx, cancel], size: 6pt)
  cdraw.line((4.8, 7.25), (2.1, 7.25), (2.1, 5.25), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((7.5, 6.9), (7.5, 6.25), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((3.4, 7.55), [cancel], size: 6pt)
  cdraw.content((19.3, 5.5), [ctx cancel reaches], size: 6pt)
  cdraw.content((19.3, 4.3), [feed and workers], size: 6pt)
  cdraw.content((19.3, 3.1), [wg.Wait orders shutdown], size: 6pt)
})

The three tests cover the healthy path, the error path, and the
pre-canceled context, and the narration is the structure: the feed
loop selects on the context while pushing, workers drain until the
channel closes, `once` makes the first error the only one, and
`wg.Wait` orders shutdown. The fan-out fan-in beside it preserves
input order by writing to indexed slots, which is the counterpoint
to "results arrive whenever".

== closures and the loop variable [EWC]

Since go 1.22, each loop iteration owns its own copy of the loop
variable, so closures spawned inside the loop see their own pass.
The demo returns exactly `[0 1 2 3 4]` where pre-1.22 go returned
five copies of the final value, and that history is worth
volunteering, because interview questions written before 1.22
expect the gotcha answer:

#listing("interview-repertoire/samples/ch15-go/patterns.go", first: 62, last: 74, caption: [per-iteration capture, the 1.22 semantics])

#diagram([one shared binding against per-iteration copies, the 1.22 fix], length: 13pt, {
  // left: five closures on one cell; right: five cells, one per closure
  cdraw.content((5.0, 8.8), [before 1.22], size: 6.5pt)
  cdraw.rect((3.9, 6.5), (6.1, 7.3), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((5.0, 6.9), [i], size: 6.5pt)
  for x in (1.5, 3.25, 5.0, 6.75, 8.5) {
    cdraw.rect((x - 0.75, 4.9), (x + 0.75, 5.7), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x, 5.3), [f], size: 6.5pt)
    cdraw.line((x, 5.7), (5.0, 6.5), stroke: luma(120), mark: (end: ">"))
  }
  cdraw.content((5.0, 4.0), [prints 4 4 4 4 4], size: 6.5pt)
  cdraw.content((5.0, 2.8), [one shared binding], size: 6pt)
  cdraw.content((5.0, 1.6), [the final value wins], size: 6pt)
  cdraw.content((16.5, 8.8), [since 1.22], size: 6.5pt)
  for (x, v) in ((12.3, "0"), (14.2, "1"), (16.1, "2"), (18.0, "3"), (19.9, "4")) {
    cdraw.rect((x - 0.8, 6.5), (x + 0.8, 7.3), fill: luma(205), stroke: luma(120), radius: 0.02)
    cdraw.content((x, 6.9), [#v], size: 6.5pt)
    cdraw.rect((x - 0.75, 4.9), (x + 0.75, 5.7), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x, 5.3), [f], size: 6.5pt)
    cdraw.line((x, 5.7), (x, 6.5), stroke: luma(120), mark: (end: ">"))
  }
  cdraw.content((16.5, 4.0), [prints 0 1 2 3 4], size: 6.5pt)
  cdraw.content((16.5, 2.8), [each iteration owns], size: 6pt)
  cdraw.content((16.5, 1.6), [its own copy], size: 6pt)
})

== generics and their constraint vocabulary [EWC]

Type parameters with a real constraint, a generic cache over
`comparable` keys, and a helper that would have been duplicated
per-type before 1.18:

#listing("interview-repertoire/samples/ch15-go/generics.go", first: 5, last: 25, caption: [an ordered constraint sum, a locked generic cache])

#diagram([constraints are type sets: ordered, comparable, methods], length: 13pt, {
  // each constraint names the set of types allowed to fill the parameter
  let cell(x0, y, x1, t) = {
    cdraw.rect((x0, y), (x1, y + 0.8), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, y + 0.4), [#t], size: 6pt)
  }
  cdraw.content((3.6, 7.4), [cmp.Ordered], size: 6.5pt)
  cell(6.6, 7.0, 9.0, "int")
  cell(9.2, 7.0, 12.4, "float64")
  cell(12.6, 7.0, 15.8, "string")
  cdraw.content((3.6, 5.2), [comparable], size: 6.5pt)
  cdraw.content((3.6, 4.05), [(map-key types)], size: 6pt)
  cell(6.6, 4.8, 9.0, "bool")
  cell(9.2, 4.8, 13.0, "numbers")
  cell(13.2, 4.8, 17.0, "pointers")
  cell(17.2, 4.8, 21.0, "channels")
  cell(6.6, 3.7, 10.2, "arrays")
  cell(10.4, 3.7, 18.2, "comparable structs")
  cdraw.content((3.6, 1.8), [any interface], size: 6.5pt)
  cell(6.6, 1.4, 17.6, "the types with those methods")
  cdraw.content((11.0, 0.3), [a constraint names the set of types that may fill it], size: 6pt)
})

The follow-up that separates practitioners: constraints are type
sets, `cmp.Ordered` is a named set, `comparable` is exactly the
types usable as map keys, and a constraint can be any interface,
including methods. Generics do not replace interfaces, they
parametrize data structures and algorithms, interfaces remain the
boundaries.

== context, timeouts, and errors as values [EWC]

Timeouts belong to the caller and travel in the context. Error
wrapping is `%w`, inspection is `errors.Is` and `errors.As`, and
go 1.26 adds `errors.AsType`, the generic one-expression form of
`As`:

#listing("interview-repertoire/samples/ch15-go/context.go", first: 29, last: 62, caption: [a typed error, %w wrapping, errors.As beside the 1.26 AsType])

#diagram([errors chain through %w, timeouts travel down the context], length: 13pt, {
  // left: the wrap chain with the walk down its right side; right: the ctx flow
  let errbox(y, t, fill: luma(235)) = {
    cdraw.rect((1.0, y), (7.5, y + 0.8), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((4.25, y + 0.4), [#t], size: 6pt)
  }
  errbox(6.6, "service: get user")
  errbox(4.9, "repo: query user")
  errbox(3.2, "*TimeoutError", fill: luma(205))
  cdraw.line((4.25, 6.6), (4.25, 5.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.1, 6.15), [%w], size: 6pt)
  cdraw.line((4.25, 4.9), (4.25, 4.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.1, 4.4), [%w], size: 6pt)
  cdraw.line((8.0, 7.0), (8.0, 3.65), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((11.0, 5.3), [Is / As / AsType], size: 6pt)
  cdraw.rect((13.5, 6.6), (19.5, 7.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((16.5, 7.0), [caller, ctx 50ms], size: 6pt)
  cdraw.line((16.5, 6.6), (16.5, 5.65), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.5, 4.8), (19.5, 5.6), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((16.5, 5.2), [service(ctx)], size: 6pt)
  cdraw.line((16.5, 4.8), (16.5, 3.85), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.5, 3.0), (19.5, 3.8), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((16.5, 3.4), [query(ctx)], size: 6pt)
  cdraw.content((16.5, 2.2), [one deadline, set by the caller,], size: 6pt)
  cdraw.content((16.5, 1.0), [travels down, never set inside], size: 6pt)
})

The suite proves both extraction paths find the typed cause and
that a foreign error returns false, and `ChainTimeout` pins the
message shape production logs want, operation name first, deadline
cause inside.

== the singleton under contention [TDD]

`sync.Once` is the whole answer: one construction, however many
goroutines race for it. The test runs a swarm of 64 through a
start gate and asserts every slot received the same pointer with
`ID == 1`:

#listing("interview-repertoire/samples/ch15-go/once.go", first: 22, last: 37, caption: [once.Do builds, everyone shares the result])

#diagram([once.Do: one build, every caller shares the result], length: 13pt, {
  // cold to building on the first Do, everyone else waits, done shares one pointer
  let st(x0, x1, t) = {
    cdraw.rect((x0, 4.6), (x1, 5.4), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 5.0), [#t], size: 6.5pt)
  }
  st(1.6, 4.6, "cold")
  st(7.8, 11.8, "building")
  st(15.0, 18.0, "done")
  cdraw.line((4.6, 5.0), (7.8, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.2, 5.55), [Do runs], size: 6pt)
  cdraw.line((11.8, 5.0), (15.0, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.4, 5.55), [returns], size: 6pt)
  // the swarm waits on building, everyone reads the same built value from done
  for (x0, x1) in ((7.6, 9.0), (9.8, 9.8), (12.0, 10.6)) {
    cdraw.line((x0, 3.0), (x1, 4.6), stroke: luma(120), mark: (end: ">"))
  }
  cdraw.content((9.8, 2.3), [63 more Dos wait], size: 6pt)
  for (x0, x1) in ((15.6, 15.0), (16.5, 16.5), (17.4, 18.0)) {
    cdraw.line((x0, 4.6), (x1, 3.4), stroke: luma(120), mark: (end: ">"))
  }
  cdraw.content((20.6, 3.9), [same pointer], size: 6pt)
  cdraw.content((20.6, 2.7), [for every caller], size: 6pt)
  cdraw.content((10.0, 1.3), [64 goroutines through a start gate, -race clean], size: 6pt)
})

Run under `go test -race`, the same test also proves no data race
in the lazy path, and it passed under the detector in this tree.
The concession to volunteer: the once-singleton is process-wide
state, tests reset it through `Reset`, and real code prefers
explicit construction at main with the dependency passed down,
which is the `go-testing` chapter's whole thesis.

sources: go 1.26 release notes at go.dev, green tea defaults,
goroutine leak detector experiment, scheduler metrics, and
errors.AsType, accessed 2026-09-09. Verified by `go vet` and
`go test` through `make verify`, 16 tests in `ch15-go`, plus the
race detector pass on the singleton test.
