#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= stdlib tour 1: fmt, errors, slices, maps, cmp, time, slog

Half of go's day to day value is the standard library, and the bet it
makes is different from C\#'s: fewer packages, each a default you keep.
This tour covers the text and data plumbing every program touches.
The sample package for this chapter is deliberately test only, its
files call the stdlib directly, so every listing is a passing test.

== fmt

Formatting is one function family, `Sprintf`, `Fprintf`, `Errorf`,
sharing a verb language:

#listing("go/samples/ch12/stdlib_test.go", first: 14, last: 27, caption: [verbs, precision, index arguments])

`%v` is the value, `%+v` adds struct fields, `%#v` go syntax, `%q`
quotes strings and runes, `%T` prints the type, and indexed
arguments `%[1]s` reorder. The same verbs drive `log` and `fmt.Fscan`
in reverse.

#diagram([the verb grid, one language driving the whole fmt family], length: 13pt, {
  let verb(xc, ytop, v, desc) = {
    cdraw.rect((xc - 3.7, ytop - 2.0), (xc + 3.7, ytop), fill: luma(235), radius: 0.02)
    cdraw.content((xc, ytop - 0.7), [#v], size: 6.5pt)
    cdraw.content((xc, ytop - 1.5), [#desc], size: 6pt)
  }
  verb(4.1, 7.2, [#"%v"], [the value])
  verb(11.9, 7.2, [#"%+v"], [plus struct fields])
  verb(19.7, 7.2, [#"%#v"], [go syntax])
  verb(4.1, 5.0, [#"%q"], [quoted string, rune])
  verb(11.9, 5.0, [#"%T"], [the type])
  verb(19.7, 5.0, [#"%[1]s"], [index reorders args])
  cdraw.content((11.8, 2.3), [width and precision ride along: #"\"%6.2f\""], size: 6pt)
  pane(0.3, 11.3, 1.6, [one verb language], [#"Sprintf, Fprintf, Errorf"], [Fscan reads it in reverse])
  cdraw.content((17.8, 0.2), [log rides the same verbs], size: 6pt)
})

== slices and maps

Since go 1.21 the `slices` and `maps` packages replaced almost every
hand written loop, and since 1.23 they return iterators, functions
composable before anything materializes:

#listing("go/samples/ch12/stdlib_test.go", first: 30, last: 63, caption: [the toolkit plus the iterator trio])

#diagram([iterators compose before anything materializes], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [Values], [or maps.Keys])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [iter.Seq], [a function, lazy])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [compose], [Backward, Chunk])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [Sorted], [materializes])
  cdraw.content((11.8, 3.2), [nothing is copied until Sorted or a range runs it], size: 6pt)
  cdraw.content((11.8, 2.1), [Sort is pdqsort, SortStableFunc], size: 6pt)
  cdraw.content((11.8, 1.0), [when equal elements keep order], size: 6pt)
})
`Values` yields the elements as a lazy sequence, `Backward` yields
index and value from the end, `Chunk` streams fixed size windows, and
`maps.Keys` returns `iter.Seq`, so `for k := range maps.Keys(m)` walks
a map without copying its keys. Sorting is `slices.Sort` for ordered
elements and `SortFunc` with `cmp.Compare` for the rest, both pattern
defeating quicksort and not stable, and `slices.SortStableFunc` takes
the same comparison function when equal elements must keep order:

#listing("go/samples/ch12/stdlib_test.go", first: 65, last: 79, caption: [clone isolates, keys iterates, deletefunc filters])

`maps.Clone` is the shallow copy, `maps.Copy` merges, and
`maps.DeleteFunc` filters in place. The `cmp` package holds two
functions, `Compare` for three way ordering and `Or` for first
nonzero default, the most used one liner in modern go:

#listing("go/samples/ch12/stdlib_test.go", first: 82, last: 88, caption: [cmp.Or replaces the ternary go refuses to grow])

== time

`time.Time` is a value with a location, `time.Duration` is an int64
of nanoseconds, and the constants `time.Second` and friends make the
arithmetic readable. Parsing and formatting go through layout
strings, and the two canonical ones are constants:

#listing("go/samples/ch12/stdlib_test.go", first: 91, last: 106, caption: [parse, format, add, sub, compare])

The reference layout is `2006-01-02 15:04:05`, monotonic counting
from a zero time, and `time.Since(t)` reads the monotonic clock so
duration math never jumps when the wall clock adjusts. `Timer`
channels are unbuffered since go 1.23 with no compat flag remaining
in 1.27, and `CutLast`, new in `strings` and `bytes`, splits around
the final separator.

#diagram([two clocks in one value: wall for people, monotonic for math], length: 13pt, {
  cdraw.rect((0.3, 3.4), (11.3, 7.2), fill: luma(240), radius: 0.02)
  cdraw.content((5.8, 6.7), [a time.Time], size: 6.5pt)
  cdraw.rect((0.9, 5.3), (10.7, 6.2), fill: luma(225), radius: 0.02)
  cdraw.content((5.8, 5.75), [wall clock, location], size: 6pt)
  cdraw.rect((0.9, 4.0), (10.7, 4.9), fill: luma(205), radius: 0.02)
  cdraw.content((5.8, 4.45), [monotonic strip], size: 6pt)
  cdraw.content((5.8, 3.0), [Since(t) subtracts monotonic:], size: 6pt)
  cdraw.content((5.8, 1.9), [wall jumps never reach the math], size: 6pt)
  pane(12.7, 23.3, 7.2, [the layout string], [#"2006-01-02 15:04:05"], [the reference time's digits], [name their own places])
  cdraw.content((18.0, 2.15), [duration is an int64 of nanoseconds,], size: 6pt)
  cdraw.content((18.0, 1.05), [constants like time.Second keep sums readable], size: 6pt)
})

== slog

Structured logging arrived in go 1.22 and ended the logging library
wars by being good enough to keep. A `Logger` wraps a `Handler`,
handlers choose the format, and attributes are key value pairs:

#listing("go/samples/ch12/stdlib_test.go", first: 109, last: 137, caption: [text handler, typed attrs, with, levels])

`TextHandler` writes `key=value` lines, `JSONHandler` writes json,
levels gate at debug, info, warn, error, and the test asserts the
rendered lines, the `250ms` duration included. `Logger.With`
returns a child carrying bound attributes, the replacement for
context fields in logging libraries, and `slog.SetDefault` wires the
package level `slog.Info` calls to the same handler. The handler
interface is public, so one custom handler serves a whole service,
and the `slog.HandlerOptions` level and source toggles cover the
rest.

#diagram([logger wraps handler, with binds a child, attrs are the payload], length: 13pt, {
  cdraw.rect((0.3, 5.2), (11.3, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.5), [Logger], size: 6.5pt)
  cdraw.content((5.8, 5.5), [level, attrs, the call], size: 6pt)
  cdraw.line((5.8, 5.0), (5.8, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 2.6), (11.3, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 3.7), [Handler], size: 6.5pt)
  cdraw.rect((0.9, 2.8), (5.4, 3.5), fill: luma(205), radius: 0.02)
  cdraw.content((3.15, 3.15), [TextHandler], size: 6pt)
  cdraw.rect((6.2, 2.8), (10.7, 3.5), fill: luma(205), radius: 0.02)
  cdraw.content((8.45, 3.15), [JSONHandler], size: 6pt)
  cdraw.content((5.8, 1.8), [formats the attrs, writes to any io.Writer], size: 6pt)
  pane(12.7, 23.3, 7.0, [With], [returns a child logger], [carrying bound attrs])
  cdraw.content((18.0, 2.4), [attrs are key value pairs], size: 6pt)
  cdraw.content((18.0, 1.3), [typed at call sites, SetDefault], size: 6pt)
  cdraw.content((18.0, 0.2), [wires package level slog.Info], size: 6pt)
})

sources: pkg.go.dev for fmt, slices, maps, cmp, time, log/slog, and
the go 1.27 release notes for CutLast, accessed 2026-09-08. All
behavior verified by `go/samples/ch12` tests, 7 of them.
