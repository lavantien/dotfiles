#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= classes and objects

Every Java program is classes: all statements live in methods, all
methods live in types, and the two workhorse type forms are the class
and the interface. Chapter 4 covered the value side, primitives and
their boxes, this chapter covers the machinery: the four member kinds,
construction order, inheritance and dispatch, the abstract and
interface forms, and records as the fixed data shape. Chapter 2 walked
the version ladder, here each feature appears with the release it
arrived in.

== the four member kinds

Members sit on two axes. Static or instance decides what the member
belongs to, the class itself or each object. Field or method decides
whether it is state or behavior. Four combinations, and a class field
is one copy shared by every instance while an instance field is one
slot per object:

#listing("java/samples/src/Ch05/Members.java", first: 14, last: 27, caption: [one class with all four member kinds])

The static method has no `this`: it runs without a receiver, so it
cannot read `id` or call `doubled()`, and the sample proves the sharing
by watching `Gauge.made` climb as two objects build themselves. The
instance method receives the current object as an implicit `this`
parameter, which is why `this.id` inside `doubled()` means the
receiver's slot. Access outside the class qualifies by class name for
statics and by expression for instances, `Gauge.nextId()` versus
`g.doubled()`.

#diagram([the two member axes: what it belongs to, and what it is], length: 13pt, {
  let cell(x0, x1, y0, y1, head, body, dark) = {
    cdraw.rect((x0, y0), (x1, y1), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content(((x0 + x1) / 2, (y0 + y1) / 2 + 0.55), head, size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, (y0 + y1) / 2 - 0.35), body, size: 6pt)
  }
  cell(6.2, 14.6, 5.2, 6.9, [class member], [`static`], true)
  cell(15.2, 23.6, 5.2, 6.9, [instance member], [per object], true)
  cdraw.content((3.0, 6.05), [field, state], size: 6.5pt)
  cdraw.content((3.0, 4.15), [method, behavior], size: 6.5pt)
  cell(6.2, 14.6, 3.5, 5.2, [class field], [one copy], false)
  cell(15.2, 23.6, 3.5, 5.2, [instance field], [one slot each], false)
  cell(6.2, 14.6, 1.8, 3.5, [class method], [no `this`], false)
  cell(15.2, 23.6, 1.8, 3.5, [instance method], [`this` implicit], false)
  cdraw.content((14.9, 0.4), [statics qualify by class name, instances by expression], size: 6pt)
})

== construction and initialization order

Object creation is a fixed sequence, and the sample records it in a
trace list: memory is allocated and zeroed, the superclass chain
constructors run top down from `Object`, then field initializers and
instance initializer blocks run in source order, then the rest of the
constructor body. Class initializers run once, at first use, before
any instance exists, base class before subclass:

#listing("java/samples/src/Ch05/Construction.java", first: 32, last: 52, caption: [the initialization order the trace asserts, and the java 25 prologue])

The measured trace is exact: `engine ctor body`, then `car field
initializer`, then `car instance init block`, then `car ctor body`,
with both static initializers already done. Before java 25 none of
that constructor body could run before the `super(...)` call, so
argument validation had to choose between throwing after the
superclass construction work and a static factory. Flexible
constructor bodies (JEP 513, final in java 25) lifted the rule: a
prologue may validate arguments and even assign fields of the same
class that lack initializers, and the explicit constructor invocation
comes last:

#listing("java/samples/src/Ch05/Construction.java", first: 42, last: 52, caption: [prologue validation and field assignment before super()])

The failure path is the point. `new Car(4, "")` throws before any
constructor body anywhere has run, and the trace shows only the two
static initializers. The prologue runs in an early construction
context: it may not read `this` as an object, only assign the blank
final fields, and it may not reference the instance being built
otherwise. `this(...)` delegation keeps the same shape, one prologue,
then the delegated call.

