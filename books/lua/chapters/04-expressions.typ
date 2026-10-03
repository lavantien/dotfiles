#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= expressions and operators

Operator precedence, lowest to highest: `or`, `and`, comparisons,
bor, bxor, band, shifts, concatenation, addition and subtraction,
multiplication family, unary operators, exponentiation. Two rules in
that list surprise people every time: unary minus binds looser than
`^`, so `-2 ^ 2` is `-4`, and `^` is right associative, so
`2 ^ 3 ^ 2` is 512. `and` and `or` short circuit and return an
operand, not a boolean:

#diagram([the precedence ladder from loosest to tightest, with the two traps], length: 13pt, {
  // twelve rungs, lowest at the bottom, concatenation between shifts and plus
  let rungs = ("or", "and", "comparisons", "|", "~", "&", "<< >>", "..", "+ -", "* / // %", "not # - ~", "^")
  for (i, r) in rungs.enumerate() {
    let hot = i >= 10
    let f = if hot { luma(205) } else { luma(235) }
    cdraw.rect((2.2, 0.5 + i), (10.2, 1.25 + i), fill: f, radius: 0.02)
    cdraw.content((6.2, 0.875 + i), [#r], size: 6pt)
  }
  // the axis arrow
  cdraw.line((1.2, 0.5), (1.2, 12.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.2, 12.8), [binds tighter], size: 6pt)
  // the two trap annotations and the operand note
  cdraw.line((10.2, 11.875), (11.2, 11.9), stroke: luma(120))
  cdraw.content((16.4, 11.9), [2 ^ 3 ^ 2 is 512, \^ right associative], size: 6.5pt)
  cdraw.line((10.2, 10.875), (11.2, 10.9), stroke: luma(120))
  cdraw.content((16.2, 10.7), [-2 ^ 2 is -4, unary minus below \^], size: 6.5pt)
  cdraw.line((10.2, 1.875), (11.2, 1.5), stroke: luma(120))
  cdraw.content((15.6, 1.9), [and / or return an operand], size: 6.5pt)
  cdraw.content((15.6, 0.7), [false or "x" is "x"], size: 6.5pt)
})

#listing("lua/samples/ch04_expressions.lua", first: 5, last: 22, caption: [precedence traps and operand-returning conditionals])

`not nil` is the one true boolean producer at that level; `not 1 == 2`
parses `(not 1) == 2`, which is false, because unary `not` also binds
below comparisons.

== arithmetic

The arithmetic rules divide by operator, not by symmetry. `/` is
always float and yields infinities and NaN quietly. `//` and `%`
floor toward minus infinity and follow the divisor's sign, and on
integers they reject zero outright while on floats they extend to
infinity:

#listing("lua/samples/ch04_expressions.lua", first: 30, last: 59, caption: [floor division, modulo sign, division's float world])

#diagram([the arithmetic rules, operator by operator], length: 13pt, {
  // two column matrix: operator cells left, rules right
  cdraw.rect((0.5, 2.7), (21.5, 11.4), stroke: luma(150), radius: 0.02)
  cdraw.line((0.5, 10.2), (21.5, 10.2), stroke: luma(150))
  cdraw.line((4.5, 2.7), (4.5, 11.4), stroke: luma(150))
  for y in (8.7, 7.2, 5.7, 4.2) {
    cdraw.line((0.5, y), (21.5, y), stroke: luma(220))
  }
  cdraw.content((2.5, 10.8), [operator], size: 6.5pt)
  cdraw.content((13.0, 10.8), [rule], size: 6.5pt)
  let row(y, op, rule) = {
    cdraw.content((2.5, y), op, size: 6pt)
    cdraw.content((13.0, y), rule, size: 6pt)
  }
  row(9.45, [+ - \*], [integer wrap, no promotion: maxinteger \* 2 is -2])
  row(7.95, [/], [always float, infinities and nan arrive quietly])
  row(6.45, [\/\/ %], [floor toward minus infinity, sign follows the divisor])
  row(4.95, [\/\/ 0, % 0], [integers reject zero, floats reach inf or nan])
  row(3.45, [\^], [always float, 2 \^ 10 is 1024.0])
})

