#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge


= ecs theory

The object oriented game engine starts with a class hierarchy: `Entity`
at the root, `Actor` and `Prop` below it, `Tank : Actor`, `ExplosiveBarrel
: Prop`, and it works until the designer asks for a barrel that is also
a tank turret. Behavior in a real game is not a tree, it is a cross
product of concerns, renderable, mobile, damageable, flammable, ai
steered, and single inheritance forces every combination to be a class
someone declared in advance. The usual escape is a god `Entity` with
every field and an `IsActive` flag per feature, which moves the problem
from design time to every cache line in the update loop.

Entity component system inverts the factoring. Three words, three
definitions, no inheritance anywhere:

An *entity* is a name, usually one integer, that identifies a thing.
It has no fields and no methods. It is not a reference to an object,
it is a handle into storage someone else owns.

A *component* is plain data, a `Position`, a `Health`, a `Velocity`,
with no behavior attached. An entity owns zero or more of them and
gains and loses them at runtime, which is the composition that
inheritance could not buy: a flammable tank is a tank entity that
also carries an `Ignitable` component, declared by no one in advance.

A *system* is code that runs over every entity owning a particular
set of components. A movement system asks for `Position` plus
`Velocity` and cares about nothing else, so it processes tanks,
barrels, and bullets through one loop with no virtual dispatch.

The FAQ that consolidated this vocabulary states the trade plainly:
inheritance is a first class citizen in object oriented design,
composition is a first class citizen in ecs. The capstone's artillery
game is built this way, a shell is an entity with position, velocity,
and a trail component, and nothing in the code knows what a shell
"class" is.

== entities are handles with generations

#listing("game-systems/samples/src/Ch02/NaiveEcs.cs", first: 3, last: 7, caption: [an entity is a slot index plus a generation])

Because an entity is just a number, every ecs owes an answer to the
stale handle question. A system caches an entity id, the entity dies,
the slot is recycled for a new entity, and the cached id now names an
innocent bystander. The standard defense is a generation counter: the
handle is `(index, generation)`, destroying an entity bumps the slot's
generation, and a handle from an older generation is refused instead
of resolved. The test pins the whole lifecycle, same slot reused, new
generation, the old handle rejected on use.

