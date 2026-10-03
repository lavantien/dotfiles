#import "../../theme/lib.typ": listing, snippet, callout, flow
#import "@preview/fletcher:0.5.8": node, edge

= testing games

Games resist testing for one structural reason: the interesting
behavior is a thousand step conversation between systems, and the
habitual unit of tests, one function with inputs and an expected
output, is the wrong shape. This chapter builds the three tools that
fix the shape, a state hash, a headless harness, and a counting
harness, and every one of them exists because a chapter before it
paid for it. The hash works because state is raw words, the
headless run works because the sim needs no window, and the
counters work because systems are named loops.

== the state hash

#listing("game-systems/samples/src/Ch13/Harness.cs", first: 11, last: 27, caption: [fnv over raw words, splitmix finalizer, avalanche by construction])

`SimHash` folds the raw words of game state into one `ulong`. The
fnv-1a core hashes, the splitmix finalizer avalanches, and the
finalizer is not optional decoration: raw fnv moves few bits per
input bit, so two nearly identical states could collide in their
high bits and a determinism test would pass on luck. The avalanche
test measures the property directly, flip one input bit at each of
sixty four positions and count the output bits that move, and the
average must sit between 24 and 40, the neighborhoods of half.
Because the inputs are fixed the assertion is not a statistical
flake, it is either true of this hash or the hash is broken.

#flow(
  [raw words to one hash, one input bit moves half the output],
  node((0, 0), [raw words#linebreak()of state]),
  node((2, 0), [fnv-1a fold,#linebreak()word by word]),
  node((4, 0), [splitmix#linebreak()finalizer]),
  node((6, 0), [one ulong]),
  edge((0, 0), (2, 0), "-|>"),
  edge((2, 0), (4, 0), "-|>"),
  edge((4, 0), (6, 0), "-|>"),
)

== determinism as an assertion

The headless flight test is the template for every game test that
follows. A terrain from a seed, a wind drawn from a named stream, a
shell integrated until impact, all constructed from the same
chapters the capstone composes, run twice inside one test process,
and the impact points compared as raw words. No rendering, no
window, no timing dependence, and a failure means something
concrete: some draw crossed the simulation's skin. The capstone's
replay suite is this test scaled to whole matches, seed and turn
inputs in, final state hash out, twice.

#listing("game-systems/samples/src/Ch13/Harness.cs", first: 30, last: 41, caption: [systems tick counters, tests assert the counts])

The counting harness replaces the profiler for the questions tests
actually ask. "Did the physics system run exactly 600 times for 10
seconds of match" is an assertion about wiring, that the fixed step
clock feeds the system loop, and it catches the bug class where a
system silently stops being called after a state change. Chapter 4
deferred measuring to the profiler and chapter 7 promised the
cordic loop was cheap, this is the tool that turns both promises
into test facts.

#flow(
  [determinism as assertions, run twice, compare words, count ticks],
  node((0, 0), [same seed,#linebreak()same inputs]),
  node((2, 0), [run twice]),
  node((4, 0), [raw words#linebreak()compared]),
  node((6, 0), [equal,#linebreak()deterministic]),
  edge((0, 0), (2, 0), "-|>"),
  edge((2, 0), (4, 0), "-|>"),
  edge((4, 0), (6, 0), "-|>"),
)

#callout("note", "what game tests look like", [
  The suite that results has three layers. Unit tests over the pure
  pieces, the fixed point arithmetic, the codec, the turn queue,
  which are ordinary and most of the count. System tests over one
  subsystem with its harness, terrain determinism, flight
  reproducibility, counters. And scenario tests, whole matches with
  scripted inputs asserting invariants, someone always wins within
  the turn cap, no health below zero, the replay hash equals the
  live hash. The capstone ships all three.
])

sources: avalanche measurement follows the standard strict avalanche
criterion treatment, fnv-1a and splitmix64 constants already pinned
in chapters 9 and 11, accessed 2026-09-08. Verified by `dotnet test
books/game-systems/samples/GameSystemsBook.slnx`, 6 tests in
`GameSystems.Samples.Tests.Ch13`.