`^` is always float, so `2 ^ 10` is `1024.0` and a negative base with
a fractional exponent is NaN. Integer arithmetic wraps in two's
complement, `math.maxinteger * 2` is `-2`, with no promotion to
float, ever.

#callout("pitfall", "integer zero division has two spellings", [
  Integer `// 0` says `attempt to divide by zero`; integer `% 0` says
  `attempt to perform 'n%0'`. Both spellings are unchanged since
  5.3, and the suite pins both.
])

== bitwise

Six operators over 64 bit integers only, no float mixing unless the
float has an exact integer value. Shifts reverse direction for
negative counts, `1 << -1` is `1 >> 1`, and shifting by 64 or more
saturates to zero rather than masking the count:

#listing("lua/samples/ch04_expressions.lua", first: 67, last: 80, caption: [the 64 bit unsigned view and reversing shifts])

#diagram([the six bitwise operators over the 64 bit unsigned view], length: 13pt, {
  cdraw.rect((0.5, 4.1), (21.5, 11.6), stroke: luma(150), radius: 0.02)
  cdraw.line((0.5, 10.4), (21.5, 10.4), stroke: luma(150))
  cdraw.line((4.5, 4.1), (4.5, 11.6), stroke: luma(150))
  for y in (8.9, 7.4, 5.9) {
    cdraw.line((0.5, y), (21.5, y), stroke: luma(220))
  }
  cdraw.content((2.5, 11.0), [operator], size: 6.5pt)
  cdraw.content((13.0, 11.0), [rule], size: 6.5pt)
  let row(y, op, rule) = {
    cdraw.content((2.5, y), op, size: 6pt)
    cdraw.content((13.0, y), rule, size: 6pt)
  }
  row(9.65, [& | \~], [over the 64 bit pattern, integers only])
  row(8.15, [\<\< \>\>], [negative counts reverse direction, 1 \<\< -1 is 1 \>\> 1])
  row(6.65, [by 64 or more], [saturates to zero, the count is not masked])
  row(5.15, [floats], [join only with an exact integer value, 1.5 | 2 errors])
  // minus one as the machine sees it
  for i in range(8) {
    cdraw.rect((5.9 + i * 1.2, 2.2), (7.1 + i * 1.2, 3.2), fill: luma(205), radius: 0.02)
    cdraw.content((6.5 + i * 1.2, 2.7), [ff], size: 6pt)
  }
  cdraw.content((10.7, 1.4), [minus one is all ones in the unsigned view], size: 6.5pt)
})

== comparison and coercion

Mixed integer float comparisons are exact, not approximate:
`2 ^ 53 == 9007199254740993` is false, `2 ^ 53 == 9007199254740992`
is true, and `math.maxinteger + 0.0` rounds to a float that no longer
equals the integer it came from. Strings compare in byte order, and a
number never compares against a string, `1 == "1"` is false and
`1 < "a"` is an error.

Numbers coerce into concatenation with the same format `tostring`
uses, integral floats keeping their `.0`. Strings coerce into
arithmetic when they read as numbers, hex and exponent forms included,
keeping the subtype the numeral implies. Bitwise operators refuse
strings entirely. 5.5's error messages for failed string arithmetic
name the operation and both operand types:

#listing("lua/samples/ch04_expressions.lua", first: 89, last: 114, caption: [concat formats, string arithmetic, and the new message shape])

