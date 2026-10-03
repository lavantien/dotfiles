#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= pets and companions

The trajectory shooters this capstone draws from hatch pets that
fight beside the gunner: passives that compose straight onto the
character sheet and actives that turn a fight. This chapter keeps
both as plain data, three actives and two passives per species, mana
gated in the battle, so a pet changes outcomes without introducing a
single floating point number.

== the species as data

#listing("game-systems/samples/src/Ch16/PetSkills.cs", first: 6, last: 53, caption: [five skill kinds, the priced skill record, the passive record, and the species pinned at three and two])

A species is exactly three active skills and exactly two innate
passives, both counts enforced at construction so no catalog entry
can drift. A skill is its kind, its mana price, and the size of its
effect, all data, the battle engine dispatches on the kind rather
than calling into pet code. A passive is the chapter 14 pet
contrib record, inherent primaries, the only raw elemental
resistances in the game, and the only raw mana. An owned pet is its
species, a name, and its own level and xp, a small character that
never fires.

#diagram([the species pinned at three actives and two passives], length: 13pt, {
  cdraw.rect((1, 0.6), (23, 7.8), stroke: luma(120), radius: 0.05)
  cdraw.content((12, 7.2), [PetSpecies, counts enforced at construction], size: 6.5pt)
  cdraw.rect((1.8, 3.5), (11.0, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 5.0), [exactly 3 actives#linebreak()a skill: kind, price,#linebreak()magnitude of the effect], size: 6pt)
  cdraw.rect((12.0, 3.5), (22.2, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 5.0), [exactly 2 passives#linebreak()inherent primaries, resists,#linebreak()and the only raw mana], size: 6pt)
  cdraw.content((12, 2.8), [the battle dispatches on the kind, no pet code runs], size: 6pt)
  cdraw.content((12, 1.7), [an owned pet: species, name, level, xp], size: 6pt)
})

== growth mirrors characters

#listing("game-systems/samples/src/Ch16/Pets.cs", first: 13, last: 27, caption: [the same xp curve and the same multi level loop])

`PetGrowth` is chapter 14's curve applied to pets: `XpForNext` and
`GainXp` are the same quadratic requirement and the same multi level
loop, so pets and their owner level up under one set of arithmetic
facts and one rebalance moves both.

#diagram([the same quadratic curve under characters and pets], length: 13pt, {
  let panel(x0, name) = {
    cdraw.line((x0, 0.8), (x0 + 8.0, 0.8), stroke: luma(100))
    for l in range(1, 6) {
      let h = 20 * l * l * 0.0032
      cdraw.rect((x0 + 0.5 + (l - 1) * 1.5, 0.8), (x0 + 1.7 + (l - 1) * 1.5, 0.8 + h), fill: luma(235), radius: 0.02)
      cdraw.content((x0 + 1.1 + (l - 1) * 1.5, 0.3), [#l], size: 6pt)
    }
    cdraw.content((x0 + 4.0, -0.6), [#name], size: 6.5pt)
  }
  panel(2.0, [character])
  panel(12.5, [pet])
  cdraw.content((11.5, 6.0), [the same 20 x level squared], size: 6pt)
  cdraw.content((11.5, 4.9), [the same multi level loop], size: 6pt)
  cdraw.content((11.5, 3.6), [one rebalance moves both], size: 6pt)
})

== hatching from a named stream

#listing("game-systems/samples/src/Ch16/Pets.cs", first: 37, last: 44, caption: [one NextInt draw picks the species])

Hatching is deliberately the smallest possible random system: one
draw from a caller supplied stream indexes the pool, the species
names the pet, and it starts at level one. The stream is a parameter
for the same reason crafting's roll was, the campaign forks a
`"hatch"` stream once at construction, so the same profile seed
hatches the same sequence of pets every time it is replayed, and the
scenario suite can pin a boss reward down to the species it hatches.

#flow(
  [hatching: one draw from the forked hatch stream picks the species],
  node((0, 0), [campaign forks#linebreak()hatch once]),
  node((2, 0), [one next int#linebreak()over the pool]),
  node((4, 0), [the draw indexes#linebreak()the species]),
  node((6, 0), [pet, level 1]),
  edge((0, 0), (2, 0), "-|>"),
  edge((2, 0), (4, 0), "-|>"),
  edge((4, 0), (6, 0), "-|>"),
)

== mana gates the actives

#flow(
  [a skill request routes through the mana gate to its effect],
  node((0, 0), [requested]),
  node((2.6, 0), [gate]),
  node((5.4, 1.3), [refused]),
  node((5.4, -0.9), [apply]),
  node((8.6, -1.8), [heal]),
  node((8.6, -0.6), [armor]),
  node((8.6, 0.6), [burst]),
  edge((0, 0), (2.6, 0), "-|>"),
  edge((2.6, 0), (5.4, 1.3), "-|>", label: [short pool]),
  edge((2.6, 0), (5.4, -0.9), "-|>", label: [paid]),
  edge((5.4, -0.9), (8.6, -1.8), "-|>"),
  edge((5.4, -0.9), (8.6, -0.6), "-|>"),
  edge((5.4, -0.9), (8.6, 0.6), "-|>"),
)

The once-per-battle bool is gone, mana is the gate now: the pools
regen five a turn, the passives decide how deep they run, and a
skill that cannot be paid for is refused by the gate rather than by
the effects. Heal and restore feed the actor's own pools, armor up
rides the same status list as the elemental afflictions for two
turns, and burst and debuff hit every living enemy flat with no
falloff and no crit. What a pet is worth is decided before the
battle by derive, the passives feed the derivation, and inside it by
what its actives cost against the pool it brought.

sources: the dd tank us wiki systems section lists pets among its
game systems, and the baidu baike dd tank entry describes the pet
raising system unlocking at level 25, accessed 2026-09-09. Verified
by `dotnet test books/game-systems/samples/GameSystemsBook.slnx`,
8 tests in `GameSystems.Samples.Tests.Ch16`.
