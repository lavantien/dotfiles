#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= an ecs implementation in c\#

Chapter 2 defined the contract and charged it to a dictionary of
dictionaries. This chapter pays the same contract from sparse sets,
and the payment plan is the chapter: one dense array per component
type, one sparse index from entity to slot, one bitmask per entity,
and system loops that touch nothing but arrays. The entity handle
from chapter 2 is kept as is, only the storage under it is replaced,
which is the ecs promise working once already, nothing above the
world's api had to change shape.

#listing("game-systems/samples/src/Ch03/World.cs", first: 5, last: 27, caption: [system delegates with ref access, the world's three arrays])

The three parallel arrays at the top are the whole entity ledger:
`_gens` for stale handle rejection, `_alive` for liveness, `_masks`
for queries. A mask has one bit per registered component type, so a
world answers "does this entity own a T" with one AND, and the
honest limit is stated in the constructor, sixty four component types
per `ulong`, more requires a wider mask, and the budget is enforced
with an exception rather than silently wrapping.

== the store

#listing("game-systems/samples/src/Ch03/World.cs", first: 187, last: 223, caption: [dense components, dense entity ids, sparse index, append on add])

`Add` appends to both dense arrays and links the sparse entry, so
components of one type sit contiguous in memory, and the entity ids
sit beside them so iteration can name what it is visiting. There is
no boxing anywhere: `T` is constrained to `struct`, and `Get`
returns `ref T` into the dense array, which is why a system can
write `world.Get<Health>(e).Points -= 30` and the store sees it.
Chapter 2's version returned a boxed copy per read, the kind of
difference that is invisible in a seven entity test and that
chapter 4 measures at one million entities, where layout alone
costs a factor of 2.1.

#listing("game-systems/samples/src/Ch03/World.cs", first: 225, last: 256, caption: [contains by identity, swap remove, destroy cleanup])

Removal is the sparse set's signature move: the last dense row swaps
into the victim's slot, one write each to the component array, the
id array, and the sparse index of the moved entity. No shifting,
nothing before the hole is touched, order is not preserved and the
tests assert nothing about order for exactly this reason. Destroy
walks the stores and removes the entity's row from each, then
recycles the slot with a generation bump, so a stale handle is
refused by the ledger before any store ever sees it.

#diagram([the store as three arrays, and a removal paid in three writes], length: 13pt, {
  // one Store<Health> holding e2, e0, e4 in arrival order; remove e0
  let sv = ([1], [-], [0], [-], [2], [-])
  for i in range(6) {
    cdraw.rect((6.0 + i * 1.1, 6.0), (7.1 + i * 1.1, 6.9), fill: luma(235), radius: 0.02)
    cdraw.content((6.55 + i * 1.1, 6.45), sv.at(i), size: 6pt)
    cdraw.content((6.55 + i * 1.1, 7.35), [e#i], size: 6pt)
  }
  let ids = ([e2], [e0], [e4], [-])
  let hp = ([72], [30], [45], [-])
  for s in range(4) {
    let victim = s == 1
    let last = s == 2
    let fill = if victim { luma(205) } else { luma(235) }
    let stroke = if last { luma(100) }
    cdraw.rect((6.0 + s * 1.3, 3.6), (7.3 + s * 1.3, 4.5), fill: fill, stroke: stroke, radius: 0.02)
    cdraw.content((6.65 + s * 1.3, 4.05), ids.at(s), size: 6pt)
    cdraw.rect((6.0 + s * 1.3, 1.2), (7.3 + s * 1.3, 2.1), fill: fill, stroke: stroke, radius: 0.02)
    cdraw.content((6.65 + s * 1.3, 1.65), hp.at(s), size: 6pt)
    cdraw.content((6.65 + s * 1.3, 0.75), [s#s], size: 6pt)
  }
  cdraw.content((4.4, 6.45), [sparse], size: 6.5pt)
  cdraw.content((4.3, 4.05), [ids], size: 6.5pt)
  cdraw.content((4.1, 1.65), [dense], size: 6.5pt)

  // sparse[e] names the slot, the permutation is the arrows
  cdraw.line((6.55, 6.0), (7.95, 4.5), stroke: luma(100))
  cdraw.line((7.75, 6.0), (6.65, 4.5), stroke: luma(100))
  cdraw.line((10.95, 6.0), (9.25, 4.5), stroke: luma(100))

  // the swap: last row fills slot 1 on both dense arrays
  cdraw.line((9.25, 4.72), (7.95, 4.72), stroke: luma(100))
  cdraw.content((8.6, 5.02), [2], size: 6pt)
  cdraw.line((9.25, 2.32), (7.95, 2.32), stroke: luma(100))
  cdraw.content((8.6, 2.62), [1], size: 6pt)

  cdraw.content((17.8, 6.9), [remove e0, slot 1 the hole], size: 6.5pt)
  cdraw.content((17.8, 5.6), [1 last component moves left], size: 6pt)
  cdraw.content((17.8, 4.3), [2 last id moves left], size: 6pt)
  cdraw.content((17.8, 3.0), [3 e4's sparse slot flips to 1], size: 6pt)
  cdraw.content((17.8, 1.7), [count 3 to 2, no shift], size: 6pt)
})

== systems as loops

#listing("game-systems/samples/src/Ch03/World.cs", first: 98, last: 141, caption: [two component queries walk the shorter store and probe the other])

`ForEach` is the entire system interface. The two component version
walks whichever store holds fewer rows and probes the other through
its sparse index, so a `Health` by `Frozen` query over a hundred
frozen entities in a world of a million healthy ones visits a
hundred rows. The tags test rides exactly this shape, `Frozen`
carries no data, routes one entity through the system, and costs one
bit in a mask.

#flow(
  [a two component query walking the shorter store],
  node((0, 0), [Health + Frozen query]),
  node((2.2, 1.1), [walk shorter store]),
  node((2.2, -1.1), [probe other store]),
  node((4.4, 0), [body(ref a, ref b)]),
  node((4.4, 1.9), [deferred spawn, kill], corner-radius: 2pt),
  edge((0, 0), (2.2, 1.1), "-|>"),
  edge((2.2, 1.1), (2.2, -1.1), "-|>", label: [mask check per row]),
  edge((2.2, -1.1), (4.4, 0), "-|>"),
  edge((4.4, 0), (4.4, 1.9), "-|>", label: [drained after the loop]),
)

The guard around the loops is the discipline sparse sets demand.
Iteration holds dense indices into arrays that structural changes
rearrange, so adding, removing, or destroying while a system runs is
rejected with an exception. The honest pattern is deferred mutation:
a system records the entities it wants to spawn or kill, and the
frame's outer code applies the list after the loop returns. The
capstone's impact resolution works this way, explosions queue entity
deaths, particle spawns, and the cluster bomb's children, and the
tick drains the queues between systems.

#callout("pitfall", "what this world does not have", [
  No archetypes, so a wide five component query probes four sparse
  indexes per row instead of walking one block. No parallel
  scheduling, systems run in registration order on one thread. No
  change detection, a system that must react to edits polls or
  compares. Each omission is deliberate, this world is small enough
  to verify by reading, and each is a door into the industrial
  engines when the game outgrows it.
])

sources: design follows chapter 2's cited ecs-faq storage discussion
and the sparse set literature it points to, the unity entities
archetype docs remain the contrast case, accessed 2026-09-08.
Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 8 tests in
`GameSystems.Samples.Tests.Ch03`.
