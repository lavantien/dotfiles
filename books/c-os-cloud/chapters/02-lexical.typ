#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= lexical structure and the preprocessor

Before any types or pointers exist, the standard already has opinions. C
defines eight translation phases that carry source bytes to a linked
program, a preprocessor with three new directives and probes in C23, an
`#embed` that reads binary resources at translation time, and a lexer
rule that decides how `a+++b` splits before the parser ever runs. Every
fact in this chapter is pinned by a check in one of the four samples, or
by a diagnostic captured on this machine with llvm/clang 23.1.1 and its
installed second opinion, gcc 15.2.

== translation phases

The standard's phase list (n3220, 5.1.1.2) is conceptual: an
implementation must behave as if the phases run in order, even though a
real compiler folds them together. The order is still load bearing,
because each phase observes the output of the one before it. Phase 7 is
where the translation unit is born: one source file plus everything its
includes bring, parsed as one whole. Later chapters say TU for exactly
that. The sample asserts six of those boundaries from inside one binary:

#listing("c-os-cloud/samples/src/Ch02/phases.c", first: 18, last: 25, caption: [phase 2 statics: a string and an identifier each cut by one splice])

The string on line 20 ends with a backslash, so phase 2 deletes the
backslash and the newline and glues the two physical lines into one
logical line. The literal is `"abcd"`, length 4, one token. The
identifier `spliced_ident` is spelled across the same kind of splice on
lines 24 and 25, and the check on it later compiles against the joined
name. Phase 1 in C23 no longer replaces trigraphs: the C17 grammar
mapped `??/` to a backslash in any context, C23 dropped that step, and
n3220's phase 1 text reads charset mapping only.

#listing("c-os-cloud/samples/src/Ch02/phases.c", first: 29, last: 62, caption: [one check per phase boundary, from trigraph absence to library resolution])

The first check holds only because trigraphs are gone: `strlen("??/n")`
is 4, and under clang's opt-in `-trigraphs` flag in C17 mode the same
string collapses to 1 with the warning `trigraph converted to '\'`
(probed 2026-09-12). The third boundary is the subtle one: the `//`
comment on line 45 ends with a backslash, so phase 2 splices first and
the entire `!!! $$$$ @@@@` line becomes part of the comment before
phase 3 deletes comments. The compile itself is the proof, and the two
`#pragma clang diagnostic` pairs silence exactly the two warnings clang
raises for these spellings: `-Wtrigraphs` and `-Wcomment`. Phases 5 and 6
close the token story, `'\x41'` becomes `'A'` in the execution
character set and `"one" "two"` concatenates to `"onetwo"`, and phase 8
is why `printf` links at all.

#callout("note", "the phases carry their own undefined behavior", [
  Three phase boundaries are undefined behavior, not diagnostics: a
  non-empty file that does not end in a newline after splicing (phase
  2), a file ending in a partial preprocessing token or partial comment
  (phase 3), and token pasting with `##` that produces a universal
  character name (phase 4). All three come from n3220 5.1.1.2. The
  samples end in newlines and paste no such tokens, so none of these
  fire here. Undefined behavior is also one of the standard's three
  contract classes: undefined, where all bets are off,
  implementation-defined, where each implementation documents its
  choice, and unspecified, where the implementation picks among allowed
  options without documenting which. Chapter 5 owns the full contract,
  this chapter only needs the names.
])

