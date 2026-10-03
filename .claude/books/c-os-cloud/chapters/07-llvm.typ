#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= llvm: the architecture of the toolchain

`clang` is one command that is not one program. Behind the single
invocation the gate uses stands an architecture: a driver that plans
the work, a front end that turns source bytes into an abstract syntax
tree and the tree into llvm ir, a middle end that rewrites the ir, a
back end that lowers the ir to x86-64 machine code, and a linker that
freezes the result into a pe file. The llvm release index announced
23.1.1 on 2026-09-08, and the binary on this machine identifies itself
down to the revision: `clang --version` prints the commit hash
`6dfe1677ab8dffbc6ec13d53a1e0215d75147689`, the same commit the github
release tag `llvmorg-23.1.1` points at. This chapter walks the
pipeline once, quotes the driver's own transcript of what it runs,
watches the pass manager report its decisions, and maps every tool in
the windows distribution onto the stage it serves.

== front, middle, and back end

LLVM's design joins three ends with one representation. The front end,
`cc1` inside the clang binary, owns everything the language standard
describes: it runs the translation phases of chapter 2, builds the
tree, performs semantic analysis, and lowers the tree to ir. The
middle end runs passes over that ir, transformations that know nothing
about c and everything about the ir's own semantics. The back end
lowers the ir through a selection dag and machine ir to real
instructions and emits the object file. Only ir passes between the
ends, which is the design's whole point: every language front end that
targets llvm feeds every hardware back end through the same
instructions.

