#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= reading llvm ir

The ir is the contract between the frontend and the optimizer. Clang
writes it, llvm's passes read and rewrite it, and the backend lowers it
to machine code. This chapter reads one small function's ir at three
optimization levels and takes the whole tour: module header, globals,
the define line, the body, the decorations, and the address arithmetic.
Because the windows distribution ships no `llvm-as`, `llvm-dis`, or
`opt` (the inventory is chapter 7's), every step routes through the
driver: `clang -S -emit-llvm` writes the text, and the same clang
compiles a `.ll` file back. Every ir line quoted below was emitted by
clang 23.1.1 on this machine on 2026-09-12, and every structural claim
is pinned in the chapter's `expect-ir.txt`, 16 assertions the gate
re-verifies on each run.

== a function through -emit-llvm, the round trip

The command line reference defines the two flags tersely: `-S`, "only
run preprocess and compilation steps", and `-emit-llvm`, "use the LLVM
representation for assembler and object files". Together they stop the
driver after ir generation and write text. The subject under the
microscope:

#listing("c-os-cloud/samples/src/Ch08/ir.c", first: 19, last: 37, caption: [the dissection subject: a struct, a restrict pointer, a branch, and a four-element loop])

`tally` reads `p->tag`, branches on `bonus`, and on the taken arm adds
the bonus and all four slots, on the other arm subtracts the bonus. The
struct is two fields, one `int` and an array of four. The checks pin
both arms and two layout facts:

#listing("c-os-cloud/samples/src/Ch08/ir.c", first: 39, last: 47, caption: [both arms asserted, plus the two numbers that reappear in the ir: 20 bytes, offset 4])

The module opens with its identity and target. The `target
datalayout` string starts with `e`, little endian, pins `i64:64`, and
ends `S128`, a 128-byte stack alignment preference; the `p270:32:32`
style clauses give the pointer sizes of x86's non-default address
spaces. The `target triple` is
`"x86_64-pc-windows-msvc19.33.0"`: that version is clang's default
msvc compatibility level, not the installed toolset. Probed the same
day: preprocessing an empty file with this triple defines
`_MSC_VER` as 1933, while the gate links against the 14.44 toolset
chapter 1 resolved. The triple fixes the abi clang targets, not which
libraries were found. Below it the struct becomes a named ir type,
`%struct.packet = type { i32, [4 x i32] }`, two members, no padding,
20 bytes, exactly the size the fourth check asserted.

The header's `stdio.h` wrappers arrive next as
`define linkonce_odr dso_local i32 @printf(...)` plus a `$printf =
comdat any` line: every translation unit may carry the definition, and
the linker keeps one. Then the initializer of main's local, a private
constant: `@__const.main.p = private unnamed_addr constant
%struct.packet { i32 100, [4 x i32] [i32 2, i32 4, i32 6, i32 8] },
align 4`. The declaration `struct packet p = {...}` compiles to `call
void @llvm.memcpy.p0.p0.i64(ptr align 4 %2, ptr align 4
@__const.main.p, i64 20, i1 false)`: 20 bytes copied from the constant
into the alloca. The `sizeof` check is physically present in the ir as
the `i64 20`.

The function's first line deserves every word:

`define dso_local i32 @tally(ptr noalias noundef %0, i32 noundef %1) #0`

`define` opens a body. `dso_local` promises the symbol resolves inside
this module, so no dllimport indirection. The return type is `i32`,
the ir spelling of `int`. `noalias` is chapter 4's `restrict` promise
translated for the optimizer, and it is already here at -O0. `noundef`
sits on every parameter in this module; section 3 reads it. Parameters
are unnamed, `%0` and `%1`, and the `#0` references an attribute group
printed at the file's bottom: `noinline nounwind optnone uwtable`,
where `optnone` is the module's confession that no pass ran. Inside,
the body is memory: `%3 = alloca i32, align 4` through `%6`, and the
first real instructions are stores of the parameters into their
allocas. Locals start at `%3` because unnamed values and blocks share
one counter and the implicit entry block consumed `%2`. The branch is
`br i1 %11, label %12, label %32`, `%11` being the `icmp sgt i32 %10,
0`.

#diagram([one source, two routes through the driver: one stops at the text for reading, one compiles the text back and demands the same output], length: 13pt, {
  let box(x, y, w, h, fill: luma(235)) = cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
  // band a: the dissection route
  box(0.4, 6.0, 3.2, 1.0)
  cdraw.content((2.0, 6.5), [ir.c], wrap: text.with(size: 6pt))
  cdraw.line((3.6, 6.5), (4.8, 6.5), stroke: luma(100), mark: (end: ">"))
  box(4.8, 5.5, 5.4, 2.0)
  cdraw.content((7.5, 6.75), [clang -S -emit-llvm], wrap: text.with(size: 6pt))
  cdraw.content((7.5, 6.15), [-O0, -O1, -O2], wrap: text.with(size: 6pt))
  cdraw.line((10.2, 6.5), (11.4, 6.5), stroke: luma(100), mark: (end: ">"))
  box(11.4, 5.5, 4.6, 2.0)
  cdraw.content((13.7, 6.75), [the .ll text,], wrap: text.with(size: 6pt))
  cdraw.content((13.7, 6.15), [dissected below], wrap: text.with(size: 6pt))
  cdraw.line((16.0, 6.5), (17.2, 6.5), stroke: luma(100), mark: (end: ">"))
  box(17.2, 4.6, 6.0, 2.9)
  cdraw.content((20.2, 6.85), [-O0: allocas, stores], wrap: text.with(size: 6pt))
  cdraw.content((20.2, 6.2), [-O1: mem2reg grows phis], wrap: text.with(size: 6pt))
  cdraw.content((20.2, 5.55), [-O2: one vector load], wrap: text.with(size: 6pt))
  // band b: the round trip route
  box(0.4, 1.4, 3.2, 1.0)
  cdraw.content((2.0, 1.9), [roundtrip.c], wrap: text.with(size: 6pt))
  cdraw.line((3.6, 1.9), (4.8, 1.9), stroke: luma(100), mark: (end: ">"))
  box(4.8, 1.4, 5.4, 1.0)
  cdraw.content((7.5, 1.9), [clang -S -emit-llvm], wrap: text.with(size: 6pt))
  cdraw.line((10.2, 1.9), (11.4, 1.9), stroke: luma(100), mark: (end: ">"))
  box(11.4, 1.4, 4.6, 1.0)
  cdraw.content((13.7, 1.9), [roundtrip.ll, optnone], wrap: text.with(size: 6pt))
  cdraw.line((16.0, 1.9), (17.2, 1.9), stroke: luma(100), mark: (end: ">"))
  box(17.2, 1.4, 6.0, 1.0)
  cdraw.content((20.2, 1.9), [exe 2, from the text], wrap: text.with(size: 6pt))
  // the direct path
  cdraw.line((2.0, 1.4), (2.0, -0.7), stroke: luma(100))
  cdraw.line((2.0, -0.7), (4.8, -0.7), stroke: luma(100), mark: (end: ">"))
  box(4.8, -1.2, 5.4, 1.0)
  cdraw.content((7.5, -0.7), [clang roundtrip.c], wrap: text.with(size: 6pt))
  cdraw.line((10.2, -0.7), (11.4, -0.7), stroke: luma(100), mark: (end: ">"))
  box(11.4, -1.2, 4.6, 1.0)
  cdraw.content((13.7, -0.7), [exe 1, direct], wrap: text.with(size: 6pt))
  // the verdict
  box(17.2, -2.4, 6.0, 2.0, fill: luma(215))
  cdraw.content((20.2, -0.95), [both run in isolated dirs,], wrap: text.with(size: 6pt))
  cdraw.content((20.2, -1.75), [stdout must match exactly], wrap: text.with(size: 6pt))
  cdraw.line((20.2, 1.4), (20.2, -0.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.0, -0.7), (17.2, -0.7), stroke: luma(100), mark: (end: ">"))
})

