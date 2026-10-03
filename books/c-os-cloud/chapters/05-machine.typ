#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the abstract machine and undefined behavior

The C standard does not describe your computer. The final c23 draft,
n3220, states the model in one sentence at 5.1.2.4: the semantic
descriptions in the document describe the behavior of an abstract
machine in which issues of optimization are irrelevant. The
implementation owes the program the observable behavior only, the same
clause enumerates it: volatile accesses evaluated strictly, data written
into files at termination identical to what abstract execution would
have produced, interactive input and output dynamics as specified. Of
the three, volatile is the programmer's lever, it tells the compiler
every read and write of the object is observable, so none may be
elided or merged. Everything else may be rewritten, reordered, or
skipped, and that license is the as-if rule the diagram names below.

That gap between the sentence and the silicon is why every behavioral
claim in this book answers to one of three machines. A claim about the
standard machine cites an n3220 clause. A claim about the compiled
machine, clang 23.1.1 on this box, cites the emitted ir or a
disassembly. A claim about the hardware cites an observed run. The
standard itself sanctions the seam with its own example: the abstract
machine promotes two `char` operands to `int` before adding them, and
an actual execution may skip the promotions provided the addition is
done without integer overflow, or with overflow wrapping silently to
produce the correct result. The deal holds only for programs that stay
inside the contract. The rest of this chapter is the contract.

== the abstract machine vs the real one

