#import "../../theme/lib.typ": listing, snippet, callout, flow
#import "@preview/fletcher:0.5.8": node, edge

= finite state machines

Every game is full of things that are always in exactly one mode. A
turn is aiming, firing, or resolving, never two at once. A menu is
open or closed, a unit is idle, moving, or attacking, a network
session is connecting, live, or ended. The failure mode is also
universal: the mode lives as a pile of bools and every code path
that touches them has to keep the impossible combinations
impossible. The finite state machine makes the mode a single value
and the legal mode changes data.

== transitions as table rows

#listing("game-systems/samples/src/Ch05/Fsm.cs", first: 10, last: 23, caption: [rows keyed by from state and event, guards and actions optional])

A row names its source state, its event, and its target, plus two
optional hooks. A guard answers "is this change legal right now",
an action observes the change happening. Registration order matters
because rows for the same `(state, event)` are tried in order and
the first guard that passes wins, which is how one event routes to
different targets on different conditions:

#listing("game-systems/samples/src/Ch05/Fsm.cs", first: 25, last: 39, caption: [fire: first passing row moves the machine])

`Fire` returns a bool instead of throwing, and that is a deliberate
choice worth defending in review. In a game, most events most of
the time are irrelevant to most machines, the player presses jump
while the menu is open, and the machine's honest answer is "not
now", an answer the caller checks or ignores. The alternative,
throwing on every unhandled pair, turns the common case into
exception-driven control flow. The trade is real though: a refused
event is silent, so a wiring typo reads as "nothing happens", which
is why the tests pin refusals explicitly.

The artillery demo in the tests is the capstone's actual turn
machine in miniature: `Idle` to `Aiming` on start, `Aiming` to
`Firing` on fire, `Firing` to `Resolving` on impact, and the turn
end routed by a guard, more than one player alive loops back to
`Aiming`, otherwise the machine lands in `GameOver` and stays.
The last property is free: with no row for any event out of
`GameOver`, every fire is refused, and a terminal state is simply a
state with no exits.

#flow(
  [the turn machine, one row per arrow],
  node((0, 0), [Idle]),
  node((2.0, 0), [Aiming]),
  node((4.0, 0), [Firing]),
  node((6.0, 0), [Resolving]),
  node((8.2, 0), [GameOver]),
  edge((0, 0), (2.0, 0), "-|>", label: [start]),
  edge((2.0, 0), (4.0, 0), "-|>", label: [fire]),
  edge((4.0, 0), (6.0, 0), "-|>", label: [impact]),
  edge((6.0, 0), (2.0, 0), "-|>", bend: 28deg, label: [guard: players alive > 1]),
  edge((6.0, 0), (8.2, 0), "-|>", label: [guard: else]),
)

#callout("note", "the doors out of a flat fsm", [
  Flat machines stop scaling when states share behavior, a pause
  overlay that any state can enter, or when history matters,
  returning to the state you came from. The standard exits are
  hierarchical state machines, where a state owns substates, and
  pushdown automata, which stack states so exiting restores the
  previous one. The capstone stays flat because a turn based
  artillery match has neither problem, and the table is auditable
  at a glance, every legal change is one row.
])

sources: gameprogrammingpatterns.com "state" chapter for the
boolean pile against single state value framing, accessed
2026-09-08. Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 6 tests in
`GameSystems.Samples.Tests.Ch05`.
