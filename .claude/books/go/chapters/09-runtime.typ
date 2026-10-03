#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= runtime

Go programs run on a small operating system, the runtime: a
scheduler multiplexing goroutines onto threads, a concurrent garbage
collector, growing stacks, and a profiler wired into every event.
None of it needs configuration to work, and the realistic skill is
knowing which knob exists and what it trades.

== the scheduler

The model is M:N, many goroutines onto fewer os threads, with three
players: `G` the goroutine, `M` the os thread, `P` the processor
slot that owns a run queue. `GOMAXPROCS` sets the number of P slots
and defaults to the machine's core count. Work steals balance the
queues, network io integrates through netpoller so a goroutine
waiting on a socket parks its G and frees the thread, and since go
1.14 preemption is async, a tight loop no longer starves the
scheduler:

#listing("go/samples/ch09/runtime.go", first: 13, last: 16, caption: [the read form, argument zero])

#flow(
  [G, M, P: goroutines wait in P run queues, M threads execute them, idle queues steal],
  node((0, 0), [P 0, G queue]),
  node((2.6, 0), [P 1, G queue]),
  node((5.2, 0), [P 2, G queue]),
  node((1.3, 1.6), [M, os thread]),
  node((3.9, 1.6), [M, os thread]),
  edge((0, 0), (2.6, 0), "<->", bend: 20deg, label: [work stealing]),
  edge((0, 0), (1.3, 1.6), "-|>", label: [executes]),
  edge((2.6, 0), (3.9, 1.6), "-|>"),
  edge((5.2, 0), (3.9, 1.6), "-|>", label: [executes]),
)

Goroutine stacks start at 2 kib and grow by copying, up to the 1 gib
per-goroutine ceiling (`debug.SetMaxStack` moves it), and past the cap
the runtime kills the program with a fatal stack overflow error:

#listing("go/samples/ch09/runtime.go", first: 36, last: 41, caption: [ten thousand frames deep, no configuration])

The test recurses 10000 deep and sums to 50005000. The cost model
that follows from cheap stacks plus small allocations: prefer
passing values, let escape analysis keep them on stack frames, and
reach for object pools only when a profile says so.

== the garbage collector

Concurrent tricolor mark and sweep, non generational, non
compacting. The pacer targets a heap ratio: `GOGC=100`, the default,
collects when the heap doubles since the last live set. Two knobs
matter in production, `GOGC` for the ratio and `GOMEMLIMIT` for a
soft memory ceiling, and the api route to the first is
`debug.SetGCPercent`:

#listing("go/samples/ch09/runtime.go", first: 19, last: 33, caption: [forced collection, count, and live heap])

`runtime.GC` forces a full cycle, `NumGC` counts them, `HeapAlloc`
is the live heap the collector just measured. There are no
generations and no separate large-object heap: objects over 32 kib
skip the size classes and come from the page allocator, a split
chapter 10 walks. Go 1.27 shaved up to 30 percent off sub 80 byte
allocations through size specialized allocation routines, a runtime
change invisible to code but visible in allocation profiles.

#diagram([the pacer: gogc collects when the heap doubles, gememlimit draws the ceiling], length: 13pt, {
  cdraw.line((1.2, 0.6), (15.0, 0.6), stroke: luma(100))
  cdraw.line((1.2, 0.6), (1.2, 6.6), stroke: luma(100))
  cdraw.content((8.1, 0.1), [allocation, time], size: 6pt)
  cdraw.content((0.6, 6.6), [heap], size: 6pt)
  cdraw.line((1.2, 1.7), (4.0, 3.0), stroke: luma(60))
  cdraw.line((4.0, 3.0), (4.0, 1.9), stroke: luma(60))
  cdraw.line((4.0, 1.9), (7.2, 3.6), stroke: luma(60))
  cdraw.line((7.2, 3.6), (7.2, 2.2), stroke: luma(60))
  cdraw.line((7.2, 2.2), (10.8, 4.3), stroke: luma(60))
  cdraw.line((10.8, 4.3), (10.8, 2.6), stroke: luma(60))
  cdraw.line((10.8, 2.6), (14.8, 5.1), stroke: luma(60))
  cdraw.line((1.2, 5.8), (15.0, 5.8), stroke: luma(140), dash: "dashed")
  cdraw.content((4.8, 4.9), [each peak is twice], size: 6pt)
  cdraw.content((4.8, 3.9), [the live set: gc], size: 6pt)
  cdraw.content((11.6, 6.5), [GOMEMLIMIT, soft ceiling], size: 6pt)
  pane(16.2, 23.3, 6.6, [the collector], [tricolor mark, sweep], [concurrent, non], [generational, non], [compacting])
  cdraw.content((7.5, -0.9), [live set measured at each collection, GOGC draws the ratio], size: 6pt)
})

