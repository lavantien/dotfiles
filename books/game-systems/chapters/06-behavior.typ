#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= behavior trees and utility scoring

The fsm of chapter 5 answers "what mode am I in" for one entity.
The question that scales badly is "what should I do next" when the
answer is a pile of conditions, fallbacks, and priorities, because
nested ifs with early returns encode the same shape as a tree but
cannot be inspected, reordered, or reused. The behavior tree makes
the decision a data structure again, and its whole grammar is five
words.

== the grammar

A node's `Tick` returns one of three statuses: `Success`,
`Failure`, or `Running` for work that spans more than one tick, a
shell still flying, an animation still playing. Leaves do work,
conditions turn predicates into statuses:

#listing("game-systems/samples/src/Ch06/Behavior.cs", first: 3, last: 22, caption: [status, the leaf, and the condition])

Composites walk their children and short circuit. A `Sequence` is
logical and, every child must succeed, the first failure ends the
walk with failure. A `Selector` is logical or, the first success
ends the walk with success, all failing fails. Both propagate
`Running` upward untouched:

#listing("game-systems/samples/src/Ch06/Behavior.cs", first: 25, last: 60, caption: [sequence and selector, the two composites])

The decorator family is one node here, `Inverter`, which swaps
success and failure and passes running through, and in the wild it
is where the family grows, repeats, timeouts, cooldowns, parallels
with success and failure policies. The compositor is deliberately
dumb. It walks children in order and returns, which is what makes a
hundred node tree still auditable, the priority of every option is
literally its position.

#flow(
  [the chapter's tree, selector takes the first succeeding child, sequence needs all],
  node((0.9, 0), [Selector]),
  node((-0.9, -1.3), [Sequence]),
  node((2.7, -1.3), [leaf: advance]),
  node((-1.9, -2.6), [cond: in range?]),
  node((0.1, -2.6), [leaf: fire]),
  edge((0.9, 0), (-0.9, -1.3), "-|>", label: [try first]),
  edge((0.9, 0), (2.7, -1.3), "-|>", label: [else]),
  edge((-0.9, -1.3), (-1.9, -2.6), "-|>"),
  edge((-0.9, -1.3), (0.1, -2.6), "-|>"),
)

#listing("game-systems/samples/src/Ch06/Behavior.cs", first: 63, last: 72, caption: [the inverter decorator])

== the ai in miniature

#listing("game-systems/samples/src/Ch06/Behavior.cs", first: 74, last: 98, caption: [fire in range else advance, built once, ticked per decision])

The tree closes over the ai's own mutable state, so building it
once in the constructor and ticking it per decision re-reads
`Distance` each time through the condition. The walk is reactive,
every tick restarts from the root, which costs re-running cheap
conditions and buys total statelessness, there is no memory to
desynchronize when the world changes under the tree. The
alternative, nodes with memory that resume where they left off, is
worth having exactly when the early conditions are expensive, and
the door is marked in the capstone where the ai re-solves its aim
on every decision for free because aiming is arithmetic.

