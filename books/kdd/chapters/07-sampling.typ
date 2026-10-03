// ch07, overwriting the stub 2026-09-22. every behavioral claim is one of
// the 29 checks in kdd/samples/src/Ch07/sampling.c or a cited source:
// Park and Miller 1988, "Random number generators: good ones are hard to
// find", CACM 31(10) 1192, the MINSTD generator (banked by
// kdd-contract-s1s2.md). all pinned values are witnessed by
// kdd-contract-s1s2.md + playground/kdd-matrix/gen_s2.py, run 2026-09-22,
// exit 0.
#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= sampling

One sample carries the chapter: `sampling.c` builds a deterministic
sampling toolkit on the Park-Miller MINSTD generator, draws a simple
random sample without replacement with a full recorded trace, allocates a
stratified sample by Hamilton's largest remainder, and walks a progressive
sampling schedule to its stop rule, 29 checks in all. The chapter makes 4
moves: the engine and why its arithmetic must be 64-bit, the partial
Fisher-Yates draw traced to the last swap, the leftover-seat allocation,
and the gain-based stop rule. Every behavioral claim below is one of the
29 checks of chapter 07's sample or the banked Park and Miller citation.
#xref-to("kdd", "process") quoted Fayyad et al. naming subsampling as part
of the loop itself; this chapter is that stage, and #xref-to("kdd",
"imbalance") and #xref-to("kdd", "hypothesis") both consume its output
later.

== the engine: park-miller minstd

A linear congruential generator is one line of arithmetic, $s' = (16807
s) mod (2^(31) - 1)$, and the pin is the MINSTD generator of Park and
Miller's 1988 CACM paper, multiplier 16807, modulus $2^(31) - 1 =
2147483647$ which is prime, seed 1. The single trap is width: the
intermediate product $16807 dot (2^(31) - 1)$ is about $3.6 times
10^(13)$, far past $2^(32)$, so the multiply must run in `uint64_t` or it
silently wraps and every downstream number in the chapter turns to a
different, wrong, but equally confident stream.

The dry run: from seed 1 the states read 16807, 282475249, 1622650073,
984943658, 1144108930, printed as `state1 = 16807` through `state5 =
1144108930`, each one asserted as its own check. Every value is one
multiply and one remainder, recomputable by hand, which is the property
the rest of the chapter leans on: a sampler whose stream anyone can audit
with pencil arithmetic.

#listing("kdd/samples/src/Ch07/sampling.c", first: 36, last: 40,
  caption: [the minstd recurrence, uint64 intermediates or it wraps])

#listing("kdd/samples/src/Ch07/sampling.c", first: 64, last: 75,
  caption: [five states from seed 1, each pinned])

