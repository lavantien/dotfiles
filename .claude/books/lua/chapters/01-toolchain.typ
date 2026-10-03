#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= toolchain

Lua 5.5.0 shipped on 22 december 2025 and the current 5.5.1, a bug fix
release, on 3 august 2026. This book pins 5.5.1, built from the official
source tarball into `tools/lua55/build/bin/`, so every claim in every
chapter runs against the same interpreter binary that `make verify-lua`
invokes. The first test in the first sample suite pins `_VERSION` to
the family name, and the `-v` banner with the exact point release is a
later test in the same suite.

#diagram([the 5.5 release line, and the verify loop that pins every claim to one binary], length: 13pt, {
  // release timeline
  cdraw.line((1.0, 5.4), (21.0, 5.4), stroke: luma(100))
  cdraw.circle((3.5, 5.4), radius: 0.1, fill: luma(100))
  cdraw.circle((10.5, 5.4), radius: 0.1, fill: luma(100))
  cdraw.content((3.5, 6.1), [5.5.0], size: 6pt)
  cdraw.content((3.5, 4.7), [22 december 2025], size: 6pt)
  cdraw.content((10.5, 6.1), [5.5.1], size: 6pt)
  cdraw.content((10.5, 4.7), [3 august 2026, bug fix], size: 6pt)
  cdraw.content((16.8, 6.1), [this book pins 5.5.1], size: 6.5pt)
  cdraw.line((13.6, 6.1), (15.2, 6.1), stroke: luma(220), mark: (end: ">"))
  // the verify loop below the timeline
  cdraw.line((10.5, 4.2), (10.5, 3.3), stroke: luma(100), mark: (end: ">"))
  let box(x0, x1, txt) = {
    cdraw.rect((x0, 1.5), (x1, 2.5), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 2.0), txt, size: 6pt)
  }
  box(0.5, 5.5, [every claim in every chapter])
  box(7.5, 13.5, [one binary, tools/lua55])
  box(15.5, 21.5, [make verify-lua, #linebreak() nonzero on any failure])
  cdraw.line((5.5, 2.0), (7.5, 2.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.5, 2.0), (15.5, 2.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.5, 1.5), (18.5, 0.7), (3.0, 0.7), (3.0, 1.5), stroke: luma(220), mark: (end: ">"))
})

Lua the language is 8 types, 23 keywords in 5.5 (`global` included,
22 before it), and one associative array
constructor. The release highlights for 5.5 over 5.4 are four: global
variable declarations with the new `global` statement, named vararg
tables, a more compact internal array representation, and major
collections inside the generational collector done incrementally. Each
of those gets a full chapter treatment later; the toolchain chapter
establishes how this book proves anything at all.

== the project

Samples live in `lua/samples/`, one module per chapter, each returning
a list of named tests. There is no npm, no sdk, no test framework: the
harness is 40 lines of lua, registry through exit code.

#listing("lua/samples/run.lua", first: 1, last: 40, caption: [the whole test runner])

#flow(
  [the runner pipeline, chapter modules through pcall to the exit code],
  node((0, 0), [make verify-lua]),
  node((-2.4, 1.7), [samples runner]),
  node((2.4, 1.7), [capstone runner]),
  node((-2.4, 3.4), [pcall each test]),
  node((2.4, 3.4), [pcall each test]),
  node((0, 5.2), [any failure: #linebreak() nonzero exit]),
  edge((0, 0), (-2.4, 1.7), "-|>"),
  edge((0, 0), (2.4, 1.7), "-|>"),
  edge((-2.4, 1.7), (-2.4, 3.4), "-|>", label: [each \{name, fn\}]),
  edge((2.4, 1.7), (2.4, 3.4), "-|>", label: [each \{name, fn\}]),
  edge((-2.4, 3.4), (0, 5.2), "-|>", label: [report per chapter]),
  edge((2.4, 3.4), (0, 5.2), "-|>"),
)

`make verify-lua` runs this file with the pinned interpreter from the
samples directory and again from the capstone directory, and make fails
if either exits nonzero. Chapters register themselves in the runner's
list as they are written, the same grow-the-map discipline the other
books use.

Assertions come from a shared helper module, deep comparing tables and
reporting at the failing line:

#listing("lua/samples/lib.lua", first: 17, last: 47, caption: [deep equality, level 2 error reporting, and the error-capturing throws helper])

== the interpreter surface

The standalone `lua` program is the host this book uses: it reads a
chunk from a file argument, from `-e` strings, or from stdin in the
read eval print loop. The suite's first probes pin identity and the
two number subtypes, since almost every later chapter leans on the
integer versus float split:

#listing("lua/samples/ch01_toolchain.lua", first: 8, last: 19, caption: [subtype split and 64 bit wraparound])

#flow(
  [how the standalone interpreter picks its chunk, with arg and package.path around it],
  node((0, 0), [lua invocation]),
  node((0, 1.6), [file argument?]),
  node((-2.2, 1.6), [load and run the file]),
  node((0, 3.2), [-e string?]),
  node((-2.2, 3.2), [run the string]),
  node((0, 4.8), [stdin, repl]),
  node((2.8, 1.6), [arg\[0\] and args]),
  node((2.8, 3.2), [package.path]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (-2.2, 1.6), "-|>", label: [yes]),
  edge((0, 1.6), (0, 3.2), "-|>", label: [no]),
  edge((0, 3.2), (-2.2, 3.2), "-|>", label: [yes]),
  edge((0, 3.2), (0, 4.8), "-|>", label: [no]),
  edge((2.8, 1.6), (1.0, 1.6), "--|>"),
  edge((2.8, 3.2), (-1.0, 3.2), "--|>"),
)

