#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "../../theme/xref.typ": xref-to
#import "@preview/fletcher:0.5.8": node, edge

= behavioral patterns

Behavioral patterns distribute responsibility between objects. In go
the first draft of every one of them is a function value, because a
function is an object that carries behavior, compares against nil,
and slots into fields and parameters. The chapter builds the six
that survive translation, strategy, observer, command, iterator,
state, and visitor, and each section runs one shared fixture through
c, c\#, go, javascript, python, and lua, the dry-run block stating
the contract before the six listings.

== strategy

A strategy is a named function type with one implementation per
algorithm, and selection becomes a lookup:

The dry run: the fixture is aaabbc packing to the byte and count
pairs (97,3)(98,2)(99,1), the empty input encoding to nothing, a
single a to (97,1), and the 257 run splitting at the count byte's
255 cap into (122,2)(113,255)(113,2). The null strategy passes its
input through untouched and an unknown name fails selection. The go
lane's frozen test pins its own string, aaabbb to two pairs, both
verified against the same implementation.

+ aaabbc walks 3 runs, and each pair carries the byte value beside
  its count.
+ A run longer than 255 cannot fit its count byte, so zz followed
  by 257 q's splits into 2, 255, and 2, the cap every lane pins.
+ Selection hands back the function value itself, and the unknown
  name is an error in each language's own error idiom.

#listing("patterns-concurrency-distributed/samples-c/src/Ch04/strategy.c", first: 21, last: 61, caption: [C, a function pointer typedef, rle capping runs at 255, selection from a name table])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch04/Strategy.cs", first: 4, last: 38, caption: [C\#, a delegate type, rle and null as static values, the error riding a tuple])

#listing("patterns-concurrency-distributed/samples/ch04/behavioral.go", first: 12, last: 40, caption: [Go, compression as a function type, rle and null as values])

#listing("patterns-concurrency-distributed/samples-js/src/ch04-strategy.mjs", first: 6, last: 33, caption: [JavaScript, plain functions as values, selection throws on the unknown name])

#listing("patterns-concurrency-distributed/samples-py/src/Ch04/strategy.py", first: 13, last: 41, caption: [Python, first class functions, selection raises UnknownCompression])

#listing("patterns-concurrency-distributed/samples-lua/ch04_strategy.lua", first: 6, last: 34, caption: [Lua, function values in a table, the nil plus message refusal])

Function types give the pattern for free: `Compression` is
documented, comparable to nil, and the caller passes `Rle` like any
value. The sibling trees say the same thing in their own spelling.
C writes a function pointer typedef and answers the unknown name
with NULL, C\# uses a delegate with the refusal riding a tuple,
javascript and python pass functions natively and signal refusal by
throwing and raising, and lua looks the name up in a table and hands
back nil with a message. When strategies need configuration or
state, they become closures, chapter 5's territory.

#diagram([selection is data, a lookup from name to function value], length: 13pt, {
  cdraw.rect((0, 1.0), (7, 4.2), fill: luma(235), radius: 0.02)
  cdraw.rect((9, 1.0), (16, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 4.8), [name], size: 6.5pt)
  cdraw.content((12.5, 4.8), [Compression value], size: 6.5pt)
  cdraw.content((3.5, 3.6), ["rle"], size: 6pt)
  cdraw.content((12.5, 3.6), [Rle], size: 6pt)
  cdraw.content((3.5, 2.55), ["null"], size: 6pt)
  cdraw.content((12.5, 2.55), [Null], size: 6pt)
  cdraw.content((3.5, 1.5), [anything else], size: 6pt)
  cdraw.content((12.5, 1.5), [error], size: 6pt)
  cdraw.line((5.6, 3.6), (10.4, 3.6), stroke: luma(100))
  cdraw.line((5.6, 2.55), (10.4, 2.55), stroke: luma(100))
  cdraw.line((5.6, 1.5), (10.4, 1.5), stroke: luma(100))
})

== observer with channels

Book 3 toured the channel syntax#xref-to("go", "concurrency"), and
the observer pattern is where channels earn a salary. Subscribers
receive buffered channels, the hub's `Notify` is non-blocking with a
`select` default, and `Close` releases everyone:

#callout("note", "the base layer", [
  Three channel facts this dry run stands on, rules chapter 6 lays
  in full: a buffered channel of capacity C holds C values before a
  further send must wait, a send on a full channel inside a `select`
  with a default takes the default and drops the event instead of
  blocking, and a closed channel keeps its buffered values, drain
  first, then the closed read.
])

