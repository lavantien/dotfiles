#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= lexical structure

Lua is free form: whitespace and comments separate tokens and nothing
else. Names are case sensitive, `And` and `AND` are two different valid
names while `and` is grammar. In 5.5 `global` joins the reserved
list, the first new reserved word since 5.2's `goto` in 2011,
bringing the count to 23.

== names and the compat caveat

The probe suite pins the reserved list by brute force, trying each word
as a local name:

#listing("lua/samples/ch02_lexical.lua", first: 4, last: 12, caption: [the 23 reserved words and the loads helper])

#listing("lua/samples/ch02_lexical.lua", first: 22, last: 37, caption: [exactly one reserved word parses as a name])

#flow(
  [why exactly one reserved word parses as a name, the compat un-reserving and the declaration lookahead],
  node((0, 0), [word used as a name]),
  node((0, 1.6), [in the reserved list?]),
  node((-2.0, 3.2), [syntax error, #linebreak() the other 22 words]),
  node((2.0, 3.2), [global: compat on, #linebreak() the lexer un-reserves it]),
  node((2.0, 4.8), [statement start, #linebreak() followed by \<, name, #linebreak() \*, or function?]),
  node((0.0, 6.4), [global declaration]),
  node((4.2, 6.4), [a plain name]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (-2.0, 3.2), "-|>", label: [yes]),
  edge((0, 1.6), (2.0, 3.2), "-|>", label: [no, one word]),
  edge((2.0, 3.2), (2.0, 4.8), "-|>"),
  edge((2.0, 4.8), (0.0, 6.4), "-|>", label: [yes]),
  edge((2.0, 4.8), (4.2, 6.4), "-|>", label: [no]),
)

Exactly one word survives: `global`. This is the book's first honest
finding about 5.5.1 as distributed. The manual reserves `global`
outright, but `luaconf.h` ships `LUA_COMPAT_GLOBAL` defined to 1, and
under it the lexer marks the word not reserved. The parser then
recognizes a global declaration contextually: in statement position,
the name `global` followed by a lookahead of `<`, a name, `*`, or
`function` parses as the declaration statement. So `local global = 1`
is legal, `global = 5` is a plain assignment to a global literally
named `global`, and `global x; x = 1; y = 2` still fails to compile
because `y` is undeclared. Code that needs the manual's strict
reservation compiles with `LUA_COMPAT_GLOBAL` unset; this book tests
the stock tarball and says so in every affected chapter.

The identifier alphabet has the same shape of caveat. The manual
describes names as Latin letters, Arabic-Indic digits, and
underscores, but the stock build's character table marks nothing above
byte 127 alphabetic unless `LUA_UCID` is defined at compile time:

#listing("lua/samples/ch02_lexical.lua", first: 44, last: 51, caption: [an utf 8 continuation byte is an unexpected symbol in the stock build])

== short strings and escapes

A short string is single or double quoted, one line, with C-like
escapes: the controls `\a \b \f \n \r \t \v`, quotes, backslash, plus
`\z` to skip whitespace, a backslash line break for a newline, `\xXX`
for a byte, up to three decimal digits for a byte, and `\u{XXX}` for a
code point in lua's original, non unicode restricted utf 8. The manual
compresses the whole system into five spellings of one string:

#listing("lua/samples/ch02_lexical.lua", first: 53, last: 66, caption: [two escapes, two long brackets, one byte coded string])

The decimal escape has the classic trap the suite pins: `\0658` is the
byte 65 followed by the digit 8, while `\658` tries to read one escape
of 658 and fails to load:

#listing("lua/samples/ch02_lexical.lua", first: 68, last: 89, caption: [z, backslash newline, byte escapes, and u with a beyond unicode code point])

#diagram([the escape grammar of a short string as one taxonomy], length: 13pt, {
  // grid: header band then five single rows and two double rows
  cdraw.rect((0.0, 0.8), (20.0, 11.6), stroke: luma(150))
  cdraw.line((0.0, 10.6), (20.0, 10.6), stroke: luma(150))
  for y in (9.5, 8.4, 7.3, 6.2, 5.1, 2.95) {
    cdraw.line((0.0, y), (20.0, y), stroke: luma(220))
  }
  cdraw.line((8.5, 0.8), (8.5, 11.6), stroke: luma(150))
  cdraw.content((4.25, 11.05), [spelling], size: 6.5pt)
  cdraw.content((14.25, 11.05), [produces], size: 6.5pt)
  cdraw.content((4.25, 10.05), [\\a \\b \\f \\n \\r \\t \\v], size: 6pt)
  cdraw.content((14.25, 10.05), [the seven control characters], size: 6pt)
  cdraw.content((4.25, 8.95), [\\" \\' \\\\], size: 6pt)
  cdraw.content((14.25, 8.95), [the quote and the backslash themselves], size: 6pt)
  cdraw.content((4.25, 7.85), [\\z], size: 6pt)
  cdraw.content((14.25, 7.85), [skips all following whitespace], size: 6pt)
  cdraw.content((4.25, 6.75), [\\ + a real newline], size: 6pt)
  cdraw.content((14.25, 6.75), [a newline inside the literal], size: 6pt)
  cdraw.content((4.25, 5.65), [\\xXX], size: 6pt)
  cdraw.content((14.25, 5.65), [one byte from two hex digits], size: 6pt)
  cdraw.content((4.25, 4.55), [\\ddd], size: 6pt)
  cdraw.content((14.25, 4.55), [up to three decimals for a byte], size: 6pt)
  cdraw.content((14.25, 3.45), [\\0658 is byte 65 then 8, \\658 fails], size: 6pt)
  cdraw.content((4.25, 2.35), [\\u{XXX}], size: 6pt)
  cdraw.content((14.25, 2.35), [a code point up to 2^31^-1], size: 6pt)
  cdraw.content((14.25, 1.25), [in lua's original utf 8], size: 6pt)
})

`\u{7FFFFFFF}` encodes to 6 bytes because lua implements the original
utf 8 proposal, not the unicode capped one, and it accepts code points
up to 2^31^-1.

== long brackets

A long bracket of level n is `[` repeated `=` n times then `[`; the
string runs to the matching close and ignores brackets of every other
level. No escapes are interpreted. The first newline after the opening
bracket is dropped, and any end of line sequence inside, including
carriage return alone, normalizes to one newline:

#listing("lua/samples/ch02_lexical.lua", first: 97, last: 109, caption: [level nesting, literal backslashes, dropped leading newline, crlf folding])

#diagram([long bracket scanning, the dropped first newline and the folded line ends], length: 13pt, {
  // source bytes inside a level 2 long bracket
  cdraw.content((0.0, 6.4), [source inside \[==\[ \]\==\]], size: 6.5pt)
  let src = (("\\n", true), ("a", false), ("\\", false), ("b", false), ("CR", true), ("LF", true), ("c", false))
  for (i, (t, hot)) in src.enumerate() {
    let f = if hot { luma(205) } else { luma(235) }
    cdraw.rect((1.0 + i * 1.7, 5.0), (2.7 + i * 1.7, 6.0), fill: f, radius: 0.02)
    cdraw.content((1.85 + i * 1.7, 5.5), [#t], size: 6pt)
  }
  // the resulting string bytes
  cdraw.content((0.0, 2.9), [the string it produces], size: 6.5pt)
  let out = ("a", "\\", "b", "\\n", "c")
  for (i, t) in out.enumerate() {
    let f = if i == 3 { luma(205) } else { luma(235) }
    cdraw.rect((1.0 + i * 1.7, 1.5), (2.7 + i * 1.7, 2.5), fill: f, radius: 0.02)
    cdraw.content((1.85 + i * 1.7, 2.0), [#t], size: 6pt)
  }
  // arrows: the dropped newline, the folded pair
  cdraw.line((1.85, 5.0), (1.85, 4.4), (0.6, 4.4), stroke: luma(120), mark: (end: ">"))
  cdraw.content((1.6, 4.05), [dropped], size: 6pt)
  cdraw.line((9.25, 5.0), (9.25, 4.4), (7.55, 4.4), stroke: luma(120), mark: (end: ">"))
  cdraw.content((8.9, 4.05), [cr, lf or crlf #linebreak() all fold to one \\n], size: 6pt)
  cdraw.content((15.5, 5.5), [backslashes are #linebreak() literal bytes], size: 6pt)
})

Comments reuse the machinery: `--` to end of line, or `--` plus a long
bracket for a block comment, which is how you comment out code that
itself contains `]]` by going up a level.

== numerals

A numeral with a radix point or exponent is a float, in decimal or
hexadecimal, hexadecimal exponents marked `p`. Without either, it is
an integer if it fits, with two overflow rules that differ by base:
hexadecimal integers wrap around, decimal integers that overflow
become floats:

#listing("lua/samples/ch02_lexical.lua", first: 111, last: 129, caption: [the subtype rules and both overflow behaviors])

#flow(
  [numeral classification, what forces a float and the two overflow rules],
  node((0, 0), [a numeral]),
  node((0, 1.6), [radix point or exponent?]),
  node((-2.2, 1.6), [float, decimal #linebreak() or hex with p]),
  node((0, 3.2), [fits in 64 bits?]),
  node((-2.2, 3.2), [integer]),
  node((0, 4.8), [on overflow: hex wraps, #linebreak() decimal becomes a float]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (-2.2, 1.6), "-|>", label: [yes]),
  edge((0, 1.6), (0, 3.2), "-|>", label: [no]),
  edge((0, 3.2), (-2.2, 3.2), "-|>", label: [yes]),
  edge((0, 3.2), (0, 4.8), "-|>", label: [no]),
)

The manual's own example `0x1.fp10` is 31 sixteenths times 1024, which
is exactly 1984, and the suite holds it to that.

sources: lua.org manual 5.5 section 3.1, lua.org/versions.html 5.5
entry, accessed 2026-09-08. Lexer and parser behavior verified against
the stock 5.5.1 tarball source, llex.c, lparser.c, lctype.c, lctype.h,
luaconf.h, 15 tests green through `make verify-lua`.