#diagram([the eight translation phases, what each one does, and where the preprocessor ends], length: 13pt, {
  let box(x, t) = {
    cdraw.rect((x, 4.6), (x + 2.6, 6.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.3, 5.4), t, wrap: text.with(size: 6pt))
  }
  let pitch = 3.05
  box(0.4, [1 #linebreak() charset])
  box(0.4 + pitch, [2 #linebreak() splices])
  box(0.4 + 2 * pitch, [3 #linebreak() tokens])
  box(0.4 + 3 * pitch, [4 #linebreak() macros])
  box(0.4 + 4 * pitch, [5 #linebreak() escapes])
  box(0.4 + 5 * pitch, [6 #linebreak() concat])
  box(0.4 + 6 * pitch, [7 #linebreak() parse])
  box(0.4 + 7 * pitch, [8 #linebreak() link])
  for i in range(7) {
    let x0 = 0.4 + i * pitch + 2.6
    cdraw.line((x0, 5.4), (x0 + 0.45, 5.4), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((12.2, 3.5), [phases 1 to 4 are the preprocessor, `#include` re-enters at phase 1], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((12.2, 2.4), [comments are gone by phase 3, each becomes one space], wrap: text.with(size: 6.5pt))
  cdraw.content((12.2, 1.3), [c23 removed the trigraph replacement from phase 1], wrap: text.with(size: 6.5pt))
  cdraw.content((12.2, 0.2), [a missing final newline after phase 2 is undefined behavior], wrap: text.with(size: 6.5pt))
})

== elifdef and has_include

C23 added two conditional directives and standardized three probes:
`#elifdef` and `#elifndef` (clang implements N2645 and backports both
to C89 modes), `__has_include` (an extension clang shipped for years,
now standard), `__has_c_attribute`, and `__has_embed`. The chain in the
sample is compiled twice with one macro difference between the passes:

#listing("c-os-cloud/samples/src/Ch02/conditionals.c", first: 17, last: 45, caption: [the same chain twice, once with GATE defined and once after `#undef` GATE])

`first_chain` returns 1: `GATE` is defined at line 18, so `#ifdef`
takes the first block and every later directive in the chain is never
evaluated. After the `#undef` on line 34 the identical chain returns 3:
`#ifdef GATE` fails, `#elifdef OTHER` fails because `OTHER` was never
defined, and `#elifndef THIRD` fires precisely because `THIRD` is not
defined. One directive per not-defined case is the whole reason
`#elifndef` exists, replacing the older `#elif !defined(THIRD)`.

#listing("c-os-cloud/samples/src/Ch02/conditionals.c", first: 47, last: 92, caption: [`has_include`, `has_c_attribute`, and `has_embed` routed through directives into macros])

The `__has_include` probes cannot live in ordinary expressions: clang
rejects them outside a directive with `'__has_include' must be used
within a preprocessing directive` (captured 2026-09-12 while writing
this chapter), so each result flows through an `#if` into a macro and
the checks read the macros. `__has_include` evaluates to 1 or 0 for the
angle and quoted forms alike. `__has_c_attribute` answers with the
year-month the attribute was adopted into the standard: 201904 for
`deprecated`, 202003 for `nodiscard`, and 0 for a name the
implementation does not know. `__has_embed` reports the state of a
resource with `__STDC_EMBED_FOUND__`, `__STDC_EMBED_EMPTY__`, and
`__STDC_EMBED_NOT_FOUND__`, which the next section puts to work.

#callout("verify", "the chain check failed red before it went green", [
  The first gate run of this sample failed check 2: both chains
  returned 1, because `GATE` was still defined when the preprocessor
  reached the second function. The harness printed the FAIL line and
  turned red. Adding the `#undef GATE` on line 34 turned it green, and
  that pair is the evidence the `#elifndef` check actually bites.
])

#flow(
  [the conditional chain walked in order, first true block wins, the rest is skipped],
  node((0, 0), [`#ifdef GATE`]),
  node((0, -1.6), [`#elifdef OTHER`]),
  node((0, -3.2), [`#elifndef THIRD`]),
  node((0, -4.8), [`#else`]),
  node((2.8, -0.8), [defined: return 1]),
  node((2.8, -2.4), [defined: return 2]),
  node((2.8, -4.0), [not defined: return 3]),
  node((2.8, -5.6), [all failed: return 4]),
  node((-3.4, 0), [`#if __has_include(...)`]),
  node((-3.4, -1.8), [1: header found]),
  node((-3.4, -3.6), [0: `#else` branch]),
  edge((0, 0), (2.8, -0.8), "-|>"),
  edge((0, 0), (0, -1.6), "->"),
  edge((0, -1.6), (2.8, -2.4), "-|>"),
  edge((0, -1.6), (0, -3.2), "->"),
  edge((0, -3.2), (2.8, -4.0), "-|>"),
  edge((0, -3.2), (0, -4.8), "->"),
  edge((0, -4.8), (2.8, -5.6), "-|>"),
  edge((-3.4, 0), (-3.4, -1.8), "-|>"),
  edge((-3.4, 0), (-3.4, -3.6), "-|>"),
)

== embed in practice

`#embed` (clang implements N3017 and backports it to C89 and C++ modes)
is a preprocessing directive: it expands during phase 4 into a
comma-separated list of integer constant expressions, one per byte of
the named resource. Initializing an `unsigned char` array from it is
specified to behave as if the resource's data were `fread` into the
array at translation time. The resource here is four bytes shipped next
to the sample:

#listing("c-os-cloud/samples/src/Ch02/embed.c", first: 18, last: 39, caption: [four arrays from one 4 byte resource: full, limited, terminated, and wrapped])

`flag.bin` holds the ascii bytes of `c23` and a newline, `63 32 33
0a`. The quoted resource name resolves against the directory of the
file doing the embedding, verified by compiling from a working
directory two levels away (probed 2026-09-12), which is what lets the
gate copy sources and binaries around freely. `limit(2)` keeps the
first two elements of the resource. The `text` array appends `'\0'`
after the expansion and becomes a valid C string. The `padded` array
uses `prefix(0x00, )` and `suffix(, 0x00)`: when the resource is
non-empty, the prefix tokens land immediately before the byte list and
the suffix tokens immediately after, which is how a sentinel or a
terminator gets welded onto data the compiler reads.

#listing("c-os-cloud/samples/src/Ch02/embed.c", first: 41, last: 59, caption: [size, byte, sum, and string checks over the embedded arrays])

Eleven checks: sizes 4, 2, 5, 6, the exact bytes, the sum 210, and the
strcmp against `"c23\n"`. The ir expectation file pins the constant
the bytes become, `@flag = internal constant [4 x i8] c"c23\0A"`, and
the round trip leg recompiles the emitted `.ll` back to an exe and
diffs the output: the resource is compile-time data baked into the
translation unit, not a file the exe opens.

#diagram([generated header versus embed, same four bytes through the old path and the c23 path], length: 13pt, {
  cdraw.content((5.0, 7.2), [the old way: generated text], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.rect((0.4, 5.6), (9.6, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 6.1), [flag.h, from xxd -i flag.bin], wrap: text.with(size: 6pt))
  cdraw.rect((0.4, 3.7), (9.6, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 4.85), [unsigned char flag[] = {], wrap: text.with(size: 6pt))
  cdraw.content((5.0, 4.0), [0x63, 0x32, 0x33, 0x0a };], wrap: text.with(size: 6pt))
  cdraw.rect((0.4, 1.5), (9.6, 3.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 2.65), [a text copy of the bytes,], wrap: text.with(size: 6pt))
  cdraw.content((5.0, 1.8), [regenerated at every edit], wrap: text.with(size: 6pt))
  cdraw.content((18.2, 7.2), [c23: one directive reads it], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.rect((11.8, 5.6), (24.6, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((18.2, 6.1), [flag.bin, 4 bytes, the only copy], wrap: text.with(size: 6pt))
  cdraw.rect((11.8, 3.7), (24.6, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((18.2, 4.85), [unsigned char flag[] = {], wrap: text.with(size: 6pt))
  cdraw.content((18.2, 4.0), [`#embed "flag.bin"` };], wrap: text.with(size: 6pt))
  for (i, b) in ("63", "32", "33", "0a").enumerate() {
    cdraw.rect((11.8 + i * 1.0, 2.0), (12.8 + i * 1.0, 3.0), fill: luma(215), radius: 0.02)
    cdraw.content((12.3 + i * 1.0, 2.5), b, wrap: text.with(size: 6pt))
  }
  cdraw.content((18.6, 1.5), [read at translation time], wrap: text.with(size: 6pt))
  cdraw.line((18.2, 5.6), (18.2, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.3, 3.7), (13.3, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.6, 4.4), (11.8, 5.8), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((12.0, 0.4), [no generated file, no regeneration, one source of truth], wrap: text.with(size: 6pt))
})

== maximal munch and pp-numbers

Lexing in phase 3 is longest-match: if the input has been parsed up to
a character, the next preprocessing token is the longest sequence of
characters that could constitute one (n3220, 6.4). One exception
exists, header names form only inside `#include`, `#embed`,
`__has_include`, and `__has_embed`. The sample demonstrates the rule
with spellings that survive only because `clang-format` is switched off
around them:

#listing("c-os-cloud/samples/src/Ch02/munch.c", first: 18, last: 21, caption: [the stringify pair: `#` reports the tokens of the argument as lexed])

#listing("c-os-cloud/samples/src/Ch02/munch.c", first: 23, last: 50, caption: [munch arithmetic and pp-number proofs, spellings pinned by clang-format off])

`a+++b` is `a` `++` `+` `b`: the check reads 3 and leaves `a` at 2,
which only the `a++ + b` grouping produces. `d---e` is `d-- - e` by
the same rule, and `1 - -1` shows the opposite direction, the space is
the only thing preventing a `--` token. The stringification checks
make the lexer's choices visible: `#` between tokens of the argument's
spelling collapses to a single space, so `XSTR(a/*c*/b)` printing
`"a b"` is the comment-becomes-one-space rule seen directly, and
`XSTR(0xE+2)` printing `"0xE+2"` with no gap means the preprocessor
held one token.

That one token is the pp-number. The grammar (n3220, 6.4.8) continues
a pp-number with `e sign`, `E sign`, `p sign`, or `P sign`, identical
to n1570's C11 grammar, because a hexadecimal floating constant's
exponent sign belongs to the number: `0x1p+3` must lex as one token
and the final check reads it as 8.0. The cost is that `0xE+2` also
matches, making it a pp-number no phase 7 conversion can turn into a
valid constant. The two fragments below are illustrative, not
executed:

#snippet("int x = 0xE+2;\n", lang: "c")

gcc 15.2 rejects it with `invalid suffix '+2' on integer constant`
(probed 2026-09-12), which is the standard-conforming diagnostic.
clang 23 accepts the line silently: its stringification still proves
the pp-token was one token, so the split into `0xE`, `+`, `2` happens
later, at conversion, with no diagnostic. Portable code treats the
spelling as forbidden regardless. The standard's own example of the
same trap is `x+++++y`:

#snippet("int main(void) { int x = 1, y = 2; return x+++++y; }\n", lang: "c")

It lexes as `x` `++` `++` `+` `y`, which clang reports as `expression
is not assignable`, and the `x ++ + ++ y` reading the programmer
wanted is not available without a space.

#diagram([the same characters, different token streams, munch decides before the parser runs], length: 13pt, {
  cdraw.content((3.4, 6.1), [`0xE+2`, no spaces], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 4.9), (6.2, 5.9), fill: luma(205), radius: 0.02)
  cdraw.content((3.4, 5.4), [0xE+2], wrap: text.with(size: 7pt))
  cdraw.content((9.8, 5.4), [one pp-number], wrap: text.with(size: 6pt))
  cdraw.content((3.4, 4.2), [`0xE +2`, one space], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 3.0), (2.9, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((1.75, 3.5), [0xE], wrap: text.with(size: 7pt))
  cdraw.rect((3.9, 3.0), (6.2, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.05, 3.5), [+2], wrap: text.with(size: 7pt))
  cdraw.content((10.4, 3.5), [two tokens, spaced], wrap: text.with(size: 6pt))
  cdraw.content((3.4, 2.3), [`a+++b`], wrap: text.with(size: 6.5pt))
  let cellx = (0.6, 2.6, 4.6, 6.6)
  let cellt = ("a", "++", "+", "b")
  for i in range(4) {
    cdraw.rect((cellx.at(i), 1.1), (cellx.at(i) + 1.4, 1.9), fill: luma(235), radius: 0.02)
    cdraw.content((cellx.at(i) + 0.7, 1.5), cellt.at(i), wrap: text.with(size: 7pt))
  }
  cdraw.content((10.5, 1.5), [four tokens], wrap: text.with(size: 6pt))
  cdraw.content((19.4, 6.2), [pp-number grammar, 6.4.8], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((19.4, 5.2), [pp-number: digit | . digit], wrap: text.with(size: 6pt))
  cdraw.content((19.4, 4.2), [pp-number e sign | E sign], wrap: text.with(size: 6pt))
  cdraw.content((19.4, 3.2), [pp-number p sign | P sign], wrap: text.with(size: 6pt))
  cdraw.content((19.4, 2.2), [pp-number digit, nondigit], wrap: text.with(size: 6pt))
  cdraw.content((19.4, 1.2), [p joined c99 hex floats], wrap: text.with(size: 6pt))
  cdraw.content((19.4, 0.3), [0x1p+3 is one token], wrap: text.with(size: 6pt))
})

sources: open-std.org n3220 working draft, sections 5.1.1.2, 6.4,
6.4.8, and 6.4.9, and n1570 for the pre-c23 pp-number grammar,
clang.llvm.org language extensions page (`__has_include`,
`__has_c_attribute`, and the backport table naming N3017 and N2645),
and cppreference pages for translation phases, conditional inclusion,
embed, and floating constants, all accessed 2026-09-12; the trigraph,
diagnostic, and gcc 15.2 divergence claims were probed on this machine
the same day. Sample behavior verified by `make verify-c`, 35 checks
in chapter 2 of the samples suite.
