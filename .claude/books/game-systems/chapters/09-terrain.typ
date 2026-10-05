#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= terrain: heightmaps

The terrain of the artillery game is one array: a height per column.
That representation, a heightfield, is chosen before any generation
happens, because everything downstream consumes it, chapter 8's
collision walks it column by column, the renderer of chapter 21
draws it as a polyline, craters rewrite individual entries, and a
replay only needs the seed that produced it. Generation is where
determinism earns its keep: the same seed must rebuild the same map
bit for bit or the replay of a match played on a hill replays onto
a different hill.

== value noise from a hash

#listing("game-systems/samples/src/Ch09/Heightmap.cs", first: 11, last: 31, caption: [a knot height straight from splitmix64, then smoothstep between knots])

A lattice point, a knot every 16 columns, gets its height by hashing
its coordinates. The hash is splitmix64's finalizer, the avalanche
stage whose absence bit book 11, and chapter 11 owns the generator:
without it, adjacent knots share high bits and the terrain comes out
as broad terraces instead of hills. The top 32 bits of the mixed value become a fraction of the
amplitude, and between knots the height is the smoothstep of the
interpolation parameter, `3t^2 - 2t^3`, which has zero slope at both
ends and therefore no visible seam at the knots.

The tests pin the contract from both ends. At a knot the map equals
the hash output exactly, no interpolation, and between knots the
step from one column to the next is bounded by a quarter of the
amplitude, the suite's slack bound over the roughly nine percent
smoothstep's maximum slope of 1.5 allows across a 16 column cell, so
a jump in the map is a bug in the generator, not noise being noisy.

#diagram([two knots hashed by splitmix64, smoothstep between them], length: 13pt, {
  // hashed knot heights, one cell is 16 columns wide
  let hs = (0.7, 0.25, 0.6)
  let Y(h) = 0.8 + h * 4.5
  cdraw.line((0.5, 0.8), (17.5, 0.8), stroke: luma(100))
  let prev = none
  for c in range(2) {
    for k in range(25) {
      let t = k / 24
      let x = 1 + c * 8 + t * 8
      let h = hs.at(c) + (hs.at(c + 1) - hs.at(c)) * (3 * t * t - 2 * t * t * t)
      let p = (x, Y(h))
      if prev != none { cdraw.line(prev, p, stroke: 1pt + luma(30)) }
      prev = p
    }
  }
  cdraw.line((1, Y(0.7)), (9, Y(0.25)), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((9, Y(0.25)), (17, Y(0.6)), stroke: (paint: luma(160), dash: "dashed"))
  for i in range(3) {
    cdraw.circle((1 + i * 8, Y(hs.at(i))), radius: 0.12, fill: luma(30))
    cdraw.line((1 + i * 8 - 0.9, Y(hs.at(i))), (1 + i * 8 + 0.9, Y(hs.at(i))), stroke: (paint: luma(100), dash: "dotted"))
    cdraw.content((1 + i * 8, 0.3), [col #(i * 16)], size: 6pt)
  }
  cdraw.content((9.5, 6.5), [knot heights hashed by splitmix64], size: 6pt)
  cdraw.content((9.5, 5.3), [dashed: straight lerp, a corner at each knot], size: 6pt)
  cdraw.content((4.2, 4.1), [slope 0 here], size: 6pt)
  cdraw.content((12.5, 1.4), [and here], size: 6pt)
})

== octaves

#listing("game-systems/samples/src/Ch09/Heightmap.cs", first: 33, last: 45, caption: [fractional brownian motion: stack octaves at halving amplitude])

One noise layer is one hill every 32 columns, rolling but featureless.
Fractal noise stacks layers, octave two at half the amplitude and
twice the frequency, octave three at a quarter, and the sum reads as
a mountain range: big shapes from the low octaves, texture from the
high ones. The roughness test measures this as total variation over
the map and demands that four octaves vary more than one, the same
number a designer tunes by ear, octave count is the terrain's
roughness dial, amplitude its height dial, seed its identity.

#diagram([octaves at halving amplitude and doubling frequency, and their sum], length: 13pt, {
  let tau = 6.2832
  let wave(y0, amp, freq, name) = {
    let pts = ()
    for i in range(25) {
      let x = i
      pts.push((x, y0 + amp * calc.sin(freq * x * tau / 24)))
    }
    for i in range(24) { cdraw.line(pts.at(i), pts.at(i + 1), stroke: 0.7pt) }
    cdraw.content((12, y0 + amp + 0.35), [#name], size: 6.5pt)
  }
  wave(7.5, 0.9, 1, [octave 1, amplitude 1])
  wave(5.2, 0.45, 2, [octave 2, half amplitude, double frequency])
  wave(2.9, 0.22, 4, [octave 3, quarter amplitude])
  let pts = ()
  for i in range(25) {
    let x = i
    pts.push((x, 0.9 * calc.sin(x * tau / 24) + 0.45 * calc.sin(2 * x * tau / 24) + 0.22 * calc.sin(4 * x * tau / 24)))
  }
  for i in range(24) { cdraw.line(pts.at(i), pts.at(i + 1), stroke: 1pt) }
  cdraw.content((12, 2.0), [the sum, mountain shapes from the low octaves, texture from the high], size: 6.5pt)
})

#callout("note", "why the seed is the whole map", [
  A 512 column map is four kilobytes of state. A match with craters
  cannot be reproduced from the seed alone, because carving changes
  columns after generation, and the replay format of chapter 12
  carries the seed plus every shot, so the craters rebuild
  themselves from the same inputs. The map is a function of its
  seed and its wound history, nothing else.
])

sources: value noise, smoothstep interpolation, and octave stacking
follow the standard noise treatments, Iñigo Quílez's articles at
iquilezles.org on value noise among them, and the splitmix64
finalizer constants from the splitmix paper as used in book 11
chapter 12, accessed 2026-09-08. Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 6 tests in
`GameSystems.Samples.Tests.Ch09`.
