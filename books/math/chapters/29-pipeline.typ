#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= pipelines and effects

Chapter #xref-to("math", "adt") gave failures a type, chapter
#xref-to("math", "railway") gave them a track, and chapter
#xref-to("math", "monads") peeled the laws off the combinators. This chapter
composes the whole arc into programs: functions as values in a tagged tree
with composition, currying, and the fused pass one composition buys, the
pipeline operator macro that reads left to right over the error track, state
threading through explicit world values instead of static cells, seeded
random streams carried as parameters, the line between a pure core and an
impure shell, and the testing discipline that split makes possible. Every
behavioral claim below is one of the 69 checks in the 4 samples of chapter
29 or a sentence quoted from a canonical source fetched 2026-09-22. The dsa
book drives its game loops with inline mutation and returned error codes,
so this chapter owns the plumbing discipline itself, and the capstone game
is where it all gets spent.

== composition as data

Composition builds a new function from two old ones: apply $f$ first, then
$g$, and the pair acts as $g(f(x))$. C will not let a function return a
new function, so the composition has to live in data. The sample gives
functions a sum type, the same discipline chapter #xref-to("math", "adt")
used for shapes: a tag picks between four primitives, identity, increment,
double, and subtract 3, plus one composition node carrying two child
pointers. One switch interprets the tree, every kind handled, no default.

The dry run: the fixture is 5. The interpreter walks the tree $"sub3" dot
"dbl" dot "inc"$ by recursion, and the three primitives fire in order.

+ $"inc"$ maps 5 to 6, one addition.
+ $"dbl"$ maps 6 to 12, one multiply.
+ $"sub3"$ maps 12 to 9, and the composed value is 9.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*x*], [*inc*], [*dbl after inc*], [*sub3 after dbl*]),
  [5], [6], [12], [9],
  [-4], [-3], [-6], [-9],
  [12], [13], [26], [23],
  [0], [1], [2], [-1],
)

Associativity is the property that makes the tree shape free: LEFT, the
nesting that groups $"sub3"$ with $"dbl"$ first, and RIGHT, the nesting that
groups $"dbl"$ with $"inc"$ first, are different static values with different
pointer shapes, and the sample checks they agree on all 4 fixtures. Identity is neutral on
either side, checked at 41 mapping to 42 both ways. Neither law needed a
proof, both needed a CHECK, and both are the reason a C composition can be
rebuilt into any tree the caller finds readable.

#listing("math/samples/src/Ch29/compose.c", first: 9, last: 55, caption: [the function adt, a tag plus two child pointers, and the one switch that interprets it])

#diagram([the composed chain on top, the two associativity nestings below, same output], length: 13pt, {
  let box(x, y, w, t, fill: luma(235), stroke: luma(100)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, stroke: stroke, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0, 6.4, 2.2, [x = 5])
  cdraw.line((2.2, 6.9), (3.9, 6.9), stroke: luma(60), mark: (end: ">"))
  box(3.9, 6.4, 2.2, [inc])
  cdraw.line((6.1, 6.9), (7.8, 6.9), stroke: luma(60), mark: (end: ">"))
  box(7.8, 6.4, 2.2, [dbl])
  cdraw.line((10.0, 6.9), (11.7, 6.9), stroke: luma(60), mark: (end: ">"))
  box(11.7, 6.4, 2.2, [sub3])
  cdraw.line((13.9, 6.9), (15.6, 6.9), stroke: luma(60), mark: (end: ">"))
  box(15.6, 6.4, 1.6, [9])
  cdraw.content((3.05, 7.1), [6], size: 6pt)
  cdraw.content((6.95, 7.1), [12], size: 6pt)
  cdraw.content((11.85, 7.1), [9], size: 6pt)

  cdraw.content((7.4, 5.6), [both nestings land the same 9], size: 6.5pt)
  box(0.4, 3.4, 2.6, [inc])
  cdraw.line((3.0, 3.9), (4.4, 3.9), stroke: luma(60), mark: (end: ">"))
  box(4.4, 3.4, 3.0, [sub3 . dbl], fill: luma(205))
  cdraw.line((7.4, 3.9), (8.8, 3.9), stroke: luma(60), mark: (end: ">"))
  box(8.8, 3.4, 2.6, [output 9])
  cdraw.content((3.7, 4.5), [left nesting], size: 6pt)

  box(11.6, 3.4, 3.0, [dbl . inc], fill: luma(205))
  cdraw.line((14.6, 3.9), (15.6, 3.9), stroke: luma(60), mark: (end: ">"))
  box(15.6, 3.4, 2.2, [sub3])
  cdraw.line((17.8, 3.9), (18.8, 3.9), stroke: luma(60), mark: (end: ">"))
  cdraw.content((18.85, 3.6), [9], size: 6pt)
  cdraw.content((13.1, 4.5), [right nesting], size: 6pt)
})

