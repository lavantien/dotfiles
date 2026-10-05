#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= turn systems and game flow

Real time games spend their complexity on the loop. Turn based games
spend it on the queue: who acts, in what order, and what happens to
the order when someone stops existing mid round. The artillery
capstone is turn based, and its fairness lives entirely in this
chapter's data structure.

== initiative order

#listing("game-systems/samples/src/Ch10/TurnQueue.cs", first: 8, last: 22, caption: [sorted by initiative, ties by registration, a cursor into the living])

The order is computed once from the roster, and the sort is stable,
which is not decoration here: initiative ties resolved by
registration order are the same discipline book 9's sorting chapter
defended for `OrderBy`, an unstable sort would make the tie break
change between runs and the match would not replay. `Round` counts
completed cycles of the living, `Current` is a cursor, and the
structure never re-sorts, it only removes.

#listing("game-systems/samples/src/Ch10/TurnQueue.cs", first: 24, last: 49, caption: [advance wraps, removal fixes the cursor])

`Remove` is where turn queues earn their keep. An actor dying mid
round must not skip or double the next actor's turn: removing an
entry before the cursor pulls the cursor back by one so the same
actor stays current, removing the current actor leaves the cursor
pointing at the successor, and a removal that empties the tail wraps
with a round increment. The tests walk every case, including the
one that locks most hand rolled implementations, an actor marked
dead before their turn comes up is simply never visited, no skip
logic anywhere.

#diagram([one round on the queue, the cursor through advance and three removals], length: 13pt, {
  // initiative order A 9, B 7, C 5, D 3; caret marks the cursor
  let strip(y0, names, dead: (), cursor: none) = {
    for i in range(names.len()) {
      let x0 = 2.0 + i * 2.0
      cdraw.rect((x0, y0), (x0 + 2.0, y0 + 0.9), fill: luma(235), stroke: if dead.contains(i) { luma(100) }, radius: 0.02)
      cdraw.content((x0 + 1.0, y0 + 0.45), names.at(i), size: 6.5pt)
      if dead.contains(i) {
        cdraw.line((x0 + 0.25, y0 + 0.15), (x0 + 1.75, y0 + 0.75), stroke: luma(100))
      }
    }
    if cursor != none {
      let cx = 3.0 + cursor * 2.0
      cdraw.line((cx - 0.2, y0 - 0.45), (cx, y0 - 0.15), stroke: 1pt + luma(30))
      cdraw.line((cx + 0.2, y0 - 0.45), (cx, y0 - 0.15), stroke: 1pt + luma(30))
    }
  }

  strip(8.2, ([A], [B], [C], [D]), cursor: 1)
  cdraw.line((9.5, 9.5), (6.0, 10.0), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((6.0, 10.0), (2.5, 9.5), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((6.0, 10.35), [the tail wraps, round increments], size: 6pt)
  cdraw.line((5.4, 7.45), (6.6, 7.45), stroke: luma(100))
  cdraw.content((6.0, 7.15), [advance], size: 6pt)

  strip(5.7, ([A], [B], [C], [D]), dead: (1,), cursor: 2)
  strip(3.2, ([A], [B], [C], [D]), dead: (2,), cursor: 3)
  strip(0.7, ([A], [B], [D]), dead: (2,), cursor: 0)

  cdraw.content((2.6, 12.0), [initiative order, one box per living actor], size: 6pt)
  cdraw.content((17.5, 9.4), [advance steps the cursor right], size: 6pt)
  cdraw.content((17.5, 8.2), [past the tail it wraps to A], size: 6pt)
  cdraw.content((17.5, 6.3), [remove one before the cursor], size: 6pt)
  cdraw.content((17.5, 5.1), [it pulls back, C stays current], size: 6pt)
  cdraw.content((17.5, 3.8), [remove the current actor], size: 6pt)
  cdraw.content((17.5, 2.6), [the cursor finds the successor], size: 6pt)
  cdraw.content((17.5, 1.3), [remove the tail], size: 6pt)
  cdraw.content((17.5, 0.1), [wrap, round increments], size: 6pt)
})

#callout("note", "simultaneous and team turns", [
  The queue here is strict alternation, one actor fully resolves
  before the next. The two standard variants are simultaneous turn,
  everyone commits orders blind then all resolve together, which
  needs an order buffer and a deterministic resolution tiebreak,
  and team phase turn, all of one side moves then all of the other,
  which is this queue with the team id as sort key. The capstone
  keeps strict alternation because one shell in flight per turn is
  the game.
])

sources: initiative queues and the cursor discipline follow
standard turn based design treatments, cross checked against the
turn scheduling vocabulary in the gameprogrammingpatterns.com game
loop chapter cited in chapter 1, accessed 2026-09-08. Verified by
`dotnet test books/game-systems/samples/GameSystemsBook.slnx`,
7 tests in `GameSystems.Samples.Tests.Ch10`.
