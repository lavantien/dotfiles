#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= functions

Three definition sugars sit on one runtime fact, functions are
values. `function f() end` assigns to the visible `f`, `local
function f` expands to `local f; f = function` so the body can
recurse, and 5.5 adds the third form, `global function f`, which
declares then initializes the global, so redefining it is the
initialization error:

#listing("lua/samples/ch06_functions.lua", first: 5, last: 15, caption: [recursion through the local sugar, and the global redefinition error])

#diagram([the three definition sugars and what each expands to], length: 13pt, {
  // each row: what you write, an arrow, what it means, and the consequence
  cdraw.content((4.25, 11.9), [you write], size: 6.5pt)
  cdraw.content((14.0, 11.9), [it expands to], size: 6.5pt)
  let sugar(y, write, expand, note) = {
    cdraw.rect((0.5, y), (8.0, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((4.25, y + 0.7), write, size: 6pt)
    cdraw.line((8.2, y + 0.7), (9.2, y + 0.7), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((9.4, y), (18.6, y + 1.4), fill: luma(205), radius: 0.02)
    cdraw.content((14.0, y + 0.7), expand, size: 6pt)
    cdraw.content((9.65, y - 0.9), note, size: 6.5pt)
  }
  sugar(9.6, [function f() end], [f = function() end], [assigns the visible f, plain assignment])
  sugar(6.2, [local function f() end], [local f; f = function() end], [the local exists before the body, recursion works])
  sugar(2.8, [global function f() end], [global f; f = function() end], [declaration plus initialization, redefining is an error])
})

The colon defines methods: `function t.a.b.c:m(...)` sugar-assigns
`t.a.b.c.m` with `self` as the first parameter, and the call site
`obj:m(x)` passes `obj` implicitly.

== multiple results

Lua functions return lists, not tuples. The list expands only in
tail positions: the last argument of a call, the last field of a
constructor, the last element of a `return`. Anywhere else the call
truncates to one value, and parentheses force that truncation
explicitly:

#listing("lua/samples/ch06_functions.lua", first: 27, last: 49, caption: [expansion rules and the parenthesis cut])

#flow(
  [when a call's results expand, and when they are cut],
  node((0, 0), [a call inside an expression]),
  node((0, 1.6), [in a tail position? #linebreak() last arg, last field, return]),
  node((-2.9, 1.6), [every result #linebreak() flows out]),
  node((0, 3.2), [wrapped in parentheses?]),
  node((-2.9, 3.2), [one value, #linebreak() the explicit cut]),
  node((0, 4.8), [adjusted to one value]),
  node((3.0, 1.6), [f(g()) passes along #linebreak() every result of g]),
  node((3.0, 3.2), [(f()) keeps #linebreak() the first only]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (-2.9, 1.6), "-|>", label: [yes]),
  edge((0, 1.6), (0, 3.2), "-|>", label: [no]),
  edge((0, 3.2), (-2.9, 3.2), "-|>", label: [yes]),
  edge((0, 3.2), (0, 4.8), "-|>", label: [no]),
)

== the 5.5 vararg model

This is the release's second language change. A variadic function no
longer exposes only an expression: the extra arguments land in a
vararg table whose field `n` is the count, and the parameter list can
name it, `function g(a, b, ...rest)`. The name binds a read-only
local; without a name, only the `...` expression reaches the table.
The manual's own mapping table, with a multret call in the last
argument position, is pinned directly:

#listing("lua/samples/ch06_functions.lua", first: 51, last: 67, caption: [named vararg table, count at n, and the manual's mapping])

#diagram([where the extra arguments land in the 5.5 vararg model], length: 13pt, {
  // the call and the two fixed parameters
  cdraw.content((3.4, 10.0), [call g(1, 2, 3, 4)], size: 6pt)
  cdraw.content((3.4, 8.5), [parameters a and b], size: 6.5pt)
  cdraw.rect((0.5, 6.6), (3.2, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((1.85, 7.2), [a = 1], size: 6pt)
  cdraw.rect((3.6, 6.6), (6.3, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.95, 7.2), [b = 2], size: 6pt)
  cdraw.line((2.5, 9.6), (1.85, 7.9), stroke: luma(120))
  cdraw.line((4.3, 9.6), (4.95, 7.9), stroke: luma(120))
  // the extras land in a real table the name binds to
  cdraw.rect((9.5, 5.4), (21.5, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((15.5, 8.2), [rest, the vararg table], size: 6pt)
  cdraw.rect((10.3, 6.0), (12.3, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.3, 6.6), [3], size: 6pt)
  cdraw.rect((12.7, 6.0), (14.7, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((13.7, 6.6), [4], size: 6pt)
  cdraw.rect((16.3, 6.0), (20.3, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((18.3, 6.6), [n = 2, the count], size: 6pt)
  cdraw.line((5.2, 9.6), (10.1, 7.3), stroke: luma(120))
  cdraw.line((6.0, 9.6), (13.5, 7.3), stroke: luma(120))
  // the observable table, and the elision rule
  cdraw.content((5.2, 4.2), [... reads the table, #linebreak() edits are visible through it], size: 6.5pt)
  cdraw.content((16.0, 4.2), [the name is a read only local, #linebreak() it never rebinds], size: 6.5pt)
  cdraw.content((10.7, 2.4), [a closure capturing the name forces the real table, else the compiler may elide it], size: 6.5pt)
})

Because the extras are a real table, code can edit it, and the
vararg expression reads what the table now holds:

#listing("lua/samples/ch06_functions.lua", first: 69, last: 96, caption: [mutation through the table, and the compile time name lock])

#callout("warning", "the table is observable but not guaranteed", [
  When the vararg table is anonymous, or the name is only ever used
  as `t[exp]` or `t.id` and never captured by a nested closure, the
  compiler skips building an actual table and compiles accesses to
  the internal vararg data. Capturing the name into a closure, as
  the escape test does, forces the real table. Programs should treat
  the table as a read window unless they deliberately mutate it.
])

== closures and tail calls

A closure pairs a function prototype with the locals it captured.
Each execution of a `local` creates a fresh variable, so the loop's
closures each own their `own` while sharing the outer `shared`, and
two counters from the same factory are independent:

#listing("lua/samples/ch06_functions.lua", first: 98, last: 125, caption: [per-declaration upvalues, shared versus independent])

#diagram([two closures from one factory, one upvalue box between them], length: 13pt, {
  // the factory's counter local lives in one upvalue box
  cdraw.rect((7.9, 3.4), (14.3, 4.4), fill: luma(230), radius: 0.05)
  cdraw.content((11.1, 3.9), [upvalue: count], size: 6.5pt)
  // each closure holds the prototype plus a reference to that box
  let clo(x, t) = {
    cdraw.rect((x, 0.6), (x + 7.6, 1.6), fill: luma(245), stroke: luma(120), radius: 0.05)
    cdraw.content((x + 3.8, 1.1), [#t], size: 6.5pt)
  }
  clo(0, "closure one, incr")
  clo(14.6, "closure two, incr")
  cdraw.line((3.8, 1.6), (9.2, 3.4))
  cdraw.line((18.4, 1.6), (13.0, 3.4))
  cdraw.content((11.1, 5.1), [created once by the factory call], size: 6.5pt)
  cdraw.content((11.1, -0.4), [both see every increment, the box is the sharing], size: 6.5pt)
})

A proper tail call, `return f(...)`, reuses the frame, so a tail
recursive loop of any depth runs in constant stack. A non tail
recursion still consumes stack, but that stack is bounded by the lua
stack's million slots, not by the 200 c call budget, which only
counts nested c calls, so plain recursion runs hundreds of thousands
deep before the overflow error:

#listing("lua/samples/ch06_functions.lua", first: 127, last: 144, caption: [constant stack tail loop, deep non tail recursion, the eventual overflow])

#diagram([tail calls reuse the frame, plain recursion pays a frame per level], length: 13pt, {
  // panel a: the tail call, one frame forever
  cdraw.content((3.4, 9.8), [return f(...)], size: 6.5pt)
  cdraw.rect((1.4, 7.0), (5.4, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((3.4, 7.6), [one frame], size: 6pt)
  cdraw.line((5.6, 7.9), (6.4, 7.9), (6.4, 8.9), (2.4, 8.9), (2.4, 8.3), stroke: luma(120), mark: (end: ">"))
  cdraw.content((3.4, 5.8), [the frame is reused, #linebreak() the stack stays flat], size: 6.5pt)
  // panel b: plain recursion
  cdraw.content((12.0, 9.8), [plain recursion], size: 6.5pt)
  for i in range(5) {
    cdraw.rect((10.0, 7.2 - i * 1.3), (14.0, 8.2 - i * 1.3), fill: luma(235), radius: 0.02)
    cdraw.content((12.0, 7.7 - i * 1.3), [a frame], size: 6pt)
  }
  cdraw.content((12.0, 0.4), [about 10\^6 lua stack slots, then the overflow error], size: 6.5pt)
  // panel c: the c budget
  cdraw.content((19.0, 9.8), [calls into c], size: 6.5pt)
  for i in range(3) {
    cdraw.rect((17.2, 7.2 - i * 1.3), (20.8, 8.2 - i * 1.3), fill: luma(235), radius: 0.02)
    cdraw.content((19.0, 7.7 - i * 1.3), [c frame], size: 6pt)
  }
  cdraw.content((19.0, 2.9), [capped near 200, #linebreak() LUAI\_MAXCCALLS], size: 6.5pt)
})

sources: lua.org manual 5.5 sections 2.2, 3.4.11, 3.4.12, accessed
2026-09-08. Vararg and recursion limits verified live with lua 5.5.1,
LUAI_MAXCCALLS confirmed at 200 in ldo.h for C calls only, 13 tests
green through `make verify-lua`.