C closures are the same move with a struct. A closure is a function plus the
environment it captured, and in C the environment is a context struct the
function receives back. The sample fixes one parameter of the two parameter
family $f(x) = "slope" dot x + "bias"$, so partial application is
constructing the struct, currying is the LIN_ADD and LIN_MUL macros that fix
$k$, and the one hole left is the argument. The generic closure pairs a
call pointer with a context pointer, 16 bytes, checked.

#listing("math/samples/src/Ch29/compose.c", first: 57, last: 84, caption: [the closure: a context struct, currying macros that fix one parameter, and the pointer pair])

Composition also pays in cache walks. Three separate passes over an 8
element array, inc then dbl then sub3, touch 24 elements. The fused pass
walks once and applies the composed tree per element, 8 touches. Same
outputs, the pinned ladder 1, 3, 5, 7, 9, 11, 13, 15, and the visit
counter is the measured witness: 24 against 8.

#listing("math/samples/src/Ch29/compose.c", first: 86, last: 120, caption: [the visit counter, the three separate passes, and the fused pass])

== the pipeline operator

Composition reads inside out. Pipelines read left to right, and the spelling
with a name is the F\# forward pipe operator, which Microsoft's operator
reference says "passes the result of the left side to the function on the
right side" (learn.microsoft.com/en-us/dotnet/fsharp/language-reference/symbol-and-operator-reference/,
fetched 2026-09-22). C has no infix operator to overload, so the sample
builds |> as a macro family, and the honest desugaring is the chapter 27
railway: the first stage turns the raw input into a carrier, and every later
stage binds onto the ok track, redeclared here so the file stands alone.

#listing("math/samples/src/Ch29/pipeline.c", first: 10, last: 51, caption: [the local carrier, the bind and map combinators, and the PIPE macro family])

#callout("pitfall", "why the desugaring is plain function calls", [The macro expands to nested calls to bind, a function, not to statement expressions or any compiler extension. Function call evaluation order is defined, the stages are ordinary symbols the debugger sees, and the file stays ISO C23. An infix |> written with GNU statement expressions would buy nothing here and pin the chapter to one compiler family.])

The dry run: the domain is a firmware word. The input 48 rides four stages:
s1 checks parity and passes 48, s2 halves to 24 inside the 90 bound, s3
computes the calibration word $10 dot 24 + 2 = 242$, s4 tags it with the
checksum $242 xor 165 = 87$. Each stage logs the value it received, so the
trace array pins 48, 48, 24, 242.

+ The counters read 1, 1, 1, 1, every stage ran exactly once.
+ The input 7 dies in s1 with residue 1, the counters read 1, 0, 0, 0,
  and the trace holds one entry.
+ The input 200 halves to 100, ten over the bound, and dies in s2 with
  counters 1, 1, 0, 0.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*input*], [*stages run*], [*trace*], [*result*]),
  [48], [4 of 4], [48, 48, 24, 242], [ok 87],
  [180], [4 of 4], [180, 180, 90, 902], [ok 803],
  [7], [1 of 4], [7], [odd, residue 1],
  [200], [2 of 4], [200, 200], [bound, excess 10],
)

The failing rows are the chapter's argument in miniature: the error carries
a typed code and position exactly as chapter #xref-to("math", "railway")
built, the downstream stages never wake, and the counters prove it rather
than assert it. The 2 of 4 against 4 of 4 is the two-number play, work
not done on the failure track.

#listing("math/samples/src/Ch29/pipeline.c", first: 53, last: 101, caption: [the four stages, each counting itself and logging its input])

