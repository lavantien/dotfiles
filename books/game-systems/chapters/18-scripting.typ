#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= embedded scripting: hosting lua

Seventeen chapters of systems, and every behavior in them is compiled
c\#. That is the right default: compiled code is fast, typed, and
versioned with the binary that shipped it. But a game is also a pile
of decisions somebody wants to change without a recompile, the
designer tuning enemy weights, the modder rewriting a rule, the map
author scripting a boss intro. The industry answer is an embedded
script runtime, and this chapter builds a real one: the campaign
keeps its engine, its state, and its randomness, lua answers exactly
one kind of question, which choice. The chapter's rule runs through
every section: scripts own policy, never state.

== why games embed a script runtime

The recompile cycle is the whole argument. A designer iterating on
how much a boss values desperation waits minutes per change in
compiled code and seconds in a script, and a modder never has the
build at all. The cost is everything this book spent 17 chapters
defending: determinism, replay exactness, the state hash. A script
that reads the clock, rolls its own dice, or mutates engine state
directly breaks all three. So the embedding draws a hard line. The
engine keeps the loop, every byte of state, the named rng streams of
chapter 11, and the save file. The script receives facts as plain
values, answers with an index or a command, and cannot reach
anything else. Inside that line a script is a policy function like
any other, and the equivalence proofs later in this chapter hold it
to the same standard as the compiled policy it sits beside.

#diagram([the embedding boundary: the engine keeps everything, the script only answers], length: 13pt, {
  cdraw.rect((1, 0.0), (23, 8.4), stroke: luma(120), radius: 0.05)
  cdraw.content((12, 7.9), [the engine keeps], size: 6.5pt)
  cdraw.rect((1.8, 5.4), (11.0, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 6.3), [the tick loop and turn flow], size: 6pt)
  cdraw.rect((12.0, 5.4), (22.2, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 6.3), [every byte of game state], size: 6pt)
  cdraw.rect((1.8, 3.4), (11.0, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 4.3), [the named rng streams, chapter 11], size: 6pt)
  cdraw.rect((12.0, 3.4), (22.2, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 4.3), [the save file and the replay log], size: 6pt)
  cdraw.line((1.8, 2.6), (22.2, 2.6), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((12, 2.0), [the script gets], size: 6.5pt)
  cdraw.rect((4.0, 0.4), (11.4, 1.5), fill: luma(248), radius: 0.02)
  cdraw.content((7.7, 0.95), [a table of facts, one roll], size: 6pt)
  cdraw.rect((12.6, 0.4), (20.0, 1.5), fill: luma(248), radius: 0.02)
  cdraw.content((16.3, 0.95), [answers: an index, a command], size: 6pt)
})

== the host in c\#

#listing("game-systems/samples/src/Ch18/LuaHost.cs", first: 12, last: 43, caption: [the smallest useful host: evaluate, read a global, call a function, hand one back])

The host is nlua 1.7.9 from nuget, riding keralua 1.4.9, the
minimum version nlua asks for, which embeds lua 5.4 and ships the
native runtime as `lua54.dll` under
`runtimes/win-x64/native`, with linux and macos libraries beside it,
so one package reference runs the same interpreter on all of them.
The api surface is four moves: `DoString` evaluates a chunk and returns
whatever it returned as an `object[]`, the indexer reads and writes
globals, `GetFunction` plus `LuaFunction.Call` invokes a script
function with arguments, and assigning a delegate to the indexer
hands a c\# function to the script. The lua book teaches the other
side of this seam, the stack discipline every host rides, in
#xref-to("lua", "capi"), and closes with a c host of its own over
allegro 5 in #xref-to("lua", "allegro").