#diagram([three machines and the observable seam between them], length: 13pt, {
  // 6pt two-line content needs 1.8-unit boxes: line pitch 0.6, border
  // clearance 0.35 (measured on the 300ppi render, 2026-09-12)
  let layer(y, l1, l2, fill: luma(235)) = {
    cdraw.rect((1.0, y), (16.4, y + 1.8), fill: fill, radius: 0.02)
    cdraw.content((8.7, y + 1.2), l1, wrap: text.with(size: 6pt))
    cdraw.content((8.7, y + 0.6), l2, wrap: text.with(size: 6pt))
  }
  layer(8.0, [the standard machine: n3220,], [the abstract machine of 5.1.2.4], fill: luma(205))
  layer(5.8, [the compiled machine: clang 23.1.1,], [ir, passes, the as-if rule])
  layer(3.6, [the hardware: x86-64,], [two's complement at the bits], fill: luma(205))
  cdraw.content((8.7, 2.7), [claims answer upward: observed, read, cited], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.rect((1.0, 0.4), (16.4, 2.1), stroke: luma(160), radius: 0.02)
  cdraw.content((8.7, 1.6), [observable behavior: volatile accesses,], wrap: text.with(size: 6pt))
  cdraw.content((8.7, 1.0), [file contents at exit, interactive io], wrap: text.with(size: 6pt))
  cdraw.content((21.4, 8.9), [what the standard #linebreak() owes the program], wrap: text.with(size: 6pt))
  cdraw.content((21.4, 4.7), [what the cpu does #linebreak() with the bytes it gets], wrap: text.with(size: 6pt))
  cdraw.content((21.4, 1.25), [all three agree here #linebreak() or the bug is elsewhere], wrap: text.with(size: 6pt))
})

The three layers disagree exactly where behavior is undefined, and the
standard says what that word costs. 6.5 paragraph 5: if an exceptional
condition occurs during the evaluation of an expression, that is, if
the result is not mathematically defined or not in the range of
representable values for its type, the behavior is undefined. Signed
overflow is the canonical exceptional condition. The annex that
enumerates undefined behavior lists it beside reading a stored value
through an lvalue of a non-allowable type, the strict aliasing rule,
and 6.5.6 supplies the pointer side: if the pointer operand and the
result do not point to elements of the same array object or one past
the last element, the behavior is undefined. Undefined means the
standard imposes no requirements at all. No crash is guaranteed, no
wrap is guaranteed, no diagnosis is required.

== the ub contract, tbaa evidence

#callout("pitfall", "this book never executes the violation", [
  A program whose execution reaches undefined behavior has no
  obligations left, so a run that happened to wrap demonstrates
  nothing about the next compiler or the next flag. Every sample in
  this chapter keeps every promise. The evidence for what the optimizer
  assumes comes from the ir emitted for clean code and from the
  standard's own sentences, never from a crash the gate coaxed into
  existence.
])

The samples keep the aliasing promise on record and let the compiler
show what it does with it. Two functions differ by one word:

#listing("c-os-cloud/samples/src/Ch05/restrict_tbaa.c", first: 18, last: 30, caption: [the restrict twin and the plain twin, one word apart])

The `restrict` qualifiers are a promise from caller to compiler that
the arrays behind `out` and `in` do not overlap for the whole call.
The caller keeps it:

#listing("c-os-cloud/samples/src/Ch05/restrict_tbaa.c", first: 40, last: 47, caption: [distinct arrays in, same arithmetic asserted out of both twins])

Emitting the ir with the gate's own command, `clang -std=c23 -S
-emit-llvm -O2`, shows the promise banked. At -O0 the restrict
function already reads `define dso_local void @scale_accum(ptr
noalias noundef %0, ptr noalias noundef %1, ...)` while the plain
twin's arguments carry nothing. At -O2 the difference becomes the
whole body. The restrict version walks straight into a vector body,
`<4 x i32>` loads and stores with no pointer test anywhere. The plain
twin first computes two `icmp ult ptr` comparisons and branches on
their conjunction, a runtime overlap check guarding the vector body,
and the loads inside that versioned body carry `!alias.scope` and
`!noalias` metadata the compiler synthesized from its own check. The
pointer math inside both vector bodies is `getelementptr inbounds`,
the optimizer's own restatement of the promise 6.5.6 writes for source
code, that every computed address stays inside its array object or one
past its end. The gate pins all four facts in `Ch05/expect-ir.txt`:
`noalias` at -O0 and -O2, `icmp ult ptr` and `getelementptr inbounds`
at -O2.

One piece of the planned evidence does not exist on this target. The
plan asked for `!tbaa`, the type-based alias analysis metadata, in the
-O2 ir. The probe found why it is absent and why no flag brings it
back. `clang -###` shows the driver injecting `-relaxed-aliasing`
into cc1 for the x86_64-pc-windows-msvc target, which turns tbaa off
to match msvc semantics, and the classic `-fstrict-aliasing` spelling
no longer exists in this frontend: cc1 rejects it as an unknown
argument and the driver drops it from the cc1 line, so there is no
way to re-enable tbaa on this target at all. The same twin shape on
a linux triple grows `!tbaa` on every load and store by default,
probed 2026-09-12. The aliasing evidence in this book's gate is
`noalias` and the versioned-loop metadata. The contract itself still
binds. Reading an
`int` object through a `float` lvalue is undefined today, listed by
the same annex as the exceptional condition, and `restrict` only adds
promises on top of it. Chapter 4 treats restrict as an interface
tool. Here it is a contract whose banking is visible.

#diagram([one word of promise, two machines: what the -O2 ir shows for each twin], length: 13pt, {
  let colbase(x, title) = {
    cdraw.rect((x, 6.5), (x + 9.8, 7.6), fill: luma(205), radius: 0.02)
    cdraw.content((x + 4.9, 7.05), title, wrap: text.with(size: 6.5pt))
    cdraw.rect((x, 5.0), (x + 9.8, 6.3), fill: luma(235), radius: 0.02)
    cdraw.rect((x, 3.7), (x + 9.8, 4.8), fill: luma(235), radius: 0.02)
    cdraw.rect((x, 2.3), (x + 9.8, 3.6), fill: luma(235), radius: 0.02)
  }
  // left column, the promise kept
  colbase(0.6, [the promise kept])
  cdraw.content((5.5, 5.95), [`int *restrict out`,], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 5.4), [`const int *restrict in`], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 4.25), [-O0 ir: noalias on both], wrap: text.with(size: 6pt))
  cdraw.content((5.5, 3.25), [-O2: vector body], wrap: text.with(size: 6pt, fill: rgb("#006400")))
  cdraw.content((5.5, 2.7), [unguarded], wrap: text.with(size: 6pt, fill: rgb("#006400")))
  // right column, no promise
  colbase(13.2, [no promise])
  cdraw.content((18.1, 5.95), [`int *out`,], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 5.4), [`const int *in`], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 4.25), [-O0 ir: no noalias], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 3.25), [-O2: icmp ult ptr,], wrap: text.with(size: 6pt, fill: rgb("#8B0000")))
  cdraw.content((18.1, 2.7), [runtime overlap guard], wrap: text.with(size: 6pt, fill: rgb("#8B0000")))
  // shared notes, single-line contents: multi-line blocks spread around their
  // anchor and interleave when stacked this close (probed on the render)
  cdraw.content((11.8, 1.9), [the guarded body carries !alias.scope and !noalias,], wrap: text.with(size: 6pt))
  cdraw.content((11.8, 1.35), [metadata synthesized from the runtime check itself], wrap: text.with(size: 6pt))
  cdraw.content((11.8, 0.6), [never executed on either side: signed overflow,], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.8, 0.05), [the wrong-type lvalue, the out-of-bounds pointer], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== checked arithmetic vs raw overflow probes

