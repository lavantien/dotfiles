#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= a c host: allegro 5 with lua embedded

Chapter 14 drove lua from c on a console. A game wants the same
embedding with a clock, a window, and an event source, and that is
what a host library is for: this chapter embeds lua 5.5 in an
allegro 5 program, the c side owning time and input, the lua side
owning the game. Everything is built by the tree itself, one mingw
gcc 15.2 building `lua55.dll` and linking the same-flavored allegro
prebuilt, and the contract the two sides speak is designed to run
with no window at all.

#xref-to("lua", "capi") built the vocabulary, the stack, protected
calls, registered functions, userdata, references. This chapter
spends it.

== why a c host owns time

Lua has no clock of its own and no opinion about frame rates. The
language does not even guarantee that a busy loop yields, so
scheduling belongs to the embedder: the c host creates a timer,
waits for it, and only then tells lua a tick happened. The lua side
receives a fixed `dt`, never measures wall time, and stays
deterministic, the property #xref-to("lua", "profiling") needed and
the capstone depends on:

#listing("lua/samples/ch18_allegro.lua", first: 98, last: 106, caption: [one update per tick, the fixed dt asserted, no wall clock anywhere])

#diagram([who owns what in an embedded game], length: 13pt, {
  // the host's column and lua's column
  cdraw.rect((0.5, 7.4), (10.5, 10.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 9.85), [the c host owns], size: 6pt)
  cdraw.content((5.5, 8.75), [time, input, the window, the render], size: 6pt)
  cdraw.content((5.5, 7.85), [main never returns to lua], size: 6pt)
  cdraw.rect((11.5, 7.4), (21.5, 10.4), fill: luma(205), radius: 0.02)
  cdraw.content((16.5, 9.85), [the lua side owns], size: 6pt)
  cdraw.content((16.5, 8.75), [the game state, the rules, the bot], size: 6pt)
  cdraw.content((16.5, 7.85), [pure data in, pure data out], size: 6pt)
  // the seam
  cdraw.line((10.7, 8.9), (11.3, 8.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.3, 8.2), (10.7, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 9.4), [dt], size: 6pt)
  cdraw.content((11.0, 7.6), [draw calls], size: 6pt)
  // the laws
  cdraw.content((11.0, 5.6), [a fixed dt and a seeded rng make runs reproducible], size: 6.5pt)
  cdraw.content((11.0, 4.4), [lua never waits, it is always the host that wakes it], size: 6.5pt)
  cdraw.content((11.0, 3.2), [the same game code runs headless, the capstone's whole test story], size: 6.5pt)
  cdraw.content((11.0, 2.0), [chapter 14's stack protocol carries every crossing], size: 6.5pt)
})

== the vendored toolchain

Allegro ships official mingw prebuilts. `make allegro-tools` fetches
the pinned asset, checks its sha256, unpacks the monolith dll, its
import library, and the headers into gitignored
`tools/allegro/build/`, then compiles and runs a probe that asserts
the linked version:

#snippet("asset  allegro-x86_64-w64-mingw32-gcc-15.2.0-posix-seh-dynamic-5.2.11.3.zip\nsha256 f9a02e841d956b05f032f8dca70dab3972ffd0972a94ea0c4453e0190c0429a0\nrelease  5.2.11.3, 2026-02-09, github.com/liballeg/allegro5/releases\nprobe    linked allegro 5.2.11.4", lang: "text")

The version byte is a measured oddity worth pinning: the 5.2.11.3
release asset reports itself as 5.2.11.4 through
`al_get_allegro_version()`, the packed integer's low revision byte
set to 4 by the release tooling, so the probe asserts the top three
bytes, 5.2.11, and the acquisition script records the fourth as
printed. The asset was built by gcc 15.2.0 posix-seh, the same
runtime flavor as this repo's documented compiler, which is why one
compiler serves both libraries:

#diagram([the vendored toolchain, two libraries one compiler], length: 13pt, {
  // two source lanes into one gcc
  cdraw.rect((0.5, 8.0), (9.5, 10.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 10.05), [lua 5.5.1 source], size: 6pt)
  cdraw.content((5.0, 9.15), [tools/build-lua55.sh, #linebreak() make mingw], size: 6pt)
  cdraw.content((5.0, 8.45), [lua55.dll, lua.exe, luac.exe], size: 6pt)
  cdraw.rect((12.5, 8.0), (21.5, 10.6), fill: luma(235), radius: 0.02)
  cdraw.content((17.0, 10.05), [allegro 5.2.11.3 prebuilt], size: 6pt)
  cdraw.content((17.0, 9.15), [tools/build-allegro.sh, #linebreak() sha256 pinned], size: 6pt)
  cdraw.content((17.0, 8.45), [allegro\_monolith-5.2.dll, headers], size: 6pt)
  cdraw.rect((10.0, 6.0), (12.0, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 6.6), [gcc 15.2], size: 6pt)
  cdraw.content((11.0, 5.4), [posix-seh], size: 6.5pt)
  cdraw.line((5.0, 7.8), (10.4, 6.6), stroke: luma(120), mark: (end: ">"))
  cdraw.line((17.0, 7.8), (11.6, 6.6), stroke: luma(120), mark: (end: ">"))
  // the measured facts
  cdraw.content((11.0, 4.0), [the release asset reports revision byte 4, probe pins 5.2.11], size: 6.5pt)
  cdraw.content((11.0, 2.8), [same abi flavor, no second runtime to reconcile], size: 6.5pt)
  cdraw.content((11.0, 1.6), [everything lands in gitignored tools/, nothing ships], size: 6.5pt)
})

== linking two mingw libraries

The host links both libraries in one command, `-llua55
-lallegro_monolith`, against `lua55.dll` built in-tree and the
monolith import library `liballegro_monolith.dll.a` from the
prebuilt. The monolith folds allegro's addons into one dll, so one
flag covers core, primitives, font, and image. The runtime dll set
is short because every dependency, freetype, zlib, png, the audio
codecs, is statically baked into the monolith already; what loads
besides it is only the mingw runtime:

#snippet("allegro_monolith-5.2.dll\nlibgcc_s_seh-1.dll\nlibwinpthread-1.dll\nlibstdc++-6.dll", lang: "text")

Those three runtime dlls are not in the allegro zip and scoop's gcc
ships none, so the acquisition script locates them on the mingw
runtime already on PATH and stages them beside the monolith, which
also sidesteps a windows trap this repo has met before: the loader
searches the exe's own directory first, so no PATH edit is needed
at all. `make verify-lua-c` runs every sample with the two bin
directories prepended in PowerShell, where the semicolon PATH needs
no cygpath games.

#flow(
  [one host binary, two libraries, the dlls it loads],
  node((0, 0), [host.exe, #linebreak() gcc 15.2 built]),
  node((-3.0, 1.8), [-llua55, #linebreak() lua55.dll, built in tree]),
  node((0, 1.8), [-lallegro\_monolith, #linebreak() the import lib]),
  node((3.0, 1.8), [the loader, #linebreak() exe dir first, then PATH]),
  node((0, 3.6), [the monolith: addons and deps #linebreak() baked in, statically]),
  node((3.0, 3.6), [the mingw runtime trio, #linebreak() staged by the script]),
  edge((0, 0), (-3.0, 1.8), "-|>"),
  edge((0, 0), (0, 1.8), "-|>"),
  edge((-3.0, 1.8), (0, 3.6), "-|>", bend: 20deg),
  edge((0, 1.8), (0, 3.6), "-|>"),
  edge((3.0, 1.8), (3.0, 3.6), "-|>"),
)

== the event loop skeleton

The loop is a timer, a queue, and a wait. `al_create_timer` fixes
the tick rate, the timer's event source is registered on one queue,
and `al_wait_for_event` blocks the host until the next tick, which
is the entire scheduling story. No display is needed for any of it,
the skeleton below runs in the verify suite with no window:

#listing("lua/samples-c/src/Ch18/host_skeleton.c", first: 37, last: 46, caption: [the clock, its queue, and the registration])

Each tick the host digs the lua game table out of the registry, the
chapter 14 reference trick, and calls its `update` with `self` and
the fixed `dt`, protected:

#listing("lua/samples-c/src/Ch18/host_skeleton.c", first: 48, last: 64, caption: [wait, drain, call lua per tick])

#diagram([the loop's shape, timer to queue to lua and back], length: 13pt, {
  // the cycle as a ring
  cdraw.rect((0.5, 7.6), (6.5, 9.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 8.7), [a 64 hz timer], size: 6pt)
  cdraw.content((3.5, 7.9), [al\_create\_timer], size: 6pt)
  cdraw.line((6.7, 8.7), (8.9, 8.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((9.1, 7.6), (13.6, 9.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.35, 8.7), [the queue], size: 6pt)
  cdraw.content((11.35, 7.9), [al\_wait\_event], size: 6pt)
  cdraw.line((13.8, 8.7), (16.0, 8.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.2, 7.6), (21.5, 9.8), fill: luma(235), radius: 0.02)
  cdraw.content((18.85, 8.7), [update(self, dt)], size: 6pt)
  cdraw.content((18.85, 7.9), [a pcall, per tick], size: 6pt)
  cdraw.line((18.85, 9.8), (18.85, 10.8), stroke: luma(100))
  cdraw.line((3.5, 10.8), (18.85, 10.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.5, 9.8), (3.5, 10.8), stroke: luma(100))
  cdraw.content((11.0, 11.2), [the next tick wakes it again], size: 6pt)
  // the guarantees
  cdraw.content((11.0, 5.8), [64 events became 64 updates, asserted in the suite], size: 6.5pt)
  cdraw.content((11.0, 4.6), [the game table is pinned with luaL\_ref between ticks], size: 6.5pt)
  cdraw.content((11.0, 3.4), [the timer's own count is the cross check, 64 and 64], size: 6.5pt)
  cdraw.content((11.0, 2.2), [no display anywhere, a window is an addon to this loop], size: 6.5pt)
})

== events to commands

Input is the second thing the host owns, and the design decision
that makes the capstone testable is translating events into plain
command tables the moment they arrive. A command is a table with a
string `type` and a fixed shape per type, and it enters the game
through one fifo queue with validation at the door. The pure lua
sample below is the whole contract, written and run before any
windowed code exists, so the c host must satisfy lua's tests rather
than the other way around:

#listing("lua/samples/ch18_allegro.lua", first: 9, last: 32, caption: [the command shapes, and the push that validates them])

#listing("lua/samples/ch18_allegro.lua", first: 47, last: 73, caption: [the fake host, scripted events, one update and one draw a tick])

The automation seam falls out for free: whatever pushes a command,
an allegro event translated in c, or a scripted driver in lua, the
game cannot tell apart, and the suite pins exactly that:

#listing("lua/samples/ch18_allegro.lua", first: 129, last: 136, caption: [identical commands, whatever pushed them])

#flow(
  [two producers, one queue, one consumer],
  node((0, 0), [allegro events, #linebreak() keys, clicks, close]),
  node((0, 1.8), [the c host translates, #linebreak() lua\_createtable per command]),
  node((-2.9, 3.6), [queue.push, #linebreak() validated at the door]),
  node((2.9, 1.8), [a scripted driver, #linebreak() the same tables, from lua]),
  node((0, 5.4), [queue.drain once a tick]),
  node((0, 7.0), [the game systems, #linebreak() blind to the source]),
  edge((0, 0), (0, 1.8), "-|>"),
  edge((0, 1.8), (-2.9, 3.6), "-|>"),
  edge((2.9, 1.8), (-2.9, 3.6), "-|>", bend: -25deg),
  edge((-2.9, 3.6), (0, 5.4), "-|>"),
  edge((0, 5.4), (0, 7.0), "-|>"),
)

== lua draws while c renders

Drawing is the mirror of commands: the host owns the target and the
frame, lua receives primitives as registered c functions, exactly
the `luaL_Reg` table of #xref-to("lua", "capi"). Each primitive
draws onto whatever target the host set, counts as it crosses, and
knows nothing about displays:

#listing("lua/samples-c/src/Ch18/draw_host.c", first: 32, last: 46, caption: [clear and rect, drawing is registered functions])

#listing("lua/samples-c/src/Ch18/draw_host.c", first: 53, last: 74, caption: [text and size, the api table lua sees])

The frame is the host's to finish, `al_flip_display` is c's call,
and the sample proves the drawing really happened by reading pixels
back from the target and comparing exact bytes:

#listing("lua/samples-c/src/Ch18/draw_host.c", first: 104, last: 110, caption: [exact colors read back from the target])

== headless by design

Nothing above needs a window. The draw sample targets a memory
bitmap, the loop sample needs only a timer, and the fake host
sample runs the entire contract in pure lua with a tick counter for
a clock. That is a design rule, not an accident: game logic never
touches allegro, draw primitives degrade to cheap calls on an
offscreen target, and the same lua runs in the verify suite and in
front of a display. The capstone leans on this completely, its
whole test story is the game headless while the human side is
automated through the command queue.

#listing("lua/samples/ch18_allegro.lua", first: 138, last: 152, caption: [a full loop with no window, one simulated second])

#diagram([headless by design, what a window adds and what it does not], length: 13pt, {
  // the headless lane and the windowed lane sharing the core
  cdraw.rect((0.5, 7.0), (21.5, 10.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 9.5), [the game in lua: state, rules, bot, the command queue], size: 6pt)
  cdraw.content((11.0, 8.5), [never touches allegro, runs under lua.exe alone], size: 6pt)
  cdraw.content((11.0, 7.6), [make verify-lua, 229 checks], size: 6pt)
  cdraw.rect((0.5, 4.0), (9.5, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 5.5), [headless lane], size: 6pt)
  cdraw.content((5.0, 4.65), [a memory bitmap target, #linebreak() make verify-lua-c], size: 6pt)
  cdraw.rect((12.5, 4.0), (21.5, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.0, 5.5), [windowed lane], size: 6pt)
  cdraw.content((17.0, 4.65), [a display, al\_flip\_display, #linebreak() the capstone host], size: 6pt)
  cdraw.line((5.0, 6.2), (5.0, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.0, 6.2), (17.0, 6.8), stroke: luma(100), mark: (end: ">"))
  // the laws
  cdraw.content((11.0, 2.8), [the same lua on both lanes, no build flag, no branch in game code], size: 6.5pt)
  cdraw.content((11.0, 1.6), [draw primitives degrade, they never become errors], size: 6.5pt)
})

sources: liballeg.org allegro 5 api docs and the 5.2.11.3 release
page at github.com/liballeg/allegro5/releases, accessed 2026-09-21;
the lua.org manual sections chapter 14 already pinned. All facts
measured in-tree: the asset name and sha256 frozen in
`tools/build-allegro.sh`, the linked version, the dll set, and the
loop counts printed by the probe and the verify suite. 6 tests in
`samples/ch18_allegro.lua` green through `make verify-lua`, the
samples suite at 229 checks, 2 c samples with 20 checks green
through `make verify-lua-c`.
