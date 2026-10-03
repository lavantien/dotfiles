#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= linq

LINQ is a query language over sequences. Anything implementing
`IEnumerable<T>` can be filtered, projected, ordered, grouped, and
joined with a uniform vocabulary, and because the operators are just
extension methods over `IEnumerable<T>`, the whole system is open:
LINQ to Objects runs in memory, the same syntax targets databases
through `IQueryable<T>`, where operators become expression trees, the
lambdas captured as data that the provider translates. LINQ is also
where this book's chapter 5
variance and chapter 7 delegates pay off, every operator takes a
`Func<...>` and `IEnumerable<out T>` is what lets one query method
serve every element type.

The demonstrations below all run over rows in a real SQLite database:
`OpenShop` seeds the `product`, `shopper`, and `line` tables with
integer-cent prices in an in-memory file, and typed readers turn each
`SELECT` into the `IEnumerable<T>` the operators consume, so the test
suite checks every LINQ answer against the equivalent plain SQL.

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 14, last: 41, caption: [the shop as schema and seed rows, one in-memory SQLite file])

== method syntax and query syntax

Two spellings, one compiler output. Method syntax chains extension
methods with lambda arguments. Query syntax is the `from ... where ...
select` form the compiler translates into exactly those calls:

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 89, last: 101, caption: [one plan written twice, producing equal results])

