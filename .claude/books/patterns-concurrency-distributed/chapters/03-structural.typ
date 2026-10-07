#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= structural patterns

Structural patterns wire values together, and the wrapper mechanism
is each tree's own. Go's structural interfaces make a wrapper type
declaring the same method set an adapter, decorator, or proxy before
any framework shows up, C folds the same shape into a struct holding
the next function table, java declares the interface once and
implements it on the wrapper side alone, C\# declares the interface
once and implements it on both sides, and the dynamic three wrap duck
typed objects without asking anyone's permission. The wiring is the
cheap
half. The interesting engineering content is what each wrapper owes
its caller, error transparency, ordering, and access control, which
is what the tests in this chapter pin.

== adapter

The adapter exists to satisfy an interface a type cannot be edited to
satisfy, third party code, generated code, or a stable legacy api:

The dry run: the fixture is 72 fahrenheit reading as the exact double
22.22222222222222, byte for byte across the six sibling lanes,
computed as `(f - 32) * 5 / 9` with no epsilon anywhere. The go
lane's frozen test pins its own input, 212 boiling to 100 through a
1e-9 tolerance on its own constant, an anchor the sibling trees pin
beside the shared literal, both verified against the same conversion.

+ The computed quotient equals the printed literal as the same ieee
  double, the exactness the whole section stands on.
+ The legacy side is untouched, its field and accessor unchanged, and
  the adapter is the only new code either side sees.

#listing("patterns-concurrency-distributed/samples-c/src/Ch03/adapter.c", first: 18, last: 31, caption: [C, the adapter embeds the legacy struct and converts through its accessor])

#listing("patterns-concurrency-distributed/samples/ch03/structural.go", first: 14, last: 31, caption: [Go, fahrenheit sensor behind a celsius interface])

#listing("patterns-concurrency-distributed/samples-java/src/Ch03/Adapter.java", first: 19, last: 47, caption: [Java, nominal satisfaction, the adapter implements the new interface, the legacy class never learns it])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch03/Adapter.cs", first: 6, last: 27, caption: [C\#, nominal satisfaction, the adapter declares the interface the legacy type never will])

#listing("patterns-concurrency-distributed/samples-js/src/ch03-adapter.mjs", first: 6, last: 24, caption: [JavaScript, duck typing, anything with a readC method is a celsius reader])

#listing("patterns-concurrency-distributed/samples-py/src/Ch03/adapter.py", first: 16, last: 35, caption: [Python, a runtime checkable Protocol the adapter satisfies and the legacy type does not])

#listing("patterns-concurrency-distributed/samples-lua/ch03_adapter.lua", first: 6, last: 30, caption: [Lua, the adapter carries ReadC, the legacy metatable never learns it])

Because satisfaction is structural, `CelsiusAdapter` needs no
inheritance and `LegacySensor` needs no changes. The adapter owns the
conversion and its error, and the caller sees one interface. In a
class language this pattern needs an interface declaration on both
sides plus an adapter class, in go it is 8 lines, which is why
adapters in go code are usually anonymous local types or function
values, seldom named citizens. C is the same economy with the
function table folded into the struct, java pays the one interface
declaration and proves the legacy side stays outside with an
`instanceof` check in the checks, C\# pays the one interface
declaration and gets the compiler checking both sides, and the
dynamic three never needed permission at all: python's Protocol
checks at run time, javascript's predicate is any caller's, lua's
lookup happens at the call.

