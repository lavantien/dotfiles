#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= capstone part 2: the campaign core

Part 1 left the battle a pure function; part 2 spends it. The
campaign is the composition root over chapters 14 through 17: a
character sheet that levels and wears 14 slots of gear, a shop and
a diamond forge, pets that hatch with three mana gated actives and
two passives, and expeditions that turn stage records into battles
with a boss at the end. One rule holds all of it together, the whole
campaign is a pure function of the profile seed plus the command
sequence, pinned by a test that replays a scripted run twice and
hashes after every command.

== the composition root

#listing("game-systems/capstone/src/Campaign.cs", first: 29, last: 49, caption: [every stream forked once at construction, and the v2 sheet it all hangs on])

Chapter 11's discipline at its widest: `"battle"`, `"loot"`,
`"craft"`, and `"hatch"` fork at construction, battle seeds derive
per expedition and stage without touching the parent, and each
battle's own wind forks inside the engine. A replayed profile draws
the same loot and hatches the same pets, every time. The sheet is
the chapter 15 record: primary attributes, the 14 slot loadout with
per slot upgrade levels, the paged grid, and the wallet, all of it
folded into the state hash.

#flow(
  [the composition root: four streams forked once, stage seeds derive],
  node((0, 0), [the profile seed]),
  node((-3, 1.3), [battle]),
  node((-1, 1.3), [loot]),
  node((1, 1.3), [craft]),
  node((3, 1.3), [hatch]),
  node((-3, 2.7), [per stage seeds,#linebreak()wind forks inside]),
  edge((0, 0), (-3, 1.3), "-|>"),
  edge((0, 0), (-1, 1.3), "-|>"),
  edge((0, 0), (1, 1.3), "-|>"),
  edge((0, 0), (3, 1.3), "-|>"),
  edge((-3, 1.3), (-3, 2.7), "-|>"),
)

== a stage becomes a battle

#listing("game-systems/capstone/src/Campaign.cs", first: 408, last: 473, caption: [stats derive through the loadout, the stage arms the enemy, the seed derives])

`BeginStage` is where the systems meet: `ComposeStats` walks the
loadout, scales each worn piece by its upgrade level, adds the
active pet's passives, and runs chapter 14's `Attributes.Derive` to
produce the primaries, armor, pools, and elemental arrays the player
fights with, the stage record arms the enemy with its own numbers,
weapon, and terrain, and the derived seed fixes the ground under
both. Losing keeps the cleared stages and the retry walks back into
the same fight, which is why the unlock chain of chapter 17 is
permanent progress rather than a streak.

#flow(
  [a stage becomes a battle: the loadout walks into derive],
  node((0, 0), [the loadout,#linebreak()14 slots]),
  node((2, 0), [scale each piece#linebreak()by its upgrade]),
  node((4, 0), [add the pet's#linebreak()passives]),
  node((4, 1.6), [derive]),
  node((2, 1.6), [primaries, pools,#linebreak()elemental arrays]),
  node((0, 1.6), [the fighter]),
  edge((0, 0), (2, 0), "-|>"),
  edge((2, 0), (4, 0), "-|>"),
  edge((4, 0), (4, 1.6), "-|>"),
  edge((4, 1.6), (2, 1.6), "-|>"),
  edge((2, 1.6), (0, 1.6), "-|>"),
)

== the payout

#listing("game-systems/capstone/src/Campaign.cs", first: 313, last: 341, caption: [loot rolls, gold and diamonds pay, xp crosses levels, the boss hatches a pet])

A won battle rolls the stage's weighted table through the `"loot"`
stream, then the same stream rolls the gold between the stage's
bounds, bosses pay four diamonds on top, xp can cross several levels
in one step, and a boss clear hatches from the `"hatch"` stream and
becomes the active pet. The gold buys shop gear and the diamonds
upgrade it, both compounding into the next battle's derived stats. A
lost one pays nothing and keeps the progress. Either way the outcome
record carries what the reward screen shows.

#flow(
  [the campaign loop, everything feeds the sheet and the sheet feeds back],
  node((1.8, 0), [sheet]),
  node((1.8, -2.2), [weapons]),
  node((1.8, -4.4), [pets]),
  node((1.8, -6.6), [expeditions]),
  node((5.2, -3.3), [begin stage]),
  node((7.6, -3.3), [battle]),
  node((10.0, -3.3), [payout]),
  edge((1.8, 0), (5.2, -3.3), "-|>"),
  edge((1.8, -2.2), (5.2, -3.3), "-|>"),
  edge((1.8, -4.4), (5.2, -3.3), "-|>"),
  edge((1.8, -6.6), (5.2, -3.3), "-|>"),
  edge((5.2, -3.3), (7.6, -3.3), "-|>"),
  edge((7.6, -3.3), (10.0, -3.3), "-|>", label: [over]),
  edge((10.0, -3.3), (1.8, 0), "-|>", bend: -35deg, label: [loot, xp, pet]),
)

== replay v3

#listing("game-systems/capstone/src/ReplayV3.cs", first: 16, last: 48, caption: [magic bumped, version 3, seven fields per turn, the profile hash beside the seed])

Chapter 12 taught the rule and warned what happens when a format
grows: this is the predicted case twice over. Weapons joined the log
in version 2, then movement joined: the turn record now carries the
shot, the decimeters walked while aiming, and the flags holding any
paper plane flight, the magic moved to `GSR3`, the version byte
reads 3, and the profile hash rides beside the seed so a file names
the character that fired it. The chapter 12 codec still loads
version 1 forever; this lineage replaces its own version 2 outright,
the binary is book-versioned, and a battle rebuild replays its log
through a fresh campaign start to the same state hash.

#diagram([replay v3: 29 of header, the profile hash beside the seed, 32 per turn], length: 13pt, {
  let w = 0.7
  let b0 = 1.0
  let header = ((0, 4, [magic, 4]), (4, 5, []), (5, 9, [width, 4]), (9, 17, [seed, 8]), (17, 25, [profile hash, 8]), (25, 29, [count, 4]))
  for (s0, e0, t) in header {
    cdraw.rect((b0 + s0 * w, 5.4), (b0 + e0 * w, 6.8), fill: luma(235), radius: 0.02)
    if t != [] { cdraw.content((b0 + (s0 + e0) / 2 * w, 6.1), t, size: 6pt) }
  }
  cdraw.content((b0 + 4.5 * w, 7.3), [version 3, 1], size: 6pt)
  cdraw.line((b0 + 4.5 * w, 7.05), (b0 + 4.5 * w, 6.8), stroke: luma(100))
  cdraw.content((11.5, 4.8), [the profile hash names the character that fired], size: 6pt)

  let t0 = 1.0
  let tw = 0.62
  let turns = ((0, 4), (4, 8), (8, 12), (12, 16), (16, 20), (20, 24), (24, 32))
  let names = ([player], [angle], [power], [weapon], [move dm], [flags], [teleport, 8])
  for i in range(7) {
    let (s0, e0) = turns.at(i)
    cdraw.rect((t0 + s0 * tw, 1.6), (t0 + e0 * tw, 2.9), fill: luma(235), radius: 0.02)
    let y = if calc.even(i) { 1.15 } else { 0.15 }
    cdraw.content((t0 + (s0 + e0) / 2 * tw, y), names.at(i), size: 6pt)
  }
  cdraw.content((11.0, 3.4), [the teleport lands only when its flag is set], size: 6pt)
  cdraw.content((11.0, -1.3), [32 bytes per turn, seven fields], size: 6pt)
})

sources: composed from chapters 11, 14, 15, 16, and 17 of this book,
each with its own pinned sources. Verified by `dotnet test
books/game-systems/capstone/GameSystemsCapstone.slnx`, 95 tests in
`GameSystems.Capstone.Tests` covering the campaign, the economy, the
balance bands, and the replay.
