#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= randomness and determinism discipline

A game rng has one job and it is not statistical elegance. It is
that every machine drawing "random" numbers produces the same
"random" numbers, because terrain, ai decisions, and wind gusts are
all replay inputs. `System.Random` seeds itself from the clock when
you do not pass a seed, and even seeded, its algorithm is an
implementation detail the runtime may change between versions, which
makes it the wrong tool for anything a replay touches. The fix is
the same as chapter 7's: own the arithmetic.

== splitmix64

#listing("game-systems/samples/src/Ch11/Rng.cs", first: 11, last: 23, caption: [a counter through an avalanche finalizer])

Splitmix64 is a state counter plus two xorshift-multiply rounds and a
final bare xor.
There is nothing to initialize and nothing platform dependent, one
`ulong` in, the same `ulong` sequence out, forever. It is not
cryptographic and a game does not want cryptographic, players
figuring out the wind pattern from saves is a feature, it wants
period, speed, and bit-identical streams.

#diagram([splitmix64: a counter through two xorshift-multiply rounds and a final xor], length: 13pt, {
  // the finalizer as one horizontal pipeline, constants live in the listing
  let boxes = (
    ([state#linebreak()counter], 1.0), ([+ gamma], 5.0),
    ([xor >> 30#linebreak()multiply], 9.0), ([xor >> 27#linebreak()multiply], 13.0),
    ([xor >> 31#linebreak()last xor], 17.0), ([the draw#linebreak()64 bits], 21.0),
  )
  for (t, x) in boxes {
    cdraw.rect((x, 7.0), (x + 3.2, 8.6), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.6, 7.8), t, size: 6pt)
  }
  for i in range(5) {
    let x0 = boxes.at(i).at(1) + 3.2
    cdraw.line((x0 + 0.1, 7.8), (x0 + 0.7, 7.8), stroke: luma(100))
  }
  cdraw.content((12.6, 6.6), [every round: shift right, xor, multiply], size: 6pt)

  // avalanche: two states one bit apart, half the output moves
  let bits(y, shaded) = {
    for i in range(16) {
      let f = if shaded.contains(i) { luma(205) } else { luma(245) }
      cdraw.rect((3.2 + i * 0.8, y), (4.0 + i * 0.8, y + 0.8), fill: f, radius: 0.02)
    }
  }
  bits(4.6, ()); bits(3.5, (5,))
  bits(2.0, (0, 2, 3, 6, 7, 9, 11, 13)); bits(0.9, (1, 2, 4, 5, 8, 10, 12, 14, 15))
  cdraw.content((2.2, 5.0), [state 1], size: 6pt)
  cdraw.content((2.2, 3.9), [state 2], size: 6pt)
  cdraw.content((2.2, 2.4), [draw 1], size: 6pt)
  cdraw.content((2.2, 1.3), [draw 2], size: 6pt)
  cdraw.content((18.9, 4.9), [one bit of#linebreak()state apart], size: 6pt)
  cdraw.content((10.0, 0.2), [about half the output bits move], size: 6pt)
})

== unbiased integers

#listing("game-systems/samples/src/Ch11/Rng.cs", first: 25, last: 37, caption: [rejection sampling against a bucket limit])

The tempting integer draw is `NextUlong() % max`, and modulo is
biased whenever `2^64` is not a multiple of `max`, which is always.
Seven buckets do not divide a power of two, so some buckets get
more of the raw range than others. Rejection sampling fixes it:
draw, discard draws at or above the largest exact multiple of the
bucket count, and every bucket receives the same width of raw
range. The uniformity test draws seventy thousand values into seven
buckets and checks each against ten thousand plus or minus five
hundred, and because the seed is fixed those bounds are not flaky,
they are either true of this deterministic stream or the sampler is
biased. Fixed point draws take the top 32 bits of one draw as a
value in `[0, 1)`.

#diagram([seven buckets: modulo folds the leftover, rejection discards it], length: 13pt, {
  // 2^64 = 7 * 2635249153387078802 + 2, so buckets 0 and 1 eat the tail under modulo
  for b in range(7) {
    cdraw.rect((1.0 + b * 2.7, 4.4), (3.7 + b * 2.7, 5.3), fill: luma(235), radius: 0.02)
    cdraw.content((2.35 + b * 2.7, 3.9), [#b], size: 6pt)
  }
  cdraw.rect((19.9, 4.4), (20.4, 5.3), stroke: luma(100), radius: 0.02)
  cdraw.line((19.9, 5.45), (17.5, 6.15), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((17.5, 6.15), (2.7, 6.15), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((2.7, 6.15), (2.35, 5.45), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((4.9, 6.15), (5.05, 5.45), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((12.0, 6.6), [modulo: the two leftover values fold into buckets 0 and 1], size: 6pt)
  cdraw.content((21.1, 4.85), [the tail,#linebreak()2 values], size: 6pt)

  for b in range(7) {
    cdraw.rect((1.0 + b * 2.7, 1.4), (3.7 + b * 2.7, 2.3), fill: luma(235), radius: 0.02)
  }
  cdraw.rect((19.9, 1.4), (20.4, 2.3), stroke: luma(100), radius: 0.02)
  cdraw.line((19.75, 1.25), (20.55, 2.45), stroke: luma(100))
  cdraw.content((12.0, 3.3), [rejection: a draw on the tail is discarded, redraw], size: 6pt)
  cdraw.content((12.0, 0.3), [every bucket the same width of raw range], size: 6pt)
})

== streams

#listing("game-systems/samples/src/Ch11/Rng.cs", first: 39, last: 54, caption: [fnv over the name, finalizer, fork])

One generator shared by every subsystem is a determinism bug with a
delay fuse: fix the wind by drawing one extra number and the ai's
decisions for the rest of the match change. The discipline is to
fork named streams at construction, wind from `Stream("wind")`,
terrain from `Stream("terrain")`, so subsystems never consume each
other's draws. The stream seed is the name hashed with fnv-1a and
passed through the same splitmix finalizer, and the reason for the
finalizer is book 11's chapter 12 finding again: raw fnv shares high
bits across similar inputs, and seeded streams named `"a"`, `"b"`,
`"c"` would land in correlated corners of the state space.

The last test states the discipline as an assertion: consuming from
the parent before forking shifts every child, so the fork point is
part of the replay contract. The capstone follows it twice over: the
battle forks `"wind"` in its constructor, and the campaign forks
`"battle"`, `"loot"`, `"craft"`, and `"hatch"` in its own, deriving
per stage battle seeds without a parent draw.

#flow(
  [the match seed forking named streams, children never share draws],
  node((0, -0.6), [the match seed,#linebreak()one counter]),
  node((-3, 1.2), [wind]),
  node((-1, 1.2), [terrain]),
  node((1, 1.2), [battle]),
  node((3, 1.2), [loot]),
  node((-1.5, 2.6), [fnv-1a over the name,#linebreak()then the finalizer]),
  node((1.5, 2.6), [each child its own counter,#linebreak()no shared draws]),
  edge((0, -0.6), (-3, 1.2), "-|>"),
  edge((0, -0.6), (-1, 1.2), "-|>"),
  edge((0, -0.6), (1, 1.2), "-|>"),
  edge((0, -0.6), (3, 1.2), "-|>"),
)

#callout("pitfall", "the shared static rng", [
  `static Random.Shared` is correct for cosmetic effects, muzzle
  sparks, screenshake, that no replay observes. The moment a draw
  changes game state it belongs to a named stream from the match
  seed, and the test suite's determinism check, same inputs, same
  state hash, is the guard that catches a smuggled `Random` call.
])

sources: splitmix64 constants from Steele, Lea, and Flood's
"fast splittable pseudorandom number generators" paper, and
learn.microsoft.com System.Random remarks, "the implementation of
the random number generator in the Random class isn't guaranteed to
remain the same across major versions of .NET", which is the hole
this chapter's owned arithmetic closes, accessed 2026-09-08.
Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 6 tests in
`GameSystems.Samples.Tests.Ch11`.
