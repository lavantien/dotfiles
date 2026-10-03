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

= concurrency

Go's pitch since launch: concurrency built into the language, not a
library bolted on. `go` starts work, channels move values between
it, `select` waits on many things at once, and the `sync` package
covers what channels should not. The sample package exercises each
primitive deterministically, no sleeps anywhere.

== goroutines

`go f(x)` runs `f` concurrently and forgets about it: no handle, no
result, no way to wait on the function itself. Every coordination
mechanism below exists because the `go` statement provides none. A
goroutine costs a few kilobytes of stack that grows and shrinks, so
hundreds of thousands are ordinary. The scheduler multiplexes them
onto `GOMAXPROCS` os threads with work stealing, and since go 1.14
goroutines yield preemptively, so a tight loop stops starving others,
and the scheduler underneath is chapter 9's subject.

#diagram([goroutines layer over the scheduler, the primitives add what go lacks], length: 13pt, {
  cdraw.rect((0.3, 3.1), (11.3, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.8), [goroutines], size: 6.5pt)
  cdraw.content((5.8, 5.7), [stacks start at 2 kb,], size: 6pt)
  cdraw.content((5.8, 4.7), [grow, so many 100k], size: 6pt)
  cdraw.content((5.8, 3.7), [of them are ordinary], size: 6pt)
  cdraw.rect((0.3, 0.0), (11.3, 2.8), fill: luma(222), radius: 0.02)
  cdraw.content((5.8, 2.3), [scheduler], size: 6.5pt)
  cdraw.content((5.8, 1.4), [#"GOMAXPROCS, work stealing,"], size: 6pt)
  cdraw.content((5.8, 0.4), [preemptive since 1.14], size: 6pt)
  cdraw.rect((0.3, -2.2), (11.3, -0.3), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, -0.8), [os threads], size: 6.5pt)
  cdraw.content((5.8, -1.8), [the m in m:n], size: 6pt)
  pane(12.7, 23.3, 7.4, [the go statement gives], [no handle, no result,], [no join to wait on])
  cdraw.content((18.0, 1.9), [wait for it: WaitGroup], size: 6pt)
  cdraw.content((18.0, 0.8), [take its result: channel], size: 6pt)
  cdraw.content((18.0, -0.3), [stop it early: context], size: 6pt)
})

== channels

A channel is a typed conduit with a capacity. Capacity zero is a
rendezvous, the send completes only when a receiver takes the value,
which is synchronization, not just transport:

#listing("go/samples/ch06/concurrency_test.go", first: 97, last: 116, caption: [unbuffered handoff, sender and receiver meet])

Capacity n is a buffer: n sends proceed without a receiver, and the
n+1st blocks until a receive frees a slot. The capstone in chapter 34
caps its simultaneous fetches with a buffered `chan struct{}` of
capacity workers, because a buffered channel used this way is the
semaphore pattern.

Closing is the completion signal. A receive on a closed channel
returns immediately, the zero value and `false` from the comma ok
form, and `range` drains then terminates:

#listing("go/samples/ch06/concurrency.go", first: 77, last: 95, caption: [drain semantics, and the nil channel rule])

A nil channel blocks forever. That sounds like a bug and is a
feature: a select case whose channel is nil is switched off, so a
state machine disables a direction by nil ing its channel. Sends on
closed channels panic, a double close panics too, and only the sender
should close.

