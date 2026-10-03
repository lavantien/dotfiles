#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= stdlib 1: basic, string patterns, utf8

The basic library is the prelude that needs no prefix. The chapter
picks up the pieces not already spent in earlier chapters: `select`
from both ends, `tonumber` with a base, `ipairs` versus `pairs` on a
holed table, `xpcall` with a handler, `rawlen` and `rawequal`, and
`tostring` honoring the `__tostring` metamethod. Every string method
call in this book, like `("abc"):upper()`, is the string metatable
from #xref-to("lua", "values") at work.

#listing("lua/samples/ch11_stdlib1.lua", first: 130, last: 158, caption: [base parsing, select, the two iteration protocols])
#listing("lua/samples/ch11_stdlib1.lua", first: 159, last: 174, caption: [xpcall handlers, the tostring metamethod, and raw access])

#diagram([the basic library's leftover surface, one row each], length: 13pt, {
  cdraw.rect((0.5, 2.6), (21.5, 11.6), stroke: luma(150), radius: 0.02)
  cdraw.line((0.5, 10.4), (21.5, 10.4), stroke: luma(150))
  cdraw.line((5.5, 2.6), (5.5, 11.6), stroke: luma(150))
  for y in (9.1, 7.8, 6.5, 5.2, 3.9) {
    cdraw.line((0.5, y), (21.5, y), stroke: luma(220))
  }
  cdraw.content((3.0, 11.0), [call], size: 6.5pt)
  cdraw.content((13.5, 11.0), [what it does], size: 6.5pt)
  let row(y, op, rule) = {
    cdraw.content((3.0, y), op, size: 6pt)
    cdraw.content((13.5, y), rule, size: 6pt)
  }
  row(9.75, [select], [counts from either end, -1 is the last])
  row(8.45, [tonumber], [a base argument reads 2 through 36])
  row(7.15, [ipairs, pairs], [ipairs stops at the first nil, pairs walks every key])
  row(5.85, [xpcall], [the handler runs at the error site, stack still intact])
  row(4.55, [the raw family], [rawequal, rawlen, rawget, rawset bypass metatables])
  row(3.25, [tostring], [honors \_\_tostring, else the type and address format])
})

== the string library

`sub` indexes negatively from the end, `rep` takes a separator,
`byte` and `char` are byte level, and `string.format` carries the c
printf surface with one lua addition, `%q`, which quotes a string so
`load` can read it back:

#listing("lua/samples/ch11_stdlib1.lua", first: 12, last: 36, caption: [indexing, bytes, and the format surface])

