#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= program structure

Program structure in go is packages, declarations, and scope, plus
the statement level machinery: for, switch, labels, iota. Nothing
here is exotic, and the design bet is visible: fewer statement forms
than any language in this collection, each carrying more weight.

== declarations

Four kinds: `var`, `const`, `type`, `func`. All accept grouping,
functions nest none of them, and package level declarations may
appear in any order across any file of the package, the compiler
sorts out dependencies. Blocks come in four widths, universe, package,
file, and local, from chapter 2's predeclared identifiers down to any
pair of braces. Scope is lexical and block structured:

#listing("go/samples/ch08/structure.go", first: 126, last: 134, caption: [:= inside a block declares, it never assigns])

`inner` is a new variable that dies at the closing brace, and `outer`
keeps its value. Shadowing an outer variable is legal and occasionally
a bug, which is why loops that need to modify an outer variable
declare it first. The blank identifier discards at any scope, and
`_ = v` is the idiom for an intentional discard.

#diagram([blocks nest, a := inside declares a name that dies at the brace], length: 13pt, {
  cdraw.rect((0.3, 1.6), (11.3, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.9), [outer block], size: 6.5pt)
  cdraw.content((5.8, 5.8), [#"x := 1"], size: 6pt)
  cdraw.rect((1.3, 2.0), (10.3, 4.9), fill: luma(222), radius: 0.02)
  cdraw.content((5.8, 4.4), [inner block], size: 6.5pt)
  cdraw.content((5.8, 3.3), [#"x := 2 shadows it"], size: 6pt)
  cdraw.content((5.8, 2.4), [dies at the brace], size: 6pt)
  pane(12.7, 23.3, 7.4, [four kinds to declare], [#"var, const, type, func"], [grouping allowed, none], [nest inside a function])
  cdraw.content((18.0, 1.7), [#":= declares, never assigns"], size: 6pt)
  cdraw.content((18.0, 0.6), [shadowing: legal, sometimes a bug], size: 6pt)
  cdraw.content((5.8, 0.4), [outer keeps 1 after the brace closes], size: 6pt)
})

== if and for

`if` and `for` accept an init statement, `if v, ok := m[k]; ok`,
which scopes the variable to the statement and kills the leak of
temporary names. The grade chain is the everyday shape:

#listing("go/samples/ch08/structure.go", first: 7, last: 19, caption: [else if chain, no ternary exists in go])

There is no conditional expression in the language, the chain above
is the replacement, and go's formatting vertically aligns it. For has
one keyword and three forms:

#listing("go/samples/ch08/structure.go", first: 57, last: 84, caption: [three form, range form, infinite form])

Since go 1.22 `for n := range 10` counts, and since 1.23 `for f :=
range seq` iterates any function matching `iter.Seq`, which is how
the pipeline sample of chapter 6 consumed a sequence. Range over
slices gives index and value, over maps key and value, over channels
values until close, over strings runes, and over integers counts.

#diagram([one for keyword, three forms, and what range yields], length: 13pt, {
  pane(0.3, 7.4, 8.2, [three clause], [#"init; cond; post"], [the classic loop])
  pane(8.0, 15.1, 8.2, [range], [over anything with a], [sequence shape])
  pane(15.7, 22.8, 8.2, [infinite], [#"for { }"], [break or return exits])
  cdraw.content((11.5, 4.1), [range yields, ints since 1.22, iter.Seq since 1.23], size: 6.5pt)
  let cell(xc, text) = {
    cdraw.rect((xc - 2.15, 2.2), (xc + 2.15, 3.2), fill: luma(235), radius: 0.02)
    cdraw.content((xc, 2.7), [#text], size: 6pt)
  }
  cell(2.5, [slice: i, v])
  cell(7.0, [map: k, v])
  cell(11.5, [chan: v])
  cell(16.0, [string: rune])
  cell(20.5, [#"int: 0..n-1"])
  cdraw.content((11.5, 1.1), [init statements scope names to the if or for], size: 6pt)
  cdraw.content((11.5, 0.0), [no ternary exists: the else if chain is the form], size: 6pt)
})

== switch

Go's switch does not fall through by default, the historical default
reversed because implicit fallthrough was C's most productive bug
source. Cases therefore need no break, values may be arbitrary
expressions, and the operandless form is the cleanest boolean
dispatch:

#listing("go/samples/ch08/structure.go", first: 22, last: 35, caption: [operandless switch, comma separated cases])

The type switch tests an interface's dynamic type and binds the
converted value in each case, `nil` included:

#listing("go/samples/ch08/structure.go", first: 37, last: 55, caption: [type switch over any])

#diagram([three switch kinds, none of them falling through], length: 13pt, {
  pane(0.3, 7.9, 7.2, [expression], [cases comma separated,], [values any expr])
  pane(8.5, 15.6, 7.2, [operandless], [each case a bool,], [first true runs])
  pane(16.2, 22.8, 7.2, [type switch], [#"v := x.(type)"], [binds v per case])
  cdraw.content((11.5, 2.9), [nil has its own case, and no case falls into the next], size: 6pt)
  cdraw.content((11.5, 1.8), [break is implicit: go reversed c's default], size: 6pt)
  cdraw.content((11.5, 0.7), [fallthrough exists but must be asked for], size: 6pt)
})

== labels, break, continue, goto

`break` and `continue` take an optional label to name which loop
they mean, and `goto` jumps to a label in the same function, legal
but rare, mostly generated code:

#listing("go/samples/ch08/structure.go", first: 88, last: 101, caption: [labeled break leaving both loops])

#diagram([the label names which loop the break leaves], length: 13pt, {
  cdraw.rect((0.3, 1.9), (9.3, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.8, 6.9), [outer:], size: 6.5pt)
  cdraw.rect((1.3, 3.5), (8.3, 6.1), fill: luma(222), radius: 0.02)
  cdraw.content((4.8, 5.6), [inner:], size: 6.5pt)
  cdraw.content((4.8, 4.5), [break leaves inner], size: 6pt)
  cdraw.line((6.2, 4.0), (11.6, 2.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((4.8, 2.4), [#"break outer leaves both"], size: 6pt)
  pane(12.9, 23.3, 7.4, [the other escapes], [goto: a label in the], [same function, rare,], [mostly generated code])
  cdraw.content((18.1, 2.4), [fallthrough runs the next], size: 6pt)
  cdraw.content((18.1, 1.3), [case body without testing], size: 6pt)
  cdraw.content((18.1, 0.2), [its condition], size: 6pt)
})

`fallthrough` executes the next case's body unconditionally, without
evaluating its condition, which is why the vowel function above does
not need it and almost nothing does.

== const and iota

Constants are compile time untyped values until context fixes their
type, and `iota` is the row index of a const block, the entire enum
mechanism the language has:

#listing("go/samples/ch08/structure.go", first: 105, last: 123, caption: [weekday enum and shifted sizes])

#diagram([iota is the row index, the expression repeats, two enums from one mechanism], length: 13pt, {
  cdraw.content((5.7, 7.0), [the weekday enum], size: 6.5pt)
  let row(y, i, name, val) = {
    cdraw.line((0.9, y - 0.45), (10.5, y - 0.45), stroke: luma(220))
    cdraw.content((2.3, y), [#i], size: 6pt)
    cdraw.content((5.7, y), [#name], size: 6pt)
    cdraw.content((8.9, y), [#val], size: 6pt)
  }
  row(6.1, [iota 0], [Sunday], [0])
  row(5.1, [iota 1], [Monday], [1])
  row(4.1, [iota 2], [Tuesday], [2])
  cdraw.content((17.4, 7.0), [the shift ladder], size: 6.5pt)
  let srow(y, i, name, val) = {
    cdraw.line((12.6, y - 0.45), (23.0, y - 0.45), stroke: luma(220))
    cdraw.content((14.0, y), [#i], size: 6pt)
    cdraw.content((17.4, y), [#name], size: 6pt)
    cdraw.content((20.6, y), [#val], size: 6pt)
  }
  srow(6.1, [iota 0], [KB], [#"1 << 0"])
  srow(5.1, [iota 1], [MB], [#"1 << 10"])
  srow(4.1, [iota 2], [GB], [#"1 << 20"])
  cdraw.content((11.5, 2.7), [one block, the expression repeats each row, iota counts], size: 6pt)
  cdraw.content((11.5, 1.6), [typed enums declare a defined type first, so], size: 6pt)
  cdraw.content((11.5, 0.5), [#"Weekday stays off limits to plain ints"], size: 6pt)
})

One const block, repetition of the previous expression, `iota`
counting rows: this builds the weekday enum and the kb, mb, gb ladder
from identical machinery. Typed enums declare a defined type first,
which is what makes `Weekday` printable and type safe against plain
ints.

== packages and visibility

A package is a directory, imported by path, compiled as a unit, and
re-exporting nothing. The export rule from chapter 2 decides the
boundary, and the sample's `inner` subpackage exists so the test
file can stand outside it:

#listing("go/samples/ch08/inner/inner.go", first: 1, last: 12, caption: [answer crosses the boundary, hidden does not])

#diagram([the export boundary as a stack: capitalization crosses, lowercase stays], length: 13pt, {
  cdraw.rect((0.3, 5.4), (11.3, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.7), [the importer], size: 6.5pt)
  cdraw.content((5.8, 5.9), [the test file, outside], size: 6pt)
  cdraw.line((2.8, 5.2), (2.8, 3.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((4.3, 4.6), [reaches], size: 6pt)
  cdraw.rect((0.3, 1.4), (11.3, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 2.95), [package inner], size: 6.5pt)
  cdraw.rect((1.0, 1.7), (4.6, 2.5), fill: luma(205), radius: 0.02)
  cdraw.content((2.8, 2.1), [#"Answer: out"], size: 6pt)
  cdraw.rect((6.4, 1.7), (10.7, 2.5), fill: luma(222), radius: 0.02)
  cdraw.content((8.55, 2.1), [#"hidden: stays"], size: 6pt)
  pane(12.7, 23.3, 7.2, [the rules], [capitalized: exported], [lowercase: package only], [#"internal/: subtree only"])
  cdraw.content((18.0, 1.7), [the proof is structural: an outside], size: 6pt)
  cdraw.content((18.0, 0.6), [#"spelling of inner.hidden fails"], size: 6pt)
  cdraw.content((18.0, -0.5), [to compile at all], size: 6pt)
  cdraw.content((5.8, 0.4), [a package is a directory], size: 6pt)
})

`inner.Answer` and `inner.Describe()` are reachable from the test,
`inner.hidden` and `inner.itoa` are not, and the proof is structural:
any attempt to spell them from outside fails to compile, so the test
file cannot contain one. The `internal` directory name adds a second
rule enforced by the toolchain, packages under `internal/` import
only within their subtree, which is how a module hides its
implementation packages.

sources: go.dev/ref/spec, declarations and statements, and effective
go, accessed 2026-09-08. Verified by `go/samples/ch08` tests with
the inner subpackage compiling the visibility boundary.
