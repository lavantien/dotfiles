#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= data oriented design

Chapter 3 chose a memory layout and promised it mattered. This chapter
is the receipt. Data oriented design is the practice of organizing
memory and code around how the data is actually transformed, in what
order, how often, and at what width, instead of around a taxonomy of
real world concepts. Its founding observation is arithmetic is nearly
free and waiting for memory is not: a register add is a single cycle,
while a load that misses every cache and goes to dram costs on the
order of two hundred. A loop that touches memory badly does not do
less math, it does the same math surrounded by stalls.

== the two shapes

#listing("game-systems/samples/src/Ch04/Dod.cs", first: 5, last: 24, caption: [array of structs against structure of arrays])

The object oriented shape puts each entity's whole state behind one
reference, so walking a list of entities walks a list of pointers,
and every hop is a potential cache miss wherever the allocator put
that object. The structure of arrays shape puts each field in its own
contiguous array, so reading `X` for a thousand entities reads a
thousand doubles in a straight line, sixteen per 128 byte cache line
on this machine, and the prefetcher sees the pattern after two lines.

#diagram([the two shapes, array of objects versus structure of arrays], length: 13pt, {
  // left: an array of references pointing at scattered heap objects
  cdraw.content((5.5, 7.2), [array of objects], size: 7pt)
  let rcell(x, t) = {
    cdraw.rect((x, 5.8), (x + 2.2, 6.6), fill: luma(230), radius: 0.05)
    cdraw.content((x + 1.1, 6.2), [#t], size: 6.5pt)
  }
  rcell(0, "ref e1"); rcell(2.4, "ref e2"); rcell(4.8, "ref e3")
  let obj(x, y, t) = {
    cdraw.rect((x, y), (x + 3.2, y + 1.7), fill: luma(245), stroke: luma(120), radius: 0.05)
    cdraw.content((x + 1.6, y + 0.85), [#t], size: 6.5pt)
  }
  obj(0.0, 3.4, "e1: x, y, flag"); obj(4.0, 2.2, "e2: x, y, flag"); obj(8.8, 0.8, "e3: x, y, flag")
  cdraw.line((1.1, 5.8), (1.6, 5.1))
  cdraw.line((3.5, 5.8), (5.4, 3.9))
  cdraw.line((5.9, 5.8), (10.2, 2.5))
  cdraw.content((4.8, -0.4), [pointer per entity, allocator decides where], size: 6.5pt)

  // right: each field in its own contiguous array
  cdraw.content((21.1, 7.2), [structure of arrays], size: 7pt)
  let arr(y, name, w) = {
    cdraw.content((14.4, y + 0.35), [#name], size: 6.5pt)
    for i in range(8) {
      cdraw.rect((16.0 + i * w, y), (16.0 + (i + 1) * w, y + 0.7), fill: luma(230), radius: 0.02)
    }
  }
  arr(5.4, "xs:", 1.3); arr(3.4, "ys:", 1.3); arr(1.4, "flags:", 0.9)
  cdraw.content((19.8, 5.0), [one cache line reads many xs], size: 6.5pt)
  cdraw.content((21.1, -0.4), [a flags scan reads one byte per entity], size: 6.5pt)
})

#listing("game-systems/samples/src/Ch04/Dod.cs", first: 46, last: 74, caption: [the same integration over both layouts])

The arithmetic is identical, statement for statement, and the test
proves it: both integrators over the same seeded data produce
bitwise equal positions and checksums. What differs is only the
memory traffic. Measured on this machine, .NET 10, release build, one
million entities, median of thirty rounds after warmup, the array of
objects takes 4.37 milliseconds per pass and the structure of arrays
takes 2.09, a factor of 2.1. The benchmark test keeps a loose guard,
the suite rerunning the same ordering at 300,000 entities: the soa
path must never lose by more than fifty percent, so a future runtime
change that inverts the honest ordering fails the suite instead of
silently rotting the chapter.

== what the soa shape buys beyond speed

#listing("game-systems/samples/src/Ch04/Dod.cs", first: 18, last: 26, caption: [a flags scan reads one byte per entity])

`CountFlagged` touches only the flags array, one byte per entity,
while the array of objects version of the same question drags every
pointer and every double into cache to read one flag. A query over a
subset of fields pays for exactly those fields, which is the same
property the ecs of chapter 3 relies on when a two component query
walks the shorter store. Sparse sets are dod applied to entity
storage.

#diagram([which entities are flagged, the bytes each shape must touch], length: 13pt, {
  // left: every ref and every double rides along to reach one flag
  cdraw.content((5.0, 9.6), [array of objects], size: 7pt)
  let rcell(x) = {
    cdraw.rect((x, 7.4), (x + 2.2, 8.2), fill: luma(235), radius: 0.05)
    cdraw.content((x + 1.1, 7.8), [ref], size: 6pt)
  }
  rcell(0); rcell(2.4); rcell(4.8)
  let obj(x, y) = {
    for c in range(4) {
      cdraw.rect((x + c * 1.0, y), (x + c * 1.0 + 1.0, y + 0.9), fill: luma(235), radius: 0.02)
    }
    cdraw.rect((x + 4.0, y), (x + 4.6, y + 0.9), fill: luma(205), radius: 0.02)
  }
  obj(0, 5.6); obj(3.4, 4.2); obj(6.8, 2.8)
  cdraw.line((1.1, 7.4), (2.0, 6.5), stroke: luma(100))
  cdraw.line((3.5, 7.4), (5.4, 5.1), stroke: luma(100))
  cdraw.line((5.9, 7.4), (8.8, 3.7), stroke: luma(100))
  cdraw.content((0.5, 6.05), [x], size: 6pt)
  cdraw.content((1.5, 6.05), [y], size: 6pt)
  cdraw.content((2.5, 6.05), [dx], size: 6pt)
  cdraw.content((3.5, 6.05), [dy], size: 6pt)
  cdraw.content((4.3, 6.05), [f], size: 6pt)
  cdraw.content((5.5, 1.6), [the flag hides inside every object], size: 6pt)
  cdraw.content((5.5, 0.6), [8 byte ref plus 32 bytes of doubles], size: 6pt)

  // right: the flags strip alone answers, the doubles never load
  cdraw.content((18.0, 9.6), [structure of arrays], size: 7pt)
  let strip(y, name, fill) = {
    cdraw.content((13.4, y + 0.35), [#name], size: 6pt)
    for i in range(8) {
      cdraw.rect((14.6 + i * 0.95, y), (15.55 + i * 0.95, y + 0.7), fill: fill, radius: 0.02)
    }
  }
  strip(7.35, "xs:", luma(245)); strip(6.3, "ys:", luma(245))
  strip(5.25, "dxs:", luma(245)); strip(4.2, "dys:", luma(245))
  cdraw.content((18.0, 8.7), [four double arrays, never touched], size: 6pt)
  strip(2.6, "flags:", luma(205))
  cdraw.content((18.0, 3.55), [the scan reads only this strip], size: 6pt)
  cdraw.content((18.4, 1.6), [1 byte per entity], size: 6pt)
  cdraw.content((18.4, 0.6), [128 flags per cache line], size: 6pt)
})

== alignment and padding

#listing("game-systems/samples/src/Ch04/Dod.cs", first: 26, last: 44, caption: [seventeen bytes of fields, twenty four of struct])

`Wide` holds two doubles and a byte, seventeen bytes of fields, and
`Marshal.SizeOf` reports twenty four: the runtime pads the tail so
the next element in an array starts on the largest member's
alignment, eight bytes, because an unaligned double costs split
accesses. `Packed` with `Pack = 1` really is seventeen, and the
choice is a trade rather than a free win, packed arrays trade
unaligned double access for density. The layout probe is a test
because padding rules are runtime facts, not intuitions, and the
numbers are asserted, not narrated.

#diagram([wide at twenty four bytes against packed at seventeen, the pad labeled], length: 13pt, {
  // one byte per 0.85 units, fields light, the tail pad shaded
  cdraw.content((10.7, 5.5), [Wide, Marshal.SizeOf 24], size: 6.5pt)
  cdraw.rect((1, 3.9), (7.8, 5.1), fill: luma(235), radius: 0.02)
  cdraw.rect((7.8, 3.9), (14.6, 5.1), fill: luma(235), radius: 0.02)
  cdraw.rect((14.6, 3.9), (15.45, 5.1), fill: luma(255), radius: 0.02)
  cdraw.rect((15.45, 3.9), (21.4, 5.1), fill: luma(205), radius: 0.02)
  cdraw.content((4.4, 4.5), [x, 8 bytes], size: 6pt)
  cdraw.content((11.2, 4.5), [y, 8 bytes], size: 6pt)
  cdraw.content((4.4, 3.4), [offset 0], size: 6pt)
  cdraw.content((11.2, 3.4), [offset 8], size: 6pt)
  cdraw.content((14.9, 3.4), [flag, 1], size: 6pt)
  cdraw.content((18.4, 3.4), [pad, 7], size: 6pt)
  cdraw.line((15.45, 3.9), (15.45, 5.1), stroke: luma(100))

  cdraw.content((9.75, 2.2), [Packed, Pack = 1, Marshal.SizeOf 17], size: 6.5pt)
  cdraw.rect((1, 0.6), (7.8, 1.8), fill: luma(235), radius: 0.02)
  cdraw.rect((7.8, 0.6), (14.6, 1.8), fill: luma(235), radius: 0.02)
  cdraw.rect((14.6, 0.6), (15.45, 1.8), fill: luma(255), radius: 0.02)
  cdraw.content((4.4, 1.2), [x, 8 bytes], size: 6pt)
  cdraw.content((11.2, 1.2), [y, 8 bytes], size: 6pt)
  cdraw.content((14.9, 0.1), [flag, 1], size: 6pt)
  cdraw.content((18.4, 1.2), [no pad], size: 6pt)

  cdraw.content((10.7, -1.1), [the pad keeps the next element's doubles on 8 byte alignment], size: 6pt)
})

#callout("note", "when not to do this", [
  Data oriented design pays where the same transform runs over many
  entities, projectiles, particles, tiles. It costs where entities
  are few and access is by name, one player, one camera, and a
  scattershot of one off systems. The capstone keeps the combatants
  and the turn machine as plain objects and reserves the ecs for the
  many: shells, embers, and particles. Optimize the loop the profiler
  says is hot, which chapter 13's counting harness identifies
  without a profiler attached.
])

sources: the memory latency ladder and cache line framing follow
Ulrich Drepper's "what every programmer should know about memory"
and Mike Acton's 2014 cppcon talk on data oriented design, the
numbers cited above are measured locally 2026-09-08 on
windows/amd64, .NET 10, `Marshal.SizeOf` probes run in the test
suite. Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 4 tests in
`GameSystems.Samples.Tests.Ch04`.
