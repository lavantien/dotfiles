#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= idioms

Everything so far was mechanics. This chapter is the set of habits
that separates fluent C\# from correct C\#: deterministic cleanup, the
equality contract, string comparison discipline, nullable discipline,
and the testing posture this book's own suite demonstrates.

== disposal

`IDisposable` says "I hold something the garbage collector cannot be
trusted to reclaim promptly", a file handle, a socket, a native
buffer. The `using` statement scopes the lifetime and calls
`Dispose` at the closing brace, on every exit path, including an
exception in flight:

#listing("csharp-net/samples/src/Ch17/Craft.cs", first: 5, last: 11, caption: [the smallest honest disposable])

#listing("csharp-net/samples/src/Ch17/Craft.cs", first: 39, last: 47, caption: [alive inside, disposed after])

#listing("csharp-net/samples/src/Ch17/Craft.cs", first: 49, last: 64, caption: [the exception unwinds through the using, dispose still runs])

#diagram([using is a state machine over exit paths, dispose always runs], length: 13pt, {
  // the three exits at left, the one guaranteed call at right
  let exits = ([normal completion], [a `return`], [an exception unwinds])
  for (i, t) in exits.enumerate() {
    let y = 5.3 - i * 1.7
    cdraw.rect((0.2, y - 0.6), (4.4, y + 0.6), fill: luma(235), radius: 0.02)
    cdraw.content((2.3, y), t, size: 6pt)
    cdraw.line((4.4, y), (6.6, 3.6), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.rect((6.8, 2.6), (11.8, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((9.3, 3.6), [`Dispose` runs #linebreak() on every path], size: 6pt)
  cdraw.content((17.6, 4.4), [the compiler writes #linebreak() the try/finally], size: 6.5pt)
  cdraw.content((17.6, 2.0), [`await using` carries #linebreak() it into `DisposeAsync`], size: 6.5pt)
})

When teardown itself awaits, implement `IAsyncDisposable` and consume
with `await using`, the chapter 9 rules apply to `DisposeAsync` like
any await:

#listing("csharp-net/samples/src/Ch17/Craft.cs", first: 13, last: 23, caption: [an async disposable whose cleanup awaits])

#listing("csharp-net/samples/src/Ch17/Craft.cs", first: 66, last: 73, caption: [await using closes the async scope])

The `using` declaration form (`using var x = ...`) disposes at the end
of the enclosing block and is the shape to prefer when the scope is
the whole method.

== the equality contract

If two instances of your type can be meaningfully equal, the contract
is three parts: implement `IEquatable<T>` so collections compare
typed, override `object.Equals` to delegate to it, and override
`GetHashCode` consistently, equal values must produce equal hashes,
or dictionaries lose them. Classes do none of this automatically.
Records do all of it, plus the `==` operator:

#listing("csharp-net/samples/src/Ch17/Craft.cs", first: 25, last: 35, caption: [the manual contract, three members])

#diagram([three members, one equality contract], length: 13pt, {
  // the three members at left, the hash buckets they keep honest at right
  let members = (
    ([`IEquatable<T>`, #linebreak() the typed compare]),
    ([`Equals` delegates #linebreak() to it]),
    ([`GetHashCode` routes #linebreak() to the bucket]),
  )
  for (i, t) in members.enumerate() {
    let y = 5.6 - i * 2.4
    cdraw.rect((0.2, y - 0.9), (6.8, y + 0.9), fill: luma(235), radius: 0.02)
    cdraw.content((3.5, y), t, size: 6pt)
    if i < 2 { cdraw.line((3.5, y - 0.9), (3.5, y - 1.5), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((9.0, 5.8), [bucket 17], size: 6pt)
  cdraw.rect((8.2, 4.2), (11.0, 5.2), fill: luma(230), radius: 0.02)
  cdraw.content((9.6, 4.7), [`Tag("a")`], size: 6pt)
  cdraw.rect((11.4, 4.2), (14.2, 5.2), fill: luma(230), radius: 0.02)
  cdraw.content((12.8, 4.7), [`Tag("a")`], size: 6pt)
  cdraw.content((9.0, 3.4), [bucket 9], size: 6pt)
  cdraw.rect((8.2, 1.8), (11.0, 2.8), fill: luma(230), radius: 0.02)
  cdraw.content((9.6, 2.3), [`Tag("b")`], size: 6pt)
  cdraw.content((19.6, 4.6), [equal keys, one #linebreak() bucket, or lookups miss], size: 6.5pt)
  cdraw.content((17.6, 2.4), [records synthesize #linebreak() the whole set], size: 6.5pt)
})

#listing("csharp-net/samples/src/Ch17/Craft.cs", first: 75, last: 83, caption: [manual equality beside record equality])

#callout("warning", "equal objects, equal hashes, always", [
  Overriding `Equals` without `GetHashCode` compiles and corrupts
  hash based collections quietly: two equal keys can land in
  different buckets and lookups miss. The pair is one contract.
  Prefer records for any type whose equality is value shaped, they
  synthesize the whole set including the runtime type check from
  chapter 3.
])

== string comparison discipline

`==` on strings is ordinal, culture blind. That is right for program
logic and wrong to assume about comparisons you did not write.
Explicit comparisons should say what they mean: ordinal for machine
keys, ordinal ignore case for user facing keys, culture aware only
when producing text for humans to read:

#listing("csharp-net/samples/src/Ch17/Craft.cs", first: 85, last: 87, caption: [explicit rules, no defaults inherited])

#diagram([the comparer grid, which rule for which job], length: 13pt, {
  // the rule on the left, the job it owns on the right
  let rows = (
    ([ordinal], [machine keys, exact code units]),
    ([ordinal ignore-case], [user-facing keys]),
    ([culture aware], [display text only]),
  )
  for (i, row) in rows.enumerate() {
    let y = 4.6 - i * 1.15
    cdraw.rect((0.4, y - 0.5), (6.4, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((3.4, y), row.at(0), size: 6pt)
    cdraw.line((6.4, y), (7.4, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((14.0, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((11.4, 0.0), [`hellö` differs from `hello` by code unit, #linebreak() `==` is ordinal and culture blind], size: 6.5pt)
})

The test asserts both directions: case-insensitive matches across
casing, and ordinal treats `hellö` as different from `hello` because
the code units differ.

== nullable discipline

Chapter 3 built the model. The working rules: annotations tell the
truth, `string?` only where null is a real answer. Null checks narrow
the flow state, so check at the boundary and let the compiler carry
the knowledge inward. `!` is a debt, each occurrence is a claim the
compiler could not verify, and a candidate for a test. `??` and
`?.` remove most of the branches the checks would otherwise create.

#diagram([nullable discipline, check once at the boundary], length: 13pt, {
  // boundary, check, carried knowledge, the debt branch below
  cdraw.rect((0.2, 3.2), (6.2, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.2, 4.0), [the boundary, #linebreak() a `string?` arrives], size: 6pt)
  cdraw.line((6.2, 4.0), (7.2, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.2, 3.2), (13.2, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((10.2, 4.0), [check once, #linebreak() the state narrows], size: 6pt)
  cdraw.line((13.2, 4.0), (14.2, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.2, 3.2), (20.2, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((17.2, 4.0), [carried inward #linebreak() by the compiler], size: 6pt)
  cdraw.line((10.2, 3.2), (10.2, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.2, 0.6), (13.2, 2.4), fill: luma(230), radius: 0.02)
  cdraw.content((10.2, 1.5), [`!` is a debt, each #linebreak() one deserves a test], size: 6pt)
  cdraw.content((10.0, -0.6), [annotations tell the truth: `string?` only #linebreak() where null is a real answer], size: 6.5pt)
  cdraw.content((10.0, -2.1), [`??` and `?.` remove the branches], size: 6.5pt)
})

== the testing posture

This book's sample suite is the reference implementation of the
habit. Facts for one behavior, theories with `InlineData` when the
behavior is parameter shaped, and assertions that name the behavior
in the test method's own name, so a failure reads as a sentence.
The red-green rhythm from chapter 13's generator applies everywhere:
write the failing test, run it, watch it fail for the predicted
reason, then make it pass and refactor.

The suite's own conventions are worth copying: static pure sample
functions returning tuples, so tests read as input to output pairs,
deterministic seeds over wall clock, `Assert.Throws` family over
try-catch rethrow in tests, and one behavioral assertion per test so
a failure points at one fact.

#diagram([red green refactor, the loop the suite runs], length: 13pt, {
  // four stages in a row, the loop-back arrow underneath
  let stages = (
    ((0.2, 5.4), [write the #linebreak() failing test]),
    ((6.4, 11.6), [watch it fail for #linebreak() the predicted reason]),
    ((12.6, 17.8), [make it pass]),
    ((18.8, 23.8), [refactor]),
  )
  for ((x0, x1), t) in stages {
    cdraw.rect((x0, 3.4), (x1, 5.2), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 4.3), t, size: 6pt)
  }
  for x in (5.4, 11.6, 17.8) {
    cdraw.line((x, 4.3), (x + 1.0, 4.3), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.line((21.3, 3.4), (21.3, 2.0), stroke: luma(100))
  cdraw.line((21.3, 2.0), (2.8, 2.0), stroke: luma(100))
  cdraw.line((2.8, 2.0), (2.8, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.0, 1.5), [the next behavior], size: 6.5pt)
  cdraw.content((12.0, -0.2), [one behavioral assertion per test, #linebreak() a failure reads as a sentence], size: 6.5pt)
})

sources: learn.microsoft.com, implementing dispose, iasyncdisposable,
equals and gethashcode, string comparison best practices, and xunit
documentation at xunit.net, accessed 2026-09-08. Sample behavior
verified by `make verify-csharp`, 6 tests.