The dry run: the fixture is a fast subscriber with buffer 2 and a
slow one with buffer 1. Two notifies deliver 2 then 1, the fast
subscriber taking both events while the slow keeps its one, the
third notify lands nowhere, and after `Close` the slow subscriber
still drains its buffered event before reading the channel as
closed.

+ The first notify reaches both subscribers and the second fills the
  fast buffer while the slow one drops it, delivered counts 2 then 1.
+ The third notify is dropped everywhere because both buffers are
  full, and the producer never waits.
+ Close marks every channel closed without erasing buffers, so the
  lagging subscriber drains its one event, then reads closed.

#listing("patterns-concurrency-distributed/samples-c/src/Ch04/observer.c", first: 77, last: 94, caption: [C, subscribe under the hub mutex, cancel marks one subscriber closed])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch04/Observer.cs", first: 17, last: 46, caption: [C\#, Subscribe returns a bounded reader and its cancel, Remove completes the writer])

#listing("patterns-concurrency-distributed/samples/ch04/behavioral.go", first: 42, last: 68, caption: [Go, hub: subscribe returns a channel and its cancel function])

#listing("patterns-concurrency-distributed/samples-js/src/ch04-observer.mjs", first: 12, last: 29, caption: [JavaScript, subscribe returns a queue record and its cancel closure])

#listing("patterns-concurrency-distributed/samples-py/src/Ch04/observer.py", first: 45, last: 69, caption: [Python, subscribe hands back a Subscription, unsubscribe releases it])

#listing("patterns-concurrency-distributed/samples-lua/ch04_observer.lua", first: 33, last: 51, caption: [Lua, Subscribe returns the sub and a double-call-safe cancel])

Registration is the quieter half of the pattern, and the notify half
carries the two contract points the tests pin:

#listing("patterns-concurrency-distributed/samples-c/src/Ch04/observer.c", first: 46, last: 64, caption: [C, try-send into each bounded buffer, a full one drops])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch04/Observer.cs", first: 48, last: 80, caption: [C\#, TryWrite is the drop, Complete is the close])

#listing("patterns-concurrency-distributed/samples/ch04/behavioral.go", first: 80, last: 104, caption: [Go, non-blocking fan-out, then close on shutdown])

#listing("patterns-concurrency-distributed/samples-js/src/ch04-observer.mjs", first: 31, last: 47, caption: [JavaScript, notify walks the queues, close flips every one])

#listing("patterns-concurrency-distributed/samples-py/src/Ch04/observer.py", first: 55, last: 73, caption: [Python, notify counts deliveries, close releases without erasing])

#listing("patterns-concurrency-distributed/samples-lua/ch04_observer.lua", first: 55, last: 74, caption: [Lua, Notify skips closed subs, Close marks them all])

Dropping is deliberate: a slow subscriber with a full buffer loses
the event instead of blocking the producer, the drop policy of
last resort, and the alternatives, infinite buffers, blocking sends,
one goroutine per subscriber, are chapter 8's fan-in fan-out
discussion. And `close` does not erase buffered values: a subscriber
that lags behind shutdown still drains what it was sent, which the
test asserts by draining `slow` after `Close` and finding its one
buffered event.

The cancel function returned from `Subscribe` is the registration
lifecycle made explicit, the caller owns unsubscription and double
cancel is safe because `remove` checks the map first. The sibling
trees build the channel by hand where they must: C keeps a fixed
array of bounded subscriber buffers under one mutex, C\# hands each
subscriber a real bounded Channel where `TryWrite` stands in for the
select default, javascript pushes onto plain arrays inside a Map
whose insertion order fixes delivery order, python's Subscription
answers takes with a value, a closed marker, or a BLOCKED sentinel
naming where a goroutine would park, and lua keeps one table per
subscriber with its own bounded buffer.

