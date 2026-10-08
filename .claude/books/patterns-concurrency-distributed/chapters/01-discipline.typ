#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= pattern discipline

The classic pattern vocabulary was written for languages with classes,
inheritance, and virtual dispatch. Go has none of the three, and
neither do four of the seven languages asking the question beside it in
this book. The first engineering decision is not which pattern to
apply but which patterns survive translation at all: some collapse
into a function, some into a struct literal or a plain table, and the
ones that remain take a different shape in each language's grain.

This book asks in seven voices. The go lane stays the frozen reference:
one module, `patternsbook` on go 1.27, living at
`patterns-concurrency-distributed/samples/`, its listings and tests
untouched while six sibling trees grew around it, and every shared
fixture in those trees cross-verified against its implementation. The
siblings carry the same samples, one concept per file, each in its own
spelling:

#table(
  columns: (auto, 1.9fr, 1.1fr),
  inset: 4pt,
  table.header([*tree*], [*shape*], [*verify leg*]),
  [`samples-c/`], [one standalone `main` per file, libc plus C23 `<threads.h>` and `<stdatomic.h>`], [`verify-c`],
  [`samples/`], [one go module, go 1.27, the frozen reference lane], [`verify-go`, race leg included],
  [`samples-java/`], [one public class per file, checks printed as `ok N name` on the pinned jdk 27], [`verify-java`],
  [`samples-cs/`], [one net solution, sources beside xunit test projects], [`verify-csharp`],
  [`samples-js/`], [pure esm modules, one test file per chapter], [`verify-ts`],
  [`samples-py/`], [script-style modules, each ending in `ok N name`], [`verify-py`],
  [`samples-lua/`], [files returning named test rows to a shared `run.lua`], [`verify-lua`],
)

Every leg also runs chapter scoped, the form the dry runs in this
book assume:

+ C: `-SampleRoot books/patterns-concurrency-distributed/samples-c/src -Chapter ChNN`
+ go: `go test ./chNN`
+ java: `-SampleRoot books/patterns-concurrency-distributed/samples-java/src -Chapter ChNN` under `run-java-samples`
+ C\#: `dotnet test` filtering the solution to `FullyQualifiedName~ChNN`
+ javascript: `node --test test/chNN*.test.mjs`
+ python: the matching `-SampleRoot books/patterns-concurrency-distributed/samples-py/src -Chapter ChNN`
+ lua: the runner always reads the whole suite, each chapter's rows kept in order

The caption contract for everything that follows: every featured
section shows all seven listings, labeled with their language, in
corpus order c, go, java, c\#, javascript, python, lua. Go is one
voice among seven, the reference the others are checked against, no
longer the book's default. The chapter 16 raft capstone and the
chapter 17 appendices stay go only, single-language capstones on
purpose.

The discipline this chapter sets for the next four: a pattern is a
name attached to a recurring tradeoff, never a folder of boilerplate.
When the language makes the tradeoff disappear, the pattern goes with
it, and saying so is more useful than imitating java.

== the seven execution models

Most of the patterns ahead are concurrency patterns, so the map worth
pinning once is the execution model under each tree. C spawns real
operating system threads through C23 `<threads.h>` and shares state
through `<stdatomic.h>`: the kernel preempts, the scheduler lives
outside the program, and every claim about interleaving has to survive
that. Go multiplexes goroutines onto a pool,
#xref-to("go", "runtime") opens the scheduler they ride, and the
culture hands data through native channels. Java rides virtual
threads, cheap threads the jvm multiplexes onto a carrier pool, with
`ExecutorService` for pools and `VarHandle` fences for shared state,
the primitives the concurrency chapters ahead lean on. C\# multiplexes
tasks onto a pool and reaches for `System.Threading.Channels` beside
go's native ones. Javascript runs one thread per realm: the event loop
is the only scheduler, every `await` is a queue entry, and true
parallelism means `worker_threads` exchanging messages,
#xref-to("javascript", "async") tours that loop. Python runs threads
under the GIL and does its serious concurrency in asyncio, where the
interpreter interleaves coroutines at await points,
#xref-to("python", "interpreter") is that machine. Lua has no
scheduler at all: coroutines suspend by hand, so every lua lane in
this book is a scripted coroutine under a deterministic driver,
#xref-to("lua", "coroutines") builds on that model.

