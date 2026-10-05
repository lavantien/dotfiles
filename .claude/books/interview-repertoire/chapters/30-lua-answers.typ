#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= lua answers

The lua round is a contrast round. The questions arrive addressed to a
javascript practitioner, and the answer that lands names what lua
does differently instead of translating a habit across: metatables
against prototypes, stackful coroutines against the event loop,
`_ENV` against the scope chain. Three drills, spoken, every claim
floored to the lua manual whose gated samples carry the depth, and
the javascript side of each contrast floored to this book's own
#xref-to("repertoire", "js-core").

== metatables and metamethods [DRILL]

A metatable is a table of fallbacks keyed by event name, and lua's
object system is the protocol that consults it, because there is no
class keyword anywhere in the language. Any value may carry one:
tables get theirs from `setmetatable`, every other type shares one
per type, and only C or the debug library can change those, which is
how the string library gives every string an `__index` pointing at
the string table so `("abc"):len()` works. Read and write are
separate events. `__index` fires only when the access is not a table
or the key is absent, the metavalue can be a function, a table, or
any value with its own metavalue, and because the follow-up access
is regular, misses chain, and that chain is inheritance,
`setmetatable(child, {__index = parent})` being the whole mechanism.
`__newindex` is the write twin and the trap: an assignment routed
through it never performs the primitive store, and `rawset` and
`rawget` exit the protocol entirely, the escape hatch the follow-up
probes for. The operator events are orthodox: arithmetic searches
the first operand then the second and passes the operands in
original order, `__eq` runs only between two tables or two full
userdata that are not primitively equal, `__lt` and `__le` take any
mixed pair, and `__call` prepends the callee to the argument list.
So give the conclusion, not the tour: oop in lua is dispatch by
agreement, one table asking another what to do about a miss, a
constructor an ordinary function returning a fresh table plus a
metatable, methods living in the `__index` table, `self` the colon
sugar, the full event inventory at #xref-to("lua", "values").

