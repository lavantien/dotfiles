#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= lexical structure

Every java program is unicode text before it is anything else, and the
lexer cuts that text into five token kinds: identifiers, keywords,
literals, operators, and separators, with comments and whitespace
dropped on the way. Chapter 2 walked the ladder release by release,
and this chapter walks the surface it delivered: what a name may look
like, which words the language has frozen, how every literal is
spelled, the one precedence table worth memorizing, and the comment
forms including the markdown doc comments of 23. The Ch03 samples run
every claim through `javax.lang.model.SourceVersion`, the compiler's
own token predicates, so the taxonomy below is measured on the pinned
27 rather than recited.

== identifiers

Java has accepted unicode in source since 1, and an identifier is any
length of unicode letters and digits with a letter in front, where
letter and digit are decided by `Character.isJavaIdentifierStart` and
`isJavaIdentifierPart`. Vietnamese, greek, and kanji spellings are
legal, a digit cannot lead, and the dollar sign and other currency
symbols are legal but reserved by convention for generated code, the
compiler names its own artifacts with them. The underscore may appear
inside a name but has not been a name on its own since 9.

#listing("java/samples/src/Ch03/Tokens.java", first: 60, last: 69, caption: [unicode identifiers, and the classifier the lexer actually uses])

Identifiers shadow the contextual keywords freely, which is the point
of contextuality: code written before `var` or `record` meant anything
still compiles. All 16 identifier-shaped contextual words can name
locals in one scope, `var` still infers beside a local actually named
`var`, and since 22 the underscore declares an unnamed variable that
discards its initializer, the migration JEP 456 gave every catch and
lambda parameter.

#listing("java/samples/src/Ch03/Tokens.java", first: 71, last: 83, caption: [contextual words as working identifiers, and the unnamed variable])

One rule cuts the other way for type names: a class cannot be called
`var`, `record`, `sealed`, `permits`, or `yield`, the `TypeIdentifier`
production in the spec, and a method invocation of `yield` must be
qualified so the parser can tell it from the statement.

== keywords, 51 reserved and 17 contextual

The spec for 27 reserves 51 character sequences. The list froze at 51
when the underscore joined in 9: `enum` arrived with 5, `const` and
`goto` have been reserved and unused since 1.0 as error-message
insurance for c++ programmers, and `strictfp` survives as an obsolete
word that 17 turned into a no-op when the platform went uniformly
IEEE 754. Alongside the reserved list sit three literal tokens,
`true`, `false`, and `null`, reserved like keywords but classified as
literals, so the honest sentence is that 54 character sequences cannot
name anything.

#listing("java/samples/src/Ch03/Tokens.java", first: 25, last: 58, caption: [the reserved list counted through the compiler's own isKeyword])

Contextual keywords are the escape valve that kept the frozen list
frozen. Each one is only a keyword where the grammar expects it, and
the spec adds a guard worth knowing: the sequence is not a keyword
when a letter or digit touches it, so `varfilename` is one identifier,
never `var` followed by `filename`.

