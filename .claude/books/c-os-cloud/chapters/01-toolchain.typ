#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= toolchain: clang 23 on windows

Every claim in this book compiles and runs before it is printed. This
chapter pins the toolchain that makes that sentence true: llvm/clang 23,
built under 23.1.1 (announced 2026-09-08) and drifted on this machine to
23.1.2 (announced 2026-09-22) with every gate green under both, because
the pinned asserts ask for the c23 standard version and the major 23
rather than a patch number. The one exception was chapter 8's ir
expectation, the only assertion carrying a literal patch number inside
the emitted ident metadata, and its first verify under 23.1.2 went red
and taught the rule it now follows, the ident pinned at the major. It
drives the msvc-compatible
toolchain that links against the Visual Studio 2022 libraries installed on
this machine. The gcc 15.2 mingw distribution sits next to it as a second
opinion, and every divergence between the two is a fact about the standard,
not a preference.

== the compiler and the target

The gate compiles every sample with `clang -std=c23 -Werror -Wall
-Wextra`, plus one opt-in: `-fdefer-ts`. That flag defines
`__STDC_DEFER_TS25755__` and enables the `defer` keyword from technical
specification 25755, which chapter 6 uses; probed on this machine it is
inert for every file that does not spell the word. The first check in
the first sample refuses to run on anything
else: `__STDC_VERSION__` must be 202311L, the value the C23 standard
assigns, or the book's own harness turns red:

#listing("c-os-cloud/samples/src/Ch01/hello.c", first: 1, last: 21, caption: [the check contract every sample carries, and the c23 version gate])

The `CHECK` macro is the whole testing convention of this book: a check
either prints `ok` and increments the counter or prints `FAIL` and
returns a nonzero exit code. The harness counts the `ok` lines, fails on
any nonzero exit, and the chapter's closing sources line quotes the
count. Nothing is tested by eyeball.