#diagram([the state chain from seed 1, one multiply and one mod per hop], length: 13pt, {
  let vals = (([seed 1], [16807]), ([x 16807], [282475249]), ([x 16807], [1622650073]), ([x 16807], [984943658]), ([x 16807], [1144108930]))
  for i in range(5) {
    let x0 = 1.0 + i * 3.15
    cdraw.rect((x0, 4.6), (x0 + 2.7, 5.9), fill: luma(242), radius: 0.02)
    cdraw.content((x0 + 1.35, 5.45), vals.at(i).at(1), size: 6pt)
    cdraw.content((x0 + 1.35, 5.0), [state#(i + 1)], size: 5.5pt)
    if i < 4 {
      cdraw.line((x0 + 2.7, 5.25), (x0 + 3.15, 5.25), stroke: luma(60), mark: (end: ">"))
      cdraw.content((x0 + 2.92, 5.62), vals.at(i + 1).at(0), size: 5pt)
    }
  }
  cdraw.content((3.0, 3.9), [s' = (16807 s) mod (2^31 - 1)], size: 6pt)
  cdraw.content((3.0, 3.1), [16807 x (2^31 - 1) is about 3.6e13, past 2^32:], size: 6pt)
  cdraw.content((3.0, 2.4), [the multiply runs in uint64_t or it silently wraps], size: 6pt)
})

== five of twelve, fully traced

A simple random sample without replacement is k draws from n items where
no item repeats and every subset of size k is equally likely. The sample
implements it as a partial Fisher-Yates: keep the ids 0..11 in an array,
at step i pick $j = i + (s_i mod (12 - i))$ from the pool still
untouched, swap positions i and j, and emit the value now sitting at
position i. Exactly k = 5 steps run, the tail of the array is never
touched, and the trace of every (i, j, state) is recorded as it happens.

The dry run: the hand remainders drive everything. 16807 mod 12 = 7, so
j = 7 and the swap (0, 7) emits 7. 282475249 mod 11 = 1, j = 2, swap (1,
2) emits 2. 1622650073 mod 10 = 3, j = 5, swap (2, 5) emits 5. For the
fourth state the digit sum of 984943658 is 56, and casting out nines
leaves 2, so 984943658 mod 9 = 2, j = 5, and the swap (3, 5) emits the 1
that earlier swaps had parked at position 5. 1144108930 mod 8 = 2, j = 6,
swap (4, 6) emits 6. The printed trace reads `trace i=0 j=7 state=16807`
through `trace i=4 j=6 state=1144108930`, the draws print as `draw1 = 7`
through `draw5 = 6`, and the closing lines read `sorted = 1 2 5 6 7` and
the distinctness check, all five different. The D3 check runs the entire
procedure a second time and asserts every draw, every j, every state
matches, "ch07 srs double-run identical (D3)".

#listing("kdd/samples/src/Ch07/sampling.c", first: 44, last: 61,
  caption: [partial Fisher-Yates, j from the shrinking pool, trace recorded])

#listing("kdd/samples/src/Ch07/sampling.c", first: 139, last: 145,
  caption: [the five trace rows, each asserted])

#diagram([the trace ladder, one row per draw, arithmetic on the left, outcome on the right], length: 13pt, {
  let rows = (((0, 7, [16807], [7]), [16807 mod 12 = 7]), ((1, 2, [282475249], [2]), [282475249 mod 11 = 1]), ((2, 5, [1622650073], [5]), [1622650073 mod 10 = 3]), ((3, 5, [984943658], [1]), [984943658 mod 9 = 2]), ((4, 6, [1144108930], [6]), [1144108930 mod 8 = 2]))
  cdraw.content((1.5, 7.6), [i], size: 6pt)
  cdraw.content((3.5, 7.6), [j], size: 6pt)
  cdraw.content((7.6, 7.6), [state], size: 6pt)
  cdraw.content((11.6, 7.6), [swap], size: 6pt)
  cdraw.content((14.2, 7.6), [draw], size: 6pt)
  for r in range(5) {
    let y = 6.75 - r * 0.92
    let t = rows.at(r)
    cdraw.rect((0.9, y - 0.28), (15.9, y + 0.34), fill: luma(244), radius: 0.01)
    cdraw.content((1.5, y), [#t.at(0).at(0)], size: 6pt)
    cdraw.content((3.5, y), [#t.at(0).at(1)], size: 6pt)
    cdraw.content((7.6, y), t.at(0).at(2), size: 6pt)
    cdraw.content((11.6, y), [#(t.at(0).at(0)), #t.at(0).at(1)], size: 6pt)
    cdraw.content((14.2, y), t.at(0).at(3), size: 6pt)
    cdraw.content((7.6, y - 0.55), t.at(1), size: 5pt)
  }
  cdraw.content((4.6, 1.3), [the pool shrinks: 12, 11, 10, 9, 8], size: 6pt)
  cdraw.content((11.9, 1.3), [draw order 7, 2, 5, 1, 6], size: 6pt)
})

#callout("note", "determinism is what makes the sample auditable", [
  A sampling chapter has no business printing a number nobody can
  reproduce. The LCG stream is D0 integer arithmetic, the draw is
  recomputed from it in exact integers, and the sample closes the loop
  with a double-run assertion, "ch07 srs double-run identical (D3)",
  that runs the whole procedure a second time and compares every draw,
  every j, and every state. The pinned trace table is therefore not a
  snapshot of one lucky run, it is a theorem about this binary.
])

== stratified: hamilton's leftover seat

When classes differ wildly in size, a simple random sample
underrepresents the small ones by construction. Stratified sampling
splits n by class weight, and the sample implements Hamilton's largest
remainder method: take each class's exact quota, keep the floors, and
hand the leftover seats to the classes with the largest fractional
remainders. The fixture is 3 classes of counts A 47, B 31, C 22 over a
population of 100, with n = 10.

The dry run: the exact quotas are 4.7, 3.1, and 2.2 seats. The floors are
(4, 3, 2), which hands out 9 of the 10 seats, and the remainders over 100
are (70, 10, 20), printed as `floors 4 3 2 rems 70 10 20 left 1`. One
leftover seat remains and A's remainder 70 is the largest, so A takes it,
printed as `alloc A=5 B=3 C=2 sum 10` and asserted by "ch07 stratified
allocation (5,3,2)" plus the sum check against n = 10. The tie rule is
pinned too, equal remainders resolve by class name order, inert on this
fixture because the remainders are distinct, but living in the comparator
where any real allocation would exercise it.

#listing("kdd/samples/src/Ch07/sampling.c", first: 155, last: 167,
  caption: [quotas, floors, remainders, and the count of leftover seats])

#listing("kdd/samples/src/Ch07/sampling.c", first: 182, last: 195,
  caption: [leftover seats to the largest remainders, final (5,3,2)])

