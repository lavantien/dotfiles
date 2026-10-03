#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= clang tooling and diagnostics

Chapter 1 built a gate and this chapter opens the toolbox it stands
on: the compiler's own diagnostic machinery, the format leg,
`clang-tidy`, the static analyzer, and the two windows into the ast
that explain what all of these tools are actually looking at. Every
transcript quoted below is real output from the llvm 23.1.1 binaries
installed at `C:\Program Files\LLVM\bin`, probed on 2026-09-12; paths
are shortened to file names and ast node addresses are elided, nothing
else is retyped. Three samples carry the chapter: `diagnostics.c`
compiles warning clean while carrying diagnostic surfaces on purpose,
`ast.c` and `tidy.c` are the small subjects the ast and tidy tools are
run against.

The gate's floor is unchanged since chapter 1: every sample compiles
with `-std=c23 -Werror -Wall -Wextra`. That floor is the reason this
chapter's discipline section exists. A toolchain that silently accepts
nearly-correct code teaches nothing; one that turns every warning into
a stopped build forces the cause to be fixed while it is still cheap.

== diagnostics and -Werror discipline

The users manual states the control surface compactly: `-Werror`
"turn warnings into errors", `-Werror=foo` turns one named group,
`-Wno-error=foo` turns that group back into a warning even under
`-Werror`, and `-w` disables all warnings while "errors are still
emitted". The diagnostics reference lists every `-W` group
alphabetically with its default status, including the downgrade
sentence for default errors: "this diagnostic is an error by default,
but the flag" `-Wno-...` "can be used to disable the error". The
manual also documents `-Weverything` and then argues against it,
`-Wall` and `-Wextra` "are a better choice for most projects". The
gate took exactly that advice. Errors stop the build, warnings under
this floor stop it too, and remarks never stop anything: the manual
reserves `-Rpass`, `-Rpass-missed`, and `-Rpass-analysis` for
optimizer commentary, each "a regular expression that identifies the
name of the pass which should emit the associated diagnostic".