#diagram([one construction, top to bottom], length: 13pt, {
  cdraw.rect((7.2, 6.4), (16.4, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 7.0), [class initializers, once at first use], size: 6pt)
  cdraw.line((11.8, 6.4), (11.8, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.2, 4.4), (16.4, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.8, 5.0), [prologue, java 25: validate, assign blanks], size: 6pt)
  cdraw.line((11.8, 4.4), (11.8, 3.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.2, 2.4), (16.4, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 3.0), [super chain, Object down to the direct super], size: 6pt)
  cdraw.line((11.8, 2.4), (11.8, 1.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((7.2, 0.4), (16.4, 1.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 1.0), [field initializers in source order, rest of body], size: 6pt)
  pane(17.4, 23.6, 7.2, [before 25], [super() first], [no exceptions], [validate after])
  cdraw.content((11.8, -0.6), [the prologue is the only part that may run before the super chain], size: 6pt)
})

Records follow the same sequence and add two forms: the canonical
constructor the header implies, and a compact constructor that omits
the parameter list, validates, and lets the compiler do the field
assignments. Chapter 6 revisits the generic forms.

== inheritance: overriding, hiding, dispatch

`extends` gives one superclass, every class but `Object` has one, and
a subclass inherits the accessible members. Fields and static methods
hide, instance methods override, and the difference decides everything
about polymorphism:

#listing("java/samples/src/Ch05/Dispatch.java", first: 15, last: 31, caption: [the same names, three different relations: hide, override, one-step super])

Hiding follows the static type. `b.i` reads the subclass slot, the
cast view reads the superclass slot, both slots exist in one object.
Overriding follows the runtime type. `asA.f()` calls `B.f()` through
an `A` variable, because instance method invocation is a virtual
lookup on the receiver's actual class, and that is the entire basis of
substitutability: a `Circle[]` may hold any shape and each element
computes with its own method. `super.f()` is the one exception, it
starts the lookup one class up and runs exactly one step, `C.f()`
reaching `B.f()` but never `A.f()` directly.

