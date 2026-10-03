#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= functional alternatives

Go is not a functional language and does not try to be: no curried
syntax, no monadic chaining, no tail call guarantee. But functions
are values, generics arrived in 1.18, and a surprising share of the
classic pattern vocabulary reduces to passing and returning
functions. The same reduction runs through all six trees, and the
per-language spelling is the chapter's real content: the trio is
one generic away in go and C\#, three plain loops in C, an array
method in javascript, a comprehension in python, a table walk in
lua. The chapter builds that toolkit and, just as carefully, marks
the line where the functional imitation should stop.

== the trio, generic

The trio is where generics earn their keep, one type parameter
saying what six handwritten loops would repeat:

The dry run: the fixture is 1 through 6. Map doubling lands 2 4 6 8
10 12, Filter keeping the evens lands 2 4 6, Reduce summing from 0
lands 21, and all six lanes assert these exact values. Map of empty
stays a real empty container, never nil or null, and Reduce of
empty hands back its init, pinned at 9.

+ Map preserves positions, Filter shrinks, Reduce collapses to one
  value carrying the init through.
+ The empty contracts: map of empty is an allocated zero-length
  slice in go, a real buffer in C, a fresh array in javascript, a
  list in python, a table in lua.
+ Reduce of empty never calls the fold, so the init comes back
  untouched, the identity every lane pins at 9.

#listing("patterns-concurrency-distributed/samples-c/src/Ch05/trio.c", first: 20, last: 49, caption: [C, the trio over int arrays, a function pointer per element, map of empty still returns a real buffer])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch05/Trio.cs", first: 4, last: 37, caption: [C\#, generics say it once, the same shape go writes])

#listing("patterns-concurrency-distributed/samples/ch05/functional.go", first: 6, last: 30, caption: [Go, map, filter, reduce over any slice])

#listing("patterns-concurrency-distributed/samples-js/src/ch05-trio.mjs", first: 6, last: 24, caption: [JavaScript, the standalone functions beside the array methods])

#listing("patterns-concurrency-distributed/samples-py/src/Ch05/trio.py", first: 13, last: 25, caption: [Python, comprehensions are the native map and filter, the fold is a plain loop])

#listing("patterns-concurrency-distributed/samples-lua/ch05_trio.lua", first: 6, last: 30, caption: [Lua, the trio as table walks, empty in keeps a table out])

These are one to three lines each and read fine, which is why the
stdlib never grew them: `Map` and `Filter` are usually clearer
inlined as a range loop, and the language even gave `for i := range
n` the integer form in 1.22 to trim the most common loop of all.
The moment composition, not iteration, is the point, chapter 4's
`iter.Seq` adapters are the better substrate because they fuse
instead of allocating intermediate slices. The sibling trees land
where their grain puts them: go and C\# write the generic
shape#xref-to("go", "generics") once and reuse it for every element
type, C specializes to int arrays with function pointers because
its generics are macros and the honest sample is just loops,
javascript arrays already carry `map`, `filter`, and `reduce` as
methods so the standalone functions exist to pin the contracts,
python's comprehensions are the native trio with `functools.reduce`
the fold nobody imports, and lua walks tables because that is all a
lua sequence is.