The testing discipline follows from the map, and it is the same in all
seven trees. Where the lesson is what happens when operations
interleave, the test drives the interleaving itself: scripted
state-machine walks, coroutine schedulers, async queue pumps, a
patched clock. Where the lesson needs real threads, the test asserts
invariants, exact totals, multiset equality, bounds, never timings and
never free order. And one boundary stated once here and again in
chapter 9: race detection in this corpus is `go test -race`, the only
detector any verify leg runs. This platform's C toolchain ships no
thread sanitizer, the wall the icpc book documents for its own C
toolbox, so the C tree earns its concurrency claims by construction,
every observed interleaving either scripted or invariant checked.

== satisfaction is structural

A Go interface is a method set, and a type satisfies it by having the
methods, with no declaration binding the two. Effective Go states the
rule plainly: a type implements an interface just by implementing its
methods. The consequence for patterns is large: adapters and
decorators can be retrofitted onto types their author never knew
about, which is why half of the structural and behavioral patterns in
chapter 3 and 4 need nothing but a new type wrapping an old one.

The dry run: the prefix logger records exactly `app: hello`, the null
object emits nothing and satisfies anyway, and a value without the
method fails the shape check, at build time in go, C, C\#, and java,
at run time in javascript, python, and lua. The literal is pinned by
the six new trees, the frozen go test asserts the fresh-empty start
and the Discard null object, both against the same implementation.

#listing("patterns-concurrency-distributed/samples-c/src/Ch01/satisfaction.c", first: 19, last: 55, caption: [C, the interface is a vtable, the proof a static initializer that stops building when a slot goes missing])

#listing("patterns-concurrency-distributed/samples/ch01/discipline.go", first: 5, last: 24, caption: [Go, one method, two implementors, one of them the null object])

#listing("patterns-concurrency-distributed/samples/ch01/discipline.go", first: 26, last: 32, caption: [Go, blank identifier assertions fail the build when satisfaction breaks])

#listing("patterns-concurrency-distributed/samples-java/src/Ch01/Satisfaction.java", first: 18, last: 39, caption: [Java, satisfaction is nominal, the implements clause is the proof, checked where it is written])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch01/Satisfaction.cs", first: 3, last: 28, caption: [C\#, satisfaction is nominal, the declaration is the whole proof])

#listing("patterns-concurrency-distributed/samples-js/src/ch01-satisfaction.mjs", first: 1, last: 28, caption: [JavaScript, no declarations anywhere, the proof is a predicate any caller can run])

#listing("patterns-concurrency-distributed/samples-py/src/Ch01/satisfaction.py", first: 16, last: 45, caption: [Python, a runtime-checkable Protocol moves the proof to check time])

#listing("patterns-concurrency-distributed/samples-lua/ch01_satisfaction.lua", first: 6, last: 32, caption: [Lua, the protocol is a caller, any table carrying the method fits])

Each language spends the proof differently. Go writes it as dead
code, `var _ Logger = (*PrefixLogger)(nil)` never runs, allocates
nothing, and turns a would-be runtime surprise into a compile error.
C spends a static initializer: `prefix_iface` only builds while
`prefix_log` matches the slot's signature, the same contract enforced
by the linker's type checker instead of the compiler's. Java spends
nothing, `implements Logger` on the class header is checked where it
is written, and the file's `quiet instanceof Logger` check is the
runtime witness go spells as dead code. C\# spends nothing the same
way, `class PrefixLogger : Logger` at the declaration, the two
nominal trees where the classic interface shape is native. Javascript
has no build-time method-set check, so its honest proof is the
`isLogger` predicate, runnable by any caller and by tests. Python's
`runtime_checkable` Protocol moves go's compile error to an
`isinstance` in the checks, method presence only, signatures stay the
type checker's job. Lua has no check to move: the lookup happens at
the call, one lookup too late to save you, so the row table pins that
a bare table throws.

