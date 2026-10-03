#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= lexical structure

Everything the compiler sees before it understands types: identifiers,
keywords, literals, operators, and the preprocessor. C\#'s lexical design
goal was familiarity for C and Java programmers with the rough edges filed
off. The places it files hardest: raw string literals, digit separators,
and the `@` and contextual keyword system.

== identifiers

Identifiers start with a letter or underscore and continue with letters,
digits, or underscores, where letter means any unicode letter. Vietnamese
diacritics are legal identifiers, and this book's author takes advantage:

#listing("csharp-net/samples/src/Ch02/Lexical.cs", first: 11, last: 12, caption: [unicode identifiers are legal])

#diagram([identifier grammar, position one, later positions, and the @ escape], length: 13pt, {
  // the grammar is positional, two rules and one escape
  cdraw.rect((0, 2.6), (7.0, 4.4), fill: luma(205), radius: 0.02)
  cdraw.content((3.5, 3.5), [first char #linebreak() unicode letter or `_`], size: 6pt)
  cdraw.line((7.0, 3.5), (8.2, 3.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.2, 2.6), (15.2, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.7, 3.5), [later chars #linebreak() letter, digit, or `_`], size: 6pt)
  cdraw.line((15.2, 3.5), (16.4, 3.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.4, 2.6), (23.4, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((19.9, 3.5), [`@` prefix #linebreak() borrows keywords], size: 6pt)
  cdraw.content((11.7, 1.2), [`TổngHaiSố`: one identifier, every position legal #linebreak() `@class`: keyword borrowed, `class` alone: syntax error], size: 6.5pt)
})

Reserved keywords cannot be identifiers, but the `@` prefix borrows any
keyword as a name. This is occasionally necessary for interop with other
languages and otherwise a curiosity to avoid:

#snippet(
  "// reserved word borrowed as an identifier\n"
  + "string @class = \"not a class declaration here\";\n"
  + "int @int = 3;      // legal, discouraged\n",
  lang: "cs",
)

== keywords

C\# has 77 reserved keywords, `abstract` through `while`, listed completely
in the appendix coverage matrix. The design that matters more: since C\# 2,
every new language word has been a *contextual* keyword, meaningful only in
position, so old code that used `async`, `yield`, or `from` as variable
names keeps compiling. C\# 14 continued with `extension` and `field`, C\# 15
continues with `union`, the next section's subject. The count of contextual
keywords now rivals the reserved set, and the appendix maps every one to
the chapter that teaches it.

#callout("note", "why contextual matters", [
  A language that keeps its reserved set frozen can add features without
  breaking its own ecosystem. When you meet a new word in C\#, check whether
  it is contextual. If it is, the word is also a legal identifier, which is
  the tell that it arrived in a later version.
])

#diagram([reserved vs contextual keywords, what each class allows], length: 13pt, {
  // two columns, four rows, the matrix of the keyword classes
  let cols = ((0.0, 6.0, []), (6.0, 14.6, "reserved (77)"), (14.6, 23.2, "contextual (grows)"))
  for (x0, x1, head) in cols {
    cdraw.rect((x0, 4.6), (x1, 5.6), fill: luma(205), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 5.1), head, size: 6.5pt)
  }
  let rows = (
    ("count", [77, frozen since c\# 1], [one or more per version]),
    ("as identifier", [never], [yes, outside its position]),
    ("examples", [`class`, `while`, `return`], [`async`, `yield`, `field`]),
  )
  for (i, row) in rows.enumerate() {
    let y0 = 3.5 - i * 1.15
    cdraw.rect((0.0, y0), (6.0, y0 + 0.9), fill: luma(235), radius: 0.02)
    cdraw.content((3.0, y0 + 0.45), row.at(0), size: 6pt)
    cdraw.rect((6.0, y0), (14.6, y0 + 0.9), fill: luma(245), radius: 0.02)
    cdraw.content((10.3, y0 + 0.45), row.at(1), size: 6pt)
    cdraw.rect((14.6, y0), (23.2, y0 + 0.9), fill: luma(245), radius: 0.02)
    cdraw.content((18.9, y0 + 0.45), row.at(2), size: 6pt)
  }
})

== the union keyword

C\# 15 adds `union`, and the word arrives the way every new word since
C\# 2 has arrived: contextual. Chapter 3 owns the union semantics, the
cases, the conversions, the exhaustiveness. This chapter owns the word
itself. In type declaration position, `union` followed by a name and a
parenthesized case list, the parser reads a type declaration.
Everywhere else the word is a plain identifier, and the suite proves
it with code that compiles on the default language version, no
preview flag:

#listing("csharp-net/samples/src/Ch02/Lexical.cs", first: 43, last: 51, caption: [a local named union, an addition, a call, all ordinary])

#diagram([union, one word, two parses], length: 13pt, {
  // the word at top, the two parses below, position decides
  cdraw.rect((8.0, 4.6), (15.6, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 5.2), [`union`], size: 6.5pt)
  cdraw.line((9.2, 4.6), (5.0, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.4, 4.6), (18.6, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 1.4), (9.8, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((5.0, 2.5), [declaration position: #linebreak() `union Pet(Cat, Dog)`, #linebreak() a type declaration], size: 6pt)
  cdraw.rect((13.8, 1.4), (23.4, 3.6), fill: luma(230), radius: 0.02)
  cdraw.content((18.6, 2.5), [everywhere else: #linebreak() `int union = 5`, #linebreak() a plain identifier], size: 6pt)
  cdraw.content((11.8, 0.2), [the case list in parentheses is the declaration tell, #linebreak() pre c\# 15 code with a `union` variable needs no `@` escape], size: 6.5pt)
})

The census was recounted from the live keywords reference for this
edition rather than carried forward. The reserved table still lists 77
words, `abstract` through `while`, unchanged. The contextual table
lists 48 words as of the read date: `partial`, `unmanaged`, `when`,
and `where` each appear twice in the table because each word serves
two documented contexts, they count once. `union` was not yet in that
table, the index page lags the compiler, but the union reference page
documents the word and the listing above shows it parsing as an
identifier outside its position, which is the contextual signature.
The appendix matrix files it under contextual, 49 rows, taught here.

== literals, the full inventory

Integer literals come in decimal, hexadecimal (`0x`), and binary (`0b`)
forms, with `_` digit separators allowed anywhere between digits and type
suffixes forcing width:

#listing("csharp-net/samples/src/Ch02/Lexical.cs", first: 14, last: 17, caption: [integer literal forms])

Real literals come in three precisions: `double` by default, `f` for 32 bit
`float`, `m` for `decimal`, the base 10 fixed point type for money where
`0.1` must mean exactly 0.1:

#listing("csharp-net/samples/src/Ch02/Lexical.cs", first: 19, last: 22, caption: [real literal forms and suffixes])

Character literals take a single character, a `\u` unicode escape, or a
`\x` hex escape:

#listing("csharp-net/samples/src/Ch02/Lexical.cs", first: 24, last: 25, caption: [char literal forms])

#diagram([literal inventory, bases, separators, suffixes, escapes], length: 13pt, {
  // one row per literal kind, example chips, the rule at the right
  let kinds = ([integer], [real], [char])
  let chiprows = (
    (`1_000_000`, `0xFF_FF`, `0b1010_1010`),
    (`1.5e3`, `2.5f`, `19.99m`),
    (`'A'`, `'B'`, `'\x0043'`),
  )
  let chipw = (4.3, 2.3, 2.9)
  let notes = (
    [`L`, `u` width],
    [double by default #linebreak() `f` float, `m` decimal],
    [one char or an #linebreak() escape],
  )
  for i in range(3) {
    let y = 5.0 - i * 2.1
    let w = chipw.at(i)
    cdraw.content((1.7, y), kinds.at(i), size: 6.5pt)
    for j in range(3) {
      let x0 = 4.2 + j * (w + 0.35)
      cdraw.rect((x0, y - 0.55), (x0 + w, y + 0.55), fill: luma(235), radius: 0.02)
      cdraw.content((x0 + w / 2, y), chiprows.at(i).at(j), size: 6pt)
    }
    cdraw.content((20.2, y), notes.at(i), size: 6.5pt)
  }
})

== strings, five ways

The string literal system deserves its own section because it has grown
five forms, each solving a real problem:

#listing("csharp-net/samples/src/Ch02/Lexical.cs", first: 27, last: 32, caption: [regular, verbatim, and raw string literals])

Regular strings interpret escapes. Verbatim strings (`@"..."`) take
everything literally, doubling `""` for a quote, the natural form for
Windows paths and regex patterns. Raw string literals (three or more
quotes) take everything literally with no escaping at all, and strip
indentation to the closing delimiter, which makes embedded SQL, JSON, and
multi line text painless.

Interpolation is `$"..."`, with format specifiers after `:` and alignment
after `,`:

#listing("csharp-net/samples/src/Ch02/Lexical.cs", first: 33, last: 33, caption: [interpolation with format and alignment])

Combining interpolation with raw strings doubles the braces, `$$"""` with
`{{...}}` for holes, which keeps single braces literal for templating:

#listing("csharp-net/samples/src/Ch02/Lexical.cs", first: 35, last: 37, caption: [raw interpolated strings])

#diagram([the five string forms and their escape policies], length: 13pt, {
  // form on the left, the policy that separates it on the right
  let forms = (`"..."`, `@"..."`, `"""` , `$"..."`, `$$"""`)
  let policies = (
    [`\t`, `\n`, `\"` interpreted],
    [everything literal, `""` writes one quote],
    [no escapes, indentation stripped],
    [`{expr}` holes, `:` format, `,` align],
    [`{{expr}}` holes, single `{` stays literal],
  )
  for i in range(5) {
    let y = 6.0 - i * 1.25
    cdraw.rect((0.2, y - 0.55), (3.8, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((2.0, y), forms.at(i), size: 6pt)
    cdraw.line((3.8, y), (5.0, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((12.4, y), policies.at(i), size: 6.5pt)
  }
})

#callout("pitfall", "the colon in interpolation holes", [
  `{Math.PI:F2}` parses because the compiler knows `Math.PI` is an
  expression, but a conditional operator inside a hole needs parentheses:
  `{(flag ? "a" : "b")}`, because the bare `:` would be read as the start
  of a format specifier.
])

== bool and null

`true` and `false` are literals of type `bool`. `null` is the null literal,
typed by context, and under nullable reference types the compiler tracks
which references can hold it, which is the type system chapter's subject.

#diagram([true, false, null, two literals with fixed types and one typed by context], length: 13pt, {
  // the fixed pair on the left, the context dependent literal on the right
  cdraw.rect((0.4, 4.1), (2.2, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((1.3, 4.55), [`true`], size: 6pt)
  cdraw.rect((2.6, 4.1), (4.4, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 4.55), [`false`], size: 6pt)
  cdraw.line((4.4, 4.55), (5.6, 4.55), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.6, 4.1), (8.2, 5.0), fill: luma(205), radius: 0.02)
  cdraw.content((6.9, 4.55), [`bool`, always], size: 6pt)
  cdraw.rect((11.0, 4.1), (12.8, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 4.55), [`null`], size: 6pt)
  cdraw.line((11.9, 4.1), (10.0, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.9, 4.1), (13.8, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.9, 2.45), [`string? s = null`], size: 6pt)
  cdraw.content((15.0, 2.45), [`int? i = null`], size: 6pt)
  cdraw.content((12.0, 0.8), [the context picks the type, and under nullable reference types #linebreak() the compiler tracks nullness while the runtime type never changes], size: 6.5pt)
})

== the preprocessor

Lines beginning with `#` are directives, evaluated before parsing proper.
The honest description: C\#'s preprocessor is not a text macro processor.
There is no `#define PI 3.14`. The directives that matter:

#snippet(
  "#define TRACE              // boolean symbol only, no value symbols\n"
  + "#if TRACE\n"
  + "  Console.WriteLine(\"traced\");\n"
  + "#elif DEBUG\n"
  + "#else\n"
  + "#endif\n"
  + "#pragma warning disable CS8600   // silence one warning by id\n"
  + "#nullable enable                 // set nullable context per file\n"
  + "#endregion                      // editor folding, nothing more\n",
  lang: "cs",
)

#diagram([preprocessor symbols, two feeds, boolean only, pruning before parse], length: 13pt, {
  // sources feed a boolean symbol table, the if family prunes before parsing
  cdraw.rect((0.2, 4.5), (6.2, 5.5), fill: luma(235), radius: 0.02)
  cdraw.content((3.2, 5.0), [`#define TRACE`], size: 6pt)
  cdraw.rect((0.2, 2.9), (6.2, 3.9), fill: luma(235), radius: 0.02)
  cdraw.content((3.2, 3.4), [`<DefineConstants>`], size: 6pt)
  cdraw.line((6.2, 5.0), (7.2, 4.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.2, 3.4), (7.2, 4.05), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.2, 3.3), (13.6, 5.1), fill: luma(205), radius: 0.02)
  cdraw.content((10.4, 4.2), [symbol table #linebreak() boolean only], size: 6pt)
  cdraw.line((13.6, 4.2), (15.4, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((15.4, 3.3), (23.2, 5.1), fill: luma(235), radius: 0.02)
  cdraw.content((19.3, 4.2), [`#if` / `#elif` / `#else` #linebreak() prunes code before parsing], size: 6pt)
  cdraw.content((11.7, 1.4), [no value macros: `#define PI 3.14` does not exist, #linebreak() `#pragma` and `#nullable` are compiler directives, not macros], size: 6.5pt)
})

Conditional compilation uses boolean symbols set by `#define` or the
`<DefineConstants>` property, and the `#if` family is how cross platform
code paths compile selectively. It is a feature to use sparingly, most
conditional behavior belongs in runtime `if` statements where tests can
reach it.

== comments and the rest of the surface

Line comments `//`, block comments `/* */` which do not nest, and
documentation comments `///` that produce XML docs, covered with reflection
in chapter 13. Statements end in `;`. Whitespace has no meaning beyond
separation, and the grammar is free form. That is the entire lexical
surface, everything from here on is grammar and types.

#diagram([three comment forms, their consumers, and what survives], length: 13pt, {
  // two forms vanish at compile time, one becomes a document
  let forms = (`//`, `/* */`, `///`)
  let consumers = (
    [the compiler reads and discards],
    [the compiler, cannot nest],
    [the xml doc generator, chapter 13],
  )
  let survives = ([gone], [gone], [xml doc file])
  for i in range(3) {
    let y = 4.6 - i * 1.6
    cdraw.rect((0.2, y - 0.55), (2.8, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((1.5, y), forms.at(i), size: 6pt)
    cdraw.line((2.8, y), (4.0, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((9.6, y), consumers.at(i), size: 6.5pt)
    cdraw.content((17.6, y), survives.at(i), size: 6.5pt)
  }
})

sources: learn.microsoft.com, c\# language reference, lexical structure and
keywords pages, accessed 2026-09-08, the keywords reference recounted and
the union types reference page, accessed 2026-09-13. Sample behavior
verified by `make verify-csharp`, 10 tests.
