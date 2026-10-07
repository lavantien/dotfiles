#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= creational patterns

Creation gravitates toward the plain in every tree this book runs. Go
builds a struct literal with named fields, C an aggregate initializer,
java a constructor over plain fields, C\# an object initializer,
javascript and lua a literal object or table, python a call with
keyword arguments, and each form is constructor, builder, and
configuration file in one. The creational
patterns that earn their keep are the ones solving a problem the plain
form cannot express, validating before the value exists, assembling
over several fallible steps, deferring work to first use, or
collapsing duplicates of unbounded input.

== constructors are functions

The `New` prefix convention is the whole factory story for most go
types. A function, unlike a constructor in a class language, can
refuse, and every tree refuses in its own grain, a `(T, error)` pair
in go, a reason string beside an untouched out struct in C, a thrown
exception in java, C\#, javascript, and python, nil with a message in
lua. Nothing stops a type from having several:

#snippet(
  "func NewServer(name string, opts ...Option) (*Server, error)\n"
  + "func NewTLSProxy(name string, cert tls.Certificate) (*Server, error)\n",
  lang: "go",
)

The error return is the part that carries the weight. Class languages
throw from inside a failed constructor. In go the invalid value never
escapes, in C the out parameter is never written, the C options lane
pins a sentinel struct surviving a rejected build untouched, and every
caller handles the failure at the same place it asked for the object.

#flow(
  [a constructor returns the failure instead of throwing from inside],
  node((0, 0), [caller]),
  node((2.7, 0), [NewServer(name, opts)]),
  node((5.6, 0.9), [`*Server`, nil]),
  node((5.6, -0.9), [nil, err]),
  edge((0, 0), (2.7, 0), "-|>"),
  edge((2.7, 0), (5.6, 0.9), "-|>", label: [valid]),
  edge((2.7, 0), (5.6, -0.9), "-|>", label: [invalid never escapes]),
)

== functional options

When a constructor grows past a handful of optional knobs, positional
flags become unreadable and a nil-heavy config struct becomes a second
api. Functional options keep named construction with per-option
validation, one function value per knob that mutates the target or
refuses:

The dry run: the fixture builds one server with `WithTimeout(1s)` and
`WithReadOnly()` and reads timeout 1s beside the untouched default of
3 retries and read only true. The rejected lanes are a negative
timeout and 11 retries, each failing construction with its named
reason wrapped inside the server's name. The go lane's frozen test
pins its own rejection constant, 99 against the same range check,
both verified against the same implementation.

+ Defaults live in one place, timeout 5 seconds and retries 3, and
  each option overrides exactly one field.
+ A rejected option fails the whole build and no partial server
  escapes, while zero retries is an override, the boundary the range
  check draws.

#listing("patterns-concurrency-distributed/samples-c/src/Ch02/options.c", first: 27, last: 73, caption: [C, no closures, an option is an apply function pointer beside its captured argument])

#listing("patterns-concurrency-distributed/samples/ch02/creational.go", first: 20, last: 30, caption: [Go, an option is a closure over one field])

#listing("patterns-concurrency-distributed/samples/ch02/creational.go", first: 46, last: 56, caption: [Go, defaults in one place, options applied in order])

#listing("patterns-concurrency-distributed/samples-java/src/Ch02/Options.java", first: 38, last: 83, caption: [Java, an option is a lambda over the half-built server, null when applied or its rejection reason])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch02/Options.cs", first: 13, last: 58, caption: [C\#, the delegate list mirrors go one to one, each lambda capturing its argument])

#listing("patterns-concurrency-distributed/samples-js/src/ch02-options.mjs", first: 5, last: 35, caption: [JavaScript, arrow closures over one object, the constructor throws on the first refusal])

#listing("patterns-concurrency-distributed/samples-py/src/Ch02/options.py", first: 26, last: 58, caption: [Python, closures validate and raise, new_server wraps the failure with the server name])

#listing("patterns-concurrency-distributed/samples-lua/ch02_options.lua", first: 6, last: 43, caption: [Lua, each option returns nil or a reason, Server folds them and wraps the first refusal])

