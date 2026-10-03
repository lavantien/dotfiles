#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= error handling

Go has no exceptions. An error is a value of the two method
interface `error`, returned as the last result, checked by the caller.
Everything else in this chapter, wrapping, matching, joining,
recovering, is machinery over that one decision, and it is why go
code reads top to bottom with the failure path visible beside the
happy one.

== the interface and the convention

#snippet(
  "type error interface {\n"
  + "    Error() string\n"
  + "}\n",
  lang: "go",
)

#diagram([one method, returned as the last slot, checked by the caller], length: 13pt, {
  pane(0.3, 9.9, 6.8, [the interface], [#"Error() string"], [anything with that], [method is an error])
  cdraw.line((10.4, 4.5), (11.4, 4.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((11.9, 2.6), (23.3, 6.8), fill: luma(240), radius: 0.02)
  cdraw.content((17.6, 6.2), [the return shape, error last], size: 6.5pt)
  cdraw.rect((12.5, 3.6), (17.2, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((14.85, 4.4), [value], size: 6.5pt)
  cdraw.rect((17.9, 3.6), (22.7, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((20.3, 4.4), [error], size: 6.5pt)
  cdraw.content((17.6, 2.2), [checked at the call site, in the open], size: 6pt)
  cdraw.content((17.6, 1.1), [error nil exactly when the value], size: 6pt)
  cdraw.content((17.6, 0.0), [is meaningful: the pair is the contract], size: 6pt)
})

Anything with an `Error() string` method is an error, and the
convention is positional: functions return `(value, error)`, the
error is nil exactly when the value is meaningful, and callers
handle it at the call site:

#listing("go/samples/ch07/errors.go", first: 11, last: 17, caption: [the standard shape])

`fmt.Errorf` builds wrapped messages, `errors.New` builds bare ones,
and neither is more than a struct with a string.

== sentinels, wrapping, matching

A sentinel is an exported error value that names a condition, and
`%w` is the verb that chains errors together:

#listing("go/samples/ch07/errors.go", first: 20, last: 33, caption: [sentinel plus percent w wrap])

The wrap is what makes matching work. `errors.Is(err, ErrNotFound)`
walks the chain of wrapped errors and compares each link, so the
sentinel stays comparable no matter how many layers of context
surround it. Use `Is` for sentinel identity, and when the match must
be by type because the error carries data, use `errors.As`:

#listing("go/samples/ch07/errors.go", first: 36, last: 51, caption: [a typed error found with As])

`As` requires a pointer to the concrete type and finds the first
match in the chain, giving the caller the `Line` and `Col` payload.
Since go 1.20 `errors.Join` carries a tree of failures, and every
branch stays findable:

#listing("go/samples/ch07/errors.go", first: 53, last: 69, caption: [join keeps every branch Is-able])

#diagram([the wrap chain and the join tree, walked by Is and As], length: 13pt, {
  cdraw.rect((0.3, 6.0), (7.7, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 6.55), [#"wrap: %w adds context"], size: 6pt)
  cdraw.line((4.0, 5.8), (4.0, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 4.3), (7.7, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 4.85), [#"wrap: %w again"], size: 6pt)
  cdraw.line((4.0, 4.1), (4.0, 3.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 2.6), (7.7, 3.7), fill: luma(205), radius: 0.02)
  cdraw.content((4.0, 3.15), [sentinel ErrNotFound], size: 6pt)
  cdraw.content((4.0, 1.5), [Is compares each link,], size: 6pt)
  cdraw.content((4.0, 0.4), [As stops at the typed one], size: 6pt)
  cdraw.content((14.0, 7.0), [join keeps every branch findable], size: 6.5pt)
  cdraw.rect((10.7, 5.3), (14.5, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((12.6, 5.85), [#"errors.Join"], size: 6pt)
  cdraw.line((11.6, 5.1), (10.6, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((13.6, 5.1), (14.4, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.3, 3.05), (12.9, 4.15), fill: luma(235), radius: 0.02)
  cdraw.content((10.6, 3.6), [#"name: Is-able"], size: 6pt)
  cdraw.rect((13.3, 3.05), (17.9, 4.15), fill: luma(235), radius: 0.02)
  cdraw.content((15.6, 3.6), [#"age: Is-able"], size: 6pt)
  cdraw.rect((12.7, -1.1), (23.3, 1.9), fill: luma(205), radius: 0.02)
  cdraw.content((18.0, 1.4), [the percent v trap], size: 6.5pt)
  cdraw.content((18.0, 0.4), [#"fmt.Errorf(\"..: %v\")"], size: 6pt)
  cdraw.content((18.0, -0.6), [flattens: no Is will match], size: 6pt)
})

Validation is the natural use: collect every field problem, return
one error, and callers test each condition independently.

#callout("pitfall", "fmt.Errorf with percent v loses the chain", [
  `%w` wraps, `%v` formats. `fmt.Errorf("lookup %q: %v", k,
  ErrNotFound)` produces an error no `errors.Is` call will ever
  match, because the sentinel was flattened into text. Vet cannot
  catch this one, review has to.
])

== the typed nil trap

An interface value is a pair of type and pointer. Storing a typed nil
pointer into an error interface fills the type half, and the pair
compares non nil:

#listing("go/samples/ch07/errors.go", first: 71, last: 90, caption: [the trap and the well behaved form, both return true])

The test asserts both: the typed nil reports `err != nil`, and the
plain nil interface reports `err == nil`. The trap fires when a
function returns `*MyErr` as an `error` on a failure path that
produced a nil pointer, the caller sees a non nil error holding
nothing. The defenses are returning a real error, or returning the
concrete type and letting `errors.As` handle absence.

#diagram([one interface value is two words, and nil means both are empty], length: 13pt, {
  let iface(x, tword, dword, note) = {
    cdraw.rect((x, 3.2), (x + 4.6, 4.0), fill: luma(230), radius: 0.05)
    cdraw.content((x + 1.15, 3.6), [#tword], size: 6.5pt)
    cdraw.line((x + 2.3, 3.2), (x + 2.3, 4.0))
    cdraw.rect((x + 2.3, 3.2), (x + 4.6, 4.0), fill: luma(240), radius: 0.05)
    cdraw.content((x + 3.45, 3.6), [#dword], size: 6.5pt)
    cdraw.content((x + 1.15, 4.5), [type], size: 6pt)
    cdraw.content((x + 3.45, 4.5), [data], size: 6pt)
    cdraw.content((x - 0.4, 2.4), [#note], size: 6.5pt)
  }
  cdraw.content((5.6, 5.3), [nil interface], size: 7pt)
  iface(1.0, "nil", "nil", [err == nil])
  cdraw.content((17.4, 5.3), [typed nil inside], size: 7pt)
  iface(13.0, "*MyErr", "nil", [err != nil, the trap])
})

== panic and recover

Panic is for programmer error and unrecoverable states, invariant
violations, index bounds, nil dereferences, impossible switches.
Recover exists so a package can keep a broken call from taking down
the process, at library boundaries and server request handlers:

#listing("go/samples/ch07/errors.go", first: 94, last: 101, caption: [recover in the panicking frame's defer])

#diagram([panic unwinds the defers, recover catches, named results carry the error out], length: 13pt, {
  let step(y, label, fill) = {
    cdraw.rect((0.3, y - 0.5), (8.5, y + 0.7), fill: fill, radius: 0.02)
    cdraw.content((4.4, y + 0.1), [#label], size: 6pt)
  }
  step(7.3, [frame running], luma(235))
  cdraw.line((4.4, 6.6), (4.4, 6.0), stroke: luma(100), mark: (end: ">>"))
  step(5.4, [panic: unwind begins], luma(225))
  cdraw.line((4.4, 4.7), (4.4, 4.1), stroke: luma(100), mark: (end: ">>"))
  step(3.5, [defers run, lifo], luma(235))
  cdraw.content((4.4, 2.5), [the defer holds recover], size: 6pt)
  cdraw.content((4.4, 1.4), [only the panicking frame's], size: 6pt)
  cdraw.line((4.4, 0.9), (4.4, 0.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, -0.9), (8.5, 0.3), fill: luma(205), radius: 0.02)
  cdraw.content((4.4, -0.3), [#"err = recovered value"], size: 6pt)
  cdraw.content((4.4, -2.0), [the caller sees an error], size: 6pt)
  pane(12.7, 23.3, 7.3, [across a goroutine], [each goroutine owns], [its own defers: the], [spawner cannot recover])
  cdraw.content((18.0, 1.5), [the panic reaches the top], size: 6pt)
  cdraw.content((18.0, 0.4), [of that goroutine, process exits], size: 6pt)
})

`recover` only works inside a deferred function of the panicking
frame, the recovered value is what panic received, and converting it
to an error through named results is the standard bridge back to the
value world. A panic that crosses a goroutine boundary cannot be
recovered by the spawner, each goroutine owns its own defers, which
is why library code documents its panics and server frameworks wrap
every handler.

#callout("note", "when not to panic", [
  Ordinary expected failure, a missing file, a bad request, a closed
  connection, is an error value. A panic there forces every caller
  into recover blocks or crashes, and the stack unwinding throws away
  the structured context an error would have carried.
])

sources: go.dev/ref/spec and go.dev/blog, error handling posts plus
pkg.go.dev/errors, accessed 2026-09-08. Verified by `go/samples/ch07`
tests, including the typed nil behavior asserted live.