#diagram([the read miss walks the index chain, the write detours, the raw pair exits both], length: 13pt, {
  // left: a miss walking __index to a methods table; right: __newindex as a gate that skips the store
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), [#t], size: 6pt)
  }
  cdraw.content((5.2, 10.4), [the read event], size: 6.5pt)
  box(0.4, 8.6, 4.2, 1.0, [t.k, a miss])
  cdraw.line((4.6, 9.1), (5.8, 9.1), stroke: luma(100), mark: (end: ">"))
  box(5.8, 8.6, 3.2, 1.0, [metatable], fill: luma(245))
  cdraw.line((9.0, 9.1), (10.2, 9.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 8.2), [\_\_index], size: 6pt)
  box(10.2, 8.6, 4.2, 1.0, [methods table], fill: luma(215))
  cdraw.content((8.6, 7.6), [a miss in the metavalue is a regular access, the chain continues], size: 6pt)
  cdraw.line((2.5, 8.5), (2.5, 7.1), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((2.5, 6.7), [rawget(t, k), no walk], size: 6pt)
  cdraw.content((18.6, 10.4), [the write event], size: 6.5pt)
  box(13.6, 8.6, 3.6, 1.0, [t.k = v])
  cdraw.line((17.2, 9.1), (18.4, 9.1), stroke: luma(100), mark: (end: ">"))
  box(18.4, 8.6, 3.6, 1.0, [\_\_newindex], fill: luma(245))
  cdraw.line((20.2, 8.5), (20.2, 7.5), stroke: luma(100), mark: (end: ">"))
  box(17.6, 6.3, 5.2, 1.0, [the watcher's table], fill: luma(215))
  cdraw.content((20.2, 5.8), [the primitive store never happens, rawset exits], size: 6pt)
  cdraw.content((11.5, 3.4), [operator events: first operand then second, \_\_eq needs two tables, \_\_lt takes any pair, \_\_call prepends the callee], size: 6pt)
  cdraw.content((11.5, 2.2), [no classes anywhere: a constructor is a function returning a fresh table plus a metatable], size: 6pt)
})

== coroutines versus javascript async [DRILL]

A lua coroutine is a value of type `thread`, a collaborative
execution context with its own stack, and the stack is the whole
answer. `coroutine.create` only builds it, `resume` runs it, `yield`
suspends it, status walks suspended, running, normal, dead, and
because the entire stack parks, a function at any nesting depth can
yield, the 5.4 guarantee holding in 5.5 that yields cross `pcall`
bodies and metamethods, #xref-to("lua", "coroutines"). Control is
asymmetric: `yield` returns to whoever resumed and `resume` runs the
body on, values flowing both ways, resume arguments entering the
body and each `yield`, yield arguments coming back out of the
matching resume. Now the contrast, #xref-to("repertoire", "js-core"):
javascript runs one call stack, suspension happens only at an
`await`, and `await` exists only inside async functions, so functions
are colored, one async callee forcing async on every caller up the
chain, the parked continuations riding a microtask queue the event
loop drains to empty after every macrotask. Lua has neither colors
nor a scheduler: the caller of a yielding function cannot tell, no
syntax marks the suspension point, nothing runs until some `resume`
calls it, so a coroutine is a value you store and pass, `wrap`
handing back the plain function the generic `for` wants and trading
`resume`'s error tuple for exceptions. The boundary, volunteered
before it is asked: one thread of control at a time, cooperative
only, no parallelism, and an unprotected error kills the coroutine
without unwinding its stack so the debug library can read the corpse.

#diagram([lua parks whole stacks and owns no scheduler, javascript parks one frame and pays the queue], length: 13pt, {
  // left: main and coroutine stacks with resume and yield crossing; right: one stack, await queuing resumes on the microtask queue
  let frame(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), [#t], size: 6pt)
  }
  cdraw.content((5.5, 10.4), [lua, one stack per coroutine], size: 6.5pt)
  frame(0.8, 8.6, 3.9, [main chunk])
  frame(0.8, 7.7, 3.9, [resume(c)], fill: luma(215))
  frame(6.7, 8.6, 3.9, [the body])
  frame(6.7, 7.7, 3.9, [helper])
  frame(6.7, 6.8, 3.9, [yield(v)], fill: luma(215))
  cdraw.line((4.7, 8.15), (6.7, 8.15), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.7, 8.55), [resume], size: 6pt)
  cdraw.line((6.7, 6.3), (4.7, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.7, 5.9), [yield], size: 6pt)
  cdraw.content((5.5, 4.9), [the whole stack parks, any nesting depth can yield], size: 6pt)
  cdraw.content((5.5, 3.9), [status: suspended, running, normal, dead], size: 6pt)
  cdraw.content((18.6, 10.4), [javascript, one call stack], size: 6.5pt)
  frame(13.6, 7.7, 4.4, [async fn, at await], fill: luma(215))
  cdraw.content((15.8, 7.25), [suspends here only], size: 6pt)
  cdraw.line((18.0, 8.15), (19.2, 8.15), stroke: luma(100), mark: (end: ">"))
  for i in range(3) {
    cdraw.rect((19.2 + i * 1.5, 7.7), (20.7 + i * 1.5, 8.6), fill: if i == 0 { luma(215) } else { luma(245) }, stroke: luma(120), radius: 0.02)
  }
  cdraw.content((21.5, 7.25), [resumes queued], size: 6pt)
  cdraw.rect((19.2, 5.4), (23.0, 6.3), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((21.1, 5.85), [timer, a macrotask], size: 6pt)
  cdraw.content((18.6, 4.9), [the queue drains to empty after every macrotask], size: 6pt)
  cdraw.content((11.5, 3.1), [lua: no colored functions, the caller cannot tell, and no scheduler, resume is an ordinary call], size: 6pt)
  cdraw.content((11.5, 2.0), [javascript: every awaiter is async up the chain, the event loop owns resumption], size: 6pt)
})

== closures and environments against javascript [DRILL]