Each `With` function returns a closure that mutates the target and
reports why it cannot, and `NewServer` seeds the defaults and folds
the options in, so partial application is impossible to get wrong. C
has no closures, so its option is an apply function pointer beside a
pointer to the caller-owned argument, the captured state a closure
would hide written out by hand. C\# mirrors go one to one because a
lambda over the parameter is the same closure, and java is one lane
over: its `Option` is a single-method interface, so the lambda is the
option, returning null when applied or the reason when refusing. The
dynamic three already own cheap named construction, keyword arguments
and object
literals, so what the closure list buys them is the refusal row, one
checked rejection per knob. The alternatives each fail differently,
and knowing how is the tradeoff: config structs accept anything and
validate later, setters allow partially configured intermediates, and
subtypes of a fluent builder duplicate the validation. Options cost
one closure per call site, which is the price of validation at
creation.

#flow(
  [options fold over seeded defaults, one failure aborts the build],
  node((0, 0), [seed defaults,#linebreak()timeout 5s, retries 3]),
  node((2.7, 0), [WithTimeout(1s)]),
  node((5.2, 0), [WithReadOnly()]),
  node((7.4, 0), [`*Server`]),
  edge((0, 0), (2.7, 0), "-|>"),
  edge((2.7, 0), (5.2, 0), "-|>"),
  edge((5.2, 0), (7.4, 0), "-|>"),
  node((2.7, -1.9), [rejected option]),
  node((5.2, -1.9), [(nil, wrapped err),#linebreak()no partial server]),
  edge((2.7, 0), (2.7, -1.9), "-|>", label: [fails]),
  edge((2.7, -1.9), (5.2, -1.9), "-|>"),
)

== builder, when assembly can fail midway

The builder earns its lines only when construction is a genuine
sequence with validation best expressed at the end. The sample
collects issues as it goes and joins them at `Build`, and each tree
joins with its own multi-error spelling:

The dry run: the fixture walks `Method("")` then `URL("ftp://x")`
into one build that fails with a single error naming both the empty
method and the refused url, while a good build lands its method and
url with the unset header and body fields left at zero. The
both-names reading is pinned by the six new trees, the frozen go
test pins that the join exists and that the url reason rides it,
both verified against the same implementation.

+ One error carries every issue, so a caller learns all its mistakes
  in one round trip instead of fixing them one at a time.
+ The steps keep chaining after a recorded issue, header calls still
  ride along, and build stays the single validation point.

#listing("patterns-concurrency-distributed/samples-c/src/Ch02/builder.c", first: 48, last: 91, caption: [C, issues collect in a fixed array, build joins them into one message])

#listing("patterns-concurrency-distributed/samples/ch02/creational.go", first: 90, last: 109, caption: [Go, collect issues, validate once at build])

#listing("patterns-concurrency-distributed/samples-java/src/Ch02/Builder.java", first: 34, last: 66, caption: [Java, the fluent chain collects issues, build joins them with String.join and throws BuildError])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch02/Builder.cs", first: 21, last: 63, caption: [C\#, the fluent chain records strings, build joins them and returns the tuple])

#listing("patterns-concurrency-distributed/samples-js/src/ch02-builder.mjs", first: 5, last: 44, caption: [JavaScript, each step records its Error, build joins the messages and throws])

#listing("patterns-concurrency-distributed/samples-py/src/Ch02/builder.py", first: 29, last: 58, caption: [Python, BuildError carries the issue list, build is the gate that raises it])

#listing("patterns-concurrency-distributed/samples-lua/ch02_builder.lua", first: 13, last: 47, caption: [Lua, issues collect in a table, Build concatenates them after the colon call chain])

`errors.Join` from go 1.20 bundles every complaint into one error.
The siblings spell the same join in their own error idioms,
`String.join` inside a thrown `BuildError` in java, `string.Join`
over the issue list in C\#, `table.concat` in lua, a `BuildError`
carrying every issue in python, arrays of strings in C and message
arrays joined with a newline in javascript. What never varies is the
round trip: all the mistakes, one error, one fix cycle.

#flow(
  [issues accumulate across the steps, build joins them into one round trip],
  node((0, 0), [Method("")]),
  node((2.2, 0), [URL(ftp)]),
  node((4.4, 0), [Build]),
  node((6.6, 0), [one error,#linebreak()both issues named]),
  edge((0, 0), (2.2, 0), "-|>"),
  edge((2.2, 0), (4.4, 0), "-|>"),
  edge((4.4, 0), (6.6, 0), "-|>"),
  node((2.2, -1.9), [issues: empty method, bad url]),
  edge((0, 0), (2.2, -1.9), "-|>", bend: 20deg),
  edge((2.2, 0), (2.2, -1.9), "-|>"),
)

== lazy and once

Lazy creation is `sync.OnceValue` since go 1.21, and it replaced a
page of double checked locking boilerplate with one call. Every tree
has a native once or builds one from a lock: C's `call_once` over a
`once_flag` is the standard's own, the same C23 threads.h discipline
#xref-to("c-os-cloud", "threads") teaches, java ships no
`OnceValue`, so its `Once<T>` is one synchronized method over a done
flag, C\# wraps `Lazy<T>` in `ExecutionAndPublication` mode,
javascript's memo closure needs no lock because one realm runs one
thread, python writes the lock and done flag by hand, and lua drives
an idle, running, done state machine whose overlapping callers park
until the value exists:

The dry run: the parse runs on the first call and never again, and
every later caller reads the same payload, alpha 0, beta 1, gamma 2.
The concurrent half is pinned by the threaded lanes and lua's
scripted overlap, 8 callers in C, 8 more behind a `CyclicBarrier` in
java, 20 racing tasks in C\#, 20 behind a barrier in python, 20
overlapping coroutines in lua, all at exactly one parse.
The frozen go test pins the sequential once-only property, the
concurrent walks and their counting are pinned by the six new
trees.

+ Calls 2 through N replay the identical value, identity pinned
  where the language exposes object identity.
+ Lua keeps the failure on stage, a naive flag that parses once per
  overlapping caller, and C\# pins the once caching its exception
  across 3 calls.

#listing("patterns-concurrency-distributed/samples-c/src/Ch02/lazy.c", first: 27, last: 46, caption: [C, call_once over a once_flag, the payload built under the flag, every caller reads it])

#listing("patterns-concurrency-distributed/samples/ch02/creational.go", first: 111, last: 119, caption: [Go, parse happens on first call, never again, concurrent callers safe])

#listing("patterns-concurrency-distributed/samples-java/src/Ch02/Lazy.java", first: 20, last: 50, caption: [Java, no OnceValue in the jdk, a generic Once whose synchronized call holds a done flag and the value])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch02/Lazy.cs", first: 3, last: 40, caption: [C\#, Lazy in ExecutionAndPublication mode is the bcl once, the counter makes it observable])

#listing("patterns-concurrency-distributed/samples-js/src/ch02-lazy.mjs", first: 5, last: 32, caption: [JavaScript, the memo closure, one thread means a done flag is the whole lock])

#listing("patterns-concurrency-distributed/samples-py/src/Ch02/lazy.py", first: 16, last: 38, caption: [Python, a lock plus done flag, the once python writes by hand])

#listing("patterns-concurrency-distributed/samples-lua/ch02_lazy.lua", first: 61, last: 87, caption: [Lua, idle, running, done, overlapping callers park and wake holding the value])

The seven spellings differ in who owns the hard part: go and C\#
delegate it to the runtime, `OnceValue` and `Lazy<T>`, C carries
`call_once` out of threads.h, java pays a monitor it writes itself,
one `synchronized` on the call, python pays a lock it writes itself,
javascript gets correctness free from the single thread, and lua's
scheduler turns once into a state machine. The replay contract is
identical everywhere, one evaluation, every caller the same value,
or in go and C\# the same panic. Chapter 7 opens the whole family,
`OnceFunc`, `OnceValue`, `OnceValues`, but as a creational tool this
is the singleton go actually endorses: not one global instance of a
type, but one evaluation of a function, scoped to whatever var
holds it.

#diagram([one parse on the first call, every later caller replays the value], length: 13pt, {
  cdraw.line((1, 1), (22, 1), stroke: luma(100))
  cdraw.line((22, 1), (21.6, 1.15), stroke: luma(100))
  cdraw.line((22, 1), (21.6, 0.85), stroke: luma(100))
  cdraw.content((23, 1), [t], size: 6pt)
  cdraw.circle((3.5, 1), radius: 0.14, fill: luma(30))
  cdraw.content((3.2, 1.8), [first call: parse runs], size: 6pt)
  for x in (8, 11.2, 14.4, 17.6) {
    cdraw.circle((x, 1), radius: 0.14, fill: luma(30))
    cdraw.content((x, 0.3), [replay], size: 6pt)
  }
  cdraw.content((14, 1.8), [calls 2..N replay the cached map], size: 6pt)
  cdraw.content((12, -1.0), [one evaluation ever, scoped to the var holding the function], size: 6.5pt)
})

== prototype as an explicit clone

There is no clone protocol in go, no `MemberwiseClone`, no copy
constructor, and none of the six sibling trees ships one either.
The prototype pattern survives as a hand written method, and the
only interesting part is depth:

The dry run: a server clone renamed to core with retries pushed to 9
never leaks back to the original holding edge and 1, and a pool
clone that replaces its first backend and grows the array leaves the
original's 2 entries a and b intact. The value-only clone is plain
assignment or its per-language twin, the reference field is the trap
every lane re-copies by hand.

+ Scalar fields copy with the struct and reference fields share their
  storage, so `Clone` must re-copy each of those or hand out aliased
  state.
+ Java, python, and lua keep the villain on stage, a shallow copy
  whose writes do leak through the shared list or array.

#listing("patterns-concurrency-distributed/samples-c/src/Ch02/prototype.c", first: 26, last: 53, caption: [C, the value struct clones by assignment, the pointer array by hand])

#listing("patterns-concurrency-distributed/samples/ch02/creational.go", first: 158, last: 172, caption: [Go, copy the struct, then fix every reference field by hand])

#listing("patterns-concurrency-distributed/samples-java/src/Ch02/Prototype.java", first: 19, last: 46, caption: [Java, the value class copies field by field, the pool re-copies its list or the two alias it])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch02/Prototype.cs", first: 3, last: 39, caption: [C\#, hand written clones, the list field re-copied into a fresh one])

#listing("patterns-concurrency-distributed/samples-js/src/ch02-prototype.mjs", first: 6, last: 28, caption: [JavaScript, the clone re-creates the object, slice copies the array one level deep])

#listing("patterns-concurrency-distributed/samples-py/src/Ch02/prototype.py", first: 15, last: 35, caption: [Python, the clone method copies scalars and re-copies the list])

#listing("patterns-concurrency-distributed/samples-lua/ch02_prototype.lua", first: 17, last: 45, caption: [Lua, the field loop copies, backends gets its own array, ShallowClone is the villain])

A struct assignment copies the scalar fields and shares the
reference ones, slices, maps, pointers, and the other class trees
meet the same rule one level down: a field-by-field java copy would
alias the same `List`, javascript's spread and slice copy exactly
one level, python's assignment shares every mutable field, and lua's
tables are references. For value shaped types with no
reference fields, plain assignment is the clone and a method is
ceremony, which is why the C lane's server clone is `return *s`.

#diagram([assignment shares the backing cells, clone must allocate fresh ones], length: 13pt, {
  let card(y, title) = {
    cdraw.rect((0, y), (6.4, y + 2.6), fill: luma(235), radius: 0.02)
    cdraw.content((3.2, y + 2.1), title, size: 6.5pt)
    cdraw.content((3.2, y + 1.15), [Name "edge"], size: 6pt)
    cdraw.content((3.2, y + 0.2), [Backends ptr len cap], size: 6pt)
  }
  card(6.4, [p the original])
  card(3.2, [`q := *p`])
  card(0.0, [r := p.Clone()])
  for i in range(3) {
    cdraw.rect((12 + i * 2.2, 5.6), (14 + i * 2.2, 7.0), fill: luma(205), radius: 0.02)
    cdraw.rect((12 + i * 2.2, 0.2), (14 + i * 2.2, 1.6), fill: luma(205), radius: 0.02)
  }
  cdraw.content((17.1, 7.9), [one backing array, p and q both point here], size: 6pt)
  cdraw.content((17.1, -0.7), [fresh cells, r alone points here], size: 6pt)
  cdraw.line((6.4, 6.6), (11.8, 6.4), stroke: luma(100))
  cdraw.line((6.4, 3.4), (11.8, 6.0), stroke: luma(100))
  cdraw.line((6.4, 0.2), (11.8, 0.9), stroke: luma(100))
})

