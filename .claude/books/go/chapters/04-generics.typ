#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= generics and generic methods

Generics arrived in go 1.18 and stopped growing until now. Go 1.27
ships the change the proposal process spent years on: methods may
declare their own type parameters, plus a generalized function type
inference. This chapter covers the whole mechanism as it stands, and
every listing runs in the sample module against go1.27.0.

== type parameters and constraints

A function declaration lists its parameters in square brackets, each
with a constraint, and the constraint is an interface:

#listing("go/samples/ch04/generics.go", first: 12, last: 18, caption: [one constraint, the standard ordered set])

`any` is alias for `interface{}`, a no constraint. `comparable` is
the constraint of types that support `==`. The standard constraints
live in the `cmp` and `slices` packages, `cmp.Ordered` above covers
numbers and strings. Constraints are ordinary interfaces, so they
carry methods for behavior and type sets for capability:

#listing("go/samples/ch04/generics.go", first: 38, last: 46, caption: [approximation terms accept defined types])

The tilde is the operator that matters: `~int` means any type whose
underlying type is int, so `Grams`, a defined int, passes where a
bare `int` constraint would reject it. Union terms combine sets,
`~int | ~float64` above. Call sites infer the argument, `Sum(1, 2)`
instantiates `Sum[int]`, and `Sum(Grams(100), Grams(250))`
instantiates `Sum[Grams]` because the variadic pack fixes `N`.