The second sample rides the gate's roundtrip leg end to end:

#listing("c-os-cloud/samples/src/Ch08/roundtrip.c", first: 18, last: 30, caption: [a checksum with a loop, a branch, a shift, and a multiply: real instructions for the text to carry])

#listing("c-os-cloud/samples/src/Ch08/roundtrip.c", first: 32, last: 39, caption: [five checks, two of them digests pinned from observed runs])

The leg compiles the source directly to one exe, emits the `.ll` at
the driver's default level (no `-O` flag; the emitted text carries
`optnone`, the no-pass marker), compiles the `.ll` itself into a
second exe, runs both in isolated directories, and fails unless the
stdout matches exactly. At the default level `checksum` reads `define
dso_local i32 @checksum(ptr noundef %0, i32 noundef %1) #0`, the same
parameter decorations as `tally`. The digests are fnv-1a arithmetic
modulo 2^32, 286893964 and 4180433557 for the byte string `"llvm"` with
and without the rotation, and both exes must print them.

#callout("verify", "what the round trip proves, and what it does not", [
  The leg proves observable behavior survives a stop at the textual ir:
  same checks, same digests, same exit code from an exe built out of
  `.ll` text. It does not prove the pipeline is an identity. The two
  executables are not compared byte for byte, and nothing claims every
  optimization is invertible. The comparison is exactly the observable
  the standard owes the program, the same list chapter 5 quoted from
  5.1.2.4, which is the honest thing to assert about a compiler.
])

