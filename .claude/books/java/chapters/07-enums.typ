#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= enums, annotations, and nested types

Three specialized type forms round out the reference type story: enums
since java 5, a class with a fixed set of self-typed instances,
annotations since java 5, an interface specialized for metadata, and
nested types since java 1.1, types declared inside other types. None
of the three is syntax sugar, each compiles to a real class file, and
each carries rules this chapter measures.

== an enum is a class

`enum` declares a class with a fixed number of instances, created at
class initialization and never again. The constants are static final
fields of the enum's own type, the constructor runs once per
constant, and the class extends `java.lang.Enum`, which is why an enum
cannot extend anything else:

#listing("java/samples/src/Ch07/Planet.java", first: 6, last: 34, caption: [constants with arguments, fields, a constructor, methods, and a nested enum with constant bodies])

Everything after the constant list is ordinary class body. The nested
`Op` shows the further step, an abstract method in the enum forces
every constant to carry its own body, the state machine pattern in
one declaration:

#listing("java/samples/src/Ch07/Planet.java", first: 29, last: 34, caption: [constant-specific bodies implementing one abstract method])

The family machinery comes from `java.lang.Enum`. `values()` returns
a fresh array every call, callers may sort it without vandalizing the
type. `ordinal()` is declaration position and `compareTo` is exactly
that order, `valueOf` parses a name back to the same instance, and
`name` and `toString` start identical. The constants are singletons,
which is the singleton story: no reflective construction, no
serialization duplicate, one instance each:

#listing("java/samples/src/Ch07/Singleton.java", first: 24, last: 36, caption: [the enum singleton, and the measured refusal to construct a second])

The reflection refusal is a jvm rule, `Constructor.newInstance` checks
for enum classes specifically, so the classic singleton hazards of
double construction and reflective bypass are structurally closed.

#diagram([one enum declaration, what the runtime holds], length: 13pt, {
  pane(0.3, 8.3, 6.8, [declaration], [`enum Planet`], [8 constants,], [constructor, fields, methods], [abstract Op nested])
  cdraw.line((8.6, 4.0), (9.6, 4.0), stroke: luma(100), mark: (end: ">>"))
  pane(9.9, 17.9, 6.8, [class initialization], [8 static final instances], [Enum superclass], [values() copies fresh])
  pane(18.2, 23.4, 6.8, [closed], [no new, no clone,], [no reflective ctor,], [no subclassing])
})

The collections answer enums with two purpose-built families.
`EnumSet` is a bit vector, one long covers universes up to 64
constants, `RegularEnumSet` in the measurement, with a `JumboEnumSet`
beyond. `EnumMap` is an array indexed by ordinal, which is why its
iteration follows declaration order while a `HashMap` follows hashes.
Both demand the enum's `Class` object at construction because the
universe must be known:

#listing("java/samples/src/Ch07/Planet.java", first: 60, last: 72, caption: [EnumSet range over the declaration, EnumMap in declaration order])

== annotations

An annotation type is an interface with restrictions: no generics,
zero-argument methods only, restricted return types, and `default`
values allowed. It compiles to an interface extending
`java.lang.annotation.Annotation`. The design intent was metadata
without semantics, compile time hints like `@Override`, and the
platform still ships those, but container frameworks put so much
behavior behind runtime annotations that the strict reading has
eroded:

#listing("java/samples/src/Ch07/Annotations.java", first: 23, last: 36, caption: [a repeatable annotation and its container, both RUNTIME])

Two meta-annotations do the policy work. `@Target` says where the
annotation may appear, its `ElementType` enum grew `TYPE_PARAMETER`
and `TYPE_USE` in java 8 so annotations could sit inside type
positions. `@Retention` says how far it survives: `SOURCE` is
discarded by `javac`, `CLASS` lands in the class file unseen by the
jvm, `RUNTIME` is readable through reflection. The sample reads the
retention of platform annotations off their own class objects, and
`@Override` measures as `SOURCE`:

