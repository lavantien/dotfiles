#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= characters and progression

The artillery game so far has two tanks and nothing to lose. The
trajectory shooters this book's capstone draws its progression from,
the DDTank lineage, put a character at the center: a level, primary
attributes, gear, a bag, and one screen that shows all of it. This
chapter builds that character as plain data and pure functions,
integers only, because a character that can drift cannot be replayed.

== four primaries, four elements

#listing("game-systems/samples/src/Ch14/Attributes.cs", first: 4, last: 31, caption: [the four elements every effect speaks, and the four primaries every stat derives from])

`PrimaryBlock` is four integers and nothing else, with component wise
addition as its only operator, which is all composing bonuses ever
needs. Offense raises every damage number and crit damage, defense
raises health, armor percent, and all resistances, agility raises
stamina regen and the turn order, luck raises crit chance and dampens
the wind drawn on your turn. The `Element` enum fixes the vocabulary
every weapon, resistance, and effect shares, so earth is the same
integer in the catalog, the pipeline, and the save.

#diagram([which primary moves which number, the four by four map], length: 13pt, {
  let cols = ([damage,#linebreak()crit dmg], [health, armor#linebreak()resistances], [stamina regen#linebreak()turn order], [crit chance,#linebreak()wind])
  let rows = ([Offense], [Defense], [Agility], [Luck])
  for c in range(4) {
    cdraw.content((6.9 + c * 5.0, 7.3), cols.at(c), size: 6pt)
  }
  for r in range(4) {
    cdraw.content((2.6, 6.0 - r * 1.3), rows.at(r), size: 6.5pt)
    for c in range(4) {
      let f = if c == r { luma(205) } else { luma(245) }
      cdraw.rect((4.9 + c * 5.0, 5.5 - r * 1.3), (8.9 + c * 5.0, 6.5 - r * 1.3), fill: f, radius: 0.02)
    }
  }
  cdraw.content((12.4, 0.9), [every effect speaks one of four elements], size: 6pt)
  cdraw.content((12.4, -0.4), [earth, water, fire, wind, the same integer everywhere], size: 6pt)
})

== growth as arithmetic

#listing("game-systems/samples/src/Ch14/Characters.cs", first: 33, last: 62, caption: [stats scale off the base, xp escalates quadratically, one award can cross levels])

Growth is derived, never stored: `AtLevel` scales the base sheet by
half the base per stat per level, minimum one so no stat freezes at
an even base, and a zero stat stays zero, a stat the base does not
have must not grow from nothing. The same rule serves the legacy
stat block and the primaries. The xp requirement is
`20 × level²`. The loop in `GainXp` is the part worth noticing, one
award may cross several levels in a single call because the
expedition boss payout in the capstone is large enough to do exactly
that. Storing grown stats instead of deriving them would invite the
classic bug, a rebalance that leaves saved characters frozen at the
old curve. Here the curve lives in the binary and the sheet holds
only level and xp.