#flow(
  [one slot's life, and the stale handle refused on use],
  node((0, 0), [create#linebreak()slot 4, gen 3]),
  node((2.8, 0), [destroy#linebreak()gen bumps to 4]),
  node((5.6, 0), [recycle#linebreak()slot 4, gen 4]),
  node((4.2, 2.2), [fresh (4, 4)#linebreak()resolves]),
  node((7.2, 2.2), [stale (4, 3)#linebreak()refused]),
  edge((0, 0), (2.8, 0), "-|>"),
  edge((2.8, 0), (5.6, 0), "-|>"),
  edge((5.6, 0), (4.2, 2.2), "-|>"),
  edge((5.6, 0), (7.4, 2.2), "-|>"),
)

== the reference implementation, and its bill

#listing("game-systems/samples/src/Ch02/NaiveEcs.cs", first: 28, last: 55, caption: [slot recycling behind create and destroy])

#listing("game-systems/samples/src/Ch02/NaiveEcs.cs", first: 57, last: 76, caption: [component bags: correct, general, boxed])

This is the first ecs nearly everyone writes, a dictionary of typed
bags per entity, and it is worth owning deliberately before replacing
it, because its semantics are the spec chapter 3 must meet: duplicate
component types rejected, missing components throw, destroy clears the
bags and recycles the slot. The bill arrives in the memory layout.
Every `Get<T>` is a dictionary probe, then a cast out of `object`,
which boxes every struct component on `Add` and allocates a copy on
every read. A query walks all rows and probes one hash table per
component per row:

#listing("game-systems/samples/src/Ch02/NaiveEcs.cs", first: 78, last: 99, caption: [a query as a full table scan with hash probes])

For a hundred entities this is nothing. For the million entities the
dod chapter measures, it is the difference between data in cache lines
and data behind pointers, and it is why real storage engines pick a
layout and defend it.

#flow(
  [one query row: dictionary probes and boxed copies against the contiguous walk],
  node((0, 0), [naive query, per row]),
  node((2.7, 0), [hash probe#linebreak()per component]),
  node((5.4, 0), [boxed copy#linebreak()on the heap]),
  node((8.1, 0), [unbox into#linebreak()a local]),
  node((0, 2.3), [sparse set walk]),
  node((2.7, 2.3), [dense structs#linebreak()in place]),
  node((5.4, 2.3), [8-byte rows,#linebreak()16 per cache line]),
  edge((0, 0), (2.7, 0), "-|>"),
  edge((2.7, 0), (5.4, 0), "-|>"),
  edge((5.4, 0), (8.1, 0), "-|>"),
  edge((0, 2.3), (2.7, 2.3), "-|>"),
  edge((2.7, 2.3), (5.4, 2.3), "-|>"),
)

== the two storage religions

Everything else in ecs design is a consequence of one question: where
does component data live.

*Archetype storage* groups entities that own exactly the same
component set into one contiguous block, Unity's entities package
calls them archetypes stored in 16 kb chunks, one array per component
type plus the entity ids. Iteration over a component set is a linear
walk through memory at full bandwidth. The cost is structural churn:
adding a component moves the entity's every component to a different
block, so composition changes are the expensive operation.

*Sparse set storage* gives each component type its own dense array
plus a sparse index, entity id to dense slot. Any component set
intersection iterates the shortest array and probes the others.
Component add and remove are swaps within one type's storage, cheap
and isolated, at the price of iteration touching one array per
component in the set instead of one block.

#diagram([the two storage religions, archetype chunk versus sparse set], length: 13pt, {
  // left: one archetype chunk holds every entity owning the same component set
  cdraw.content((4.5, 6.6), [archetype chunk: one per component set], size: 7pt)
  let acol(x, name) = {
    cdraw.rect((x, 1.8), (x + 3.0, 5.8), fill: luma(230), radius: 0.05)
    for i in range(1, 4) { cdraw.line((x, 5.8 - i), (x + 3.0, 5.8 - i)) }
    cdraw.content((x + 1.5, 6.0), [#name], size: 6.5pt)
  }
  acol(0, "entity"); acol(3.2, "pos x"); acol(6.4, "pos y"); acol(9.6, "vel x")
  cdraw.content((4.5, 1.2), [same set, contiguous, one linear walk per query], size: 6.5pt)

  // right: sparse set storage, one store per type, shown for Position
  cdraw.content((20.0, 6.6), [sparse set: one store per type], size: 7pt)
  let dcell(x, t) = {
    cdraw.rect((x, 3.4), (x + 3.4, 4.9), fill: luma(230), radius: 0.05)
    cdraw.content((x + 1.7, 4.15), [#t], size: 6.5pt)
  }
  dcell(14.2, "pos of e7"); dcell(18.0, "pos of e2"); dcell(21.8, "pos of e9")
  let scell(x, t) = {
    cdraw.rect((x, 0.9), (x + 3.4, 2.4), radius: 0.05)
    cdraw.content((x + 1.7, 1.65), [#t], size: 6.5pt)
  }
  scell(14.2, "e7 -> 0"); scell(18.0, "e2 -> 1"); scell(21.8, "e9 -> 2")
  for x in (15.9, 19.7, 23.5) { cdraw.line((x, 2.4), (x, 3.4)) }
  cdraw.content((20.0, 0.2), [sparse index maps entity to dense slot], size: 6.5pt)
})

Neither wins. Archetypes favor simulations where component sets are
stable and queries are wide, sparse sets favor games where entities
gain and shed components constantly, projectiles spawning and dying.
Chapter 3 builds sparse sets, because the artillery capstone's load is
spawn and death heavy, and the machinery is small enough to hold in
your head. The honest rule is to know which religion your storage
follows and write systems that respect its cheap path.

#callout("note", "tags are components too", [
  A component with no fields, an `Enemy` marker or a `Frozen` marker,
  is a tag. It carries no data, but it participates in queries
  exactly like any component, and it is often the cheapest way to
  route an entity through a system without adding a field anyone has
  to maintain. The capstone tags wind-affected embers so one marker
  routes them through the wind system while plain debris falls
  straight.
])

sources: github.com/SanderMertens/ecs-faq for the entity, component,
and system definitions and the composition over inheritance framing,
docs.unity3d.com entities 1.0 archetypes and chunks concepts for the
archetype storage model, accessed 2026-09-08. Verified by
`dotnet test books/game-systems/samples/GameSystemsBook.slnx`,
7 tests in `GameSystems.Samples.Tests.Ch02`.