#flow(
  [the same tree ticked at two distances, in range fires, out of range advances],
  node((1, -1), [distance 30,#linebreak()range 50]),
  node((1, 0), [Selector]),
  node((0, 1), [Sequence#linebreak()passes]),
  node((2, 1), [advance#linebreak()skipped]),
  node((0, 2), [in range?#linebreak()yes]),
  node((1, 2), [fire#linebreak()wins]),
  edge((1, 0), (0, 1), "-|>"),
  edge((1, 0), (2, 1), "-|>"),
  edge((0, 1), (0, 2), "-|>"),
  edge((0, 1), (1, 2), "-|>"),
  node((4, -1), [distance 80,#linebreak()range 50]),
  node((4, 0), [Selector]),
  node((3, 1), [Sequence#linebreak()fails]),
  node((5, 1), [advance#linebreak()wins]),
  node((3, 2), [in range?#linebreak()no]),
  node((4, 2), [fire#linebreak()never]),
  edge((4, 0), (3, 1), "-|>"),
  edge((4, 0), (5, 1), "-|>"),
  edge((3, 1), (3, 2), "-|>"),
  edge((3, 1), (4, 2), "-|>"),
)

== utility scoring

Trees decide by structure, first branch that applies wins. When the
choice is instead "pick the best of N by how good each is", utility
scoring is the honest tool: score every option as a number, take
the max, and normalize the inputs so the numbers mean something:

#listing("game-systems/samples/src/Ch06/Behavior.cs", first: 101, last: 115, caption: [linear response curves and argmax])

`Linear` maps a raw quantity, distance, health, ammo, onto 0 to 1
with clamped ends, and options combine several curves with weights
before `Best` picks the winner. The capstone's ai picks shot angles
this way, a score per candidate solution from expected damage and
travel risk, and the framework is four lines because the discipline
lives in choosing the curves, not the code. Curves beat bools for
the same reason the fsm's single state beats the flag pile, they
compose, 0.7 and 0.9 can be weighted against each other while
"close enough" and "far" cannot.

#diagram([response curves onto 0 to 1, weighted sums, argmax picks], length: 13pt, {
  // panel one: two clamped linear ramps over one raw quantity
  cdraw.line((2.5, 0.8), (2.5, 6.2), stroke: luma(100))
  cdraw.line((2.5, 0.8), (13.0, 0.8), stroke: luma(100))
  cdraw.content((2.0, 5.7), [1], size: 6pt)
  cdraw.content((2.0, 0.8), [0], size: 6pt)
  cdraw.line((2.5, 0.8), (4.5, 0.8), stroke: 1pt + luma(100))
  cdraw.line((4.5, 0.8), (10.5, 5.7), stroke: 1pt + luma(100))
  cdraw.line((10.5, 5.7), (13.0, 5.7), stroke: 1pt + luma(100))
  cdraw.line((2.5, 5.7), (5.5, 5.7), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((5.5, 5.7), (12.5, 0.8), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((12.5, 0.8), (13.0, 0.8), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((4.6, 6.35), [risk x 1], size: 6pt)
  cdraw.content((9.5, 6.35), [damage x 2], size: 6pt)
  cdraw.line((8.5, 0.8), (8.5, 6.2), stroke: (paint: luma(160), dash: "dotted"))
  cdraw.circle((8.5, 4.07), radius: 0.1, fill: luma(30))
  cdraw.circle((8.5, 3.6), radius: 0.1, stroke: luma(30))
  cdraw.content((9.25, 4.35), [0.67], size: 6pt)
  cdraw.content((9.25, 3.25), [0.57], size: 6pt)
  cdraw.content((7.75, 0.25), [raw quantity], size: 6pt)

  // panel two: the weighted sums as bars, the taller fires
  cdraw.content((18.8, 6.35), [two options, weighted sums], size: 6.5pt)
  cdraw.rect((15.2, 4.6), (18.68, 5.4), fill: luma(205), radius: 0.02)
  cdraw.rect((18.68, 4.6), (20.16, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((20.6, 5.0), [1.91], size: 6pt)
  cdraw.rect((15.2, 2.8), (16.76, 3.6), fill: luma(205), radius: 0.02)
  cdraw.rect((16.76, 2.8), (18.84, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((19.8, 3.2), [1.40], size: 6pt)
  cdraw.content((17.5, 4.2), [argmax], size: 6pt)
  cdraw.line((17.5, 4.32), (17.5, 4.6), stroke: luma(100))
  cdraw.content((17.8, 1.7), [dark: damage part, light: risk part], size: 6pt)
  cdraw.content((17.8, 0.5), [the higher score fires], size: 6pt)
})

#callout("note", "trees and utilities compose", [
  The standard architecture is both, a behavior tree where some
  leaves are utility choices. The tree owns priorities and
  sequencing, utility owns comparisons, and the capstone's ai is
  exactly this hybrid.
])

sources: Chris Simpson, "behavior trees for ai: how they work",
gamedeveloper.com, 2014, for the grammar, composite and decorator
semantics, and the data driven framing, and the gdc vault talk
"improving ai decision modeling through utility theory" for
response curves and weighted scoring, both accessed 2026-09-08.
Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 9 tests in
`GameSystems.Samples.Tests.Ch06`.
