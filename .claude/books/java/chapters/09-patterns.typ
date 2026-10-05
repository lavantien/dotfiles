#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= pattern matching

Pattern matching is the longest arc project amber has run: instanceof
patterns finalized in java 16, record patterns and switch patterns in
21, unnamed variables and patterns in 22, and primitive patterns
still in preview, the fifth round in java 27. The destination is
algebraic data types java style: sealed interfaces as the sum, records
as the product, and a switch that checks its own coverage against the
permits list. Chapter 2 walked the ladder, this chapter works the
machinery.

== instanceof patterns

The java 8 idiom was three steps, test, cast, bind, and the cast could
fail if the test and the cast ever drifted apart. The pattern does all
three in one expression, and the compiler scopes the binding to exactly
the places where the test succeeded:

#listing("java/samples/src/Ch09/InstanceofPatterns.java", first: 15, last: 21, caption: [test and bind in one step, s scoped to the branch])

Flow scoping is the interesting part. The binding is live where the
pattern is guaranteed true, dead where it is false, which lets it join
boolean chains and survive negation without any cast anywhere:

#listing("java/samples/src/Ch09/InstanceofPatterns.java", first: 23, last: 33, caption: [the binding in a condition chain, and after a failed negation])

One rule never moved: no pattern matches `null`, not even a type
pattern on `Object`, so a pattern test doubles as a null test. The
sample runs `null` through all three helpers to pin it.

== record patterns

A record pattern deconstructs a record into its components, matching
when the value is an instance of the record type and each component
pattern matches. Nesting goes as deep as the data:

#listing("java/samples/src/Ch09/RecordPatterns.java", first: 22, last: 27, caption: [two levels of deconstruction in one test])

Component patterns may use `var`, inferring each component's declared
type, which keeps the spelling short without giving up the check. In
switch labels the same shapes appear after `case`:

#listing("java/samples/src/Ch09/RecordPatterns.java", first: 37, last: 47, caption: [full spelling and var spelling of the same two cases])

One sharp edge is worth measuring because it looks like a spec bug
until you read it as an optimization. A component pattern that is
unconditional for the component's declared type, `String label`
against a `String` component, has its runtime check elided, so it
matches even a null component. A narrowing component pattern keeps
the check and rejects the null:

#listing("java/samples/src/Ch09/RecordPatterns.java", first: 51, last: 60, caption: [the unconditional component matched null, the bare type test does not])

The rule is component-local and symmetric with chapter 6's erasure
story: the compiler only skips checks it can prove, and `null` is
assignable to every reference type.

== switch patterns and exhaustiveness

Sealed types since 17 (JEP 409) say who may implement them, and switch
patterns since 21 (JEP 441) read that list. Together the compiler can
prove coverage, and a switch over a sealed type needs no `default`:

#listing("java/samples/src/Ch09/SwitchPatterns.java", first: 15, last: 27, caption: [sealed interface, records, one switch, no default])

The proof is the permits list, and the compiler walks it as a decision
procedure:

#flow(
  [exhaustiveness checking over a sealed tree],
  node((0, 0), [selector type, sealed Shape]),
  edge("-|>"),
  node((2.1, 0), [permits, Circle, Rect, from the declaration]),
  edge("-|>"),
  node((4.4, 0), [each case, subtract what it covers]),
  edge("-|>"),
  node((6.8, 0), [anything left?, yes: compile error, no: exhaustive]),
)