`arg[0]` names the running script, and the `arg` table carries command
line arguments around it, which is how the runner could tell you which
file failed. `package.path` decides what `require` finds; the runner
prepends `./?.lua` so chapter modules and `lib` resolve from the
samples directory regardless of where lua was invoked.

#callout("note", "one binary, two shells", [
  `lua.exe -v` prints the banner and exits. The suite shells out to it
  through `io.popen` with a path relative to the samples directory,
  which doubles as the book's proof that `io.popen` works on a plain
  windows build. `luac.exe` beside it precompiles and disassembles,
  and #xref-to("lua", "capi") uses it heavily.
])

== loading chunks

`load` is the boundary between text and function. It takes source or
bytecode, a chunk name for error messages, a mode that pins which form
is acceptable, and since 5.2 an explicit environment table that free
names resolve against:

#listing("lua/samples/ch01_toolchain.lua", first: 25, last: 40, caption: [environment argument, mode gate, and a bytecode round trip])

#diagram([load as the text to function boundary, the mode gate and the dump round trip], length: 13pt, {
  // two source forms on the left
  cdraw.rect((0.0, 4.1), (4.2, 5.1), fill: luma(235), radius: 0.02)
  cdraw.content((2.1, 4.6), [text chunk], size: 6pt)
  cdraw.rect((0.0, 0.7), (4.2, 1.7), fill: luma(235), radius: 0.02)
  cdraw.content((2.1, 1.2), [string.dump bytes], size: 6pt)
  // the load box, four arguments then the mode gate
  cdraw.rect((6.2, 0.5), (13.8, 5.0), fill: luma(205), radius: 0.02)
  cdraw.content((10.0, 4.5), [load(chunk, name,], size: 6pt)
  cdraw.content((10.0, 3.4), [mode, env)], size: 6pt)
  cdraw.content((10.0, 2.3), [mode t: text only,], size: 6pt)
  cdraw.content((10.0, 1.2), [b binary, bt both], size: 6pt)
  cdraw.line((4.2, 4.6), (6.2, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.2, 1.2), (6.2, 2.4), stroke: luma(100), mark: (end: ">"))
  // outcomes
  cdraw.rect((16.0, 3.3), (19.6, 4.3), fill: luma(235), radius: 0.02)
  cdraw.content((17.8, 3.8), [a function], size: 6pt)
  cdraw.content((17.8, 2.6), [or nil + error], size: 6pt)
  cdraw.line((13.8, 3.8), (16.0, 3.8), stroke: luma(100), mark: (end: ">"))
  // the dump round trip above
  cdraw.line((19.6, 4.6), (19.6, 5.5), (8.0, 5.5), (4.6, 1.5), (4.2, 1.3), stroke: luma(220), mark: (end: ">"))
  cdraw.content((13.0, 5.9), [string.dump serializes back, undump is version locked], size: 6.5pt)
  // the env argument
  cdraw.content((12.0, -0.1), [env is the table free names resolve against], size: 6.5pt)
})

`string.dump` serializes a function back to binary and `load` accepts
it with mode `"b"`, rejects it with mode `"t"`, and accepts either
with the default mode `"bt"`. Undumping is version locked: a 5.4 dump
will not load in 5.5 and the manual says so, which is why the book
never treats bytecode as a distribution format.

sources: lua.org manual 5.5 sections 1, 6.2 (assert, load),
lua.org/news.html release dates, lua.org/versions.html 5.5 features,
accessed 2026-09-08. Interpreter behavior verified live with
lua 5.5.1 built from the official tarball, 10 tests green through
`make verify-lua`.