== ssa and phi

Every numbered value in this module is defined exactly once. `%3` is
one `alloca`, `%11` is one `icmp`, and no line ever reassigns `%11`.
That is single static assignment, and the ir holds the shape at every
`-O` level for its own registers. What -O0 lacks is ssa for the source
variables: `total` and `i` are not registers but four bytes of stack
each. Every mutation is a store, `%15 = add i32 %14, %13` followed by
`store i32 %15, ptr %5, align 4` on the taken arm, another store
inside the loop, and one final `%37 = load i32, ptr %5, align 4`
before the `ret`. `tally`'s -O0 body contains no phi at all: the
if/else result travels through memory.

At -O1 the allocas are gone and three phis carry the same program:

`%9 = phi i64 [ 0, %5 ], [ %14, %8 ]` is the induction variable: 0 on
entry to the loop from block `%5`, the incremented `%14` when control
returns along the back edge from `%8` to itself. `%10 = phi i32 [
%6, %5 ], [ %13, %8 ]` is the running total over the same two edges.
`%19 = phi i32 [ %17, %16 ], [ %13, %8 ]` is the if/else merge: `%17`
when the else arm ran, `%13` when the loop exited. The pass that
performs this conversion is mem2reg, which reads the -O0 store
pattern and manufactures the phis; chapter 9 watches it run. The
language reference gives phi its shape: `<result> = phi <ty> [
<val0>, <label0>], ...`, "used to implement the φ node in the SSA
graph representing the function". It takes "a list of pairs as
arguments, with one pair for each predecessor basic block of the
current block", and "PHI instructions must be first in a basic
block", which is why block `%8` opens with its two phis before any
other instruction. At runtime the instruction "logically takes on the
value specified by the pair corresponding to the predecessor basic
block that executed just prior to the current block". The machine
never sees a phi: the backend lowers merges into register moves on
the incoming edges.