Closures match until you name the unit of sharing. A lua closure
captures upvalues, and the box is created when the block executes
the local declaration: two closures from one factory invocation
share one upvalue box, two invocations build independent boxes,
private state in five lines, #xref-to("lua", "functions"). The
javascript gotcha is the mirror, #xref-to("repertoire", "js-core"):
a `var` loop shares one binding and every callback prints 3, `let`
gives per-iteration bindings and they print 0, 1, 2, and lua lands
on the `let` side by construction, every executed declaration a
fresh box, no hoisting to share. Then the part javascript has no
answer for: there is no global scope in lua, only a variable named
`_ENV`. Every free name compiles to `_ENV.var`, every chunk compiles
inside an external local named `_ENV`, and every function captures
whichever `_ENV` was visible where it was defined, so the global
namespace is one ordinary upvalue, #xref-to("lua", "environments").
Shadow `_ENV` with a local and globals change, `load`'s fourth
argument swaps it per chunk, and `_G` is not the mechanism, just an
ordinary global pointing at the usual table. The line to say out
loud: javascript resolves free names up a scope chain that ends at
a real global object, so a sandbox is a realm or a vm boundary,
while lua's globals are a captured variable, so a sandbox is
`load(src, name, "t", env)` and the untrusted chunk never sees `io`.

#callout("pitfall", "_ENV is a captured variable, not a registry", [
  Globals do not resolve through a hidden table the runtime owns.
  They compile to field reads on `_ENV`, an upvalue like any other,
  so a chunk's global namespace is swapped by handing it a different
  `_ENV` and nothing else. Assigning `_G = {}` rebinds one name and
  changes nothing about how any free name resolves.
])

#diagram([one upvalue box per executed declaration, the chunk's globals one captured `_ENV`], length: 13pt, {
  // left: two closures from one factory sharing a box; right: the chunk wrapped in the external local _ENV
  cdraw.content((5.4, 10.6), [closures, the box is the unit], size: 6.5pt)
  cdraw.rect((0.8, 5.4), (9.9, 9.7), fill: luma(250), stroke: (paint: luma(150), dash: "dashed"), radius: 0.02)
  cdraw.content((5.35, 9.15), [one factory invocation], size: 6pt)
  cdraw.rect((3.4, 8.0), (7.3, 8.8), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((5.35, 8.4), [upvalue: count], size: 6pt)
  cdraw.rect((1.4, 6.6), (4.0, 7.5), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((2.7, 7.05), [inc], size: 6pt)
  cdraw.rect((6.7, 6.6), (9.3, 7.5), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((8.0, 7.05), [get], size: 6pt)
  cdraw.line((2.7, 6.5), (4.4, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.0, 6.5), (6.3, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.35, 5.9), [a second invocation builds its own count], size: 6pt)
  cdraw.content((17.6, 10.6), [environments, no global scope], size: 6.5pt)
  cdraw.rect((12.0, 5.4), (23.2, 9.7), fill: luma(250), stroke: (paint: luma(150), dash: "dashed"), radius: 0.02)
  cdraw.content((17.6, 9.15), [external local \_ENV], size: 6pt)
  cdraw.rect((12.5, 7.2), (18.5, 8.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((15.5, 8.0), [the chunk], size: 6pt)
  cdraw.content((15.5, 7.55), [x = 1 compiles to \_ENV.x = 1], size: 6pt)
  cdraw.line((18.5, 7.75), (19.1, 7.75), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((19.1, 7.2), (22.7, 8.4), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((20.9, 7.8), [print, io, x], size: 6pt)
  cdraw.content((17.6, 6.6), [shadow \_ENV with a local and globals change], size: 6pt)
  cdraw.content((17.6, 5.9), [load's fourth argument swaps it, \_G is just a name in it], size: 6pt)
  cdraw.content((11.5, 4.2), [javascript ends its scope chain at a real global object, lua's globals are one captured variable], size: 6pt)
})

sources: no measurements in this chapter, every claim the manual's
own semantics, and every drill floors to the lua manual, book 8,
#xref-to("lua", "values") for the event tables and the raw access,
#xref-to("lua", "functions") for the upvalue box,
#xref-to("lua", "coroutines") for the stack, the resume yield
channel, and the un-unwound corpse, and #xref-to("lua",
"environments") for `_ENV`, `load`, and the sandbox.
