#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= functions

Functions are go's unit of composition, and the language bets on
having few features done thoroughly: multiple returns instead of
tuples, defer instead of finally, closures instead of classes,
methods as syntax over functions. Every rule below is exercised by
the sample package's tests.

== multiple returns and named results

A function returns as many values as it declares, and go's error
convention rides on this: the last return is an error, callers check
it, and there is no exception to intercept. Named results document
the slots and stay in scope for the whole body:

#listing("go/samples/ch05/functions.go", first: 9, last: 13, caption: [quotient and remainder, named])

Naked `return` with named results compiles, but explicit values read
better beyond two slots. The
second use of named results is the serious one: they are variables
the function owns, so deferred code can set them, which is how a
defer recovers a panic into an error return.

#diagram([results are slots the function owns, named ones stay in scope], length: 13pt, {
  cdraw.rect((0.5, 2.6), (9.5, 7.0), fill: luma(240), radius: 0.02)
  cdraw.content((5.0, 6.5), [#"func Divide"], size: 6.5pt)
  cdraw.content((5.0, 5.4), [#"(a, b int)"], size: 6pt)
  cdraw.content((5.0, 4.35), [result slots], size: 6pt)
  cdraw.rect((1.0, 3.0), (3.4, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((2.2, 3.5), [#"q int"], size: 6pt)
  cdraw.rect((3.7, 3.0), (6.1, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((4.9, 3.5), [#"r int"], size: 6pt)
  cdraw.rect((6.4, 3.0), (8.8, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((7.6, 3.5), [#"err error"], size: 6pt)
  pane(10.8, 23.4, 7.0, [named results], [slots become variables], [in scope for the body,], [deferred code writes], [them: panic to error])
  cdraw.line((10.6, 3.5), (9.0, 3.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.8, 1.5), [error nil exactly when the value is meaningful], size: 6pt)
})

== defer

`defer` registers a call to run when the function returns, whoever
returns however. Three rules, all pinned by tests:

#diagram([defers stack up lifo, arguments already captured at registration], length: 13pt, {
  cdraw.content((4.25, 6.9), [the defer stack], size: 6.5pt)
  cdraw.rect((0.5, 4.9), (8.0, 6.1), fill: luma(225), radius: 0.02)
  cdraw.content((4.25, 5.5), [#"3 close(sock)"], size: 6pt)
  cdraw.rect((0.5, 3.5), (8.0, 4.7), fill: luma(232), radius: 0.02)
  cdraw.content((4.25, 4.1), [#"2 close(db)"], size: 6pt)
  cdraw.rect((0.5, 2.1), (8.0, 3.3), fill: luma(240), radius: 0.02)
  cdraw.content((4.25, 2.7), [#"1 close(file)"], size: 6pt)
  cdraw.line((8.4, 5.5), (8.4, 2.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.4, 4.1), [return pops 3, 2, 1], size: 6pt)
  pane(12.9, 23.4, 6.9, [the rules], [arguments evaluated at], [defer time, not run time], [renaming resource later], [changes nothing])
  cdraw.content((11.9, 0.8), [three defers in a loop all fire at the one return], size: 6pt)
})

First, defers run last in, first out:

#listing("go/samples/ch05/functions.go", first: 22, last: 33, caption: [lifo order, and arguments evaluated at defer time])

Second, the deferred call's arguments are evaluated when the defer
statement executes. `resource` is renamed after registration and the
closed message still says `"closed: file"`, because the string was
already built. Third, defers accumulate, they do not nest:

#listing("go/samples/ch05/functions.go", first: 35, last: 41, caption: [three defers fire at one return])

A defer inside a loop holds its resource until the function ends.
For per iteration cleanup, wrap the loop body in a function or use
the pattern `func() { defer close(f); ... }()` per turn. Loop
contexts and transactions are where this bites.

== closures and loop variables

A function literal captures its free variables by reference, so
closures over the same variable share state:

#listing("go/samples/ch05/functions.go", first: 43, last: 52, caption: [three closures, one count])

The historical trap was the loop variable: one `i` for the whole
loop meant every closure saw the final value. Go 1.22 changed the
semantics, each iteration gets a fresh variable, and 1.27 keeps it:

#listing("go/samples/ch05/functions.go", first: 54, last: 60, caption: [per iteration capture, 0 1 2 since go 1.22])

#diagram([loop capture before and after 1.22: one variable versus one per iteration], length: 13pt, {
  pane(0.3, 11.3, 6.8, [before 1.22], [one i for the loop,], [every closure sees 3], [output: 3 3 3])
  cdraw.line((11.6, 4.0), (12.4, 4.0), stroke: luma(100), mark: (end: ">>"))
  pane(12.7, 23.3, 6.8, [since 1.22], [fresh i each turn,], [each closure its own], [output: 0 1 2])
  cdraw.content((11.8, 0.9), [the remaining trap: a shared outer variable], size: 6pt)
})

#callout("pitfall", "capturing range value versus index", [
  `for _, x := range xs` also gives a fresh `x` per iteration since
  1.22, but `&x` taken during iteration still points at that
  iteration's copy, which is what you want. The bug that remains is
  capturing a shared outer variable you meant to pass as a parameter.
])

== variadics

The last parameter may collect, `nums ...int` is a slice inside the
function and accepts zero or more arguments, or one slice with
`...`:

#listing("go/samples/ch05/functions.go", first: 62, last: 69, caption: [the variadic collect])

#diagram([variadics: two call shapes pack into one slice parameter], length: 13pt, {
  cdraw.rect((0.5, 5.3), (6.5, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 5.9), [#"Sum(1, 2, 3)"], size: 6pt)
  cdraw.rect((0.5, 3.5), (6.5, 4.7), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 4.1), [#"Sum(xs...)"], size: 6pt)
  cdraw.line((6.7, 5.9), (8.6, 5.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((6.7, 4.1), (8.6, 4.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.8, 4.2), (14.6, 5.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.7, 5.35), [packs into], size: 6pt)
  cdraw.content((11.7, 4.6), [#"nums ...int"], size: 6.5pt)
  pane(15.8, 23.4, 6.5, [inside the call], [a plain slice:], [len, range, append], [all work as usual])
  cdraw.content((11.8, 2.7), [zero arguments arrive as a nil slice], size: 6pt)
  cdraw.content((11.8, 1.6), [only the last parameter may collect], size: 6pt)
})

== methods and method sets

A method is a function with a receiver. The receiver choice is the
design decision: value receivers get a copy and cannot mutate, so
stateful types use pointer receivers, and the choice decides which
interfaces a type satisfies:

#listing("go/samples/ch05/functions.go", first: 73, last: 90, caption: [one interface, two satisfaction outcomes])

The method set of `T` contains value receiver methods only, the
method set of `*T` contains both. `Counter` satisfies `Incrementer`,
`Locked` does not, `*Locked` does, and the test reads the verdicts
from reflect rather than trusting the prose. Interface satisfaction
is compile time, implicit, and there is no `implements` clause.

#diagram([the receiver decides the method set, the method set decides satisfaction], length: 13pt, {
  pane(0.3, 11.3, 7.6, [method set of T], [value receiver], [methods only])
  cdraw.line((11.6, 5.9), (12.4, 5.9), stroke: luma(100), mark: (end: ">>"))
  pane(12.7, 23.3, 7.6, [#"method set of *T"], [value and pointer], [receiver methods, both])
  cdraw.content((11.8, 2.6), [the verdicts, read from reflect], size: 6.5pt)
  let row(y, name, recv, verdict) = {
    cdraw.line((0.9, y - 0.45), (22.8, y - 0.45), stroke: luma(220))
    cdraw.content((3.8, y), [#name], size: 6pt)
    cdraw.content((11.0, y), [#recv], size: 6pt)
    cdraw.content((18.2, y), [#verdict], size: 6pt)
  }
  row(1.8, [Counter], [Inc on T], [satisfies Incrementer])
  row(0.8, [Locked], [#"Inc on *T"], [does not satisfy])
  row(-0.2, [#"*Locked"], [both methods], [satisfies Incrementer])
  cdraw.content((11.8, -1.3), [implicit at compile time, no implements clause exists], size: 6pt)
})

== init

A package may define `init` functions, parameterless, uncallable,
running once at program start after imported packages initialized and
variable initializers ran. They register drivers and formats, and
beyond that they are a smell: test suites cannot reach them, so
prefer explicit constructors:

#listing("go/samples/ch05/functions.go", first: 98, last: 106, caption: [the init pair the tests observe])

#diagram([package initialization runs once, in order, before any caller], length: 13pt, {
  let stage(x0, title, l1, l2) = {
    cdraw.rect((x0, 3.1), (x0 + 4.9, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.45, 5.9), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.45, 4.7), [#l1], size: 6pt)
    cdraw.content((x0 + 2.45, 3.7), [#l2], size: 6pt)
  }
  stage(0.3, [imported], [deepest first], [up the tree])
  cdraw.line((5.35, 4.8), (5.95, 4.8), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [variables], [package level], [initializers])
  cdraw.line((11.15, 4.8), (11.75, 4.8), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [init functions], [in file order,], [all of them])
  cdraw.line((16.95, 4.8), (17.55, 4.8), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [callers run], [main, tests,], [importers last])
  cdraw.content((11.8, 1.9), [once, at program start, no argument, no return], size: 6pt)
  cdraw.content((11.8, 0.8), [uncallable from tests: registration work belongs], size: 6pt)
  cdraw.content((11.8, -0.3), [in an explicit constructor the test can call], size: 6pt)
})

sources: go.dev/ref/spec, function declarations, defer statements,
and method sets sections, accessed 2026-09-08, plus the go 1.22
release notes for loop variable semantics. Verified by
`go/samples/ch05` tests.
