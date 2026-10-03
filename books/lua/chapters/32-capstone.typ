#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= capstone: auto chess, human versus bot

The capstone is a complete auto chess game, two players, shops,
gold, xp, merges, deterministic combat, one of them a bot, and the
whole of it embedded in the allegro host chapter 18 built. The game
is pure lua, 10 modules plus a 34 test suite under the pinned 5.5
binary, and the c host that renders it also runs it headless over
scripted drivers that pin entire games to one digest string. The
human interface is a mouse and four keys, and it is also the
automation api: both speak the same command queue.

== the game

Two players start at 20 hp, 10 gold, level 2. A round is a prep
phase, buy from a five slot shop, field units up to your level, then
both sides ready and the boards fight. The loser takes 2 damage plus
the winner's survivors, the winner banks a bonus, everyone draws
income and interest, and three copies of a unit merge into the next
tier. Five unit types carry the tactics: walls soak, blades hit,
archers shoot the weakest, pyros splash neighbors, medics heal:

#listing("lua/capstone/stats.lua", first: 7, last: 17, caption: [the stat sheet, five types of three tiers each])

#diagram([one round of the game, prep to income], length: 13pt, {
  // the round cycle
  let stage(x0, x1, txt, hot) = {
    let f = if hot { luma(205) } else { luma(235) }
    cdraw.rect((x0, 8.4), (x1, 10.6), fill: f, radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 9.5), txt, size: 6pt)
  }
  stage(0.5, 4.4, [prep: #linebreak() buy, field], false)
  cdraw.line((4.6, 9.5), (5.4, 9.5), stroke: luma(100), mark: (end: ">"))
  stage(5.6, 9.0, [both ready, #linebreak() boards fight], true)
  cdraw.line((9.2, 9.5), (10.0, 9.5), stroke: luma(100), mark: (end: ">"))
  stage(10.2, 14.2, [damage: #linebreak() 2 plus survivors], false)
  cdraw.line((14.4, 9.5), (15.2, 9.5), stroke: luma(100), mark: (end: ">"))
  stage(15.4, 21.5, [income, interest, #linebreak() xp, new offers], false)
  // the arrows home
  cdraw.line((18.4, 8.4), (18.4, 7.2), stroke: luma(100))
  cdraw.line((2.4, 7.2), (18.4, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((2.4, 8.4), (2.4, 7.2), stroke: luma(100))
  // the laws
  cdraw.content((11.0, 5.8), [level is the deploy cap, 2 to 6, xp buys level], size: 6.5pt)
  cdraw.content((11.0, 4.6), [three copies merge, bench first, recursively to tier 3], size: 6.5pt)
  cdraw.content((11.0, 3.4), [selling returns half, income 5, interest 1 per 10 capped at 3], size: 6.5pt)
  cdraw.content((11.0, 2.2), [a side with nothing fielded fights an empty board and loses], size: 6.5pt)
})

== the command queue, the automation seam

#xref-to("lua", "allegro") designed the contract, the capstone ships
the production queue. Commands are validated tables, `keydown`,
`keyup`, `click`, `quit`, and the game consumes exactly one
`drain()` per tick, nothing else reads input at all:

#listing("lua/capstone/queue.lua", first: 17, last: 32, caption: [push validates at the door, the only way in])

The seam is bidirectional automation. In a window, the c host
translates allegro events into these tables through the fixed pixel
layout, a click at a shop slot buys it, a bench slot selects it, a
board cell places or moves, `r` rerolls, `d` buys xp, `e` sells the
selection, `space` readies. In the verify suite, scripted drivers
push the same tables at chosen ticks, and the game cannot tell the
difference, which is the point:

#listing("lua/capstone/actions.lua", first: 207, last: 225, caption: [the input mapping, clicks against the fixed layout])

#flow(
  [two hands, one queue, one game],
  node((0, 0), [a mouse and four keys, #linebreak() or a driver file]),
  node((-2.9, 1.7), [the c host translates #linebreak() allegro events]),
  node((2.9, 1.7), [drivers push at #linebreak() chosen ticks]),
  node((0, 3.4), [queue.push, validated tables]),
  node((0, 5.1), [one drain a tick, #linebreak() the game systems]),
  edge((0, 0), (-2.9, 1.7), "-|>"),
  edge((0, 0), (2.9, 1.7), "-|>"),
  edge((-2.9, 1.7), (0, 3.4), "-|>"),
  edge((2.9, 1.7), (0, 3.4), "-|>"),
  edge((0, 3.4), (0, 5.1), "-|>"),
)

== ecs in lua

Units and players are entities, integer ids in one world, with a
sparse store per component, `unit`, `team`, `loc`, and iteration
that picks the smallest store as its anchor, the trick
#xref-to("game-systems", "ecstheory") teaches for free queries:

#listing("lua/capstone/ecs.lua", first: 43, last: 59, caption: [each anchors on the smallest store among the wanted components])

The board and bench are indexes beside the stores, cell keys to
entity ids, so placement queries stay O(1) while the world owns the
truth. Merges and sells kill entities, the collector reclaims the
component rows, and the suite pins the lifecycle:

#listing("lua/capstone/ecs.lua", first: 11, last: 22, caption: [spawn and kill are the whole lifecycle])

#diagram([entities, per-component stores, the anchor law], length: 13pt, {
  // entities as a column, stores as rows
  cdraw.content((2.0, 10.4), [entities 1 2 3 4], size: 6pt)
  cdraw.rect((0.5, 7.8), (10.5, 9.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 9.3), [store: unit, 4 entities], size: 6pt)
  cdraw.content((5.5, 8.3), [type and tier per unit], size: 6pt)
  cdraw.rect((0.5, 5.6), (10.5, 7.4), fill: luma(205), radius: 0.02)
  cdraw.content((5.5, 6.9), [store: loc, 2 entities], size: 6pt)
  cdraw.content((5.5, 6.0), [the smallest store anchors], size: 6pt)
  cdraw.rect((0.5, 3.4), (10.5, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.5, 4.7), [store: team, 4 entities], size: 6pt)
  cdraw.content((5.5, 3.8), [side, human or bot], size: 6pt)
  // the query result
  cdraw.line((10.7, 6.5), (12.4, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.6, 5.4), (21.5, 7.6), fill: luma(245), radius: 0.02)
  cdraw.content((17.05, 6.9), [each(unit, loc)], size: 6pt)
  cdraw.content((17.05, 5.9), [walks 2, checks 4, #linebreak() returns the intersection], size: 6pt)
  // the guarantees
  cdraw.content((16.0, 3.4), [kill removes every store row], size: 6.5pt)
  cdraw.content((16.0, 2.2), [cells and bench slots are indexes, #linebreak() never the ownership], size: 6.5pt)
})

== the bot's brain, a state machine

The bot plays through the same action functions the input mapping
calls, `buy`, `deploy_from_bench`, `reroll`, `buy_xp`, `ready`, and
a four state machine decides which, the shape
#xref-to("game-systems", "fsm") teaches. `OPENING` buys the cheapest
offers until the board is full, `ACCUMULATE` hoards gold and buys
only duplicates, `SPEND` rerolls for upgrades and levels, and
`STABILIZE` is panic mode at low hp, spending everything:

#listing("lua/capstone/bot.lua", first: 14, last: 30, caption: [the transition table, five events over four states])

#listing("lua/capstone/bot.lua", first: 48, last: 62, caption: [opening: cheapest offers in slot order, then field them])

#diagram([the bot's four states and the events that move it], length: 13pt, {
  // four states in a diamond
  let state(x, y, name, hot) = {
    let f = if hot { luma(205) } else { luma(235) }
    cdraw.rect((x - 2.3, y - 0.7), (x + 2.3, y + 0.7), fill: f, radius: 0.02)
    cdraw.content((x, y), [#name], size: 6pt)
  }
  state(4.0, 10.2, [OPENING], false)
  state(15.0, 10.2, [ACCUMULATE], false)
  state(15.0, 6.6, [SPEND], true)
  state(4.0, 6.6, [STABILIZE], false)
  cdraw.line((6.3, 10.2), (12.7, 10.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.5, 10.7), [bench\_full, board\_full], size: 6pt)
  cdraw.line((15.0, 9.5), (15.0, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.3, 8.4), [gold\_changed, #linebreak() gold at 12 or more], size: 6pt)
  cdraw.line((12.7, 6.6), (6.3, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.5, 7.1), [round\_result], size: 6pt)
  cdraw.line((4.0, 7.3), (4.0, 9.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.9, 8.4), [low\_hp, #linebreak() 6 or less], size: 6pt)
  // the policies
  cdraw.content((11.0, 4.6), [opening buys cheapest, accumulate hoards for interest], size: 6.5pt)
  cdraw.content((11.0, 3.4), [spend rerolls and levels, stabilize is all-in at low hp], size: 6.5pt)
  cdraw.content((11.0, 2.2), [the bot buys through the same actions a human's click resolves to], size: 6.5pt)
  cdraw.content((11.0, 1.0), [every state ends by readying, the round always proceeds], size: 6.5pt)
})

== deterministic combat

Combat has no rng anywhere. Both boards face each other, units act
in reading order, front row first, and one tick is one full pass:
melee swings at the nearest front enemy, archers and pyros pick the
weakest, medics heal the weakest ally, pyro splash halves onto
orthogonal neighbors:

#listing("lua/capstone/rules.lua", first: 62, last: 89, caption: [targeting: front, weakest, or the weakest ally])

#listing("lua/capstone/rules.lua", first: 90, last: 108, caption: [one tick, one pass, heal, splash, and plain hits])

The game layer runs one rules tick every quarter second of sim time
until a side is empty or the 40 tick cap draws the fight, and the
whole fight is a replay: same boards, same ticks, same result, which
the suite pins twice, once for the resolution and once for the
per-tick event log:

#listing("lua/capstone/run.lua", first: 263, last: 277, caption: [the deterministic resolve test, run twice])

#diagram([one combat tick, the targeting rules], length: 13pt, {
  // two boards facing
  cdraw.rect((0.5, 7.0), (21.5, 11.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 10.9), [the enemy board, rows 3 2 1 top to bottom], size: 6pt)
  cdraw.rect((0.5, 3.2), (21.5, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 6.1), [your board, row 1 is the front], size: 6pt)
  // arrows from your front unit
  cdraw.line((4.0, 5.4), (4.0, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.6, 6.9), [melee: nearest front], size: 6pt)
  cdraw.line((12.0, 5.4), (17.5, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.4, 6.9), [ranged: weakest], size: 6pt)
  cdraw.line((19.5, 5.4), (19.5, 8.2), stroke: luma(120))
  cdraw.content((19.5, 4.9), [medic: #linebreak() heals instead], size: 6pt)
  // the guarantees
  cdraw.content((11.0, 2.2), [reading order, no rng, one pass per tick, cap at 40], size: 6.5pt)
  cdraw.content((11.0, 1.0), [survivors feed the damage, 2 plus the count], size: 6.5pt)
})

== the c host, both interop directions

The host is chapter 18's skeleton grown up. Direction one, c calls
lua: the timer ticks, the host builds a command table with
`lua_createtable` and field pushes, hands it to the queue, and calls
`update(dt)` protected. Direction two, lua calls c: the api table
registers draw primitives that early-return headless, so the same
game draws into a window or into nothing:

#listing("lua/capstone/src/host.c", first: 201, last: 211, caption: [the headless loop, driver commands then one update])

#listing("lua/capstone/src/api.c", first: 12, last: 17, caption: [headless primitives early-return, never error])

The verdict at the end of a headless run is a digest, one string
summarizing rounds, hp, gold, levels, and every unit with its
position, compared against the outcome and digest the driver file
freezes. All three drivers end `bot_win`, and the honest result is
in the numbers: a casual human script dies by round 6 against a bot
that never misses an economy beat, the steady `fixed-open` driver
holds to round 6, `rush` and `concede` fall at round 5:

#snippet("fixed-open  3656 ticks  bot_win\nrush        2756 ticks  bot_win\nconcede     2716 ticks  bot_win", lang: "text")

== the headless suite

`make verify-lua` runs the 34 lua tests, `make verify-lua-c` adds
the c side, 8 host samples plus the capstone host over its three
drivers, 118 checks in all, and none of it opens a window. The
drivers live beside the game and are ordinary lua:

#listing("lua/capstone/tests/drivers/fixed-open.lua", first: 5, last: 10, caption: [a driver is a tick script of the same command tables])

The determinism test is the suite's keystone: two games from one
seed, one command script, and the digests must match exactly, or a
stray `math.random` has leaked into the game:

#listing("lua/capstone/run.lua", first: 387, last: 398, caption: [same seed, same run, digest equal])

#flow(
  [the headless gates, three layers, no windows],
  node((0, 0), [34 lua tests, #linebreak() make verify-lua]),
  node((0, 1.7), [8 c host samples, #linebreak() make verify-lua-c]),
  node((0, 3.4), [the capstone host, #linebreak() 3 drivers, digest pinned]),
  node((2.9, 1.7), [the same binary #linebreak() runs --window]),
  edge((0, 0), (0, 1.7), "-|>"),
  edge((0, 1.7), (0, 3.4), "-|>"),
  edge((0, 1.7), (2.9, 1.7), "-|>"),
)

== profiled, and why

The profiling chapter's census turns on the game once, measured
standalone on this machine, 2026-09-21, lua 5.5.1: a full three
driver sweep, 9128 game ticks, took a count-hook census at every 200
instructions, 2807 samples. The distribution is the tick loop
speaking: `game.lua` carries 45.6 percent, every tick drains the
queue and walks the phase machine even when nothing happens,
`queue.lua` follows at 9.3 for the same reason, validation runs per
command, then `actions.lua` at 5.1, `board.lua` at 4.2, and the
combat walker `rules.lua` at 2.7, while the bot's brain never
registered a sample at all, it thinks once per prep phase. The
shape says where a real engine would spend its optimization budget,
and why this one does not need to: the whole sweep is milliseconds
of interpreted lua.

The why is the capstone's testing story. Determinism makes the
digest pins possible, the digest pins make the drivers regression
proof, and the instruction census, not wall time, keeps the claim
honest on a machine that is doing anything else. The suite never
measures seconds, it counts.

== the service part after the capstone

The game is this book's teaching artifact, and the next evidence
layer was built after it, on the same language: the service part
under `books/lua/service`, thirteen chapters 19 through 31, closed at
version 5.0. The wave's closeout in the findings register, dated
2026-09-28, records the gates green: the plain lane 188 passed
0 failed under `make verify-lua`, 136 family-array checks over
15 modules plus 52 scenario checks over 6 files, the jit lane 18
over the ffi store under `make verify-lua-jit`, and the host lane 162
over the winsock seam under `make verify-lua-c`, with all 16 frozen
vectors byte-exact through the composition root's real chain.

sources: the repo's own modules and hosts, all behavior verified in
tree: 34 tests through `make verify-lua`, 10 ffi tests through
`make verify-lua-jit` from `books/lua/jit/`, 118 c checks through
`make verify-lua-c`, driver outcomes and digests measured 2026-09-21
and frozen in `tests/drivers/*.lua`. The ecs and fsm vocabulary
cross referenced to #xref-to("game-systems", "ecstheory") and
#xref-to("game-systems", "fsm").