#diagram([the keyword taxonomy: 51 reserved and frozen, 17 contextual and dated], length: 13pt, {
  cdraw.rect((0.3, 1.6), (11.3, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.1), [51 reserved], size: 6.5pt)
  cdraw.content((5.8, 5.15), [frozen since 9, when #sym.underscore joined], size: 6pt)
  cdraw.content((5.8, 4.2), [enum 5, const goto unused, strictfp a no-op], size: 6pt)
  cdraw.content((5.8, 3.25), [true false null: literal neighbors], size: 6pt)
  cdraw.content((5.8, 2.3), [abstract through while, underscore last], size: 6pt)
  cdraw.rect((12.5, 1.6), (23.3, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((17.9, 6.1), [17 contextual], size: 6.5pt)
  cdraw.content((17.9, 5.15), [9: module open requires transitive], size: 6pt)
  cdraw.content((17.9, 4.2), [10: var, 13: yield, 14: record], size: 6pt)
  cdraw.content((17.9, 3.25), [17: sealed permits non-sealed when], size: 6pt)
  cdraw.content((17.9, 2.3), [all 17 legal as variable names], size: 6pt)
  cdraw.content((11.8, 0.6), [every arrival after 9 rides context, never reservation], size: 6pt)
})

The dates on the right are the Amber story in miniature: the module
system minted 10 words in 9, `var` inferred in 10, `yield` arrived with
the 13 switch-expression preview and went final with the expressions in
14, `record` previewed in 14 and finalized in 16, and the sealed trio
plus the `when` guard landed in 17, with `when` waiting for the 21
pattern switch to carry it final. Chapter 9 is where the sealed set and
`when` earn their keep.

== operators and precedence

Operators associate left to right except where the table says
otherwise, and assignment is the broadest right-associative form. The
levels, tightest first:

#table(
  columns: (auto, 1fr, 1fr),
  inset: 4pt,
  table.header([*level*], [*operators*], [*notes*]),
  [postfix], [`expr++ expr--`, `.`, `[]`, method call], [binds tightest, left to right],
  [unary], [`++expr --expr +expr -expr ~ !`], [right to left, `~` flips bits, `!` flips booleans],
  [multiplicative], [`* / %`], [left to right],
  [additive], [`+ -`], [left to right, `+` also concatenates strings],
  [shift], [`<< >> >>>`], [`>>>` is the logical shift, no sign extension],
  [relational], [`< > <= >= instanceof`], [left to right],
  [equality], [`== !=`], [compares references on objects, values on primitives],
  [bitwise and], [`&`], [unparenthesized `&` before `^` before `|`],
  [bitwise xor], [`^`], [],
  [bitwise or], [`|`], [],
  [logical and], [`&&`], [short circuits],
  [logical or], [`||`], [short circuits],
  [ternary], [`? :`], [right to left, chapter 4 measures its var typing],
  [assignment], [`= += -= *= /= %= &= ^= |= <<= >>= >>>=`], [right to left, an expression, not a statement],
  [arrow], [`->`], [lambda and switch case labels, not an operator by precedence],
)

The two rows c readers trip on are `>>>`, which java has and c lacks,
and the fact that `&` and `|` on booleans do not short circuit, which
is occasionally exactly what an order-independent side effect wants.
Precedence answers ambiguity, but the working habit is parentheses:
the corpus style adds them the moment a shift meets an additive
operator.

== separators

Twelve separator tokens: `( ) { } [ ] ; , . ... @ ::`. The ellipsis is
varargs since 5, the double colon method reference since 8, and the
at-sign annotates declarations. They carry no precedence, they only
bracket. The semicolon and brace get their own grounding at the end of
this chapter because java inherits c's statement discipline exactly.

== literals

Integer literals come in four bases. Hexadecimal runs `0x` or `0X`,
octal is a leading zero, and binary `0b` and the underscore digit
separator both arrived with 7's project coin. Octal is legacy, kept
because file permissions and pre-java history read naturally in it,
and it is the one base that silently changes meaning when a padding
zero lands in front of a decimal.

#listing("java/samples/src/Ch03/Literals.java", first: 18, last: 33, caption: [four bases, underscores since 7, and int by default with L for long])

A decimal literal is an `int` unless it ends in `L` or `l`, and the
uppercase form wins on readability because lowercase `l` reads as 1.
Floating literals default to `double`, take `f` or `F` for `float`,
and scale with `e` or `E`. The exotic form is hexadecimal floating
point, significand in hex with a `p` binary exponent, in the language
since 5 and read back by `Double.toHexString` since the same release:
`0x1.8p1` is one-and-a-half times two, exactly 3.0.

#listing("java/samples/src/Ch03/Literals.java", first: 35, last: 41, caption: [suffixes, exponents, and the hexadecimal float form])

Char literals quote one utf-16 code unit and share their escapes with
string literals. The five control escapes cover the ascii whitespace
set, octal escapes run one to three digits capped at `\377`, and
`\uXXXX` takes exactly four hex digits with any number of extra `u`
characters allowed in front, a spec quirk the sample pins. The `\s`
escape, an explicit space that survives text-block trailing-space
stripping, came with 14's second text block preview.

#listing("java/samples/src/Ch03/Literals.java", first: 43, last: 53, caption: [every escape family, octal to unicode, plus the space escape])

String literals sit in double quotes on one source line. Text blocks,
previewed in 13 and 14 then final in 15, span lines with `"""`, and at
runtime they are ordinary `String` values, indented by the compiler's
minimum-strip algorithm: chapter 13 pins that algorithm line by line,
so this chapter only claims the lexical shape. One compile-time fact
belongs here: literal concatenation is a constant expression, folded
and pooled before the program runs.

#listing("java/samples/src/Ch03/Literals.java", first: 55, last: 69, caption: [one-line strings, the text block shape, and compile-time folding])

== comments

Four forms. `//` runs to end of line, `/* */` spans lines and nests
nothing, `/** */` is the javadoc doc comment, and since 23 the `///`
line form carries doc comments in markdown instead of html, JEP 467,
the form this book's samples use. The compiler only strips them, and
javadoc is the tool that reads the doc forms: chapter 1 set up the jdk
toolchain those ride on.

One lexical trap hides in the preprocessing stage that runs before the
lexer. Unicode escapes are translated into their characters first, so
an escape inside a comment is code as far as the compiler is concerned:

#snippet("// looks like a comment, ends the line:\n// the escape below is a real newline " + "\\" + "u000A int nowCode = 1;", lang: "java")

The `\u000A` becomes a line terminator before tokenization, the `//`
comment ends, and the words after it must compile or javac rejects the
file. Unicode escapes also cannot name a `\u` they have already
consumed: the translation is one pass, earliest leftmost first.

== semicolons and blocks for c readers

Java keeps c's punctuation habits whole. Semicolons terminate
statements, braces group them and open a scope, whitespace between
tokens means nothing, and there is no preprocessor: no `#define`, no
`#include`, no textual substitution of any kind, the nearest
equivalents being `static final` constants and the `import` that
resolves names rather than pasting text. Statements that look like c
statements read like c statements, and the one habit worth unlearning
is the declaration-on-top style the old c compilers needed, since java
declares at first use and `var` rewards it.

sources: docs.oracle.com/javase/specs/jls/se27/html/jls-3.html accessed
2026-10-04 for the 51 reserved words, the 17 contextual keywords and
their recognition rule, true false null as literal classifications,
const and goto reservation, and the obsolete strictfp note,
openjdk.org/jeps/213 accessed 2026-10-04 for the underscore warning in
8 and removal in 9, openjdk.org/jeps/354 for yield in the 13 preview,
openjdk.org/projects/jdk/14 and /jdk/15 accessed 2026-10-04 for
records preview 14 and sealed preview 15 alongside the ladder-chapter
spine (records final 16, sealed final 17, switch expressions final 14,
text blocks final 15, markdown doc comments 23), JEP 456 for unnamed
variables in 22, docs.oracle.com/javase/tutorial/java/nutsandbolts/datatypes.html
accessed 2026-10-04 for underscores in numeric literals since se 7,
docs.oracle.com/javase/7/docs/technotes/guides/language/binary-literals.html
for binary literals since 7, and
docs.oracle.com/en/java/javase/17/docs/api/java.base/java/lang/Double.html
for the since 1.5 marker on hexadecimal float notation. Grounding on
Java in a Nutshell 8th edition chapter 2 (lexical structure, primitive
data types) for the token inventory, the contextual keyword list at 17,
and the separator set, rewritten here. Everything behavioral verified
live on tools/jdk27/build/jdk-27 by the Ch03 samples under pwsh
tools/run-java-samples.ps1 -Chapter Ch03: 26 checks, Tokens 11 and
Literals 15, covering the 51 reserved words through SourceVersion,
the 16 identifier-shaped contextual words as locals, the underscore as
unnamed variable, unicode identifier classification, the four integer
bases, underscores, suffixes, hexadecimal floats, every escape family,
the text block shape, and compile-time literal folding, all dated
2026-10-04.
