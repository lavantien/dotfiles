#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= members

Classes and structs are containers of members: fields, constants,
properties, methods, events, indexers, operators, constructors, and
nested types. This chapter covers the data bearing members and the two
C\# 14 additions that change how they are written. Methods get their own
treatment spread over the pattern matching, delegate, and async chapters.

== properties and accessors

A property is a member that reads like a field and runs like a method.
The common form is the auto implemented property, where the compiler
synthesizes the storage. Accessors control each side: `get` reads,
`set` writes, `init` writes only during construction. The sample type
uses all three plus `required`, which forces callers to initialize the
member explicitly:

#listing("csharp-net/samples/src/Ch04/Members.cs", first: 5, last: 18, caption: [one class showing field, init, and required in C\# 14 style])

#diagram([a property, one storage behind three accessor gates], length: 13pt, {
  // gate on the left, what it allows in the middle, the hidden field at right
  let gates = (
    ([`get`], [reads, any time]),
    ([`set`], [writes, any time]),
    ([`init`], [writes only in #linebreak() initializer or ctor]),
  )
  for (i, (gate, policy)) in gates.enumerate() {
    let y = 5.4 - i * 1.5
    cdraw.rect((0.4, y - 0.5), (2.2, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((1.3, y), gate, size: 6pt)
    cdraw.line((2.2, y), (3.4, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((7.6, y), policy, size: 6.5pt)
  }
  cdraw.line((13.2, 4.2), (15.4, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.4, 2.8), (19.8, 5.6), fill: luma(230), radius: 0.02)
  cdraw.content((17.6, 4.2), [synthesized #linebreak() storage], size: 6pt)
  cdraw.content((9.6, 0.9), [every access goes through a gate, the field itself is never visible], size: 6.5pt)
})

== the field keyword

Before C\# 14, a property that validated its input needed a hand declared
backing field, and the property accessor talked to that field. C\# 14
makes the synthesized backing field addressable with the contextual
keyword `field` inside an accessor. Validation no longer costs you the
auto property, and the backing field cannot drift out of sync with the
accessor because there is only one declaration:

#snippet(
  "// pre-14: declare storage yourself\n"
  + "private decimal _celsius;\n"
  + "public decimal Celsius\n"
  + "{\n"
  + "    get => _celsius;\n"
  + "    set => _celsius = value >= -273.15m ? value\n"
  + "        : throw new ArgumentOutOfRangeException();\n"
  + "}\n\n"
  + "// C\# 14: same behavior, one declaration\n"
  + "public decimal Celsius\n"
  + "{\n"
  + "    get;\n"
  + "    set => field = value >= -273.15m ? value\n"
  + "        : throw new ArgumentOutOfRangeException();\n"
  + "}\n",
  lang: "cs",
)

#diagram([backing fields before and after the c\# 14 field keyword], length: 13pt, {
  // before: two declarations that can drift, after: one declaration
  cdraw.content((3.2, 6.9), [before c\# 14], size: 7pt)
  cdraw.rect((0.2, 4.6), (6.2, 5.8), fill: luma(230), radius: 0.02)
  cdraw.content((3.2, 5.2), [`_celsius` field], size: 6pt)
  cdraw.line((3.2, 4.6), (3.2, 3.8), stroke: luma(100), mark: (end: ">", start: ">"))
  cdraw.rect((0.2, 2.6), (6.2, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.2, 3.2), [`Celsius` property], size: 6pt)
  cdraw.content((3.2, 1.5), [two names, #linebreak() the field can drift], size: 6.5pt)
  cdraw.line((6.6, 4.2), (9.6, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.6, 6.9), [c\# 14 `field`], size: 7pt)
  cdraw.rect((10.0, 2.6), (19.2, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((14.6, 5.2), [`Celsius` property], size: 6pt)
  cdraw.rect((10.4, 2.9), (18.8, 4.0), fill: luma(230), radius: 0.02)
  cdraw.content((14.6, 3.45), [`field` names the storage], size: 6pt)
  cdraw.content((14.6, 1.5), [one declaration, #linebreak() validation stays in the accessor], size: 6.5pt)
})

The suite drives both sides of the validation through the real property:

#listing("csharp-net/samples/src/Ch04/Members.cs", first: 77, last: 91, caption: [valid input stores, invalid input throws])

== init and required

`init` (C\# 9) makes a property settable only in an object initializer or
constructor, so a type can be immutable without being awkward to build.
`required` (C\# 11) closes the other gap: it makes the compiler reject any
construction that leaves the member unset. Together they replace most
telescoping constructors. Forgetting a required member is a compile
error, not a null at runtime:

#snippet(
  "var t = new Temperature();\n"
  + "// error CS9035: required member 'Temperature.Site' must be set\n"
  + "// in the object initializer or attribute constructor\n",
  lang: "cs",
)

#diagram([the construction timeline, init's window and required's gate], length: 13pt, {
  // one window where init writes, one gate that must be passed
  cdraw.line((0.6, 4.8), (15.8, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.0, 4.5), (9.0, 5.1), stroke: luma(100))
  cdraw.content((4.6, 5.7), [initializer or ctor #linebreak() `init` writes here], size: 6pt)
  cdraw.content((12.6, 5.7), [after construction #linebreak() `init` refuses], size: 6pt)
  cdraw.content((9.0, 3.9), [construction ends], size: 6.5pt)
  cdraw.rect((0.6, 1.2), (8.6, 2.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.6, 1.9), [`required` member unset #linebreak() at construction], size: 6pt)
  cdraw.line((8.6, 1.9), (10.0, 1.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.0, 1.2), (17.6, 2.6), fill: luma(205), radius: 0.02)
  cdraw.content((13.8, 1.9), [error CS9035 #linebreak() before anything runs], size: 6pt)
})

#listing("csharp-net/samples/src/Ch04/Members.cs", first: 93, last: 96, caption: [init defaults survive, initializers override])

== indexers

An indexer is a property with parameters, invoked with bracket syntax. It
turns an object into something indexable without exposing the underlying
storage. Indexers can overload on their parameter lists, take any
parameter types, and use `get`, `set`, and `init` accessors like
properties. There is no auto implemented indexer, storage is always
yours:

#listing("csharp-net/samples/src/Ch04/Members.cs", first: 20, last: 30, caption: [an array backed indexer over days])

#diagram([an indexer, bracket syntax delegated to private storage], length: 13pt, {
  // the caller's brackets land in one cell of the hidden array
  cdraw.rect((0.2, 4.6), (3.4, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((1.8, 5.1), [`log[3]`], size: 6pt)
  cdraw.line((3.4, 5.1), (5.0, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.0, 2.2), (12.4, 6.0), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((8.7, 5.4), [`this[int day]`], size: 6pt)
  cdraw.line((8.7, 5.0), (8.7, 3.8), stroke: luma(100), mark: (end: ">"))
  for i in range(7) {
    let f = if i == 3 { luma(205) } else { luma(230) }
    cdraw.rect((5.4 + i, 2.9), (6.4 + i, 3.7), fill: f, radius: 0.02)
  }
  cdraw.content((8.8, 1.4), [`_readings`, your storage, there is no auto implemented indexer], size: 6.5pt)
  cdraw.line((12.4, 4.9), (13.8, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.2, 4.9), [overloads on the #linebreak() parameter list], size: 6.5pt)
})

#listing("csharp-net/samples/src/Ch04/Members.cs", first: 98, last: 103, caption: [bracket syntax on the calling side])

== events

An event is a delegate field with restricted access, a delegate being
chapter 7's type whose values are methods: external code can
only attach and detach handlers with `+=` and `-=`, and only the
declaring type can invoke it. That restriction is the point, it stops
subscribers from invoking each other's handlers or clearing the list.
Inside the declaring class the event is an ordinary delegate field:

#listing("csharp-net/samples/src/Ch04/Members.cs", first: 32, last: 48, caption: [an event declared, raised with null conditional invocation])

#diagram([an event, one delegate field behind permission walls], length: 13pt, {
  // outside code gets two verbs, the declaring type gets the invoke
  cdraw.rect((0.4, 4.4), (5.2, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((2.8, 4.9), [outside code], size: 6pt)
  cdraw.line((5.2, 5.15), (8.0, 4.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.2, 4.65), (8.0, 4.45), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.6, 5.5), [`+=`], size: 6pt)
  cdraw.content((6.6, 4.0), [`-=`], size: 6pt)
  cdraw.rect((8.0, 2.8), (14.4, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.2, 4.1), [`Breached` #linebreak() delegate field], size: 6pt)
  cdraw.line((17.0, 4.9), (14.4, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((17.0, 4.4), (22.2, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((19.6, 4.9), [declaring type], size: 6pt)
  cdraw.content((15.7, 5.5), [`?.Invoke`], size: 6pt)
  cdraw.content((11.2, 1.4), [zero subscribers means null, #linebreak() which is why the invoke is null conditional], size: 6.5pt)
})

The `?.` in `Breached?.Invoke(...)` guards the case where no one
subscribed, since an event with no handlers is null. The test subscribes
a lambda, records a value under the limit where the handler must stay
silent, then records one over it:

#listing("csharp-net/samples/src/Ch04/Members.cs", first: 105, last: 114, caption: [subscribing and observing the threshold event])

Chapter 7 covers delegates, the multicast model, and unsubscription
discipline in depth.

== extension members

Extensions add members to a type you do not own, without inheritance and
without editing the original. Before C\# 14 there was exactly one form, a
static method in a static class with `this` on its first parameter. C\# 14
adds the `extension` block: a declaration inside a static class that
names a receiver once, then declares methods, properties, and operators
against it:

#listing("csharp-net/samples/src/Ch04/Members.cs", first: 50, last: 73, caption: [the this form and two C\# 14 extension blocks side by side])

#diagram([extension members, an instance call rewritten to a static one], length: 13pt, {
  // what the call looks like, what the compiler actually emits
  cdraw.content((8.0, 6.5), [what the compiler does with an instance looking call], size: 7pt)
  cdraw.rect((0.4, 4.6), (5.4, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.9, 5.1), [`source.IsEmpty()`], size: 6pt)
  cdraw.line((5.4, 5.1), (7.0, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.0, 5.1), [a static call in an imported static class, #linebreak() the receiver becomes the first argument], size: 6.5pt)
  cdraw.content((7.6, 3.2), [one c\# 14 block names one receiver, then three member kinds hang off it], size: 6.5pt)
  let chips = ((2.6, [methods]), (7.2, [properties]), (12.0, [statics]))
  for (x0, t) in chips {
    cdraw.rect((x0, 1.2), (x0 + 4.2, 2.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.1, 1.7), t, size: 6pt)
  }
})

The three blocks in that listing are worth reading line by line. The
`this` form is unchanged since C\# 3 and still compiles. The first
extension block takes a named receiver, `source`, and everything inside
can use it, so `IsEmpty` is a property, something the old form could
never express. The second block omits the receiver name and declares a
static member, which makes `CountingTo` appear as a static member of
`IEnumerable<int>` itself. Calls on the using side look native:

#listing("csharp-net/samples/src/Ch04/Members.cs", first: 116, last: 123, caption: [instance extension property, method, and a static extension in use])

#callout("note", "extensions are syntax, not mutation", [
  Extension members are static calls the compiler resolves at compile
  time. They cannot see private state, cannot be overridden, and only
  apply when their containing namespace is imported. A receiver declared
  `ref` in the block lets an extension mutate a struct receiver in
  place, which is the one form with by reference semantics.
])

C\# 15 completes the set with extension indexers, indexed access on a
type you do not own. Indexers have no name and are always instance
members, so the block must name its receiver: `extension(Path path)`
gives the indexer body a variable to index through, an unnamed
`extension(Path)` does not. Everything else is an ordinary indexer,
including overloads on the parameter list:

#listing("csharp-net/samples/src/Ch04/ExtensionIndexers.cs", first: 5, last: 15, caption: [a C\# 15 extension indexer and an overload, one named receiver])

Resolution walks the same scopes as extension method calls, and
instance indexers win first: arrays and lists keep their own bracket
access untouched. The extension indexer binds only where no instance
indexer applies, which is why the receiver below is declared
`IEnumerable<int>`, a lazy sequence with no indexer of its own:

#listing("csharp-net/samples/src/Ch04/ExtensionIndexers.cs", first: 20, last: 25, caption: [the call site reads as membership, the extension carries it])

#diagram([extension indexers, the last member kind joins the block], length: 13pt, {
  // the eras stack, c# 15 adds the indexer row
  let rows = (
    ([c\# 3], [methods on the `this` parameter]),
    ([c\# 14], [blocks: properties, operators, statics]),
    ([c\# 15], [indexers, the set is complete]),
  )
  for (i, row) in rows.enumerate() {
    let y = 4.6 - i * 1.3
    cdraw.rect((0.4, y - 0.5), (3.2, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((1.8, y), row.at(0), size: 6pt)
    cdraw.line((3.2, y), (4.4, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((11.4, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((11.4, 0.1), [instance indexers bind first, #linebreak() the receiver must be named], size: 6.5pt)
})

sources: learn.microsoft.com, c\# 14 what's new, extension members,
extension declaration, field keyword, init, required, indexers, events,
and object initializers pages accessed 2026-09-08, c\# 15 what's new,
extension indexers, and extension declaration pages accessed 2026-09-13.
Sample behavior verified by `make verify-csharp`, 10 tests.