#diagram([the happy track with the macro sugar, the dashed error track bypassing the later stages], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0, 5.6, 2.0, [raw 48])
  cdraw.line((2.0, 6.1), (3.6, 6.1), stroke: luma(60), mark: (end: ">"))
  cdraw.content((2.8, 6.4), [|>], size: 6pt)
  box(3.6, 5.6, 2.4, [s1 even])
  cdraw.line((6.0, 6.1), (7.6, 6.1), stroke: luma(60), mark: (end: ">"))
  cdraw.content((6.8, 6.4), [|>], size: 6pt)
  box(7.6, 5.6, 2.4, [s2 bound])
  cdraw.line((10.0, 6.1), (11.6, 6.1), stroke: luma(60), mark: (end: ">"))
  cdraw.content((10.8, 6.4), [|>], size: 6pt)
  box(11.6, 5.6, 2.4, [s3 calib])
  cdraw.line((14.0, 6.1), (15.6, 6.1), stroke: luma(60), mark: (end: ">"))
  cdraw.content((14.8, 6.4), [|>], size: 6pt)
  box(15.6, 5.6, 2.4, [s4 tag])
  cdraw.line((18.0, 6.1), (19.6, 6.1), stroke: luma(60), mark: (end: ">"))
  cdraw.content((18.8, 6.35), [87], size: 6pt)

  cdraw.line((4.8, 5.6), (4.8, 3.8), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((8.8, 5.6), (8.8, 3.8), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((4.8, 3.8), (18.8, 3.8), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((18.8, 3.8), (18.8, 4.4), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  box(9.4, 2.8, 5.6, [error track: code + info], fill: luma(205))
  cdraw.content((6.6, 4.05), [odd], size: 6pt)
  cdraw.content((11.4, 4.05), [bound], size: 6pt)
  cdraw.content((12.0, 1.9), [stages 3 and 4 never wake], size: 6pt)
})

The call site is the payoff. One line holds the whole pipeline in reading
order, the explicit bind nest is checked to reach the same 87, and a shorter
chain, PIPE3, stops at the calibration word 242 with the tag counter still
zero. A pure stage rides the same track through map, doubling the ok value
to 174 and leaving the parity failure untouched.

#listing("math/samples/src/Ch29/pipeline.c", first: 103, last: 106, caption: [the whole pipeline, one line, stages in reading order])

== threading state

A pipeline stage that needs memory has three places to put it: a static
cell, a heap object with an owner, or the function signature. Threading
puts it in the signature: the state arrives as a value and leaves as the
return, the shape $f: (a, s) -> (b, s)$ that chapter
#xref-to("math", "monads") called the state carrier. Every step is pure,
so every intermediate state is a CHECK away.

#listing("math/samples/src/Ch29/state.c", first: 11, last: 29, caption: [the fold state and its step, state in, input in, next state out])

The dry run: the values 3, -1, 4, 1, 5 fold through acc_step, and the
sample pins the accumulator after every single step, sum 3, 2, 6, 7, 12
with count 1 to 5, min settling at -1 on the second step and max at 5 on
the last. The automaton thread is the same discipline with a transition
table instead of arithmetic: three states recognizing the substring "ab",
state 2 absorbing, and the walk over "aababb" pins 0, 1, 1, 2, 2, 2, 2.

#listing("math/samples/src/Ch29/state.c", first: 31, last: 62, caption: [the dfa transition table, its pure step, and the world that threads both states at once])

The world struct carries the automaton and the fold together, 40 bytes,
checked, and run_script advances it with an explicit copy per step. The
typeof on the copy is the point in code: whatever world grows into, the
step receives a value and returns a value, and no step can reach back into
the state the caller still holds.

#listing("math/samples/src/Ch29/state.c", first: 64, last: 74, caption: [the runner, typeof names the copy, value semantics on every step])

#diagram([the world threading above, the one byte static twin below], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.2), fill: fill, stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.85), t, size: 6pt)
  }
  box(0, 5.8, 3.4, [w0])
  cdraw.content((1.7, 6.15), [q0, sum 0], size: 6pt)
  cdraw.line((3.4, 6.4), (5.0, 6.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.2, 6.7), [(a, 3)], size: 6pt)
  box(5.0, 5.8, 3.4, [w1])
  cdraw.content((6.7, 6.15), [q1, sum 3], size: 6pt)
  cdraw.line((8.4, 6.4), (10.0, 6.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((9.2, 6.7), [(a, -1)], size: 6pt)
  box(10.0, 5.8, 3.4, [w2])
  cdraw.content((11.7, 6.15), [q1, sum 2], size: 6pt)
  cdraw.line((13.4, 6.4), (15.0, 6.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((14.2, 6.7), [(b, 4)], size: 6pt)
  box(15.0, 5.8, 3.4, [w3])
  cdraw.content((16.7, 6.15), [q2, sum 6], size: 6pt)

  cdraw.content((9.2, 4.6), [the static twin: one cell, one machine], size: 6.5pt)
  cdraw.rect((7.0, 2.6), (11.4, 3.8), fill: luma(245), stroke: (paint: luma(150), dash: "dashed"), radius: 0.02)
  cdraw.content((9.2, 3.5), [g_dfa], size: 6pt)
  cdraw.content((9.2, 3.0), [1 byte], size: 6pt)
  cdraw.line((9.2, 2.6), (9.2, 1.9), stroke: luma(140), mark: (end: ">"))
  cdraw.line((7.6, 1.9), (10.8, 1.9), stroke: luma(140), mark: (end: ">"))
  cdraw.content((9.2, 1.5), [reset, feed, ask], size: 6pt)
})

The impure twin keeps the same transition function but hides the state in
file scope behind a reset, feed, ask interface. It is not wrong, it is
single: the sample runs both over 4 fixture strings and the final states
agree every time, but the twin holds exactly 1 byte of state, checked,
while the threaded version holds one world per caller. Two worlds fed
alternately, "aab" and "ba", each land where their sequential runs land,
2 interleaved machines against the twin's 1, and that is the two-number
play: threading buys instances the way passing arguments buys them.

#listing("math/samples/src/Ch29/state.c", first: 85, last: 93, caption: [the global twin, same transition, one static cell behind an interface])

#callout("note", "when the static twin is the right call", [One machine, one owner, called from one place, the interface twin is simpler and the corpus ships plenty of them. The threaded version earns its copies the moment a second instance exists, a test replays a script against a fresh world, or a caller needs the state at an intermediate step for a checkpoint. The cost is not speed, it is the copy, 40 bytes here.])

== rng discipline

Deterministic simulation needs randomness that is a value. The corpus rule
is no rand() and no time(), and the sample uses Marsaglia's xorshift64,
from the paper that described "a class of simple, extremely fast random
number generators (RNGs) with periods" of $2^k - 1$ for word sizes $k = 32$
through 192, so the 64 bit member runs a full period of $2^64 - 1$ on any
nonzero seed (jstatsoft.org/article/view/v008i14, fetched 2026-09-22). The
generator is three shifts and three xors, the seed is a constexpr word, and
the stream is a struct passed by pointer: seed in, next seed out, draw
returned.

#listing("math/samples/src/Ch29/effects.c", first: 14, last: 40, caption: [the xorshift64 stream as a struct, and the finalizer that scrambles a draw into a fresh seed])

The discipline has two rules and both are checked. First, the same seed
replays the same stream: two independent runs of 6 draws from
0x1BADB002CAFEF00D agree bit for bit, 0 differing bits, and the first four
draws are pinned as literals. Second, the stream belongs to the caller.
The pure jitter core takes the stream by value and returns the next stream
with the answer, so calling it never moves the caller's seed, checked, the
same move the world struct made in the previous section. This is the same
determinism contract as the fixed point CORDIC lane in
#xref-to("game-systems", "math"), stated over random draws instead of
trigonometry.

The dry run: the first draw has residue 5 mod 7, so jitter at base 100 is
$100 + 5 - 3 = 102$, and at base -50 the third draw's residue 2 gives
$-51$. The naive split hands draw 1 to a child stream as its seed, and the
child's first output equals the parent's second output exactly, the two
streams overlap draw for draw. The fix finalizes the draw first, two rounds
of multiply and xor shift, and the finalized child's first three draws are
pinned and all differ from the parent's next three.

#diagram([the parent stream, the naive handoff rejoining it, the finalized branch diverging], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0, 6.2, 2.4, [seed])
  cdraw.line((2.4, 6.7), (4.0, 6.7), stroke: luma(60), mark: (end: ">"))
  box(4.0, 6.2, 2.4, [draw 0])
  cdraw.line((6.4, 6.7), (8.0, 6.7), stroke: luma(60), mark: (end: ">"))
  box(8.0, 6.2, 2.4, [draw 1])
  cdraw.line((10.4, 6.7), (12.0, 6.7), stroke: luma(60), mark: (end: ">"))
  box(12.0, 6.2, 2.4, [draw 2])

  cdraw.line((5.2, 6.2), (5.2, 4.2), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  box(2.6, 3.2, 3.8, [child seed = draw 0], fill: luma(205))
  cdraw.line((6.4, 3.7), (9.0, 5.9), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((8.1, 4.35), [c0 = draw 1], size: 6pt)

  cdraw.line((5.2, 6.2), (5.2, 5.6), stroke: luma(60))
  cdraw.line((5.2, 5.6), (12.6, 5.6), stroke: luma(60))
  cdraw.line((12.6, 5.6), (12.6, 4.4), stroke: luma(60), mark: (end: ">"))
  box(11.4, 3.4, 2.4, [finalize])
  cdraw.line((13.8, 3.9), (15.0, 3.9), stroke: luma(60), mark: (end: ">"))
  box(15.0, 3.4, 2.8, [mixed seed])
  cdraw.content((16.4, 2.9), [diverges], size: 6pt)
})

#callout("warning", "the handoff overlap is invisible in output", [Two overlapping xorshift streams still look random in any histogram. The failure is correlation, not repetition: every child draw is a parent draw, so simulations that think they sample two independent noises sample one. The check that catches it is the equality the sample pins, child first output equals parent second. Any split that hands a raw draw to a child needs the finalizer.])

== the pure core and the impure shell

Isolation is a boundary, drawn once, with globals on one side. The pure
core owns the arithmetic: jitter takes the stream by value and the base,
returns the answer and the next stream, and touches nothing else, no
globals, no io, checked by construction because it has no symbols to reach.
The impure shell owns every effect the program has, five file-scope
objects, countable in the listing: the stream g_stream, the call counter
g_calls, the log array g_log with its fill index g_log_n, and the busy
guard g_busy.

#listing("math/samples/src/Ch29/effects.c", first: 42, last: 52, caption: [the pure core, stream in by value, answer and next stream out])

#listing("math/samples/src/Ch29/effects.c", first: 54, last: 81, caption: [the impure shell, it owns the stream, the counter, the log, and the guard, defer lowers it])

The dry run: reset the shell, then call jitter_shell three times at base
100. The stream draws residues 5, 2, 2, the core answers 102, 99, 99, the
counter reads 3, the log holds the same three numbers, and the guard is
down after the last call. A second scenario resets and replays base -50
for -48, -51, -51, every number pinned.

The shell sets its busy guard and registers the release with defer, the
TS 25755 lane the corpus pinned in c-os-cloud ch 06, available here as
clang 23.1.1 stddefer.h under the gate's -fdefer-ts. Every exit path
lowers the guard, including the implicit one, and the check after three
calls finds it down. The shell's calls land in the log, so its effects are
data too, and the checks read them back like any other array.

#diagram([the core takes and returns values only, the shell ring carries every effect], length: 13pt, {
  cdraw.rect((0, 3.4), (13.2, 6.6), fill: luma(245), stroke: luma(140), radius: 0.02)
  cdraw.content((6.6, 6.2), [impure shell], size: 6.5pt)
  cdraw.rect((2.2, 4.0), (11.0, 5.6), fill: luma(235), stroke: luma(100), radius: 0.02)
  cdraw.content((6.6, 5.2), [pure core], size: 6.5pt)
  cdraw.content((6.6, 4.65), [jitter(rng by value, base)], size: 6pt)
  cdraw.content((6.6, 4.25), [0 globals, 0 io], size: 6pt)
  cdraw.line((-1.0, 4.8), (2.2, 4.8), stroke: luma(60), mark: (end: ">"))
  cdraw.content((-0.9, 5.1), [base], size: 6pt)
  cdraw.line((11.0, 4.8), (14.2, 4.8), stroke: luma(60), mark: (end: ">"))
  cdraw.content((12.0, 5.1), [out + next], size: 6pt)

  cdraw.line((2.0, 3.7), (2.0, 2.6), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((6.6, 3.4), (6.6, 2.6), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.line((11.2, 3.7), (11.2, 2.6), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((2.0, 2.2), [counter], size: 6pt)
  cdraw.content((6.6, 2.2), [log array], size: 6pt)
  cdraw.content((11.2, 2.2), [guard, defer], size: 6pt)
})

The two-number play sits in the middle of the figure: the core crosses the
ring with values only, 2 arrows, while the ring itself owns 5 file-scope
objects. A program drawn this way can move the core to any thread, replay
it against any recorded stream, or reason about it with substitution, and
the shell is small enough to audit by reading it once.

== testing effectful code

The split turns testing from mocking into arithmetic. The pure core is
tested directly: feed a seed, CHECK the answer, the same contract every
chapter of this book has used. The shell is tested through its log: drive
it with fixed inputs, then CHECK the log equals the trace the core's
replay predicts. Nothing is stubbed, nothing sleeps, no order of global
initialization is consulted.

#diagram([the test route for a pure unit and for an effectful one], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, stroke: luma(100), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0, 5.4, 4.0, [unit under test])
  cdraw.line((4.0, 5.9), (5.6, 6.4), stroke: luma(60), mark: (end: ">"))
  cdraw.line((4.0, 5.9), (5.6, 4.4), stroke: luma(60), mark: (end: ">"))
  cdraw.content((4.4, 6.75), [pure], size: 6pt)
  cdraw.content((4.4, 5.2), [effectful], size: 6pt)
  box(5.6, 6.6, 5.6, [CHECK the returned values], fill: luma(205))
  box(5.6, 2.8, 5.6, [drive the shell, capture the log])
  cdraw.line((8.4, 2.8), (8.4, 1.8), stroke: luma(60), mark: (end: ">"))
  box(5.0, 0.8, 6.8, [CHECK the log against the core replay], fill: luma(205))
  cdraw.content((2.0, 4.2), [same CHECK macro both ways], size: 6pt)
})

The dry run is the whole chapter on one file. effects.c holds 20 checks:
5 hold the stream, the four pinned draws and the two-run bit identity, 3
hold the core arithmetic with the caller's seed unmoved, 5 hold the split,
the naive handoff, the finalized seed, and its three pinned draws, 5 hold
the shell's outputs, counter, log, and guard, and 2 pin the sizes. The
other three samples apply the same discipline to their own subjects, 20 on
composition, 14 on the pipeline, 15 on threading, 69 in total, and every
expected value was computed before it was checked, by a script in
playground/math-ch29, never typed from memory.

#callout("verify", "the determinism gate is two runs", [Any sample that claims determinism runs its effectful path twice and compares. Here the second six-draw run equals the first bit for bit and the shell's second scenario replays -48, -51, -51 from the reset seed. If the two-run check ever fails, the effect leaked into the core, and the boundary needs redrawing, not the test.])

The capstone spends this chapter where it counts. The arena game behind
#xref-to("math", "capstone-design") is headless: its driver main.c prints
rollout lines with no window and no clock reads, and its header names the
split in this chapter's terms, the ai trees live in the impure shell while
the core modules stay free of mutable globals. The fixed timestep is one
constexpr, DT = 1/120, declared exactly once, and one step is a stage
sequence over the game state: physics_step takes the state through a
pointer and walks controls, both verlet halves, contacts, drag, and orb
rules in order, returning void. No railway carrier rides that loop, the
stages return void and carry no error path, so chapter 27's error track is
not what the capstone reuses. What it reuses is the rest of this chapter:
struct game is a value
to copy, hash, and replay, the rng streams are driver-owned locals handed
by pointer into the search, and the replay mode runs the same rollout
twice demanding bit-identical hashes over the raw state bits, the two-run
gate the verify callout states. 69 small proofs here, one program there.

sources: Microsoft Learn, "Symbol and Operator Reference - F\#",
learn.microsoft.com/en-us/dotnet/fsharp/language-reference/symbol-and-operator-reference/,
the |> row quoted, fetched 2026-09-22. George Marsaglia, "Xorshift RNGs",
Journal of Statistical Software 8(14) 2003,
jstatsoft.org/article/view/v008i14, the abstract's periods sentence
quoted, fetched 2026-09-22. Defer ground truth from the corpus's own
pinned coverage, TS 25755 and clang 23.1.1 `stddefer.h` under
`-fdefer-ts`, c-os-cloud ch 06. Capstone facts read from the committed
source, books/math/capstone/src main.c, common.h, physics.h, state.h.
mml-book draft 2024-01-15: no mapped
chapter for pipelines and effects, none cited. Sample behavior verified by
`pwsh -NoProfile -File tools/run-c-samples.ps1 -SampleRoot books/math/samples/src -Chapter Ch29`,
69 checks in chapter 29 of the math suite, format and asan clean.
