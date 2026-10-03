#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= testing

Testing is a language feature in go the same way formatting is: one
command, one file convention, no framework choice to make. This
entire book's go verification is `go test ./...` plus `go vet`, and
this chapter's sample folder is a working demonstration of every
test kind the toolchain runs.

== the test function

A test is a function named `TestXxx` taking `*testing.T` in a
`_test.go` file. Table driven is the house style, a slice of cases
looped once, and subtests give each case a name:

#listing("go/samples/ch14/testing_test.go", first: 22, last: 35, caption: [subtests with parallel bodies])

The subtlety the test documents: `t.Parallel` pauses a subtest until
the parent's function body returns, so the parent cannot check
subtest results after its loop, each subtest asserts its own
outcome. Parallel tests share process cores through the same
scheduler as everything else, `go test -parallel` caps it.

Failures are `t.Error` to mark and continue, `t.Fatal` to stop the
test, both taking format strings, and `t.Helper` marks assertion
utilities so line numbers point at the caller.

#diagram([t.Parallel parks each subtest until the parent body returns], length: 13pt, {
  pane(0.3, 11.3, 7.6, [the parent loop], [#"t.Run(name, f) each turn"], [each body calls t.Parallel])
  let sub(x0, name) = {
    cdraw.rect((x0, 1.5), (x0 + 3.4, 2.7), fill: luma(222), radius: 0.02)
    cdraw.content((x0 + 1.7, 2.1), [#name], size: 6pt)
  }
  sub(0.3, [a: parked])
  sub(4.0, [b: parked])
  sub(7.7, [c: parked])
  cdraw.line((5.8, 1.2), (5.8, 0.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((9.4, 0.9), [parent body returns], size: 6pt)
  cdraw.rect((0.3, -1.2), (11.3, 0.5), fill: luma(205), radius: 0.02)
  cdraw.content((5.8, -0.35), [now every parked subtest runs], size: 6pt)
  pane(12.7, 23.3, 7.6, [the consequence], [the parent cannot check], [outcomes after its loop,], [each case asserts itself])
  cdraw.content((18.0, 1.7), [t.Error marks and continues,], size: 6pt)
  cdraw.content((18.0, 0.6), [t.Fatal stops the test], size: 6pt)
  cdraw.content((5.8, -2.3), [go test -parallel caps the shared cores], size: 6pt)
})

== examples are tests

A function named `ExampleXxx` with an `// Output:` comment is a
test that compares stdout:

#listing("go/samples/ch14/testing_test.go", first: 16, last: 20, caption: [the example doubles as documentation])

Examples fail when output drifts, which keeps documentation
executable, and godoc renders them beside the function they
demonstrate. `go doc -ex` lists them since 1.27.

#diagram([the example with an output comment is a stdout-comparing test], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [#"ExampleGreet"], [#"an // Output:" #linebreak() #"comment"])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [run it], [capture stdout])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [compare], [vs the comment])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [verdict], [drift fails it])
  pane(0.3, 11.3, 3.2, [godoc renders it], [beside the function it], [demonstrates, doc -ex too])
  cdraw.content((17.6, 2.5), [the comment is the assertion, so], size: 6pt)
  cdraw.content((17.6, 1.4), [documentation that cannot rot], size: 6pt)
})

== fuzzing

`FuzzXxx` functions declare a fuzz target with seed corpus entries,
`f.Add`:

#listing("go/samples/ch14/testing_test.go", first: 68, last: 81, caption: [seed corpus plus the property])

Plain `go test` runs the seeds, so the corpus is an ordinary table
test. `go test -fuzz=FuzzReverse` then generates inputs hunting for
the property to break, length preservation and double reverse
identity here, and failing discoveries land in the module's
`testdata/fuzz` corpus, committed so they become permanent
regression cases.

#diagram([seeds to mutation to property, failures become permanent cases], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [seed corpus], [#"f.Add(x, want)"])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [mutation], [mutates inputs])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [property], [holds or breaks])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [verdict], [breaks: saved])
  cdraw.line((20.3, 4.2), (20.3, 3.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((14.6, 1.8), (23.2, 3.3), fill: luma(205), radius: 0.02)
  cdraw.content((18.9, 2.55), [#"testdata/fuzz, committed"], size: 6pt)
  cdraw.content((5.8, 2.55), [plain go test runs the seeds,], size: 6pt)
  cdraw.content((5.8, 1.45), [an ordinary table test, and], size: 6pt)
  cdraw.content((5.8, 0.35), [every saved case a regression], size: 6pt)
})

== benchmarks

`BenchmarkXxx` with `*testing.B` measures, `b.Loop()` (go 1.24
onward) runs the body until the measurement is stable and resets
allocs per iteration, replacing the manual `for i := 0; i <
b.N; i++`:

#listing("go/samples/ch14/testing_test.go", first: 83, last: 87, caption: [b.Loop, the modern harness])

`go test -bench=. -benchmem` reports throughput and allocations per
operation, and `pprof` profiles from chapter 9 attach with
`-cpuprofile` and `-memprofile` for the follow up question.

#diagram([b.Loop, the 1.24 harness that replaced the b.N loop], length: 13pt, {
  pane(0.3, 11.3, 6.8, [before 1.24], [#"for i := 0; i < b.N; i++"], [manual pacing, allocs], [counted by hand])
  cdraw.line((11.6, 4.0), (12.4, 4.0), stroke: luma(100), mark: (end: ">>"))
  pane(12.7, 23.3, 6.8, [1.24 onward], [#"for b.Loop() {"], [runs until stable,], [resets allocs per turn])
  cdraw.content((11.8, 0.6), [-benchmem reports both, pprof flags attach], size: 6pt)
})

== testing/synctest

Concurrency tests that sleep are flaky or slow. Go 1.25 stabilized
`testing/synctest`, a bubble of fake time where sleeps complete the
moment every goroutine in the bubble is durably blocked:

#listing("go/samples/ch14/testing_test.go", first: 37, last: 47, caption: [three hours pass in microseconds of real time])

`synctest.Test` opens the bubble, `synctest.Wait` blocks until
others park, and go 1.27 adds `synctest.Sleep`, the combination as
one call:

#listing("go/samples/ch14/testing_test.go", first: 49, last: 58, caption: [sleep plus wait, new in 1.27])

Inside a bubble, timers, channels, and goroutines interact on
deterministic fake time, which is how the two tests above pass
four hours of sleeping, three plus one, in microseconds of real
time. Pair it with `httptest.NewTestServer`, 1.27's socket free
server, and a full http pipeline tests deterministically in
memory.

#diagram([the synctest bubble: fake time advances only when everyone is parked], length: 13pt, {
  cdraw.rect((0.3, 4.3), (15.6, 7.2), fill: luma(240), radius: 0.02)
  cdraw.content((7.95, 6.75), [the bubble], size: 6.5pt)
  cdraw.content((2.6, 5.7), [#"g1 sleeps 3h"], size: 6pt)
  cdraw.content((8.2, 5.7), [#"g2 sleeps 1h"], size: 6pt)
  cdraw.line((2.6, 5.45), (2.6, 5.2), stroke: luma(100))
  cdraw.line((8.2, 5.45), (8.2, 5.2), stroke: luma(100))
  cdraw.line((0.9, 5.2), (15.0, 5.2), stroke: luma(100))
  cdraw.content((7.95, 4.75), [both parked: durable block], size: 6pt)
  cdraw.line((15.8, 5.2), (16.6, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((19.4, 6.3), [bubble time jumps], size: 6pt)
  cdraw.content((19.4, 5.2), [the full 3 hours], size: 6pt)
  cdraw.content((7.95, 3.4), [real time elapsed: microseconds], size: 6pt)
  pane(0.3, 11.3, 2.0, [the api], [#"synctest.Test opens it"], [Wait parks, 1.27 Sleep])
  cdraw.content((17.6, 1.6), [pairs with the in memory], size: 6pt)
  cdraw.content((17.6, 0.5), [test server: no sockets at all], size: 6pt)
})

#callout("note", "the whole verification chain", [
  `go test ./...` runs tests, examples, and seed corpora. `go vet
  ./...` runs the analyzers. `gofmt -l .` checks formatting. `go
  test -race ./...` finds data races at run time. This repo's
  `make verify-go` runs the first two for every go module it
  contains, and the race detector is one flag away, worth a local
  run on any package that touches chapter 6.
])

sources: pkg.go.dev/testing and testing/synctest, go.dev/blog on
the b.Loop harness and fuzzing, accessed 2026-09-08. Verified by
`go/samples/ch14`, 5 tests, 1 example, 1 fuzz target with 3 seeds,
1 benchmark, zero sleeps of real time.