#diagram([constraints are interfaces: type sets, with the tilde opening the door], length: 13pt, {
  cdraw.rect((0.5, 2.6), (12.0, 7.0), fill: luma(240), radius: 0.02)
  cdraw.content((6.25, 6.6), [every type], size: 6.5pt)
  cdraw.rect((1.5, 3.0), (11.0, 5.9), fill: luma(225), radius: 0.3)
  cdraw.content((6.25, 5.5), [#"the ~int set"], size: 6.5pt)
  cdraw.content((3.6, 4.2), [int], size: 6pt)
  cdraw.content((8.0, 4.2), [Grams], size: 6pt)
  cdraw.content((6.25, 3.35), [underlying type int], size: 6pt)
  cdraw.content((6.0, 1.9), [bare int rejects Grams,], size: 6pt)
  cdraw.content((6.0, 0.8), [#"~int accepts it"], size: 6pt)
  pane(12.5, 23.4, 7.0, [the standard three], [any: no constraint], [#"comparable: supports =="], [cmp.Ordered: numbers], [and strings])
  cdraw.content((11.8, -0.4), [constraints are interfaces: methods, unions, tilde terms], size: 6pt)
})

== generic types

Types take parameters the same way, and methods on them use the
receiver's parameters for free. Receivers and method sets are chapter
5's subject, here the receiver's parameters simply ride along:

#listing("go/samples/ch04/generics.go", first: 20, last: 33, caption: [two arguments, and swap with inferred result type])

#diagram([the receiver's parameters ride along: swap with no explicit instantiation], length: 13pt, {
  cdraw.rect((0.5, 3.0), (8.5, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.5, 6.3), [#"Pair[int, string]"], size: 6.5pt)
  cdraw.content((4.5, 5.1), [#"first: int"], size: 6pt)
  cdraw.content((4.5, 3.9), [#"second: string"], size: 6pt)
  cdraw.line((8.7, 4.9), (14.3, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 5.6), [Swap()], size: 6.5pt)
  cdraw.content((11.5, 4.2), [T, U ride along], size: 6pt)
  cdraw.rect((14.5, 3.0), (22.5, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((18.5, 6.3), [#"Pair[string, int]"], size: 6.5pt)
  cdraw.content((18.5, 5.1), [#"first: string"], size: 6pt)
  cdraw.content((18.5, 3.9), [#"second: int"], size: 6pt)
  cdraw.content((11.5, 2.2), [#"p.Swap() infers everything: zero explicit brackets"], size: 6pt)
})

No explicit instantiation appears at `p.Swap()`: the receiver fixes
`T` and `U`, and the result `Pair[U, T]` follows. That inference is
why generic types feel native rather than templated, and a type
parameter's zero value is available as `var zero T`, the substitute
for a default constructor:

#listing("go/samples/ch04/generics.go", first: 103, last: 108, caption: [zero value without constructors, and a one line generic])

== generic methods, the go 1.27 change

Until 1.27 a method could use only the type parameters of its
receiver. Workarounds were package level functions taking the
receiver as the first argument, which is why `slices.Sort(s)` exists
alongside `s.Sort` that never could. Go 1.27 lifts the restriction: a
method may declare fresh type parameters, used in its parameters,
results, and body:

#listing("go/samples/ch04/generics.go", first: 51, last: 70, caption: [a generic type whose method adds its own parameter])

`Map` transforms the set's elements to any type `U` chosen per call,
`Map[int]` and `Map[string]` both work on the same `*Set[int]`. The
same liberty extends to plain receivers:

#listing("go/samples/ch04/generics.go", first: 74, last: 101, caption: [a plain type with a generic getter])

Two restrictions survive from the design discussion, and they are the
same fact: interface methods may not declare type parameters, and
interface methods cannot be implemented by generic methods. A method
set must be knowable from the interface alone, before any call site
picks arguments. The standard library's own example is
`math/rand/v2`, whose `Rand.N` is now a generic method,
`func (r *Rand) N[Int intType](Int) Int`, matching the package level
`N`.

#diagram([generic methods, the 1.27 change: fresh parameters on the method], length: 13pt, {
  pane(0.3, 11.3, 7.0, [before 1.27], [methods could use only], [the receiver's params], [workaround: package level], [#"fns, why slices.Sort"], )
  cdraw.line((11.6, 4.2), (12.4, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(12.7, 23.3, 7.0, [1.27], [#"func (s *Set[T])"], [#"  Map[U any](f) Set[U]"], [fresh type parameters], [on the method itself])
  cdraw.content((11.8, 0.6), [two restrictions, one fact: interface methods declare], size: 6pt)
  cdraw.content((11.8, -0.5), [no type parameters, so generic methods implement none], size: 6pt)
})

#callout("note", "when a function beats a method", [
  Even with generic methods available, `slices.Sort(s)` style
  functions stay idiomatic when the operation reads as a utility over
  a standard shape. Methods earn their keep when the receiver carries
  state, like `Set.Map` above or a registry keyed by type.
])

== function type inference, generalized in 1.27

Before 1.27, inference happened at calls, and assigning a generic
function to a variable of function type required spelling the
instantiation, `var f = Double[int]`. Go 1.27 generalizes inference to
every context where a generic function meets a matching function
type:

#snippet(
  "func Double[N ~int | ~float64](x N) N { return x + x }\n\n"
  + "var f func(int) int = Double     // 1.27: inferred as Double[int]\n"
  + "var g func(float64) float64 = Double\n",
  lang: "go",
)

Both assignments in the test suite compile and return 42 and 3. This
is the feature that makes generic functions drop in where closures or
passed functions were the only option, callbacks, handlers, and table
driven dispatch all accept generic functions directly now.

#diagram([function type inference, generalized in 1.27], length: 13pt, {
  pane(0.3, 11.3, 6.6, [before 1.27], [#"var f = Double[int]"], [spelled at every use])
  cdraw.line((11.6, 4.0), (12.4, 4.0), stroke: luma(100), mark: (end: ">>"))
  pane(12.7, 23.3, 6.6, [1.27], [#"var f func(int) int = Double"], [inferred from the type])
  cdraw.content((11.8, 1.4), [callbacks, handlers, and dispatch tables], size: 6pt)
  cdraw.content((11.8, 0.3), [accept generic functions directly], size: 6pt)
})

sources: go.dev, go 1.27 release notes, language changes section, and
proposal issue 9859's sibling discussion for generic methods,
accessed 2026-09-08. All syntax verified by compiling and running
`go/samples/ch04` on go1.27.0.