#diagram([the 10 seats: floors first, the leftover seat lands on A], length: 13pt, {
  let bars = (([A, 47], 4, 70, 5), ([B, 31], 3, 10, 3), ([C, 22], 2, 20, 2))
  for r in range(3) {
    let y = 6.6 - r * 1.15
    let b = bars.at(r)
    cdraw.rect((2.6, y), (2.6 + b.at(3) * 0.62, y + 0.78), fill: luma(240), radius: 0.02)
    cdraw.content((1.9, y + 0.39), b.at(0), size: 6pt)
    cdraw.content((2.6 + b.at(3) * 0.62 + 0.35, y + 0.39), [floor #b.at(1), rem #b.at(2), final #b.at(3)], size: 6pt)
  }
  cdraw.content((1.0, 2.9), [the 10 seats], size: 6pt)
  for i in range(10) {
    let x0 = 4.3 + i * 1.3
    let isA = i < 5
    let extra = i == 4
    cdraw.rect((x0, 2.0), (x0 + 1.1, 2.75),
      fill: if extra {luma(214)} else if isA {luma(238)} else if i < 8 {luma(230)} else {luma(244)}, radius: 0.01)
    cdraw.content((x0 + 0.55, 2.38), if isA {[A]} else if i < 8 {[B]} else {[C]}, size: 6pt)
  }
  cdraw.content((9.7, 1.4), [the 5th A seat is the leftover, remainder 70 beats 20 and 10], size: 6pt)
})

== progressive: stop when the gain dies

Progressive sampling grows the sample and watches the model's accuracy,
paying for data only while accuracy still climbs. The schedule is sizes
(25, 50, 100, 200, 400) with pinned accuracies (5\/8, 11\/16, 3\/4,
25\/32) for the first four stops, every one a dyadic fraction so the
doubles subtract exactly. The stop rule is the whole point: stop the
first time the gain is at or under 1\/32.

The dry run: the gains print as `gain1 = 0.0625`, `gain2 = 0.0625`,
`gain3 = 0.03125`, that is 1\/16, 1\/16, 1\/32. The third gain equals
the threshold, the rule fires, and the summary line reads `stop_idx 2
evals 4 chosen 200`: four evaluations happened, sizes 25 through 200, and
the chosen sample size is 200. Size 400 is never evaluated, never paid
for, and the checks "ch07 progressive stops after 4 evaluations" and
"ch07 progressive chosen size 200" pin both facts. The gains halving in
lockstep is the fixture's geometry, real curves flatten irregularly, but
the rule reads the same either way.

