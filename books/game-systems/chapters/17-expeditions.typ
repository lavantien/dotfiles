#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= expeditions and bosses

The campaign needs somewhere to spend the sheet. The genre's answer
is the expedition: a fixed sequence of staged fights that ends at a
boss, pays loot that feeds crafting, and unlocks the next one only
when this one is cleared. This chapter makes the stage, the loot
table, and the unlock chain data and pure functions, the same
discipline as every system before it.

== the stage as data

#listing("game-systems/samples/src/Ch17/Expeditions.cs", first: 13, last: 28, caption: [one fight as a record, and the expedition as its ordered stages])

A stage carries everything a battle needs to build itself: the
enemy's health, attack, and defense, the terrain's octave and
amplitude knobs, the weapon it fires, the weighted rewards it can
drop, and the gold a win rolls between. The boss flag changes
behavior in the battle engine, a desperation branch in its aim tree
and four diamonds on the payout, without changing the stage's shape.
An expedition is just the ordered list with the boss last, which is
a convention the tests pin rather than a rule the type enforces.

#diagram([the stage record feeding a whole battle build], length: 13pt, {
  cdraw.rect((1, -2.0), (23, 7.6), stroke: luma(120), radius: 0.05)
  cdraw.content((12, 7.1), [StageDef, one fight as a record], size: 6.5pt)
  cdraw.rect((1.8, 4.6), (11.0, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 5.4), [enemy: health,#linebreak()attack, defense], size: 6pt)
  cdraw.rect((12.0, 4.6), (22.2, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 5.4), [terrain: octaves,#linebreak()amplitude knobs], size: 6pt)
  cdraw.rect((1.8, 2.0), (11.0, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 3.0), [the weapon it fires], size: 6pt)
  cdraw.rect((12.0, 2.0), (22.2, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 3.0), [weighted rewards,#linebreak()the loot table], size: 6pt)
  cdraw.rect((1.8, -0.6), (11.0, 1.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 0.4), [gold: a roll between], size: 6pt)
  cdraw.rect((12.0, -0.6), (22.2, 1.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 0.4), [boss flag: tree branch,#linebreak()four diamonds], size: 6pt)
  cdraw.content((12, -1.4), [the boss flag changes behavior, never shape], size: 6pt)
})

== enemy rosters and the two brains

#listing("game-systems/samples/src/Ch17/Rosters.cs", first: 6, last: 28, caption: [an enemy as data with its brain kind, script for creeps, fuzzy for bosses])

A stage can also carry a roster, one `EnemyDef` per combatant, each
with its own numbers, weapon, and brain. Creeps run the scripted
brain, a deterministic coarse grid search with no randomness
anywhere, and bosses run the utility tree of chapter 19. The roster
field is what lets one stage hold creeps and a boss in the same
fight once the campaign consumes it.

#diagram([creep against boss, the scripted grid against the utility tree], length: 13pt, {
  let cols = ([the brain], [randomness], [how it aims])
  let rows = ([creep], [boss])
  let cells = (([scripted], [none at all], [coarse grid]), ([utility tree], [utility scored], [desperation]))
  for c in range(3) {
    cdraw.content((7.8 + c * 6.2, 6.4), cols.at(c), size: 6pt)
  }
  for r in range(2) {
    cdraw.content((2.9, 5.1 - r * 1.7), rows.at(r), size: 6.5pt)
    for c in range(3) {
      cdraw.rect((5.0 + c * 6.2, 4.6 - r * 1.7), (10.6 + c * 6.2, 5.6 - r * 1.7), fill: luma(235), radius: 0.02)
      cdraw.content((7.8 + c * 6.2, 5.1 - r * 1.7), cells.at(r).at(c), size: 6pt)
    }
  }
  cdraw.content((11.5, 2.4), [one roster, one EnemyDef per combatant], size: 6pt)
  cdraw.content((11.5, 1.3), [each with its own numbers, weapon, and brain], size: 6pt)
})

== weighted loot from one stream

#listing("game-systems/samples/src/Ch17/Expeditions.cs", first: 35, last: 61, caption: [one NextInt over the total weight per draw, repeats stack])

Each draw is one `NextInt` over the total weight, then a walk that
subtracts weights until the pick falls inside an entry, so a zero
weight entry can never win no matter the seed. Repeated picks of the
same entry stack their counts into one line of loot. The stream is a
parameter again: the campaign forks a `"loot"` stream at construction
and every reward in a replayed run lands identically, which is what
lets the scenario suite assert a full clear down to the items.

#diagram([one draw over the total weight, the subtracting walk picks], length: 13pt, {
  // weights 3, 2, 5; one draw of 8 lands inside the hat
  let segs = ((2.0, 5.4, [ore, 3], luma(235)), (7.4, 3.6, [gem, 2], luma(235)), (11.0, 9.0, [hat, 5], luma(205)))
  for (x0, w, label, f) in segs {
    cdraw.rect((x0, 4.5), (x0 + w, 5.7), fill: f, radius: 0.02)
    cdraw.content((x0 + w / 2, 5.1), label, size: 6pt)
  }
  cdraw.line((16.4, 4.2), (16.4, 6.2), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((11.0, 6.7), [one next int over the total weight, drew 8], size: 6pt)
  cdraw.content((11.0, 3.6), [the walk: 8 - 3 - 2 = 3, inside hat], size: 6pt)
  cdraw.content((11.0, 2.5), [a zero weight entry can never win], size: 6pt)
  cdraw.content((11.0, 1.4), [repeat picks stack their counts], size: 6pt)
})

== the unlock chain

#listing("game-systems/samples/src/Ch17/Expeditions.cs", first: 70, last: 78, caption: [index zero is always open, the rest need all earlier cleared])

#flow(
  [an expedition paying out per stage, the boss clearing opens the next],
  node((0, 0), [expedition]),
  node((3.0, 1.4), [stage one]),
  node((3.0, 0), [stage two]),
  node((3.0, -1.4), [boss, last]),
  node((6.4, 0), [rewards, xp and loot]),
  node((6.4, -2.8), [next expedition]),
  edge((0, 0), (3.0, 1.4), "-|>"),
  edge((0, 0), (3.0, 0), "-|>"),
  edge((0, 0), (3.0, -1.4), "-|>"),
  edge((3.0, 1.4), (6.4, 0), "-|>", label: [clear]),
  edge((3.0, 0), (6.4, 0), "-|>"),
  edge((3.0, -1.4), (6.4, 0), "-|>"),
  edge((3.0, -1.4), (6.4, -2.8), "-|>", label: [all cleared], bend: 35deg, label-side: left),
)

The chain is strict order: the first expedition is always unlocked,
every later one needs all earlier ones cleared, and clearing means
the boss went down, because completion counts stages and the boss is
a stage. Losing a fight keeps the cleared stages, the retry walks
back in at the same place, so an unlock is permanent progress rather
than a streak. That is the whole persistence story, and it needs no
save machinery beyond the profile the character chapter already
owns.

sources: the adventure mode framing follows the gamesindustry.biz
dd tank overview naming adventure as one of the game's two main
modes, accessed 2026-09-09, alongside the pins of chapters 14
through 16. Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 12 tests in
`GameSystems.Samples.Tests.Ch17`.
