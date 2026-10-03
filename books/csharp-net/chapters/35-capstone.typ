#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= capstone: a small language interpreter

The capstone is a working interpreter for a small language, built
test-first in this repo at `books/csharp-net/capstone/`, 54 xunit
tests, zero skipped, runnable from that folder with `dotnet test`.
Every stage of this book's material appears once in it, for real: the
lexer is a `ref struct` over a span, the syntax tree is a pair of
C\# 15 unions that serializes through `System.Text.Json`, the
checker is a pattern-matching pass, the evaluator is async end to
end, the builtin function table does not exist, a source generator
writes it, and interpreter state survives to disk through one SQLite
file.

== the pipeline

Source text becomes tokens, tokens become a tree, the tree is checked
once statically, then evaluated:

#snippet(
  "var lexer = new Lexer(source.AsSpan());\n"
  + "var tokens = lexer.Scan();\n"
  + "var program = new Parser(tokens).ParseProgram();\n"
  + "new Checker().Check(program);\n"
  + "var evaluator = new Evaluator(Console.Out.WriteLineAsync);\n"
  + "await evaluator.RunAsync(program, cancellationToken);\n",
  lang: "cs",
)

#flow(
  [the interpreter pipeline, one pass per stage],
  node((0, 0), [source text]),
  node((1.9, 0), [lexer]),
  node((3.8, 0), [parser]),
  node((5.7, 0), [checker]),
  node((7.6, 0), [evaluator]),
  edge((0, 0), (1.9, 0), "-|>", label: [span, no copies]),
  edge((1.9, 0), (3.8, 0), "-|>", label: [tokens]),
  edge((3.8, 0), (5.7, 0), "-|>", label: [union tree]),
  edge((5.7, 0), (7.6, 0), "-|>", label: [checked tree]),
)

== the language

Statements: `let` bindings, assignment, `print`, `if`/`else if`/
`else`, `while`, blocks. Expressions: number, string, and boolean
literals, names, unary `!` and `-`, comparisons, arithmetic, and
calls to builtin functions. Comments run to end of line. The test
suite's `Run` helper is the whole language in miniature:

#listing("csharp-net/capstone/tests/Capstone.Tests/EvalTests.cs", first: 7, last: 20, caption: [source to output in one helper])