== flyweight through unique

The flyweight, many handles to few shared instances, has a stdlib
implementation since go 1.24: the `unique` package interns comparable
values behind handles that are cheap to compare and safe as map
keys. Every runtime already canonicalizes something, and each lane
picks its own native door, C keeps a canonical pointer per word,
java keeps the first-seen reference in a map so `==` is the handle,
C\# reaches for `string.Intern`, javascript leans on the engine's
own interning with the map value as the handle, python calls
`sys.intern`, and lua's VM interns strings already, so the sample
demonstrates the property through a value keyed table of handle
objects:

The dry run: 100 adds of one long string and 1 of another leave 2
distinct entries with counts 100 and 1, and handle equality mirrors
value equality everywhere.

+ The 100 adds collapse onto one handle, and the per-word counts read
  100 and 1.
+ Equal values share a handle and different values never do, the
  equality the map keys rely on.

#listing("patterns-concurrency-distributed/samples-c/src/Ch02/flyweight.c", first: 21, last: 52, caption: [C, the canonical pointer is the handle, one allocation per distinct word])

#listing("patterns-concurrency-distributed/samples/ch02/creational.go", first: 137, last: 152, caption: [Go, interning strings through globally unique handles])

#listing("patterns-concurrency-distributed/samples-java/src/Ch02/Flyweight.java", first: 18, last: 41, caption: [Java, add returns the first-seen reference, so equal words compare true under ==])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch02/Flyweight.cs", first: 3, last: 24, caption: [C\#, string.Intern makes the handle, ReferenceEquals is its equality])