#diagram([the compile pipeline from source to exe, one box per stage the driver runs], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 4.4, 3.2, [hello.c])
  box(4.8, 4.4, 3.2, [clang driver])
  box(9.2, 4.4, 3.2, [cc1: parse, #linebreak() lower to ir])
  box(13.6, 4.4, 3.4, [backend: ir to #linebreak() machine code])
  box(17.9, 4.4, 3.2, [lld-link])
  box(21.9, 4.4, 2.8, [hello.exe])
  cdraw.line((3.6, 4.9), (4.8, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.0, 4.9), (9.2, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.4, 4.9), (13.6, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.0, 4.9), (17.9, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((21.1, 4.9), (21.9, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.5, 3.3), [-std=c23 -Werror -Wall -Wextra ride every box from left to right], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((12.5, 2.4), [the target triple is x86_64-pc-windows-msvc, asserted by the next listing], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

The ir the diagram names is llvm's intermediate representation, a
low-level typed code format every stage past the front end speaks, from
optimization through code generation. Chapter 8 reads it line by line.

== the link model

A C file never becomes an executable alone. The driver folds in the C
runtime startup, the ucrt from the Windows SDK, and the import libraries
for every win32 api the sample touches. The second sample asserts the
environment the linker resolved against:

#listing("c-os-cloud/samples/src/Ch01/target.c", first: 17, last: 23, caption: [target macros: windows, clang 23 major, hosted, 64 bit pointers])

`_WIN32` comes from the platform, `__clang_major__` from the compiler,
`__STDC_HOSTED__` from the standard's freestanding versus hosted
distinction, and the pointer width from the target triple. Four checks,
four different sources of truth, one binary.

#callout("note", "why the gate names kernel32 and synchronization", [
  Clang's msvc-target link step finds the crt and default libraries by
  scanning the installed Visual Studio toolsets, because its registry
  auto-detection fails on this machine (probed 2026-09-12: it only ever
  looked at Visual Studio 8, 9, and 10 paths). Windows api sets are not
  default link inputs: `WaitOnAddress` lives in the synchronization
  apiset, so the harness passes `-lkernel32 -lsynchronization`
  explicitly. Chapters show plain calls; the gate owns the plumbing.
])

#diagram([the link stack, what each layer contributes to the exe], length: 13pt, {
  let layer(y, t, fill: luma(235)) = {
    cdraw.rect((1.0, y), (15.6, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((8.3, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  layer(6.8, [your code: one translation unit per .c file], fill: luma(205))
  layer(5.5, [crt startup and libcmt: argv to main to exit])
  layer(4.2, [ucrt: stdio, malloc, threads.h, strtol family])
  layer(2.9, [win32 import libs: kernel32, user32, synchronization])
  layer(1.6, [lld-link writes the pe: sections, imports, entry point], fill: luma(205))
  cdraw.content((8.3, 0.6), [the exe is all five layers frozen into one file], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((18.2, 4.7), [each layer is a separate library, #linebreak() resolved when lld-link runs], wrap: text.with(size: 6pt))
})

The pe the bottom layer names is the portable executable, the windows
exe format, the file every layer above freezes into.

== the verify gate

`make verify-c` runs the harness in `tools/run-c-samples.ps1`. It
resolves the toolchain, then walks every chapter's samples through six
legs: compile, run and count checks, clang-format dry run, ir substring
assertions, an ll round trip, and an address-sanitizer pass over the
chapters whose samples own raw memory. Any leg failing turns the target
red, and `make verify` fails with it.

#callout("verify", "the gate was written test first", [
  The first version of the chapter 1 sample asserted `__STDC_VERSION__ ==
  199901L`, the c99 value. The harness compiled it, ran it, watched the
  CHECK fail, and turned red. The fix to `202311L` turned it green. That
  red-then-green pair is the evidence the harness actually reports
  failures rather than rubber-stamping output.
])

#flow(
  [one sample through the six legs of the verify gate],
  node((0, 0), [discover .c files]),
  node((-2.4, -1.8), [compile: #linebreak() -std=c23 -Werror]),
  node((0, -1.8), [run: exit 0, #linebreak() count ok lines]),
  node((2.4, -1.8), [format: #linebreak() clang-format dry run]),
  node((-2.4, -3.6), [ir: substrings #linebreak() in emitted .ll]),
  node((0, -3.6), [roundtrip: .c to .ll #linebreak() to exe, same stdout]),
  node((2.4, -3.6), [asan: chosen samples, #linebreak() staged dll]),
  node((0, -5.4), [green: N files, M checks, #linebreak() K ir assertions]),
  edge((0, 0), (-2.4, -1.8), "->"),
  edge((0, 0), (0, -1.8), "->"),
  edge((0, 0), (2.4, -1.8), "->"),
  edge((-2.4, -1.8), (-2.4, -3.6), "->"),
  edge((0, -1.8), (0, -3.6), "->"),
  edge((2.4, -1.8), (2.4, -3.6), "->"),
  edge((-2.4, -3.6), (0, -5.4), "->"),
  edge((0, -3.6), (0, -5.4), "->"),
  edge((2.4, -3.6), (0, -5.4), "->"),
)

== what the windows release omits

The llvm project's windows distribution is a subset of the toolset. This
machine's install ships the clang compiler family, clang-format,
clang-tidy, clang-query, llvm-objdump, and the lld linkers, and ships no
`opt`, `llc`, `llvm-as`, `llvm-dis`, `lli`, or `llvm-config`. The
optimizer chapters lose nothing by this: `clang -S -emit-llvm` writes
the ir text, the same driver compiles `.ll` back to objects at any `-O`
level, and `llvm-objdump -d` disassembles the result. Where the missing
tools would appear in a linux walkthrough, the chapters name them and
route through the driver instead.

#diagram([the llvm 23 windows bin directory, present versus absent, and the detour each absent tool takes], length: 13pt, {
  let present = ("clang", "clang++", "clang-cl", "clang-format", "clang-tidy", "clang-query", "llvm-objdump", "lld-link", "llvm-ar", "llvm-nm")
  for (i, name) in present.enumerate() {
    let x = 0.6 + calc.rem(i, 5) * 3.4
    let y = 5.8 - calc.floor(i / 5) * 1.1
    cdraw.rect((x, y), (x + 3.1, y + 0.9), fill: luma(215), radius: 0.02)
    cdraw.content((x + 1.55, y + 0.45), name, wrap: text.with(size: 6pt))
  }
  let absent = ("opt", "llc", "llvm-as", "llvm-dis", "lli", "llvm-config")
  for (i, name) in absent.enumerate() {
    let x = 0.6 + calc.rem(i, 3) * 3.4
    let y = 3.0 - calc.floor(i / 3) * 1.1
    cdraw.rect((x, y), (x + 3.1, y + 0.9), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
    cdraw.content((x + 1.55, y + 0.45), name, wrap: text.with(size: 6pt, fill: luma(140)))
  }
  cdraw.content((11.2, 5.9), [present, used directly], wrap: text.with(size: 6.5pt))
  cdraw.content((11.2, 3.3), [absent on windows, #linebreak() routed through the clang driver], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.line((10.9, 2.4), (13.4, 1.1), stroke: luma(140), mark: (end: ">"))
  cdraw.content((16.2, 0.7), [clang -S -emit-llvm stands in for llvm-as, #linebreak() clang file.ll stands in for llc + lld], wrap: text.with(size: 6.5pt))
})

sources: llvm.org release index (23.1.1 announced 2026-09-08, the
23.1.2 patch announced 2026-09-22, re-checked 2026-09-27) and
clang.llvm.org Users Manual (language support list, command line
options), accessed 2026-09-12; toolset presence and link behavior probed
on this machine the same day. Sample behavior verified by `make
verify-c`, 6 checks in chapter 1 of the samples suite.
