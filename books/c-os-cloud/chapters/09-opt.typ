#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= optimization: what -O actually does

Every sample in this book is compiled more than once. The run leg of
the gate names no `-O` flag, which is `-O0`, and counts checks. The ir
and objdump legs recompile the same files at explicit levels and
assert what changed underneath. This chapter walks two of those files
up the ladder: `mix` in `mem2reg.c`, whose `-O0` body is a stack-frame
simulation, and the `axpy` loop in `vector.c`, which the optimizer
rebuilds into packed sse arithmetic. Every claim about a pass is one
of three things: a substring the gate asserts in emitted output, a
`-Rpass` remark this clang printed on this machine, or a sentence
from the llvm documentation fetched 2026-09-12. The windows release
of llvm ships no `opt` binary, so the pipelines are observed through
the clang driver itself; chapter 7 owns the inventory of what is
missing.

== mem2reg, -O0 ir versus -O2 ir

`-O0` emits ir that mirrors the source statement by statement. Every
local variable becomes an `alloca`, which the language reference
defines as an instruction that allocates memory on the stack frame of
the currently executing function, to be automatically released when
this function returns to its caller. Every read becomes a `load`,
every assignment a `store`. The whole function under study is four
lines of arithmetic:

#listing("c-os-cloud/samples/src/Ch09/mem2reg.c", first: 19, last: 28, caption: [the two helpers and mix, one plain, one `always_inline`, both called twice])

At `-O0` `mix` gets 5 `alloca` slots, 6 `load` instructions, 6
`store` instructions, and 2 `call` instructions. Line 24 stores
`bias(a)` into `t`'s slot, line 25 loads it back and hands it to
`weight`, line 26 loads `u` and `b`, adds them, and stores the sum
into the same slot, line 27 loads it and calls `weight` again. One of
the three helper invocations is not a call even here: `bias` is
folded into the instruction `add i32 %9, 7` right inside the body, a
fact section 2 returns to. The `100`, `67`, and `43` that `main`
checks are computed at runtime through this memory traffic, one pass
per argument pair.

mem2reg is the pass that deletes the scaffolding. It walks each
`alloca` whose address never escapes, replaces every `load` with the
value most recently stored, deletes the `store`, and where control
flow merges two different values into one slot it manufactures a
`phi` node, the instruction chapter 8 reads in depth. `mix` has no
branches, so no phi appears, and the whole `-O2` body is five
register operations and a ret: `mul i32 %0, 3`, `add i32 %3, 22`,
`add i32 %4, %1`, `mul i32 %5, 3`, `add i32 %6, 1`, `ret i32 %7`.
The constants record the folds. `bias` adds 7 and `weight` adds 1
after multiplying by 3, so `weight(bias(a))` collapses to the
multiply by 3 and the single `add i32 %3, 22`, and the outer
`weight` reappears as the trailing multiply and `add i32 %6, 1`.
`-O1` emits the identical body, and the gate pins `mul i32 %0, 3` at
both levels. No arithmetic anywhere in this file carries `nsw`: the
msvc driver injects `-fwrapv` into every cc1 invocation, chapter 5's
finding, and this chapter's emitted files re-verify it, the `nsw`
substring exists at neither `-O0`, `-O1`, nor `-O2`, so no fold here
banks an undefined-overflow assumption.