#diagram([channel semantics in nine cells: state against operation], length: 13pt, {
  cdraw.content((6.65, 7.7), [send], size: 6.5pt)
  cdraw.content((13.35, 7.7), [receive], size: 6.5pt)
  cdraw.content((20.05, 7.7), [close], size: 6.5pt)
  let cell(xc, ytop, l1, l2, fill) = {
    cdraw.rect((xc - 3.15, ytop - 2.4), (xc + 3.15, ytop), fill: fill, radius: 0.02)
    cdraw.content((xc, ytop - 0.8), [#l1], size: 6pt)
    if l2 != none { cdraw.content((xc, ytop - 1.8), [#l2], size: 6pt) }
  }
  cdraw.content((1.75, 6.0), [open], size: 6.5pt)
  cell(6.65, 7.2, [blocks until], [a receiver], luma(235))
  cell(13.35, 7.2, [blocks until], [a sender], luma(235))
  cell(20.05, 7.2, [completion signal], [to every reader], luma(235))
  cdraw.content((1.75, 3.4), [nil], size: 6.5pt)
  cell(6.65, 4.6, [blocks forever,], [case disabled], luma(225))
  cell(13.35, 4.6, [blocks forever,], [case disabled], luma(225))
  cell(20.05, 4.6, [panic], none, luma(205))
  cdraw.content((1.75, 0.8), [closed], size: 6.5pt)
  cell(6.65, 2.0, [panic], none, luma(205))
  cell(13.35, 2.0, [zero, false,], [range ends], luma(235))
  cell(20.05, 2.0, [panic again], [double close], luma(205))
  cdraw.content((11.8, -1.2), [only the sender closes: closing is broadcast, not cleanup], size: 6pt)
})

#callout("pitfall", "who closes", [
  The writer closes, never the reader, and with many writers a
  coordinating `WaitGroup` closes once after all finish, the pattern
  `FanInSum` below shows. Closing is broadcast, not cleanup: it
  means no more values are coming.
])

== select

`select` waits on many channel operations and takes one that is
ready, random among the ready:

#listing("go/samples/ch06/concurrency.go", first: 100, last: 107, caption: [first delivery wins])

With `default` it becomes a non blocking attempt, and `select {}`
blocks forever. Timeouts read naturally, `case <-time.After(sec)`,
and those timer channels are unbuffered since go 1.23, with no
`asynctimerchan` compat flag remaining in 1.27.

#flow(
  [select waits on every case, runs one ready case at random],
  node((0, 0), [#"case <-ch1"]),
  node((0, 1.2), [#"case <-ch2"]),
  node((0, 2.4), [#"case <-time.After(s)"]),
  edge((0.7, 0), (1.7, 1.0), "-|>"),
  edge((0.7, 1.2), (1.7, 1.2), "-|>"),
  edge((0.7, 2.4), (1.7, 1.4), "-|>"),
  node((2.6, 1.2), [select]),
  edge((3.5, 1.2), (4.7, 0.5), "-|>", label: [one ready]),
  node((5.6, 0.5), [that case runs,#linebreak()chosen at random]),
  edge((3.5, 1.2), (4.7, 2.3), "-|>", label: [none ready]),
  node((5.6, 2.3), [default runs, else#linebreak()#"select {} blocks"]),
)

== patterns

The pipeline: each stage owns its output channel, closes it when its
input drains, and `range` carries termination downstream. Its input
is an `iter.Seq[int]`, a function iterator, chapter 8's range over
func form:

#listing("go/samples/ch06/concurrency.go", first: 16, last: 41, caption: [gen, square, consume, close chains])

#diagram([the pipeline: each stage owns its output channel and closes it], length: 13pt, {
  let stage(x0, title, l1, l2) = {
    cdraw.rect((x0, 3.1), (x0 + 4.9, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.45, 5.9), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.45, 4.7), [#l1], size: 6pt)
    cdraw.content((x0 + 2.45, 3.7), [#l2], size: 6pt)
  }
  stage(0.3, [gen], [emits values,], [closes its out])
  cdraw.line((5.35, 4.8), (5.95, 4.8), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [square], [ranges input,], [closes own out])
  cdraw.line((11.15, 4.8), (11.75, 4.8), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [consumer], [ranges squared,], [ends on close])
  cdraw.content((11.8, 1.9), [close arrives as end of input, so range terminates], size: 6pt)
  cdraw.content((11.8, 0.8), [one closer per channel, and the sender is always it], size: 6pt)
})

The fan in: workers compute partials, a `WaitGroup` tracks them, one
closer goroutine shuts the results channel, the consumer ranges.
Since go 1.25 `wg.Go(f)` both starts and tracks, replacing the
`Add(1)` plus `go func` with `defer wg.Done` dance:

#listing("go/samples/ch06/concurrency.go", first: 43, last: 75, caption: [fan in with a single closer])

#flow(
  [fan in: many producers, one close, one consumer],
  node((0, 0), [workers sum partials]),
  edge("-|>"),
  node((1, 0), [results channel]),
  edge("-|>"),
  node((2, 0), [wg.Wait, then close]),
  edge("-|>"),
  node((3, 0), [range totals]),
)

== the sync package

Channels pass ownership of data. When data stays put and many
goroutines touch it, use a lock:

#listing("go/samples/ch06/concurrency.go", first: 111, last: 126, caption: [mutex guarded counter, zero value usable])

The mutex embeds by value and its zero state is unlocked, so
`LockedCounter{}` works without a constructor, the zero value theme
of chapter 3 again. `sync.Once` runs a function exactly once under
concurrency, the standard lazy initialization:

#listing("go/samples/ch06/concurrency.go", first: 128, last: 139, caption: [once, with an atomic count as proof])

For a single word, `sync/atomic` skips the lock, and `atomic.Int64`
with `Add` and `Load` is the type to use, the test runs a thousand
concurrent adds and reads 1000. The memory model guarantee behind all
of this is happens before: a send happens before its receive
completes, an unlock happens before the next lock. A data race is two
goroutines touching the same memory, at least one access a write, and
no happens before edge between them. Go's race detector,
`go test -race`, enforces the discipline at run time, worth running
on every test suite that touches this chapter's material.

#diagram([channels move ownership, the sync package guards data that stays put], length: 13pt, {
  pane(0.3, 7.4, 6.8, [mutex], [guards data in place], [zero value: unlocked])
  pane(8.0, 15.1, 6.8, [once], [runs the function], [exactly one time])
  pane(15.7, 22.8, 6.8, [atomic], [one word, no lock], [#"Int64 Add and Load"])
  cdraw.content((11.5, 2.5), [underneath: happens before], size: 6.5pt)
  cdraw.content((11.5, 1.4), [send before receive, unlock before next lock], size: 6pt)
  cdraw.content((11.5, 0.3), [#"go test -race enforces it at run time"], size: 6pt)
})

Stopping work early is context's job, the promise the goroutines
diagram made. A `context.Context` carries cancellation: `Done` is a
channel closed on cancel, `Err` reports `context.Canceled`, and
`context.WithCancel` creates one from a parent. The capstone's crawler
in chapter 34 stops its walk through exactly this channel.

sources: go.dev/ref/spec and go.dev/doc/effective_go, concurrency
sections, go 1.27 release notes for wg.Go lineage and timer channel
cleanup, accessed 2026-09-08. Verified by `go/samples/ch06` tests
under `go test` and `go vet`.
