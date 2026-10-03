#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= delegates, lambdas, events

A delegate is a type whose values are methods. Given a delegate value,
you can call it, store it, pass it as an argument, combine several into
a chain, and remove them again. Delegates are the mechanism under
events, LINQ, callbacks, and most async APIs, which makes this the
chapter that explains how the rest of the library composes.

== declaring and invoking

A delegate declaration introduces a signature. Instances hold methods
matching that signature, and invoking the delegate calls whatever it
holds. Assignment from a bare method name is a *method group
conversion*, and it works for static and instance methods alike:

#listing("csharp-net/samples/src/Ch07/Delegates.cs", first: 3, last: 4, caption: [a custom delegate type is one line])

#listing("csharp-net/samples/src/Ch07/Delegates.cs", first: 12, last: 18, caption: [binding, invoking, and rebinding a delegate])

#diagram([a delegate type, a bound method group, and a rebinding], length: 13pt, {
  // the signature at top, the variable rebound below it
  cdraw.rect((0.2, 5.4), (10.2, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((5.2, 6.0), [`delegate int Transformer(int)`], size: 6pt)
  cdraw.content((17.0, 6.0), [the type is only #linebreak() a signature], size: 6.5pt)
  cdraw.rect((0.4, 2.6), (2.2, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((1.3, 3.1), [`t`], size: 6pt)
  cdraw.line((2.2, 3.5), (5.4, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.3, 4.7), [`t = Square`], size: 6pt)
  cdraw.rect((5.4, 4.0), (10.2, 5.0), fill: luma(230), radius: 0.02)
  cdraw.content((7.8, 4.5), [`Square`], size: 6pt)
  cdraw.line((2.2, 2.7), (5.4, 1.7), stroke: (paint: luma(150), dash: (1.5pt, 1.5pt)), mark: (end: ">"))
  cdraw.content((3.3, 1.5), [`t = Increment`], size: 6pt)
  cdraw.rect((5.4, 1.2), (10.2, 2.2), fill: luma(245), radius: 0.02)
  cdraw.content((7.8, 1.7), [`Increment`], size: 6pt)
  cdraw.content((10.5, 0.2), [assignment from a bare method name is a method group conversion, #linebreak() delegate instances are immutable, rebinding swaps the reference], size: 6.5pt)
})

Delegate instances are immutable. Reassigning `t` swaps which method
the variable refers to, it does not modify any delegate object.

== Func, Action, and lambdas

Custom delegate types are rarely needed. The library ships `Func<...>`
for methods that return a value, with the last type argument as the
return type, and `Action<...>` for methods that return void, each
family covering 0 to 16 parameters. A lambda expression creates the
delegate inline, and the compiler checks the lambda against the target
type:

#listing("csharp-net/samples/src/Ch07/Delegates.cs", first: 20, last: 28, caption: [Func, Action, a capturing lambda, and a static lambda])

#diagram([the two delegate families and the lambda surface], length: 13pt, {
  // family chip on the left, the rule on the right
  let rows = (
    ([`Func<..., TResult>`], [last type argument is the return]),
    ([`Action<...>`], [the void family]),
    ([`static` lambda], [captures forbidden at compile time]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.4 - i * 1.4
    cdraw.rect((0.4, y - 0.55), (6.2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((3.3, y), row.at(0), size: 6pt)
    cdraw.line((6.2, y), (7.4, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((12.6, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((9.4, 0.2), [both families span 0 to 16 parameters, #linebreak() lambda parameters take the full method surface], size: 6.5pt)
})

The `static` modifier on a lambda forbids captures entirely. When a
helper needs no outside state, declaring it static documents that and
catches accidental captures at compile time. Lambda parameters can also
be declared `ref`, `out`, or `in`, take default values, and use `params`
collections, the full method parameter surface.

== closures and captured variables

A lambda that references an outer variable captures the variable
itself, not its current value. The pair of lambda and captured
variables is a closure. Three lambdas sharing one counter see each
other's increments:

#listing("csharp-net/samples/src/Ch07/Delegates.cs", first: 30, last: 35, caption: [three closures, one shared variable])

The classic trap is loop capture. A `for` loop declares a single
variable reused across iterations, so closures created inside the loop
all observe the final value when invoked after the loop. A `foreach`
loop by contrast introduces a fresh variable per iteration, exactly
because of this trap:

#listing("csharp-net/samples/src/Ch07/Delegates.cs", first: 37, last: 45, caption: [the for loop variable is one variable])

#diagram([closures, one hoisted cell shared, the loop capture trap], length: 13pt, {
  // the display class at left, the two loop disciplines at right
  cdraw.rect((0.2, 0.8), (9.0, 5.8), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((4.6, 5.3), [compiler display class], size: 6.5pt)
  let lambdas = (4.2, 2.8, 1.4)
  for y in lambdas {
    cdraw.rect((0.8, y - 0.45), (5.4, y + 0.45), fill: luma(230), radius: 0.02)
    cdraw.content((3.1, y), [`() => ++count`], size: 6pt)
    cdraw.line((5.4, y), (6.0, 3.4), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.rect((6.0, 2.7), (8.8, 4.1), fill: luma(205), radius: 0.02)
  cdraw.content((7.4, 3.4), [`count` #linebreak() one cell], size: 6pt)
  cdraw.content((4.6, 0.1), [three lambdas, one cell, increments visible to all], size: 6.5pt)
  cdraw.content((13.5, 6.6), [`for`], size: 7pt)
  cdraw.rect((10.4, 2.8), (16.6, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((13.5, 4.4), [one `i` for the #linebreak() whole loop #linebreak() [`3, 3, 3`] after], size: 6pt)
  cdraw.content((20.4, 6.6), [`foreach`], size: 7pt)
  cdraw.rect((17.4, 2.8), (23.6, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((20.5, 4.4), [a fresh copy #linebreak() per iteration #linebreak() [`0, 1, 2`] after], size: 6pt)
})

#callout("pitfall", "capture rules that bite", [
  A lambda cannot capture `ref`, `out`, or `in` parameters of the
  enclosing method, and captured variables stay alive as long as any
  delegate referencing them is alive, which is how event subscriptions
  cause memory leaks. When a closure outlives its scope, you have a
  leak, and unsubscription is the fix.
])

== multicast

Delegates are multicast: `+` chains two delegates of the same type into
one whose invocation list is both, invoked in order. `-` removes by
instance, which is why handlers stored for later removal must be kept
in variables, an inline lambda can never be removed because no
reference to it survives. The return value of a multicast invocation is
the last entry's return, earlier returns are discarded:

#listing("csharp-net/samples/src/Ch07/Delegates.cs", first: 47, last: 57, caption: [combine, invoke in order, remove by instance])

#diagram([the multicast chain, combine, invoke in order, remove by instance], length: 13pt, {
  // the invocation list at top, subtraction and the null edge below
  cdraw.content((6.0, 6.9), [`both = a + b`, one delegate, two entries], size: 7pt)
  cdraw.rect((0.6, 5.0), (2.8, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((1.7, 5.5), [`a`], size: 6pt)
  cdraw.line((2.8, 5.5), (4.0, 5.5), stroke: luma(100))
  cdraw.rect((4.0, 5.0), (6.2, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((5.1, 5.5), [`b`], size: 6pt)
  cdraw.content((15.0, 5.9), [invoking runs a then b, #linebreak() only the last return survives], size: 6.5pt)
  cdraw.content((2.4, 3.6), [`both - a`], size: 6.5pt)
  cdraw.line((4.4, 3.6), (5.6, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.6, 3.1), (7.8, 4.1), fill: luma(230), radius: 0.02)
  cdraw.content((6.7, 3.6), [`b`], size: 6pt)
  cdraw.content((15.0, 3.6), [removal is by instance, keep the handler #linebreak() in a variable if you mean to remove it], size: 6.5pt)
  cdraw.content((2.4, 1.6), [`both - a - b`], size: 6.5pt)
  cdraw.line((4.8, 1.6), (6.0, 1.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.0, 1.1), (8.2, 2.1), fill: luma(245), radius: 0.02)
  cdraw.content((7.1, 1.6), [`null`], size: 6pt)
  cdraw.content((15.0, 1.6), [removing the last entry yields null, #linebreak() hence the `?.Invoke` guard], size: 6.5pt)
  cdraw.content((15.0, -0.2), [`GetInvocationList()` exposes the chain when entries #linebreak() must run individually, per handler, or async], size: 6.5pt)
})

Subtraction deserves the `?.Invoke` guard in that listing: removing the
last entry produces a null delegate, and invoking null throws. The
`GetInvocationList()` method exposes the chain as an array when you need
to invoke entries individually, catch per-handler exceptions, or run
them asynchronously, which is the standard eventing pattern for
libraries.

== delegates as parameters

A delegate parameter is how a method accepts behavior. The `Map` helper
below takes a transformation, callers pass a lambda or a method group
interchangeably:

#listing("csharp-net/samples/src/Ch07/Delegates.cs", first: 59, last: 64, caption: [a transformation passed as a delegate])

#diagram([behavior as data, one map over any transformation], length: 13pt, {
  // two spellings at left, the shared loop at right
  cdraw.content((2.7, 6.8), [either spelling], size: 7pt)
  cdraw.rect((0.4, 5.0), (5.0, 6.0), fill: luma(230), radius: 0.02)
  cdraw.content((2.7, 5.5), [`x => x * x`], size: 6pt)
  cdraw.rect((0.4, 3.6), (5.0, 4.6), fill: luma(230), radius: 0.02)
  cdraw.content((2.7, 4.1), [`Square`], size: 6pt)
  cdraw.line((5.0, 5.5), (6.6, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.0, 4.1), (6.6, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.6, 3.8), (11.6, 5.8), fill: luma(205), radius: 0.02)
  cdraw.content((9.1, 4.8), [`Map(xs, f)` #linebreak() takes a `Func`], size: 6pt)
  cdraw.line((11.6, 4.8), (13.2, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.2, 3.8), (19.6, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((16.4, 4.8), [the loop calls #linebreak() `f(xs[i])` per pass], size: 6pt)
  cdraw.line((19.6, 4.8), (20.8, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((22.2, 4.8), [result], size: 6.5pt)
})

When a signature carries parameters the body ignores, discards name
that choice at the use site:

#listing("csharp-net/samples/src/Ch07/Delegates.cs", first: 66, last: 72, caption: [discard parameters in a lambda])

== events, the restricted multicast

Chapter 4 introduced events as members. The machinery underneath is
this chapter: `event` wraps a delegate field so that outside code can
only `+=` and `-=`, which are `Delegate.Combine` and `Delegate.Remove`.
Subscribing with `+=` adds your handler to the invocation list,
unsubscribing with `-=` removes it by reference, which is why instance
methods must be unsubscribed with the same method group and lambdas
must be stored to be removable. Raising an event is invoking the
underlying multicast delegate, guarded with `?.` because an event with
no subscribers is null.

#diagram([event operations, the two outside verbs and the guarded raise], length: 13pt, {
  // each outside verb maps to one runtime call
  let rows = (
    ([`+=`], [`Delegate.Combine`]),
    ([`-=`], [`Delegate.Remove`]),
    ([raise, inside], [`?.Invoke` on the field]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.4 - i * 1.5
    cdraw.rect((0.6, y - 0.55), (4.6, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((2.6, y), row.at(0), size: 6pt)
    cdraw.line((4.6, y), (5.8, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((10.6, y), row.at(1), size: 6pt)
  }
  cdraw.content((8.4, 0.2), [an event with no subscribers is a null delegate], size: 6.5pt)
})

== local functions

A local function is a method declared inside another method. It can do
everything a lambda can and recurses naturally, since it can refer to
itself before assignment. Lambdas are converted to delegates at
declaration, local functions only when used as delegates, so a local
function that is only called directly can avoid the closure allocation
a lambda always pays:

#snippet(
  "int Fact(int n) => n <= 1 ? 1 : n * Fact(n - 1); // local function\n\n"
  + "// lambda equivalent needs the variable first\n"
  + "Func<int, int> fact = null!;\n"
  + "fact = n => n <= 1 ? 1 : n * fact(n - 1);\n",
  lang: "cs",
)

#diagram([lambda vs local function, when the delegate is created], length: 13pt, {
  // two panels, the conversion point is the difference
  cdraw.content((3.2, 6.9), [lambda], size: 7pt)
  cdraw.rect((0.2, 4.2), (6.4, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 5.0), [`fact = n => ...` #linebreak() `fact(n - 1)`], size: 6pt)
  cdraw.content((3.2, 2.8), [a delegate at declaration, #linebreak() the closure allocation is always paid], size: 6.5pt)
  cdraw.line((6.8, 5.0), (10.6, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.4, 6.9), [local function], size: 7pt)
  cdraw.rect((11.0, 4.2), (19.8, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((15.4, 5.0), [`int Fact(int n) =>` #linebreak() `n * Fact(n - 1)`], size: 6pt)
  cdraw.content((15.4, 2.8), [a delegate only when used as one, #linebreak() recursion works by name], size: 6.5pt)
})

sources: learn.microsoft.com, delegates, lambda expressions, delegates
with named versus anonymous methods, how to combine delegates,
system.delegate, and local functions pages, accessed 2026-09-08.
Sample behavior verified by `make verify-csharp`, 7 tests.