#diagram([notify is a non-blocking fan-out, slow subscribers drop, close preserves buffers], length: 13pt, {
  cdraw.rect((0, 2.4), (5.6, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((2.8, 3.75), [hub.Notify], size: 6.5pt)
  cdraw.content((2.8, 2.85), [walk the subs], size: 6pt)
  cdraw.rect((8, 5.0), (15, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 6.35), [sub1, room in buffer], size: 6pt)
  cdraw.content((11.5, 5.45), [send lands], size: 6pt)
  cdraw.rect((8, 2.4), (15, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 3.75), [sub2, buffer full], size: 6pt)
  cdraw.content((11.5, 2.85), [default: drop], size: 6pt)
  cdraw.rect((8, -0.2), (15, 1.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 1.15), [sub3, room in buffer], size: 6pt)
  cdraw.content((11.5, 0.25), [send lands], size: 6pt)
  cdraw.line((5.6, 3.6), (8, 5.6), stroke: luma(100))
  cdraw.line((5.6, 3.3), (8, 3.3), stroke: luma(100))
  cdraw.line((5.6, 3.0), (8, 0.7), stroke: luma(100))
  cdraw.content((11.5, -1.2), [close releases everyone, a lagging subscriber still drains what it buffered], size: 6pt)
})

== command with undo

A command object captures an operation and its inverse. In go the
operation is a closure and the inverse is captured alongside:

The dry run: the fixture walk sets one key to 7, then to 9, and undo
restores 7, undo again removes the key, and undo on the spent
history reports false. Interleaved keys replay newest first. The go
lane's frozen test walks its own constants, retries 3 then 5 beside
mode 1, against the same implementation.

+ Set captures the previous value and whether the key existed, so
  the undo of an overwrite is a restore and the undo of an insert
  is a delete.
+ Undo pops the history last in first out and replays the inverse
  it finds there.
+ The history is a stack of captures, one per command, not a diff
  per key, which the interleaved walk pins.

#listing("patterns-concurrency-distributed/samples-c/src/Ch04/command.c", first: 43, last: 90, caption: [C, explicit undo records in a fixed array, undo restores or deletes])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch04/Command.cs", first: 5, last: 36, caption: [C\#, each Set pushes a restoring closure, Undo pops and runs it])

#listing("patterns-concurrency-distributed/samples/ch04/behavioral.go", first: 107, last: 136, caption: [Go, set records the previous value, undo pops and replays it])

#listing("patterns-concurrency-distributed/samples-js/src/ch04-command.mjs", first: 5, last: 31, caption: [JavaScript, the undo stack holds closures over existed and prev])

#listing("patterns-concurrency-distributed/samples-py/src/Ch04/command.py", first: 14, last: 36, caption: [Python, the history is a list of key, prev, existed tuples])

#listing("patterns-concurrency-distributed/samples-lua/ch04_command.lua", first: 9, last: 39, caption: [Lua, Set's closure captures prev and existed for Undo])

The `Set` method closes over `prev` and `existed`, so the undo of an
insert is a delete and the undo of an overwrite is a restore. The
test walks all three cases. Five of the six trees capture that
inverse as a closure or a tuple, and C stores explicit undo records
in a fixed array because it has no closures to capture anything,
the same trade its strategy listing made. This is also the seed of
the raft capstone's restart story: a write ahead log is a command
history, replay is redo, and chapter 11 returns to the equivalence
as idempotent re-delivery, chapter 16 as replay on restart.

#diagram([set captures the inverse, undo pops the stack and replays it], length: 13pt, {
  cdraw.content((2.6, 4.0), [Set("user", 7)], size: 6pt)
  cdraw.content((2.6, 6.3), [Set("user", 9)], size: 6pt)
  cdraw.line((4.8, 4.0), (7.6, 4.3), stroke: luma(100))
  cdraw.line((4.8, 6.3), (7.6, 5.7), stroke: luma(100))
  cdraw.rect((7.8, 4.8), (15, 6.1), fill: luma(235), radius: 0.02)
  cdraw.content((11.4, 5.45), [restore user = 7], size: 6pt)
  cdraw.rect((7.8, 3.3), (15, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.4, 3.95), [delete "user"], size: 6pt)
  cdraw.content((11.4, 2.6), [the undo stack], size: 6.5pt)
  cdraw.content((18.6, 5.45), [Undo()], size: 6.5pt)
  cdraw.line((17.4, 5.45), (15.2, 5.45), stroke: luma(100))
  cdraw.content((11.4, 1.3), [a write ahead log is this stack persisted, replay is redo], size: 6pt)
})

== iterator, push style

Go 1.23 grew iterators into the language: `range` accepts functions
of type `func(yield func(V) bool)`, and the `iter` package names
them. The pattern is a function that calls `yield` for each element
and stops the moment `yield` returns false:

