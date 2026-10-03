#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= functions, scopes, and decorators

A function is an object that carries its own namespace, its own defaults,
and, when it closes over names, a set of cells that outlive the call that
created them. This chapter walks the four load bearing parts: scope
resolution and closures, the parameter grammar with its two markers, the
decorator protocol that makes rebinding a function a one line spelling,
and the functools toolkit built on top. Every claim is pinned by one of
the 37 checks in the four samples on cpython 3.14.7, and the closure
claims are additionally pinned in bytecode by this chapter's expect-dis
file.

== scopes and closures

Name resolution walks one fixed chain: local, then enclosing functions,
then module globals, then builtins. One function in the sample touches
every layer with a single return:

#listing("python/samples/src/Ch06/scopes.py", first: 18, last: 34, caption: [four names, four layers, one tuple proving the walk order])

A name anywhere in a function body makes it local for the whole function
unless a declaration says otherwise, and the two declarations exist
because rebinding is what needs permission, reading is not:

#listing("python/samples/src/Ch06/scopes.py", first: 36, last: 46, caption: [global reaching the module name from inside])

Closures are the enclosing layer's machinery. The inner function keeps a
reference to the cell holding `total`, the cell outlives `make_adder`'s
frame, and mutation through `nonlocal` is visible to everyone sharing the
cell:

#listing("python/samples/src/Ch06/scopes.py", first: 49, last: 64, caption: [capture by reference, the cell readable from outside])

`locals()` inside a function answers a snapshot, not a live view, a rule
PEP 667 made consistent in 3.13:

#listing("python/samples/src/Ch06/scopes.py", first: 67, last: 74, caption: [the snapshot ignoring the later assignment])

The late binding trap and its two fixes close the section, and both fixes
are the same idea, give each function its own binding moment:

#listing("python/samples/src/Ch06/scopes.py", first: 76, last: 92, caption: [three lambdas sharing one cell, the default argument binding early, the factory giving each closure its own])

The counter at lines 95 through 109 is the pattern the expect-dis file
pins: `bump` reads and writes `count` through `LOAD_DEREF` and
`STORE_DEREF`, which is the whole closure mechanism at the bytecode
level. Frames and cells from the interpreter's side are
#xref-to("python", "interpreter").

#callout("pitfall", "loops bind names, not values", [
  A lambda written in a loop captures the loop variable's cell, and the
  cell holds the last value once the loop ends, so `[fn() for fn in
  late]` reads `[2, 2, 2]`. The default argument `index=index` evaluates
  at def time, and the factory function creates a fresh cell per call.
  Both are the same fix: change when the binding happens.
])

