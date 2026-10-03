#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= ffi: c without the api

Chapter 14 showed the c api from the host's side, a stack protocol the
embedding program drives. LuaJIT's ffi library is the other road to c:
lua code declares the signatures, loads the library, and calls the
functions directly, with no binding module and no glue c compiled
against anything. The tree keeps a second interpreter for exactly
this, the LuaJIT rolling 2.1 that `make sqlite-tools` builds beside
the sqlite 3.53.4 dll this chapter calls, and the ffi lane under
`books/lua/jit/` uses the pair to give the editor modules a real
database file to persist into.

The price is printed in the interpreter's own banner: LuaJIT speaks
lua 5.1, no `goto`, no integer division operator, none of the 5.2 and
later stdlib. That constraint is not incidental here, it is the load
bearing wall between the two runtimes, and this chapter ends with the
rule the repo enforces to keep them apart.

#flow(
  [the two roads to c, who drives the calls],
  node((0, 0), [lua code needs a c library]),
  node((0, 1.7), [who drives?]),
  node((-3.0, 1.7), [the c api: the host drives, #linebreak() a stack protocol, chapter 14]),
  node((3.0, 1.7), [the ffi: lua declares #linebreak() and calls, no glue]),
  node((0, 3.4), [the ffi's price: luajit #linebreak() speaks lua 5.1]),
  edge((0, 0), (0, 1.7), "-|>"),
  edge((0, 1.7), (-3.0, 1.7), "-|>", label: [the host]),
  edge((0, 1.7), (3.0, 1.7), "-|>", label: [the lua side]),
  edge((3.0, 1.7), (0, 3.4), "-|>", bend: -35deg),
)

== the boundary

`ffi.cdef` parses c declarations. Nothing is compiled and nothing is
verified against the dll: cdef lines are a promise the caller makes,
and the first call through a wrong promise is memory corruption, not
an error message. The wrapper's promise covers the seventeen functions
the editor lane needs, no more:

#listing("lua/jit/sqlite.lua", first: 5, last: 24, caption: [the whole cdef block, the signatures the wrapper promises])

#diagram([the boundary, declarations as promises, then live calls], length: 13pt, {
  // the pipeline from cdef to machine code, single lines sized for the boxes
  let stage(x0, x1, l1, l2, hot) = {
    let f = if hot { luma(205) } else { luma(235) }
    cdraw.rect((x0, 7.4), (x1, 9.6), fill: f, radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 8.55), l1, size: 6pt)
    cdraw.content(((x0 + x1) / 2, 7.45), l2, size: 6pt)
  }
  stage(0.5, 8.0, [ffi.cdef], [seventeen signatures], false)
  cdraw.line((8.2, 8.5), (8.9, 8.5), stroke: luma(100), mark: (end: ">"))
  stage(9.1, 15.3, [a promise], [nothing is verified], true)
  cdraw.line((15.5, 8.5), (16.1, 8.5), stroke: luma(100), mark: (end: ">"))
  stage(16.3, 21.5, [ffi.load], [calls into c], false)
  // the copying rule and the pin
  cdraw.content((11.0, 6.2), [ffi.load maps the dll, the calls cross into machine code], size: 6.5pt)
  cdraw.content((11.0, 5.0), [ffi.string copies into a lua string before the c pointer can age], size: 6.5pt)
  cdraw.content((11.0, 3.8), [a wrong promise is memory corruption, the version is pinned at require time], size: 6.5pt)
})

`ffi.load` maps the dll into the process, `lib.sqlite3_libversion()`
is then an ordinary lua function call that crosses into machine code
from the dll, and `ffi.string` copies the returned `const char *`
into a lua string before the c pointer can age. The module refuses to
load against any other build:

#listing("lua/jit/sqlite.lua", first: 34, last: 43, caption: [load the dll and pin the version at require time])

== the statement lifecycle

The c api's shape survives the wrapper untouched: open returns a
connection, statements are prepared, bound, stepped, and finalized,
and every non-zero result code becomes a lua error through
`sqlite3_errmsg`. Connections and statements are thin tables whose
only job is holding the cdata handles where the collector can see
them:

#listing("lua/jit/sqlite.lua", first: 51, last: 76, caption: [open with an out pointer, exec with the error slot, prepare])

#flow(
  [a statement's life, prepare to finalize],
  node((0, 0), [open returns a connection]),
  node((0, 1.6), [prepared]),
  node((0, 3.2), [bound, transient, #linebreak() sqlite owns its copy]),
  node((0, 4.8), [step: row or done]),
  node((0, 6.4), [finalized]),
  node((-2.9, 4.8), [any nonzero rc becomes #linebreak() a lua error, via errmsg]),
  node((3.0, 0), [connections and statements, #linebreak() thin tables over cdata]),
  node((3.0, 6.4), [the rows helper finalizes #linebreak() when the iterator runs dry]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (0, 3.2), "-|>"),
  edge((0, 3.2), (0, 4.8), "-|>"),
  edge((0, 4.8), (-2.9, 4.8), "-|>"),
  edge((0, 4.8), (0, 6.4), "-|>"),
)

The destructor argument of `sqlite3_bind_text` is where ownership is
decided. SQLite defines two constants that are function pointer casts
of 0 and -1: static promises sqlite the bytes stay valid until the
statement is rebound, transient tells it to copy at bind time. A lua
string cannot promise its bytes to a c library, the collector is free
to reuse them once lua forgets the reference, so the wrapper always
hands over transient and lets sqlite own its copy:

#listing("lua/jit/sqlite.lua", first: 105, last: 125, caption: [bind text and int, step reporting row or done])

The query helper wraps that lifecycle in one closure. It finalizes
the statement exactly when the iterator runs dry, which makes
breaking out of a `rows` loop early a leak, a leak the suite found
for real on its first red run: a lookup that returned from inside
the loop left the statement alive, and sqlite refused the close with
`unable to close due to unfinalized statements`, exactly as the api
documents. Plain `sqlite3_close`, not the `close_v2` variant that
defers the problem to the collector, is the deliberate choice:

#listing("lua/jit/sqlite.lua", first: 78, last: 103, caption: [the rows helper finalizes on exhaustion, close stays strict])

Column values come back through `sqlite3_column_type`, integers and
floats through `tonumber`, text through `ffi.string`, null as nil,
and the index is 0-based because the wrapper does not hide which
convention it stands on:

#listing("lua/jit/sqlite.lua", first: 142, last: 149, caption: [typed column reads])

== who owns what

Every c value in the process is cdata, a lua value carrying a c type
identity. The collector tracks cdata like any other value, and that
is the whole gc story: handles live in lua tables that outlive the
calls made through them, `ffi.string` copies c memory into lua memory
instead of aliasing it, and memory sqlite allocates is returned to
sqlite, the error string from `exec` is read then freed in the same
breath:

#listing("lua/jit/sqlite.lua", first: 60, last: 68, caption: [borrow, copy, free back to the owner])

#diagram([who owns what, two heaps and the arrows between them], length: 13pt, {
  // lua's heap and c's heap, short lines that fit their boxes
  cdraw.rect((0.5, 6.0), (8.0, 9.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.25, 8.55), [lua's heap], size: 6pt)
  cdraw.content((4.25, 7.5), [tables holding cdata], size: 6pt)
  cdraw.content((4.25, 6.5), [the gc walks them], size: 6pt)
  cdraw.rect((14.0, 6.0), (21.5, 9.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.75, 8.55), [c's heap], size: 6pt)
  cdraw.content((17.75, 7.5), [sqlite's allocations], size: 6pt)
  cdraw.content((17.75, 6.5), [handles, error text], size: 6pt)
  // the arrows: copy in, hand over
  cdraw.line((13.8, 8.3), (8.2, 8.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 8.8), [ffi.string copies], size: 6pt)
  cdraw.line((8.2, 7.0), (13.8, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 6.4), [sqlite copies it], size: 6pt)
  cdraw.content((17.75, 5.1), [exec's error string: read, then freed], size: 6pt)
  // the law
  cdraw.content((11.0, 3.7), [whoever allocates memory frees it], size: 6.5pt)
  cdraw.content((11.0, 2.5), [lua borrows and copies, never keeps an unpinned pointer], size: 6.5pt)
})

The rule the wrapper teaches is the ffi's one law: whoever allocates
memory frees it, lua borrows and copies but never keeps a c pointer
it did not pin in a table.

== two runtimes, one tree

The split rule is absolute in this repo: the lua 5.5 runner executes
the sample suites and the capstone's `run.lua`, the auto chess game,
and never loads ffi code, the LuaJIT runner executes `run-jit.lua`
from `books/lua/jit/` and never runs the 5.5 modules. `make verify`
runs them as two separate targets, `verify-lua` with the 5.5 binary,
`verify-lua-jit` with the LuaJIT binary, so a green build proves both
worlds, never a merged one.

The editor modules themselves, `doc.lua`, `edit.lua`, `lib.lua`, live
in the jit lane now, and they still pay the one line their shared
past cost them: the binary search in `doc.lua` uses `math.floor`
division instead of the 5.3 `//` operator so LuaJIT can parse the
module. Everything else in them was already 5.1 syntax. The jit suite
guards its own side of the boundary before any test runs:

#listing("lua/jit/run-jit.lua", first: 1, last: 16, caption: [refuse the wrong interpreter, refuse the missing dll, in plain english])

#diagram([two runtimes over one tree of shared modules], length: 13pt, {
  // two runner lanes
  cdraw.rect((0.5, 7.4), (10.0, 10.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.25, 9.55), [the lua 5.5 runner], size: 6pt)
  cdraw.rect((1.2, 7.7), (5.2, 8.9), fill: luma(245), radius: 0.02)
  cdraw.content((3.2, 8.3), [samples], size: 6pt)
  cdraw.rect((5.5, 7.7), (9.5, 8.9), fill: luma(245), radius: 0.02)
  cdraw.content((7.5, 8.3), [run.lua], size: 6pt)
  cdraw.rect((12.0, 7.4), (21.5, 10.0), fill: luma(235), radius: 0.02)
  cdraw.content((16.75, 9.55), [the luajit runner], size: 6pt)
  cdraw.rect((12.7, 7.7), (16.7, 8.9), fill: luma(245), radius: 0.02)
  cdraw.content((14.7, 8.3), [run-jit.lua], size: 6pt)
  cdraw.rect((17.0, 7.7), (21.0, 8.9), fill: luma(245), radius: 0.02)
  cdraw.content((19.0, 8.3), [guards first], size: 6pt)
  // the shared modules under both
  cdraw.rect((0.5, 4.6), (21.5, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 6.1), [the jit lane: doc.lua, edit.lua, lib.lua, sqlite], size: 6pt)
  cdraw.content((11.0, 5.1), [the one toll: math.floor division instead of \/\/, so 5.1 parses it], size: 6pt)
  // the build rule
  cdraw.content((11.0, 3.4), [make verify runs two targets, verify-lua and verify-lua-jit], size: 6.5pt)
  cdraw.content((11.0, 2.2), [a green build proves both worlds, never a merged one], size: 6.5pt)
})

== the editor lane gains a database

`persist-sqlite.lua` keeps the file store's one guarantee, bodies
always carry a final newline, and adds what a file cannot give:
documents by name, replacement in place, and a modification
timestamp, one table with a primary key and an upsert:

#listing("lua/jit/persist-sqlite.lua", first: 8, last: 34, caption: [schema, the final newline rule, the upsert save])

#diagram([the documents table, the store the file could not be], length: 13pt, {
  // the table with its columns
  cdraw.rect((0.5, 6.4), (21.5, 9.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 9.15), [the documents table], size: 6pt)
  cdraw.rect((1.8, 7.6), (8.4, 8.8), fill: luma(205), radius: 0.02)
  cdraw.content((5.1, 8.2), [name, primary key], size: 6pt)
  cdraw.rect((8.9, 7.6), (14.2, 8.8), fill: luma(245), radius: 0.02)
  cdraw.content((11.55, 8.2), [body], size: 6pt)
  cdraw.rect((14.7, 7.6), (20.0, 8.8), fill: luma(245), radius: 0.02)
  cdraw.content((17.35, 8.2), [modified], size: 6pt)
  // a row as it is stored
  cdraw.rect((1.8, 6.6), (8.4, 7.5), fill: luma(245), radius: 0.02)
  cdraw.content((5.1, 7.05), [notes.md], size: 6pt)
  cdraw.rect((8.9, 6.6), (14.2, 7.5), fill: luma(245), radius: 0.02)
  cdraw.content((11.55, 7.05), [one body\\n], size: 6pt)
  cdraw.rect((14.7, 6.6), (20.0, 7.5), fill: luma(245), radius: 0.02)
  cdraw.content((17.35, 7.05), [a timestamp], size: 6pt)
  // the guarantees
  cdraw.content((11.0, 5.2), [upsert replaces in place, the key decides], size: 6.5pt)
  cdraw.content((11.0, 4.0), [bodies always carry a final newline, carried over from the file store], size: 6.5pt)
  cdraw.content((11.0, 2.8), [lookups run their iterator to the end, the lesson of the red run], size: 6.5pt)
})

The lookups learned from the red run and run their iterator to the
end, then reopen semantics are the test's job: close the store, open
the same file again, and demand the same documents back, empty
document included:

#listing("lua/jit/persist-sqlite.lua", first: 36, last: 53, caption: [primary key lookups that never break the loop])
#listing("lua/jit/run-jit.lua", first: 91, last: 107, caption: [save, close, reopen the file, demand equality])

#callout("note", "what the ffi does not cover", [
  This wrapper is a teaching surface, not a driver. There is no
  blob binding, no collation hooks, no progress handler, no
  `busy_timeout` wiring, and integers round through lua doubles, so
  64-bit values beyond 2^53 lose digits on their way back. The
  suites never store such values, and a real driver would keep
  int64 columns as cdata end to end instead of converting.
])

sources: luajit.org luajit ffi semantics and tutorial pages, sqlite.org
c interface reference for the seventeen declared functions, accessed
2026-09-10, plus this tree's `tools/sqlite/probe.lua` from the build
phase. All behavior verified live with luajit 2.1 rolling and sqlite
3.53.4, 10 tests green through `make verify-lua-jit`, now from
`books/lua/jit/`, the auto chess capstone's 34 tests green under 5.5
through `make verify-lua`.