#flow(
  [the diagnostic taxonomy and the fix discipline under the gate],
  node((0, 0), [the compiler prints a diagnostic]),
  node((-2.4, -2.0), [error: #linebreak() compilation stops]),
  node((0, -2.0), [warning: #linebreak() compile continues]),
  node((2.4, -2.0), [remark: #linebreak() opt-in -Rpass notes]),
  node((0, -4.1), [under the gate floor, #linebreak() -Werror promotes it, exit 1]),
  node((-2.4, -6.2), [fix the cause: #linebreak() the source changes]),
  node((2.4, -6.2), [rejected: casts, #linebreak() (void)x, -w, muting]),
  edge((0, 0), (-2.4, -2.0), "->"),
  edge((0, 0), (0, -2.0), "->"),
  edge((0, 0), (2.4, -2.0), "->"),
  edge((0, -2.0), (0, -4.1), "->"),
  edge((0, -4.1), (-2.4, -6.2), "->"),
  edge((0, -4.1), (2.4, -6.2), "->"),
)

The first sample carries its diagnostic surfaces deliberately, and all
of them stay silent on this toolchain:

#listing("c-os-cloud/samples/src/Ch10/diagnostics.c", first: 9, last: 15, caption: [the floor guard and the guarded warning, both silent on this toolchain])

The `#error` directive is the program refusing to compile below the
c23 floor. Probed with `-std=c17`, the guard fires:
`diagnostics.c:10:2: error: "this sample requires c23, __STDC_VERSION__ >= 202311L"`,
one error generated, nothing else in the pipeline runs. The `#warning`
behind its guard macro is the same machinery at the softer severity:
compiled with `-DTOOLING_DEMO_WARNING` the file prints
`diagnostics.c:14:2: warning: "a warning class diagnostic, deliberately behind this guard" [-W#warnings]`
and the compile succeeds. Add `-Werror` and the same line comes back
as an error whose group list now carries the promotion,
`[-Werror,-W#warnings]`, exit 1. Warning, error, and promoted warning,
one file, three probes.

The third surface is the standard's own compile-time check, each
assert paired with a runtime twin:

#listing("c-os-cloud/samples/src/Ch10/diagnostics.c", first: 33, last: 40, caption: [compile time asserts, and the attribute that answers the unused parameter warning])

#listing("c-os-cloud/samples/src/Ch10/diagnostics.c", first: 43, last: 46, caption: [the runtime twins, one check per compile time fact])

`_Static_assert` is a diagnostic that fires before anything runs: if
the claim is false the translation fails, if it is true the assert
costs nothing and proves only what the compiler can see. The twins in
`main` restate the same facts where the gate's run leg can count them,
four checks the harness verifies by execution. Compile-time and
runtime evidence for the same proposition, the pairing this book uses
everywhere a fact is checkable from both sides.

The last function in that listing is the discipline itself.
`-Wunused-parameter` comes with `-Wextra`, so the gate enables it.
Probed on a scratch twin that drops the attribute, the compile prints
`noattr.c:1:19: warning: unused parameter 'reserve' [-Wunused-parameter]`,
and under the floor the same diagnostic returns as
`[-Werror,-Wunused-parameter]` and stops the build. The c23
`[[maybe_unused]]` answers by declaring the intent in place: the
parameter is a reserved part of the interface, present for the
signature, unused by the body, and the declaration says so where a
reader finds it. The older answers, a `(void)reserve;` statement to
consume the name or a flag muting the whole group, remove the message
and keep the cause. The users manual documents the last resort,
`#pragma clang diagnostic push`, an `ignored` line, and `pop`, which
scopes any suppression to exact lines and restores the floor after;
this book never needed it, because every warning it met had a fix at
the source.

#callout("pitfall", "a silenced warning is a loan, not a fix", [
  `-w` in the project flags, `-Wno-foo` at the edge of the command
  line, the `(void)x` cast, the dummy use assignment: each removes
  the message and keeps the cause, and the interest comes due at the
  next compiler release or the next reader. The attribute and the
  scoped pragma at least state the intent where the code lives. The
  gate itself was proven to go red before it was trusted, chapter 1
  asserted the wrong `__STDC_VERSION__` value first and watched the
  harness fail the run. A tool that cannot go red is a rubber stamp,
  and a warning silenced before it is read never even gets the
  chance.
])

== clang-format as a gate leg

The format leg of the gate runs
`clang-format --dry-run --Werror --style=file`
over every `.c` and `.h` under the samples tree. The
style contract is one line, `.clang-format` at the samples root
reading `BasedOnStyle: LLVM`. The format page defines what that means:
`'file'` loads "style configuration from a .clang-format file in one
of the parent directories of the source file", so every chapter's
files walk up and find the same one-line config, and the fallback
style never engages. `--dry-run` means "if set, do not actually make
the formatting changes", and `--Werror` means "if set, changes
formatting warnings to errors": the format leg is the `-Werror`
story a second time, told over whitespace.

#diagram([the format leg: one canonical shape, two exits], length: 13pt, {
  let box(x, w, l1, l2) = {
    cdraw.rect((x, 5.1), (x + w, 6.9), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.4), l1, wrap: text.with(size: 6pt))
    cdraw.content((x + w / 2, 5.75), l2, wrap: text.with(size: 6pt))
  }
  box(0.5, 4.6, [author edit], [any shape that parses])
  box(5.7, 4.8, [clang-format -i], [rewrites the file in place])
  box(11.1, 5.8, [canonical shape], [the llvm style, one config line])
  box(17.4, 5.4, [gate: dry run, Werror], [compare, never write])
  cdraw.line((5.1, 6.0), (5.7, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.5, 6.0), (11.1, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.9, 6.0), (17.4, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.1, 5.1), (8.5, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.1, 5.1), (17.5, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.0, 1.9), (12.0, 3.7), fill: luma(235), radius: 0.02)
  cdraw.content((8.5, 3.2), [green: exit 0], wrap: text.with(size: 6pt, fill: rgb("#006400")))
  cdraw.content((8.5, 2.55), [nothing to report], wrap: text.with(size: 6pt, fill: rgb("#006400")))
  cdraw.rect((13.6, 1.9), (21.4, 3.7), fill: luma(235), radius: 0.02)
  cdraw.content((17.5, 3.2), [red: exit 1], wrap: text.with(size: 6pt, fill: rgb("#8B0000")))
  cdraw.content((17.5, 2.55), [one error per column], wrap: text.with(size: 6pt, fill: rgb("#8B0000")))
  cdraw.content((11.0, 0.9), [when the leg goes red, the fix is the same -i run that wrote the canonical shape], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.0, 0.25), [style=file walks up from each source file and finds the one line config at the samples root], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "the format leg reports drift, probed red", [
  A drift copy written in a temp directory beside the same
  `.clang-format`, one dense `main` line, three statements collapsed
  onto it: the leg returned
  `drift.c:3:17: error: code should be clang-formatted [-Wclang-format-violations]`,
  repeated once per offending column, fourteen for that line, exit 1.
  Running
  `clang-format -i` on the same file rewrote it into the canonical
  shape, and the identical dry-run invocation then exited 0 with no
  output. Red first, then green, the same evidence shape chapter 1
  demanded from the run leg. The shipped files pass because they were
  formatted with the same command before the gate ran: this
  chapter's gate line ends `format clean`.
])

The reason the leg exists is review friction. A diff that is half
whitespace buries the half that matters, and a tree without a
canonical shape pays that tax on every file forever. This book has a
second reason: every listing pins a real file by exact line range, so
whitespace churn is not cosmetic here, reformatting a sample file
silently moves every pin below the change. The format leg freezes the
shape the pins were measured against.

== clang-tidy and the static analyzer

`clang-tidy` is documented as "a clang-based C++ 'linter' tool", an
"extensible framework for diagnosing and fixing typical programming
errors", with checks selected by "a comma-separated list of positive
and negative (prefixed with -) globs" and, for a single file,
compilation options given "on the command line after" `--`. On this
box the tool needs the same `-isystem` plumbing chapter 1 documented:
run bare, tidy's internal compile dies on
`tidy.c:6:10: error: 'stdio.h' file not found [clang-diagnostic-error]`,
the msvc auto-detection failure applies to it as well, probed
2026-09-12. The subject file carries two shapes on purpose:

#listing("c-os-cloud/samples/src/Ch10/tidy.c", first: 21, last: 25, caption: [the flagged macro, parentheses missing inside and out])

#listing("c-os-cloud/samples/src/Ch10/tidy.c", first: 43, last: 56, caption: [wrong expansion and narrowing pinned at runtime, plus the clean scan's checks])

The run is `clang-tidy --checks="-*,bugprone-*" tidy.c -- -std=c23`
plus the harness include paths, and it prints two findings.
`tidy.c:25:19: warning: macro replacement list should be enclosed in parentheses [bugprone-macro-parentheses]`,
with a fix-it that draws the parentheses in under the caret. And
`tidy.c:49:16: warning: narrowing conversion from 'long long' to signed type 'int' is implementation-defined [bugprone-narrowing-conversions]`.
The trailer counts the rest: "55 warnings generated. Suppressed 53
warnings (53 in non-user code)", tidy read the system headers too and
suppressed them by default, `-header-filter=` decides what counts as
user code. The plain two dimensional scan `grid_find` in the same
file draws nothing.

Both findings name real contracts. The macro check "finds macros that
can have unexpected behavior due to missing parentheses" and
implements the CERT rule PRE02-C, and the runtime check right below
the definition pins what the missing parentheses do: `HALF(8)` is 4
for a single token, `HALF(6 + 2)` expands to `6 + 2 / 2` and computes
7, not 4. The narrowing check "checks for silent narrowing
conversions" and "diagnoses more instances of narrowing than the
compiler warning" `-Wconversion` "does", which matters here because
the gate floor enables neither: the compiler passed this line in
silence. The conversion itself is the out-of-range one: C23 made
two's complement the only allowed signed representation, so the
encoding is not in play, what the standard leaves open is converting
a value the signed type cannot hold, which yields an
implementation-defined result or raises an implementation-defined
signal, this compiler defines the result as wrapping, and the check
pins it: 5000000000 stored into an `int` reads back 705032704,
the low 32 bits.

Findings do not stop tidy. The run above exits 0, because tidy
warnings are advisory until promoted: rerun with
`--warnings-as-errors="bugprone-*"` and the output ends "2 warnings
treated as errors", exit 1. The documentation states the boundary
exactly, the option "upgrades any warnings emitted under the
`-checks=` flag to errors (but it does not enable any checks
itself)", the same promotion shape `-Werror` gives the compiler.

The static analyzer is a different oracle, not a stricter tidy.
`clang --analyze` on the shipped file prints nothing and exits 0, no
construct in `tidy.c` is a path bug. A probe file written to have one
makes the difference visible: a choose function `pick(a, b, which)`
whose null guard tests `a` while the deref goes through `chosen`,
which is `b` whenever `which` is not 0. The engine walks the branches
and prints
`pathbug.c:5:10: warning: Dereference of null pointer (loaded from variable 'chosen') [core.NullDereference]`.
The guard is true of the wrong pointer; on the path where `a` is
live, `which` is 1, and the call passed 0 for `b`, the dereference is
provably null.
No code ran: the analyzer judged paths through the ast, where tidy
judged one construct at a time. tidy reaches the same engine through
its `clang-analyzer-` module, "Clang Static Analyzer checks" in the
checks list, and the analyzer's findings are warnings here too, the
probe exited 0.

#diagram([four oracles over the same three files, what each reads and what each found], length: 13pt, {
  let x0 = (0.6, 5.4, 10.4, 15.2)
  let ww = (4.6, 4.8, 4.6, 7.2)
  let cell(xi, y, t, hdr: false) = {
    cdraw.rect((x0.at(xi), y), (x0.at(xi) + ww.at(xi), y + 0.9),
               fill: if hdr { luma(205) } else { luma(238) }, radius: 0.02)
    cdraw.content((x0.at(xi) + ww.at(xi) / 2, y + 0.45), t, wrap: text.with(size: 6pt))
  }
  for (xi, t) in ("oracle", "what it reads", "when it runs", "verdict on this chapter's files").enumerate() {
    cell(xi, 6.8, t, hdr: true)
  }
  let row(y, t0, t1, t2, t3) = { cell(0, y, t0); cell(1, y, t1); cell(2, y, t2); cell(3, y, t3) }
  row(5.7, [clang warnings], [parse and sema], [every compile], [clean, the -Werror floor])
  row(4.6, [clang-format], [tokens only], [the format leg], [clean, exit 0])
  row(3.5, [clang-tidy], [ast constructs], [on demand], [2 findings, exit 0])
  row(2.4, [the analyzer], [ast paths], [on demand], [silent here, 1 on the probe])
  cdraw.content((11.5, 1.4), [the analyzer explores branches, the other three judge constructs], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.5, 0.8), [all four are silent below the run leg: a wrong value fails the gate even when every tool agrees], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("note", "the finding the check did not print", [
  The macro check fires on `x / 2` but stayed silent on sibling
  shapes probed the same day: bodies built from `x * x` and
  `x * x * x` drew no finding, while `x + y`, `-x`, `x / 2`, and
  `x + x` all did. A body of `x * x` still computes the wrong value
  for a sum argument, `SQUARE(1 + 2)` expands to 5 against the
  intended 25, probed and run. Every static oracle has a scope. The
  run leg is the bottom of the ladder: `HALF(6 + 2)` is pinned at 7
  by a check the gate counts, whether or not any static tool looks.
])

== clang-query and -ast-dump

`clang -Xclang -ast-dump -fsyntax-only -std=c23 ast.c` prints the
front end's own tree for the whole file, and
`-Xclang -ast-dump-filter=add_pair` narrows the dump to one
declaration, prefixed `Dumping add_pair:`. With node addresses
elided, the subject function is nine lines:

#listing("c-os-cloud/samples/src/Ch10/ast.c", first: 19, last: 30, caption: [the dump subject and the loop subject, names chosen for matchers])

The root is a `FunctionDecl` node carrying everything the compiler
knows at declaration time: the source range `<line:21:1, col:51>`,
the column of the name,
`used add_pair 'int (int, int)' static internal-linkage`,
one line that answers name, type, storage, and
linkage. Two `ParmVarDecl` children bind `a` and `b`, each marked
`used`. The body is a `CompoundStmt` holding one `ReturnStmt`, whose
operand is a `BinaryOperator ... 'int' '+'`. The operands are not the
names: each one is an `ImplicitCastExpr ... <LValueToRValue>`
wrapping a `DeclRefExpr ... lvalue ParmVar ... 'a' 'int'` that
points back to the parameter's own node. Reading a value off a name
is a cast in this tree, written by the compiler, invisible in the
source. Nothing was computed to produce any of it, the dump is
pure structure, which is why the optimizer chapters can reason from
the same nodes the checker tools read.

#diagram([the dumped tree of the subject function, one box per node, the front end's own view], length: 13pt, {
  cdraw.rect((7.2, 7.0), (16.8, 8.8), fill: luma(205), radius: 0.02)
  cdraw.content((12.0, 8.3), [FunctionDecl add\_pair], wrap: text.with(size: 6pt))
  cdraw.content((12.0, 7.65), ['int (int, int)', static], wrap: text.with(size: 6pt))
  let nb(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: luma(238), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, wrap: text.with(size: 6pt))
  }
  nb(3.3, 5.7, 3.4, [ParmVarDecl a])
  nb(8.2, 5.7, 3.4, [ParmVarDecl b])
  nb(14.9, 5.7, 3.8, [CompoundStmt])
  nb(14.9, 4.4, 3.8, [ReturnStmt])
  nb(14.7, 3.1, 4.2, [BinaryOperator +])
  nb(9.6, 1.8, 4.8, [ImplicitCastExpr])
  nb(18.4, 1.8, 4.8, [ImplicitCastExpr])
  nb(9.8, 0.5, 4.4, [DeclRefExpr a])
  nb(18.6, 0.5, 4.4, [DeclRefExpr b])
  cdraw.line((12.0, 7.0), (5.0, 6.6), stroke: luma(100))
  cdraw.line((12.0, 7.0), (9.9, 6.6), stroke: luma(100))
  cdraw.line((12.0, 7.0), (16.8, 6.6), stroke: luma(100))
  cdraw.line((16.8, 5.7), (16.8, 5.3), stroke: luma(100))
  cdraw.line((16.8, 4.4), (16.8, 4.0), stroke: luma(100))
  cdraw.line((16.8, 3.1), (12.0, 2.7), stroke: luma(100))
  cdraw.line((16.8, 3.1), (20.8, 2.7), stroke: luma(100))
  cdraw.line((12.0, 1.8), (12.0, 1.4), stroke: luma(100))
  cdraw.line((20.8, 1.8), (20.8, 1.4), stroke: luma(100))
  cdraw.content((11.9, -0.3), [the body of add\_pair as the front end sees it, nothing computed], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.9, -0.85), [both casts are LValueToRValue, the conversion from name to read value], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

`clang-query` drives the same tree with the matcher language.
LibASTMatchers provides "a domain specific language to create
predicates on" the ast, "matchers are generated by nesting calls to
matcher creation functions", and matchers given several inner
conditions combine under an implicit allOf. The query tool itself has
no manual page in this release's documentation set, checked in the
docs and extra indexes on 2026-09-12; its `--help` is the usage
surface: `-c` to "specify command to run", `-p` to read a compile
command database, and otherwise the same flags-after-`--` convention
tidy uses. Four real queries on the shipped file:

#listing("c-os-cloud/samples/src/Ch10/ast.c", first: 32, last: 49, caption: [the record type, the field selector, and the runtime checks])

`match functionDecl(hasName("add_pair"))` returns `1 match.`, a note
binding "root" at `ast.c:21:1` with the caret under the whole
definition.
`match callExpr(callee(functionDecl(hasName("add_pair"))))` returns
`2 matches.`, one at `ast.c:28:13` inside the loop body, one at
`ast.c:44:9` inside this book's own `CHECK` macro, where the binding
note adds `expanded from macro 'CHECK'`: the tree sees through the
macro to the call inside. `match recordDecl(hasName("point"))` binds
the whole struct, carets under every line from the `struct` keyword
to the brace. `match forStmt()` finds the loop at `ast.c:27:3`, and
composing the other way, `forStmt(hasDescendant(callExpr()))` asks
whether a loop makes a call at all and returns `1 match.` for the
same node. Each matcher is a reusable probe over any file that
parses, and the composition is the same language clang-tidy checks
are written in: the custom check feature documents that its checks
are "based on" the query syntax, whose essence "is to parse the query
string and dynamically generate the corresponding AST matcher".

The chapter closes where the gate began. The compile leg enforces
the diagnostic floor, the format leg freezes the shape, tidy and the
analyzer read the same tree from two altitudes, and beneath all four
the run leg counts executed checks. In this chapter's three files
that ladder bottoms out at 13 checks, every one of them green in the
gate run this chapter quotes.

sources: clang.llvm.org diagnostics reference and users manual (the
`-Werror` family, `-w`, `-Weverything` with the `-Wall` `-Wextra`
advice, `-Rpass` remarks, diagnostic pragmas), ClangFormat (the
`-style=file` lookup, `--dry-run`, `--Werror`), the clang-tidy main
page and the bugprone macro-parentheses and narrowing-conversions
check pages at their clang.llvm.org/extra home (checks globs,
`--warnings-as-errors`, flags after `--`), LibASTMatchers, and the
query based custom checks page, all accessed 2026-09-12; clang-query
usage from the tool's `--help` output, probed on this machine the
same day; every quoted diagnostic, transcript, and silent run is real
output from the llvm 23.1.1 binaries on this box, probes dated
2026-09-12. Sample behavior verified by `make verify-c`, 13 checks in
chapter 10 of the samples suite.
