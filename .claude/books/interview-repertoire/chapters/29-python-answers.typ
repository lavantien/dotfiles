#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= python answers

The python round asks four questions that separate the person
who has run the interpreter from the person who has only read
about it: what the gil actually locks, how the data model
dispatches, why closures surprise, and which concurrency lane
the work belongs in. Every answer is spoken, drill-only, and
floored on the python manual.

== the gil and what it actually locks [DRILL]

The Global Interpreter Lock is one mutex inside cpython that a
thread must hold to run python bytecode. It locks bytecodes, not
bytes: it guards the interpreter's own state, and it is neither
a memory model nor a thread-safety guarantee for your objects,
#xref-to("python", "threads"). What releases it is the half the
question fishes for: any blocking system call, file and network
io, sleep, and c extensions that release it around their
compute, so waiting overlaps even when computing cannot. The
handoff: the interpreter sells a switch interval, the 0.005
second default, and which thread runs at the end of an interval
is the operating system's decision, the interpreter runs no
scheduler of its own. So cpu-bound threads do not parallelize,
the bytecode cannot overlap, and parallel cpu work means
processes, one interpreter and one gil per process. The aside,
stated carefully: free-threaded builds exist, 3.13 shipped the
build available but explicitly experimental, later releases move
it toward supported while it stays a separate binary that is not
the default, and the corpus pins the standard build. The
follow-up is "so is python thread safe": no, the callout is the
whole answer.

#callout("pitfall", "the gil serializes bytecode, not your updates", [
  One thread's counter increment is three steps, read, add,
  store, and the gil can be handed off between them, so two
  threads can both read zero and both store one. The lock
  protects the interpreter's internals, never your invariants,
  and shared state still takes a lock.
])

#diagram([one thread through the gil: the two ways out of running, only one of them overlaps], length: 13pt, {
  // three states: running holds the lock, the queue waits, a system call steps out and frees it
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.4), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.7), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 5.6, 5.0, [running: holds the gil, #linebreak() executing bytecode])
  box(8.2, 5.6, 5.6, [waiting: no bytecode, no lock], fill: luma(248))
  box(15.6, 5.6, 6.2, [blocked in a system call, gil released], fill: luma(215))
  cdraw.line((5.6, 6.8), (8.2, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.2, 5.8), (5.6, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.9, 7.4), [interval ends, os picks], size: 6pt)
  cdraw.line((13.8, 6.3), (15.6, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.6, 5.5), (13.8, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.7, 7.0), [read, sleep, return], size: 6pt)
  box(4.6, 2.8, 13.0, [cpu work cycles the left pair, io steps out right and another thread runs], fill: luma(220))
})

== the data model: dunders and protocols [DRILL]

Everything a python program touches at runtime is an object, and
every name is only a binding to one, #xref-to("python",
"objects"). Dunder methods are the operator table of the
language, and the runtime, not your code, decides when to dial
one: define the len hook and the len call dials it, define iter
and for loops take the object, define getitem and indexing,
slicing, iteration, and membership all go through it, define the
enter and exit pair and the with statement runs them, enter's
return binding the as name. The dispatch rule the question is
really asking: implicit lookups go to the type, walking the
class dicts and bypassing the instance's own namespace, so a
hook parked on the instance is dead weight the builtin never
dials. That is what makes objects first-class, the protocol on
the type means every builtin trusts the object, sorted dials lt
and nothing else, and defining eq alone makes the class
unhashable, because equal objects must hash equal. Dataclasses
are the same surface generated: a decorator writing init, repr,
and eq from the declared field list, the dunders by machine
instead of by hand. The follow-up is "why the type": one lookup
site per protocol, so the dispatch cannot be spoofed per
instance.