#callout("pitfall", "a phi is the merge, not a sequence of moves", [
  Reading `%19 = phi i32 [ %17, %16 ], [ %13, %8 ]` as "first take
  `%17`, then take `%13`" imposes an order the ir does not have. All
  pairs describe the same instant, the moment control enters the
  block, and exactly one pair is live per execution. The frontend
  emits phis for conditional-expression merges only; for C statement
  mutation across an if, the -O0 shape is stores to memory, and the
  phi exists only after mem2reg reads the pattern. The single phi in
  the whole -O0 module of `ir.c` is `%27 = phi i32 [ -1, %23 ], [
  %25, %24 ]` inside `@_vsnprintf_l`, lowered from the ternary in the
  crt header that clamps the return value. That is the entire
  population.
])

#diagram([tally at -O1: blocks, the back edge, and the three phis with the pairs they merge], length: 13pt, {
  let box(x, y, w, h, fill: luma(235)) = cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
  // entry
  box(8.8, 6.4, 7.6, 1.0)
  cdraw.content((12.6, 6.9), [block 2: load tag, icmp sgt], wrap: text.with(size: 6pt))
  // the two arms
  box(0.8, 4.4, 6.6, 1.0)
  cdraw.content((4.1, 4.9), [block 5: add bonus], wrap: text.with(size: 6pt))
  box(17.2, 4.4, 6.6, 1.0)
  cdraw.content((20.5, 4.9), [block 16: sub bonus], wrap: text.with(size: 6pt))
  // the loop, one block, two phis
  box(2.2, 0.9, 8.8, 3.0)
  cdraw.content((6.6, 3.15), [block 8, the whole loop], wrap: text.with(size: 6pt))
  cdraw.content((6.6, 2.5), [%9 = phi i64 \[ 0, %5 \], \[ %14, %8 \]], wrap: text.with(size: 6pt))
  cdraw.content((6.6, 1.85), [%10 = phi i32 \[ %6, %5 \], \[ %13, %8 \]], wrap: text.with(size: 6pt))
  // back edge elbow
  cdraw.line((2.2, 1.5), (1.0, 1.5), stroke: luma(100))
  cdraw.line((1.0, 1.5), (1.0, 3.3), stroke: luma(100))
  cdraw.line((1.0, 3.3), (2.2, 3.3), stroke: luma(100), mark: (end: ">"))
  // the merge
  box(12.4, -0.4, 9.6, 3.0)
  cdraw.content((17.2, 1.55), [block 18, the merge], wrap: text.with(size: 6pt))
  cdraw.content((17.2, 0.9), [%19 = phi i32 \[ %17, %16 \], \[ %13, %8 \]], wrap: text.with(size: 6pt))
  cdraw.content((17.2, 0.25), [ret i32 %19], wrap: text.with(size: 6pt))
  // edges
  cdraw.line((10.6, 6.4), (4.6, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.6, 6.4), (20.4, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.6, 4.4), (4.6, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.4, 4.4), (20.4, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.0, 1.6), (12.4, 1.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.6, 0.35), [two pairs, one per incoming edge], wrap: text.with(size: 6.5pt))
})

At -O2 the loop collapses but the merge survives: the body becomes
`%6 = getelementptr inbounds nuw i8, ptr %0, i64 4`, `%7 = load <4 x
i32>, ptr %6, align 4`, and `%8 = tail call i32
@llvm.vector.reduce.add.v4i32(<4 x i32> %7)`, four scalar loads
folded into one vector load and a horizontal add, while block 13
still opens with `%14 = phi i32 [ %12, %11 ], [ %10, %5 ]` before the
`ret`. The branch is the last control dependence the optimizer cannot
remove, because `bonus` arrives at runtime.

== attributes and metadata

The -O1 define line is a longer sentence than -O0's:

`define dso_local i32 @tally(ptr noalias nofree noundef readonly
captures(none) %0, i32 noundef %1) local_unnamed_addr #0`