`Discard` is the null object pattern in five lines: it satisfies the
interface with zero behavior, so callers never need a nil check.
Stdlib reached the same shape with `io.Discard` and `http.NoBody`.

#diagram([the overlap is the implements relation, no declaration edge exists], length: 13pt, {
  cdraw.rect((0, 0), (6.6, 2.4), fill: luma(235), radius: 0.02)
  cdraw.rect((7.4, 0), (14, 2.4), fill: luma(235), radius: 0.02)
  cdraw.circle((7, 1.4), radius: 2.2, fill: luma(205))
  cdraw.line((7, 3.8), (7, 3.62), stroke: luma(100))
  cdraw.content((7, 4.05), [Logger method set], size: 6.5pt)
  cdraw.content((1.9, 1.85), [PrefixLogger], size: 6.5pt)
  cdraw.content((1.9, 0.5), [Log(msg string)], size: 6pt)
  cdraw.content((12.1, 1.85), [Discard], size: 6.5pt)
  cdraw.content((12.1, 0.5), [Log(string) {}], size: 6pt)
  cdraw.content((7, 1.4), [Log(msg string)], size: 6pt)
  cdraw.content((7, -1.5), [each type overlaps the method set, and that is all satisfaction is], size: 6.5pt)
})

== accept interfaces, return concrete types

A Go function that takes an interface and returns a concrete struct
gives callers looseness at the boundary and precision at the result.
The sample's decorator does exactly that, and the shape translates
with the wrapping mechanism swapped per language: a struct holding the
next vtable in C, a class holding the next interface in C\# and java,
an object holding a duck-typed inner in the dynamic three.

The dry run: one call carrying an embedded newline lands at the inner
logger as `svc: line one line two` and the wrapper's counter reads
exactly 1, numbers that pin in all seven lanes. Stacking two
sanitizers composes with only the innermost recording, a row the
C\#, java, python, and lua lanes pin.

#listing("patterns-concurrency-distributed/samples-c/src/Ch01/decorator.c", first: 44, last: 73, caption: [C, the decorator holds the next interface value, the wrap is a function plus its state struct])

#listing("patterns-concurrency-distributed/samples/ch01/discipline.go", first: 34, last: 49, caption: [Go, decorator number one: sanitize before forwarding])

#listing("patterns-concurrency-distributed/samples-java/src/Ch01/Decorator.java", first: 40, last: 59, caption: [Java, the constructor takes the interface, the returned class keeps its counter])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch01/Decorator.cs", first: 1, last: 20, caption: [C\#, the constructor takes the interface, the result is the concrete class])

#listing("patterns-concurrency-distributed/samples-js/src/ch01-decorator.mjs", first: 1, last: 19, caption: [JavaScript, the wrapper is a class over any object with a log method])

#listing("patterns-concurrency-distributed/samples-py/src/Ch01/decorator.py", first: 30, last: 48, caption: [Python, the null object rides underneath, the wrapper stays inspectable])

#listing("patterns-concurrency-distributed/samples-lua/ch01_decorator.lua", first: 26, last: 42, caption: [Lua, Sanitizing is a metatable, decoration stacks through next])

`NewSanitizing` accepts any `Logger` and hands back a
`*SanitizingLogger` with its own extra methods. The reverse shape, a
function returning an interface, hides the concrete type and forces
assertions on every caller that wants more. C keeps the distinction
cheap by returning the concrete struct by value, C\# and java by
returning the class, and in javascript, python, and lua the returned
object already
carries everything it has, so the go row mostly evaporates and the
samples say so instead of imitating a cast. There is a place for
returning interfaces, error values and empty-interface style apis
being the honest ones, but it is the exception.