The error is precise. Add a `Triangle` to the permits list and the
sample's two-case switch stops compiling with `the switch expression
does not cover all possible input values`, and the missing-patterns
note names it `Triangle _`, the unnamed pattern from java 22 already
living in the compiler's own diagnostics. Exhaustiveness has teeth
only over sealed types, an open hierarchy still needs a `default`,
because anyone can add a subtype anywhere.

#diagram([the tree the switch is checked against], length: 13pt, {
  cdraw.rect((8.0, 5.2), (15.6, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.8, 5.8), [sealed Shape], size: 6.5pt)
  cdraw.content((16.2, 5.8), [permits], size: 6pt)
  cdraw.line((9.6, 5.2), (6.6, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.0, 5.2), (17.0, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.6, 3.0), (9.2, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.9, 3.5), [record Circle], size: 6pt)
  cdraw.rect((14.4, 3.0), (21.0, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.7, 3.5), [record Rect], size: 6pt)
  cdraw.content((5.9, 2.2), [case Circle c], size: 6pt)
  cdraw.content((17.7, 2.2), [case Rect r], size: 6pt)
  cdraw.content((11.8, 0.9), [all leaves covered, no default needed, add Triangle and the compile goes red], size: 6pt)
})

== guards, null, dominance

A `when` clause guards a pattern with a boolean the compiler treats as
part of the label. A guarded case does not count toward exhaustiveness
by itself, it can fail, so it must pair with an unguarded case for the
same type:

#listing("java/samples/src/Ch09/SwitchPatterns.java", first: 29, last: 35, caption: [a guarded and an unguarded case for one type, deconstruction in a third])

Null handling changed shape in 21. A null selector used to throw
before any label ran, it still does when no `case null` exists, but
`case null` makes absence an ordinary label. The sample measures both
sides:

#listing("java/samples/src/Ch09/SwitchPatterns.java", first: 37, last: 43, caption: [case null first, unnamed patterns after])

Dominance rules keep the order honest: a label that covers everything
an earlier label covers is an error, `case Object o` before `case
Circle c` fails with `this case label is dominated by a preceding case
label`, measured. A guarded case may precede its unguarded twin, that
ordering is the idiom, and the sample relies on it:

#listing("java/samples/src/Ch09/SwitchPatterns.java", first: 77, last: 81, caption: [guarded first, unguarded fallback, measured order])

== unnamed variables and patterns

Java 22 (JEP 456, after a 21 preview) finished the underscore's
journey. `_` was a legal identifier in java 1, drew a warning in 8,
became an error in 9 (JEP 213), and now means unnamed: bind nothing,
match anything. In a type pattern it discards the binding while
keeping the type test, and as a variable it marks a value the reader
should not track:

#listing("java/samples/src/Ch09/SwitchPatterns.java", first: 62, last: 73, caption: [unnamed variables in for, catch, and assignment])

#snippet(
  "// java 22, one underscore, four uses\n"
  + "case Circle _ -> \"some circle\";   // unnamed pattern\n"
  + "for (var _ : list) count++;        // unnamed variable\n"
  + "try { read(); } catch (IOException _) { log(); }  // unnamed parameter\n"
  + "var _ = sideEffectOnly();          // discarded result\n",
  lang: "java",
)

The rule that makes it safe: an unnamed variable may never be read,
so it cannot be confused with a forgotten binding. Longer names keep
their underscores, `_count` and `MAX_AGE` are untouched, and `_` as a
digit separator in literals is a different token from 7 on.

== what is still preview

Primitive types in patterns, instanceof and switch, remain preview in
java 27, the fifth round (JEP 532), unchanged from the java 26
revision. The feature lets `int i` and `double d` patterns match
primitives with widening conversions, `case int i when i > 0`, and it
is the piece that eventually lets records hold primitives without
boxing in pattern position. This book's samples do not use it, the
runner compiles without `--enable-preview` by design.

#callout("note", "why the arc matters", [
  Records gave java cheap products, sealed types gave it closed sums,
  and pattern matching gave the two a consumer. The result reads like
  the ml family: one declaration for the data, one switch for every
  case, and a compiler that notices when the two drift apart. Chapter
  5 and chapter 6 built the halves, this chapter is the join.
])

sources: openjdk.org/jeps/305, /jeps/394, /jeps/409, /jeps/440, /jeps/441,
/jeps/456, /jeps/532, and /jeps/213, statuses, preview chains, and
release attributions checked 2026-10-04. The null-component rule read
against JEP 440 and verified by measurement. Every behavioral claim
is asserted by `java/samples/src/Ch09`, 19 checks green under
`pwsh -NoProfile -File tools/run-java-samples.ps1 -Chapter Ch09` on
the pinned build 27+35-2325, measured 2026-10-04.