#listing("kdd/samples/src/Ch07/sampling.c", first: 203, last: 215,
  caption: [dyadic accuracies, gains as exact doubles])

#listing("kdd/samples/src/Ch07/sampling.c", first: 216, last: 227,
  caption: [first gain at or under 1/32 stops, chosen size 200])

#diagram([the accuracy staircase, the third gain hits the threshold and 400 is never bought], length: 13pt, {
  let px(s) = { 2.4 + calc.log(s / 25.0, base: 2) * 3.2 }
  let py(a) = { 1.6 + (a - 0.60) * 11.0 }
  cdraw.line((2.0, 1.2), (16.4, 1.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((2.0, 1.2), (2.0, 4.4), stroke: luma(60), mark: (end: ">"))
  for s in (25, 50, 100, 200, 400) {
    cdraw.line((px(s * 1.0), 1.05), (px(s * 1.0), 1.35), stroke: luma(60))
    cdraw.content((px(s * 1.0), 0.65), [#s], size: 6pt)
  }
  cdraw.content((1.6, 4.6), [accuracy], size: 6pt)
  let pts = ((25, 0.625, [5/8]), (50, 0.6875, [11/16]), (100, 0.75, [3/4]), (200, 0.78125, [25/32]))
  for i in range(pts.len() - 1) {
    let a = pts.at(i)
    let b = pts.at(i + 1)
    cdraw.line((px(a.at(0) * 1.0), py(a.at(1))), (px(b.at(0) * 1.0), py(b.at(1))), stroke: luma(60))
  }
  for i in range(4) {
    let p = pts.at(i)
    cdraw.circle((px(p.at(0) * 1.0), py(p.at(1))), radius: 0.11, fill: luma(150), stroke: luma(60))
    cdraw.content((px(p.at(0) * 1.0), py(p.at(1)) + 0.38), p.at(2), size: 6pt)
  }
  cdraw.line((px(200.0), py(0.78125)), (px(400.0), py(0.78125)),
    stroke: (paint: luma(170), dash: "dashed"))
  cdraw.circle((px(400.0), py(0.78125)), radius: 0.11, stroke: luma(150))
  cdraw.content((px(400.0), py(0.78125) - 0.5), [never bought], size: 6pt)
  cdraw.content((4.0, 1.85), [+1/16], size: 6pt)
  cdraw.content((7.2, 2.55), [+1/16], size: 6pt)
  cdraw.content((10.2, 3.02), [+1/32], size: 6pt)
  cdraw.content((10.2, 2.62), [threshold reached, stop], size: 6pt)
  cdraw.content((13.3, 3.15), [chosen size 200], size: 6pt)
})

Four samplers, one thread. Every draw traces back to one multiply and one
remainder over a prime modulus, every allocation to integer division with
a named tie rule, every stop to a comparison against a threshold that is
itself a dyadic double. #xref-to("kdd", "features") keeps columns instead
of rows, and #xref-to("kdd", "hypothesis") eventually asks what a sample
can claim about the population it came from.

sources: Stephen K. Park and Keith W. Miller, "Random number generators:
good ones are hard to find", Communications of the ACM 31(10), 1192-1201,
1988, the MINSTD generator, banked by kdd-contract-s1s2.md. All 29 pinned
values, the uint64-intermediate note, the mod-arithmetic hand checks, and
the stratified tie-break pin witnessed by kdd-contract-s1s2.md and
playground/kdd-matrix/gen_s2.py, run 2026-09-22, exit 0. Sample behavior
verified by `pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot
books/kdd/samples/src -Chapter Ch07`, 29 checks in chapter 07 of the kdd
suite.