#flow(
  [the adapter owns the conversion and its error, neither side changes],
  node((0, 0), [LegacySensor.ReadF,#linebreak()returns 72.0 F]),
  node((3.0, 0), [CelsiusAdapter,#linebreak() (f - 32) x 5 / 9]),
  node((6.0, 0), [CelsiusReader callers,#linebreak()receive 22.2 C]),
  edge((0, 0), (3.0, 0), "-|>", label: [fahrenheit]),
  edge((3.0, 0), (6.0, 0), "-|>", label: [celsius]),
)

== decorator as middleware

The most run decorator in the ecosystem is `net/http` middleware,
because `http.Handler` is a one method interface and a decorator of
it is just a function:

The dry run: one allowed request and one denied request walk the
chain, and the counters read hits 2, denials 1, with the inner
handler executing exactly once and seeing the bearer header. The
denied request never reaches it.

+ Ordering is behavior: with the log outermost, a denied request is
  still counted as a hit, and the token layer's 401 is the response.
+ The fold runs outside in, the first middleware in the list sees the
  request first. C and java pin the swapped order, a denial the log
  never sees, and lua pins the fold order as one, two, three, inner.

#listing("patterns-concurrency-distributed/samples-c/src/Ch03/middleware.c", first: 29, last: 63, caption: [C, a handler is a function pointer plus receiver, a middleware wraps one into another, the state struct is the closure go hides])

#listing("patterns-concurrency-distributed/samples/ch03/structural.go", first: 35, last: 66, caption: [Go, middleware chain: log outermost, token inside, inner handler last])

#listing("patterns-concurrency-distributed/samples-java/src/Ch03/Middleware.java", first: 23, last: 53, caption: [Java, a middleware is a UnaryOperator of Handler, chain folds from the end of the list])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch03/Middleware.cs", first: 6, last: 46, caption: [C\#, delegates all the way down, the chain folds middlewares into one handler])

#listing("patterns-concurrency-distributed/samples-js/src/ch03-middleware.mjs", first: 6, last: 30, caption: [JavaScript, next => req => arrows, the shape its frameworks made famous])

#listing("patterns-concurrency-distributed/samples-py/src/Ch03/middleware.py", first: 25, last: 52, caption: [Python, closures nested three deep, the chain folds with reversed])

#listing("patterns-concurrency-distributed/samples-lua/ch03_middleware.lua", first: 7, last: 38, caption: [Lua, closures returning closures, Chain counts down to fold outside in])

`Chain` folds the list outside in, so the first middleware in the
slice sees the request first, and every language above writes the
same fold with its own function-value grain: C writes the closure by
hand as a state struct beside the function pointer, java stacks
lambdas through `UnaryOperator<Handler>`, C\# composes delegates,
javascript stacks arrow closures, python nests three closures, lua
returns closures from closures. `http.HandlerFunc` is
the adapter from function to interface in the same stroke, the
stdlib's own demonstration of chapter 1. This shape generalizes past
http: any single method interface, `io.Reader`, `CelsiusReader`, a
project's `Store`, can grow decorators the same way, and `Chain` is
the whole framework.

#flow(
  [the chain folds outside in, a denial is still a counted hit],
  node((0, 0), [request]),
  node((2.4, 0), [WithAccessLog,#linebreak()counts the hit]),
  node((4.8, 0), [WithToken,#linebreak()allows or denies]),
  node((7.2, 0), [handler]),
  edge((0, 0), (2.4, 0), "-|>"),
  edge((2.4, 0), (4.8, 0), "-|>"),
  edge((4.8, 0), (7.2, 0), "-|>"),
  edge((4.8, 0), (0, 0), "-|>", bend: 35deg, label: [denied: handler untouched, hit kept]),
)

== facade

A facade collapses a multi step subsystem into one call without
hiding the steps' failures:

The dry run: each failing step surfaces with its step name, the
fetch wrap carrying the url, parse and validate naming themselves,
and the happy path returning the parsed items a, b, c. The frozen go
test pins the fetch wrap, the parse and validate step names are
pinned by the six new trees, both against the same implementation.

+ One call, three injected steps, fetch, parse, validate, each a
  strategy object from chapter 4 in miniature.
+ Every failure is attributable to its step, the url riding the fetch
  wrap and the cause readable inside it.

#listing("patterns-concurrency-distributed/samples-c/src/Ch03/facade.c", first: 61, last: 88, caption: [C, step function pointers in a struct, load wraps each failure with its step name])

#listing("patterns-concurrency-distributed/samples/ch03/structural.go", first: 68, last: 93, caption: [Go, three injected steps, one wrapped error surface])

#listing("patterns-concurrency-distributed/samples-java/src/Ch03/Facade.java", first: 27, last: 72, caption: [Java, three single-method interfaces injected, load rethrows each failure prefixed with its step])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch03/Facade.cs", first: 3, last: 32, caption: [C\#, three delegates injected, Load prefixes each failure with its step])

#listing("patterns-concurrency-distributed/samples-js/src/ch03-facade.mjs", first: 4, last: 31, caption: [JavaScript, each try wraps a new Error with cause, the step name in the message])

#listing("patterns-concurrency-distributed/samples-py/src/Ch03/facade.py", first: 35, last: 53, caption: [Python, raise from chains the cause, the step name in the new message])

#listing("patterns-concurrency-distributed/samples-lua/ch03_facade.lua", first: 5, last: 26, caption: [Lua, nil plus a step prefixed message, the cause concatenated])

The three function fields are injected at construction. `Load` adds
the only logic the caller actually wants, sequence plus error
wrapping with `%w`, the wrapping chain #xref-to("go", "errors")
grounds, so a failure is attributable to its step and matchable
downstream. The siblings wrap in their own idiom: C returns the
prefixed reason through an error buffer, java catches the `StepError`
and rethrows a new one carrying the prefix, C\# composes the string,
javascript chains `Error` with `cause`, python raises `from` the
caught step, lua concatenates onto `nil`. What every lane keeps is
attribution, the caller learning which step failed without learning
the subsystem's internals.

#flow(
  [one call, three injected steps, every failure wrapped with its step],
  node((0, 0), [Load]),
  node((2.2, 0), [fetch,#linebreak()fetch %w]),
  node((4.4, 0), [parse,#linebreak()parse %w]),
  node((6.6, 0), [validate,#linebreak()validate %w]),
  node((8.6, 0), [items]),
  edge((0, 0), (2.2, 0), "-|>"),
  edge((2.2, 0), (4.4, 0), "-|>"),
  edge((4.4, 0), (6.6, 0), "-|>"),
  edge((6.6, 0), (8.6, 0), "-|>"),
)

== composite

The composite pattern is recursive satisfaction: leaf and container
implement the same interface, and the container aggregates children
by asking each one:

The dry run: the leaves measure hi 2, ok 2, and wide! 5, the row
sums its children to 4, the stack maxes to 5, and containers nest to
any depth. The go lane's frozen test pins its own widget counts,
save and cancel composing to 10 and 12, both verified against the
same recursion.

+ Leaf and container answer the same one question, and nesting is
  free, a row inside a stack inside a row keeps summing and maxing.
+ Java, python, and lua pin the empty container as width 0, an
  absence every lane treats as a value.

#listing("patterns-concurrency-distributed/samples-c/src/Ch03/composite.c", first: 20, last: 69, caption: [C, one width slot in the struct, row and stack dispatch through it recursively])

#listing("patterns-concurrency-distributed/samples/ch03/structural.go", first: 95, last: 123, caption: [Go, label is a leaf, row sums, stack maxes, nesting is free])

#listing("patterns-concurrency-distributed/samples-java/src/Ch03/Composite.java", first: 19, last: 58, caption: [Java, a record Label and two container classes, one width method over them all])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch03/Composite.cs", first: 5, last: 49, caption: [C\#, the interface on leaf and container alike, children as IReadOnlyList])

#listing("patterns-concurrency-distributed/samples-js/src/ch03-composite.mjs", first: 4, last: 38, caption: [JavaScript, classes with the one method, the consumer never asks which kind])

#listing("patterns-concurrency-distributed/samples-py/src/Ch03/composite.py", first: 14, last: 35, caption: [Python, sum and max do the aggregation, the default handles the empty stack])

#listing("patterns-concurrency-distributed/samples-lua/ch03_composite.lua", first: 6, last: 40, caption: [Lua, tagged tables and one recursive Width function])

`Row` and `Stack` hold `[]Widget`, which can contain further rows and
stacks, and the recursion bottoms out at `Label` with no type
switches anywhere. The seven spellings differ only in how the one
method is found, a function pointer slot in the C struct, an
interface method in go, java, and C\#, a method on the class in the
dynamic three, with lua collapsing the whole pattern into one
recursive function over tagged tables. Tree shaped problems, layout,
ASTs,
file systems, config merges, all take this shape, and the alternative
in class languages, a visitor with double dispatch, is chapter 4's
type switch instead.

#flow(
  [leaves and containers share one method, widths compose recursively],
  node((2.0, 2.2), [Stack, width 5]),
  node((0.8, 0.9), [Row, sum 4]),
  node((3.4, 0.9), [Label wide!, 5]),
  node((0, -0.6), [Label hi, 2]),
  node((1.8, -0.6), [Label ok, 2]),
  edge((2.0, 2.2), (0.8, 0.9), "-|>"),
  edge((2.0, 2.2), (3.4, 0.9), "-|>"),
  edge((0.8, 0.9), (0, -0.6), "-|>"),
  edge((0.8, 0.9), (1.8, -0.6), "-|>"),
)

== proxy

A proxy stands in front of a real object and controls access or adds
caching, and the distinction from decorator is intent: a decorator
adds behavior the caller asked for, a proxy interposes policy the
caller cannot bypass:

The dry run: a forbidden key fails with the sentinel and the real
store's call counter stays at 0, and a permitted key fetched twice
costs exactly 1 real call while the cache holds 1 entry.

+ Policy first, cache second: the guard runs before any lookup, so
  an unpermitted key never reaches the store and its error wraps the
  sentinel with the key.
+ The permitted key pays the real store once, the second read is the
  cache. C, java, C\#, python, and lua also pin a permitted key the
  store lacks surfacing the store's own error uncached.

#listing("patterns-concurrency-distributed/samples-c/src/Ch03/proxy.c", first: 53, last: 101, caption: [C, the allow list gates, the cache rides a mutex, only permitted misses pay the store])

#listing("patterns-concurrency-distributed/samples/ch03/structural.go", first: 127, last: 177, caption: [Go, permission gate in front, memoization behind])

#listing("patterns-concurrency-distributed/samples-java/src/Ch03/Proxy.java", first: 35, last: 81, caption: [Java, Forbidden and NotFound keep C's literal messages, the guard runs before the synchronized cache])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch03/Proxy.cs", first: 27, last: 66, caption: [C\#, the forbidden constant, the lock object, the cache dictionary beside it])

#listing("patterns-concurrency-distributed/samples-js/src/ch03-proxy.mjs", first: 5, last: 44, caption: [JavaScript, the sentinel as a shared Error instance carried as cause])

#listing("patterns-concurrency-distributed/samples-py/src/Ch03/proxy.py", first: 16, last: 56, caption: [Python, Forbidden and NotFound types, a lock around the cache])

#listing("patterns-concurrency-distributed/samples-lua/ch03_proxy.lua", first: 6, last: 49, caption: [Lua, the guard consults the allow table, the cache is a plain table])

`ErrForbidden` is a sentinel, wrapped with the key so callers can
match it with `errors.Is` while still reading which key failed. The
siblings match in their own idiom, the exception types in java,
C\#, and python, the shared `Error` instance through `cause` in
javascript, the message text in C and lua. The memo map is guarded
by a mutex
because proxies at api boundaries see concurrent callers, the
locking rules of chapter 7 applied where they matter, and the
single-threaded lanes need no lock at all. The test pins the
contract from the outside: a forbidden key never reaches the real
store, the underlying call counter stays at zero, and a permitted
key fetched twice costs one underlying call.

#flow(
  [proxy get: policy first, cache second, real store last],
  node((0, 0), [Get(key)]),
  node((2.0, 0), [allowed?]),
  node((4.4, 1.4), [ErrForbidden,#linebreak()wrapped with the key]),
  node((4.4, 0), [cached?]),
  node((6.8, 0.7), [return memo]),
  node((6.8, -0.9), [RealStore.Get,#linebreak()store under mutex]),
  edge((0, 0), (2.0, 0), "-|>"),
  edge((2.0, 0), (4.4, 1.4), "-|>", label: [no]),
  edge((2.0, 0), (4.4, 0), "-|>", label: [yes]),
  edge((4.4, 0), (6.8, 0.7), "-|>", label: [yes]),
  edge((4.4, 0), (6.8, -0.9), "-|>", label: [no]),
)

The cache invalidation problem is deliberately absent, the proxy
caches forever for the sample's lifetime, and that boundary is the
tradeoff a real deployment pays to name: ttl, explicit
invalidation, or versioned keys, each of which turns this proxy into
a subsystem of its own.

#callout("pitfall", "wrapper transparency is a contract", [
  Every wrapper in this chapter forwards errors with `%w` and
  preserves the wrapped type's semantics. The moment a decorator
  swallows an error or a proxy rewrites a value it did not fetch
  itself, the caller's `errors.Is` and `errors.As` chains break
  silently. Wrapping code is trusted code. The sibling idioms carry
  the same duty, the rethrown exception type in java,
  `InnerException` in C\#, `cause` in javascript, `raise from` in
  python, the concatenated message in C and lua.
])

#flow(
  [wrapping with %w at every hop keeps the errors.is chain intact],
  node((-1.4, 0.3), [faithful]),
  node((0, 1.5), [caller]),
  node((2.2, 1.5), [proxy, %w]),
  node((4.4, 1.5), [decorator, %w]),
  node((6.6, 1.5), [sentinel,#linebreak()errors.Is true]),
  edge((0, 1.5), (2.2, 1.5), "-|>"),
  edge((2.2, 1.5), (4.4, 1.5), "-|>"),
  edge((4.4, 1.5), (6.6, 1.5), "-|>"),
  node((-1.4, -2.1), [broken]),
  node((0, -0.9), [caller]),
  node((2.2, -0.9), [proxy, %w]),
  node((4.4, -0.9), [swallows or rewrites]),
  node((6.6, -0.9), [new error,#linebreak()errors.Is false]),
  edge((0, -0.9), (2.2, -0.9), "-|>"),
  edge((2.2, -0.9), (4.4, -0.9), "-|>"),
  edge((4.4, -0.9), (6.6, -0.9), "-|>"),
)

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [454], [libc plus threads.h],
  [composite widths through vtable slots, only the proxy cache takes a mutex],
  [go], [142], [stdlib],
  [Middleware as func(http.Handler) http.Handler, sentinels wrapped for errors.Is],
  [java], [359], [jdk 27 stdlib],
  [UnaryOperator folds the middleware chain, Forbidden and NotFound keep C's literal messages],
  [c\#], [184], [bcl],
  [leaf and Row share Widget, forbidden and missing surface as exception types],
  [javascript], [136], [node stdlib],
  [chain folds a(b(inner)), the sentinel a shared Error carried as cause],
  [python], [247], [stdlib only],
  [typed exceptions matched at the boundary, the proxy cache under a lock],
  [lua], [380], [lib.lua harness],
  [the allow table gates, plain-table cache, errors matched by message text],
)

sources: go.dev/pkg/net/http for `HandlerFunc` and middleware
conventions, go.dev/pkg/errors for sentinel wrapping with `Is`,
go.dev/doc/effective_go embedding for why none of these wrappers need
inheritance, accessed 2026-09-08. Verified by the seven chapter legs:
5 Ch03 C programs with 31 embedded checks, `go test` at 5 tests in
`patternsbook/ch03`, 5 Ch03 java programs with 33 checks under
`run-java-samples`, 14 xunit facts, node's 8 cases in
`test/ch03.test.mjs`, 5 python modules with 36 embedded checks,
and the lua runner's 21 ch03 rows.