The dry run: the fixture is the pangram the quick brown fox jumps
over the lazy dog. Filtering words longer than 3 keeps quick, brown,
jumps, over, lazy, sorting by length replays over, lazy, quick,
brown, jumps with ties keeping source order, and early exit takes
exactly the first two, quick and brown. The source observes the stop
after offering exactly 3 words, the, quick, and brown. The go lane's
frozen test pins the filtered set, the stable sort, and the first
two, the offered-count stop probe is the five new trees' lane.

+ The consumer's break makes yield return false, and the false
  verdict unwinds Filter into the source, which stops where it
  stands after 3 offers, not 9.
+ Sorted materializes once, a full drain of all 9 words before the
  first replay.
+ The stability pin: over and lazy tie at 4 letters and keep source
  order, so the adapter never scrambles its input's tie order.

#listing("patterns-concurrency-distributed/samples-c/src/Ch04/iterator.c", first: 35, last: 61, caption: [C, the source drives a yield callback, a false verdict stops it])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch04/Iterator.cs", first: 8, last: 43, caption: [C\#, yield return words, Filter stays lazy, Sorted materializes below])

#listing("patterns-concurrency-distributed/samples/ch04/behavioral.go", first: 139, last: 177, caption: [Go, words as a sequence, filter and sorted as sequence adapters])

#listing("patterns-concurrency-distributed/samples-js/src/ch04-iterator.mjs", first: 8, last: 29, caption: [JavaScript, generator functions, the finally block observes the stop])

#listing("patterns-concurrency-distributed/samples-py/src/Ch04/iterator.py", first: 14, last: 43, caption: [Python, generators, close runs the finally, ordered_by drains once])

#listing("patterns-concurrency-distributed/samples-lua/ch04_iterator.lua", first: 7, last: 53, caption: [Lua, a sequence is a function over a yield callback, sort stability by index tiebreak])

`Filter` and `Sorted` are decorators for sequences, chapter 3's idea
with the language doing the wrapping. `Sorted` materializes once and
uses `SortStableFunc`, because a plain unstable sort reorders equal
elements and an adapter that scrambles its input's tie order is a
surprise factory, the sample's own test caught exactly that before
the fix. Early exit works through the chain: a `break` in the
caller's range loop makes `yield` return false, `Filter`'s inner
walk sees it and unwinds, and the test takes the first two words and
stops.

The sibling trees split by what the language gives them. C\# and
python grow push iterators natively as `yield return` and
generators, the interpreter pausing the function at each
yield#xref-to("python", "collections"). Javascript generators do the
same and add the honest probe: closing the generator runs its
`finally` block, so the source's stop observation is a language
guarantee.

Lua's push sequence is a function that feeds a yield callback, and
`coroutine.wrap` gives the same iteration shape natively over
cooperative threads#xref-to("lua", "coroutines"). C has neither
closures nor generators, so the yield callback carries a context
pointer and the consumer's verdict is its return value, and the
sorted adapter breaks ties by source index because the platform sort
is unstable.

For pull-style iteration, `iter.Pull` converts a sequence into
`next, stop` functions for loops that are not shaped like for
statements, consuming from two sequences in lockstep being the
canonical case.