#diagram([the quadratic xp curve, one award crossing two levels], length: 13pt, {
  // xp for next level is 20 x level squared; an award of 1300 at level 5 spans 500 + 720
  let X(l) = 2.2 + l * 1.7
  let H(xp) = 0.8 + xp * 0.0045
  cdraw.line((1.8, 0.8), (20.4, 0.8), stroke: luma(100))
  for l in range(1, 11) {
    cdraw.rect((X(l) - 0.6, 0.8), (X(l) + 0.6, H(20 * l * l)), fill: luma(235), radius: 0.02)
    cdraw.content((X(l), 0.3), [#l], size: 6pt)
  }
  cdraw.rect((X(5) - 0.6, 0.8), (X(5) + 0.6, H(1300)), fill: luma(205), radius: 0.02)
  for v in (500, 1000, 2000) {
    cdraw.line((1.8, H(v)), (20.4, H(v)), stroke: luma(235))
    cdraw.content((1.2, H(v)), [#v], size: 6pt)
  }
  cdraw.content((10.5, 10.9), [xp for next level: 20 x level squared], size: 6pt)
  cdraw.content((10.5, 9.7), [one award of 1300 at level 5], size: 6pt)
  cdraw.content((10.5, 8.5), [clears 500 and 720, two levels in one call], size: 6pt)
  cdraw.content((10.5, -0.5), [grown stats are derived from level, never stored], size: 6pt)
})

== effective stats as one pure function

#listing("game-systems/samples/src/Ch14/Attributes.cs", first: 96, last: 142, caption: [derive folds growth, gear, and pet into every number the battle reads])

#diagram([the composition stack, growth and bonuses fold into the stats the battle reads], length: 13pt, {
  let box(x0, y0, x1, y1, label) = {
    cdraw.rect((x0, y0), (x1, y1), fill: luma(230), stroke: luma(120), radius: 0.05)
    cdraw.content(((x0 + x1) / 2, (y0 + y1) / 2), [#label], size: 6.5pt)
  }
  box(0, 3.2, 4.8, 5.2, [base stats])
  cdraw.content((5.4, 4.2), [+], size: 9pt)
  box(6.0, 3.2, 11.2, 5.2, [level growth])
  cdraw.content((11.8, 4.2), [+], size: 9pt)
  box(12.4, 3.2, 17.0, 5.2, [gear contrib])
  cdraw.content((17.6, 4.2), [+], size: 9pt)
  box(18.2, 3.2, 22.2, 5.2, [pet contrib])
  cdraw.line((22.2, 4.2), (24.2, 4.2), mark: (end: ">"))
  box(24.2, 3.2, 30.6, 5.2, [primaries])
  cdraw.line((25.6, 3.2), (24.0, 2.0), mark: (end: ">"))
  cdraw.line((28.0, 3.2), (29.2, 2.0), mark: (end: ">"))
  cdraw.line((31.2, 3.2), (34.4, 2.0), mark: (end: ">"))
  box(20.8, -0.2, 26.6, 2.0, [max health#linebreak()100 + 8 × def])
  box(27.6, -0.2, 33.4, 2.0, [stamina, mana,#linebreak()crit, percents])
  box(34.8, -0.2, 41.0, 2.0, [power number])
})

The battle engine never reads the sheet directly. `Derive` folds
level growth, the summed gear contribution, and the active pet's
passives into the primaries, then derives everything combat consumes:
max health from defense, stamina from level only, mana from the pet
only, elemental resistances capped at 75, crit chance from luck, crit
damage and all damage percents from offense, and the one power number
that stands for the whole sheet. The raw sources stay exclusive by
construction: physical damage only arrives from a weapon, raw elements
only from the offhand, armor only from garments, and the percents only
from rings, the amulet, and the medal, enforced by the item catalog
never setting an illegal field. Deriving beats storing twice over,
the same sheet always composes to the same answer, and a bonus
changing at the source reaches the battle with no cache to
invalidate.

== the save file

#listing("game-systems/samples/src/Ch15/Sheet.cs", first: 36, last: 82, caption: [magic, version, length prefixed fields, the whole v2 sheet in one flat array])

The profile codec is chapter 12's discipline pointed at a character
instead of a match: magic first, then version, then length prefixed
and fixed width fields, big endian throughout. The v2 sheet carries
the loadout's 14 slots, the per slot upgrade levels, the paged grid,
and the wallet. `Load` validates before it allocates and every
failure names the field that broke, so a truncated file says `grid`
instead of handing back a half built character, and a version 1 file
is refused outright, the binary is book-versioned. The tests pin the
round trip, the corruption messages, and byte determinism, two saves
of one sheet are equal and a single level of difference moves them
apart.

#diagram([the v2 sheet as bytes, name prefix, fixed tail, eight per cell], length: 13pt, {
  // header to scale at 0.85 units per byte, the name is variable width
  let w = 0.85
  cdraw.rect((1, 6.4), (1 + 4 * w, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((1 + 2 * w, 7.0), [magic, 4], size: 6pt)
  cdraw.rect((1 + 4 * w, 6.4), (1 + 5 * w, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((1 + 4.5 * w, 8.1), [version, 1], size: 6pt)
  cdraw.line((1 + 4.5 * w, 7.85), (1 + 4.5 * w, 7.6), stroke: luma(100))
  cdraw.rect((1 + 5 * w, 6.4), (1 + 7 * w, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((1 + 6 * w, 5.9), [name len, 2], size: 6pt)
  cdraw.rect((1 + 7 * w, 6.4), (11.0, 7.6), stroke: (paint: luma(120), dash: "dashed"), radius: 0.02)
  cdraw.content((4.5 + 3.5 * w, 7.0), [name, n bytes], size: 6pt)

  // the fixed tail, grouped, 0.125 units per byte
  let g = 0.125
  let tail = ((12, [level, xp, pet: 12]), (16, [primaries: 16]), (56, [14 slots: 56]), (56, [14 upgrades: 56]), (8, [wallet: 8]), (4, [count: 4]))
  let at = 1.0
  for (i, pair) in tail.enumerate() {
    let (bytes, label) = pair
    cdraw.rect((at, 3.4), (at + bytes * g, 4.6), fill: luma(235), radius: 0.02)
    let y = if calc.even(i) { 3.1 } else { 1.9 }
    cdraw.content((at + bytes * g / 2, y), label, size: 6pt)
    at += bytes * g
  }
  cdraw.content((23.4, 4.0), [the tail is fixed,#linebreak()152 bytes], size: 6pt)

  // grid cells at the end, eight bytes each
  for c in range(2) {
    let x0 = 1.0 + c * 5.5
    cdraw.rect((x0, 0.2), (x0 + 2.75, 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 1.375, 0.65), [item, 4], size: 6pt)
    cdraw.rect((x0 + 2.75, 0.2), (x0 + 5.5, 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 4.125, 0.65), [count, 4], size: 6pt)
  }
  cdraw.content((17.6, 0.65), [8 per grid cell, then more cells], size: 6pt)
})

sources: the character and weapon feature framing follows the
ddtank ii description on the dd tank us wiki games page, "fully
customizable characters" and "versatile weapons with numerous
upgrading options", accessed 2026-09-09. Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 17 tests in
`GameSystems.Samples.Tests.Ch14`.