#flow(
  [map keeps the shape, filter shrinks it, reduce collapses to one],
  node((0, 0), [1 2 3 4 5 6]),
  node((2.6, 0), [Map 1:1,#linebreak()2 4 6 8 10 12]),
  node((5.4, 0), [Filter,#linebreak()2 4 6]),
  node((7.6, 0), [Reduce,#linebreak()21]),
  edge((0, 0), (2.6, 0), "-|>"),
  edge((2.6, 0), (5.4, 0), "-|>"),
  edge((5.4, 0), (7.6, 0), "-|>"),
)

== composition and partial application

`Pipe(f, g)` applies f then g, reading order matching writing order.
`AddTo` fixes one argument at application time. `Counter` is the
essential closure demonstration: `n` is captured by reference,
unreachable from outside, and two counters from the same
constructor share nothing:

The dry run: a pipe of trim then upper answers ABC for the padded
input, the empty pipe answers with its input untouched, and
AddTo(10) answers 15 at 5 and 0 at -10. Two counters built from 0
answer 1 and 1, then 2. The go lane's frozen test walks its own
counter literals, one counter climbing 1 2 3 4 beside a second from
100 reading 101 and 102, both verified against the same
implementation.

+ The empty pipe is the identity, and its return type is the input
  type, which is what makes it a lawful default.
+ Partial application closes over the base, not the call site, so
  the returned function carries its configuration.
+ State with an audience of zero is what closures sell and what
  chapter 7's mutexes are for when the audience grows.

#listing("patterns-concurrency-distributed/samples-c/src/Ch05/compose.c", first: 21, last: 69, caption: [C, a closure is a struct plus a function pointer, the pipe a list of them])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch05/Compose.cs", first: 3, last: 27, caption: [C\#, lambdas and a params array, the direct mirror])

#listing("patterns-concurrency-distributed/samples/ch05/functional.go", first: 33, last: 56, caption: [Go, pipe left to right, partial application, a closure with private state])

#listing("patterns-concurrency-distributed/samples-js/src/ch05-compose.mjs", first: 6, last: 24, caption: [JavaScript, rest arguments fold into arrows])

#listing("patterns-concurrency-distributed/samples-py/src/Ch05/compose.py", first: 41, last: 69, caption: [Python, nested defs, nonlocal for the writable cell, the checks pin 1, 1 then 2])

#listing("patterns-concurrency-distributed/samples-lua/ch05_compose.lua", first: 6, last: 28, caption: [Lua, closures over upvalues, the same three shapes])

C spells the closure out loud, a function pointer plus a state
pointer, because it has nothing to hide it behind, and the counter
closure becomes a `counter_state` struct the caller allocates. The
other five get the closure for free: C\# lambdas, javascript
arrows, python nested `def`s where `nonlocal` marks the writable
cell, lua upvalues. The pipe itself is the same fold everywhere,
apply the list in order and return the last output, and the empty
list folds to the identity by construction.

#diagram([pipe reads left to right, a closure is a private cell], length: 13pt, {
  cdraw.content((1.4, 7.6), [x], size: 6pt)
  cdraw.rect((2.6, 7.0), (5.4, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 7.6), [f], size: 6pt)
  cdraw.rect((6.6, 7.0), (9.4, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((8.0, 7.6), [g], size: 6pt)
  cdraw.content((11.0, 7.6), [g(f(x))], size: 6pt)
  cdraw.line((1.9, 7.6), (2.6, 7.6), stroke: luma(100))
  cdraw.line((5.4, 7.6), (6.6, 7.6), stroke: luma(100))
  cdraw.line((9.4, 7.6), (10.3, 7.6), stroke: luma(100))
  cdraw.content((7, 6.1), [pipe(f, g), the empty pipe is the identity], size: 6pt)
  cdraw.rect((3.4, 2.4), (7.2, 4.4), fill: luma(205), radius: 0.02)
  cdraw.content((5.3, 3.95), [counter a], size: 6.5pt)
  cdraw.content((5.3, 3.05), [n = 1], size: 6pt)
  cdraw.rect((8.6, 2.4), (12.4, 4.4), fill: luma(205), radius: 0.02)
  cdraw.content((10.5, 3.95), [counter b], size: 6.5pt)
  cdraw.content((10.5, 3.05), [n = 1], size: 6pt)
  cdraw.content((7.9, 1.2), [n is captured by reference and unreachable, the two share nothing], size: 6pt)
})

== the loop variable, fixed

Go 1.22 changed the oldest closure trap in the language: loop
variables are now created per iteration instead of shared. Before,
every closure capturing `i` in a loop observed the final value,
after, each observes its own:

The dry run: the fixture is 5 handlers, and the fixed lane pins
handler k returning k in all six trees. The trap lanes are
per-language truth: javascript's `var` lane returns 5 for every
handler, python's late-binding lambdas return 4 for every handler,
lua's deliberately shared local behind a while loop returns 6, and
C's shared-pointer lane returns 4. The go lane's frozen test pins
the fixed lane only.

+ `let` in javascript and the numeric for in lua create a fresh
  binding per iteration, the 1.22 semantics native and free.
+ `var` in javascript is one binding for the whole loop, the
  pre-1.22 semantics still alive whenever someone types it.
+ Python closures bind names, not values, so the default argument
  `i=i` is the hand-rolled per-iteration copy, comprehensions
  included.

#listing("patterns-concurrency-distributed/samples-c/src/Ch05/loopvar.c", first: 20, last: 36, caption: [C, no closures, the per-slot copy beside the shared-pointer trap, both written out])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch05/Loopvar.cs", first: 3, last: 30, caption: [C\#, foreach per-iteration since C\# 5, a copied local fixing the for loop])

#listing("patterns-concurrency-distributed/samples/ch05/functional.go", first: 59, last: 66, caption: [Go, each handler keeps the i of its own iteration])

#listing("patterns-concurrency-distributed/samples-js/src/ch05-loopvar.mjs", first: 7, last: 21, caption: [JavaScript, let versus var, the identical history in one file])

#listing("patterns-concurrency-distributed/samples-py/src/Ch05/loopvar.py", first: 15, last: 29, caption: [Python, late binding and the default-argument fix])

#listing("patterns-concurrency-distributed/samples-lua/ch05_loopvar.lua", first: 8, last: 37, caption: [Lua, the numeric for is per-iteration, the trap rebuilt with a while loop])

The test is the proof: five handlers, handler k returns k, where
pre-1.22 semantics would have returned 5 for all of them. The
semantics are gated by the module's `go` directive, so this module's
`go 1.27` line is what buys the fix. Code that must be correct under
both regimes still writes `i := i` at the loop head, and reviewers
still flag naked captures in old modules. The sibling trees turn
the trap into a museum: javascript's `var` lane is go's history
word for word#xref-to("javascript", "functions"), python's lambda
list is the same trap through late binding with the default
argument as the museum's exit, lua's numeric for never had the bug
so the sample builds it on purpose with a while loop over one
local, C stores a copy per slot because a pointer to the loop
variable dies with the iteration, and C\# fixed `foreach` captures
in C\# 5 while the raw `for` loop still shares, so the sample shows
the copied local beside it.

#diagram([before 1.22 one shared i, since then one i per iteration], length: 13pt, {
  cdraw.content((5.0, 8.6), [before 1.22, one shared i], size: 6.5pt)
  cdraw.rect((3.0, 6.9), (7.0, 8.1), fill: luma(205), radius: 0.02)
  cdraw.content((5.0, 7.5), [i], size: 6pt)
  for k in range(5) {
    let x = 0.8 + k * 1.9
    cdraw.rect((x, 4.6), (x + 1.6, 5.8), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.8, 5.2), [h#k], size: 6pt)
    cdraw.line((5.0, 6.9), (x + 0.8, 5.8), stroke: luma(220))
  }
  cdraw.content((5.0, 3.4), [every handler returns 5], size: 6pt)
  cdraw.content((17.3, 8.6), [since 1.22, one i per iteration], size: 6.5pt)
  for k in range(5) {
    let x = 13.1 + k * 1.9
    cdraw.rect((x, 6.9), (x + 1.6, 8.1), fill: luma(205), radius: 0.02)
    cdraw.content((x + 0.8, 7.5), [i = #k], size: 6pt)
    cdraw.rect((x, 4.6), (x + 1.6, 5.8), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.8, 5.2), [h#k], size: 6pt)
    cdraw.line((x + 0.8, 6.9), (x + 0.8, 5.8), stroke: luma(100))
  }
  cdraw.content((17.3, 3.4), [handler k returns k], size: 6pt)
})

== memoization

A memoized function is a decorator that trades memory for time, and
it generalizes cleanly:

The dry run: the wrapper holds a squaring function, 9 answers 81
twice and 12 answers 144 with the underlying function running
exactly 2 times. Recursive fib lands fib(5) = 5 at exactly 9 calls,
fib(10) = 55 at 19, and fib(40) = 102334155 at 79, the 2n-1 spine
the five new trees pin exactly. The go lane's frozen test pins the
fib(40) value, bounds the calls under 2n, and checks the count is
deterministic across instances, the 9 and 19 counts are the five
new trees' lane.

+ The wrapper guards only the map, the wrapped call runs outside
  the lock, and last write wins because the function is pure.
+ A memoized fib from an empty cache costs exactly 2n-1 calls, the
  spine down to the base cases plus one hit per level.
+ Concurrent callers hammer one wrapper and every answer is the
  function's, 50 goroutines in go, 4 threads in C, 20 threads in
  python, 50 coroutines in lua.

#listing("patterns-concurrency-distributed/samples-c/src/Ch05/memoize.c", first: 23, last: 53, caption: [C, fixed-array cache behind one mutex, the call runs outside the lock])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch05/Memoize.cs", first: 6, last: 27, caption: [C\#, the same shape, lock over a Dictionary])

#listing("patterns-concurrency-distributed/samples/ch05/functional.go", first: 68, last: 85, caption: [Go, generic memoize, lock guarded, last write wins])

#listing("patterns-concurrency-distributed/samples-js/src/ch05-memoize.mjs", first: 7, last: 15, caption: [JavaScript, a Map memo closure, no lock under one realm])

#listing("patterns-concurrency-distributed/samples-py/src/Ch05/memoize.py", first: 17, last: 30, caption: [Python, a lock-guarded dict closure, the counted lane the stdlib decorator cannot express])

#listing("patterns-concurrency-distributed/samples-lua/ch05_memoize.lua", first: 31, last: 44, caption: [Lua, the memo section never yields, so each key computes exactly once])

The lock is coarse by design: it protects the map, not the wrapped
call, so concurrent misses may both compute, last write wins, and
correctness holds because the function is pure. The test hammers it
from 50 goroutines under `-race`. The dynamic lanes state their own
boundary: javascript needs no lock because one realm runs one
thread, python's lock is real because the GIL switches threads
between bytecodes, and lua's cooperative scheduler cannot interrupt
the check, compute, store section at all, which is why its
concurrent lane also pins exactly 100 underlying calls for 100
keys, a determinism the preemptive lanes cannot promise.

#flow(
  [hit or miss, the wrapped call always runs outside the lock],
  node((0, 0), [memo(k)]),
  node((2.2, 0), [lookup,#linebreak()under lock]),
  node((4.5, 1.2), [hit: cached]),
  node((4.5, -1.2), [miss: run f,#linebreak()outside the lock]),
  node((6.8, -1.2), [store, then return]),
  edge((0, 0), (2.2, 0), "-|>"),
  edge((2.2, 0), (4.5, 1.2), "-|>", label: [hit]),
  edge((2.2, 0), (4.5, -1.2), "-|>", label: [miss]),
  edge((4.5, -1.2), (6.8, -1.2), "-|>"),
)

Recursive memoization exposes a real limit of closures: a function
cannot call its own memoized name, only the raw one, and raw
recursion skips the cache. Every tree reaches the same answer, a
named holder whose fields are the cache and the call counter:

#listing("patterns-concurrency-distributed/samples-c/src/Ch05/memoize.c", first: 73, last: 108, caption: [C, the named struct holds the cache array and the call counter])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch05/Memoize.cs", first: 30, last: 64, caption: [C\#, the Fib class, cache and counter as fields])

#listing("patterns-concurrency-distributed/samples/ch05/functional.go", first: 90, last: 116, caption: [Go, fib as a type with its own cache, calls counted])

#listing("patterns-concurrency-distributed/samples-js/src/ch05-memoize.mjs", first: 17, last: 34, caption: [JavaScript, private fields for the cache and the call count])

#listing("patterns-concurrency-distributed/samples-py/src/Ch05/memoize.py", first: 49, last: 63, caption: [Python, lock, cache, and counter as attributes])

#listing("patterns-concurrency-distributed/samples-lua/ch05_memoize.lua", first: 46, last: 61, caption: [Lua, the holder table, At recurses through it])

`Fib.At` checks the cache first, recurses on miss, stores before
returning. The test pins both correctness and economy, `fib(40)`
completes in 79 calls where the naive version needs `fib(40)` calls
for the value alone, and the call count is deterministic across
instances, which is what makes the test a test.

#diagram([naive fib calls explode, the cache holds the line at 2n-1], length: 13pt, {
  cdraw.line((2, 0), (2, 8.4), stroke: luma(100))
  cdraw.line((2, 0), (21, 0), stroke: luma(100))
  cdraw.content((1.1, 8.4), [calls], size: 6pt)
  cdraw.content((21.6, 0), [n], size: 6pt)
  cdraw.line((2, 0), (8.5, 0.9), stroke: luma(100))
  cdraw.line((8.5, 0.9), (12.5, 2.1), stroke: luma(100))
  cdraw.line((12.5, 2.1), (15.5, 3.9), stroke: luma(100))
  cdraw.line((15.5, 3.9), (17.8, 6.2), stroke: luma(100))
  cdraw.line((17.8, 6.2), (19.3, 8.2), stroke: luma(100))
  cdraw.content((14.6, 7.3), [naive: fib(40) calls], size: 6pt)
  cdraw.line((2, 0), (10.5, 1.2), stroke: luma(100))
  cdraw.line((10.5, 1.2), (19.3, 2.3), stroke: luma(100))
  cdraw.content((13.5, 1.1), [memoized: 2n-1], size: 6pt)
  cdraw.content((10.6, -1.1), [the named type holds the cache because a closure cannot reach its own memoized name], size: 6pt)
})

#callout("pitfall", "where to stop", [
  The line this book draws: functions as values, composition, and
  memoization pay rent. Simulating sum types with interfaces plus
  `IsLeft` methods, writing `FlatMap` over error, or building lazy
  evaluator frameworks fights the language for aesthetics. Idiomatic
  go keeps error handling in `if err != nil` and reaches for a
  goroutine when evaluation must be deferred, which is the next
  chapter's subject in full.
])

#diagram([where the functional style pays and where it fights], length: 13pt, {
  cdraw.rect((0, 4.0), (22, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((11, 7.95), [pays rent], size: 6.5pt)
  cdraw.content((11, 6.8), [function values], size: 6pt)
  cdraw.content((11, 5.65), [composition and partial application], size: 6pt)
  cdraw.content((11, 4.5), [memoization], size: 6pt)
  cdraw.rect((0, 0.0), (22, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((11, 3.15), [fights the language], size: 6.5pt)
  cdraw.content((11, 2.0), [sum-type simulations with IsLeft], size: 6pt)
  cdraw.content((11, 0.85), [FlatMap over error, lazy evaluator frameworks], size: 6pt)
})

== across the six languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [327], [libc plus threads.h], [closures become state structs, the trio specialized to int arrays, fib's counter inside the named struct],
  [c\#], [136], [bcl], [lambdas and generics mirror go, foreach fixed since C\# 5 with the for loop shown beside],
  [go], [92], [stdlib], [frozen reference lane, the generic trio and wrapper, fib's under-2n bound with the 2n-1 exactness landing in the five new trees],
  [javascript], [74], [node stdlib], [var versus let in one file, Map memo with no lock under one realm, private-field fib],
  [python], [167], [stdlib only], [late binding plus the default-argument fix, nonlocal cells, a real lock over the dict cache],
  [lua], [284], [lib.lua harness], [the numeric for never had the trap, the while-loop rebuild, a scheduler lane pinning exactly-once compute],
)

sources: go.dev/doc/go1.22 for per-iteration loop variables and
integer range, go.dev/ref/spec function literals and capture,
go.dev/blog/intro-generics for the type parameter syntax, accessed
2026-09-08. Verified by the six chapter legs: `go test -race` at 7
tests in `patternsbook/ch05`, 4 C programs with 35 embedded checks,
15 C\# facts over `PatternsBook.slnx`, 10 `node --test` cases, 30
Python checks across 4 files, and 18 Lua rows under `run.lua`.