#diagram([two spellings, one compiler output], length: 13pt, {
  // query syntax and method syntax at top, the shared calls below
  cdraw.rect((0.2, 3.6), (9.4, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.8, 4.6), [query syntax: `from`, `where`, #linebreak() `orderby`, `select`], size: 6pt)
  cdraw.rect((10.4, 3.6), (19.6, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((15.0, 4.6), [method syntax: `Where()`, #linebreak() `OrderBy()`, `Select()` chained], size: 6pt)
  cdraw.line((4.8, 3.6), (8.0, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 3.6), (12.0, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.0, 0.8), (15.0, 2.8), fill: luma(205), radius: 0.02)
  cdraw.content((10.0, 1.8), [one compiler output, #linebreak() the same extension method chain], size: 6pt)
  cdraw.content((12.0, -0.7), [query syntax covers the common relational shape, #linebreak() method syntax covers every operator], size: 6.5pt)
})

Method syntax covers every operator, query syntax covers the common
relational shape and reads better once `join` and `group` appear. Use
either consistently within a file.

== deferred execution

A query expression builds a plan, it does not run. Nothing executes
until enumeration, and every enumeration runs the plan again against
the current data:

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 103, last: 111, caption: [two counts, one query, different answers])

The operators that return something other than `IEnumerable<T>`
(`ToList`, `ToArray`, `ToDictionary`, `ToHashSet`, `First`, `Count`,
`Any`, `Sum`) execute immediately and materialize. That is the lever:
keep the query deferred while composing, materialize once at the end,
and never hand a live query to code that expects a snapshot.

#flow(
  [deferred execution, enumeration pulls, nothing runs until asked],
  node((0, 0), [source]),
  node((2.0, 0), [Where, a plan]),
  node((4.0, 0), [Select, a plan]),
  node((6.2, 0), [foreach, pulls]),
  edge((0, 0), (2.0, 0), "-|>"),
  edge((2.0, 0), (4.0, 0), "-|>"),
  edge((6.2, 0), (4.0, 0), "-|>", bend: 25deg, label: [asks for one element]),
  edge((4.0, 0), (2.0, 0), "-|>", bend: 25deg, label: [asks upstream]),
)

== the operator families

Filtering and projection are `Where` and `Select`. Flattening is
`SelectMany`. Ordering is `OrderBy` and `ThenBy`, both stable. The
element operators are `First`, `FirstOrDefault`, `Single`,
`SingleOrDefault`, each with a reason to be chosen: `Single` throws on
duplicates by design, `First` takes the earliest match. Quantifiers
`Any`, `All`, `Contains` answer boolean questions and short circuit.
Set operators `Distinct`, `Union`, `Intersect`, `Except` use default
or supplied equality. Partitioning is `Take`, `Skip`, `TakeWhile`,
`SkipWhile`:

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 146, last: 147, caption: [SelectMany flattens, Distinct dedupes, Order sorts])

#diagram([the operator families, one job each], length: 13pt, {
  // the family on the left, its operators on the right
  let rows = (
    ([filter], [`Where`]),
    ([project], [`Select`]),
    ([flatten], [`SelectMany`]),
    ([order], [`OrderBy`, `ThenBy`, stable]),
    ([element], [`First`, `Single`, and or-default]),
    ([quantifier], [`Any`, `All`, `Contains`]),
    ([set], [`Distinct`, `Union`, `Intersect`, `Except`]),
    ([partition], [`Take`, `Skip`, `TakeWhile`, `SkipWhile`]),
  )
  for (i, row) in rows.enumerate() {
    let y = 6.6 - i * 1.05
    cdraw.rect((0.4, y - 0.5), (3.2, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((1.8, y), row.at(0), size: 6pt)
    cdraw.line((3.2, y), (4.2, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((10.6, y), row.at(1), size: 6pt)
  }
  cdraw.content((10.6, -2.0), [operators returning something other than `IEnumerable<T>` #linebreak() execute immediately: `ToList`, `First`, `Count`, `Any`, `Sum`], size: 6.5pt)
})

== grouping and aggregation

`GroupBy` clusters a sequence by a key and returns a sequence of
groups, each carrying its key and its members:

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 113, last: 115, caption: [GroupBy into a dictionary of counts])

In query syntax, `group ... by ... into` introduces the group as a
new range variable and the query continues per group:

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 117, last: 122, caption: [group by with an into continuation])

Aggregation folds a sequence to a value. `Sum`, `Min`, `Max`,
`Average`, `Count` are specialized folds, and the general one is
`Aggregate`, which takes a function from accumulator and element to
accumulator:

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 138, last: 144, caption: [a specialized fold and a general one])

#diagram([groupby clusters by key, aggregate folds to a value], length: 13pt, {
  // groups at left, the fold ladder at right
  cdraw.rect((0.0, 4.2), (4.2, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((2.1, 4.8), [the sequence], size: 6pt)
  cdraw.line((4.2, 5.1), (5.2, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.2, 4.5), (5.2, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.2, 4.4), (10.2, 6.0), fill: luma(230), radius: 0.02)
  cdraw.content((7.7, 5.2), [key: office, #linebreak() and its members], size: 6pt)
  cdraw.rect((5.2, 2.4), (10.2, 4.0), fill: luma(230), radius: 0.02)
  cdraw.content((7.7, 3.2), [key: desk, #linebreak() and its members], size: 6pt)
  cdraw.content((7.7, 1.6), [`GroupBy` returns #linebreak() a sequence of groups], size: 6.5pt)
  cdraw.content((13.3, 6.6), [`Aggregate`], size: 6.5pt)
  cdraw.rect((12.0, 5.1), (14.6, 6.1), fill: luma(235), radius: 0.02)
  cdraw.content((13.3, 5.6), [seed], size: 6pt)
  cdraw.line((13.3, 5.1), (13.3, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 3.6), (14.6, 4.6), fill: luma(230), radius: 0.02)
  cdraw.content((13.3, 4.1), [f(acc, x)], size: 6pt)
  cdraw.line((13.3, 3.6), (13.3, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 2.1), (14.6, 3.1), fill: luma(230), radius: 0.02)
  cdraw.content((13.3, 2.6), [f(acc, x)], size: 6pt)
  cdraw.line((13.3, 2.1), (13.3, 1.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 0.6), (14.6, 1.6), fill: luma(205), radius: 0.02)
  cdraw.content((13.3, 1.1), [the value], size: 6pt)
  cdraw.content((19.4, 2.4), [`Sum`, `Min`, `Max`, #linebreak() `Average`, `Count`: #linebreak() specialized folds], size: 6.5pt)
})

== join and let

`join ... on ... equals ...` is an equi-join by key, inner by
default, `join ... into` for grouping joins. Note the shape of the
`on` clause, it names both sides around the `equals` keyword rather
than a boolean expression:

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 131, last: 136, caption: [an equi-join across shoppers and catalog])

#diagram([join pairs sources by key, let binds a name mid query], length: 13pt, {
  // the join at top, the let binding below
  cdraw.rect((0.2, 5.0), (4.4, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((2.3, 5.6), [`Shoppers`], size: 6pt)
  cdraw.rect((0.2, 3.4), (4.4, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.3, 4.0), [`Products`], size: 6pt)
  cdraw.line((4.4, 5.7), (5.4, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.4, 3.9), (5.4, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, 6.75), [key `equals` key], size: 6pt)
  cdraw.rect((5.4, 3.8), (10.4, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((7.9, 4.7), [the equi-join, #linebreak() inner by default], size: 6pt)
  cdraw.line((10.4, 4.7), (11.2, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.4, 3.8), (15.6, 5.6), fill: luma(230), radius: 0.02)
  cdraw.content((13.5, 4.7), [paired rows], size: 6pt)
  cdraw.content((18.6, 4.7), [`into` keeps every #linebreak() right-side row], size: 6.5pt)
  cdraw.rect((0.2, 1.0), (5.6, 2.8), fill: luma(235), radius: 0.02)
  cdraw.content((2.9, 1.9), [`p.Price * 1.1m`, #linebreak() an expression], size: 6pt)
  cdraw.line((5.6, 1.9), (6.6, 1.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.8, 1.0), (10.8, 2.8), fill: luma(205), radius: 0.02)
  cdraw.content((8.8, 1.9), [`let taxed`, #linebreak() a query local], size: 6pt)
  cdraw.line((10.8, 1.9), (12.0, 1.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.2, 1.0), (16.8, 2.8), fill: luma(230), radius: 0.02)
  cdraw.content((14.5, 1.9), [usable for the #linebreak() rest of the query], size: 6pt)
  cdraw.content((10.0, 0.0), [`let` is the query syntax answer to a local variable], size: 6.5pt)
})

`let` binds a name to an intermediate value usable for the rest of
the query, the query syntax answer to a local variable:

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 124, last: 129, caption: [let computing a taxed price mid query])

== outer joins

`join` is inner-only: a row without a counterpart on the other side
disappears. .NET 11 completes the relational vocabulary with three
operators, `LeftJoin` keeps every left row, `RightJoin` keeps every
right row, `FullJoin` keeps both, and each returns
`(outer, inner)` tuples with `default` on whichever side found no
match. The seed tables match on both sides, so the demo extends the
live SELECTs with the two rows that make a gap visible, a shopper in
a category with no products and a product in a category with no
shoppers:

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 155, last: 171, caption: [LeftJoin keeps chi, default fills the missing right])

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 173, last: 179, caption: [RightJoin is the mirror, rose survives without a shopper])

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 181, last: 188, caption: [FullJoin keeps both sides of the gap])

#diagram([which rows survive each join], length: 13pt, {
  // three panels: left, right, full, each showing retained rows
  let panels = (
    ([`LeftJoin`], [every left row, #linebreak() default right], luma(235)),
    ([`RightJoin`], [every right row, #linebreak() default left], luma(230)),
    ([`FullJoin`], [both sides kept, #linebreak() default on either], luma(205)),
  )
  for (i, (title, body, fill)) in panels.enumerate() {
    let x0 = 0.2 + i * 8.2
    cdraw.rect((x0, 3.4), (x0 + 7.6, 5.6), fill: fill, radius: 0.02)
    cdraw.content((x0 + 3.8, 4.9), title, size: 6pt)
    cdraw.content((x0 + 3.8, 4.0), body, size: 6pt)
  }
  cdraw.content((12.3, 6.6), [the unmatched side yields `default`: null for reference types, zero for value types], size: 6.5pt)
  cdraw.content((12.3, 1.6), [`Join` and `GroupJoin` grew tuple-returning overloads #linebreak() and optional comparer overloads across the family], size: 6.5pt)
})

The tuple shape feeds deconstruction and patterns directly, which is
the ergonomic win over the old `join ... into` plus `Any()` dance for
left joins. The family also grew: `Join` and `GroupJoin` have
tuple-returning overloads that drop the result selector, every join
operator takes an optional `IEqualityComparer<TKey>`, and the same
operators exist on `Queryable` and `AsyncEnumerable`. EF Core 11
translates `FullJoin` to SQL `FULL JOIN`, so the vocabulary crosses
the `IQueryable` boundary.

#callout("pitfall", "default is not the same as no row", [
  A missing right side surfaces as `default(TInner)`, which is `null`
  for the record types above but a real zero for a value-typed
  element. Test the gap with a pattern, `pair.Item2 is Product p`,
  which is false for both null and a zeroed struct, and only reach
  for `?.` once the pattern says a value is there. A `NullReferenceException`
  inside a left join projection is almost always a missing-match case
  handled as if it were present.
])

== what the chapter 2 keyword matrix promised

The two ordering directions close the set. `ascending` is the default
and is usually left implicit, `descending` flips a key, and one
`orderby` can mix both:

#listing("csharp-net/samples/src/Ch14/Queries.cs", first: 149, last: 153, caption: [explicit directions, category ascending then price descending])

Query syntax is where the contextual keywords from the lexical
chapter all land: `from`, `where`, `select`, `group`, `into`, `join`,
`on`, `equals`, `by`, `orderby`, `ascending`, `descending`, and
`let`. Every one of them is demonstrated in the listings above, none
is reserved, and all of them are method calls after compilation.

#diagram([every query keyword lands as a method call], length: 13pt, {
  // the keyword on the left, the call it becomes on the right
  let rows = (
    ([`from`], [the source, plus `Select`]),
    ([`where`], [`Where`]),
    ([`orderby`], [`OrderBy`, `ThenBy`]),
    ([`select`], [`Select`]),
    ([`group`], [`GroupBy`]),
    ([`join`], [`Join`]),
    ([`let`], [a transparent identifier]),
  )
  for (i, row) in rows.enumerate() {
    let y = 6.2 - i * 1.05
    cdraw.rect((0.4, y - 0.5), (2.8, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((1.6, y), row.at(0), size: 6pt)
    cdraw.line((2.8, y), (3.8, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((9.0, y), row.at(1), size: 6pt)
  }
  cdraw.content((9.0, -1.6), [thirteen contextual keywords, zero reserved words], size: 6.5pt)
})

#callout("pitfall", "captured variables and multiple enumeration", [
  Deferred execution composes with the closure rules of chapter 7: a
  lambda in a query captures the variable, not the value. Changing a
  captured variable between building and enumerating a query changes
  the result. And enumerating a deferred query twice does the work
  twice, which is fine for a list and wrong for a database round
  trip, where `ToList` first is the rule.
])

sources: learn.microsoft.com, linq overview, query syntax and method
syntax, standard query operators overview, deferred execution and
lazy evaluation in linq pages accessed 2026-09-08, what's new in .NET
11 libraries, enumerable.leftjoin, rightjoin, and fulljoin pages
accessed 2026-09-13. Sample behavior verified by `make verify-csharp`,
14 tests.