#flow(
  [adapters wrap sequences, early exit unwinds the whole chain],
  node((0, 0), [Words,#linebreak()yields each]),
  node((2.4, 0), [Filter,#linebreak()a decorator]),
  node((4.8, 0), [Sorted,#linebreak()materializes once]),
  node((7.4, 0), [range loop]),
  edge((0, 0), (2.4, 0), "-|>"),
  edge((2.4, 0), (4.8, 0), "-|>"),
  edge((4.8, 0), (7.4, 0), "-|>"),
  edge((7.4, 0), (0, 0), "-|>", bend: 35deg, label: [break makes yield return false]),
)

== state as a transition table

A state machine is a map keyed by state and event, holding the next
state and an action, and firing an event is one lookup:

The dry run: the fixture walk fires coin, push, coin, coin, push,
kick from the locked gate, and the outcomes pin row by row as
(unlocked, thanks), (locked, click), (unlocked, thanks),
(unlocked, thanks), (locked, click), and (rejected, locked). The log
records the 5 accepted actions and skips the kick. The go lane's
frozen test walks its own script, kick, push, coin, push, with the
log alarm, thanks, click, against the same table.

+ The table holds 4 real transitions, 2 states by 2 events, and the
  whole machine reads at a glance.
+ The unknown event is rejected without moving the state and without
  logging, so rejection costs nothing.
+ The action log doubles as the observable output, which makes the
  walk a pinned sequence instead of a print.

#listing("patterns-concurrency-distributed/samples-c/src/Ch04/state.c", first: 30, last: 67, caption: [C, the table as a 2d array of transitions, fire is one row lookup])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch04/State.cs", first: 20, last: 53, caption: [C\#, nested dictionaries, Fire moves and logs])

#listing("patterns-concurrency-distributed/samples/ch04/behavioral.go", first: 179, last: 231, caption: [Go, turnstile: two states, two events, four transitions, all visible at once])

#listing("patterns-concurrency-distributed/samples-js/src/ch04-state.mjs", first: 8, last: 27, caption: [JavaScript, a Map keyed by the state and event pair])

#listing("patterns-concurrency-distributed/samples-py/src/Ch04/state.py", first: 14, last: 33, caption: [Python, a dict keyed by state and event tuples])

#listing("patterns-concurrency-distributed/samples-lua/ch04_state.lua", first: 11, last: 42, caption: [Lua, nested tables, and a swapped table is a different machine])

The table makes the whole machine inspectable at a glance, which is
the entire argument for it over a switch per state. Unknown events
are rejected without a transition, and the log of actions doubles as
the observable output. The spelling of the key tracks the language:
a 2d array with a rejected marker in C, nested dictionaries in C\#,
a template string key in javascript, a tuple key in python, nested
tables in lua, where handing the constructor a different table
yields a different machine with the same Fire. This table returns in
the capstone as the follower, candidate, leader spine of raft, with
timers instead of pushes.

#diagram([the whole machine in one table, every transition visible at once], length: 13pt, {
  cdraw.content((3.6, 6.6), [coin], size: 6.5pt)
  cdraw.content((9.8, 6.6), [push], size: 6.5pt)
  cdraw.content((-1.2, 4.9), [locked], size: 6.5pt)
  cdraw.content((-1.2, 3.0), [unlocked], size: 6.5pt)
  cdraw.rect((0.2, 4.2), (6.8, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 4.9), [unlocked, thanks], size: 6pt)
  cdraw.rect((7.0, 4.2), (13.6, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((10.3, 4.9), [locked, alarm], size: 6pt)
  cdraw.rect((0.2, 2.3), (6.8, 3.7), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 3.0), [unlocked, thanks], size: 6pt)
  cdraw.rect((7.0, 2.3), (13.6, 3.7), fill: luma(235), radius: 0.02)
  cdraw.content((10.3, 3.0), [locked, click], size: 6pt)
  cdraw.content((6.9, 1.0), [an unknown event returns false and changes nothing], size: 6pt)
})

== visitor as a type switch

The visitor pattern's double dispatch exists to compensate for
languages that dispatch on one receiver. Go's type switch does the
job directly:

The dry run: the fixture is Area on a circle of radius 2 landing
12.566370614359172 with the literal 3.141592653589793, a 3 by 2 rect
landing 6, and the describe strings circle r=2.0 and rect 3 x 2. The
go lane's frozen test pins its own circle of radius 1 against the
same literal pi.

+ The variants are one closed set and the visitors are functions
  over it: Area and Describe in go, Perimeter a third visitor in the
  lua file.
+ Adding a visitor costs one function, adding a variant touches
  every visitor, the trade stated as a count.
+ The unknown variant answers zero and unknown instead of guessing.

#listing("patterns-concurrency-distributed/samples-c/src/Ch04/visitor.c", first: 18, last: 65, caption: [C, a tagged union and a switch, adding a variant adds a case])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch04/Visitor.cs", first: 5, last: 36, caption: [C\#, records as the closed set, pattern matching as the switch])

#listing("patterns-concurrency-distributed/samples/ch04/behavioral.go", first: 233, last: 258, caption: [Go, variants as plain structs, visitors as functions that switch])

#listing("patterns-concurrency-distributed/samples-js/src/ch04-visitor.mjs", first: 5, last: 31, caption: [JavaScript, kind-tagged objects, switch on the tag])

#listing("patterns-concurrency-distributed/samples-py/src/Ch04/visitor.py", first: 13, last: 39, caption: [Python, match over class patterns])

#listing("patterns-concurrency-distributed/samples-lua/ch04_visitor.lua", first: 8, last: 34, caption: [Lua, tag fields and if chains, a second visitor costs one function])

`Area` and `Describe` are two visitors over the same variant set,
each a few lines instead of a visitor interface plus accept methods
on every variant. The cost is honest: adding a variant compiles
nothing until someone runs it, while adding a method to an interface
fails every implementor at build time. The marker method `isShape`
at least keeps foreign types out of the union, a closed set by
construction. The closed set itself wears a different costume per
tree: a tagged union in C, a switch over a tag field in javascript,
if chains on a tag in lua, records under pattern matching in C\#, and
python's `match` binding class patterns directly, the structural
side of its dataclass story#xref-to("python", "dataclasses").

#diagram([one closed union, visitors are switches over it], length: 13pt, {
  cdraw.rect((0, 1.2), (5.4, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((2.7, 3.7), [Shape union], size: 6.5pt)
  cdraw.content((2.7, 2.8), [Circle], size: 6pt)
  cdraw.content((2.7, 1.7), [Rect], size: 6pt)
  cdraw.rect((8, 2.6), (13, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((10.5, 4.15), [Area], size: 6.5pt)
  cdraw.content((10.5, 3.25), [case Circle, case Rect], size: 6pt)
  cdraw.rect((8, 0.2), (13, 2.2), fill: luma(235), radius: 0.02)
  cdraw.content((10.5, 1.75), [Describe], size: 6.5pt)
  cdraw.content((10.5, 0.85), [case Circle, case Rect], size: 6pt)
  cdraw.line((5.4, 3.4), (8, 3.6), stroke: luma(100))
  cdraw.line((5.4, 2.0), (8, 1.2), stroke: luma(100))
  cdraw.content((18.2, 2.4), [adding a variant,#linebreak()compiles nothing], size: 6pt)
})

#callout("note", "the default is a function", [
  Mediator is dependency injection via parameters, chain of
  responsibility is a slice of handlers tried in order, template
  method is a parameter the caller fills, and interpreter is a tree
  of the composite from chapter 3 with an eval method. When a
  behavioral pattern feels heavy in go, the missing ingredient is
  usually a function value, not another interface.
])

#diagram([four patterns, four shapes of passing a function], length: 13pt, {
  cdraw.rect((0, 3.4), (10.5, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.25, 5.35), [mediator], size: 6.5pt)
  cdraw.content((5.25, 4.25), [injection via parameters], size: 6pt)
  cdraw.rect((11.5, 3.4), (22, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((16.75, 5.35), [chain of responsibility], size: 6.5pt)
  cdraw.content((16.75, 4.25), [a slice tried in order], size: 6pt)
  cdraw.rect((0, 0.2), (10.5, 2.7), fill: luma(235), radius: 0.02)
  cdraw.content((5.25, 2.15), [template method], size: 6.5pt)
  cdraw.content((5.25, 1.05), [a parameter the caller fills], size: 6pt)
  cdraw.rect((11.5, 0.2), (22, 2.7), fill: luma(235), radius: 0.02)
  cdraw.content((16.75, 2.15), [interpreter], size: 6.5pt)
  cdraw.content((16.75, 1.05), [the composite tree plus eval], size: 6pt)
})

== across the six languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [618], [libc plus threads.h], [fixed subscriber arrays under one mutex, undo records instead of closures, the iterator a yield callback with a context pointer],
  [c\#], [285], [bcl], [Channels subscribers with TryWrite drops, yield return iterators, record pattern matching visitors],
  [go], [211], [stdlib], [frozen reference lane, iter.Seq adapters, SortStableFunc, buffered channel subscribers],
  [javascript], [154], [node stdlib], [generators whose finally observes the stop, Map insertion order fixing delivery order],
  [python], [311], [stdlib only], [generator close runs finally, match visitors, a tuple keyed transition table],
  [lua], [521], [lib.lua harness], [push sequences as functions over yield callbacks, index tiebreak for sort stability, swapped tables make new machines],
)

sources: go.dev/pkg/iter for `Seq`, `Seq2`, and `Pull` semantics,
go.dev/ref/spec range over function, go.dev/pkg/slices for
`SortStableFunc` stability, go.dev/pkg/net/http for the middleware
as chain of responsibility precedent, accessed 2026-09-08. Verified
by the six chapter legs: `go test -race` at 6 tests in
`patternsbook/ch04`, 6 C programs with 47 embedded checks, 17 C\#
facts over `PatternsBook.slnx`, 11 `node --test` cases, 52 Python
checks across 6 files, and 28 Lua rows under `run.lua`.