`noalias` and `noundef` were present at -O0; `nofree`, `readonly`, and
`captures(none)` are new, painted by the optimizer after inspecting
the body. `readonly` is inference, not translation: the source says
`const struct packet *restrict`, yet the -O0 line carries no readonly,
because `const` qualifies the accesses while the attribute claims
something about the whole function, that it stores nothing through
the pointer. True here, and provable from the body alone. The
reference defines `noalias` exactly as chapter 4's promise: "memory
locations accessed via pointer values based on the argument or return
value are not also accessed, during the execution of the function,
via pointer values not based on the argument or return value".
Chapter 5 showed what the optimizer banks for it, the unguarded
vector body against the plain twin's runtime overlap check. `noundef`
is shorter: "If the value representation contains any undefined or
poison bits, the behavior is undefined". It converts garbage-in into
a contract violation, which later passes may assume cannot happen.

Main gains a return decoration at -O1: `define dso_local noundef
range(i32 0, 2) i32 @main()`. Both return statements return
constants, 0 and 1, so the frontend paints the half-open range; the
reference states the pair semantics, "The pair `a,b` represents the
range `[a,b)`", and the consequence, a value outside the range "is
converted to poison". Poison is ir's undefined-value mechanism, a
placeholder for a value the optimizer has proven cannot occur, it
spreads through every computation that consumes it, and a branch or
side effect that depends on it is undefined behavior. The gate's own
exit discipline is readable in the signature. Function bodies reference numbered groups, and the
group at the bottom of the -O2 file reads `mustprogress nofree
norecurse nosync nounwind willreturn memory(argmem: read)` plus the
target string `"target-cpu"="x86-64" "target-features"="+cmov,+cx8,
+fxsr,+mmx,+sse,+sse2,+x87"`, the baseline the whole module was
compiled for. `mustprogress` licenses the assumption the reference
names: "a loop in a function with the mustprogress attribute can be
assumed to terminate if it does not interact with the environment in
an observable way". `norecurse` says the function "never occurs
inside a cycle in the dynamic call graph". `memory(argmem: read)`
summarizes every memory effect into one attribute: reads, and only
its own arguments.

