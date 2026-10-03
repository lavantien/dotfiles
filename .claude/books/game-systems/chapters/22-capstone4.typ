#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= capstone part 4: balance by simulation

Every number before this chapter was chosen by hand: weapon radii,
health pools, the price of a hat. This chapter replaces the hand with
a monte carlo harness. The deterministic ai plays both sides of
scripted duels over fixed seeds, the suite pins bands on the results,
and the tuning loop walks: measure, change one constant, measure
again. Nothing here could flake, a failing band is a design
regression, because every battle is a pure function of the binary
and the seed span.

== the matrix

#listing("game-systems/capstone/src/BalanceMatrix.cs", first: 19, last: 52, caption: [mirrored duels on fixed seeds, the sweep ai on both sides])

Three questions, three runs. The mirror asks whether the first mover
wins by coin flip: identical combatants, one element per duel, team 1
win rate pooled over the elements should sit inside forty to sixty
percent. The parity run asks whether any element trivially dominates:
mean turns to resolve, the suite bands each element within a third of
the earth ball at eight seeds per element.
The ladder asks whether the power number means anything: the same
seeds twice, team 1 bare once and geared once, and gear must win
more.

#diagram([the three questions as three runs: mirror, parity, ladder], length: 13pt, {
  let cols = ([the run], [the question], [what it pins])
  let rows = ([mirror], [parity], [ladder])
  let cells = (
    ([identical duel,#linebreak()one element], [first mover a#linebreak()coin flip?], [team 1 inside#linebreak()40 to 60]),
    ([each element#linebreak()duels], [does one#linebreak()dominate?], [turns within a third#linebreak()of the earth ball]),
    ([same seeds, bare#linebreak()against geared], [does gear#linebreak()mean power?], [gear wins more,#linebreak()strictly]),
  )
  let xs = ((4.4, 10.0), (10.4, 17.0), (17.4, 24.6))
  for c in range(3) {
    let (a, b) = xs.at(c)
    cdraw.content(((a + b) / 2, 7.6), cols.at(c), size: 6pt)
  }
  for r in range(3) {
    cdraw.content((2.2, 6.05 - r * 2.0), rows.at(r), size: 6.5pt)
    for c in range(3) {
      let (a, b) = xs.at(c)
      cdraw.rect((a, 5.2 - r * 2.0), (b, 6.9 - r * 2.0), fill: luma(235), radius: 0.02)
      cdraw.content(((a + b) / 2, 6.05 - r * 2.0), cells.at(r).at(c), size: 6pt)
    }
  }
  cdraw.content((14.5, -0.3), [the sweep ai plays both sides on fixed seeds], size: 6pt)
})

== the tuning loop

The first measurement was brutal: the first mover won 72 to 84
percent of mirrors, and the earth ball took three and a half times
longer to resolve a duel than the wind bolt. Two constants moved.
The second mover's compensation gives whoever acts last in the
opening round 16 percent more health, and the mirror band is what
pinned that number: 20 percent overshot into the low forties, 12
undershot into the sixties. The earth ball's elevation window
widened from 45 to 55 degrees and its radius grew from 8 to 11,
because a weapon that cannot aim steep cannot land close, and a
weapon that cannot land close cannot kill.

#flow(
  [the tuning loop, one constant moves per lap],
  node((0, 0), [measure]),
  node((2.8, 0), [band?]),
  node((5.6, 1.2), [commit]),
  node((5.6, -1.2), [move one constant]),
  edge((0, 0), (2.8, 0), "-|>"),
  edge((2.8, 0), (5.6, 1.2), "-|>", label: [inside]),
  edge((2.8, 0), (5.6, -1.2), "-|>", label: [outside]),
  edge((5.6, -1.2), (0, 0), "-|>", bend: 35deg, label: [re-measure]),
)

== the bands and the report

#listing("game-systems/capstone/tests/BalanceTests.cs", first: 12, last: 34, caption: [pooled bands sized to the suite's runtime, never per weapon point estimates])

The bands are sized to their sample. A 16 seed per weapon mirror
swings twelve points either side of its mean, so a per weapon forty
sixty band would fail on noise alone. The suite pools all four
elements into 64 duels and bands the pool, keeps the parity band
loose at a third of the anchor, and demands the ladder strictly
rise. The wide report runs the same code at 128 mirror seeds and 32
per element and commits its output, `make balance` rewrites
`coverage/balance-report.md`, and the committed table is the
changelog: today it reads the pooled mirror at 0.58, the earth ball
at 10.5 mean turns against the wind bolt's 5.8, and the fire ball's
first mover edge at 0.69. The parity band holds on the suite's eight
seeds and not on the wide run: the wind bolt resolves at 0.55 of the
earth anchor and the water droplet at 0.61, both outside the third,
documented findings and the next tuning targets rather than hidden
constants.

#diagram([the pooled band against the per weapon noise swing], length: 13pt, {
  // percent from 30 to 70 across 20 units
  let X(pc) = 2.0 + (pc - 30) * 0.5
  for pc in (40, 60) {
    cdraw.line((X(pc), 1.2), (X(pc), 6.4), stroke: (paint: luma(160), dash: "dashed"))
    cdraw.content((X(pc), 6.9), [#pc], size: 6pt)
  }
  cdraw.line((X(50), 1.2), (X(50), 6.4), stroke: luma(220))
  cdraw.content((X(50), 6.9), [50], size: 6pt)

  cdraw.rect((X(38), 4.6), (X(62), 5.8), fill: luma(245), stroke: luma(160), radius: 0.02)
  cdraw.content((X(50), 5.2), [one weapon, 16 seeds: noise swings 12 either side], size: 6pt)
  cdraw.rect((X(44), 2.4), (X(56), 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((X(50), 3.0), [the pool, 64 duels], size: 6pt)
  cdraw.content((X(50), 1.6), [the pooled band holds where per weapon bands fail on noise], size: 6pt)
  cdraw.content((X(50), 0.4), [the committed report is the changelog: mirror 0.58, earth 10.5 turns], size: 6pt)
})

#callout("note", "why determinism is the precondition", [
  A monte carlo harness over `Random.Shared` battles would need
  thousands of runs per band for the same confidence and would still
  flake. The same determinism that makes replays byte identical
  makes one seed worth a hundred, and a failing band always means the
  design moved, never that the weather did.
])

sources: the method is the repo's own, the runs above, measured by
`make balance` and pinned by `dotnet test
books/game-systems/capstone/GameSystemsCapstone.slnx`, 3 tests in
`GameSystems.Capstone.Tests` under the balance namespace.