The textbook overflow shapes sit in the sample as evidence, executed
only on arguments whose results fit:

#listing("c-os-cloud/samples/src/Ch05/ubprobes.c", first: 20, last: 29, caption: [the comparison shapes and the width 37 probe, all run on safe inputs])

The folklore says the optimizer folds `x + 1 > x` to constant true
because overflow is undefined. This compiler cannot: `clang -###`
shows the driver passing `-fwrapv` to cc1 for the msvc target, so
signed arithmetic is compiled as wrapping by toolchain contract and
no add carries the `nsw` assumption the fold needs. What it does
instead: at
-O2 `no_overflow` reduces to a single comparison, `icmp ne i32 %0,
2147483647`, and `wraps` reduces to `icmp eq i32 %0, 2147483647`. Both
are the exact truth table two's complement wrap would compute, one
comparison instead of an add and a compare, and they agree with the
wrap machine on every input. The undefined-behavior latitude lives in
the standard machine, and this toolchain spends it nowhere, it buys
defined wrap for every translation unit instead. Where the contract
is visibly banked is the guard
elision above and the checked-arithmetic intrinsics below.

#diagram([arithmetic near the range edge: the decision this book makes every time], length: 13pt, {
  cdraw.rect((0.6, 6.2), (29.4, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((15.0, 6.7), [an operation may cross its type boundary], wrap: text.with(size: 6.5pt))
  let box(x, l1, l2, l3) = {
    cdraw.rect((x, 2.2), (x + 7.0, 4.9), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.5, 4.35), l1, wrap: text.with(size: 6pt))
    cdraw.content((x + 3.5, 3.5), l2, wrap: text.with(size: 6pt))
    cdraw.content((x + 3.5, 2.65), l3, wrap: text.with(size: 6pt))
  }
  box(0.6, [exact value matters], [the checked builtin], [report + stored wrap])
  box(8.05, [wrap is the point], [unsigned arithmetic], [modulo 2^N])
  box(15.5, [the assumption story], [-S -emit-llvm], [read the emitted .ll])
  box(22.95, [signed overflow], [undefined at 6.5p5], [never executed])
  cdraw.line((5.4, 6.2), (4.1, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.0, 6.2), (11.55, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.5, 6.2), (19.0, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((24.2, 6.2), (26.45, 4.9), stroke: luma(140), mark: (end: "x"))
})

The checked route is defined for every argument pair. The gcc
documentation of the builtin family, which clang implements, states
the deal: the operands are promoted into an infinite precision signed
type, the result is cast to the type the third pointer points to and
stored there, the function returns false when the stored result equals
the infinite precision result, and the behavior is fully defined for
all argument values. The truth table in the sample:

#listing("c-os-cloud/samples/src/Ch05/ubprobes.c", first: 31, last: 46, caption: [add, sub, and mul truth tables, report plus stored two's complement value])

The overflow return is the standard-grade fact and the stored value is
the cast landing on this target's two's complement representation:
`int_max + 1` stores `int_min`, `int_min - 1` stores `int_max`,
`int_max * 2` stores -2. In the emitted ir the builtins never become
plain arithmetic, they lower to `llvm.sadd.with.overflow.i32` and its
sub and mul siblings, and the gate pins that at -O0, where the
lowering happens in the frontend. When wrap is the point, the standard
sells it directly. A computation involving unsigned operands can never
overflow because the arithmetic is performed modulo 2^N, and 3.28
gives the process its name: wraparound, the reduction of a value
modulo 2^N where N is the width of the resulting type.

#listing("c-os-cloud/samples/src/Ch05/ubprobes.c", first: 48, last: 62, caption: [defined wrap at width 32 and at bit-precise width 37])

#callout("note", "generosity is not a contract", [
  The figure plan for this chapter said to assert signed wrap through
  `_BitInt`. The standard disagrees with the plan. Footnote 32 of
  6.2.5: any statement about signed integer types also applies to the
  bit-precise signed integer types unless otherwise noted, and no note
  grants them wraparound. Signed `_BitInt` overflow is undefined like
  every other signed overflow, so this book does not run it. The
  compiled machine is currently more generous, `bitint_probe` emits a
  plain `add i37` with no assumption flag at -O0 or -O2, and the gate
  pins only the structural fact that the width 37 add exists. What a
  compiler does today is an observation. What it may do tomorrow is
  the contract.
])

== sanitizers as oracle

