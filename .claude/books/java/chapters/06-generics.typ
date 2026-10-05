#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= generics

Generics arrived in java 5 (JSR 14) to let a container say what it
holds, turning a whole family of runtime cast failures into compile
errors. The design constraint that shaped everything after it was
migration compatibility: millions of lines of nongeneric java 1
through 4 code had to keep running and even interoperate with the new
generic collections. The mechanism that bought that compatibility,
type erasure, is also the source of every rough edge this chapter
measures.

== type parameters

A generic declaration introduces a type parameter, `List<E>`, and each
use supplies a type argument, `List<String>`. The parameter stands for
a reference type only, primitives are excluded and autoboxing bridges
the gap. The diamond, `new ArrayList<>()`, arrived in java 7 to stop
the doubled spelling the compiler could already infer. A generic
method declares its own parameter without the class carrying one:

#snippet(
  "static <T> T pick(T a, T b, boolean first) {\n"
  + "  return first ? a : b;\n"
  + "}\n"
  + "String s = pick(\"a\", \"b\", false);  // T inferred as String\n",
  lang: "java",
)

Inference reads the arguments and the expected return type. Mixed
arguments infer the least upper bound, `pick(1, 2L, true)` is typed
`Number` even though the value returned is the `Integer`. Chapter 2
walked the ladder, `var` since 10 rides on the same inference engine.

== erasure and bridges

`javac` checks every type argument, then removes the parameters from
the bytecode it emits. One `List` class exists at runtime, not one per
argument, and the sample proves both halves:

#listing("java/samples/src/Ch06/Erasure.java", first: 20, last: 23, caption: [one runtime class behind every use])

#listing("java/samples/src/Ch06/Erasure.java", first: 41, last: 45, caption: [the names agree and no arguments survive])

Erasure explains the compile errors that otherwise look arbitrary. Two
overloads that differ only in a type argument erase to the same raw
signature and the language refuses them:

#snippet(
  "// will not compile: both erase to totalOrders(Map)\n"
  + "int totalOrders(Map<String, List<String>> byName);\n"
  + "int totalOrders(Map<String, Integer> byCount);\n",
  lang: "java",
)

When a class implements a parameterized interface, the erased call
sites need a target, so the compiler writes a synthetic bridge. The
sample counts the bridge directly in the class file's reflection
view:

#listing("java/samples/src/Ch06/Erasure.java", first: 24, last: 34, caption: [compareTo(Node) is the real method])

#listing("java/samples/src/Ch06/Erasure.java", first: 46, last: 63, caption: [one synthetic bridge compareTo(Object) beside it, measured])

`Comparable<Node>` through an interface variable dispatches the
bridge, which casts and forwards. The one idiom that buys a type back
is the class token, `Class<T>` is reified because it names one class:

#listing("java/samples/src/Ch06/Erasure.java", first: 36, last: 39, caption: [the token idiom, a reified type carried as a value])

#diagram([what javac sees, what the jvm sees], length: 13pt, {
  pane(0.3, 11.3, 6.8, [compile time, javac], [`List<String>`], [`List<Integer>`], [two checked types], [casts inserted at use])
  cdraw.line((11.6, 4.0), (12.4, 4.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.0, 4.6), [erasure], size: 6pt)
  pane(12.7, 23.4, 6.8, [runtime, the jvm], [`java.util.ArrayList`], [one class], [bridges where needed], [tokens buy types back])
})

== variance: arrays covariant, generics invariant

Java 1 made arrays covariant, `String[]` assigns to `Object[]`, so
pre-generic methods like a sort for `Object[]` could serve every
reference array. The hole is measurable: the array remembers its real
element type and checks every store at runtime:

#listing("java/samples/src/Ch06/Variance.java", first: 29, last: 38, caption: [covariance compiles, the runtime check pays for it])

When generics arrived the same question came back, is
`List<String>` a subtype of `List<Object>`, and the answer was no. If
it were, the same store failure would move into collections with no
runtime check to catch it, since the element type is erased:

#snippet(
  "// will not compile: generics are invariant\n"
  + "List<Object> objects = new ArrayList<String>();\n"
  + "// the error: incompatible types\n",
  lang: "java",
)

Invariance is safe but stiff, so use-site variance arrived with
wildcards, and the mnemonic is PECS, producer extends, consumer
super. A list you read from is `List<? extends T>`, a list you write
to is `List<? super T>`:

#listing("java/samples/src/Ch06/Variance.java", first: 19, last: 26, caption: [one signature with both variance directions])

#listing("java/samples/src/Ch06/Variance.java", first: 40, last: 54, caption: [extends reads at the bound, super writes below it, measured])

The rules are strict because they are static: an extends wildcard
accepts no writes except `null`, a super wildcard reads back only
`Object`. Chapter 12 shows these shapes all over the collections api,
`Collections.copy` has exactly this signature.