#diagram([the pipeline the driver runs, one box per stage, and the fingerprints each stage leaves], length: 13pt, {
  let box(x, w, l1, l2) = {
    cdraw.rect((x, 5.4), (x + w, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.65), l1, wrap: text.with(size: 6pt))
    cdraw.content((x + w / 2, 6.0), l2, wrap: text.with(size: 6pt))
  }
  box(0.4, 4.2, [clang driver], [plans, translates, runs])
  box(5.4, 4.6, [cc1 front end], [lex, ast, lower to ir])
  box(10.8, 4.6, [middle end], [passes over the ir])
  box(16.2, 4.6, [back end], [ir to x86-64 code])
  box(21.6, 4.2, [lld-link], [objects into a pe])
  cdraw.rect((27.0, 5.9), (29.6, 6.9), fill: luma(205), radius: 0.02)
  cdraw.content((28.3, 6.4), [the exe], wrap: text.with(size: 6pt))
  cdraw.line((4.6, 6.3), (5.4, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.0, 6.3), (10.8, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.4, 6.3), (16.2, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.8, 6.3), (21.6, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((25.8, 6.3), (27.0, 6.3), stroke: luma(100), mark: (end: ">"))
  let finger(x, l1, l2) = {
    cdraw.content((x, 4.6), l1, wrap: text.with(size: 6pt, fill: luma(110)))
    cdraw.content((x, 3.95), l2, wrap: text.with(size: 6pt, fill: luma(110)))
  }
  finger(2.5, [-std=c23 -O2 in,], [gcc style flags])
  finger(7.7, [\_\_COUNTER\_\_, \_\_LINE\_\_,], [\_\_has\_c\_attribute\_\_])
  finger(13.1, [\_\_OPTIMIZE\_\_ only with -O,], [remarks report what ran])
  finger(18.5, [\_\_x86\_64\_\_, \_\_SIZEOF\_POINTER\_\_,], [\_\_MSC\_VER\_\_ 1933])
  finger(23.7, [\_\_STDC\_HOSTED\_\_ 1,], [crt and import libs])
  cdraw.content((15.0, 2.6), [one ir text passes between the three ends, every other arrow is a file on disk], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

Every stage leaves fingerprints that survive into the running program,
and `stages.c` checks them one per stage. The preprocessor's expansion
state is the first: `__COUNTER__` advances once per expansion, and
`__LINE__` expands to the line its own token sits on:

#listing("c-os-cloud/samples/src/Ch07/stages.c", first: 22, last: 26, caption: [expansion state and source location, the preprocessor's fingerprints])

Both `__COUNTER__` uses are enum initializers, so the expansion happens
in phase 4 and the constant folding in the front end, and the two
enumerators must read 0 then 1. `line_probe` returns `__LINE__`, and
the check pins the literal 26: the reader counts the lines of the file
and watches the location the lexer recorded arrive in the running
program unchanged.

#listing("c-os-cloud/samples/src/Ch07/stages.c", first: 28, last: 44, caption: [driver mode and backend target, compiled in as constants])

`__OPTIMIZE__` exists only when the driver passes an explicit `-O`
flag. The gate compiles this file with none, so the check reading 0
pins the driver default, `-O0`, no optimization pipeline at all. The
target block records what the back end was told to build:
`__x86_64__` and `_M_X64` together, the msvc-style spellings riding
alongside the clang family macros, `_MSC_VER` expanding to 1933, and
no `__GNUC__` anywhere, this driver speaks msvc compatibility, not gnu
dialect.

#listing("c-os-cloud/samples/src/Ch07/stages.c", first: 46, last: 59, caption: [ten checks, one fingerprint per stage from front end to link])

`__clang_major__` and `__clang_minor__` are the front end's identity,
`__SIZEOF_POINTER__ == 8` is the data layout the back end compiled
against, `__FILE_NAME__` keeps the driver's input spelling, and
`__STDC_HOSTED__ == 1` is the link step's signature: main exists and a
runtime sits under it.

The front end's semantic phase is where c23 attributes are checked,
and `attributes.c` holds them where their consequences are observable.
The first pair is about control flow:

#listing("c-os-cloud/samples/src/Ch07/attributes.c", first: 24, last: 38, caption: [bail never returns, so the body that ends in it needs no return])

`with_default` ends in a call with no return after it. Because the
front end knows `bail` never returns, the path where control falls off
the end does not exist as far as its flow analysis is concerned. That
is a falsifiable claim about the build, and the probe falsifies the
opposite: delete the one word `[[noreturn]]` and the gate refuses the
file with `non-void function does not return a value in all control
paths [-Werror,-Wreturn-type]`. The same falsifiability runs through
the next listing. Discard the `checksum` result at any call site and
the gate refuses the file with `ignoring return value of function
declared with 'nodiscard' attribute [-Werror,-Wunused-result]`. Strip
the `[[maybe_unused]]` from `tag` and it refuses with `unused
parameter 'tag' [-Werror,-Wunused-parameter]`, strip it from
`build_tag` and it refuses with `unused variable 'build_tag'
[-Werror,-Wunused-variable]`. All four diagnostics probed on this box,
2026-09-12:

#listing("c-os-cloud/samples/src/Ch07/attributes.c", first: 40, last: 49, caption: [nodiscard enforced at call sites, `maybe_unused` silencing deliberate waste])

#listing("c-os-cloud/samples/src/Ch07/attributes.c", first: 51, last: 70, caption: [the annotated drop into case 2, its arithmetic checkable])

The `[[fallthrough]]` case has a sharper story than the others. Under
the gate's `-Wextra` the unannotated drop compiles clean, probed:
clang runs that warning at its least strict level there. Turn the
level up with `-Wimplicit-fallthrough` and the same file dies with
`unannotated fall-through between switch labels`, and clang's own
fix-it for it reads `insert '[[fallthrough]];' to silence this
warning`. The attribute is the standard's spelling of the apology the
fix-it asks for.

#listing("c-os-cloud/samples/src/Ch07/attributes.c", first: 72, last: 87, caption: [the values this front end reports, and the behaviors the checks pin])

#callout("note", "the reported attribute values are not the ones the normative text names", [
  Every attribute sub-section of n3220 6.7.13 carries the same
  sentence, here the nodiscard one: "The `__has_c_attribute`
  conditional inclusion expression (6.10.2) shall return the value
  202311L when given nodiscard as the pp-tokens operand if the
  implementation supports the attribute." The fifth edition
  harmonized all seven attributes onto 202311L. Clang 23.1.1 reports
  the historical spellings the informative annex M table records
  instead, 201904L through 202202L, one per attribute. The checks pin
  what this front end actually answers, and the divergence is the
  lesson: feature tests should compare against the values the
  compiler in front of you reports, and code that wants to ask "is
  this attribute supported" should test nonzero, not equality with
  202311L. The annex also lists `reproducible` and `unsequenced` at
  202207L, and `__has_c_attribute(unsequenced)` answers 0 on this
  compiler: unsupported.
])

== the clang driver stages, -\#\#\#

The driver is a program with its own architecture, documented on the
clang.llvm.org DriverInternals page as five conceptual stages: parse,
pipeline, bind, translate, execute. Parse turns the command line into
arg objects in which joined and split spellings, `-Ifoo` and `-I foo`,
map to the same option. Pipeline builds a tree of actions over the
phases, the "well known compilation steps, such as preprocess,
compile, assemble, link". Bind asks the toolchain which tool performs
each action. Translate turns gcc-style flags into the flags each
chosen tool actually speaks. Execute runs the result. The command
line reference pins the phase-stopping actions the same page names:
`-E` "only run the preprocessor", `-S` "only run preprocess and
compilation steps", `-c` "only run preprocess, compile, and assemble
steps".

`-###` prints the translated commands without running them, the
driver's own account of what it would do. Probed 2026-09-12 on this
box, `clang -### -std=c23 -O2 -c stages.c` answers with one line of
mode, a marker, then the cc1 invocation. The marker says the front end
runs in process:

` (in-process)`

` "clang.exe" "-cc1" "-triple" "x86_64-pc-windows-msvc19.33.0" "-O2" "-emit-obj" "-disable-free" "-clear-ast-before-backend" "-discard-value-names" "-main-file-name" "stages.c"`

The triple grows a version suffix, 19.33.0, the msvc release the
front end promises to be compatible with. `-O2` rides through
untouched, flag translation does not change what it means, only where
it lands. `-clear-ast-before-backend` frees the tree before codegen
starts, and `-discard-value-names` strips local names, which is why
optimized ir speaks in `%0` and `%1`. The middle of the line carries
the target's codegen defaults:

` "-mframe-pointer=none" "-relaxed-aliasing" "-fmath-errno" "-ffp-contract=on"`

Frame pointers are off by default on this target. `-relaxed-aliasing`
turns tbaa off to match msvc semantics, the fact chapter 5 chased
from the ir side and recorded as cos-004: no `!tbaa` on any load, and
no flag brings it back. Then the search paths, and here the transcript
explains a mystery chapter 1 left as a probed note:

` "-internal-isystem" "C:/Program Files/Microsoft Visual Studio 10.0/VC/include" "-internal-isystem" "C:/Program Files/Microsoft Visual Studio 9.0/VC/include"`

The line continues down through Visual Studio 9.0's PlatformSDK and
both of Visual Studio 8's directories. The driver's msvc
autodetection, running on a machine with Visual Studio 2022 and msvc
14.44 installed, injects include paths for Visual Studio 8, 9, and 10
and nothing else. That is the whole reason the gate passes explicit
`-isystem` and `-L` paths resolved by scanning the installed toolsets.
The tail of the line is the compatibility contract:

` "-std=c23" "-ferror-limit" "19" "-fno-use-cxa-atexit" "-fms-extensions" "-fms-compatibility" "-fwrapv" "-fms-compatibility-version=19.33"`

`-fwrapv` is the other chapter 5 fact: signed wrap defined by
toolchain contract, no `nsw` assumptions on arithmetic, visible here
as a flag nobody typed. And because `-O2` was asked for, the same
line ends with the middle end being wired in:

` "-vectorize-loops" "-vectorize-slp"`

The link stage appears when the output is an exe instead of an
object. The same probe with the gate's own flags appends a second
command to the transcript, and its shape is the chapter 1 link model
made visible:

` "lld-link" "-out:stages.exe" "-defaultlib:libcmt" "-defaultlib:oldnames"`

` "kernel32.lib" "synchronization.lib" "...Temp\stages-4f1a9c.o"`

`-fuse-ld=lld` plus the msvc target bound the link action to lld-link,
the static crt `libcmt` is the default library pair, the gate's
`-lkernel32 -lsynchronization` translated into `.lib` names, and the
object the front end produced sits in a temp file the driver itself
named with an embedded hash. Run the same `-###` without the gate's
explicit paths and the link line begins with the placeholder libpaths
`"lib\amd64"` and `"atlmfc\lib\amd64"`: the sdk scan found the
windows kits, the msvc scan found nothing, and the dead relative
paths are what the failure looks like from inside the transcript.

#flow(
  [the driver's five conceptual stages, and where -\#\#\# stops the story],
  node((0, 0), [parse: command line to args]),
  node((0, -1.7), [pipeline: one action per phase]),
  node((0, -3.4), [bind: the toolchain picks tools]),
  node((0, -5.1), [translate: gcc flags to tool flags]),
  node((0, -6.8), [execute: cc1 in process, #linebreak() lld-link as a child]),
  node((4.2, -5.1), [-\#\#\# prints, #linebreak() runs nothing]),
  edge((0, 0), (0, -1.7), "->"),
  edge((0, -1.7), (0, -3.4), "->"),
  edge((0, -3.4), (0, -5.1), "->"),
  edge((0, -5.1), (0, -6.8), "->"),
  edge((2.0, -5.1), (4.2, -5.1), "->"),
)

== passes and -Rpass remarks

The middle end is a sequence of passes over the ir, and the `-O` flag
selects the sequence. At `-O0` almost nothing runs, which is what
`__OPTIMIZE__` staying undefined recorded. At `-O2` the transcript
showed the driver wiring `-vectorize-loops` and `-vectorize-slp` into
cc1, and the inliner runs alongside them. In this build the passes
have no standalone runner on windows, there is no `opt` binary in the
distribution, so the pipeline always executes inside cc1 under
whatever `-O` the driver translated.

The pass manager can narrate itself. The users manual's optimization
report options state the deal: "optimization reports trace, at a
high-level, all the major decisions made by compiler transformations",
in three families, `-Rpass` "when the pass makes a transformation",
`-Rpass-missed` "when the pass fails to make a transformation", and
`-Rpass-analysis` "when the pass determines whether or not to make a
transformation". Each takes a regular expression naming the pass, and
`-Rpass=.*` asks every pass. Probed at `-O2` on a two function pair,
2026-09-12:

`remark: 'twice' inlined into 'scale' with (cost=-15030, threshold=337) at callsite scale:0:34; [-Rpass=inline]`

`remark: 'scale' inlined into 'reveal' with (cost=-15030, threshold=337) at callsite reveal:0:28; [-Rpass=inline]`

The remark names the callee, the caller, the callsite, and the
inliner's own accounting: cost against threshold, where a negative
cost means the decision was never in doubt. `-Rpass-missed=inline` on
the same file prints nothing, nothing was missed. The window opens
past the inliner too. On a loop shaped like chapter 5's restrict twin:

`remark: vectorized loop (vectorization width: 4, interleaved count: 2) [-Rpass=loop-vectorize]`

Width 4 is the `<4 x i32>` the chapter 5 ir analysis read out of the
same pipeline, the remark and the ir text describing one decision from
two sides.

The `[[noreturn]]` attribute from the first section is a middle end
input as much as a diagnostic fact, and the gate pins it. At `-O0` the
front end already emits the call to `bail` followed by `unreachable`,
no block after the call exists, and `Ch07/expect-ir.txt` asserts both
substrings, `call void @bail` and `unreachable`, at `-O0`. At `-O2`
the same file collapses: the only definitions left in the module are
`main`, `printf`, and the stdio options helper, every static helper
dissolved into its caller. And the roundtrip leg compiles `stages.c`
to `.ll` text and back to an exe with identical stdout, the pipeline's
own proof that the ir between its ends is a lossless staging point.
Chapter 8 reads that text line by line.

#diagram([the pass pipelines the -O flags select, and the remark families that report them], length: 13pt, {
  let layer(y, t, fill: luma(235)) = {
    cdraw.rect((0.8, y), (16.0, y + 1.1), fill: fill, radius: 0.02)
    cdraw.content((8.4, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  layer(7.0, [the -O flag selects the pipeline, the driver wires it into cc1], fill: luma(205))
  layer(5.6, [-O0: minimal pipeline, no \_\_OPTIMIZE\_\_ macro, the gate default])
  layer(4.2, [-O1: mem2reg, instcombine, simplify])
  layer(2.8, [-O2: plus inliner, vectorize-loops, vectorize-slp])
  layer(1.4, [the passes run in process inside cc1, no standalone opt here], fill: luma(205))
  cdraw.content((22.6, 7.5), [remark families, users manual:], wrap: text.with(size: 6pt))
  cdraw.content((22.6, 6.8), [-Rpass: made the change], wrap: text.with(size: 6pt))
  cdraw.content((22.6, 6.15), [-Rpass-missed: did not], wrap: text.with(size: 6pt))
  cdraw.content((22.6, 5.5), [-Rpass-analysis: says why], wrap: text.with(size: 6pt))
  cdraw.content((22.6, 4.2), [each takes a regex naming the pass,], wrap: text.with(size: 6pt))
  cdraw.content((22.6, 3.55), [dot star asks every pass], wrap: text.with(size: 6pt))
  cdraw.content((22.6, 2.4), [real remarks, probed 2026-09-12:], wrap: text.with(size: 6pt, fill: luma(110)))
  cdraw.content((22.6, 1.7), [twice inlined into scale,], wrap: text.with(size: 6pt))
  cdraw.content((22.6, 1.05), [cost -15030, threshold 337], wrap: text.with(size: 6pt))
  cdraw.content((22.6, 0.3), [loop vectorized, width 4, interleave 2], wrap: text.with(size: 6pt))
})

== the windows tool inventory

Chapter 1 listed which binaries the llvm 23.1.1 windows distribution
installs. The architecture view names the stage each one serves. The
clang family is the driver. clang-format, clang-tidy, and clang-query
are front end tools that never see ir: format works at the token
level, tidy and query at the ast, and chapter 10 drives all three.
llvm-objdump, llvm-nm, and llvm-ar read and bundle what the back end
wrote, disassembly, symbol table, archive, probed on this chapter's
own object: `llvm-nm` lists the check-name strings as mangled
constants and `llvm-ar` packs the object into an archive. lld-link is
the link stage. The absent tools are the standalone middle and back
end, and every one of them except the jit has a driver stand-in,
probed on this box. `clang -c -emit-llvm x.c -o x.bc` writes bitcode
whose first four bytes are 66, 67, 192, 222, the `BC` magic
llvm-as would produce. `clang -S -emit-llvm x.bc` turns that bitcode
back into text, llvm-dis's job. `clang x.ll -c` compiles ir text to an
object, llc's job, and the gate's roundtrip leg is built on exactly
that step. `lli` executes ir directly through a jit and has no stand
in: the driver only compiles. `llvm-config` reports build
configuration and has no stand in either, which is why the gate
resolves its own paths by scanning the installed toolsets instead of
asking.

#diagram([every tool in this llvm 23 windows distribution, mapped to the stage it serves], length: 13pt, {
  let row(y, label) = {
    cdraw.rect((0.4, y), (5.0, y + 1.0), fill: luma(205), radius: 0.02)
    cdraw.content((2.7, y + 0.5), label, wrap: text.with(size: 6pt))
  }
  let tool(x, y, name, present: true) = {
    if present {
      cdraw.rect((x, y), (x + 3.1, y + 1.0), fill: luma(235), radius: 0.02)
      cdraw.content((x + 1.55, y + 0.5), name, wrap: text.with(size: 6pt))
    } else {
      cdraw.rect((x, y), (x + 3.1, y + 0.9), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
      cdraw.content((x + 1.55, y + 0.45), name, wrap: text.with(size: 6pt, fill: luma(140)))
    }
  }
  row(8.2, [the driver])
  tool(5.6, 8.2, [clang]); tool(9.1, 8.2, [clang++]); tool(12.6, 8.2, [clang-cl])
  cdraw.content((18.6, 8.7), [one command plans and runs every stage], wrap: text.with(size: 6pt))
  row(6.9, [front end tools])
  tool(5.6, 6.9, [clang-format]); tool(9.1, 6.9, [clang-tidy]); tool(12.6, 6.9, [clang-query])
  cdraw.content((18.6, 7.4), [tokens and ast, chapter 10, no ir ever], wrap: text.with(size: 6pt))
  row(5.6, [the middle end])
  tool(5.6, 5.65, [opt], present: false)
  cdraw.content((10.4, 6.1), [passes run inside cc1 under -O], wrap: text.with(size: 6pt))
  row(4.3, [back end and ir])
  tool(5.6, 4.35, [llc], present: false); tool(9.1, 4.35, [llvm-as], present: false)
  tool(12.6, 4.35, [llvm-dis], present: false); tool(16.1, 4.35, [lli], present: false)
  cdraw.content((21.0, 4.9), [clang file.ll -c compiles ir,], wrap: text.with(size: 6pt))
  cdraw.content((21.0, 4.25), [-emit-llvm writes text or bitcode, lli has none], wrap: text.with(size: 6pt))
  row(3.0, [objects and archives])
  tool(5.6, 3.0, [llvm-objdump]); tool(9.1, 3.0, [llvm-nm]); tool(12.6, 3.0, [llvm-ar])
  cdraw.content((18.6, 3.5), [read and bundle what the back end wrote], wrap: text.with(size: 6pt))
  row(1.7, [link and config])
  tool(5.6, 1.7, [lld-link]); tool(9.1, 1.75, [llvm-config], present: false)
  cdraw.content((14.4, 2.2), [config has no stand-in,], wrap: text.with(size: 6pt))
  cdraw.content((14.4, 1.55), [the gate scans the toolsets itself], wrap: text.with(size: 6pt))
})

The pattern is the closing fact of the architecture: the windows
distribution ships the tools whose job is to face the user, driver,
diagnostics, linkers, inspectors, and withholds the ones whose job is
to be a stage inside the pipeline. On linux the same stages exist as
separate commands because the ecosystem wires them together by hand.
Here the driver is the only door, and every chapter of this book that
needs a middle end or a back end in isolation opens it with a flag
instead.

sources: llvm.org release index (23.1.1 announced 2026-09-08) and the
github llvm-project release tag llvmorg-23.1.1 at the same commit this
machine's clang reports, both accessed 2026-09-12;
clang.llvm.org DriverInternals (five driver stages, phases, tool
binding), ClangCommandLineReference (phase-stopping action flags),
UsersManual (optimization report options), and AttributeReference
(deprecated entry), accessed 2026-09-12; open-std.org n3220 6.7.13
attribute semantics and annex M table M.1, accessed 2026-09-12; the
`\#\#\#` transcripts, the `-Rpass` remark runs, the ir pins, the negative
diagnostic probes, and the tool inventory probed on this machine the
same day. Sample behavior verified by `make verify-c`, 21 checks in
chapter 7 of the samples suite.
