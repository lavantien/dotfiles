#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= stdlib 3: coroutine, debug, package

The coroutine half of this chapter's territory lives in
#xref-to("lua", "coroutines"),
lifecycle, close semantics, yields through metamethods and pcall.
What remains here is the debug library, lua's reflection surface, and
the package machinery behind `require`.

== the debug library

`debug.getinfo` classifies activation records: `"Lua"` for interpreted
functions with a source and a defined line, `"C"` for host functions
like `print` or the `pcall` frame sitting under any test, and
`"main"` for chunk frames. `debug.traceback` is the message handler
that turns an error object into an error plus stack, which is the
`xpcall` idiom:

#listing("lua/samples/ch13_stdlib3.lua", first: 5, last: 23, caption: [classification by what field, traceback through xpcall])

#diagram([the call stack the debug library reads, level by level], length: 13pt, {
  // three activation records as stacked frames
  cdraw.rect((0.5, 10.1), (10.0, 12.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.25, 11.05), [level 1, a lua frame, #linebreak() what = "Lua", source, line], size: 6pt)
  cdraw.rect((0.5, 8.1), (10.0, 10.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.25, 9.05), [level 2, a c frame, #linebreak() what = "C", like pcall], size: 6pt)
  cdraw.rect((0.5, 6.1), (10.0, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.25, 7.05), [the chunk's frame, #linebreak() what = "main"], size: 6pt)
  // what each level exposes, and the hooks
  cdraw.content((16.0, 11.05), [getlocal, setlocal, #linebreak() by level and slot], size: 6pt)
  cdraw.content((16.0, 9.05), [getupvalue, setupvalue, #linebreak() a closure's captures], size: 6pt)
  cdraw.content((16.0, 7.05), [hooks on "c", "r", "l", #linebreak() or every n instructions], size: 6pt)
  // the registry sits under it all
  cdraw.rect((0.5, 3.6), (21.5, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 4.5), [the registry, where package.loaded lives under \_LOADED], size: 6pt)
  cdraw.content((11.0, 2.4), [debug.getmetatable returns the real table, \_\_metatable cannot hide it], size: 6.5pt)
  cdraw.content((11.0, 1.2), [traceback is the message handler that keeps the stack in the error], size: 6.5pt)
})

`debug.getlocal` and `debug.setlocal` reach into a live frame by
level and slot, names and values both, and `debug.getupvalue` with
`debug.setupvalue` do the same for a closure's captured variables.
This is the standard library's escape hatch from immutability, and
the tests use it to rewrite a counter mid-closure:

#listing("lua/samples/ch13_stdlib3.lua", first: 25, last: 45, caption: [reading and writing locals and upvalues])

Hooks instrument execution. The `"c"`, `"r"`, and `"l"` events fire
on call, return, and line, the count form fires every n vm
instructions, and `debug.sethook()` with no arguments unhooks. The
call hook can ask `debug.getinfo(2)` who called:

#listing("lua/samples/ch13_stdlib3.lua", first: 47, last: 73, caption: [count budget and call return nesting])

Two registry level operations complete the set: the registry itself,
where `package.loaded` actually lives under the key `"_LOADED"`, and
`debug.getmetatable`, which returns the real metatable even when
`__metatable` protection lies to ordinary `getmetatable`:

#listing("lua/samples/ch13_stdlib3.lua", first: 75, last: 88, caption: [the registry table and the metatable bypass])

== package and require

`require` walks `package.searchers`, first the preload searcher,
which consults `package.preload`, then the path searcher over
`package.path`, then the c path over `package.cpath`, and fourth a
c-root searcher that probes the module's first component in the
cpath, unused in this book. A searcher
returns a loader plus a provenance string on success, or a message
string explaining its part of the failure, and the require error
concatenates the whole trail, which is why a missing module's error
lists every directory lua looked in:

#listing("lua/samples/ch13_stdlib3.lua", first: 90, last: 139, caption: [file based require with caching, the search trail, preload, and the searcher contract])

#flow(
  [the require pipeline, searchers in order, the cache in front],
  node((0, 0), [require "name"]),
  node((0, 1.6), [already in package.loaded?]),
  node((-2.9, 1.6), [the cached table, #linebreak() identical every time]),
  node((0, 3.2), [the preload searcher, #linebreak() package.preload]),
  node((0, 4.8), [the path searcher, #linebreak() package.path files]),
  node((0, 6.4), [the c path searcher, #linebreak() package.cpath]),
  node((0, 8.0), [every miss message, #linebreak() concatenated into the error]),
  node((3.0, 3.2), [a hit returns a loader #linebreak() plus its provenance]),
  node((3.0, 4.8), [a miss returns a message, #linebreak() the trail grows]),
  node((3.0, 6.4), [the loader's result #linebreak() lands in the cache]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (-2.9, 1.6), "-|>", label: [yes]),
  edge((0, 1.6), (0, 3.2), "-|>", label: [no]),
  edge((0, 3.2), (0, 4.8), "-|>"),
  edge((0, 4.8), (0, 6.4), "-|>"),
  edge((0, 6.4), (0, 8.0), "-|>"),
)

The cache is `package.loaded`: a second `require` of the same name
returns the identical table, clearing the entry forces a reload, and
the suite builds and removes a real module file to watch all three
steps happen. `package.searchpath` is the path searcher's probe
exported, returning the resolved file or nil plus the same trail
message.

#callout("note", "why the samples runner prepends the path", [
  The stock `package.path` on this build points into the interpreter's
  install tree first and the current directory last. The runner sets
  `package.path = "./?.lua;" .. package.path` so chapter modules and
  the assertion library resolve from the samples directory regardless
  of the caller's location, the same trick `make verify-lua` relies on
  by always running from inside the project.
])

sources: lua.org manual 5.5 sections 6.3, 6.4, 6.11, accessed
2026-09-08. Searcher return contract and registry layout verified
live with lua 5.5.1, 12 tests green through `make verify-lua`.