#diagram([the string as one byte line, indexed from both ends], length: 13pt, {
  // the bytes with positive indices above and negative below
  let chars = ("h", "e", "l", "l", "o")
  for (i, c) in chars.enumerate() {
    let x = 4.6 + i * 1.55
    cdraw.rect((x, 7.0), (x + 1.4, 8.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.7, 7.6), [#c], size: 6pt)
    cdraw.content((x + 0.7, 8.7), [#(i + 1)], size: 6pt)
    cdraw.content((x + 0.7, 6.4), [#(i - 5)], size: 6pt)
  }
  // sub spans as brackets under the line, ticks on cell boundaries
  cdraw.line((6.15, 5.8), (6.15, 5.55), (10.65, 5.55), (10.65, 5.8), stroke: luma(120))
  cdraw.content((2.6, 5.65), [sub(2, 4)], size: 6pt)
  cdraw.content((11.4, 5.65), ["ell"], size: 6pt)
  cdraw.line((7.7, 4.4), (7.7, 4.15), (12.2, 4.15), (12.2, 4.4), stroke: luma(120))
  cdraw.content((2.6, 4.25), [sub(-3, -1)], size: 6pt)
  cdraw.content((12.9, 4.25), ["llo"], size: 6pt)
  // the rest of the surface
  cdraw.content((10.9, 2.7), [byte and char are the byte level round trip], size: 6.5pt)
  cdraw.content((10.9, 1.5), [format is the c printf surface, %q quotes for load], size: 6.5pt)
})

== patterns

Patterns are not regular expressions. They are a smaller matcher
with single character classes, `%d` `%a` `%s`, sets and negated sets,
and four repetitions: `+` one or more greedy, `*` zero or more
greedy, `-` zero or more lazy, `?` optional. Anchors `^` and `$`
apply at pattern position, so `^%d+$` means the whole string is
digits:

#listing("lua/samples/ch11_stdlib1.lua", first: 38, last: 59, caption: [classes, sets, lazy versus greedy, whole string anchors])

#diagram([the whole pattern matcher in one table], length: 13pt, {
  cdraw.rect((0.5, 0.6), (21.5, 12.2), stroke: luma(150), radius: 0.02)
  cdraw.line((0.5, 11.0), (21.5, 11.0), stroke: luma(150))
  cdraw.line((6.0, 0.6), (6.0, 12.2), stroke: luma(150))
  for y in (9.7, 8.4, 7.1, 5.8, 4.5, 3.2, 1.9) {
    cdraw.line((0.5, y), (21.5, y), stroke: luma(220))
  }
  cdraw.content((3.25, 11.6), [kind], size: 6.5pt)
  cdraw.content((13.75, 11.6), [spells and reads], size: 6.5pt)
  let row(y, kind, rule) = {
    cdraw.content((3.25, y), kind, size: 6pt)
    cdraw.content((13.75, y), rule, size: 6pt)
  }
  row(10.35, [classes], [\%d \%a \%s \%w, one character each, uppercase negates])
  row(9.05, [sets], [\[aeiou\] any of, \[\^aeiou\] none of])
  row(7.75, [greedy], [+ one or more, \* zero or more, eat all they can])
  row(6.45, [lazy], [- zero or more, stop at the first fit])
  row(5.15, [optional], [? zero or one])
  row(3.85, [anchors], [\^ and \$, \^%d+\$ demands all digits])
  row(2.55, [captures], [(p) the match, () the position])
  row(1.25, [specials], [%bxy a balanced pair, %f\[set\] a frontier into it])
})

Captures come in two flavors. Parenthesized patterns capture what
they match, empty parentheses capture the position, and `find`,
`match`, and `gmatch` all return them:

#listing("lua/samples/ch11_stdlib1.lua", first: 61, last: 69, caption: [position captures, balanced pairs, frontier])

Two special patterns have no regex equivalent worth confusing them
with: `%bxy` matches balanced pairs, and `%f[set]` matches a frontier
transition into the set:

#listing("lua/samples/ch11_stdlib1.lua", first: 65, last: 69, caption: [balanced match, frontier uppercasing])

`gsub` takes its replacement as a string with `%n` captures and
`%0`, a table keyed by the match, or a function called per match.
Both the table and the function keep the original text when they
yield nil or false, and the second return counts matches:

#listing("lua/samples/ch11_stdlib1.lua", first: 71, last: 95, caption: [the three replacement forms and the keep rule])

`find` grows a plain flag for literal searches and an init position
that can be negative, and `gmatch` walks matches as an iterator that
fits the generic for directly.

#listing("lua/samples/ch11_stdlib1.lua", first: 87, last: 101, caption: [plain find with init, gmatch walking captures])

== binary packing

`string.pack` and `string.unpack` implement the manual's binary
formats: endian prefixes, integer widths, `z` for zero terminated
strings, `s` for size prefixed ones:

#listing("lua/samples/ch11_stdlib1.lua", first: 103, last: 112, caption: [round trip, byte order, sized strings])

#diagram([a pack format string over the byte lanes it produces], length: 13pt, {
  // format tokens above the lanes they own
  cdraw.content((4.0, 9.9), [\< i2], size: 6pt)
  cdraw.content((9.5, 9.9), [z], size: 6pt)
  cdraw.content((16.0, 9.9), [s1], size: 6pt)
  // the lanes: a two byte int, a zero terminated string, a sized one
  let lane(x0, x1, txt, hot) = {
    let f = if hot { luma(205) } else { luma(235) }
    cdraw.rect((x0, 6.6), (x1, 7.8), fill: f, radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 7.2), txt, size: 6pt)
  }
  lane(2.0, 3.4, [01], false)
  lane(3.6, 5.0, [00], false)
  lane(6.8, 8.2, ["h"], false)
  lane(8.4, 9.8, ["i"], false)
  lane(10.0, 11.4, [\\0], true)
  lane(13.6, 15.0, [01], true)
  lane(15.2, 16.6, ["!"], false)
  // each token connects to its group
  cdraw.line((4.0, 9.55), (3.5, 7.9), stroke: luma(120))
  cdraw.line((9.5, 9.55), (9.1, 7.9), stroke: luma(120))
  cdraw.line((16.0, 9.55), (15.9, 7.9), stroke: luma(120))
  // annotations
  cdraw.content((11.0, 5.6), [the prefix sets byte order, \< little, \> big, = native], size: 6.5pt)
  cdraw.content((11.0, 4.4), [z ends at the zero byte, s1 is one size byte then the string], size: 6.5pt)
  cdraw.content((11.0, 3.2), [unpack reads the same lanes back out], size: 6.5pt)
})

== utf8

The `utf8` library counts code points while `#` counts bytes, exposes
`charpattern` as a plain string, itself usable inside larger
patterns, and reports bad encodings by returning nil plus the byte
position of the trouble:

#listing("lua/samples/ch11_stdlib1.lua", first: 114, last: 128, caption: [code points, offsets, codes, invalid encoding])

#diagram([the same text as six bytes and as five code points], length: 13pt, {
  // code points above, the accented one spanning two bytes
  cdraw.content((5.45, 10.3), [h = 1], size: 6pt)
  cdraw.content((9.2, 10.3), [é = 2], size: 6pt)
  cdraw.content((12.95, 10.3), [l = 3], size: 6pt)
  cdraw.content((15.45, 10.3), [l = 4], size: 6pt)
  cdraw.content((17.95, 10.3), [o = 5], size: 6pt)
  cdraw.line((6.8, 10.0), (6.8, 9.7), (11.6, 9.7), (11.6, 10.0), stroke: luma(120))
  // the byte strip
  let bytes = ("h", "c3", "a9", "l", "l", "o")
  for (i, b) in bytes.enumerate() {
    let x = 4.3 + i * 2.5
    let hot = i == 1 or i == 2
    let f = if hot { luma(205) } else { luma(235) }
    cdraw.rect((x, 6.6), (x + 2.3, 7.8), fill: f, radius: 0.02)
    cdraw.content((x + 1.15, 7.2), [#b], size: 6pt)
    cdraw.content((x + 1.15, 6.0), [#(i + 1)], size: 6pt)
  }
  // the two counts and the failure mode
  cdraw.content((11.0, 4.6), [utf8.len counts code points, 5], size: 6.5pt)
  cdraw.content((11.0, 3.4), [the \# operator counts bytes, 6], size: 6.5pt)
  cdraw.content((11.0, 2.2), [offsets are byte positions, the shaded pair is one character], size: 6.5pt)
  cdraw.content((11.0, 1.0), [a bad encoding reports nil plus the byte position], size: 6.5pt)
})

sources: lua.org manual 5.5 sections 6.2, 6.5, 6.6, accessed
2026-09-08. Pattern semantics and replacement rules verified live
with lua 5.5.1, 19 tests green through `make verify-lua`.
