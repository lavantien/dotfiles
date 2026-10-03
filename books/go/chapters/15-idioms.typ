#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= idioms

Go's designers say the language is done and the idioms are not. This
chapter is the set of conventions working go code converges on, each
one small, all of them load bearing in the capstone that follows.

== accept interfaces, return structs

Functions take the narrowest interface they need and constructors
return concrete types. The caller converts down, the callee never
converts up, and the interface lives beside its consumer, not beside
implementations:

#listing("go/samples/ch15/idioms.go", first: 35, last: 44, caption: [the interface belongs to greet, not to user])

`Namer` exists because `GreetFrom` needs one name. If another type
grows a `Name` method it satisfies the interface without asking, and
the test's `user` never imports or mentions the abstraction. Package
`io` is this pattern at standard library scale, `io.Reader` defined
where it is consumed, implemented everywhere.

#diagram([the conversion directions: narrowest in, concrete out], length: 13pt, {
  cdraw.rect((0.3, 3.6), (7.3, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 6.3), [callers arrive], size: 6.5pt)
  cdraw.content((3.8, 5.3), [concrete types, many], size: 6pt)
  cdraw.content((3.8, 4.3), [#"user, admin, mock"], size: 6pt)
  cdraw.line((7.5, 5.2), (8.5, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((8.0, 6.2), [narrows], size: 6pt)
  cdraw.rect((8.7, 3.6), (14.9, 6.8), fill: luma(222), radius: 0.02)
  cdraw.content((11.8, 6.3), [the function], size: 6.5pt)
  cdraw.content((11.8, 5.3), [takes the narrowest], size: 6pt)
  cdraw.content((11.8, 4.3), [#"interface: Namer"], size: 6pt)
  cdraw.line((15.1, 5.2), (16.1, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((15.6, 6.2), [returns], size: 6pt)
  cdraw.rect((16.3, 3.6), (23.3, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((19.8, 6.3), [the result], size: 6.5pt)
  cdraw.content((19.8, 5.3), [a struct, never an], size: 6pt)
  cdraw.content((19.8, 4.3), [unasked interface], size: 6pt)
  cdraw.content((11.8, 2.4), [the interface lives beside its consumer, io.Reader], size: 6pt)
  cdraw.content((11.8, 1.3), [is this pattern at standard library scale], size: 6pt)
})

== functional options

Constructors with many optional parameters become unreadable, and go
has neither overloading nor default arguments. The idiomatic answer
is variadic option functions over a struct with usable defaults:

#listing("go/samples/ch15/idioms.go", first: 15, last: 33, caption: [defaults in the constructor, overrides in options])

`NewServer()` gives the defaults, `NewServer(WithTimeout(d))`
overrides one, and adding a knob means adding an option without
touching any call site. The heavy alternative, a config struct,
suits knobs that callers construct dynamically.

#diagram([defaults in the constructor, options override in order], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [constructor], [usable defaults])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [options apply], [in order, variadic])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [one knob], [#"WithTimeout(d)"])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [new knob], [new option only])
  cdraw.content((11.8, 3.2), [no overloading, no default arguments in go,], size: 6pt)
  cdraw.content((11.8, 2.1), [so the option list is the parameter list,], size: 6pt)
  cdraw.content((11.8, 1.0), [and a config struct suits dynamic knobs], size: 6pt)
})

== zero values that work

Every type should aim for a usable zero value, because go declares
zero values everywhere: struct fields, map values, new variables.
`sync.Mutex`, `bytes.Buffer`, `strings.Builder`, and the capstone's
accumulator below all work without constructors:

#listing("go/samples/ch15/idioms.go", first: 46, last: 54, caption: [sum from zero, no init required])

The test drives a `strings.Builder` from `var b strings.Builder` the
same way. When a zero value cannot be valid, a constructor returns
the type in a good state and unexported fields keep it there, which
is the whole encapsulation story of go: export the type, hide the
fields, offer functions.

#diagram([aim at a usable zero, and when zero cannot work, construct], length: 13pt, {
  pane(0.3, 11.3, 6.8, [zero is usable], [#"sync.Mutex, Builder,"], [accumulator: var alone,], [no constructor at all])
  cdraw.line((11.6, 4.0), (12.4, 4.0), stroke: luma(100), mark: (end: ">>"))
  pane(12.7, 23.3, 6.8, [zero cannot be valid], [a constructor returns], [good state, unexported], [fields hold it there])
  cdraw.content((11.8, 0.6), [export the type, hide the fields, offer functions], size: 6pt)
})

== errors are values, no hierarchies

Go programs do not build exception taxonomies. A function returns
one error carrying the situation in its message, wraps with `%w`
when context accumulates, and exports sentinels only for conditions
callers must distinguish:

#listing("go/samples/ch15/idioms.go", first: 56, last: 67, caption: [wrap with context, one exported sentinel])

`Load` adds the filename, `ErrUnavailable` exists because some
caller branches on it, and the package stops there. The test asserts
the message carries the filename, which is the property that keeps
errors debuggable in logs.

#diagram([flat chain, not a taxonomy: one error, wrapped context, rare sentinels], length: 13pt, {
  cdraw.content((6.4, 7.0), [the flat chain], size: 6.5pt)
  cdraw.rect((0.3, 5.2), (6.3, 6.3), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 5.75), [#"Load: config.toml"], size: 6pt)
  cdraw.line((3.3, 5.0), (3.3, 4.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((4.2, 4.7), [%w], size: 6pt)
  cdraw.rect((0.3, 3.3), (6.3, 4.4), fill: luma(205), radius: 0.02)
  cdraw.content((3.3, 3.85), [the wrapped cause], size: 6pt)
  cdraw.content((3.3, 2.3), [the filename rides, the message], size: 6pt)
  cdraw.content((3.3, 1.2), [stays debuggable, a sentinel only], size: 6pt)
  cdraw.content((3.3, 0.1), [when a caller must branch], size: 6pt)
  cdraw.content((17.4, 7.4), [not a hierarchy], size: 6.5pt)
  cdraw.content((15.0, 6.2), [exception tree], size: 6pt)
  cdraw.content((20.6, 6.2), [go grows none], size: 6pt)
  cdraw.line((13.5, 5.9), (14.5, 5.3), stroke: luma(140))
  cdraw.line((17.4, 5.9), (17.4, 5.3), stroke: luma(140))
  cdraw.line((21.3, 5.9), (20.1, 5.3), stroke: luma(140))
  cdraw.line((13.0, 5.1), (15.0, 5.1), stroke: luma(140))
  cdraw.line((16.4, 5.1), (18.4, 5.1), stroke: luma(140))
  cdraw.line((19.8, 5.1), (21.8, 5.1), stroke: luma(140))
  cdraw.line((14.0, 4.8), (15.0, 4.2), stroke: luma(140))
  cdraw.line((17.4, 4.8), (17.4, 4.2), stroke: luma(140))
  cdraw.line((20.8, 4.8), (19.8, 4.2), stroke: luma(140))
  cdraw.content((17.4, 2.9), [no taxonomy of subtypes, no wrapping to], size: 6pt)
  cdraw.content((17.4, 1.8), [re classify: the message is the context], size: 6pt)
})

#callout("note", "the smaller vocabulary", [
  Naming: mixedCase, no underscores, initialisms capitalized, `URL`,
  `ID`. Errors: lowercase messages, no punctuation. One file per
  concern, package names singular and short, `strconv` not
  `stringutilities`. Tests beside the code, table
  driven, no framework. `gofmt` is the reviewer of style and the
  argument is over.
])

sources: go.dev/doc/effective_go and the go proverbs talk, plus
pkg.go.dev/go for the standard library expressions of these idioms,
accessed 2026-09-08. Verified by `go/samples/ch15` tests.