#diagram([the toy language, statements and expressions as one map], length: 13pt, {
  // statements at left, expressions at right
  cdraw.content((4.8, 6.4), [statements], size: 6.5pt)
  cdraw.rect((0.2, 2.4), (9.4, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.8, 4.1), [`let`, assign, `print`, #linebreak() `if`, `else if`, `else`, #linebreak() `while`, blocks], size: 6pt)
  cdraw.content((15.1, 6.4), [expressions], size: 6.5pt)
  cdraw.rect((10.4, 2.4), (19.8, 5.8), fill: luma(230), radius: 0.02)
  cdraw.content((15.1, 4.1), [number, string, bool literals, #linebreak() names, unary, comparisons, #linebreak() arithmetic, builtin calls], size: 6pt)
  cdraw.content((10.0, 1.0), [the `Run` helper is the whole language in miniature], size: 6.5pt)
  cdraw.content((10.0, -0.4), [comments run to end of line], size: 6.5pt)
})

== lexer, a ref struct over a span

Chapter 10 said `ref struct` plus `ReadOnlySpan<char>` is the
allocation free way to walk a buffer. The lexer is that shape exactly:
the source is never copied, slices convert to strings only when a
token is built, and the `Scan` loop produces the token list:

#listing("csharp-net/capstone/src/Capstone/Lexer.cs", first: 6, last: 19, caption: [the ref struct lexer and its scan loop])

Number scanning shows the span discipline, start index, advance,
slice once at the end, with the malformed-double rule enforced
against the character stream:

#listing("csharp-net/capstone/src/Capstone/Lexer.cs", first: 69, last: 89, caption: [digits, one decimal point, no second one])

#diagram([the lexer, a cursor over a span, no copies while scanning], length: 13pt, {
  // the source buffer, the cursor fields, the one place a string is built
  cdraw.rect((0.2, 3.2), (13.4, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((6.8, 3.9), [the source, a `ReadOnlySpan<char>`], size: 6pt)
  cdraw.line((3.4, 5.4), (3.4, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.4, 5.9), [`pos`], size: 6pt)
  cdraw.line((9.6, 5.4), (9.6, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 5.9), [`line`], size: 6pt)
  cdraw.line((13.4, 3.9), (14.6, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.9, 5.5), [only here], size: 6pt)
  cdraw.rect((14.8, 2.8), (22.0, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((18.4, 3.7), [a token: the slice #linebreak() becomes a string], size: 6pt)
  cdraw.content((7.0, 1.6), [scanning advances the cursor in place, the buffer is never copied], size: 6.5pt)
  cdraw.content((7.0, 0.2), [the one-decimal-point rule is enforced against the character stream], size: 6.5pt)
})

== the tree, a c\# 15 union

The C\# 15 unions from chapter 3 are the tree. Every case is a sealed
record with no base class, each carrying its own `Line`, and `Expr`
and `Stmt` are one declaration line each: a sealed struct the
compiler closes over its cases, an implicit conversion from every
case, and pattern matching that reaches the case:

#listing("csharp-net/capstone/src/Capstone/Ast.cs", first: 3, last: 21, caption: [expression cases and the one line union over them])

The statements are the same shape with one honest wrinkle. `let` and
assignment carry byte identical payloads, `Name`, `Value`, `Line`,
and no payload reader can ever tell them apart, so both records also
expose a get-only `Kind` property: the keyword rides along on the
wire, written out by the serializer and ignored on the way back, with
no serializer attributes anywhere in the tree:

#listing("csharp-net/capstone/src/Capstone/Ast.cs", first: 23, last: 47, caption: [statement cases, the kind tag, the second union])

Line lookup for error reporting is a switch expression over each
union with no discard arm. Every pass gets the same guarantee the
declaration buys: add a case, forget a switch, and the compiler says
CS8509 before any test runs:

#listing("csharp-net/capstone/src/Capstone/Ast.cs", first: 49, last: 74, caption: [exhaustive line lookup over both unions])

Serialization is where the unions pay differently from the old
polymorphic hierarchy. Serialize writes the bare case payload, no
envelope and no `$type` discriminator. Reading must name the case
from the payload alone, and the built-in
`JsonUnionTypeStructuralClassifier` refuses both unions at configure
time because it picks by property names and the three literal cases
all carry `Value` plus `Line`. The refusal names its own escape
hatch, a custom `JsonTypeClassifier` on the reused options, and that
one reads more than names: the json kind of `Value` separates the
literals, `Args` and `Operand` and `Left` name the composite cases,
and the `Kind` tag splits `let` from assignment:

#listing("csharp-net/capstone/src/Capstone/AstJson.cs", first: 14, last: 62, caption: [one classifier, payload shape back to case type])

One honest caveat surfaced by the tests: record equality does not
recurse into `List<T>` members, `Args` and `Then` compare by
reference. The round trip test therefore proves fidelity by
re-serializing and comparing documents, and the run test executes the
deserialized tree and checks its output, which is the stronger claim
anyway.

#diagram([the ast, sealed record cases under one union], length: 13pt, {
  // the tree shape at left, the json story at right
  cdraw.rect((0.6, 4.6), (4.6, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((2.6, 5.1), [`Program`], size: 6pt)
  cdraw.line((2.6, 4.6), (1.6, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.6, 4.6), (4.6, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 2.6), (3.4, 3.6), fill: luma(230), radius: 0.02)
  cdraw.content((1.8, 3.1), [`LetStmt`], size: 6pt)
  cdraw.rect((3.6, 2.6), (7.2, 3.6), fill: luma(230), radius: 0.02)
  cdraw.content((5.4, 3.1), [`PrintStmt`], size: 6pt)
  cdraw.line((1.8, 2.6), (1.8, 1.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 0.6), (3.4, 1.6), fill: luma(235), radius: 0.02)
  cdraw.content((1.8, 1.1), [`BinaryExpr`], size: 6pt)
  cdraw.rect((10.6, 4.0), (18.0, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((14.3, 4.9), [the case is the payload, #linebreak() no `$type` anywhere], size: 6pt)
  cdraw.content((14.6, 2.0), [record equality does not recurse #linebreak() into `List` members: fidelity is #linebreak() proven by re-serializing], size: 6.5pt)
})

== parser, precedence by method chain

Recursive descent encodes precedence as call depth: `Equality` calls
`Comparison` calls `Additive` calls `Multiplicative` calls `Unary`
calls `Primary`, so tighter-binding operators sit lower and finish
first:

#listing("csharp-net/capstone/src/Capstone/Parser.cs", first: 123, last: 147, caption: [two levels of the precedence chain])

#diagram([precedence as call depth, tighter operators deeper], length: 13pt, {
  // the method chain as a stack, loosest on top
  let levels = ([`Equality`], [`Comparison`], [`Additive`], [`Multiplicative`], [`Unary`], [`Primary`])
  for (i, t) in levels.enumerate() {
    let y = 6.2 - i * 1.05
    let f = if i == 5 { luma(205) } else { luma(230) }
    cdraw.rect((4.0, y - 0.45), (12.0, y + 0.45), fill: f, radius: 0.02)
    cdraw.content((8.0, y), t, size: 6pt)
  }
  cdraw.content((16.4, 6.2), [loosest, called first], size: 6.5pt)
  cdraw.content((16.4, 0.95), [tightest, finishes first], size: 6.5pt)
  cdraw.content((10.0, -0.5), [each level loops its own operator set, #linebreak() which is what makes subtraction left associative], size: 6.5pt)
})

Each level loops over its own operator set, which is what makes
`8 - 4 - 2` left associative, and `else if` is a nested `IfStmt` in
the otherwise list rather than a special node, which is why the tree
has no `ElseIf` case to pattern match.

== checker, pattern matching over the tree

The static pass proves what it can and stays quiet about the rest.
Each expression returns the statically known kind or null for
unknown, names must be declared before use, conditions must be flags
when their kind is known, and arithmetic must be numbers when its
operand kinds are known. The unknown-node fallbacks are gone: the
switch over `Stmt` carries no discard arm, and the kind lookup is a
switch expression the compiler checks, a missing case is CS8509:

#listing("csharp-net/capstone/src/Capstone/Checker.cs", first: 26, last: 60, caption: [statement checking as one switch, no discard arm])

#listing("csharp-net/capstone/src/Capstone/Checker.cs", first: 62, last: 81, caption: [conditions checked, kinds returned])

#diagram([the checker proves what it can, stays quiet about the rest], length: 13pt, {
  // the node kind on the left, the rule it enforces on the right
  let rows = (
    ([a name], [declared before use]),
    ([a condition], [flags when the kind is known]),
    ([arithmetic], [numbers when operand kinds are known]),
    ([a builtin], [exists, arity from the registry]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.4 - i * 1.15
    cdraw.rect((0.4, y - 0.5), (4.6, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((2.5, y), row.at(0), size: 6pt)
    cdraw.line((4.6, y), (5.6, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((13.4, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((10.0, -0.4), [every rule returns the statically known kind or null, #linebreak() unknown kinds pass through unchecked on purpose], size: 6.5pt)
})

The checker consults the generated registry for builtin existence
and arity, so an arity error is a compile-of-the-program error, not a
runtime surprise.

== evaluator, async end to end

`RunAsync` walks statements, `Eval` walks expressions, and both carry
the `CancellationToken` from chapter 9 through every await. `Eval` is
a switch expression, exhaustiveness compiler checked like every other
switch over the tree, and the arms with real work live in per-case
helpers. Builtin calls are dictionary lookups whose values are async
delegates:

#listing("csharp-net/capstone/src/Capstone/Evaluator.cs", first: 34, last: 67, caption: [statement execution as a switch over the union])

#listing("csharp-net/capstone/src/Capstone/Evaluator.cs", first: 69, last: 82, caption: [expression evaluation as a checked switch expression])

Binary operators apply through a switch expression with tiny helper
closures, and the one rule with dynamic flavor, text plus anything
concatenates, lives in one place:

#listing("csharp-net/capstone/src/Capstone/Evaluator.cs", first: 117, last: 148, caption: [operator application, arithmetic, comparison, plus])

#diagram([the evaluator, a statement walk with awaits inside], length: 13pt, {
  // runstmt drives eval, output is awaited, the token gates every turn
  cdraw.rect((0.2, 3.4), (5.4, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((2.8, 4.1), [`RunStmt`, #linebreak() a switch over the union], size: 6pt)
  cdraw.line((5.4, 4.1), (6.4, 4.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.6, 3.4), (10.8, 4.8), fill: luma(230), radius: 0.02)
  cdraw.content((8.7, 4.1), [`Eval`, #linebreak() expressions], size: 6pt)
  cdraw.line((10.8, 4.1), (11.8, 4.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 3.4), (17.2, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((14.6, 4.1), [the write, awaited], size: 6pt)
  cdraw.content((8.6, 1.8), [the cancellation token is checked #linebreak() at every turn of every loop], size: 6.5pt)
  cdraw.content((8.6, -0.45), [builtins: async dictionary values, #linebreak() text plus anything concatenates, one place], size: 6.5pt)
})

== builtins and the generator that registers them

A builtin is a static method marked with an attribute carrying its
call name and arity. That is the entire registration procedure:

#listing("csharp-net/capstone/src/Capstone/Builtins.cs", first: 5, last: 33, caption: [the attribute and two builtins, one async])

The chapter 13 generator shape produces `BuiltinRegistry` with a
delegate table and an arity table, collected from every marked
method, sorted for deterministic output:

#listing("csharp-net/capstone/src/Capstone.Generators/BuiltinGenerator.cs", first: 28, last: 75, caption: [collect marked methods, emit one registry])

#diagram([the registration pipeline, attribute to generated registry], length: 13pt, {
  // mark, collect, sort, emit, at compile time
  cdraw.rect((0.2, 3.2), (6.9, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.55, 4.0), [the attribute marks #linebreak() a static method], size: 6pt)
  cdraw.line((6.9, 4.0), (7.7, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.9, 3.2), (14.9, 4.8), fill: luma(230), radius: 0.02)
  cdraw.content((11.4, 4.0), [collect and sort, #linebreak() deterministic output], size: 6pt)
  cdraw.line((14.9, 4.0), (15.7, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.9, 3.2), (23.6, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((19.75, 4.0), [emit `BuiltinRegistry`, #linebreak() delegate, arity table], size: 6pt)
  cdraw.content((11.0, 1.6), [all of it at compile time, the registry never exists as hand written code], size: 6.5pt)
  cdraw.content((11.0, 0.2), [the registry tests were red until it generated], size: 6.5pt)
})

The registry tests were written before the generator existed, failed
to compile against the missing `BuiltinRegistry`, and passed once it
was generated, which is the red-green rhythm applied to compile time
metaprogramming.

== saves, one sqlite file

Interpreter state survives a process boundary. `Save` writes the
evaluator's definitions and the checker's declared names into two
tables of one SQLite file, `Load` rebuilds fresh instances from them,
and the PersistenceTests make the stronger claim: a program run
against reloaded state produces the same output as the pre-save run,
and a name loaded from disk cannot be redefined. The connection pins
`Pooling=False` because pooled connections hold the file open on
Windows after dispose. One test asserts the engine version itself,
3.53.4, the same pinned e_sqlite3 build the samples carry:

#listing("csharp-net/capstone/src/Capstone/Persistence.cs", first: 58, last: 84, caption: [load, the engine version probe, pooling off])

#diagram([saves, one sqlite file across the process boundary], length: 13pt, {
  // the live interpreter, the file, the rebuilt one, the claims below
  cdraw.rect((0.0, 5.0), (7.0, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 5.7), [the live interpreter #linebreak() definitions, declared names], size: 6pt)
  cdraw.line((7.0, 5.7), (8.8, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.9, 6.9), [`Save`], size: 6pt)
  cdraw.rect((9.0, 5.0), (15.0, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((12.0, 5.7), [one sqlite file #linebreak() two tables], size: 6pt)
  cdraw.line((15.0, 5.7), (16.8, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.9, 6.9), [`Load`], size: 6pt)
  cdraw.rect((17.0, 5.0), (24.0, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((20.5, 5.7), [a fresh process #linebreak() state rebuilt], size: 6pt)
  cdraw.content((12.0, 3.6), [the persistence tests: reloaded state produces the same output, #linebreak() and a name loaded from disk cannot be redefined], size: 6.5pt)
  cdraw.content((12.0, 1.9), [the tables `definition` and `checked_name`, `Pooling=False` because #linebreak() pooled connections hold the file open on windows, engine 3.53.4], size: 6.5pt)
})

== what the capstone proves

Every chapter's promise, cashed: lexical structure (chapter 2) in the
scanner's token set, the type system (chapter 3) in union
declarations over record cases, value semantics throughout, members
and extension blocks (chapter 4) in the attribute and generated
static class, generics (chapter 5) in the delegate table type,
patterns (chapter 6) in every switch over the AST, delegates
(chapter 7) in the registry's stored functions, exceptions (chapter
8) in `LexException` through `CheckException` with line numbers,
async (chapter 9) in the awaited evaluator and cancellation paths,
memory (chapter 10) in the span lexer, source generation (chapter
13) in the registry, the stdlib (chapters 15 and 16) in
`System.Text.Json` round trips and the SQLite save store, and the
idioms (chapter 17) in the discipline of the suite itself. The
outlook chapter that once pointed at this code is gone, folded into
the home chapters where the C\# 15 and .NET 11 features are used,
and the RC1 SDK pin honesty lives in the appendices' pinned sources.
The promise it made about this tree is kept by the tree: `Expr` and
`Stmt` are union declarations, the discard arms are gone, and a
missing case is CS8509 at build time.

#diagram([every chapter cashed in one interpreter], length: 13pt, {
  // the chapter on the left, the site where it pays off on the right
  let rows = (
    ([ch 2], [the scanner's token set]),
    ([ch 3], [union tree, record cases]),
    ([ch 5-7], [the delegate table's stored functions]),
    ([ch 9], [the awaited evaluator, cancellation]),
    ([ch 10], [the span lexer]),
    ([ch 13], [the generated registry]),
    ([ch 15-16], [json round trips, sqlite saves]),
    ([ch 17], [the discipline of the suite itself]),
  )
  for (i, row) in rows.enumerate() {
    let y = 7.1 - i * 1.15
    cdraw.rect((0.4, y - 0.5), (3.6, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((2.0, y), row.at(0), size: 6pt)
    cdraw.line((3.6, y), (4.6, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((12.4, y), row.at(1), size: 6.5pt)
  }
  cdraw.content((11.0, -2.7), [ch 3 unions are the tree: no discard arms, #linebreak() a missing case is CS8509 at build time], size: 6.5pt)
})

== profiled, and why

Chapters 11 and 12 built the measurement discipline, so the capstone
now turns it on itself. The bench's `capstone` mode runs the whole
language in miniature, a program of four statements whose `while` loop
turns 1000 times, through the full pipeline 2,000 times, plus each
stage in isolation:

#listing("csharp-net/samples/bench/CapstoneBench.cs", first: 14, last: 32, caption: [the measured workload: let, arithmetic, a 1000-turn loop, if else, print])

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*stage, 2000 runs*], [*median*], [*p99*]),
  [lex, the span lexer], [6.8 us], [12.9 us],
  [parse, precedence chain], [6.5 us], [10.9 us],
  [check, pattern pass], [7.1 us], [16.3 us],
  [eval, cached tree], [307.9 us], [1324.9 us],
  [full pipeline], [p50 0.3198 ms], [p99 0.5587 ms, p99.9 0.6737 ms],
)

BenchmarkDotNet over the same stages, InProcess toolchain, warmup 3,
15 iterations, this machine, 2026-09-13:

```text
| Method             | Mean       | Error     | StdDev    | Ratio | Gen0    | Gen1   | Allocated  | Alloc Ratio |
| EvalOverCachedTree | 318.538 us | 3.5214 us | 3.2939 us | 1.000 | 85.9375 |      - | 1102.89 KB |       1.000 |
| Lex                |   1.788 us | 0.1660 us | 0.1553 us | 0.006 |  0.4158 | 0.0057 |    5.32 KB |       0.005 |
| ColdPipeline       |   3.033 us | 0.2915 us | 0.2727 us | 0.010 |  0.5341 | 0.0076 |    6.84 KB |       0.006 |
```

#listing("csharp-net/samples/bench/CapstoneBench.cs", first: 113, last: 147, caption: [the a slash b: eval over a cached tree against lex and the cold pipeline])

The counters panel, a 4 second capture of the eval loop committed as
`samples/captures/counters-capstone-2026-09-13.csv`, reads the same
story from outside: the allocation rate is 3.0 GB per second,
generation 0 fires about 230 times a second, generation 1 and 2 stay
at zero, and the pause tax is 2.4 percent of wall time. Die-young
churn, exactly chapter 11's ephemeral pattern, at a rate the front
end never approaches.

#diagram([where the time is: the evaluator is the program, the front end is noise], length: 13pt, {
  // one row per stage, width by median, the eval bar dominant
  let stages = (
    ([lex], 6.8),
    ([parse], 6.5),
    ([check], 7.1),
    ([eval], 307.9),
  )
  for (i, (name, us)) in stages.enumerate() {
    let y = 5.6 - i * 1.15
    let w = 1.0 + us * 0.068
    cdraw.rect((0.2, y - 0.45), (w, y + 0.45), fill: luma(205), radius: 0.02)
    cdraw.content((1.2, y), name, size: 6pt)
    cdraw.content((w + 0.9, y), [#us us median], size: 6pt)
  }
  cdraw.content((11.4, 5.6), [1,129,361 bytes allocated per pipeline run], size: 6.5pt)
  cdraw.content((11.4, 4.2), [about 563 bytes per executed statement, #linebreak() the async machinery and the value traffic], size: 6pt)
  cdraw.content((11.4, 2.4), [gen 0 at ~230 per s, gen 1 and 2 at zero, #linebreak() 2.4 percent of wall paused], size: 6pt)
  cdraw.content((11.4, 0.6), [the fix path is chapter 11's: fewer allocations per statement, #linebreak() not a faster lexer], size: 6.5pt)
})

Why the evaluator costs what it costs: every statement dispatch is an
`await`ed method, so each of the 2,006 statement executions pays the
async state machinery, and the loop's hot statements, two assignments
and a condition per turn, allocate on every turn through `Eval`
returning `Task<Value>` and the state machine each awaited method
carries. The
write path never suspends, the callback is
`Task.CompletedTask`, so none of this is waiting on anything: it is
the price of the shape, measured at 563 bytes and about 150
nanoseconds per statement. The tail tells the rest: eval's p99 is 4.3
times its median because those 230 generation 0 collections per
second land inside eval reps, and the pipeline p99 of 0.5587 ms
against a p50 of 0.3198 ms is the same pauses seen end to end.
Chapter 12's rule applies to the capstone too: the front end is fast
enough that optimizing the lexer or parser is decoration, the
evaluator's allocation rate is the whole story, and the honest
comparisons are the synchronous F\# port in chapter 21, which removed
the async dimension deliberately, and a `ValueTask` rewrite, which
this teaching tree leaves as the measured exercise it now is.

== the service part

The service part built on the same book after this capstone is the
next evidence layer: chapters 22 through 34 land the api kernel and
middleware, the users, authn, authz, store, concurrency, caching,
rate limiting, observability, and load families, the docker ship
chapter, and the test suite chapter, the book stamped 5.0 at the
close. The lane gates through `make verify-csharp` in the repo
chain, the ship lane under `make verify-csapi-docker`. The audit
records the post-attack closeout, 2026-09-26: 379 tests under the
api solution after the blind module and prose attack rounds, and
the docker lane 6 of 6 over the real image.

sources: the capstone solution in this repo, built and tested with
`make verify-csharp` and from its own directory with `dotnet test`,
54 tests, zero skipped, all green on the pinned SDK 11.0.100-rc.1.
Union serialization measured on this SDK: serialize writes the bare
case payload, `JsonUnionTypeStructuralClassifier` rejects same-shaped
cases at configure time, and a custom `JsonTypeClassifier` reads the
payload back. The serializer's attribute is `JsonUnionAttribute`,
`System.Runtime.CompilerServices.UnionAttribute` belongs to the
compiler. learn.microsoft.com, what's new in .NET 11 libraries,
serialize C\# union types, and jsontypeclassifier pages, accessed
2026-09-13.