#listing("patterns-concurrency-distributed/samples-js/src/ch02-flyweight.mjs", first: 5, last: 27, caption: [JavaScript, the string is already the handle, the map counts per value])

#listing("patterns-concurrency-distributed/samples-py/src/Ch02/flyweight.py", first: 16, last: 35, caption: [Python, sys.intern returns the canonical object, dict identity does the rest])

#listing("patterns-concurrency-distributed/samples-lua/ch02_flyweight.lua", first: 6, last: 39, caption: [Lua, a value keyed table hands every equal word one handle object])

`unique.Make` returns the same `Handle[string]` for equal strings,
and the handle comparison is pointer shaped, not string shaped: C
compares canonical pointers, java `==` over the first-seen
references, C\# `ReferenceEquals` over interned strings, python the
`is` operator over interned objects, javascript value equality
because the string already is the handle, lua identity of the one
handle object per word. The cost model
matters: `Make` with a fresh value interns it forever, since the
runtime cannot know when the last handle dies, so this is for long
lived duplicates, plugin names, cache keys, tag sets, not for
unbounded user input. The C lane owns its table and frees it, the
one spelling where the flyweight's lifetime stays the programmer's.
Chapter 14's metrics dedup uses the same trick for label values.

#diagram([equal values converge on one handle, the map holds the distinct few], length: 13pt, {
  cdraw.content((2.6, 6.6), [Make("redis") x 100], size: 6pt)
  cdraw.content((2.6, 4.4), [Make("redis") again], size: 6pt)
  cdraw.content((2.6, 2.2), [Make("postgres") once], size: 6pt)
  cdraw.line((5.4, 6.6), (9.4, 5.75), stroke: luma(100))
  cdraw.line((5.4, 4.4), (9.4, 5.35), stroke: luma(100))
  cdraw.line((5.4, 2.2), (9.4, 2.45), stroke: luma(100))
  cdraw.rect((9.6, 4.6), (16.2, 6.5), fill: luma(205), radius: 0.02)
  cdraw.content((12.9, 6.05), [handle "redis"], size: 6pt)
  cdraw.content((12.9, 5.15), [count 100], size: 6pt)
  cdraw.rect((9.6, 1.5), (16.2, 3.4), fill: luma(205), radius: 0.02)
  cdraw.content((12.9, 2.95), [handle "postgres"], size: 6pt)
  cdraw.content((12.9, 2.05), [count 1], size: 6pt)
  cdraw.content((12.9, 0.2), [interned forever, the runtime cannot see the last handle die], size: 6pt)
})