#listing("java/samples/src/Ch07/Annotations.java", first: 52, last: 58, caption: [retention read off the annotation types themselves])

The original java 5 platform set is `@Override`, `@Deprecated`, and
`@SuppressWarnings`. Java 7 added `@SafeVarargs`, java 8 added
`@FunctionalInterface` and `@Repeatable`. Repeatability works exactly
as the sample shows, the class file stores the container type and
reflection expands it back, so `getAnnotationsByType` flattens while
`getAnnotations` shows the wrapper:

#listing("java/samples/src/Ch07/Annotations.java", first: 43, last: 51, caption: [two spellings of the same two annotations])

The service spine in chapters 19 through 31 leans on annotations
lightly, the http kernel is hand-routed, but the testing chapter uses
a `@Repeatable` tag the same way this sample does.

== nested types

Types nest inside types in four shapes, and the vocabulary matters
because "inner class" colloquially covers three of them. The
declaration picks the shape: `static` member type, nonstatic member
class, local class, anonymous class:

#listing("java/samples/src/Ch07/Nesting.java", first: 20, last: 45, caption: [static nested, inner with qualified this, nested record, local class and record])

A static member type is a type in a namespace, no outer instance, the
shape of `Map.Entry`. A nonstatic member class, the true inner class,
carries a reference to an enclosing instance, which is how `Tally`
touches the outer private field, and `Outer.this` is the unambiguous
name for that link. Local classes live in a block and see the
effectively final locals of it, and local records arrived with java
16 when records made the constant-field restriction obsolete. Records
and interfaces nested in a class are implicitly static.

Until java 11 nesting was a compiler fiction: separate class files
needed synthetic package-private bridge methods so `Tally` could read
`counter` at all. Nest-based access control (JEP 181) taught the jvm
the family directly, `NestHost` and `NestMembers` attributes, private
access across nestmates, and reflection exposes the relation:

#listing("java/samples/src/Ch07/Nesting.java", first: 71, last: 75, caption: [the nest, java 11, visible through Class])

The anonymous class is a local class with no name, defined and
instantiated in one `new` expression. It still earns its keep where a
one-off subclass or an interface plus state is needed, but for the
single-method case lambdas took over, and the takeover is about
identity semantics, not syntax. The sample measures the split from
both sides:

#listing("java/samples/src/Ch07/Nesting.java", first: 51, last: 60, caption: [the same two captures, lambda and anonymous class])

#listing("java/samples/src/Ch07/Nesting.java", first: 83, last: 90, caption: [this means different objects, measured])

Inside the lambda, `this` is the enclosing instance, the lambda has no
object of its own. Inside the anonymous class, `this` is the fresh
instance and the outer one needs qualification. Reflection tells the
same story, the anonymous class has an empty simple name and
`isAnonymousClass()` is true, while the lambda's class is a runtime
artifact with no source-level identity at all. Chapter 8 opens with
how lambdas actually compile.

#callout("note", "when to reach for which nest", [
  Static nested type when the pairing is namespace only. Inner class
  when each helper instance genuinely belongs to one outer instance,
  iterators are the canonical case. Local class when a block needs a
  named helper with state or multiple instances. Anonymous class only
  when you need fields or several methods on a throwaway type.
  Lambda or method reference for everything single-method, chapter 8.
])

sources: Java in a Nutshell 8th edition, chapter 4, enums, annotations,
lambda expressions, and nested types, pages 175 to 198, and its
appendix on the post-17 arc. `@Repeatable` semantics read from
docs.oracle.com java 27 api, accessed 2026-10-04, nestmate facts from
openjdk.org/jeps/181, checked 2026-10-04. Every behavioral claim is
asserted by `java/samples/src/Ch07`, 26 checks green under
`pwsh -NoProfile -File tools/run-java-samples.ps1 -Chapter Ch07` on
the pinned build 27+35-2325, measured 2026-10-04.
