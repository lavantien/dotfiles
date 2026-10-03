#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= lexical structure

Go's lexical surface is the smallest of the four languages in this
collection: 25 keywords, one identifier rule, semicolon insertion, and
literals that read like C with the ambiguity removed. The sample
package proves the rules by running `go/scanner` and `go/token`, the
compiler's own front end, so nothing here is asserted from memory.

== keywords, 25 and frozen

The complete reserved list:

#listing("go/samples/ch02/lexical.go", first: 14, last: 22, caption: [every keyword in the language])

No keyword has been added since 1.0 kept this list stable, which is
why new syntax in go 1.27 like generic methods reuses `func` rather
than minting words. The bigger design point: the names programmers
mistake for keywords are not. `len`, `cap`, `append`, `make`, `new`,
`min`, `max`, `clear`, `print`, `true`, `false`, `nil`, `iota` are
predeclared identifiers in the universe block, shadowable at any scope,
and the test suite pins that `token.IsKeyword("len")` is false while
`token.IsIdentifier("len")` is true.

#diagram([25 frozen keywords versus the shadowable predeclared universe], length: 13pt, {
  cdraw.rect((0.3, 1.9), (11.3, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 5.9), [25 keywords], size: 6.5pt)
  cdraw.content((5.8, 4.75), [reserved: cannot be], size: 6pt)
  cdraw.content((5.8, 3.6), [redeclared or shadowed], size: 6pt)
  cdraw.content((5.8, 2.45), [func go select return], size: 6pt)
  cdraw.rect((12.5, 1.9), (23.3, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((17.9, 5.9), [predeclared names], size: 6.5pt)
  cdraw.content((17.9, 4.75), [universe block: shadowable], size: 6pt)
  cdraw.content((17.9, 3.6), [like any local], size: 6pt)
  cdraw.content((17.9, 2.45), [len nil true iota], size: 6pt)
  cdraw.content((11.8, 1.0), [no word added since 1.0, so 1.27 syntax reuses func], size: 6pt)
})

== identifiers and export

An identifier is a letter followed by letters and digits, where letter
means any unicode letter plus the underscore. Vietnamese and greek
spellings are legal, digits cannot lead, and the blank identifier `_`
discards. Export is a lexical rule with no keyword for it: a name is
exported when its first character is a unicode uppercase letter,
category `Lu`, and it lives in a package block or names a field or
method. Lowercase names are private to the package, there is no
`private` or `internal` keyword:

#listing("go/samples/ch02/lexical.go", first: 24, last: 40, caption: [classification through go/token, the compiler's own predicates])

The greek cases in the test are the sharp edge: capital `Α` is `Lu` so
`Αβ` exports, small `α` is `Ll` so `αβ` does not, and a leading
underscore counts as lowercase, so `_x` never exports.