#diagram([the host's four moves over one nlua state, the stack shape the lua book teaches in c], length: 13pt, {
  cdraw.rect((0.8, 0.8), (5.6, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((3.2, 7.5), [the nlua state,#linebreak()lua 5.4], size: 6.5pt)
  cdraw.rect((1.4, 5.8), (5.0, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.2, 6.2), [the globals], size: 6pt)
  cdraw.rect((1.4, 4.3), (5.0, 4.85), stroke: luma(120), radius: 0.02)
  cdraw.rect((1.4, 3.65), (5.0, 4.2), stroke: luma(120), radius: 0.02)
  cdraw.rect((1.4, 3.0), (5.0, 3.55), stroke: luma(120), radius: 0.02)
  cdraw.content((3.2, 2.5), [the stack], size: 6pt)
  cdraw.rect((7.4, 6.35), (22.4, 7.85), fill: luma(235), radius: 0.02)
  cdraw.content((14.9, 7.1), [`DoString` runs a chunk and returns#linebreak()whatever it returned, as `object[]`], size: 6pt)
  cdraw.line((7.4, 7.1), (5.6, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.4, 4.55), (22.4, 6.05), fill: luma(235), radius: 0.02)
  cdraw.content((14.9, 5.3), [the indexer reads and writes the globals], size: 6pt)
  cdraw.line((7.4, 5.3), (5.6, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.4, 2.75), (22.4, 4.25), fill: luma(235), radius: 0.02)
  cdraw.content((14.9, 3.5), [`GetFunction` plus `LuaFunction.Call` invokes#linebreak()a script function, with arguments], size: 6pt)
  cdraw.line((7.4, 3.5), (5.6, 3.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.4, 0.95), (22.4, 2.45), fill: luma(235), radius: 0.02)
  cdraw.content((14.9, 1.7), [a delegate assigned to the indexer hands#linebreak()a c\# function to the script], size: 6pt)
  cdraw.line((7.4, 1.7), (5.6, 1.7), stroke: luma(100), mark: (end: ">"))
})

The marshaling edges are measured, not promised. A global the script
set to an integer reads back through the indexer as a `double`. The
same value returned from a called function arrives as a `long`.
Tables come back as `LuaTable`. nlua documents none of this in its
readme, so the tests pin it: evaluate `21 * 2`, read the global,
call an `add` that returns an integer sum, and register a delegate
the script calls with a string. When the capstone needs every number
to stay a lua 5.4 integer in both directions, it steps past this
object layer entirely, and the last section of this chapter shows
why.

== the sandbox

#listing("game-systems/samples/src/Ch18/Sandbox.cs", first: 12, last: 24, caption: [the sandbox is removal, not wrapping: nil the shelves, keep arithmetic])

#listing("game-systems/samples/src/Ch18/Scripts/sandbox_probe.lua", first: 4, last: 17, caption: [the probe asks each removed library for something real and reports false under pcall])

The sandbox works by deletion because nothing else works: a script
cannot reach what was never granted. `io`, `os`, `debug`, `package`,
and `load` go nil, and `math` keeps everything except `random` and
`randomseed`, which are removed by name. Randomness is the point of
that last cut. Chapter 11 gave the campaign named streams so a
replay draws the same futures, and a script calling `math.random`
would fork a second, invisible source of chance that no seed
reproduces. The probe proves absence the only honest way, by asking
each removed library for something real inside `pcall` and asserting
every answer fails. The sandbox shape is the one the lua book
teaches among its #xref-to("lua", "idioms"), and it is the same
shape warcraft iii ships, stripped shelves and all, as the
comparison below records.

#diagram([what the script sees: arithmetic and tables, nothing that touches the world], length: 13pt, {
  cdraw.content((7.0, 8.2), [kept], size: 6.5pt)
  cdraw.content((17.4, 8.2), [nil], size: 6.5pt)
  cdraw.line((0.8, 7.8), (22.4, 7.8), stroke: luma(220))
  cdraw.rect((1.6, 5.6), (11.6, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.6, 6.4), [string, table, utf8], size: 6pt)
  cdraw.rect((1.6, 3.8), (11.6, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.6, 4.6), [math, minus random and randomseed], size: 6pt)
  cdraw.rect((1.6, 2.0), (11.6, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((6.6, 2.8), [integers, floor division, pure functions], size: 6pt)
  cdraw.rect((13.0, 4.4), (22.4, 7.2), fill: luma(248), radius: 0.02)
  cdraw.content((17.7, 5.8), [io, os, debug, package, load], size: 6pt)
  cdraw.rect((13.0, 2.0), (22.4, 3.8), fill: luma(248), radius: 0.02)
  cdraw.content((17.7, 2.9), [math.random, math.randomseed], size: 6pt)
  cdraw.content((12.0, 0.8), [what was never granted does not exist], size: 6pt, fill: luma(100))
})

== events in, decisions out

#listing("game-systems/samples/src/Ch18/HookLoop.cs", first: 15, last: 41, caption: [the host owns the loop and the rng, the hook is a pure function called once per decision])

#listing("game-systems/samples/src/Ch18/Scripts/hooks.lua", first: 1, last: 12, caption: [the policy: state and one roll in, one command out, no other source of chance])

The loop never crosses the seam. Per decision the c\# side draws one
roll from its splitmix64 stream, builds a fresh table of `turn`,
`health`, and `roll`, calls `on_decide` exactly once, and applies
the command string it gets back. There are no coroutines and no
script-side state, so the hook is a function of its arguments and
nothing else, which is what makes the replay story survive the
embedding: two hosts seeded the same walk the same 25 decisions, and
the same seed with different health inputs walks differently. The
thresholds in `hooks.lua` are ordinary policy, heal below 30 health
when the roll is under 60, open with a power shot early, and editing
them changes behavior without touching the engine or any test that
does not assert the policy itself.

#flow(
  [one decision, end to end: the host supplies the roll, lua only answers],
  node((0, 0), [roll plus state table]),
  node((2.4, 0), [on_decide]),
  node((4.4, 0), [command string]),
  node((6.4, 0), [engine applies]),
  edge((0, 0), (2.4, 0), "-|>"),
  edge((2.4, 0), (4.4, 0), "-|>"),
  edge((4.4, 0), (6.4, 0), "-|>"),
)

== warcraft iii reforged: lua in the world editor

Warcraft iii added lua to its world editor in patch 1.31, whose
official notes carry the line "(Beta) Added Lua as a supported
scripting language." The notes survive as an archived mirror on
warcraft.wiki.gg because the original blizzard forum thread did not
survive the 2024 forum migration. The patch reached the public test
realm on April 24, 2019 and went live May 28, 2019, and the notes
are titled as the last major patch for classic before reforged: the
reforged line starts at 1.32.0 and shipped January 28, 2020. The
language is a per-map either-or, chosen in the editor under
`Scenario` > `Map Options` > `Script Language`, and the notes say
maps save in the selected language, so a map is jass or lua, never
both, and a map with custom script must disable its custom triggers
before converting.

Around the pinned notes sits a community record, and this chapter
labels it as such wherever it leans on it. The embedded version is
community-reported as lua 5.3, "a modified version of 5.3.4" in the
ptr thread, with no blizzard statement existing either way. The
engine's natives, `CreateUnit`, `GetTriggerUnit`, the `Blz` family,
are exposed as plain global lua functions out of the classic
`common.j` api, per hive workshop guides whose code calls them
directly. The sandbox is community-documented too: `os` is cut down
to `clock`, `date`, `time`, and `difftime`, `io`, `file`, `package`,
and `debug` are disabled, and the `collectgarbage` functions were
removed because influencing the collector could desync a match.
Determinism is the same worry this book's chapter 11 and chapter 12
answer with streams and input logs. Warcraft iii is lockstep
multiplayer and every client runs the map script, so the community
rules around `GetLocalPlayer` read like a desync catalog: local code
must not touch net traffic or shared state, and iterating a table
with unordered `pairs` can land differently per client and desync
the match. The official notes share the mindset, recording that the
editor stopped saving file times to keep maps deterministic.

#diagram([warcraft iii: one script language per map, natives as globals, shelves stripped], length: 13pt, {
  cdraw.content((2.9, 6.9), [language], size: 6pt, anchor: "east")
  cdraw.rect((4.0, 6.28), (7.6, 7.52), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.9), [jass], size: 6pt)
  cdraw.content((8.15, 6.9), [or], size: 6pt)
  cdraw.rect((8.7, 6.28), (12.3, 7.52), fill: luma(235), radius: 0.02)
  cdraw.content((10.5, 6.9), [lua], size: 6pt)
  cdraw.rect((13.1, 6.28), (22.6, 7.52), fill: luma(235), radius: 0.02)
  cdraw.content((17.85, 6.9), [set per map in map options,#linebreak()custom triggers off to convert], size: 6pt)
  cdraw.content((2.9, 5.2), [the natives], size: 6pt, anchor: "east")
  cdraw.rect((4.0, 4.58), (16.4, 5.82), fill: luma(235), radius: 0.02)
  cdraw.content((10.2, 5.2), [the engine's natives, `CreateUnit`,#linebreak()`GetTriggerUnit`, the `Blz` family], size: 6pt)
  cdraw.rect((17.2, 4.58), (22.6, 5.82), fill: luma(248), radius: 0.02)
  cdraw.content((19.9, 5.2), [plain globals#linebreak()from `common.j`], size: 6pt)
  cdraw.content((2.9, 3.5), [the sandbox], size: 6pt, anchor: "east")
  cdraw.rect((4.0, 2.88), (11.2, 4.12), fill: luma(235), radius: 0.02)
  cdraw.content((7.6, 3.5), [`os` keeps `clock`, `date`,#linebreak()`time`, `difftime`], size: 6pt)
  cdraw.rect((12.0, 2.88), (22.6, 4.12), fill: luma(248), radius: 0.02)
  cdraw.content((17.3, 3.5), [`io`, `file`, `package`,#linebreak()`debug` off, `collectgarbage` removed], size: 6pt)
  cdraw.content((2.9, 1.8), [lockstep], size: 6pt, anchor: "east")
  cdraw.rect((4.0, 1.18), (10.8, 2.42), fill: luma(235), radius: 0.02)
  cdraw.content((7.4, 1.8), [every lockstep client#linebreak()runs the map script], size: 6pt)
  cdraw.rect((11.6, 1.18), (22.6, 2.42), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 1.8), [`GetLocalPlayer` rules,#linebreak()unordered `pairs` can desync], size: 6pt)
  cdraw.content((11.7, 0.5), [community-reported: the natives and the shelves], size: 6pt, fill: luma(100))
})

== dota 2: vscript in source 2

Dota 2 custom games run on vscript, and the valve wiki states the
shape plainly: "Scripting in Dota 2 is handled by the VScript
virtual machine using the Lua programming language," launched at run
time when the game loads the addon. No valve page states the lua
version. Community tooling is the evidence: the moddota typescript
addon template compiles through typescript-to-lua with
`"luaTarget": "JIT"`, a 5.1 semantics target, so this chapter says
lua 5.1-family and stops there. The unit of authoring is the addon,
built in the free workshop tools. Game logic lives under
`scripts/vscripts` with `addon_game_mode.lua` as the entry point,
whose `Activate` function the game calls on load. From there the
flow is event driven: `ListenToGameEvent` takes an event name and a
function and the game calls that function every time the event
happens, and community code wraps the handler in `Dynamic_Wrap` so
the `script_reload` console command can rebind listeners without a
restart. Behavior attaches through registration calls like
`LinkLuaModifier(className, fileName, LuaModifierType)`, which links
a lua-defined modifier class to its file. The ui is a different
stack entirely: panorama is valve's html5, css, and javascript
framework living under `content/dota_addons/<name>/panorama`, so a
custom game is lua logic on the game side and web tech on the screen
side. Source 2 itself arrived with the reborn beta in 2015, "Dota 2
is now powered by the Source 2 engine," and the scripting model rode
across.

#diagram([dota 2 vscript: the addon's entry point, its event listeners, the linked modifier classes], length: 13pt, {
  cdraw.content((2.9, 6.9), [the addon], size: 6pt, anchor: "east")
  cdraw.rect((4.0, 6.28), (22.6, 7.52), fill: luma(235), radius: 0.02)
  cdraw.content((13.3, 6.9), [the unit of authoring, built in the free workshop tools,#linebreak()the vscript machine launched at run time], size: 6pt)
  cdraw.content((2.9, 5.2), [entry], size: 6pt, anchor: "east")
  cdraw.rect((4.0, 4.58), (11.2, 5.82), fill: luma(235), radius: 0.02)
  cdraw.content((7.6, 5.2), [game logic lives under#linebreak()`scripts/vscripts`], size: 6pt)
  cdraw.rect((12.0, 4.58), (22.6, 5.82), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 5.2), [`addon_game_mode.lua`,#linebreak()the game calls `Activate` on load], size: 6pt)
  cdraw.content((2.9, 3.5), [events], size: 6pt, anchor: "east")
  cdraw.rect((4.0, 2.88), (12.6, 4.12), fill: luma(235), radius: 0.02)
  cdraw.content((8.3, 3.5), [`ListenToGameEvent`: a name#linebreak()and a function, every time], size: 6pt)
  cdraw.rect((13.4, 2.88), (22.6, 4.12), fill: luma(235), radius: 0.02)
  cdraw.content((18.0, 3.5), [wrapped in `Dynamic_Wrap`,#linebreak()`script_reload` rebinds], size: 6pt)
  cdraw.content((2.9, 1.8), [behavior], size: 6pt, anchor: "east")
  cdraw.rect((4.0, 1.18), (22.6, 2.42), fill: luma(235), radius: 0.02)
  cdraw.content((13.3, 1.8), [`LinkLuaModifier`(className, fileName, type)#linebreak()links a lua-defined modifier class to its file], size: 6pt)
  cdraw.content((11.7, 0.5), [the ui is panorama, html5, css, and javascript], size: 6pt, fill: luma(100))
})

== our host against theirs

#diagram([three hosts mapped: runtime, sandbox, loop ownership, failure mode], length: 13pt, {
  cdraw.content((2.9, 8.4), [dimension], size: 6pt, anchor: "east")
  cdraw.content((8.3, 8.4), [our capstone], size: 6pt)
  cdraw.content((14.9, 8.4), [warcraft iii], size: 6pt)
  cdraw.content((20.9, 8.4), [dota 2], size: 6pt)
  cdraw.line((0.8, 8.0), (22.6, 8.0), stroke: luma(220))
  let row(y, dim, a, b, c) = {
    cdraw.content((2.9, y), dim, size: 6pt, anchor: "east")
    cdraw.rect((4.0, y - 0.62), (11.0, y + 0.62), fill: luma(235), radius: 0.02)
    cdraw.content((7.5, y), a, size: 6pt)
    cdraw.rect((11.4, y - 0.62), (18.2, y + 0.62), fill: luma(235), radius: 0.02)
    cdraw.content((14.8, y), b, size: 6pt)
    cdraw.rect((18.6, y - 0.62), (22.6, y + 0.62), fill: luma(235), radius: 0.02)
    cdraw.content((20.6, y), c, size: 6pt)
  }
  row(6.9, [runtime], [lua 5.4,#linebreak()keralua native], [5.3, community#linebreak()reported], [5.1-family,#linebreak()vscript])
  row(5.2, [sandbox], [io os debug package#linebreak()nil, no random], [io file package debug off,#linebreak()os: clocks only], [not asserted,#linebreak()this pass])
  row(3.5, [owns the loop], [the campaign tick,#linebreak()c\# draws the roll], [map script, every#linebreak()lockstep client], [event listeners,#linebreak()fire on game events])
  row(1.8, [a broken script], [degrades to the#linebreak()compiled policy], [desync is the#linebreak()failure mode], [error surfaces#linebreak()in the console])
  cdraw.content((12.0, 0.4), [documentation-verified, neither game was run here], size: 6pt, fill: luma(100))
})

The map is the payoff of the two surveys. All three hosts draw the
same boundary this chapter drew, state and randomness stay with the
engine and the script answers questions, but they draw it at
different depths. Warcraft iii hands the script the whole map, runs
it on every lockstep client, and polices determinism with desync
rules because a script gone wrong does not throw, it silently
diverges the match. Dota 2 keeps the script inside event listeners
and registration calls with a web-tech ui beside it. Ours is the
smallest of the three and the only one where a broken script is a
non-event: the host degrades to the compiled policy and the battle
finishes. That guarantee is not luck, it is the fallback latch the
next section builds.

#callout("note", "documentation-verified, neither game was run", [
  Neither warcraft iii reforged nor dota 2 was installed or run for
  this chapter. Every claim about them is read from vendor pages
  (the archived 1.31 patch notes, the valve developer wiki, the
  blizzard release announcement) or labeled community-reported from
  hive workshop threads, jassdoc, and the moddota template, all
  accessed 2026-09-23 and pinned in the coverage sources with urls.
  The comparison maps what those documents state. No number in this
  book was measured against a live copy of either game.
])

== the capstone wires it in

#listing("game-systems/capstone/src/CampaignOptions.cs", first: 1, last: 9, caption: [one switch: scripts on loads the lua policies, off runs the compiled brains])

The campaign takes options beside its seed. Scripts on, the default,
builds one script host for the campaign's life and hangs two brains
off it, the enemy sweep's scorer and the pet's skill chooser.
Scripts off constructs the compiled brains directly, and the
seed-only constructor every existing call site uses means the whole
golden corpus of chapters 19 through 22 runs unmodified either way.
The player side never crosses the seam in either world: the golden
hand stays the compiled water-constrained policy, so equivalence
tests isolate exactly the enemy brain and the pet choice.

#listing("game-systems/capstone/src/Scripting/ScriptHost.cs", first: 16, last: 47, caption: [one interpreter per campaign, the two scripts embedded as resources, the fallback latch])

#listing("game-systems/capstone/src/Scripting/ScriptHost.cs", first: 49, last: 94, caption: [one batched call: a table and a scalar pushed as raw lua 5.4 integers, pcalled, restored])

The call deliberately steps under nlua's object layer to keralua's
raw state. Measured in a probe during the build: nlua's `Call`
marshals a `long[]` argument as userdata, which the script cannot
index as a table, so the host pushes the candidate table itself,
`CreateTable`, `PushInteger`, `RawSetInteger`, pushes the scalar,
and `PCall`s the hook with a type check that demands an integer
back. Every value crosses as a lua 5.4 integer in both directions,
there is no float to drift and no userdata to surprise, and the
`finally` restores the stack top whatever the script did. Any
failure latches `Fallback` and every later call answers null: a
script that throws, a hook that misbehaves, a script that fails to
load, even a disposed host, whose null-state guards degrade instead
of throwing. The brains turn null into the compiled policy, so a
broken script costs behavior nothing and never crashes a battle.

#listing("game-systems/capstone/src/Scripting/UtilityBrain.cs", first: 49, last: 80, caption: [the seam: candidates flattened six ints each, lua answers the winning index, the score stays compiled])

#listing("game-systems/capstone/src/Scripts/ai_weights.lua", first: 1, last: 30, caption: [the sweep's scoring table in lua: integer math, floor division, the argmax])

The division of labor keeps one yardstick. Lua scores every
candidate with the weights and answers the 1-based index of the
best, nothing else, and the c\# side maps that index to the candidate
and computes the winner's score with the compiled `Score` function,
so the behavior tree's argmax never compares a lua-computed number
against a compiled one. Ties keep the first candidate in both
worlds. The arithmetic is integer end to end, and lua's floor
division `//` matches the compiled truncating division because every
value in the table is non-negative, the one signedness fact the
equivalence suite watches. The ghost flights, the thing that makes
the sweep expensive, never leave c\#, one batched call per sweep is
the entire crossing.

#flow(
  [the sweep crosses the seam once per decision, the score never leaves],
  node((0, 0), [ghost flights,#linebreak()stay in c\#]),
  node((2.2, 0), [flat candidate table]),
  node((4.3, 0), [pick(cands)]),
  node((6.4, 0), [winning index,#linebreak()scored in c\#]),
  edge((0, 0), (2.2, 0), "-|>"),
  edge((2.2, 0), (4.3, 0), "-|>"),
  edge((4.3, 0), (6.4, 0), "-|>"),
)

#listing("game-systems/capstone/tests/ScriptEquivalenceTests.cs", first: 55, last: 74, caption: [the equivalence walk: both expeditions, scripts on and off, per-turn state hashes must match])

#callout("verify", "scripts on, scripts off, one trace", [
  The equivalence suite walks both expeditions twice per seed, once
  with scripts on and once off, and asserts the per-turn
  `Match.StateHash` traces are identical, not the outcomes:
  campaign seeds 42 through 45, plus mirror duels, both brains
  scripted against both compiled, on seeds 7, 21, and 42. A full
  eight-seed band was trimmed for suite budget and the trim is
  recorded in a comment in `ScriptEquivalenceTests.cs`. The walks
  demand no wins, deliberately: the compiled water hand loses
  expedition 1 stage 3 on seeds 44, 46, and 47 and expedition 2
  stage 3 on seed 48, a pre-existing compiled-world fact, so the
  only win assertions live in the seed-42 golden test. The balance
  matrix and the renderer's bots construct compiled ai only, so the
  committed balance report is untouched by construction.
])

sources: the warcraft iii facts cite the archived mirror of the
official 1.31 patch notes on warcraft.wiki.gg, the original blizzard
forum thread having died in the 2024 migration, and the reforged
release announcement on news.blizzard.com, both accessed 2026-09-23.
the embedded 5.3 version, the natives-as-globals shape, the stripped
library list, and the desync rules are community-reported from hive
workshop threads and jassdoc, same date, labeled as such in the
text. the dota 2 facts cite developer.valvesoftware.com pages, the
scripting page fetched live and the rest through wayback snapshots
of a site sitting behind bot protection, plus the moddota typescript
template for the 5.1-family
tooling evidence, all accessed 2026-09-23. nlua and keralua facts
cite nuget, the nlua readme, and the lua 5.4 manual, accessed
2026-09-23, with the marshaling behavior measured by this book's own
tests rather than cited. Verified by `make test-gs-samples` and
`make test-gs-capstone`: 8 tests in `GameSystems.Samples.Tests.Ch18`,
3 in `ScriptHostTests`, 4 in `ScriptEquivalenceTests`.