#callout("note", "when a pattern is a literal", [
  Before reaching for any of the above, check the zero value. A go
  struct usable as `&Server{Name: "edge"}` with the rest zero is a
  design goal, and the sync types are built for it: `Mutex` works
  unzeroed, `bytes.Buffer` works unzeroed, `http.Client` works
  unzeroed. The siblings have their own free starts, field defaults
  in C\#, undefined until assigned in javascript, class attributes in
  python, the empty table in lua, but go is the one that turns the
  stance into a stated rule. The best creational pattern is often a
  constructor that does nothing but document that.
])

#diagram([the zero value already works, the literal finishes it], length: 13pt, {
  cdraw.rect((0, 0), (10, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((5, 3.7), [`&Server{Name: "edge"}`], size: 6.5pt)
  cdraw.content((5, 2.75), [Timeout 0s], size: 6pt)
  cdraw.content((5, 1.8), [Retries 0], size: 6pt)
  cdraw.content((5, 0.85), [ReadOnly false], size: 6pt)
  cdraw.content((5, -0.9), [zero values are valid states, the value works unconfigured], size: 6.5pt)
  cdraw.rect((11.5, 0.6), (22, 3.0), fill: luma(205), radius: 0.02)
  cdraw.content((16.75, 2.4), [the best constructor], size: 6.5pt)
  cdraw.content((16.75, 1.3), [only documents this], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [444], [libc plus threads.h],
  [call_once over once_flag, clones by assignment, references re-copied by hand],
  [go], [132], [stdlib],
  [Option closures, OnceValue lazy, unique.Make hands the flyweight its handle],
  [java], [354], [jdk 27 stdlib],
  [Option lambdas returning null or the reason, a hand-written synchronized Once, first-seen references as handles],
  [c\#], [178], [bcl],
  [delegates returning string?, Lazy at ExecutionAndPublication, Intern handles],
  [javascript], [128], [node stdlib],
  [options mutate and return error or null, the string itself the handle],
  [python], [264], [stdlib only],
  [a Lock under the lazy parse, Barrier(20) exposing the flag race, sys.intern],
  [lua], [399], [lib.lua harness],
  [value-keyed handle table, pool clones re-copy the array so mutations never leak],
)

sources: go.dev/pkg/sync for the `Once` family, go.dev/pkg/unique for
handle semantics and the interning cost note, go.dev/pkg/errors for
`Join`, go.dev/doc/effective_go composite literals, accessed
2026-09-08. Verified by the seven chapter legs: 5 Ch02 C programs
with 64 embedded checks, `go test` at 7 tests in
`patternsbook/ch02`, 5 Ch02 java programs with 35 checks under
`run-java-samples`, 16 xunit facts, node's 12 cases in
`test/ch02.test.mjs`, 5 python modules with 40 embedded checks, and
the lua runner's 21 ch02 rows.