#diagram([export is one lexical test: the first rune decides], length: 13pt, {
  cdraw.content((7.0, 6.3), [Αβ], size: 7pt)
  cdraw.content((11.4, 6.3), [αβ], size: 7pt)
  cdraw.content((15.8, 6.3), [#"_x"], size: 7pt)
  cdraw.line((7.0, 5.95), (7.0, 5.6), stroke: luma(100))
  cdraw.line((11.4, 5.95), (11.4, 5.6), stroke: luma(100))
  cdraw.line((15.8, 5.95), (15.8, 5.6), stroke: luma(100))
  cdraw.rect((4.6, 3.4), (18.2, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.4, 5.0), [first rune in unicode], size: 6.5pt)
  cdraw.content((11.4, 3.85), [category Lu?], size: 6.5pt)
  cdraw.line((8.5, 3.4), (5.0, 2.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((5.8, 3.1), [yes], size: 6pt)
  cdraw.line((14.3, 3.4), (18.7, 2.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((17.0, 3.1), [no], size: 6pt)
  cdraw.rect((2.0, 1.2), (8.0, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 1.8), [exported], size: 6.5pt)
  cdraw.rect((15.2, 1.2), (23.2, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((19.2, 1.8), [package private], size: 6.5pt)
  cdraw.content((11.4, 0.4), [#"the underscore counts as lowercase, so _x never exports"], size: 6pt)
})

== literals

Integers come in four bases with underscores as separators after the
prefix and between digits. `0b101`, `0o600`, `0xBadFace`, `4_2`, and
`0x_67_7a_2f` are all legal, while `42_` and `4__2` are not, and a
leading plain zero is legacy octal, so `0600` is 384:

#listing("go/samples/ch02/lexical.go", first: 79, last: 81, caption: [parse with base 0, exactly what the compiler does])

Rune literals quote one code point with four escape forms: `\x` plus
two hex digits, `\u` plus four, `\U` plus eight, and three octal
digits, plus the single character escapes `\n`, `\t`, `\a`, `\b`,
`\f`, `\r`, `\v`, `\\`. In rune literals `\'` is legal and `\"` is
not, in string literals the reverse.

Strings have exactly two forms, and the difference is bytes versus
characters:

#listing("go/samples/ch02/lexical.go", first: 83, last: 102, caption: [raw versus interpreted strings, and rune escapes])

Back quote strings are raw: newlines and backslashes are literal
characters and the only forbidden content is a back quote itself.
Double quote strings interpret escapes, and here the byte boundary
matters: `\xff` and octal escapes name single bytes, `ÿ` names a
code point and becomes its two byte utf-8 encoding, so
`len(EscapeByte)` is 1 while `len(EscapedChar)` is 2 and only the
second equals the string `"ÿ"`.

#diagram([the literal grammar: four integer bases, rune escape widths, two string forms], length: 13pt, {
  cdraw.rect((0.3, 1.4), (7.5, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 6.2), [integer bases], size: 6.5pt)
  cdraw.content((3.9, 5.1), [0b101 0o600], size: 6pt)
  cdraw.content((3.9, 4.0), [0xBadFace 4_2], size: 6pt)
  cdraw.content((3.9, 2.9), [#"ok: 0x_67_7a_2f"], size: 6pt)
  cdraw.content((3.9, 1.8), [#"bad: 42_ 4__2"], size: 6pt)
  cdraw.rect((8.1, 1.4), (15.3, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.7, 6.2), [rune escapes], size: 6.5pt)
  cdraw.content((11.7, 5.1), [#"\\x + 2 hex"], size: 6pt)
  cdraw.content((11.7, 4.0), [#"\\u + 4 hex"], size: 6pt)
  cdraw.content((11.7, 2.9), [#"\\U + 8 hex"], size: 6pt)
  cdraw.content((11.7, 1.8), [3 octal digits], size: 6pt)
  cdraw.rect((15.9, 1.4), (23.1, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((19.5, 6.2), [strings], size: 6.5pt)
  cdraw.content((19.5, 5.1), [back quotes: raw], size: 6pt)
  cdraw.content((19.5, 4.0), [double: escapes], size: 6pt)
  cdraw.content((19.5, 2.9), [#"\\xff: one byte"], size: 6pt)
  cdraw.content((19.5, 1.8), [#"ÿ: two bytes"], size: 6pt)
})

== semicolon insertion

Go has semicolons in the grammar and none in the source. Two rules
insert them. A semicolon appears after a line's final token when that
token is an identifier, a literal, one of `break`, `continue`,
`fallthrough`, `return`, or one of `++`, `--`, `)`, `]`, `}`. And a
semicolon may be omitted before a closing `)` or `}` so a complex call
fits one line. The scanner output is the proof, and it carries a
fingerprint: an inserted semicolon reports its literal as `"\n"` while
a typed one reports `";"`:

#listing("go/samples/ch02/lexical.go", first: 52, last: 77, caption: [the compiler's scanner, with insertion visible])

The classic wound this design inflicts is a `return` alone on its
line. The semicolon lands immediately after it, the expression on the
next line becomes a separate statement, and the function returns zero
values. The test pins the token stream `return ; x` exactly, and the
same trap bites `break` and `continue`, and any literal or identifier
ended line inside a call argument list. The closing brace on its own
line after a slice literal is not just style: it is what makes the
comma before it legal.

#diagram([semicolon insertion: the line-final token rule, and the return trap], length: 13pt, {
  cdraw.rect((0.5, 2.4), (15.0, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((7.75, 6.1), [line ends with one of], size: 6.5pt)
  cdraw.content((7.75, 5.0), [identifier, literal,], size: 6pt)
  cdraw.content((7.75, 3.9), [break continue fallthrough return,], size: 6pt)
  cdraw.content((7.75, 2.8), [#"++ -- ) ] }"], size: 6pt)
  cdraw.line((5.0, 2.4), (4.6, 1.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((3.4, 1.95), [these], size: 6pt)
  cdraw.line((10.5, 2.4), (15.4, 1.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((13.0, 1.95), [anything else], size: 6pt)
  cdraw.rect((0.6, 0.2), (8.6, 1.4), fill: luma(205), radius: 0.02)
  cdraw.content((4.6, 0.8), [semicolon inserted], size: 6.5pt)
  cdraw.rect((12.0, 0.2), (19.0, 1.4), fill: luma(235), radius: 0.02)
  cdraw.content((15.5, 0.8), [no semicolon], size: 6.5pt)
  cdraw.rect((16.4, 2.4), (23.2, 6.6), fill: luma(240), radius: 0.02)
  cdraw.content((19.8, 6.1), [the trap], size: 6.5pt)
  cdraw.content((19.8, 5.0), [return alone], size: 6pt)
  cdraw.content((19.8, 3.9), [#"becomes return ;"], size: 6pt)
  cdraw.content((19.8, 2.8), [zero values back], size: 6pt)
})

== operators and precedence

Five binary levels, tightest first:

#snippet(
  "5    *  /  %  <<  >>  &  &^\n"
  + "4    +  -  |  ^\n"
  + "3    ==  !=  <  <=  >  >=\n"
  + "2    &&\n"
  + "1    ||\n",
  lang: "go",
)

Unary operators bind tighter than all of these, comparisons yield
untyped booleans, and `&^` is bit clear, `a &^ b` clears the bits of
`a` that `b` sets. Untyped means the value has no type until context
fixes one, a mechanism chapter 8's const section owns. When in doubt,
parenthesize: unlike C there is no
assignment-expression tower, and the fixed table above is the whole
story.

#diagram([five binary levels with unary above them all, comparisons yield untyped bool], length: 13pt, {
  cdraw.rect((6.0, 7.6), (17.6, 8.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.8, 8.1), [unary binds tightest], size: 6.5pt)
  let level(y, w, num, ops) = {
    cdraw.rect((11.8 - w / 2, y), (11.8 + w / 2, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((11.8 - w / 2 + 1.0, y + 0.5), [#num], size: 6.5pt)
    cdraw.content((12.2, y + 0.5), [#ops], size: 6pt)
  }
  level(6.3, 14.8, [5], [#"* / % << >> & &^"])
  level(5.0, 13.2, [4], [#"+ - | ^"])
  level(3.7, 11.6, [3], [#"== != < <= > >="])
  level(2.4, 10.0, [2], [#"&&"])
  level(1.1, 8.4, [1], [#"||"])
  cdraw.content((11.8, 0.2), [&^ is bit clear: a &^ b clears the bits b sets], size: 6pt)
  cdraw.content((11.8, -0.9), [loosest at the bottom, unary above all five], size: 6pt)
})

sources: go.dev/ref/spec, lexical elements section, accessed
2026-09-08, and go 1.27 release notes. Scanner behavior verified by
`go/samples/ch02` tests through go/scanner and go/token.
