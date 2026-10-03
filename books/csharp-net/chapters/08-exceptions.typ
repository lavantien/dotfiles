#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= exceptions

Exceptions are the language's mechanism for failures a method cannot
handle locally: bad arguments, broken invariants, io errors, cancelled
operations. The design rule that keeps them useful is narrow: throw
when a caller further up can make a better decision, catch only what
you can actually handle, and never let an expected outcome become an
exception.

== throwing

`throw` takes any expression convertible to `System.Exception`. The
standard library covers most needs, argument problems throw
`ArgumentException` and its subclasses, state problems throw
`InvalidOperationException`, and .NET 6 added one line guards for the
common argument checks:

#listing("csharp-net/samples/src/Ch08/Errors.cs", first: 105, last: 111, caption: [ThrowIfNull and ThrowIfNullOrEmpty replace four line guard clauses])

#diagram([the guard clause, four lines to one], length: 13pt, {
  // the hand rolled guard against the library one liner
  cdraw.content((6.2, 6.9), [hand rolled guard], size: 7pt)
  cdraw.rect((0.2, 1.4), (12.2, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.2, 3.9), [`if (rate is null)` #linebreak() `{` #linebreak() `  throw new ArgumentNullException(` #linebreak() `      nameof(rate));` #linebreak() `}`], size: 6pt)
  cdraw.line((12.2, 3.9), (13.6, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.6, 6.9), [.net 6 one liner], size: 7pt)
  cdraw.rect((13.6, 2.9), (23.6, 4.9), fill: luma(205), radius: 0.02)
  cdraw.content((18.6, 3.9), [`ThrowIfNull(rate)` #linebreak() `ThrowIfNullOrEmpty(s)`], size: 6pt)
  cdraw.content((11.9, 0.0), [a custom exception names the domain failure #linebreak() and carries its payload to the handler], size: 6.5pt)
})

When a failure is specific to your domain, name it. A custom exception
is a small class carrying the data the handler needs:

#listing("csharp-net/samples/src/Ch08/Errors.cs", first: 7, last: 12, caption: [a custom exception carrying its payload])

#listing("csharp-net/samples/src/Ch08/Errors.cs", first: 113, last: 114, caption: [throwing it])

`throw` is also an expression, valid on the right side of `?:`, `??`,
and in lambda bodies, which is how the guard clauses above are
implemented.

== try, catch, finally

`try` wraps the code that might fail. Catch clauses are examined top
to bottom and at most one runs, most derived type first. `finally`
runs on every exit path, normal completion, a `return` or `break` out
of the block, or an exception propagating. A `try` block must have at
least one catch or a finally:

#listing("csharp-net/samples/src/Ch08/Errors.cs", first: 90, last: 103, caption: [finally runs before the exception escapes])

#diagram([try catch finally, the scan and the guaranteed bar], length: 13pt, {
  // clauses scan top down, every exit path lands on finally
  cdraw.rect((0.4, 4.4), (3.0, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((1.7, 4.9), [`try`], size: 6pt)
  cdraw.line((3.0, 5.2), (5.0, 5.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.0, 5.4), (13.0, 6.4), fill: luma(230), radius: 0.02)
  cdraw.content((9.0, 5.9), [`catch (SpecificException)`], size: 6pt)
  cdraw.line((9.0, 5.4), (9.0, 4.8), stroke: (paint: luma(150), dash: (1.5pt, 1.5pt)), mark: (end: ">"))
  cdraw.rect((5.0, 3.8), (13.0, 4.8), fill: luma(230), radius: 0.02)
  cdraw.content((9.0, 4.3), [`catch (Exception)`], size: 6pt)
  cdraw.content((18.8, 5.6), [scanned top to bottom, #linebreak() most derived match runs, #linebreak() no match falls through], size: 6.5pt)
  cdraw.line((1.7, 4.4), (1.7, 2.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.0, 3.8), (9.0, 2.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.4, 3.2), [normal exit], size: 6pt)
  cdraw.content((10.6, 3.2), [handled], size: 6pt)
  cdraw.rect((0.4, 1.0), (23.6, 2.0), fill: luma(205), radius: 0.02)
  cdraw.content((12.0, 1.5), [`finally`, cleanup on every exit path], size: 6pt)
  cdraw.content((11.9, 0.1), [runs on normal completion, on a `return` or `break` out of the block, #linebreak() and while an exception is still propagating], size: 6.5pt)
})

The test suite checks both paths: the happy path appends `after` after
`finally`, the throwing path never reaches `after` but the `finally`
entries land before the exception surfaces to the caller. `finally` is
for cleanup, with the `using` statement covered in chapter 17 as the
usual better tool. Only process termination skips it.

== exception filters

A `when` clause between the catch type and the block adds an arbitrary
boolean condition. The filter runs *before the stack unwinds*, so
locals at the throw site are still alive in the debugger, and a filter
that returns false leaves the exception propagating untouched, same
type, same stack, as if the clause did not exist:

#listing("csharp-net/samples/src/Ch08/Errors.cs", first: 16, last: 38, caption: [two filters on one exception type, plus the thrower])

#diagram([the when filter, evaluated before the stack unwinds], length: 13pt, {
  // throw, filter, unwind: the filter runs in the middle, stack intact
  cdraw.line((0.6, 4.6), (15.4, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.4, 4.3), (4.4, 4.9), stroke: luma(100))
  cdraw.line((10.4, 4.3), (10.4, 4.9), stroke: luma(100))
  cdraw.content((2.2, 5.5), [exception #linebreak() thrown], size: 6pt)
  cdraw.content((7.2, 5.5), [`when` filter runs, #linebreak() stack still intact], size: 6pt)
  cdraw.content((13.2, 5.5), [a match #linebreak() unwinds], size: 6pt)
  cdraw.line((5.4, 4.3), (5.4, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((3.6, 2.2), (7.2, 3.2), fill: luma(230), radius: 0.02)
  cdraw.content((5.4, 2.7), [filter false], size: 6pt)
  cdraw.line((11.4, 4.3), (11.4, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((9.6, 2.2), (13.2, 3.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.4, 2.7), [filter true], size: 6pt)
  cdraw.content((8.0, 1.0), [false leaves the search untouched, locals alive in the debugger, #linebreak() several `when` clauses on one type become legal], size: 6.5pt)
})

Filters make several catch clauses for one type legal, and they are
the honest way to write "catch this except when it is cancellation",
which appears in almost every async pipeline:

#snippet(
  "catch (Exception e) when (e is not OperationCanceledException)\n"
  + "{\n"
  + "    Log(e);\n"
  + "    throw; // cancellation is not an error, let it fly\n"
  + "}\n",
  lang: "cs",
)

== rethrowing, the difference one word makes

Inside a catch block, `throw;` rethrows the caught exception with its
original stack trace. `throw e;` rethrows the same instance but resets
the stack trace to the current frame, erasing the origin. The suite
asserts the difference on both forms, with `NoInlining` so the frame
survives optimized builds:

#listing("csharp-net/samples/src/Ch08/Errors.cs", first: 40, last: 63, caption: [bare throw keeps the origin in the stack trace])

#listing("csharp-net/samples/src/Ch08/Errors.cs", first: 65, last: 88, caption: [throw e keeps the instance but loses the origin])

#diagram([rethrowing, one word decides whether the origin survives], length: 13pt, {
  // two stack strips, one keeps its older frames, one does not
  cdraw.content((6.4, 6.9), [bare `throw;`], size: 7pt)
  cdraw.rect((0.4, 5.2), (3.2, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((1.8, 5.7), [`throw;`], size: 6pt)
  cdraw.line((3.2, 5.7), (4.4, 5.7), stroke: luma(100), mark: (end: ">"))
  let frames = ((4.4, [origin]), (6.5, [.]), (8.6, [.]), (10.7, [rethrow]))
  for (x0, t) in frames {
    let f = if t == [origin] { luma(205) } else { luma(230) }
    cdraw.rect((x0, 5.2), (x0 + 1.9, 6.2), fill: f, radius: 0.02)
    cdraw.content((x0 + 0.95, 5.7), t, size: 6pt)
  }
  cdraw.content((8.5, 4.4), [same instance, origin frames intact], size: 6.5pt)
  cdraw.content((19.4, 6.9), [`throw e;`], size: 7pt)
  cdraw.rect((13.6, 5.2), (16.4, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((15.0, 5.7), [`throw e;`], size: 6pt)
  cdraw.line((16.4, 5.7), (17.6, 5.7), stroke: luma(100), mark: (end: ">"))
  let erased = ((17.6, [.]), (19.8, [.]), (22.0, [rethrow]))
  for (x0, t) in erased {
    let f = if t == [rethrow] { luma(205) } else { luma(245) }
    cdraw.rect((x0, 5.2), (x0 + 1.9, 6.2), fill: f, radius: 0.02)
    cdraw.content((x0 + 0.95, 5.7), t, size: 6pt)
  }
  cdraw.content((19.9, 4.4), [same instance, trace restarts here], size: 6.5pt)
  cdraw.content((11.9, 2.6), [CA2200 flags `throw e;` inside a catch, wrap instead #linebreak() and keep the original as `InnerException`], size: 6.5pt)
})

#callout("pitfall", "the analyzer watches this too", [
  CA2200 flags `throw e;` in a catch block for exactly this reason, and
  the second listing carries its suppression as documentation. When you
  must wrap rather than rethrow, keep the original as
  `InnerException`: `throw new TransferException("context", amount,
  caught);` so the chain stays walkable.
])

== expected failure is not an exception

Exceptions are for the exceptional. Parsing untrusted input, probing a
cache, reading an optional setting, these fail routinely, and the
library reflects that with `TryParse`, `TryGetValue`, and `TryAdd`
pairs that return a bool and push the value through an `out`
parameter, `out` being the by-reference parameter the callee must
assign, chapter 10 has the family:

#listing("csharp-net/samples/src/Ch08/Errors.cs", first: 116, last: 117, caption: [TryParse turns a throwing parse into a branch])

#diagram([two error models, throwing parse vs try pattern], length: 13pt, {
  // the same routine failure under each model
  cdraw.content((2.0, 6.6), [throwing], size: 7pt)
  cdraw.rect((0.4, 4.8), (7.2, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 5.3), [`int.Parse(input)`], size: 6pt)
  cdraw.line((7.2, 5.3), (8.6, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.6, 4.4), (16.6, 6.2), fill: luma(245), radius: 0.02)
  cdraw.content((12.6, 5.3), [FormatException #linebreak() on garbage input], size: 6pt)
  cdraw.content((2.0, 3.8), [try pattern], size: 7pt)
  cdraw.rect((0.4, 2.0), (7.2, 3.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 2.5), [`TryParse(s, out n)`], size: 6pt)
  cdraw.line((7.2, 2.5), (8.6, 2.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.6, 1.6), (16.6, 3.4), fill: luma(205), radius: 0.02)
  cdraw.content((12.6, 2.5), [false, `out` value set, #linebreak() nothing ever throws], size: 6pt)
  cdraw.content((10.0, 0.2), [routine failure becomes a branch with no exception cost, #linebreak() the same shape as `TryGetValue` and `TryAdd`], size: 6.5pt)
})

The suite drives that line with valid input, garbage, a negative
number, and null. None of them throw. Chapter 15 collects this into
the wider discipline of choosing between error models.

sources: learn.microsoft.com, exception handling statements, creating
and throwing exceptions, exception handling programming guide, and
ca2200 pages, accessed 2026-09-08. Sample behavior verified by `make
verify-csharp`, 14 tests.