The last leg of the gate recompiles `ubprobes.c` with
`-fsanitize=address` and runs it. AddressSanitizer instruments every
memory access against shadow memory. The design maps 8 bytes of
application memory into 1 shadow byte, on 64-bit via shadow equals
`(mem >> 3) + 0x7fff8000`, and encodes the verdict per shadow byte: 0
for fully addressable, negative for poisoned, 1 through 7 for the
first k bytes addressable at the tail of an allocation. It detects
out-of-bounds accesses to heap, stack and globals, use-after-free,
double-free and invalid free, produces no false alarms, and exits on
the first error it finds. A sample that probed out of bounds would
abort the leg, which is why `ubprobes.c` owns arithmetic truth tables
and no memory violation: what the sanitizer would catch is explained
here with the encoding above, not executed.

The windows detail is the runtime. The instrumented exe imports
`clang_rt.asan_dynamic-x86_64.dll` from the compiler resource
directory, and the gate copies that dll next to the exe before
running. Probed: the unstaged exe dies with exit code `0xc0000135`,
dll not found, before `main` runs, and the staged one passes all 15
checks. UndefinedBehaviorSanitizer would check the contract
violations directly, its default group includes `alignment`, `bounds`,
`null`, `shift` and `signed-integer-overflow`, reporting `runtime
error: signed integer overflow: 2147483647 + 1 cannot be represented
in type 'int'` and continuing by default. It is a cited command in
this book, never a gate leg, because it does not run on this box: the
standalone runtime fails to link against the plain gate line with
undefined sanitizer-internal symbols, and forcing the asan import
library in produces an exe that dies at startup with `0xc0000139`,
entry point not found. Probed 2026-09-12.

#diagram([the sanitizer leg: instrument, stage, run, and the two ways the run ends], length: 13pt, {
  let box(x, y, w, l1, l2) = {
    cdraw.rect((x, y), (x + w, y + 1.6), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 1.1), l1, wrap: text.with(size: 6pt))
    cdraw.content((x + w / 2, y + 0.5), l2, wrap: text.with(size: 6pt))
  }
  box(0.4, 5.2, 7.2, [compile ubprobes.c,], [-fsanitize=address])
  box(8.6, 5.2, 7.2, [stage the asan], [dynamic dll])
  box(16.4, 5.2, 8.0, [run in temp dir], [under shadow checks])
  cdraw.line((7.6, 5.8), (8.6, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.8, 5.8), (16.4, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.4, 5.2), (18.5, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((1.5, 2.4), (22.5, 4.5), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((12.0, 4.0), [shadow model: 8 app bytes to 1 shadow byte], wrap: text.with(size: 6pt))
  cdraw.content((12.0, 3.45), [shadow = (mem >> 3) + 0x7fff8000], wrap: text.with(size: 6pt))
  cdraw.content((12.0, 2.95), [0 addressable, negative poisoned, 1-7 partial], wrap: text.with(size: 6pt))
  box(1.2, 0.4, 9.6, [green: 15 checks counted,], [the memory contract held])
  box(12.4, 0.4, 9.6, [red: first error aborts,], [poisoned shadow reported])
  cdraw.line((8.6, 2.4), (6.0, 2.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.0, 2.4), (17.2, 2.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.8, -0.9), [ubsan is the cited command only, #linebreak() its runtime does not link on this box], wrap: text.with(size: 6pt, fill: luma(100)))
})

Together with the other legs the oracle covers the chapter end to
end. The compile leg proves the probes are warning-clean c23, the run
leg counts every check, the format leg freezes the source shape, the
ir leg proves the structural facts this chapter quoted, `noalias`,
`icmp ult ptr`, `getelementptr inbounds`, the width 37 add, the
overflow intrinsics, and the asan leg proves the memory contract holds
on the sample the gate nominates for it.

sources: open-std.org n3220 (5.1.2.4 abstract machine and observable
behavior, 6.5p5 exceptional condition, 3.28 wraparound, 6.5.6 pointer
arithmetic, 6.2.5 footnotes 32 and 33, the undefined behavior annex),
accessed 2026-09-12; gcc.gnu.org integer overflow builtins and
clang.llvm.org language extensions, the `_BitInt` support and abi
notes, accessed 2026-09-12; clang.llvm.org UndefinedBehaviorSanitizer
and AddressSanitizer pages and the sanitizer project's
AddressSanitizerAlgorithm wiki, the shadow mapping and encodings,
accessed 2026-09-12; the ir facts, the dll staging, and the ubsan link
behavior probed on this machine the same day. Sample behavior verified
by `make verify-c`, 20 checks in chapter 5 of the samples suite.