Metadata rides on instructions and on the module. The loop back edge
carries `!llvm.loop !7` even at -O0, and the node's content is `!8 =
!{!"llvm.loop.mustprogress"}`, the same progress license echoed per
loop. The module tail stamps its producer twice, `!llvm.ident =
!{!6}` with `!6 = !{!"clang version 23.1.2 ..."}` (the book froze
under 23.1.1 and the machine drifted to 23.1.2, so the expectation
pins the major only, the ident's presence rather than its patch
number, the drift rule applied to this pin too) and a
`!llvm.dbg.cu` compile unit whose `isOptimized` field flips from
false at -O0 to true at -O2. The `!alias.scope` and `!noalias`
metadata from chapter 5's guarded loop body are the optimizer
annotating its own runtime check; the reference describes the pair as
"generic noalias memory-access sets" in which instructions carrying
`noalias` metadata "can specifically be specified not to alias with
some other collection of memory access instructions that carry
`alias.scope` metadata".

#callout("note", "pin what exists", [
  This section's figure-plan row originally named `!tbaa` as the
  metadata to show. The emitted files contain none of it at any
  level, and the reason is pinned in chapter 5 as cos-004: the
  msvc-target driver injects `-relaxed-aliasing` into every cc1
  invocation, which disables type-based alias analysis for the whole
  module, and no flag turns it back on. The plan row was corrected to
  the probed absence, and the gate pins `noalias`, `range`, and
  `!llvm.loop` instead. Evidence has to exist before it can be
  asserted.
])

#diagram([the module's self description: token, where it appears, who wrote it, and what it promises], length: 13pt, {
  let cols = ((0.6, 5.4), (6.2, 5.6), (12.0, 6.2), (18.4, 8.8))
  let row(y, cells, fill: none) = {
    for (i, (x, w)) in cols.enumerate() {
      if fill != none { cdraw.rect((x, y), (x + w, y + 0.8), fill: fill, radius: 0.02) }
      cdraw.content((x + w / 2, y + 0.4), cells.at(i), wrap: text.with(size: 6pt))
    }
  }
  row(7.35, ([token], [seen in], [written by], [what it claims]), fill: luma(215))
  row(6.5, ([noalias], [tally %0, all levels], [frontend, from restrict], [no access through other bases]), fill: luma(245))
  row(5.65, ([noundef], [every parameter, -O0], [frontend], [undef bits become undefined behavior]))
  row(4.8, ([readonly], [tally %0, -O1 and -O2], [the optimizer], [nothing is stored through it]), fill: luma(245))
  row(3.95, ([captures(none), nofree], [tally %0, -O1 and -O2], [the optimizer], [the pointer never escapes or frees]))
  row(3.1, ([range(i32 0, 2)], [main return, -O1], [frontend], [the value is 0 or 1, else poison]), fill: luma(245))
  row(2.25, ([!llvm.loop], [the branch back edge], [frontend], [loop identity, mustprogress echo]))
  row(1.4, ([!llvm.ident], [module tail], [frontend], [the clang 23.1.1 stamp]), fill: luma(245))
  row(0.55, ([!alias.scope, !noalias], [ch5 guarded vector body], [the optimizer], [disjoint scopes from a runtime check]))
  row(-0.3, ([!tbaa], [nowhere, any level], [nobody: -relaxed-aliasing], [off on this target, cos-004]), fill: luma(245))
})

== gep and typed pointers

Every pointer in this module is `ptr`. There is no `i32*` anywhere in
a 23.x module: the opaque pointers migration made `ptr` the only
pointer type, enabled by default in llvm 15 and, quoting the
migration page's version table for 17, "Only opaque pointers are
supported. Typed pointers are not supported." The page records the
reasoning: the pointee type "carries no real semantics" because
pointers could always be cast between pointee types, and the
community concluded "the costs of pointee types outweigh the
benefits". Interpretation moved onto the instructions, `load i32,
ptr %8` says what is read, and the one instruction that still needs a
type to scale offsets is gep, whose first operand is the source
element type.

The two element walks at -O0 are the whole lesson: `%8 =
getelementptr inbounds nuw %struct.packet, ptr %7, i32 0, i32 0`
reads `p->tag`. The slots walk is three instructions: `%21 =
getelementptr inbounds nuw %struct.packet, ptr %20, i32 0, i32 1`
selects the field, `%23 = sext i32 %22 to i64` widens the C `int`
index to the pointer index type, and `%24 = getelementptr inbounds
[4 x i32], ptr %21, i64 0, i64 %23` scales it by the element size.
The reference's rule: the instruction "performs address calculation
only and does not access memory", "the first index always indexes the
pointer value given as the second argument, the second index indexes
a value of the type pointed to", struct indices must be `i32`
constants, and array indices "are not required to be constant". The
offset itself is the index "multiplied by the type allocation size":
the field walk lands at `p + 4`, the `offsetof` check's 4, and the
array walk at `p + 4 + 4i`. The dedicated gep page adds the two
sentences that keep beginners out of trouble: "The GetElementPtr
instruction dereferences nothing", and without `inbounds` "there are
no restrictions on computing out-of-bounds addresses".

The flags are promises with proofs attached. `inbounds` says the base
points into an allocated object and every successive addition keeps
the result "in bounds of the allocated object at each step"; a gep
with all-zero indices is always inbounds. `nuw` strengthens this to
no-wrap arithmetic: the index multiplication and offset additions "do
not wrap the pointer index type in an unsigned sense". The emission
is exact about what is provable when: both constant-offset field geps
carry `inbounds nuw` at -O0, a constant offset cannot wrap, while the
runtime-index gep carries `inbounds` alone, because no frontend proof
exists that an arbitrary index times the element size stays inside
the pointer's unsigned arithmetic. At -O1 the loop's element walk reappears
as `%11 = getelementptr inbounds nuw [4 x i8], ptr %7, i64 %9`: the
same addresses, the stride folded into a 4-byte element type, and
`nuw` now claimed because the loop test proved `0 <= %9 < 4`. Flags
grow with proof. At -O2 the walk compresses to `%6 = getelementptr
inbounds nuw i8, ptr %0, i64 4` and a single `<4 x i32>` load across
all 16 bytes of `slots`.

#diagram([struct.packet on the byte strip: where the two geps land and what -O2 does to the walk], length: 13pt, {
  // five 4-byte cells, tag shaded
  let names = ([tag], [slot 0], [slot 1], [slot 2], [slot 3])
  for i in range(5) {
    let f = if i == 0 { luma(205) } else { luma(235) }
    cdraw.rect((3.0 + i * 2.6, 4.4), (5.6 + i * 2.6, 5.8), fill: f, radius: 0.02)
    cdraw.content((4.3 + i * 2.6, 5.1), names.at(i), wrap: text.with(size: 6pt))
  }
  // byte ruler
  for (i, off) in ("0", "4", "8", "12", "16", "20").enumerate() {
    cdraw.content((3.0 + i * 2.6, 3.95), off, wrap: text.with(size: 6pt, fill: luma(100)))
  }
  // the base pointer
  cdraw.content((1.4, 5.1), [p], wrap: text.with(size: 6.5pt))
  cdraw.line((1.8, 5.1), (3.0, 5.1), stroke: luma(100), mark: (end: ">"))
  // the two geps
  cdraw.content((5.0, 7.1), [field gep: i32 0, i32 1, lands at byte 4], wrap: text.with(size: 6pt))
  cdraw.line((6.4, 6.8), (5.6, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.2, 7.1), [array gep: i64 0, i64 %23, lands at 4 + 4i], wrap: text.with(size: 6pt))
  cdraw.line((14.0, 6.8), (10.4, 5.8), stroke: luma(100), mark: (end: ">"))
  // the -O2 span over the whole array
  cdraw.line((5.6, 2.9), (16.0, 2.9), stroke: luma(120))
  cdraw.line((5.6, 2.9), (5.6, 3.2), stroke: luma(120))
  cdraw.line((16.0, 2.9), (16.0, 3.2), stroke: luma(120))
  cdraw.line((11.6, 2.9), (11.6, 3.65), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.8, 2.3), [-O2: gep i8 by 4 once, then one 16-byte vector load], wrap: text.with(size: 6pt))
  cdraw.content((10.8, 1.3), [inbounds: every step stays inside these 20 bytes], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((10.8, 0.5), [gep computes addresses and dereferences nothing: the load reads], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

This is the arithmetic under C's pointer rules. Chapter 4's `a + 2`
and `*(*(m + 1) + 2)` lower to geps, chapter 5's optimizer restated
its aliasing promises as `getelementptr inbounds` on walks it
invented, and the type-based analysis this target keeps switched off
would have consumed the same instruction stream. The next chapter
stops reading the ir and starts asking what the passes do to it.

sources: llvm.org/docs/LangRef.html (the phi instruction, the
getelementptr instruction with its inbounds and nuw rules, the
parameter attributes noalias, noundef, and range, the function
attributes mustprogress and norecurse, and the noalias and
alias.scope metadata), llvm.org/docs/GetElementPtr.html,
llvm.org/docs/OpaquePointers.html, and
clang.llvm.org/docs/ClangCommandLineReference.html for -emit-llvm and
-S, all accessed 2026-09-12; every quoted .ll line emitted by clang
23.1.1 on this machine the same day, and the tbaa absence follows
the -relaxed-aliasing injection pinned in chapter 5. Sample behavior
verified by `make verify-c`, 10 checks in chapter 8 of the samples
suite.
