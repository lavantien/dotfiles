#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= functional programming

The pieces are already on the table. Chapter 3 built records and, with
C\# 15, unions and closed hierarchies. Chapter 4 added extension
members. Chapter 6 made switches exhaustive over a closed domain.
Chapter 14 built LINQ. This chapter assembles them into one working
style: model the world as data, transform it with functions, and let
the compiler prove the transforms total. Everything runs on one sample,
a document processor small enough to read in a sitting and complete
enough to exercise all five pieces.

== the five pieces

Functional C\# is five features that compose. Records carry plain data
with value equality, chapter 3's records section. A union closes a
domain in one line, chapter 3's union types section, or `closed` fixes
an existing hierarchy, its closed hierarchies section. Pattern matching
branches on the shape of a value rather than on flags, chapter 6's
switching over unions without a fallback. Collection expressions build
and spread the sequences those branches produce. LINQ chains the
transformations, chapter 14. The document model is all five at once:

#listing("csharp-net/samples/src/Ch18/Functional.cs", first: 7, last: 14, caption: [four case records and the one line domain])

#diagram([five pieces, one job each, composed into one style], length: 13pt, {
  // the piece on the left, what it contributes on the right
  let rows = (
    ([records], [data with value equality and `with`]),
    ([union], [the domain, closed in one line]),
    ([patterns], [branching on shape, exhaustive]),
    ([collection expressions], [building and spreading sequences]),
    ([linq], [the transformation vocabulary]),
  )
  for (i, row) in rows.enumerate() {
    let y = 6.4 - i * 1.2
    cdraw.rect((0.2, y - 0.5), (5.8, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((3.0, y), row.at(0), size: 6pt)
    cdraw.line((5.8, y), (7.0, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((13.0, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((13.0, -0.4), [the whole model is one 140 line sample], size: 6.5pt)
})

The four case records hold data and nothing else, no methods, no
visitor interfaces, no behavior. A heading is a level and a text, an
item list is an array of entries, and the quote case is the one that
nests: its `Nested` field is more document, which is what makes the
model a tree rather than a list. The union declaration is the entire
contract. Every function that follows is written against those four
cases, and the compiler holds each one to all of them.

The `is` operator is union aware, chapter 3 measured that, and so is
every switch arm below. The boxing rule from that chapter applies
unchanged: keep values statically typed as `Doc` across boundaries,
because a union boxed to `object` hides its case from a type test.

== data over behavior

The object oriented reflex is to put behavior inside the model, one
class per case with a virtual method. The functional shape inverts it:
the model stays dumb, transforms are functions from document to
document, and behavior that needs to look at every block becomes a
fold. The sample document is built with collection expressions, the
`[a, b]` literal and `..` spread that build sequences inline (C\# 12),
and the spread in the flatten below is the same syntax at work:

#listing("csharp-net/samples/src/Ch18/Functional.cs", first: 18, last: 31, caption: [a document built with collection expressions, one quote nested])

A tree to tree transform walks the structure and returns a new one.
Demoting every heading copies each heading with a `with` expression,
the nondestructive mutation from chapter 3's records section, and
recurses into the quote's children. The original document is
untouched, which the tests assert rather than trust:

#listing("csharp-net/samples/src/Ch18/Functional.cs", first: 96, last: 106, caption: [with copies the heading, the recursion rebuilds the quote])

#diagram([data over behavior, transforms walk a model that stays dumb], length: 13pt, {
  // build, the dumb model, the demote copy, the render fold, left to right
  cdraw.rect((0.0, 3.1), (5.2, 4.9), fill: luma(235), radius: 0.02)
  cdraw.content((2.6, 4.0), [collection expressions #linebreak() build the tree], size: 6pt)
  cdraw.line((5.2, 4.0), (6.0, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.0, 3.1), (11.2, 4.9), fill: luma(205), radius: 0.02)
  cdraw.content((8.6, 4.0), [the model, dumb #linebreak() data, no methods], size: 6pt)
  cdraw.line((11.2, 4.0), (12.0, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 3.1), (17.2, 4.9), fill: luma(235), radius: 0.02)
  cdraw.content((14.6, 4.0), [demote via `with` #linebreak() copies each heading], size: 6pt)
  cdraw.line((17.2, 4.0), (18.0, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.0, 3.1), (23.2, 4.9), fill: luma(235), radius: 0.02)
  cdraw.content((20.6, 4.0), [render: one fold #linebreak() with a stringbuilder], size: 6pt)
  cdraw.content((11.6, 2.1), [every behavior is a function from document to document, #linebreak() the model never learns a method], size: 6.5pt)
})

Behavior is a fold over the flattened model. Rendering to text is one
`Aggregate`, the general fold chapter 14's grouping and aggregation
section introduced, carrying a `StringBuilder` as its accumulator and a
switch as its step function:

#listing("csharp-net/samples/src/Ch18/Functional.cs", first: 108, last: 119, caption: [rendering as one fold, a switch per block kind])

#callout("note", "data over behavior is a default, not a law", [
  The dumb model earns its keep when many behaviors read the same
  structure, outlines, word counts, renderers, all in this sample. When
  exactly one behavior owns the type, or when a hot path needs to
  mutate in place, a class with methods is still the honest tool, the
  same trade chapter 3's choosing a kind of type ladder walked.
])

== exhaustiveness as a type-level test

Every switch in the sample names all four cases and carries no default
arm. That discipline turns the compiler into a test suite for the
domain. Declare a fifth case, say `Table`, and every transform in the
file stops compiling until it says what a table means: CS8509, the
warning chapter 6's switching over unions without a fallback section
quoted verbatim, fires at each switch that misses it. A rename or a
removed case fails the same way. The chapter 6 callout stands for this
chapter too, promote CS8509 to an error so the proof cannot ride a
green build:

#listing("csharp-net/samples/src/Ch18/Functional.cs", first: 33, last: 43, caption: [the recursive walk, four arms, no fallback])

The empty arms are the point. `HeadingsIn` returns nothing for 3 of
the 4 cases, and those arms exist precisely so the compiler can count
them. Writing `_ => []` instead would compile today and silently
swallow the fifth case tomorrow, the failure mode chapter 6 diagrammed:

#listing("csharp-net/samples/src/Ch18/Functional.cs", first: 45, last: 52, caption: [three empty arms, each one named for the compiler])

#diagram([a new case turns every transform red until handled], length: 13pt, {
  // the domain on the left, transforms on the right, a fifth case lights them up
  cdraw.rect((0.0, 1.0), (8.4, 6.8), fill: luma(205), radius: 0.02)
  cdraw.content((4.2, 5.8), [`union Doc(Heading,` #linebreak() `Paragraph, Items, Quote)`], size: 6pt)
  cdraw.content((4.2, 3.4), [add a fifth case, #linebreak() the domain grew], size: 6pt)
  cdraw.line((8.4, 4.4), (8.8, 4.4), stroke: luma(100), mark: (end: ">"))
  let rows = ([flatten], [outline], [numbered items], [word counts], [renderer])
  for (i, t) in rows.enumerate() {
    let y = 6.2 - i * 1.15
    cdraw.rect((9.0, y - 0.45), (14.6, y + 0.45), fill: luma(235), radius: 0.02)
    cdraw.content((11.8, y), t, size: 6pt)
    cdraw.line((14.6, y), (16.2, y), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((12.4, 0.0), [every arrow ends at the same error, CS8509, `Table` not covered], size: 6.5pt)
})

This is the difference from the pre C\# 15 idiom. A record hierarchy
with a discard arm trusted the writer to update every switch, and the
compiler had nothing to say when they forgot. With the domain in the
union declaration, an unhandled case is a compile time fact, not a
runtime `SwitchExpressionException` waiting for the one input that
carries it. Chapter 6 measured both halves of that failure, the
warning text and the throw.

== pipelines

LINQ is the backbone, and chapter 4's extension members section is the
reason it reads left to right: every operator is a static extension
method over `IEnumerable<T>`, resolved at compile time, which is also
why the vocabulary is open to the same plumbing. The pattern in this
sample is flatten once, then query. `Flatten` walks the tree into a
block sequence, and every query below composes over it:

#listing("csharp-net/samples/src/Ch18/Functional.cs", first: 54, last: 57, caption: [outline, flatten then project the headings])

#listing("csharp-net/samples/src/Ch18/Functional.cs", first: 59, last: 72, caption: [renumber, the indexed select threads one counter through both lists])

Word counts are chapter 14's grouping and aggregation shape exactly:
`SelectMany` to words, `GroupBy` to cluster, `OrderByDescending` and
`ThenBy` to rank, with the ordinal rule from chapter 17's string
comparison discipline keeping the ties deterministic:

#listing("csharp-net/samples/src/Ch18/Functional.cs", first: 74, last: 94, caption: [words to groups to ranked counts])

The join earns its place at the roster: which authors never got
quoted. That is the outer joins section of chapter 14 verbatim,
`LeftJoin` keeps every roster name and fills the missing right side
with `default`, so `null` is the answer, and the pattern filters the
gap. The pitfall from that chapter is why the filter is a pattern
rather than a null check on a property:

#listing("csharp-net/samples/src/Ch18/Functional.cs", first: 121, last: 139, caption: [left join over attributions, unmatched names are the result])

#diagram([the sample as pipelines, flatten once then query], length: 13pt, {
  // the tree at left, the flatten, then the three queries stacked
  cdraw.rect((0.2, 3.4), (4.4, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((2.3, 4.8), [the document, #linebreak() headings, paragraphs, #linebreak() lists, quotes], size: 6pt)
  cdraw.line((4.4, 4.8), (5.6, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.8, 3.5), (10.0, 6.1), fill: luma(205), radius: 0.02)
  cdraw.content((7.9, 4.8), [`Flatten`, #linebreak() one block sequence], size: 6pt)
  let queries = ([outline], [numbered items], [word counts], [roster join])
  for (i, t) in queries.enumerate() {
    let y = 6.2 - i * 1.6
    cdraw.line((10.0, 4.8), (11.4, y), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((11.6, y - 0.5), (16.6, y + 0.5), fill: luma(230), radius: 0.02)
    cdraw.content((14.1, y), t, size: 6pt)
  }
  cdraw.content((14.1, -0.6), [each query is where, select, group by, join, #linebreak() the operators from chapter 14], size: 6.5pt)
})

Deferred execution from chapter 14 applies to these pipelines the same
as any other: the queries are plans until enumerated, and `[.. ]`
materializes at the end. `Flatten` itself materializes once inside
each query, which is the honest shape for a tree walk that a query
cannot express.

== what c\# borrows from f\#

None of the five pieces is a C\# invention. Records, `with`, and
pattern matching came through the functional lineage into C\# 7
through 10. Collection expressions and the pipeline reading of LINQ
echo list literals and the `|>` operator. The `union` keyword in
C\# 15 is the newest loan, and it is the largest: a discriminated
union is the native data type of F\#, where the exhaustiveness this
chapter treats as a test suite has been the default posture of every
`match` since the language began.

#diagram([each c\# piece, its f\# ancestry], length: 13pt, {
  // the c# feature on the left, the f# original on the right
  let rows = (
    ([`record` + `with`], [record types, immutable by default]),
    ([`union`], [discriminated unions, `type Doc = ...`]),
    ([switch expression], [`match`, exhaustive or it does not compile]),
    ([collection expressions], [list literals and spreading]),
    ([linq chains], [`Seq` module, `|>` pipelines]),
  )
  for (i, row) in rows.enumerate() {
    let y = 6.4 - i * 1.2
    cdraw.rect((0.2, y - 0.5), (6.6, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((3.4, y), row.at(0), size: 6pt)
    cdraw.line((6.6, y), (7.8, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((13.6, y), row.at(1), size: 6.5pt)
  }
})

C\# keeps its own posture. The union is a struct wrapper rather than a
heap allocated tree, equality and conversions are synthesized to feel
like the rest of the type system, and LINQ remains method calls all
the way down. The f\# part of this corpus takes the same idea further:
the document model in this chapter reappears there as a discriminated
union with a `match` per transform, written in the language where the
pattern is native and the borrowings were never borrowed. Read it
after this chapter, the five pieces will all be familiar, only the
syntax moved.

sources: learn.microsoft.com, union types, custom union types, closed
hierarchy patterns, switch expressions, and standard query operators
pages accessed 2026-09-13. Sample behavior verified by
`make verify-csharp`, 8 tests.