#diagram([the same mix at -O0 and at -O1, -O2, mem2reg deleted every alloca the frontend needed], length: 13pt, {
  let col(x, title) = {
    cdraw.rect((x, 7.4), (x + 10.2, 8.4), fill: luma(205), radius: 0.02)
    cdraw.content((x + 5.1, 7.9), title, wrap: text.with(size: 6.5pt))
    cdraw.rect((x, 0.6), (x + 10.2, 7.1), fill: luma(235), radius: 0.02)
  }
  col(0.6, [-O0: values through memory])
  cdraw.content((5.7, 6.3), [5 alloca slots], wrap: text.with(size: 6pt))
  cdraw.content((5.7, 5.65), [6 loads, 6 stores], wrap: text.with(size: 6pt))
  cdraw.content((5.7, 5.0), [%12 = call i32 \@weight(...)], wrap: text.with(size: 6pt))
  cdraw.content((5.7, 4.35), [%17 = call i32 \@weight(...)], wrap: text.with(size: 6pt))
  cdraw.content((5.7, 3.7), [ret i32 %17], wrap: text.with(size: 6pt))
  cdraw.content((5.7, 2.6), [one source statement, one ir block], wrap: text.with(size: 6pt))
  cdraw.content((5.7, 1.95), [the shape a debugger wants], wrap: text.with(size: 6pt))
  col(13.4, [-O1 and -O2: ssa registers])
  cdraw.content((18.5, 6.3), [%3 = mul i32 %0, 3], wrap: text.with(size: 6pt))
  cdraw.content((18.5, 5.65), [%4 = add i32 %3, 22], wrap: text.with(size: 6pt))
  cdraw.content((18.5, 5.0), [%5 = add i32 %4, %1], wrap: text.with(size: 6pt))
  cdraw.content((18.5, 4.35), [%6 = mul i32 %5, 3], wrap: text.with(size: 6pt))
  cdraw.content((18.5, 3.7), [%7 = add i32 %6, 1], wrap: text.with(size: 6pt))
  cdraw.content((18.5, 3.05), [ret i32 %7], wrap: text.with(size: 6pt))
  cdraw.content((18.5, 1.95), [zero allocas, zero loads, zero calls], wrap: text.with(size: 6pt))
  cdraw.content((18.5, 1.3), [the add 22 is bias plus weight folded], wrap: text.with(size: 6pt))
  cdraw.content((11.8, 0.05), [both bodies are pinned in Ch09 expect-ir.txt, alloca at -O0, mul at -O1 and -O2], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

The gate asserts four substrings for this file: `alloca` and
`call i32 @weight` at `-O0`, `mul i32 %0, 3` at `-O1` and at `-O2`.

== inlining, the call graph collapse

At `-O0` `weight` is a real symbol with `internal` linkage, one
define, three call sites, two in `mix` and one in `main`'s check. At
`-O2` all three calls are gone and so is the define: every caller
holds a folded copy, and an internal function with no remaining
callers is dead. `mix` itself is inlined into `main` three times,
once per check, and survives as an outline anyway because its linkage
is external, so the definition must ship for callers this file cannot
see. The remark stream names every fold: `'weight' inlined into 'mix'
with (cost=-25, threshold=337)`, `'mix' inlined into 'main' with
(cost=-40, threshold=337)` at each of the three checks, and
`'weight'` into `'main'` with `cost=-15035`, the check call that
constant-folds to nothing.

Negative cost means the inliner estimates the fold shrinks code: the
call sequence it deletes costs more bytes than the body it copies in.
The threshold is the brake. Every inline trades call overhead for
code size, code size is not free, a bigger binary pays in instruction
cache misses, and the inliner prices each site against a budget
instead of folding everything it can see. `-Os` and `-Oz` exist as
documented levels for the size-first end of that trade.

`always_inline` waives the budget. The language reference defines the
attribute as an instruction to the inliner to attempt to inline this
function into callers whenever possible, ignoring any active inlining
size threshold for this caller. This clang honors it at `-O0`, where
nothing else inlines: `-Rpass=inline` at `-O0` prints exactly two
remarks for this file, `'bias' inlined into 'mix'` and `'bias'
inlined into 'main'`, both carrying `(cost=always): always inline
attribute`, while `-Rpass-missed=inline` prints nothing, the ordinary
inliner does not run at `-O0` at all. `bias` never exists as a call
or a define at any level. The attribute is a promise about every
caller, which is why it belongs on tiny helpers and on almost nothing
else.

#listing("c-os-cloud/samples/src/Ch09/mem2reg.c", first: 30, last: 37, caption: [the checks: helper calls and mix results, computed and compared at runtime])

The checks in that listing are what the optimizer may not touch. At
`-O2` the comparisons fold to constants, `mix(2, 5)` is `100` at
compile time, so `main` prints five unconditional `ok` lines with no
branch anywhere. The printed bytes and the exit code are identical at
`-O0` and `-O2`, chapter 5's as-if seam seen from the optimizer's
side: everything may change as long as the observable behavior does
not.

#diagram([the call graph of mem2reg.c at -O0 and at -O2, weight vanishes, mix survives standalone], length: 13pt, {
  // left: -O0
  cdraw.content((5.1, 7.7), [-O0: three live symbols], wrap: text.with(size: 6.5pt))
  cdraw.rect((2.6, 5.4), (7.6, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.1, 5.9), [main], wrap: text.with(size: 6pt))
  cdraw.rect((0.6, 3.2), (4.2, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((2.4, 3.7), [mix], wrap: text.with(size: 6pt))
  cdraw.rect((5.4, 3.2), (9.6, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((7.5, 3.7), [weight, internal], wrap: text.with(size: 6pt))
  cdraw.line((4.0, 5.4), (2.8, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.8, 5.4), (7.2, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.2, 3.7), (5.4, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.8, 4.3), [2 calls], wrap: text.with(size: 6pt))
  cdraw.rect((0.6, 1.0), (9.6, 2.4), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((5.1, 2.0), [bias: no box exists, not even at -O0], wrap: text.with(size: 6pt))
  cdraw.content((5.1, 1.35), [its body is the add i32 %9, 7 inside mix], wrap: text.with(size: 6pt))
  // right: -O2
  cdraw.content((19.3, 7.7), [-O2: mix still emitted, weight gone], wrap: text.with(size: 6.5pt))
  cdraw.rect((13.4, 5.4), (19.4, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((16.4, 6.05), [main, holds 3 folded], wrap: text.with(size: 6pt))
  cdraw.content((16.4, 5.5), [copies of mix], wrap: text.with(size: 6pt))
  cdraw.rect((13.4, 3.2), (17.2, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((15.3, 3.7), [mix, outline ships], wrap: text.with(size: 6pt))
  cdraw.rect((18.4, 3.2), (24.0, 4.2), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((21.2, 3.7), [weight, deleted], wrap: text.with(size: 6pt))
  cdraw.content((18.7, 2.3), [no call edges remain in this file], wrap: text.with(size: 6pt))
  cdraw.content((12.1, 0.35), [every fold was priced: cost=-40 against threshold=337 for each mix into main], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("pitfall", "remarks are diagnostics, not a contract", [
  The users manual warns twice. Do not expect a report from every
  transformation made by the compiler, and the locations remarks
  carry are translated from debug annotations, a translation that can
  be lossy, so some remarks arrive without one. The remarks quoted in
  this chapter are observed output of this clang on these files, a
  window into one build, not an interface to program against. The
  gate pins the transformations themselves, in ir and disassembly,
  and never a remark string.
])

== vectorization evidence

The kernel is one line of body:

#listing("c-os-cloud/samples/src/Ch09/vector.c", first: 19, last: 23, caption: [the axpy loop, float, trip count unknown to the compiler])

At `-O0` the loop runs one float at a time, and the `-O0`
disassembly shows it: `movss 0x34(%rsp), %xmm1` loads one `y`
element, `mulss %xmm2, %xmm0` multiplies one lane, `addss %xmm1,
%xmm0` adds one lane, `movss %xmm0, 0x34(%rsp)` stores one result,
64 passes for 64 elements. Scalar sse is still sse: those
instructions live in `xmm` registers because the x86-64 baseline has
no legacy x87 path for this arithmetic. So `xmm` in a disassembly is
not by itself evidence of vectorization, and the gate pins two
substrings for exactly that reason: `xmm`, which both levels show,
and `mulps`, the packed multiply only `-O2` emits.

At `-O1` the vectorizer does not run. Its missed remark says so in
one line, `loop not vectorized: only vectorizing loops that
explicitly request it`, the `-O1` policy, loops carrying a `#pragma
clang loop vectorize(enable)` request excepted. At `-O2` the remark
flips to `vector.c:20:3: remark: vectorized loop (vectorization
width: 4, interleaved count: 2)`. The vectorizer documentation states
the mechanism: the loop vectorizer uses a cost model to decide on the
optimal vectorization factor and unroll factor, and both the loop and
slp vectorizers are enabled by default at the levels that run them.

The `-O2` ir shows the rebuild. A runtime guard `icmp ult i32 %33, 8`
sends short counts straight to the scalar tail. The volatile-loaded
`scale` becomes a vector splat through `insertelement <4 x float>
poison, float %34, i64 0` followed by a `shufflevector` with a
zeroinitializer mask. The induction is `%44 = phi i64 [ 0, %39 ], [
%55, %43 ]`, a phi the optimizer manufactured, the same merge
instruction mem2reg uses, doing loop duty. Each pass loads two
`<4 x float>` vectors from `xs` and two from `ys`, computes two
`@llvm.fmuladd.v4f32` calls, and stores both back: 8 floats per pass,
the interleave the remark reported. The scalar epilogue keeps the
same shape one float wide with `llvm.fmuladd.f32`. The language
reference defines the intrinsic family as multiply-add expressions
that can be fused if the code generator determines that the target
instruction set has support for a fused operation and the fused
operation is more efficient than the equivalent separate pair of mul
and add instructions. This target's emitted feature string is
`"+cmov,+cx8,+fxsr,+mmx,+sse,+sse2,+x87"`, no fused instruction
exists there, the first condition fails, and the intrinsic lowers to
a multiply and an add.

#listing("c-os-cloud/samples/src/Ch09/vector.c", first: 25, last: 38, caption: [volatiles hide the multiplier and the trip count, the fill loop is plain, the first checks are element exact])

The loop stays a loop because `main` hides two facts from the
optimizer: `scale` and `count` are `volatile`, so the multiplier and
the trip count are runtime values. The fill loop above them has no
such protection and at `-O2` dissolves entirely, unrolled and
constant-folded into 32 `store <4 x float>` instructions, sixteen per
array.

#listing("c-os-cloud/samples/src/Ch09/vector.c", first: 39, last: 51, caption: [the reduction checks and the zero length call, every value binary exact])

The checks are exact by construction: `2.5f` is binary-exact, every
index below 64 is exact in `float`, and every product and sum lands
on a value a `float` holds exactly, so `ys[1] == 4.5f` and the
`9072.0f` accumulated sum pass identically whether the loop runs one
float at a time or eight. The zero-length call tests the guard: with
`n` 0 the entry branch `icmp sgt i32 %33, 0` fails and `z` is
untouched.

The machine code carries the same structure. The setup broadcasts
the scale into all four lanes, `shufps $0x0, %xmm0, %xmm1`, the
counterpart of the `shufflevector` splat. The body then loads with
`movaps 0x120(%rsp,%r8), %xmm2`, multiplies with `mulps %xmm1,
%xmm2`, adds with `addps 0x20(%rsp,%r8), %xmm2`, repeats the three
for `xmm3` at offsets `0x130` and `0x30`, stores both results with
two more `movaps`, advances with `addq $0x20, %r8`, and loops on
`cmpq` and `jne`. The `p` in `mulps` and `addps` is packed, four
lanes per instruction, the interleaved `xmm2` and `xmm3` pair is the
count of 2 from the remark, and the 32-byte advance is 8 floats, so
64 elements finish in 8 passes plus the scalar tail for trip counts
that are not multiples of 8.

#diagram([one pass of the axpy loop at -O0 and at -O2, lanes and stride], length: 13pt, {
  // left: scalar
  cdraw.rect((0.6, 6.7), (9.4, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((5.0, 7.15), [-O0: one float per pass], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 0.6), (9.4, 6.3), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 5.5), [movss 0x34(%rsp), %xmm1], wrap: text.with(size: 6pt))
  cdraw.content((5.0, 4.85), [mulss %xmm2, %xmm0], wrap: text.with(size: 6pt))
  cdraw.content((5.0, 4.2), [addss %xmm1, %xmm0], wrap: text.with(size: 6pt))
  cdraw.content((5.0, 3.55), [movss %xmm0, 0x34(%rsp)], wrap: text.with(size: 6pt))
  cdraw.content((5.0, 2.65), [64 passes for 64 elements], wrap: text.with(size: 6pt))
  cdraw.content((5.0, 1.75), [scalar sse still uses xmm], wrap: text.with(size: 6pt))
  cdraw.content((5.0, 1.1), [xmm alone proves nothing], wrap: text.with(size: 6pt))
  // right: vector
  cdraw.rect((11.0, 6.7), (24.8, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.9, 7.15), [-O2: 8 floats per pass], wrap: text.with(size: 6.5pt))
  cdraw.rect((11.0, 0.6), (24.8, 6.3), fill: luma(235), radius: 0.02)
  cdraw.content((13.7, 6.05), [xmm2: 4 lanes], wrap: text.with(size: 6pt))
  cdraw.content((19.9, 6.05), [xmm3: the interleaved pair], wrap: text.with(size: 6pt))
  for i in range(4) {
    cdraw.rect((11.5 + i * 1.15, 5.0), (12.55 + i * 1.15, 5.8), fill: luma(215), radius: 0.02)
    cdraw.content((12.02 + i * 1.15, 5.4), [x#i], wrap: text.with(size: 5.5pt))
    cdraw.rect((16.6 + i * 1.15, 5.0), (17.65 + i * 1.15, 5.8), fill: luma(215), radius: 0.02)
    cdraw.content((17.12 + i * 1.15, 5.4), [x#(i + 4)], wrap: text.with(size: 5.5pt))
  }
  cdraw.content((17.9, 4.3), [mulps %xmm1, %xmm2], wrap: text.with(size: 6pt))
  cdraw.content((17.9, 3.65), [addps 0x20(%rsp,%r8), %xmm2], wrap: text.with(size: 6pt))
  cdraw.content((17.9, 3.0), [movaps %xmm2, 0x20(%rsp,%r8)], wrap: text.with(size: 6pt))
  cdraw.content((17.9, 2.35), [addq \$0x20, %r8], wrap: text.with(size: 6pt))
  cdraw.content((17.9, 1.45), [8 passes for 64 elements, plus a scalar tail], wrap: text.with(size: 6pt))
  cdraw.content((12.7, 0.05), [the p in mulps and addps is packed, four lanes per instruction], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== reading remarks, when -O0 wins

`-Rpass` is the documentation's own window into these decisions. The
users manual defines the family by the three moments: when the pass
makes a transformation, `-Rpass`, when the pass fails to make one,
`-Rpass-missed`, and when the pass determines whether or not to make
one, `-Rpass-analysis`, and notes that each of these flags takes a
regular expression that identifies the name of the pass. The manual's
own example is `clang -O2 -Rpass=inline code.cc -o code`, which is
how every remark in this chapter was produced, with `-Rpass=inline`
and `-Rpass=loop-vectorize` on these files. Underneath, the levels
expand to pipelines through the pass builder: the pass manager
documentation shows `buildPerModuleDefaultPipeline(OptimizationLevel::O2)`
assembling what corresponds to a typical -O2 optimization pipeline,
and notes that the optimization pipeline, the middle end, uses the
new pass manager. The driver is the only way to reach those
pipelines on this box, the standalone runner named in the opening
paragraph is not in this release.

`-O0` wins three ways in this book. Debuggability: the allocas of
section 1 are the variables, and a debugger can name every
intermediate because every intermediate has a slot and a source line.
Evidence: `-O0` ir mirrors the source one statement per block, which
is why the ir pins across the evidence chapters, including this one,
read `-O0` output, and why the sanitizer leg of the gate runs at the
level the driver defaults to. Compile speed: the command line
reference documents the level flags as controlling how much
optimization should be performed, `-O0` performs almost none, and
`-O` is equivalent to `-O1`; the same page marks `-Ofast` as
deprecated, pointing at `-O3 -ffast-math`. `-O2` is the shipping
level this chapter measured, and `-O3`, `-Os`, `-Oz` are the other
documented rungs. No level changes observable behavior, and this
chapter's gate rows hold the discipline in miniature: the same two
files pass 11 runtime checks at `-O0` and satisfy 9 ir and objdump
assertions across `-O0`, `-O1`, and `-O2`.

#diagram([choosing a level, and what each answer buys], length: 13pt, {
  let box1(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  let box2(x, y, w, l1, l2) = {
    cdraw.rect((x, y), (x + w, y + 1.8), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 1.2), l1, wrap: text.with(size: 6pt))
    cdraw.content((x + w / 2, y + 0.6), l2, wrap: text.with(size: 6pt))
  }
  box1(11.3, 7.4, 7.4, [a compile needs an -O level])
  box2(0.8, 5.0, 7.4, [debugging, or reading], [emitted evidence])
  box1(11.3, 5.0, 7.4, [shipping the binary])
  box1(21.8, 5.0, 7.4, [binary size first])
  box2(0.8, 2.4, 7.4, [-O0: allocas are the variables,], [ir mirrors the source])
  box2(11.3, 2.4, 7.4, [-O2: mem2reg, inlining,], [loop vectorization])
  box2(21.8, 2.4, 7.4, [-Os, -Oz: documented levels,], [not probed in this book])
  cdraw.line((15.0, 7.4), (15.0, 7.05), stroke: luma(100))
  cdraw.line((15.0, 7.05), (4.5, 7.05), stroke: luma(100))
  cdraw.line((4.5, 7.05), (4.5, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 7.05), (15.0, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 7.05), (25.5, 7.05), stroke: luma(100))
  cdraw.line((25.5, 7.05), (25.5, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.5, 5.0), (4.5, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 5.0), (15.0, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((25.5, 5.0), (25.5, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.5, 2.4), (4.5, 1.5), stroke: luma(100))
  cdraw.line((25.5, 2.4), (25.5, 1.5), stroke: luma(100))
  cdraw.line((4.5, 1.5), (25.5, 1.5), stroke: luma(100))
  cdraw.line((15.0, 1.5), (15.0, 1.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.0, 0.5), [every level preserves observable behavior, the 11 checks pass at -O0], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "one file, two legs, two kinds of truth", [
  The run leg compiles `mem2reg.c` and `vector.c` with no `-O` flag
  and counts 11 checks, all behavioral, all passing on the `-O0`
  build. The ir leg compiles the same files at `-O0`, `-O1`, and
  `-O2` and asserts 9 substrings: 4 in `mem2reg.c` ir, 3 in
  `vector.c` ir, 2 in the `-O2` disassembly. Behavior is claimed
  where it runs, structure is claimed where it is emitted, and no
  claim crosses legs.
])

sources: llvm.org/docs/LangRef.html (the `alloca` instruction, the
`alwaysinline` attribute, the `llvm.fmuladd.*` intrinsics),
clang.llvm.org/docs/UsersManual.html (the -Rpass remark family),
clang.llvm.org/docs/ClangCommandLineReference.html (the optimization
level flags), llvm.org/docs/NewPassManager.html (PassBuilder and
default pipelines), llvm.org/docs/Vectorizers.html (the loop
vectorizer cost model and remarks), accessed 2026-09-12; the ir
bodies, disassembly, and remark lines quoted in this chapter probed
on this machine the same day. Sample behavior verified by `make
verify-c`, 11 checks in chapter 9 of the samples suite.