#diagram([one receiver, two views: hiding by static type, dispatch by runtime type], length: 13pt, {
  cdraw.rect((0.4, 3.4), (6.4, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((3.4, 6.1), [static type A], size: 6.5pt)
  cdraw.content((3.4, 5.2), [field i: 1], size: 6pt)
  cdraw.content((3.4, 4.3), [method f: declared], size: 6pt)
  cdraw.rect((8.4, 3.4), (14.4, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.4, 6.1), [runtime type B], size: 6.5pt)
  cdraw.content((11.4, 5.2), [field i: 2, hides], size: 6pt)
  cdraw.content((11.4, 4.3), [method f: overrides], size: 6pt)
  cdraw.line((6.4, 5.2), (8.4, 4.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((7.4, 5.5), [one object], size: 6pt)
  pane(15.4, 23.6, 6.6, [reads through A], [asA.i gives 1], [asA.f() gives -2,], [the body of B])
  cdraw.content((11.8, 2.2), [covariant returns since 5: a subclass may narrow the return type], size: 6pt)
  cdraw.content((11.8, 1.1), [`@Override` makes the intent a compile check, and javac enforces it], size: 6pt)
})

A class can also be `final`, closed to extension, the default stance
for most classes. `abstract` is the opposite move, the class declares
signature without body and cannot be instantiated, a concrete subclass
must implement every abstract method. Sealed types, the third
possibility between open and final, arrived final in java 17 (JEP 409,
after previews in 15 and 16) and chapter 9 owns them, because their
whole value is pattern exhaustiveness.

== interfaces

An interface is a reference type of signatures. A class gets one
superclass but implements any number of interfaces, which is how Java
splits single inheritance of state from multiple inheritance of
behavior. The member rules evolved in three steps and the releases are
worth remembering: before java 8 an interface held only public
abstract methods and constants, java 8 added `default` and `static`
methods so the collections could grow lambda-facing methods without
breaking every implementation, java 9 added private methods for code
shared between defaults:

#listing("java/samples/src/Ch05/Interfaces.java", first: 17, last: 33, caption: [one abstract, one private since 9, one default, one static since 8])

A default method is an inherited implementation the class may keep or
override, and an override always wins. Two interfaces bringing the
same default signature is the diamond, and the language refuses to
guess: the class must override, and `Vocal.super.call()` picks a side
explicitly. Interfaces hold no instance state, defaults can only call
the interface's other methods, so the multiple inheritance is of
behavior alone.

#listing("java/samples/src/Ch05/Interfaces.java", first: 35, last: 51, caption: [diamond clash resolved in code, and a plain override beating a default])

C\#'s near-identical machinery lives in #xref-to("csharp-net", "typesystem"), where default interface methods arrived only in c\# 8, five
years after java.

== records as the fixed data shape

A record is a class that promises its header is the whole state. The
compiler generates the canonical constructor, the accessors named
after each component, and `equals`, `hashCode`, and `toString` derived
from the components. Records previewed in 14 and 15 and arrived final
in java 16 (JEP 395), with the deeper type treatment in chapter 4.
What remains here is the contract the generated methods carry, because
handwritten classes still carry it too:

#listing("java/samples/src/Ch05/Contracts.java", first: 19, last: 42, caption: [the handwritten trio every value class owes Object])

`equals` defines value equality against `==` reference identity: reflexive,
symmetric, transitive, consistent, and `null` is equal to nothing, which
the `instanceof` test gives for free since it is false on `null`.
`hashCode` must agree with it: equal objects carry equal hash codes,
or every hash table misbehaves. The sample measures the failure mode
directly:

#listing("java/samples/src/Ch05/Contracts.java", first: 88, last: 91, caption: [an equals with no matching hashCode loses the entry, measured])

That class also trips the `[overrides]` lint, javac knows the smell,
and the sample suppresses it in exactly that one place to run the
experiment. The same trio from a record needs no writing at all:

#listing("java/samples/src/Ch05/Contracts.java", first: 59, last: 65, caption: [a record pair, and a compact constructor that validates])

The compact constructor assigns the fields implicitly after the body
runs, so validation is its only job. `isRecord()` distinguishes the
shapes at runtime, and the accessor rule is strict: component `x`
produces method `x()`, never `getX()`.

#callout("pitfall", "records are shallowly immutable", [
  A record's fields are final, but a component of reference type can
  still point at mutable state, `record Log(ArrayList<String> lines)`
  is a record holding a mutable list. Deep immutability is a design
  property you bring, chapter 12 returns to it with `List.of` copies.
])

== why contextual keywords matter

Java froze its reserved word list at java 1 and kept it frozen, and
every later language word is contextual: meaningful in one syntactic
position, an ordinary identifier everywhere else. `record` and
`sealed` arrived in 16 and 17, `permits` in 17, `yield` in 14 when
switch expressions did, `var` in 10, and code written before any of
them keeps compiling:

#listing("java/samples/src/Ch05/Contextual.java", first: 29, last: 43, caption: [four new words as four ordinary locals, one record in the same file])

The one hyphenated exception proves the design discipline: `non-sealed`,
needed by sealed types in java 17, is the first keyword spelled with a
hyphen, because `nonsealed` would have stolen an identifier outright.

#callout("note", "why contextual matters", [
  A frozen reserved set is why old code never breaks on new language.
  When you meet a new word in java, check whether it is contextual. If
  it is, the word is also a legal identifier, which is the tell that it
  arrived in a later release. C\# runs the same policy from the other
  direction, #xref-to("csharp-net", "lexical") counts its contextual table growing past 48 words.
])

sources: openjdk.org/jeps/395, /jeps/409, and /jeps/513, statuses and
release attributions checked 2026-10-04. Java in a Nutshell 8th
edition, chapters 3 and 5, object lifecycle, inheritance, and the
common method contracts, pages 107 to 216. Every behavioral claim in
this chapter is asserted by `java/samples/src/Ch05`, 33 checks green
under `pwsh -NoProfile -File tools/run-java-samples.ps1 -Chapter Ch05`
on the pinned build 27+35-2325, measured 2026-10-04.
