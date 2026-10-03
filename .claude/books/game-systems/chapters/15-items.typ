#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= items, weapons, and crafting

The match so far fires one shell that does one thing. The genre this
book's capstone now draws from treats the weapon as the star of the
itemization: different weapons reshape the battlefield differently,
and the gear a fight drops comes back through upgrades as more of the
same piece. This chapter makes the weapon data, the terrain effects
compositions, the item stats exclusive by slot, the upgrade curve a
pure function, and the forge a pure function.

== the weapon as data

#listing("game-systems/samples/src/Ch15/Items.cs", first: 9, last: 43, caption: [four carve kinds, two profiles, and the elemental weapon record that carries them])

Everything a weapon does travels in one record. The damage profile
is a max damage and a radius, the carve profile is a kind plus a
scale knob, and the elemental fields say what the weapon is: its
element, the secondary element it splashes, and the elevation window
it can fire in, the earth ball stops at 55 degrees while the wind
bolt flies near vertical. The capstone's four weapons are the four
elements, each with 100 base physical damage and a different crater
shape. The catalog a game ships is a list of these records, versioned
with the binary, never serialized into saves, so adding a weapon is
a data change and rebalancing one never invalidates a save file.

#diagram([the weapon record: identity, two profiles, and a fire window], length: 13pt, {
  cdraw.rect((1, 0.1), (23, 8.4), stroke: luma(120), radius: 0.05)
  cdraw.content((12, 7.8), [WeaponDef, one record], size: 6.5pt)

  cdraw.rect((1.8, 4.5), (11.0, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 5.8), [identity: id, name,#linebreak()element, splash, bonus], size: 6pt)
  cdraw.rect((12.0, 4.5), (22.2, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 5.8), [damage: max, radius,#linebreak()shared with the crater], size: 6pt)
  cdraw.rect((1.8, 0.8), (11.0, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 2.1), [carve: kind, scale,#linebreak()one of four kinds], size: 6pt)
  cdraw.rect((12.0, 0.8), (22.2, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((17.1, 2.1), [window: min, max angle,#linebreak()earth to 55, wind near vertical], size: 6pt)

  cdraw.content((12, -0.6), [the catalog ships with the binary, never the save], size: 6pt)
})

== damage falls off linearly

#listing("game-systems/samples/src/Ch15/Items.cs", first: 44, last: 53, caption: [full damage at the impact, zero at the radius, integer raw units])

The falloff the artillery match used to own now belongs to the
weapon: the reach is the radius minus the horizontal distance, and
the damage scales by the fraction of reach remaining. Beyond the
radius the answer is exactly zero, which is the boundary the tests
pin, and the arithmetic stays in raw fixed point integers so a
damage number cannot drift between builds.

#diagram([linear falloff, full at the impact, exactly zero at the radius], length: 13pt, {
  cdraw.line((2, 1.0), (21.5, 1.0), stroke: luma(100))
  cdraw.line((2, 1.0), (2, 6.3), stroke: luma(100))
  cdraw.line((2, 6.0), (14, 1.0), stroke: 1pt + luma(30))
  cdraw.line((14, 1.0), (21.5, 1.0), stroke: 1pt + luma(160))
  cdraw.line((14, 1.0), (14, 6.3), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((14, 0.35), [radius], size: 6pt)
  cdraw.content((2.6, 6.5), [max damage], size: 6pt)
  cdraw.circle((8, 3.5), radius: 0.11, fill: luma(30))
  cdraw.line((8, 3.5), (8, 1.0), stroke: (paint: luma(160), dash: "dotted"))
  cdraw.content((9.6, 4.6), [half reach, half damage], size: 6pt)
  cdraw.line((8.3, 3.75), (8.9, 4.35), stroke: luma(160))
  cdraw.content((19.6, 5.4), [damage = max x reach / radius], size: 6pt)
  cdraw.content((18.8, 4.2), [reach = radius - distance], size: 6pt)
  cdraw.content((19.3, 1.9), [raw integer units throughout], size: 6pt)
})

== the terrain remembers the weapon type

#listing("game-systems/samples/src/Ch15/Items.cs", first: 59, last: 85, caption: [each kind is a fixed recipe over the terrain's own carve])

#diagram([the four carve shapes on the same ground, same base radius], length: 13pt, {
  // sample one parabolic dip exactly the way Terrain.Carve does
  let ground(cx, base, r, depth) = {
    let pts = ((cx - 5.4, base),)
    let n = 10
    for i in range(n + 1) {
      let dx = -r + 2 * r * i / n
      pts.push((cx + dx, base - depth * (1 - (dx / r) * (dx / r))))
    }
    pts.push((cx + 5.4, base))
    cdraw.line(..pts, stroke: luma(100))
  }
  let panel(cx, name, note, r, depth) = {
    ground(cx, 3.5, r, depth)
    cdraw.content((cx, 4.7), [#name], size: 6.5pt)
    cdraw.content((cx, 2.2), [#note], size: 6.5pt)
  }
  panel(4.6, [shell], [one circle], 2.2, 0.55)
  panel(13.8, [digger], [narrow, stacked deep], 0.9, 0.9)
  panel(23.0, [cluster], [five small craters], 0.6, 0.18)
  panel(32.2, [heavy], [wide, shallow], 3.4, 0.85)
  cdraw.line((0, 1.6), (36.8, 1.6), stroke: luma(220))
})

No new terrain code exists in this chapter. Each kind is a recipe
over the heightfield's own parabolic carve: the shell kind carves
once at full radius and belongs to the water droplet, the digger
kind stacks half-radius carves at the same column so depth
accumulates while width stays narrow and belongs to the fire ball,
the cluster kind drops small carves at the impact column and at
fixed offsets to each side and belongs to the wind bolt, and the
heavy kind carves once at double radius, trading depth per column
for reach across them, and belongs to the earth ball. The heightfield
never learns that weapons exist, which is the point, terrain
deformation composes from one primitive instead of growing a switch
per munition.

#figure(
  kind: image,
  supplement: [figure],
  caption: [the four carve profiles as the mvp renders them, one per element, fired from measured solutions on the seed 42 profile],
  grid(
    columns: (1fr, 1fr),
    column-gutter: 8pt,
    row-gutter: 4pt,
    text(size: 8pt)[water droplet, shell kind], text(size: 8pt)[fire ball, digger kind],
    image("/game-systems/figures/mvp-crater-water.png", width: 100%),
    image("/game-systems/figures/mvp-crater-fire.png", width: 100%),
    text(size: 8pt)[wind bolt, cluster kind], text(size: 8pt)[earth ball, heavy kind],
    image("/game-systems/figures/mvp-crater-wind.png", width: 100%),
    image("/game-systems/figures/mvp-crater-earth.png", width: 100%),
  ),
)

== item stats and where each raw number may come from

#listing("game-systems/samples/src/Ch15/Gear.cs", first: 10, last: 62, caption: [item types, the slot legality table, and the stats record whose raw fields are exclusive by source])

One legality table decides what fits where, and one stats record
decides what a piece lends its wielder. The raw fields are exclusive
by slot kind exactly as the stat rules say: physical damage on
weapons, raw elemental damage on the offhand, armor on the eight
garment slots, percent elemental damage on the ring pair, percent
resistances on the amulet and medal, and inherent primaries on
everything. The catalog enforces this by never setting an illegal
field, so the derivation in chapter 14 can trust its inputs.

#diagram([which raw field each slot kind may carry, one legality table], length: 13pt, {
  let cols = ([physical#linebreak()damage], [element#linebreak()damage], [armor], [element#linebreak()damage %], [resist#linebreak()%])
  let rows = ([weapon], [offhand], [garment], [ring], [amulet], [medal])
  let legal = ((0,), (1,), (2,), (3,), (4,), (4,))
  for c in range(5) {
    cdraw.content((6.7 + c * 3.6, 8.0), cols.at(c), size: 6pt)
  }
  for r in range(6) {
    cdraw.content((2.9, 6.1 - r * 1.15), rows.at(r), size: 6.5pt)
    for c in range(5) {
      let f = if legal.at(r).contains(c) { luma(205) } else { luma(245) }
      cdraw.rect((5.0 + c * 3.6, 5.65 - r * 1.15), (8.2 + c * 3.6, 6.55 - r * 1.15), fill: f, radius: 0.02)
    }
  }
  cdraw.content((11.5, -0.7), [inherent primaries ride on everything], size: 6pt)
  cdraw.content((11.5, -1.8), [eggs and materials fit no slot at all], size: 6pt)
})

== upgrades compound, costs double

#listing("game-systems/samples/src/Ch15/Gear.cs", first: 64, last: 108, caption: [each level grows every stat by a fifth of the previous, and the diamond price is 2 to the level])

Diamond upgrades are fixed point arithmetic in the open: every level
scales every stat on the item by a compounding 1.2, rounded to
nearest because the fixed point 1.2 sits a hair under and a +1
printed as 119 out of 100 would read as broken, and the price of
level n is exactly 2 to the nth diamonds, so the whole road to +12
costs 2 + 4 + ... + 4096. A stat the item does not have never grows,
which is the zero stays zero rule again.

#diagram([the stat scale compounds 1.2, the diamond price doubles], length: 13pt, {
  let X(l) = 2.0 + l * 1.5
  let Y(v) = 0.8 + v * 0.0011
  cdraw.line((1.7, 0.8), (20.6, 0.8), stroke: luma(100))
  for v in (1000, 2000, 4000) {
    cdraw.line((1.7, Y(v)), (20.6, Y(v)), stroke: luma(235))
    cdraw.content((1.1, Y(v)), [#v], size: 6pt)
  }
  let prev = none
  for l in range(13) {
    let p = (X(l), Y(calc.pow(2, l)))
    if prev != none { cdraw.line(prev, p, stroke: 1pt + luma(30)) }
    prev = p
  }
  let prev = none
  for l in range(13) {
    let m = calc.pow(1.2, l) * 100
    let p = (X(l), Y(m))
    if prev != none { cdraw.line(prev, p, stroke: (paint: luma(100), dash: "dashed")) }
    prev = p
  }
  for l in (0, 4, 8, 12) {
    cdraw.content((X(l), 0.3), [+#l], size: 6pt)
  }
  cdraw.content((8.0, 5.7), [diamond price, 2 to the n], size: 6pt)
  cdraw.content((8.0, 4.6), [stat scale, 1.2 to the n], size: 6pt)
  cdraw.content((8.0, 3.5), [at +12: 8.9x stat, 4096 diamonds], size: 6pt)
})

== crafting as consume plus roll

#listing("game-systems/samples/src/Ch15/Items.cs", first: 92, last: 123, caption: [the gate, the consume, and one roll from a caller supplied stream])

`CanCraft` is the gate and `Craft` enforces it with a throw, so there
is no silent partial consume. Inputs are consumed whether the roll
succeeds or not, the genre's real risk, and the output stacks onto
the inventory only on success. The roll is exactly one draw from a
stream the caller owns, chapter 11's discipline at its second call
site. The capstone's forge is now the diamond counter, but the
consume plus roll machinery stays the cleanest teaching shape for
stream ownership, and the campaign still forks its `"craft"` stream
the day a recipe table returns.

#flow(
  [crafting: gate, consume either way, one draw, stack on success],
  node((0, 0), [caller's stream]),
  node((2, 0), [gate: can craft]),
  node((4, 0), [consume inputs,#linebreak()either way]),
  node((2, 1.5), [one draw]),
  node((0, 2.8), [fail: inputs gone]),
  node((4, 2.8), [success: stacks]),
  edge((0, 0), (2, 0), "-|>"),
  edge((2, 0), (4, 0), "-|>"),
  edge((4, 0), (2, 1.5), "-|>"),
  edge((2, 1.5), (0, 2.8), "-|>", label: [tails]),
  edge((2, 1.5), (4, 2.8), "-|>", label: [heads]),
)

#callout("note", "why the stream is a parameter", [
  A `Random.Shared` roll inside `Craft` would make crafting the first
  nondeterministic system in the game, unreplayable and untestable in
  the scenario suite. Passing the stream in keeps this chapter's code
  pure and pushes the ownership decision to the one place that has
  the seeding policy, the composition root.
])

sources: the weapon grouping and drop framing follow the dd tank us
wiki weapons page, normal and special weapons earned from tasks,
events, and rare battle drops, accessed 2026-09-09, and the games
page pinned in chapter 14. Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 23 tests in
`GameSystems.Samples.Tests.Ch15`.
