#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= idioms

Lua's object model is three moves: a table of methods, `__index`
pointing there, and constructor sugar. The chapter's vector class
puts every metamethod family to work at once, arithmetic, equality,
ordering, length, and printing, and the inheritance pattern is one
more line, a class whose metatable's `__index` is the superclass:

#listing("lua/samples/ch16_idioms.lua", first: 1, last: 30, caption: [the vector class and the shape to circle chain])

#diagram([the object model as one chain of index links], length: 13pt, {
  // object, class, superclass as a chain
  cdraw.rect((0.5, 8.6), (5.0, 10.4), fill: luma(235), radius: 0.02)
  cdraw.content((2.75, 9.5), [an object, #linebreak() x and y], size: 6pt)
  cdraw.line((5.2, 9.5), (7.8, 9.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.5, 9.95), [\_\_index], size: 6pt)
  cdraw.rect((8.0, 8.6), (14.0, 10.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 9.5), [the class table, #linebreak() \_\_add, \_\_eq, len], size: 6pt)
  cdraw.line((14.2, 9.5), (16.4, 9.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.3, 9.95), [\_\_index], size: 6pt)
  cdraw.rect((16.6, 8.6), (21.5, 10.4), fill: luma(205), radius: 0.02)
  cdraw.content((19.05, 9.5), [superclass], size: 6pt)
  // the constructor and the fluent chain
  cdraw.content((11.0, 7.0), [a constructor is a function that sets the metatable and returns], size: 6.5pt)
  cdraw.content((11.0, 5.8), [mutation methods return self, that is the fluent chain], size: 6.5pt)
  cdraw.content((11.0, 4.6), [inheritance is the second link, one line of setup], size: 6.5pt)
})
#listing("lua/samples/ch16_idioms.lua", first: 32, last: 46, caption: [operator classes, chaining through returned self])

Mutation methods return `self`, which is what makes fluent apis
readable, and constructors are just functions that set a metatable.

== errors

`error` with level 2 blames the caller, which is what argument
checking wants, with one caveat the suite tripped over: a tail call
erases the frame the blame reads, so the level 2 position comes back
empty when the checked call sits in `return` position. Keep the call
out of a tail or the message loses its location:

#listing("lua/samples/ch16_idioms.lua", first: 48, last: 68, caption: [the one line index chain, level 2 blame])

#flow(
  [choosing the error level, with the tail call caveat],
  node((0, 0), [an argument check fails]),
  node((0, 1.7), [blame the caller?]),
  node((-2.9, 1.7), [level 1, #linebreak() the check itself]),
  node((0, 3.4), [level 2, the caller]),
  node((0, 5.1), [a tail call erases the frame, #linebreak() keep the check out of return position]),
  node((3.0, 1.7), [assert pairs its message #linebreak() with the failing value]),
  node((3.0, 3.4), [x or default, #linebreak() false falls through too]),
  edge((0, 0), (0, 1.7), "-|>"),
  edge((0, 1.7), (-2.9, 1.7), "-|>", label: [no]),
  edge((0, 1.7), (0, 3.4), "-|>", label: [yes]),
  edge((0, 3.4), (0, 5.1), "-|>", label: [caveat]),
)

`x or default` is the default parameter idiom, with the standing
caveat that false falls through to the default too, which for
boolean flags is a bug and for absent values is exactly right.

== iteration and forwarding

Two iterator shapes cover most needs: the stateless triple that
avoids allocating anything per step, and the coroutine wrap that
can express arbitrarily complex producers as straight line code:

#listing("lua/samples/ch16_idioms.lua", first: 70, last: 99, caption: [stateless triple, coroutine producer, assert with messages, defaults through or])

#flow(
  [three producers, one loop, and 5.5 forwarding],
  node((0, 0), [the generic for]),
  node((-2.5, 1.7), [the stateless triple, #linebreak() f, s, control, #linebreak() no allocation per step]),
  node((0, 1.7), [a closure iterator]),
  node((2.5, 1.7), [a wrapped coroutine, #linebreak() straight line producers]),
  node((0, 3.6), [forwarding: the named vararg table, #linebreak() unpack(t, 1, t.n) re-emits embedded nils]),
  edge((-2.5, 1.7), (0, 0), "-|>"),
  edge((0, 1.7), (0, 0), "-|>"),
  edge((2.5, 1.7), (0, 0), "-|>"),
  edge((0, 1.7), (0, 3.6), "-|>", bend: -60deg),
)

Forwarding varargs in 5.5 reads better than any earlier release:
the named table carries the count, `unpack` to position `n`
re-emits the list including embedded nils.

== state and caching

Private state is a closure over locals, two counters from one
factory share nothing. Memoization is a table and a call counter,
and the protected call wrapper returns its success flag first,
which composes into the result type shape the javascript book built
with generics, here in seven lines:

#listing("lua/samples/ch16_idioms.lua", first: 101, last: 145, caption: [vararg forwarding detail, memoization, closure state, pcall as result])
#listing("lua/samples/ch16_idioms.lua", first: 111, last: 131, caption: [memoization with call counting])

#diagram([closure state, the memo cache, and pcall as a result type], length: 13pt, {
  // closure locals as private state
  cdraw.rect((0.5, 7.6), (9.0, 9.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.75, 8.5), [a closure over locals, #linebreak() two factories share nothing], size: 6pt)
  // the memo cache as boxes
  cdraw.rect((10.0, 7.6), (21.5, 9.4), fill: luma(235), radius: 0.02)
  cdraw.content((15.75, 9.0), [the memo cache], size: 6pt)
  cdraw.rect((10.6, 7.9), (14.6, 8.7), fill: luma(245), radius: 0.02)
  cdraw.content((12.6, 8.3), [args → result], size: 6pt)
  cdraw.rect((14.8, 7.9), (18.8, 8.7), fill: luma(245), radius: 0.02)
  cdraw.content((16.8, 8.3), [args → result], size: 6pt)
  cdraw.rect((19.0, 7.9), (21.1, 8.7), fill: luma(205), radius: 0.02)
  cdraw.content((20.05, 8.3), [calls], size: 6pt)
  // pcall's shape as two result cells
  cdraw.content((11.0, 6.5), [a protected call returns its verdict first], size: 6.5pt)
  cdraw.rect((4.0, 4.6), (9.5, 5.8), fill: luma(245), radius: 0.02)
  cdraw.content((6.75, 5.2), [true, value], size: 6pt)
  cdraw.rect((11.0, 4.6), (16.5, 5.8), fill: luma(205), radius: 0.02)
  cdraw.content((13.75, 5.2), [false, error], size: 6pt)
  cdraw.content((11.0, 3.4), [the flag composes into a result type, seven lines here], size: 6.5pt)
})

== the sandbox shape

The load environment from #xref-to("lua", "environments") is the
whole sandboxing story:
hand in exactly the functions the embedded code may use, and
nothing else exists, not even `_G`:

#listing("lua/samples/ch16_idioms.lua", first: 160, last: 165, caption: [a three function environment])

#diagram([the sandbox, an environment holding exactly what you grant], length: 13pt, {
  // the load call on top
  cdraw.rect((0.5, 8.8), (21.5, 10.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 9.7), [load(src, name, "t", env), text mode only, no bytecode], size: 6pt)
  // the granted environment
  cdraw.rect((2.5, 5.6), (19.5, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 7.5), [the environment table you hand in], size: 6pt)
  cdraw.rect((4.0, 6.0), (7.5, 7.0), fill: luma(245), radius: 0.02)
  cdraw.content((5.75, 6.5), [print], size: 6pt)
  cdraw.rect((8.0, 6.0), (11.5, 7.0), fill: luma(245), radius: 0.02)
  cdraw.content((9.75, 6.5), [string], size: 6pt)
  cdraw.rect((12.0, 6.0), (15.5, 7.0), fill: luma(245), radius: 0.02)
  cdraw.content((13.75, 6.5), [math], size: 6pt)
  cdraw.content((18.0, 6.5), [...], size: 6pt)
  // what exists inside
  cdraw.rect((0.5, 3.0), (21.5, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 3.9), [inside the chunk, exactly these exist, no \_G, no io], size: 6pt)
  cdraw.content((11.0, 1.8), [the chunk cannot escape its table, chapter 8's mechanism], size: 6.5pt)
})

sources: lua.org manual 5.5 sections 2.4, 3.4.11, 6.2, programming
in lua fourth edition idioms as background, accessed 2026-09-08.
Verified live with lua 5.5.1, 12 tests green through `make verify-lua`.