#diagram([the legb stack, and the cell a closure carries], length: 13pt, {
  let layer(y, t, sub) = {
    cdraw.rect((0.6, y), (9.4, y + 1.3), fill: luma(235), radius: 0.02)
    cdraw.content((5.0, y + 0.95), t, wrap: text.with(size: 6.5pt))
    cdraw.content((5.0, y + 0.4), sub, wrap: text.with(size: 6pt))
  }
  layer(7.2, [local], [`inner`'s own names, decided at compile time])
  layer(5.7, [enclosing], [cells of functions `inner` was defined in])
  layer(4.2, [global], [the module namespace, `globals()`])
  layer(2.7, [builtins], [`len`, `type`, the interpreter's last answer])
  cdraw.content((5.0, 2.1), [first hit wins, assignment makes a name local for the whole body], wrap: text.with(size: 6pt))
  cdraw.content((15.4, 8.1), [the cell, after return], wrap: text.with(size: 6.5pt))
  cdraw.rect((12.2, 6.4), (18.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((15.4, 7.0), [`total` cell, value 11], wrap: text.with(size: 6pt))
  cdraw.rect((12.2, 4.6), (18.6, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((15.4, 5.2), [`add.__closure__[0]` #linebreak() `.cell_contents`], wrap: text.with(size: 6pt))
  cdraw.line((15.4, 6.4), (15.4, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.2, 2.8), (18.6, 4.0), fill: luma(248), radius: 0.02)
  cdraw.content((15.4, 3.4), [`adder(10)` wrote 11 #linebreak() through `nonlocal`], wrap: text.with(size: 6pt))
  cdraw.line((15.4, 4.6), (15.4, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.4, 2.1), [bytecode: `LOAD_DEREF` and `STORE_DEREF`], wrap: text.with(size: 6pt))
  cdraw.content((15.4, 1.2), [`locals()` in a function: snapshot, pep 667], wrap: text.with(size: 6pt))
})

== arguments

The parameter list has an order and two markers that divide it: `/` ends
the positional-only zone, `*` starts the keyword-only zone:

#listing("python/samples/src/Ch06/args.py", first: 19, last: 28, caption: [one signature with every flavor, and the positional-only refusal])

The error messages are worth reading on this build: `mixed() got some
positional-only arguments passed as keyword arguments: 'a'`. The `*`
marker's refusal lands the same way:

#listing("python/samples/src/Ch06/args.py", first: 31, last: 39, caption: [a required keyword-only argument and its diagnostic])

Packing and unpacking are mirror spellings of the same two markers, one
pair at the def site, the other at the call site:

#listing("python/samples/src/Ch06/args.py", first: 42, last: 58, caption: [packing the extras into args and kwargs, then unpacking a tuple and a dict into a call])

The function object carries its defaults, split by zone, and `inspect`
renders the whole contract back as source-shaped text:

#listing("python/samples/src/Ch06/args.py", first: 60, last: 67, caption: [`__defaults__` and `__kwdefaults__`, and the signature string with both markers])

One argument cannot arrive twice, the last classic:

#listing("python/samples/src/Ch06/args.py", first: 70, last: 78, caption: [positional and keyword naming the same parameter is a TypeError])

The mutable default trap closes the section, the same accident chapter 3
demonstrated from the object side:

#listing("python/samples/src/Ch06/args.py", first: 81, last: 100, caption: [the default list built once, and the None sentinel per call])

#callout("note", "defaults are def time state, and 3.14 added a reserved slot", [
  `__defaults__` is a plain tuple on the function object, built when `def`
  runs, which is why every call without the argument shares one list.
  New in 3.14, `functools.Placeholder` is a sentinel for reserving
  positional slots in `partial` objects, the modern spelling of the
  pass-through-then-fill pattern. Chapter 3's copies sample shows the
  object side of the same trap, see #xref-to("python", "objects").
])

#diagram([the parameter zones of one signature], length: 13pt, {
  let zones = (
    ([positional only], [before `/`, call may not name them]),
    ([positional or keyword], [between `/` and `*`, both spellings work]),
    ([keyword only], [after `*`, the call must name them]),
  )
  for (i, z) in zones.enumerate() {
    let x = 0.6 + i * 7.2
    cdraw.rect((x, 5.8), (x + 6.8, 7.0), fill: luma(205), radius: 0.02)
    cdraw.content((x + 3.4, 6.65), z.at(0), wrap: text.with(size: 6.5pt))
    cdraw.content((x + 3.4, 6.15), z.at(1), wrap: text.with(size: 6pt))
  }
  cdraw.content((4.2, 5.0), [`/`], wrap: text.with(size: 8pt))
  cdraw.content((11.4, 5.0), [`*`], wrap: text.with(size: 8pt))
  cdraw.line((4.2, 5.4), (4.2, 7.4), stroke: luma(140), dash: "dashed")
  cdraw.line((11.4, 5.4), (11.4, 7.4), stroke: luma(140), dash: "dashed")
  cdraw.content((7.8, 8.3), [`mixed(a, b=1, /, c=2, *, d=4)`], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 2.8), (10.2, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 3.4), [def site: `*args` collects extras #linebreak() into a tuple, `**kwargs` collects #linebreak() named extras into a dict], wrap: text.with(size: 6pt))
  cdraw.rect((11.4, 2.8), (21.6, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((16.5, 3.4), [call site: `f(*pair, **keywords)` #linebreak() unpacks them back into arguments], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 1.9), [defaults: `__defaults__` holds (1, 2), `__kwdefaults__` holds the keyword-only ones], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 1.0), [one argument twice is a TypeError: `duplicate(1, a=1)`], wrap: text.with(size: 6pt))
})

== decorators

`@` is sugar. The expression above the `def` runs once, at definition
time, receives the fresh function, and whatever it returns is what the
name binds to:

#listing("python/samples/src/Ch06/decos.py", first: 19, last: 49, caption: [a decorator that only registers, and the same wrapping done by hand])

The manual `shout(plain_greet)` line is the whole protocol with the sugar
removed. Stacking reads bottom up, the decorator nearest the `def`
applies first, and both run at definition time, before any call:

#listing("python/samples/src/Ch06/decos.py", first: 51, last: 70, caption: [the order list proving bottom up application])

Wrapping costs identity, and `functools.wraps` is the standard repair,
copying `__name__`, `__doc__`, and the rest onto the wrapper and keeping
the original reachable as `__wrapped__`:

#listing("python/samples/src/Ch06/decos.py", first: 73, last: 91, caption: [wraps preserving the identity, and `__wrapped__` reaching the original])

A decorator with arguments is one more closure level: the outer function
takes the arguments, returns the decorator, the decorator returns the
wrapper. A stateful decorator keeps its counter in a cell the same way a
closure does:

#listing("python/samples/src/Ch06/decos.py", first: 94, last: 131, caption: [repeat(3) as a three level closure, and a counting decorator])

Nothing requires the decorator to be a function. Any callable works, and
a class instance carrying `__call__` gives the decorator somewhere to
keep state as attributes:

#listing("python/samples/src/Ch06/decos.py", first: 134, last: 151, caption: [a class as decorator, counting calls in an attribute])

The class machinery behind method calls is
#xref-to("python", "classes"), and the two decorator ecosystems built on
this protocol, dataclasses and properties, get their own chapters.

#diagram([a decorated function, from def to call], length: 13pt, {
  cdraw.rect((0.6, 6.6), (6.6, 7.8), fill: luma(205), radius: 0.02)
  cdraw.content((3.6, 7.2), [`def greet` makes the function], wrap: text.with(size: 6pt))
  cdraw.rect((9.6, 6.6), (15.6, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((12.6, 7.2), [applied once, at def time], wrap: text.with(size: 6pt))
  cdraw.line((6.6, 7.2), (9.6, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.6, 6.6), (21.6, 7.8), fill: luma(248), radius: 0.02)
  cdraw.content((20.1, 7.2), [stored], wrap: text.with(size: 6pt))
  cdraw.line((15.6, 7.2), (18.6, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.2, 5.9), [bottom decorator first when stacked], wrap: text.with(size: 6pt))
  cdraw.rect((9.6, 4.0), (15.6, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((12.6, 4.7), [`greet("x")` calls the wrapper], wrap: text.with(size: 6pt))
  cdraw.line((20.1, 6.6), (20.1, 5.6), stroke: luma(100))
  cdraw.line((20.1, 5.6), (15.6, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((1.6, 2.4), (8.4, 3.6), fill: luma(248), radius: 0.02)
  cdraw.content((5.0, 3.0), [wrapper calls the original #linebreak() through `fn(name)`], wrap: text.with(size: 6pt))
  cdraw.line((9.6, 4.4), (8.4, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.0, 1.9), [`wraps` copies `__name__` and `__doc__`, #linebreak() `__wrapped__` holds the original], wrap: text.with(size: 6pt))
  cdraw.content((14.4, 2.4), [with arguments: repeat(3) returns a decorator, #linebreak() one more closure level, state lives in a cell], wrap: text.with(size: 6pt))
  cdraw.content((14.4, 1.2), [classes decorate too: `__call__` plus attributes for state], wrap: text.with(size: 6pt))
})

== the functools toolkit

`partial` freezes a function's arguments into a new callable, positional
or keyword:

#listing("python/samples/src/Ch06/functool.py", first: 19, last: 24, caption: [one keyword frozen, the rest supplied at call time])

`lru_cache` memoizes by arguments and answers with counts, and the
maxsize eviction is visible in the same numbers:

#listing("python/samples/src/Ch06/functool.py", first: 27, last: 37, caption: [a size 2 cache computing fib(10) correctly while evicting])

`fib(10)` recurses through many repeated calls, the cache holds only the
2 most recent arguments at each level, and `cache_info` reports the hits
that the eviction allowed. `cached_property` is the instance level
sibling, computing once and storing the result in the instance dict,
where deleting it forces a recompute:

#listing("python/samples/src/Ch06/functool.py", first: 40, last: 55, caption: [the value landing in `__dict__`, and deletion recomputing])

`singledispatch` routes on the runtime type of the first argument, the
most specific registration wins, and unregistered types fall to the
default:

#listing("python/samples/src/Ch06/functool.py", first: 58, last: 77, caption: [int and bool registrations, with bool winning over its own base class])

`reduce` folds left with a seed, refuses an empty iterable without one,
and is almost never what you want because a builtin or a comprehension
says it better:

#listing("python/samples/src/Ch06/functool.py", first: 79, last: 87, caption: [the fold, the empty refusal, and sum being the answer])

#diagram([the toolkit, what each tool holds and when it pays], length: 13pt, {
  let tools = (
    ([`partial`], [a function plus frozen arguments, #linebreak() a new callable with fewer decisions]),
    ([`lru_cache`], [arguments in, cached answers out, #linebreak() eviction at maxsize, `cache_info` tells all]),
    ([`cached_property`], [compute once, store in the instance dict, #linebreak() delete to invalidate]),
    ([`singledispatch`], [one generic function, #linebreak() implementations selected by runtime type]),
    ([`reduce`], [fold a sequence with a two place function, #linebreak() prefer sum, any, a comprehension]),
  )
  for (i, t) in tools.enumerate() {
    let y = 7.8 - i * 1.7
    cdraw.rect((0.6, y), (6.0, y + 1.4), fill: luma(205), radius: 0.02)
    cdraw.content((3.3, y + 0.7), t.at(0), wrap: text.with(size: 6.5pt))
    cdraw.rect((6.2, y), (21.6, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((13.9, y + 0.7), t.at(1), wrap: text.with(size: 6pt))
  }
  cdraw.content((13.9, 0.1), [all five are ordinary callables and compose with decorators], wrap: text.with(size: 6pt))
})

#callout("verify", "37 checks, first run green, bytecode pinned", [
  All four samples in this chapter ran green on their first execution,
  after the underlying behaviors were probed in scratch scripts, and that
  green is the weakest evidence in the book, which is why the closure
  claims carry a second witness: the expect-dis rows beside the samples
  assert that `make_counter.<locals>.bump` compiles to `LOAD_DEREF`,
  `BINARY_OP`, `STORE_DEREF`, and `RETURN_VALUE`, verified against
  `dis.get_instructions` on this interpreter. If the compiler changed how
  closures are built, that file goes red before any prose drifts. Sample
  behavior verified by `make verify-py`, 37 checks in chapter 6 of the
  samples suite.
])

sources: docs.python.org/3/reference/compound_stmts.html (the def
statement, parameter grammar with `/` and `*`, decorator application),
docs.python.org/3/reference/simple_stmts.html (global, nonlocal, del),
docs.python.org/3/reference/expressions.html (lambda, calls, argument
unpacking),
docs.python.org/3/library/functools.html (partial and the new
Placeholder, lru_cache, cached_property, singledispatch, reduce),
docs.python.org/3/library/inspect.html (signature rendering),
docs.python.org/3/library/stdtypes.html (function attributes
`__defaults__`, `__kwdefaults__`, `__wrapped__`),
docs.python.org/3/whatsnew/3.13.html (PEP 667 locals semantics),
docs.python.org/3/whatsnew/3.14.html (functools.Placeholder), and
peps.python.org/pep-0570/ and pep-0667/, all accessed 2026-09-12; the
error message texts and the dis opnames were probed on this machine the
same day. Sample behavior verified by `make verify-py`, 37 checks in
chapter 6.