#flow(
  [any logger in, the concrete sanitizer out, the reverse hides the type],
  node((0, 0), [caller]),
  node((2.6, 0), [NewSanitizing(next Logger)]),
  node((5.4, 0), [`*SanitizingLogger`,#linebreak()SanitizedCount attached]),
  edge((0, 0), (2.6, 0), "-|>", label: [any Logger]),
  edge((2.6, 0), (5.4, 0), "-|>", label: [no casts needed]),
  node((2.6, -1.7), [NewX() Logger]),
  node((5.4, -1.7), [callers assert,#linebreak()s.(`*SanitizingLogger`)]),
  edge((2.6, -1.7), (5.4, -1.7), "-|>", label: [concrete type hidden]),
)

== embedding is forwarding, not inheritance

Struct embedding looks like subclassing and behaves like composition.
The methods of the embedded type are promoted, available on the outer
type without forwarding stubs, but the receiver stays the inner type.
Effective Go's phrasing is exact: when an embedded method is invoked,
the receiver is the inner type, not the outer one.

The dry run: `d.Name()` resolves to the outer override in every
language. `d.Describe()` prints `i am base` in go and in C, and
`i am derived` in C\#, java, javascript, python, and lua. That split
is the whole section, and each lane's name counter proves which call
actually ran.

#listing("patterns-concurrency-distributed/samples-c/src/Ch01/embedding.c", first: 19, last: 45, caption: [C, derived embeds base as a member, the forward into base's code is written out by hand])

#listing("patterns-concurrency-distributed/samples/ch01/discipline.go", first: 51, last: 68, caption: [Go, derived overrides name, but describe never notices])

#listing("patterns-concurrency-distributed/samples-java/src/Ch01/Embedding.java", first: 19, last: 63, caption: [Java, describe dispatches name virtually, and the Holder class forwards into a held base to rebuild go's trap on purpose])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch01/Embedding.cs", first: 1, last: 39, caption: [C\#, Name is virtual so Describe reaches the override, and `new`-hiding reproduces go's trap])

#listing("patterns-concurrency-distributed/samples-js/src/ch01-embedding.mjs", first: 1, last: 31, caption: [JavaScript, the prototype chain dispatches through the receiver, the override always wins])

#listing("patterns-concurrency-distributed/samples-py/src/Ch01/embedding.py", first: 15, last: 34, caption: [Python, self always consults the instance's class first, the go trap has no analog])

#listing("patterns-concurrency-distributed/samples-lua/ch01_embedding.lua", first: 8, last: 37, caption: [Lua, the class chain shares base's methods, lookup stays receiver-driven])

C matches go by construction: embedding a base struct as the first
member and forwarding `derived_describe` into `base_describe` is
exactly what go's promotion generates, and neither runtime
re-dispatches through the outer type. The five class-dispatch
languages agree with each other instead: `Describe` is one virtual
call away from the override. C\#'s file carries both behaviors in one
language, virtual `Name` for the contrast and the `new`-hiding
`Hidden` class for go's exact trap, which makes it the one place C\#
reads simpler than go, and java needs the keyword for neither half:
`Derived extends Base` gets the virtual dispatch for free while
`Holder` forwards `describe` into a held base against a fixed
receiver, the trap rebuilt by hand.

The test side is half the fixture, and each tree answers with its own
test artifact: the frozen go test file, the xunit and node test files,
and the check regions of the C, java, python, and lua modules.

#listing("patterns-concurrency-distributed/samples-c/src/Ch01/embedding.c", first: 47, last: 70, caption: [C, the check region: promotion reads the outer name, describe stays base, the counter catches it])

#listing("patterns-concurrency-distributed/samples/ch01/discipline_test.go", first: 27, last: 44, caption: [Go, the outer method wins by name, the inner body sees only the inner receiver])

#listing("patterns-concurrency-distributed/samples-java/src/Ch01/Embedding.java", first: 85, last: 99, caption: [Java, the check region: dispatch skips base.name, the Holder counter catches the forward, super pins the base])

#listing("patterns-concurrency-distributed/samples-cs/tests/Ch01/EmbeddingTests.cs", first: 1, last: 34, caption: [C\#, xunit pins virtual dispatch seeing the override and hiding reproducing forwarding])

#listing("patterns-concurrency-distributed/samples-js/test/ch01.test.mjs", first: 48, last: 68, caption: [JavaScript, node:test pins the contrast, the override intercepts every call])

#listing("patterns-concurrency-distributed/samples-py/src/Ch01/embedding.py", first: 36, last: 76, caption: [Python, the script region: dispatch skips base.name, super() pins it back on purpose])

#listing("patterns-concurrency-distributed/samples-lua/ch01_embedding.lua", first: 60, last: 89, caption: [Lua, the row table: dispatch reaches the override, a fixed-receiver forward reproduces go])

`d.Name()` resolves to the outer method, ordinary method-set rules.
But `d.Describe()` runs `Base`'s code, and inside that code `b.Name()`
is `Base.Name`, so the override is invisible and the counter proves
the inner method ran. In a virtual dispatch language `Describe` would
print `i am derived`. Template method, the gang of four pattern that
depends on exactly that late binding, does not translate: the go
shape is to pass the varying piece in, as a function value or an
interface field, which chapter 5 does with closures.

#flow(
  [go and c forward, the five class-dispatch languages reach the override],
  node((-1.2, 0.75), [go, c]),
  node((0, 1.5), [d.Name()]),
  node((1.9, 1.5), [Derived.Name,#linebreak()returns derived]),
  edge((0, 1.5), (1.9, 1.5), "-|>"),
  node((0, 0), [d.Describe()]),
  node((1.9, 0), [Base.Describe,#linebreak()base code runs]),
  node((4.3, 0), [b.Name() is Base.Name,#linebreak()prints i am base]),
  edge((0, 0), (1.9, 0), "-|>"),
  edge((1.9, 0), (4.3, 0), "-|>"),
  node((-1.2, -2.6), [c\#, java, js, py, lua]),
  node((0, -1.9), [d.Name()]),
  node((1.9, -1.9), [Derived.Name]),
  edge((0, -1.9), (1.9, -1.9), "-|>"),
  node((0, -3.1), [d.Describe()]),
  node((1.9, -3.1), [Base.Describe]),
  node((4.3, -3.1), [dispatch to override,#linebreak()prints i am derived]),
  edge((0, -3.1), (1.9, -3.1), "-|>"),
  edge((1.9, -3.1), (4.3, -3.1), "-|>"),
)

When composition needs the outer type, the fix is explicit
delegation, a named field plus forwarding methods, or an interface
field the inner code consults. Both are shown by contrast in the
decorator above: `SanitizingLogger` holds `Next Logger` and forwards
through it, so the chain is traversed by value, not by implicit
receiver. Python's `Cooperating` class in the check region shows the
same fix, `super().name()` when base behavior is what the override
wants, and java's `Cooperating` spells the same pin `super.name()`.

== what each language changes about the shapes

Two go facts keep the reference lane's pattern code honest this year.
Methods may now declare their own type parameters, so a generic
helper can be a method on a concrete type, while interface methods
still cannot be generic, so a strategy or visitor interface cannot
demand type-parameterized behavior from its implementors. Struct
literal keys accept field selectors, which trims some builder-shaped
ceremony around nested literals, covered with the creational chapter.

The wider question is what each tree changes about every shape, and
the answer is one line per language, the cards this book keeps
filling in:

#diagram([seven rule cards, one language each, the idiom summary every chapter returns to], length: 13pt, {
  let card = (x, y, lang, line) => {
    cdraw.rect((x, y), (x + 10.9, y + 2.6), fill: luma(235), radius: 0.02)
    cdraw.content((x + 5.45, y + 2.05), lang, size: 6.5pt)
    cdraw.content((x + 5.45, y + 0.9), line, size: 6pt)
  }
  card(0, 6.2, [c], [vtables, closures as state structs, threads by hand])
  card(11.1, 6.2, [go], [satisfaction, embedding, errors are values])
  card(0, 3.1, [java], [implements clauses, virtual dispatch, virtual threads])
  card(11.1, 3.1, [c\#], [nominal interfaces, virtual dispatch, channels in the bcl])
  card(0, 0.0, [javascript], [prototypes, duck typing, one loop per realm])
  card(11.1, 0.0, [python], [protocols, self dispatches, GIL bounds threads])
  card(0, -3.1, [lua], [metatables, coroutines by hand, tables do the rest])
})

The table this book keeps repeating, set once here in its go spelling:

#callout("note", "translation table", [
  The diagram below is the table. Two cells carry less than their
  rows deserve: singleton is package scope, or `sync.Once` when
  lazy, chapter 7, and adapter is a one method wrapper that needs
  no inheritance because satisfaction is structural. Every row has
  a per-language spelling, the map this chapter opened with.
])

#diagram([the translation table, class patterns to go shapes], length: 13pt, {
  let rows = (
    ([inheritance], [embedding, and it forwards]),
    ([abstract factory], [a function returning structs]),
    ([builder, simple cases], [a struct literal]),
    ([template method], [pass the varying step in]),
    ([visitor, double dispatch], [a type switch]),
    ([singleton], [package scope or sync.Once]),
    ([adapter], [a one method wrapper]),
  )
  cdraw.content((5, 9.1), [class language], size: 6.5pt)
  cdraw.content((17.25, 9.1), [go shape], size: 6.5pt)
  for (i, row) in rows.enumerate() {
    let y = 7.4 - i * 1.0
    cdraw.rect((0.5, y), (9.5, y + 0.85), fill: luma(235), radius: 0.02)
    cdraw.rect((12.5, y), (22, y + 0.85), fill: luma(235), radius: 0.02)
    cdraw.content((5, y + 0.42), row.at(0), size: 6pt)
    cdraw.content((17.25, y + 0.42), row.at(1), size: 6pt)
    cdraw.content((11, y + 0.42), [$arrow.r$], size: 6.5pt)
  }
})

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [171], [libc],
  [vtable of function pointers with void self, embedding a one-line forward],
  [go], [38], [stdlib],
  [satisfaction needs no declaration, the promoted Describe forwards into base],
  [java], [181], [jdk 27 stdlib],
  [the implements clause is the whole proof, go's forwarding trap must be rebuilt by hand as the Holder class],
  [c\#], [55], [bcl],
  [the declaration is the proof, virtual Name dispatches to the outermost override],
  [javascript], [49], [node stdlib],
  [duck typing proven by a runtime predicate, typeof x.log the whole check],
  [python], [127], [stdlib only],
  [runtime_checkable isinstance standing in for go's compile-time assertion],
  [lua], [163], [lib.lua harness],
  [metatable objects satisfy by carrying the method, checked one lookup too late],
)

sources: go.dev/doc/effective_go for satisfaction, embedding, and
receiver semantics, go.dev/doc/go1.27 for generic methods and literal
selector keys, accessed 2026-09-08. Verified by the seven chapter
legs: 3 Ch01 C programs with 16 embedded checks, `go test` at 4 tests
in `patternsbook/ch01`, the java runner's 22 Ch01 checks under
`run-java-samples`, 9 xunit facts, node's 8 cases in
`test/ch01.test.mjs`, 3 python modules with 25 embedded checks,
and the lua runner's 12 ch01 rows.
