#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= capstone part 1: the battle engine

The eighteen chapters before this one built systems; this chapter
assembles the battle that uses them, and this time the assembly is
literal. Shells
fly as entities in the chapter 3 world, the turn machine is the
chapter 5 fsm verbatim, damage and carving come from the chapter 15
weapon table, the pet abilities of chapter 16 gate inside the loop,
and every structural change queues and drains between systems the
way chapter 3 said it would. The battle is tick stepped: fire
launches, then one `Step()` per 60 hertz tick advances wind, flight,
impact, and smoke, so a renderer can watch the shell arc under live
wind.

== components and the machine

#listing("game-systems/capstone/src/BattleComponents.cs", first: 13, last: 33, caption: [shell components, the ember tag, and the chapter 5 states verbatim])

A shell carries position, velocity, a trail of its previous tick for
the collision segment, and a payload naming its weapon and owner.
Particles carry position, velocity, and life, and the `Ember` tag
marks the ones the wind should push: one marker routes them through
the wind system while plain debris falls straight. The phase and
command enums are copied name for name from the chapter 5 test
machine, so the miniature the fsm chapter taught and the engine this
chapter runs are the same object at two scales.

#diagram([the shell, the particle, and the chapter 5 machine verbatim], length: 13pt, {
  cdraw.rect((1, 0.4), (23, 8.0), stroke: luma(120), radius: 0.05)
  cdraw.content((12, 7.55), [one world, two kinds of body, one machine], size: 6.5pt)
  cdraw.rect((1.8, 5.0), (22.2, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((12, 5.9), [a shell: position, velocity,#linebreak()trail, payload: weapon and owner], size: 6pt)
  cdraw.rect((1.8, 2.9), (22.2, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((12, 3.8), [a particle: position, velocity, life,#linebreak()the ember tag routes it through wind], size: 6pt)
  cdraw.rect((1.8, 0.8), (22.2, 2.7), fill: luma(235), radius: 0.02)
  cdraw.content((12, 1.75), [phase: idle, aiming, firing, resolving, gameover#linebreak()cmd: start, fire, impact, nextturn], size: 6pt)
  cdraw.content((12, -0.2), [the enums copied name for name from the chapter 5 machine], size: 6pt)
})

== fire, then the tick owns the flight

#listing("game-systems/capstone/src/Match.Flight.cs", first: 16, last: 53, caption: [aim checks, the shell spawn, the fsm event, and the log entry])

#flow(
  [one turn through the battle engine's systems],
  node((0, 0), [fire]),
  node((2.0, 0), [spawn shell]),
  node((4.0, 0), [tick]),
  node((4.0, -1.4), [wind, embers]),
  node((4.0, -2.6), [flight, collide]),
  node((4.0, -3.8), [carve, damage]),
  node((4.0, -5.0), [particles]),
  node((6.8, -2.6), [drain queues]),
  node((9.0, 0), [turn end]),
  edge((0, 0), (2.0, 0), "-|>"),
  edge((2.0, 0), (4.0, 0), "-|>"),
  edge((4.0, 0), (4.0, -1.4), "-|>"),
  edge((4.0, -1.4), (4.0, -2.6), "-|>"),
  edge((4.0, -2.6), (4.0, -3.8), "-|>"),
  edge((4.0, -3.8), (4.0, -5.0), "-|>"),
  edge((4.0, -1.4), (6.8, -2.6), "-", bend: -35deg),
  edge((4.0, -2.6), (6.8, -2.6), "-|>", label: [drain]),
  edge((4.0, -5.0), (6.8, -2.6), "-", bend: 35deg),
  edge((6.8, -2.6), (9.0, 0), "-|>", label: [shells gone]),
)

`Fire` validates against the phase, the weapon's own elevation window,
and the power ceiling, queues the shell, drains it into existence,
fires the fsm's `Fire` event, and appends the turn record the replay
needs: shooter, angle, power, weapon, the decimeters walked while
aiming, and the flags carrying any paper plane flight. `Step` then
runs one tick of the firing phase. The wind system's query is
`ForEach<Position, Ember>`: the tag is the routing. The flight system
queries `Position` joined with `Payload`, shells and only shells,
integrates with the chapter 8 ballistics, and on a hit queues the
impact. Impact resolution carves with the weapon's chapter 15 profile,
runs the damage pipeline, physical falloff scaled by offense and cut
by armor percent, the offhand's raw element channeled through the
weapon plus its secondary splash, both cut by resistance, one crit
roll per target from a named stream, applies the element's on-hit
toll, fire burns for two of the target's turns, water soaks their
pools, wind knocks them two meters and grounds their plane, earth
carves again scaled by channeled earth damage, queues debris and
embers, and a wind bolt queues its five children, all through the
deferred lists. The drain applies them between systems, which is the
chapter 3 discipline, and the children are why it is not optional:
spawning mid iteration would throw. The turn ends when the payload
population hits zero, the fsm routes `NextTurn` through its living
teams guard, statuses tick at the afflicted's turn start before the
machine hands the turn over so a burn death is visible to the guards,
the smoke dies with the turn so the world is empty at rest, and the
state hash folds terrain, combatants, wind, phase, statuses, and the
pet flags.

The engine is no longer a duel. `Match` takes any number of
combatants, each on a team, the queue is built once with initiative
`40 + 2 * agility` and stable ties by id, a blast spares the shooter's
own team, and the match ends when one team remains. During the aiming
phase the actor may `Move` along the terrain, two stamina per meter
inside a 100 decimeter budget and 8 meters from anyone, and may fly
the paper plane `Teleport` once per match for 20 stamina, which ends
the walk so a turn is always walk then fly and the replay stays
exact.

== the weapon table

#listing("game-systems/capstone/src/WeaponCatalog.cs", first: 15, last: 54, caption: [four elemental weapons plus the wind child, versioned with the binary])

The catalog is the balance half of the identity split: the config
record carries seed, terrain shape, and power ceiling, everything a
replay needs to be itself, while damage numbers and carve shapes ride
with the binary. Rebalancing a weapon changes no save file and breaks
no replay, the state hash tells the truth about a mismatch, and the
wind child exists only as something the wind bolt spawns, never as a
player choice. The four weapons are the four elements: the earth ball
carves widest, heavy kind at twice its radius, the water droplet
splashes one round crater, the fire ball bores a narrow deep shaft,
and the wind bolt scatters pocks wide. Each carries 100 base physical
damage, its own elevation window, the earth ball stops at 55 degrees
while the wind bolt flies near vertical, a secondary element splash,
and an on-hit toll that matches its element.

#diagram([four elemental weapons plus the wind child, side by side], length: 13pt, {
  let cols = ([radius], [carve], [window], [on-hit toll])
  let rows = ([earth ball], [water droplet], [fire ball], [wind bolt], [wind child])
  let cells = (
    ([11], [heavy, wide], [-55 to 55], [carves again]),
    ([10], [one circle], [-70 to 70], [soaks pools]),
    ([9], [digger x 8], [-60 to 60], [burns two turns]),
    ([9], [cluster pocks], [-85 to 85], [knocks, grounds]),
    ([4], [small shell], [-89 to 89], [spawned only]),
  )
  let xs = ((5.2, 7.8), (8.3, 12.7), (13.2, 17.2), (17.7, 23.3))
  for c in range(4) {
    let (a, b) = xs.at(c)
    cdraw.content(((a + b) / 2, 8.1), cols.at(c), size: 6pt)
  }
  for r in range(5) {
    cdraw.content((2.5, 7.0 - r * 1.25), rows.at(r), size: 6pt)
    for c in range(4) {
      let (a, b) = xs.at(c)
      cdraw.rect((a, 6.55 - r * 1.25), (b, 7.45 - r * 1.25), fill: luma(235), radius: 0.02)
      cdraw.content(((a + b) / 2, 7.0 - r * 1.25), cells.at(r).at(c), size: 6pt)
    }
  }
  cdraw.content((11.0, -0.1), [all 100 base damage except the child at 40], size: 6pt)
  cdraw.content((11.0, -1.2), [the wind child is never a player choice], size: 6pt)
})

== the hybrid ai

#listing("game-systems/capstone/src/AiOpponent.cs", first: 26, last: 75, caption: [a selector tree over utility leaves, the sweep scores by expected damage])

Chapter 6's shape exactly: the tree owns priorities and the leaves
own comparison. A hurt boss tries desperation earth first, a close
fight scatters wind, and otherwise the sweep leaf scores the best
shot of every owned element by the damage its falloff would deal
where it lands, chapter 15's curve as the utility function, and
fires the argmax. The sweep respects each weapon's own elevation
window. `LastPlan` exposes the leaf that won for the tests and this
book. The tree is stateless, so the enemy re-solves its whole problem
every decision, which is free because aiming is arithmetic.

#flow(
  [the hybrid: a selector over desperation, scatter, and the sweep leaf],
  node((0, 0), [Selector]),
  node((-2.4, 1.4), [hurt boss?#linebreak()desperation earth]),
  node((0, 1.4), [close fight?#linebreak()scatter wind]),
  node((2.4, 1.4), [sweep]),
  node((2.4, 2.8), [score each shot by#linebreak()the damage its falloff deals]),
  node((2.4, 4.0), [fire the argmax]),
  edge((0, 0), (-2.4, 1.4), "-|>"),
  edge((0, 0), (0, 1.4), "-|>"),
  edge((0, 0), (2.4, 1.4), "-|>"),
  edge((2.4, 1.4), (2.4, 2.8), "-|>"),
  edge((2.4, 2.8), (2.4, 4.0), "-|>"),
)

== the match is still a pure function

The same seed and the same log rebuild the same end state, now with
walks, flights, and weapons in the log, magic "GSR3". The tests pin
the fsm's refusals, the world populated in flight and empty at rest,
wind impacts counting six on a wind bolt, the fire ball deeper and
the earth ball wider on identical flights, friendly fire off, team
wipes ending the match, agility ordering three actors, movement cost
and blocking, the paper plane once per match, burn, soak, knock, and
lock timing, the damage pipeline's caps, crit from a named stream,
and the shield halving a real incoming hit. The chapter 8 bug story
survives the rewrite: the first end to end run still needed the
segment collision to skip its launch end, and that regression pin is
still in chapter 8's suite.

#flow(
  [seed plus log in, the rebuild, the state hash out, run twice],
  node((0, 0), [seed plus the log,#linebreak()magic GSR3]),
  node((2, 0), [rebuild the match]),
  node((4, 0), [state hash out]),
  node((6, 0), [run twice,#linebreak()hashes equal]),
  edge((0, 0), (2, 0), "-|>"),
  edge((2, 0), (4, 0), "-|>"),
  edge((4, 0), (6, 0), "-|>"),
)

#callout("note", "why the tick matters", [
  The old engine resolved a shot inside one `Fire` call, which was
  correct and invisible. Splitting the flight into ticks changes no
  number, the tick count is a pure function of state, but it lets a
  window animate the shell instead of its recording, and it is what
  makes the drain between systems observable rather than decorative.
])

sources: everything here composes chapters 3, 5, 6, 8, 9, 11, 13, and
15 of this book, each with its own pinned sources. Verified by
`dotnet test books/game-systems/capstone/GameSystemsCapstone.slnx`,
95 tests in `GameSystems.Capstone.Tests` covering the engine, the
elements, the balance bands, and the ai.