#diagram([three container relations and what enforces each], length: 13pt, {
  let row(y, kind, rule, when) = {
    cdraw.rect((0.2, y - 0.6), (5.4, y + 0.6), fill: luma(235), radius: 0.02)
    cdraw.content((2.8, y), kind, size: 6.5pt)
    cdraw.content((9.6, y), rule, size: 6pt)
    cdraw.content((17.4, y), when, size: 6pt)
  }
  row(5.6, [arrays], [covariant, `C[]` to `P[]`], [runtime ArrayStoreException])
  row(4.0, [generics], [invariant, no relation], [compile time, always])
  row(2.4, [wildcards], [`? extends` covariant reads], [`? super` contravariant writes])
  row(0.8, [go, c\#], [invariant, reified], [the roads not taken, below])
  cdraw.content((9.6, 6.6), [relation], size: 6pt)
  cdraw.content((17.4, 6.6), [enforcement], size: 6pt)
})

Go's generics (#xref-to("go", "generics")) took the other road in 1.18: invariant, no
wildcards, no variance annotation at all, and types carried as
dictionaries at compile time. C\#'s (#xref-to("csharp-net", "generics")) are reified, the
runtime knows `List<int>` from `List<string>`, which is why that
platform overloads on generic arguments and this one cannot.

== bounds

A bound narrows what a parameter may stand for, and the bound's
members become callable inside the declaration:

#listing("java/samples/src/Ch06/Bounded.java", first: 18, last: 25, caption: [one bound, Number's interface unlocked])

Bounds stack, class first then interfaces, and a bound may mention the
parameter itself, the recursive or f-bounded shape every `Comparable`
hierarchy uses:

#listing("java/samples/src/Ch06/Bounded.java", first: 27, last: 36, caption: [a record meeting two bounds, and the method that demands both])

== heap pollution and `@SafeVarargs`

A varargs parameter is an array, arrays are covariant, and generics
erase, so `List<String>...` is really an untyped `List[]` slot anyone
can write through. A variable whose static type lies about its
contents is heap pollution, and the failure lands far from the cause:

#listing("java/samples/src/Ch06/Pollute.java", first: 29, last: 40, caption: [the polluted slot throwing on read, measured])

The annotation `@SafeVarargs` is the developer's promise that the
method only reads the array or copies it out safely, and it silences
the warning at the declaration and every call site. It arrived in
java 7 for static and final methods only, java 9 extended it to
private methods:

#listing("java/samples/src/Ch06/Pollute.java", first: 18, last: 26, caption: [a genuinely safe varargs method, annotated, private since 9])

This sample keeps one deliberately unsafe method to run the failure,
and the `@SuppressWarnings("varargs")` scoped to it is the honest
marker of that choice. The general rule stands: do not build generic
arrays, and when an api hands you one, read it or copy it, never
publish it.

#callout("pitfall", "raw types are still legal, still a trap", [
  `List list = new ArrayList()` compiles today with a warning, and
  every element that comes out is `Object`. Raw types exist only for
  migration compatibility, this book's samples run under
  `-Xlint:all -Werror` where any raw or unchecked use fails the
  build, which is the discipline production code should keep.
])

== generics, records, and patterns

A record can be generic, and the generated members are written once
over the parameters. Chapter 9 owns pattern matching, one interaction
belongs here because it is erasure at work: a pattern may not spell a
type argument the runtime cannot check. Measured on the pinned build,
`Object o` against `Box<Integer>` fails with `Object cannot be
safely cast to Box<Integer>`. The component patterns carry the check
instead, through inference:

#listing("java/samples/src/Ch06/GenericRecords.java", first: 32, last: 42, caption: [the class-level argument refused, components inferred and checked])

The same-type selector, where the expression is already known to be
`Box<Integer>`, is the one spelling that survives, because nothing is
unchecked about it:

#listing("java/samples/src/Ch06/GenericRecords.java", first: 43, last: 46, caption: [the one legal spelled form])

#snippet(
  "// will not compile, measured on build 27+35-2325:\n"
  + "Object o = List.of();\n"
  + "if (o instanceof List<String> l) { }\n"
  + "// error: Object cannot be safely cast to List<String>\n",
  lang: "java",
)

sources: openjdk.org/jeps/513 and the java 5 through 9 release
attributions discussed here follow the verified spine in
docs/audit/java.md, checked 2026-10-04. `@SafeVarargs` applicability
read from the java 27 api page, docs.oracle.com, accessed 2026-10-04.
Java in a Nutshell 8th edition, chapter 4, generics through nested
types, pages 162 to 198. Every behavioral claim in this chapter is
asserted by `java/samples/src/Ch06`, 26 checks green under
`pwsh -NoProfile -File tools/run-java-samples.ps1 -Chapter Ch06` on
the pinned build 27+35-2325, measured 2026-10-04.