#diagram([implicit calls dial hooks on the type, the instance's namespace is bypassed], length: 13pt, {
  // left: the call you write, middle: the hook the runtime dials, right: where the hook must live
  let cell(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 0.95), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.48), t, size: 6pt)
  }
  cell(0.6, 8.6, 5.0, [you write], fill: luma(205))
  cell(5.6, 8.6, 5.6, [the runtime dials], fill: luma(205))
  cell(11.2, 8.6, 6.4, [found on], fill: luma(205))
  cell(0.6, 7.4, 5.0, [len(obj)], fill: luma(250))
  cell(5.6, 7.4, 5.6, [the len hook])
  cell(11.2, 7.4, 6.4, [the class dicts])
  cell(0.6, 6.2, 5.0, [for item in obj], fill: luma(250))
  cell(5.6, 6.2, 5.6, [iter, else getitem])
  cell(0.6, 5.0, 5.0, [with obj], fill: luma(250))
  cell(5.6, 5.0, 5.6, [enter, then exit])
  cdraw.rect((11.2, 5.0), (17.6, 8.35), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((14.4, 6.6), [the class dicts, #linebreak() on the type], wrap: text.with(size: 6pt))
  cdraw.rect((0.6, 3.4), (17.6, 4.35), fill: luma(248), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((9.1, 3.88), [a hook parked on the instance is never dialed, the lookup bypasses it], size: 6pt)
})

== decorators, closures, scopes [DRILL]

Name resolution is a walk up four namespaces, local, enclosing,
global, builtin, and a closure is the enclosing layer's
machinery: the inner function keeps a reference to the cell
holding the enclosing name, and the cell outlives the call that
created it, #xref-to("python", "functions"). The gotcha the
round fishes for: closures capture cells, not values. A lambda
written in a loop shares the loop variable's one cell, the cell
holds the last value once the loop ends, and a list of three
such lambdas answers with that last value three times. The two
fixes, named out loud: bind at def time through a default
argument, or call a factory that builds a fresh cell per
invocation. A decorator is the same machinery wearing syntax: a
function that takes a function and returns a function, the at
spelling rebinding the name at def time to whatever the decorator
hands back, which is why stacked decorators apply bottom up.
functools.wraps is the apology the wrapper owes: without it the
wrapper's name and doc replace the wrapped function's, and help
and tracebacks lie about who is running. The follow-up is the
gotcha asked as code, answered with the cell, then the factory.

#diagram([three lambdas share the loop's one cell and all answer 2, the factory mints a cell per call], length: 13pt, {
  // top: the shared cell the loop leaves behind, bottom: the factory's per-call cells
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0.6, 8.4, 3.0, [fns 0])
  box(4.4, 8.4, 3.0, [fns 1])
  box(8.2, 8.4, 3.0, [fns 2])
  cdraw.line((2.1, 8.3), (6.2, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.9, 8.3), (7.9, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.7, 8.3), (9.6, 7.2), stroke: luma(100), mark: (end: ">"))
  box(5.6, 6.0, 4.8, [one cell: i, now 2], fill: luma(215))
  cdraw.content((8.0, 4.9), [called now, all three answer 2], size: 6pt)
  box(0.6, 2.4, 3.6, [mk 0, owns 0], fill: luma(215))
  box(5.0, 2.4, 3.6, [mk 1, owns 1], fill: luma(215))
  box(9.4, 2.4, 3.6, [mk 2, owns 2], fill: luma(215))
  cdraw.content((6.8, 1.2), [the factory: a fresh cell per call, each keeps its own value], size: 6pt)
})

== asyncio versus threads [DRILL]

Asyncio is cooperative multitasking: one thread, one event loop,
and the concurrency comes from suspension, not from more threads,
#xref-to("python", "asyncio"). The loop yields exactly where the
code says await, and only there: a coroutine that never awaits
starves everything sharing the loop, awaiting a coroutine runs it
like a subroutine, and the body only overlaps once it is wrapped
in a task the loop schedules. Cancellation holds the same
contract, it lands at the next await, never mid-statement. The
two-lanes answer, said as one sentence: io-bound work goes to
async when the stack is already async, or to threads when the
calls block, the gil releasing around the wait either way, and
cpu-bound work goes to processes, because no lane inside one
interpreter runs bytecode in parallel. The contrast the strong
candidate volunteers: go multiplexes many goroutines onto few os
threads with work stealing, a blocking goroutine parks and its
thread runs another, #xref-to("repertoire", "go-runtime"),
javascript is asyncio's family, one call stack, run to
completion, the microtask queue drained between turns,
#xref-to("repertoire", "js-core"), and python threads are real
os threads the os switches at the interval, the difference from
async being who decides to switch. The follow-up is "why not
threads for everything": they overlap the waiting and still lose
the cpu lane.

#diagram([io waits in either lane, cpu leaves the interpreter, and the models differ in who switches], length: 13pt, {
  // left: the two lanes a workload lands in, right: the four models and who decides the switch
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((4.1, 9.7), [the lanes], size: 6.5pt)
  box(0.6, 7.5, 7.0, 1.6, [io-bound: asyncio, or threads, #linebreak() the gil released around the wait])
  box(0.6, 5.3, 7.0, 1.6, [cpu-bound: processes, #linebreak() one interpreter and one gil each], fill: luma(248))
  cdraw.content((4.1, 4.6), [bytecode never overlaps inside one interpreter], size: 6pt)
  cdraw.content((15.6, 9.7), [who switches], size: 6.5pt)
  box(9.8, 7.5, 5.6, 1.6, [asyncio: the code, #linebreak() at each await], fill: luma(248))
  box(16.0, 7.5, 5.6, 1.6, [go: the runtime, #linebreak() goroutines onto threads], fill: luma(248))
  box(9.8, 5.3, 5.6, 1.6, [threads: the os, #linebreak() at the interval], fill: luma(248))
  box(16.0, 5.3, 5.6, 1.6, [javascript: the loop, #linebreak() run to completion], fill: luma(248))
  cdraw.content((13.4, 3.5), [cooperative at await points, preemptive elsewhere], size: 6pt)
})

floored to the python manual: #xref-to("python", "threads") for
the gil states and the lock toolbox, #xref-to("python",
"objects") for the data model, #xref-to("python", "functions")
for scopes, cells, and decorators, #xref-to("python", "asyncio")
for the loop and its tasks, and #xref-to("python", "toolchain")
for the interpreter build the corpus pins.