#flow(
  [which operators coerce which operand types, and where the boundary is],
  node((0, 0), [a pair of values meets an operator]),
  node((0, 1.6), [comparison?]),
  node((-2.9, 1.6), [numbers exact, #linebreak() strings byte order]),
  node((0, 3.2), [arithmetic?]),
  node((-2.9, 3.2), [strings turn #linebreak() into numbers]),
  node((0, 4.8), [concatenation?]),
  node((-2.9, 4.8), [numbers format #linebreak() into strings]),
  node((0, 6.4), [bitwise?]),
  node((-2.9, 6.4), [nothing coerces, #linebreak() strings error]),
  node((2.9, 1.6), [mixed int float is exact, #linebreak() 1 == "1" stays false]),
  node((2.9, 3.2), [the subtype follows #linebreak() the numeral]),
  node((2.9, 4.8), [integral floats #linebreak() keep the .0]),
  node((2.9, 6.4), [a float joins only #linebreak() when exactly integral]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (-2.9, 1.6), "-|>", label: [yes]),
  edge((0, 1.6), (0, 3.2), "-|>", label: [no]),
  edge((0, 3.2), (-2.9, 3.2), "-|>", label: [yes]),
  edge((0, 3.2), (0, 4.8), "-|>", label: [no]),
  edge((0, 4.8), (-2.9, 4.8), "-|>", label: [yes]),
  edge((0, 4.8), (0, 6.4), "-|>", label: [no]),
  edge((0, 6.4), (-2.9, 6.4), "-|>", label: [yes]),
)

== constructors and length

A constructor takes positional items, `name = value` sugar for string
keys, `[exp] = value` for computed keys, and nested constructors as
items, with commas or semicolons freely as separators. The assignment
order inside a constructor is unspecified, and the observed behavior
is that keyed fields assign before positional ones, so a positional
item wins a key collision in either textual order:

#listing("lua/samples/ch04_expressions.lua", first: 116, last: 129, caption: [every key form, and positional winning the collision])

#diagram([constructor collisions and the length border], length: 13pt, {
  // panel a: the same constructor in either order
  cdraw.content((4.8, 12.0), [the same constructor, either order], size: 6.5pt)
  cdraw.content((5.0, 10.6), [\{ \[1\] = "k", "p" \}], size: 6pt)
  cdraw.line((5.0, 10.1), (5.0, 9.3), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.5, 8.1), (7.5, 9.3), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 8.7), [1 → "p"], size: 6pt)
  cdraw.content((5.0, 6.9), [\{ "p", \[1\] = "k" \}], size: 6pt)
  cdraw.line((5.0, 6.4), (5.0, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.5, 4.4), (7.5, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 5.0), [1 → "p"], size: 6pt)
  cdraw.content((5.0, 3.1), [keyed fields assign first,], size: 6.5pt)
  cdraw.content((5.0, 1.9), [the positional item wins in either order], size: 6.5pt)
  // panel b: the length operator on a holed table
  cdraw.content((17.9, 12.0), [the length operator on a holed table], size: 6.5pt)
  let vals = ("10", "20", "30", "nil", "50")
  for i in range(5) {
    let f = if i == 3 { luma(205) } else { luma(235) }
    cdraw.rect((12.7 + i * 1.9, 8.1), (14.6 + i * 1.9, 9.3), fill: f, radius: 0.02)
    cdraw.content((13.65 + i * 1.9, 8.7), [#vals.at(i)], size: 6pt)
    cdraw.content((13.65 + i * 1.9, 7.6), [#(i + 1)], size: 6pt)
  }
  cdraw.line((17.45, 7.0), (17.45, 6.2), stroke: luma(120))
  cdraw.content((17.45, 5.7), [a border], size: 6pt)
  cdraw.line((21.25, 7.0), (21.25, 6.2), stroke: luma(120))
  cdraw.content((21.25, 5.7), [a border], size: 6pt)
  cdraw.content((17.4, 4.3), [\# returns any border, 3 or 5 here,], size: 6.5pt)
  cdraw.content((17.4, 3.1), [only a full sequence makes it the count], size: 6.5pt)
})

`#` is byte count on strings. On tables it is a border, any positive
index where the next index is nil, which on a contiguous sequence is
the count but on a holed table is only guaranteed to be one of the
borders:

#listing("lua/samples/ch04_expressions.lua", first: 131, last: 138, caption: [length as border, not count])

sources: lua.org manual 5.5 sections 3.4.1 through 3.4.7, accessed
2026-09-08. Error message wording verified live with lua 5.5.1 against
the 5.4 spellings, 15 tests green through `make verify-lua`.