#callout("note", "what to actually do about the gc", [
  Defaults first. If a service needs tighter memory, `GOMEMLIMIT`
  answers ceiling questions better than `GOGC` tuning, and the
  collection that hurts is usually caused by allocation rate, which
  `pprof` heap profiles attribute by allocation site. Escape
  analysis, `go build -gcflags=-m`, explains why a value escaped.
])

== profiling and debug

Every profile hangs off `runtime/pprof`, cpu, heap, goroutine,
block, mutex, threadcreate, and `net/http/pprof` serves them over
http on a debug port. Go 1.27 adds `goroutineleak`, a detector for
goroutines blocked on primitives that no runnable goroutine can
reach, promoted from an experiment into the standard profile set:

#listing("go/samples/ch09/runtime.go", first: 46, last: 48, caption: [the 1.27 leak profile, registered and queryable])

#diagram([the profile set, one registry, two ways in], length: 13pt, {
  let cell(xc, ytop, text, fill) = {
    cdraw.rect((xc - 2.3, ytop - 1.0), (xc + 2.3, ytop), fill: fill, radius: 0.02)
    cdraw.content((xc, ytop - 0.5), [#text], size: 6pt)
  }
  cell(3.0, 7.0, [cpu], luma(235))
  cell(8.2, 7.0, [heap], luma(235))
  cell(13.4, 7.0, [goroutine], luma(235))
  cell(18.6, 7.0, [block], luma(235))
  cell(3.0, 5.6, [mutex], luma(235))
  cell(8.2, 5.6, [threadcreate], luma(235))
  cell(13.4, 5.6, [goroutineleak], luma(205))
  cdraw.content((17.9, 4.9), [new in 1.27], size: 6pt)
  pane(0.3, 11.3, 3.7, [runtime/pprof], [starts a profile,], [writes it to a file])
  pane(12.7, 23.3, 3.7, [net/http/pprof], [serves every profile], [over http, debug port])
  cdraw.content((11.8, -0.3), [labels from pprof.Do reach tracebacks in 1.27], size: 6pt)
})

The test asserts the profile exists, which is also a version check:
on 1.26 this lookup returns nil and the test fails. Tracebacks
gained goroutine labels in 1.27, so pprof labels set with
`pprof.Do` appear in stack dumps, and the `GODEBUG` mechanism gates
compatibility switches per module from the `go.mod` `godebug`
directive. The remaining 1.27 runtime note for application code: the
asynctimerchan compatibility period ended, timer channels from
`time.After` and friends are unbuffered with no opt out, which the
concurrency chapter's select patterns already assume.

== the goroutine lifecycle

A goroutine starts with `go`, runs until its function returns, and
nothing observes that return. Lifecycle management is explicit:
`WaitGroup` for completion, channels for results, `context` for
cancellation, and `runtime.NumGoroutine` plus the goroutine profile
for leaks after the fact. The leak profile automates what teams did
by diffing goroutine dumps, blocked forever on a send nobody
receives, a mutex nobody releases, and it flags exactly those
goroutines unreachable from any live work.

#diagram([spawned to returned with nobody watching, the leak is the blocked-forever case], length: 13pt, {
  let stage(x0, title, l1, l2) = {
    cdraw.rect((x0, 3.8), (x0 + 4.9, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.45, 6.4), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.45, 5.2), [#l1], size: 6pt)
    cdraw.content((x0 + 2.45, 4.2), [#l2], size: 6pt)
  }
  stage(0.3, [spawned], [go f(x), cheap,], [no handle yet])
  cdraw.line((5.35, 5.85), (5.95, 5.85), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [running], [until its function], [returns])
  cdraw.line((11.15, 5.85), (11.75, 5.85), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [blocked], [on a channel or], [a lock])
  cdraw.line((16.95, 5.85), (17.55, 5.85), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [returned], [gone, nobody], [observes it])
  cdraw.line((14.35, 3.6), (14.35, 3.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((11.6, 2.0), (17.1, 3.3), fill: luma(205), radius: 0.02)
  cdraw.content((14.35, 2.65), [blocked forever: a leak], size: 6pt)
  cdraw.content((5.8, 2.65), [the leak profile flags exactly], size: 6pt)
  cdraw.content((5.8, 1.55), [these, unreachable from live work], size: 6pt)
  cdraw.content((11.8, 0.2), [the explicit tools: WaitGroup waits, channels deliver, context cancels], size: 6pt)
})

sources: go.dev/doc/diagnostics, pkg.go.dev/runtime and
runtime/debug for the `debug.SetMaxStack` 1 gib default, and the go
1.27 release notes runtime section, accessed 2026-09-08. Verified by
`go/samples/ch09` tests on go1.27.0, including the goroutineleak
profile presence check.
