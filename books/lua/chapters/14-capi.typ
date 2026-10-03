#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= the c api, hands on

Lua is a library first and a language second. The interpreter this
book runs is one host program among possible ones, linking
`lua55.dll` and driving it through a c api of roughly two hundred
functions, and pure lua code can see the seam from both sides: 127 of
the standard library's functions are c functions, identified by
`debug.getinfo`'s `"C"` classification, and the host's compiler,
`luac`, is a separate executable that shares the same front end.

#listing("lua/samples/ch14_capi.lua", first: 70, last: 83, caption: [counting the c functions behind the lua libraries])

This tree now builds hosts of its own: six c programs under
`samples-c/src/Ch14/`, compiled with the documented mingw gcc against
`lua55.dll` and run by `make verify-lua-c`, 89 checks green. The same
chapter walks them in order, a first host, the stack, protected
calls, c functions for lua, userdata, and references.

#diagram([the seam from both sides, a host linking the library], length: 13pt, {
  // the host and the library it drives
  cdraw.rect((0.5, 8.6), (8.0, 10.4), fill: luma(235), radius: 0.02)
  cdraw.content((4.25, 9.5), [a host program, #linebreak() the interpreter is one], size: 6pt)
  cdraw.line((8.2, 9.5), (9.6, 9.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.9, 9.95), [links], size: 6pt)
  cdraw.rect((9.8, 8.6), (21.5, 10.4), fill: luma(235), radius: 0.02)
  cdraw.content((15.65, 9.5), [the library, lua55.dll, #linebreak() about 200 api functions], size: 6pt)
  // the census
  cdraw.rect((0.5, 5.0), (12.0, 6.8), fill: luma(205), radius: 0.02)
  cdraw.content((6.25, 5.9), [the c census: 127 stdlib functions], size: 6pt)
  cdraw.rect((12.5, 5.0), (21.5, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((17.0, 5.9), [the rest, written in lua], size: 6pt)
  // what it means
  cdraw.content((11.0, 3.6), [counted through debug.getinfo's what field], size: 6.5pt)
  cdraw.content((11.0, 2.4), [luac is a second host sharing the same front end], size: 6.5pt)
  cdraw.content((11.0, 1.2), [six hosts in this tree, run by make verify-lua-c], size: 6.5pt)
})

== luac

`luac` precompiles and disassembles. Its output binary is exactly
what `string.dump` produces, loadable with mode `"b"`, and its `-l`
listing is the register machine made visible: `VARARGPREP` opens
vararg functions, `MMBIN` is the metamethod fallback arm beside each
arithmetic op, `TAILCALL` and the `RETURN` family carry result
counts, and `LOADI` packs small integers into the instruction:

#listing("lua/samples/ch14_capi.lua", first: 20, last: 46, caption: [compile to binary and execute it, then read the opcode names])

#diagram([source to binary through luac, and the register machine it shows], length: 13pt, {
  // the compile pipeline
  cdraw.rect((0.5, 8.6), (3.8, 10.0), fill: luma(235), radius: 0.02)
  cdraw.content((2.15, 9.3), [source], size: 6pt)
  cdraw.line((4.0, 9.3), (5.2, 9.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.4, 8.6), (11.4, 10.0), fill: luma(205), radius: 0.02)
  cdraw.content((8.4, 9.3), [luac, or string.dump], size: 6pt)
  cdraw.line((11.6, 9.3), (12.8, 9.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.0, 8.6), (21.5, 10.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.25, 9.3), [one binary, load with mode "b"], size: 6pt)
  // the visible register machine
  cdraw.content((2.5, 7.0), [the -l listing], size: 6.5pt)
  let ops = (("VARARGPREP", 3.2), ("MMBIN", 2.0), ("TAILCALL", 2.2), ("LOADI", 1.6))
  let x = 6.2
  for (op, w) in ops {
    cdraw.rect((x, 6.2), (x + w, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.8), [#op], size: 6pt)
    x += w + 0.4
  }
  cdraw.content((16.6, 6.8), [the register machine], size: 6pt)
  // the guarantees
  cdraw.content((11.0, 4.8), [the dump is exactly what string.dump produces], size: 6.5pt)
  cdraw.content((11.0, 3.6), [a syntax error stops at the compiler, never at runtime], size: 6.5pt)
  cdraw.content((11.0, 2.4), [stripping debug info trades tracebacks for size], size: 6.5pt)
})
#listing("lua/samples/ch14_capi.lua", first: 85, last: 94, caption: [a syntax error stops at the compiler, not at runtime])

`string.dump` takes a strip flag that removes debug information, the
difference between the 98 byte dump of a one line function and its
73 byte stripped form, trading traceback quality for size:

#listing("lua/samples/ch14_capi.lua", first: 48, last: 54, caption: [full and stripped dumps])

== a first host

The smallest host is three calls: `luaL_newstate` builds a state,
`luaL_openlibs` stocks the standard libraries, and `luaL_dostring`
runs one chunk. Everything else this chapter does is the same three
moves with more values crossing the boundary:

#listing("lua/samples-c/src/Ch14/firsthost.c", first: 27, last: 42, caption: [newstate, openlibs, dostring, and the value it leaves behind])

Errors come back as return codes, never crashes. One 5.5 trap hides
in the convenience macro: `luaL_dostring` expands to
`luaL_loadstring(L, s) || lua_pcall(...)`, so its result is a bare
truth value, 0 for success, 1 for any failure, and a host that wants
the specific code calls the two steps itself:

#listing("lua/samples-c/src/Ch14/firsthost.c", first: 44, last: 60, caption: [syntax errors from the macro, runtime errors from the two steps])

#diagram([a host's first minute, state, libraries, one chunk, error codes home], length: 13pt, {
  // the pipeline of the first host
  cdraw.rect((0.5, 7.4), (4.6, 9.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.55, 8.85), [luaL_newstate], size: 6pt)
  cdraw.content((2.55, 7.95), [then lua\_close], size: 6pt)
  cdraw.line((4.8, 8.5), (6.0, 8.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.2, 7.4), (12.6, 9.6), fill: luma(205), radius: 0.02)
  cdraw.content((9.4, 8.85), [luaL_openlibs], size: 6pt)
  cdraw.content((9.4, 7.95), [the globals table fills], size: 6pt)
  cdraw.line((12.8, 8.5), (14.0, 8.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.2, 7.4), (21.5, 9.6), fill: luma(235), radius: 0.02)
  cdraw.content((17.85, 8.85), [luaL_dostring], size: 6pt)
  cdraw.content((17.85, 7.95), [0 ok, 1 any failure], size: 6pt)
  // the guarantees
  cdraw.content((11.0, 5.6), [the chunk's return value waits on the stack], size: 6.5pt)
  cdraw.content((11.0, 4.4), [error text crosses the boundary as a string], size: 6.5pt)
  cdraw.content((11.0, 3.2), [specific codes need loadstring plus pcall, 5.5's macro is boolean], size: 6.5pt)
  cdraw.content((11.0, 2.0), [the host owns main, lua never does], size: 6.5pt)
})

== the stack

Every value crosses the boundary on one growable stack, pushed by
the host or by lua, read by index. Positive indices count from the
bottom, negative from the top, and the type predicates split the
number subtypes exactly the way #xref-to("lua", "values") taught
them:

#listing("lua/samples-c/src/Ch14/stack.c", first: 27, last: 41, caption: [five pushes, both index directions, the subtype predicates])

Stack discipline is explicit: `lua_pop` takes from the top,
`lua_settop` truncates, `lua_pushvalue` duplicates, and `lua_copy`
overwrites one slot with another without moving anything else:

#listing("lua/samples-c/src/Ch14/stack.c", first: 50, last: 64, caption: [pop, settop, pushvalue, copy])

#diagram([one stack, two index directions, the moves between slots], length: 13pt, {
  // five slots with both index numbers
  let slot(i, val, pos, neg) = {
    cdraw.rect((6.2, 9.8 - i * 1.3), (12.4, 10.9 - i * 1.3), fill: luma(235), radius: 0.02)
    cdraw.content((8.1, 10.35 - i * 1.3), val, size: 6pt)
    cdraw.content((5.2, 10.35 - i * 1.3), pos, size: 6pt)
    cdraw.content((13.4, 10.35 - i * 1.3), neg, size: 6pt)
  }
  slot(0, [7, integer], [1], [-5])
  slot(1, [2.5, float], [2], [-4])
  slot(2, ["hi", string], [3], [-3])
  slot(3, [false], [4], [-2])
  slot(4, [nil], [5], [-1])
  cdraw.content((2.2, 10.35), [from the bottom], size: 6pt)
  cdraw.content((16.2, 10.35), [from the top], size: 6pt)
  // the moves
  cdraw.line((6.0, 10.35), (4.6, 7.4), stroke: luma(120), mark: (end: ">"))
  cdraw.content((3.6, 8.9), [pushvalue #linebreak() copies slot 1], size: 6pt)
  cdraw.line((12.6, 7.75), (15.0, 9.0), stroke: luma(120), mark: (end: ">"))
  cdraw.content((17.2, 8.4), [copy overwrites, #linebreak() pop takes the top], size: 6pt)
  // the law
  cdraw.content((11.0, 2.6), [one stack per lua\_State, the call channel and the scratchpad], size: 6.5pt)
  cdraw.content((11.0, 1.4), [isinteger and isnumber split the subtypes, conversions follow the language], size: 6.5pt)
})

== calling lua protected

`lua_call` jumps unprotected and takes the host down with an error.
Every robust host, the stock interpreter included, runs `lua_pcall`
instead, with a message handler sitting below the function whose
absolute index the call receives. The handler is the one place to
build a traceback, because the error is still on the stack and the
frames are still alive:

#listing("lua/samples-c/src/Ch14/protected.c", first: 23, last: 38, caption: [the message handler, stringify then traceback])

#listing("lua/samples-c/src/Ch14/protected.c", first: 40, last: 52, caption: [docall, handler below, absolute index, host cleans up])

Results and errors come back on the same stack. A runtime error
arrives with the traceback appended, a non-string error object is
stringified by the handler instead of lost, and a syntax error never
reaches the handler at all:

#listing("lua/samples-c/src/Ch14/protected.c", first: 72, last: 91, caption: [the three failure flavors, all survived])

#flow(
  [one protected call, handler under function, results or one error],
  node((0, 0), [docall pushes #linebreak() msghandler, then the chunk]),
  node((0, 1.6), [loadstring ok?]),
  node((-2.9, 1.6), [LUA_ERRSYNTAX, #linebreak() handler never ran]),
  node((0, 3.2), [lua\_pcall, msgh index #linebreak() under the function]),
  node((0, 4.8), [results, or the #linebreak() handler's message]),
  node((3.0, 3.2), [pcall pops function and #linebreak() args, never the handler]),
  node((3.0, 4.8), [host removes the handler, #linebreak() stack is clean]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (-2.9, 1.6), "-|>", label: [no]),
  edge((0, 1.6), (0, 3.2), "-|>", label: [yes]),
  edge((0, 3.2), (0, 4.8), "-|>"),
)

== c functions for lua

The seam runs the other way too: a c function is a `lua_CFunction`
that receives the state, reads its arguments from the stack, and
returns how many results it pushed. `luaL_checkinteger` and
`luaL_optinteger` do the argument validation with the stdlib's own
error wording, and `lua_gettop` is the arity:

#listing("lua/samples-c/src/Ch14/cfuncs.c", first: 24, last: 40, caption: [three c functions, checked args, arity, multiple results])

Registration is one array. `luaL_newlib` builds the table, registers
every `luaL_Reg` pair, and leaves the table on the stack for
`lua_setglobal`; `lua_register` plants a single function without any
array at all:

#listing("lua/samples-c/src/Ch14/cfuncs.c", first: 48, last: 65, caption: [the luaL\_Reg array and both registration forms])

#diagram([registration, the seam from lua's side], length: 13pt, {
  // the array and the table it becomes
  cdraw.rect((0.5, 7.6), (9.0, 10.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.75, 9.4), [a luaL\_Reg array], size: 6pt)
  cdraw.content((4.75, 8.3), [(add, l\_add), (sum, l\_sum), #linebreak() the NULL pair ends it], size: 6pt)
  cdraw.line((9.2, 8.8), (10.4, 8.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.8, 9.3), [luaL_newlib], size: 6pt)
  cdraw.rect((10.6, 7.6), (15.6, 10.0), fill: luma(205), radius: 0.02)
  cdraw.content((13.1, 9.4), [one table], size: 6pt)
  cdraw.content((13.1, 8.3), [add and sum, #linebreak() c functions inside], size: 6pt)
  cdraw.line((15.8, 8.8), (17.0, 8.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.4, 9.3), [setglobal], size: 6pt)
  cdraw.rect((17.2, 7.6), (21.5, 10.0), fill: luma(235), radius: 0.02)
  cdraw.content((19.35, 8.8), [box.add(19, 23)], size: 6pt)
  // the laws
  cdraw.content((11.0, 5.8), [arguments at 1..n, the return counts what was pushed], size: 6.5pt)
  cdraw.content((11.0, 4.6), [checkinteger raises with the stdlib wording, optinteger defaults], size: 6.5pt)
  cdraw.content((11.0, 3.4), [getinfo classifies the newcomer exactly like print, what C], size: 6.5pt)
  cdraw.content((11.0, 2.2), [this is how all 127 stdlib c functions are made], size: 6.5pt)
})

== userdata in outline

Userdata is raw c memory wearing a lua value: `lua_newuserdata`
allocates, the host writes its struct, and a metatable named in the
registry guards every later access. `luaL_checkudata` compares the
name and refuses the wrong type with a loud error, which is the
entire type safety story:

#listing("lua/samples-c/src/Ch14/userdata.c", first: 24, last: 34, caption: [the struct, and checked access through the metatable name])

Methods are ordinary c functions whose first argument is the value
itself, the self convention, and `__gc` is the one hook into the
collector: the finalizer runs when the last reference drops, once
per value, and `lua_close` finalizes whatever survived:

#listing("lua/samples-c/src/Ch14/userdata.c", first: 36, last: 54, caption: [bump returns self, get reads, gc counts])

#diagram([a counter value, c memory behind a lua face], length: 13pt, {
  // the userdata value as struct memory
  cdraw.rect((0.5, 7.8), (10.5, 10.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 9.65), [one userdata value], size: 6pt)
  cdraw.rect((1.2, 8.1), (6.0, 9.2), fill: luma(245), radius: 0.02)
  cdraw.content((3.6, 8.65), [the Counter struct], size: 6pt)
  cdraw.rect((6.3, 8.1), (9.8, 9.2), fill: luma(205), radius: 0.02)
  cdraw.content((8.05, 8.65), [metatable name], size: 6pt)
  cdraw.line((10.7, 8.65), (11.9, 8.65), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.1, 7.8), (21.5, 9.5), fill: luma(235), radius: 0.02)
  cdraw.content((16.8, 9.0), [book.counter in the registry], size: 6pt)
  cdraw.content((16.8, 8.15), [bump, get, and \_\_gc ride \_\_index], size: 6pt)
  // the lifecycle
  cdraw.content((5.5, 6.3), [lua\_newuserdata allocates, the host writes the struct], size: 6.5pt)
  cdraw.content((5.5, 5.1), [checkudata refuses impostors by name], size: 6.5pt)
  cdraw.content((5.5, 3.9), [last reference drops: \_\_gc runs once, collected], size: 6.5pt)
  cdraw.content((5.5, 2.7), [lua\_close finalizes the survivors, measured twice in the suite], size: 6.5pt)
  cdraw.content((5.5, 1.5), [light userdata is a bare pointer, no metatable, no gc], size: 6.5pt)
})

== references

The registry is a table the host reaches through the
`LUA_REGISTRYINDEX` pseudo-index. In 5.5 its fixed integer slots are
exactly two, `LUA_RIDX_GLOBALS` at 2 and `LUA_RIDX_MAINTHREAD` at 3,
and `package.loaded` lives at the `"_LOADED"` string key, verified
by identity against the global it publishes:

#listing("lua/samples-c/src/Ch14/refs.c", first: 27, last: 49, caption: [the registry, its two fixed slots, and the \_LOADED key])

`luaL_ref` pins any value at a fresh integer key and pops it,
`lua_rawgeti` pushes it back, and `luaL_unref` releases the pin. The
5.5 release keeps a freelist: the freed slot reads back as the
next-free integer rather than nil, and slot 1 heads the list, so the
same integer is reused before any new one is minted:

#listing("lua/samples-c/src/Ch14/refs.c", first: 51, last: 72, caption: [pin, call through, release, and the freelist it joins])

#flow(
  [a reference's life, pin, use, freelist],
  node((0, 0), [a value to keep, #linebreak() a closure, a table]),
  node((0, 1.7), [luaL\_ref, an integer key, #linebreak() the value pops off the stack]),
  node((0, 3.4), [rawgeti pushes it back, #linebreak() it calls like any function]),
  node((0, 5.1), [luaL\_unref releases the pin]),
  node((2.9, 5.1), [slot 1 heads the freelist, #linebreak() the integer comes back around]),
  edge((0, 0), (0, 1.7), "-|>"),
  edge((0, 1.7), (0, 3.4), "-|>"),
  edge((0, 3.4), (0, 5.1), "-|>"),
  edge((0, 5.1), (2.9, 5.1), "-|>"),
)

== the state model

#diagram([what a host drives, states, their stacks, and the registry], length: 13pt, {
  // two states, each owning a growable value stack
  cdraw.rect((0.5, 9.2), (10.5, 11.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 10.95), [the main state], size: 6pt)
  for i in range(4) {
    cdraw.rect((1.3 + i * 1.75, 9.5), (2.85 + i * 1.75, 10.4), fill: luma(245), radius: 0.02)
  }
  cdraw.content((8.9, 9.95), [...], size: 6pt)
  cdraw.rect((11.5, 9.2), (21.5, 11.4), fill: luma(235), radius: 0.02)
  cdraw.content((16.5, 10.95), [a coroutine's state], size: 6pt)
  for i in range(4) {
    cdraw.rect((12.3 + i * 1.75, 9.5), (13.85 + i * 1.75, 10.4), fill: luma(245), radius: 0.02)
  }
  cdraw.content((19.9, 9.95), [...], size: 6pt)
  cdraw.content((11.0, 8.6), [one lua\_State per coroutine, each with a growable value stack], size: 6.5pt)
  // the registry under both
  cdraw.rect((0.5, 6.2), (21.5, 7.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 7.0), [the registry: globals at 2, mainthread at 3, \_LOADED by name, both states reach it], size: 6pt)
  // the call protocol
  cdraw.content((11.0, 4.9), [calls exchange values on the stack, lua\_call asks for nresults], size: 6.5pt)
  cdraw.content((11.0, 3.7), [nresults caps at 250 in 5.5, LUA\_MULTRET asks for all], size: 6.5pt)
  cdraw.content((11.0, 2.5), [lua\_newstate's seed randomizes string hashing per run], size: 6.5pt)
})

The api the hosts use is one `lua_State` per coroutine plus the main
state, a growable value stack per state, and the registry, measured
above as globals at slot 2, the main thread at 3, and
`package.loaded` behind the `"_LOADED"` string key that
#xref-to("lua", "stdlib3") visited. Calls exchange
values over that stack, `lua_call` and friends requesting `nresults`
return slots, and 5.5 specifies the limit
#xref-to("lua", "incompat") lists among incompatibilities: at most
250, with `LUA_MULTRET` for
everything. `lua_newstate` gained a string hashing seed parameter,
which is why table iteration order differs between runs and why
`math.randomseed` exists separately for reproducible sequences.

#callout("note", "what stays invisible", [
  The fourth 5.5 headline, more compact internal arrays, is an
  implementation change with no observable language semantics, and
  this book's binary is the only lua in the tree, so there is no
  5.4 baseline to measure memory against. The claim is documented,
  not tested, and the coverage matrix says so.
])

== chunk names

A chunk's name decides its error prefix and tracebacks. Source from
`loadfile` gets the file path, a string from `load` defaults to a
`[string "..."]` form, and the `"=name"` form uses the name
literally, the way to make generated code debuggable:

#listing("lua/samples/ch14_capi.lua", first: 56, last: 68, caption: [the three prefix forms])

#diagram([three source name forms and the prefixes they buy], length: 13pt, {
  // rows: how the chunk was loaded, against the error prefix it gets
  let pair(y, left, right) = {
    cdraw.rect((0.5, y), (8.0, y + 1.4), fill: luma(235), radius: 0.02)
    cdraw.content((4.25, y + 0.7), left, size: 6pt)
    cdraw.line((8.2, y + 0.7), (9.4, y + 0.7), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((9.6, y), (21.5, y + 1.4), fill: luma(245), radius: 0.02)
    cdraw.content((15.55, y + 0.7), right, size: 6pt)
  }
  pair(8.8, [a string chunk, unnamed], [\[string "x()"\]:1: ...])
  pair(6.2, [load(src, "=gen")], [gen:1: ..., the name, literally])
  pair(3.6, [loadfile("app.lua")], [app.lua:1: ..., the file path])
  cdraw.content((11.0, 2.2), [the = form is how generated code stays debuggable], size: 6.5pt)
})

sources: lua.org manual 5.5 sections 1 and 4, the auxiliary library
sections on tracebacks, references, and userdata, and the luac man
page in the 5.5.1 distribution, accessed 2026-09-08 and 2026-09-21.
Opcode names, dump sizes, the c census, the dostring macro shape,
the registry slots, and the ref freelist verified live with lua
5.5.1: 7 tests green through `make verify-lua`, 89 c checks across
6 hosts green through `make verify-lua-c`.
