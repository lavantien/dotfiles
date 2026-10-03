#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= strings, bytes, and text

Text and bytes are different types with different jobs, and most encoding
bugs are a missing conversion between them. This chapter builds the model
from the bottom: `str` as code points, `bytes`, `bytearray`, and
`memoryview` as byte sequences with the encode/decode discipline between
them, the `re` module over text, and the four formatting mechanisms
python already carries, and the 3.14 addition. Every claim is
pinned by one of the 44 checks in the four samples on cpython 3.14.7.

== str and the unicode model

A `str` is a sequence of unicode code points, not bytes and not
graphemes. The same character can be spelled several ways, and
normalization is the discipline that makes comparisons honest:

#listing("python/samples/src/Ch05/strmodel.py", first: 19, last: 26, caption: [one code point composed, two decomposed, NFC reuniting them])

`"é"` composed is length 1, its NFD form is a base letter plus a
combining mark, length 2, and neither `==` nor `len` treats them alike.
Indexing follows the same unit:

#listing("python/samples/src/Ch05/strmodel.py", first: 28, last: 38, caption: [one astral code point is one element, slices step by code point, ord and chr])

An emoji from the astral planes is one `str` element here, which is the
practical difference from utf-16 languages where such characters split
across two units. Ordering is by code point, so uppercase sorts before
lowercase, and the type is immutable, so every method returns a new
string:

#listing("python/samples/src/Ch05/strmodel.py", first: 40, last: 50, caption: [code point ordering, methods building new strings, and tuple membership tests])

#callout("pitfall", "code points are not graphemes", [
  `len` counts code points, so `"é"` NFD reports 2 while a user sees one
  character, and flag-plus-skin-tone emoji count as several. Comparisons
  across spellings need `unicodedata.normalize` first, and text that
  must round trip through another system should agree on NFC or NFD up
  front. Byte counts are a third number again, and belong to the next
  section.
])

#diagram([the same character, three spellings, and what indexing sees], length: 13pt, {
  cdraw.content((2.0, 8.6), [composed, NFC], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 7.0), (3.4, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((2.0, 7.5), [é], wrap: text.with(size: 10pt))
  cdraw.content((2.0, 6.3), [U+00E9, len 1], wrap: text.with(size: 6pt))
  cdraw.content((11.3, 8.6), [decomposed, NFD], wrap: text.with(size: 6.5pt))
  cdraw.rect((8.4, 7.0), (11.2, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((9.8, 7.5), [e], wrap: text.with(size: 10pt))
  cdraw.rect((11.4, 7.0), (14.2, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((12.8, 7.5), [◌́], wrap: text.with(size: 10pt))
  cdraw.content((11.3, 6.3), [e plus U+0301, len 2], wrap: text.with(size: 6pt))
  cdraw.line((3.6, 7.5), (8.2, 7.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.9, 7.0), [`NFD` splits], wrap: text.with(size: 5.5pt))
  cdraw.line((14.4, 7.5), (16.6, 7.5), stroke: luma(100), mark: (end: "<"))
  cdraw.content((15.4, 7.0), [`NFC` rejoins], wrap: text.with(size: 5.5pt))
  cdraw.content((18.7, 8.6), [astral plane], wrap: text.with(size: 6.5pt))
  cdraw.rect((16.8, 7.0), (20.6, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((18.7, 7.5), [😀], wrap: text.with(size: 10pt))
  cdraw.content((18.7, 6.3), [U+1F600, len 1], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 5.2), [indexing, slicing, `len`, and ordering all step by code point], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 4.2), [a user visible character may span several cells: #linebreak() accent marks, emoji modifiers, joined scripts], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 3.0), [byte counts live on the other side of `encode`, #linebreak() utf-8 spends 1 to 4 bytes per code point], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 1.6), [comparison across spellings: #linebreak() normalize both sides first], wrap: text.with(size: 6pt))
})

== bytes, bytearray, memoryview

`bytes` literals look like strings with a `b`, but they hold byte values
and accept only ascii text or escapes:

#listing("python/samples/src/Ch05/bytesio.py", first: 19, last: 25, caption: [byte values, and the ascii rule enforced at compile time])

Encoding is the bridge, and it is a choice, not a property of the text.
The same `é` becomes two bytes in utf-8 and one in latin-1:

#listing("python/samples/src/Ch05/bytesio.py", first: 27, last: 31, caption: [the encoding picks the bytes])

Decoding is where the errors surface, and `errors=` is the policy dial.
Strict is the default and the right default:

#listing("python/samples/src/Ch05/bytesio.py", first: 33, last: 45, caption: [strict refusing, replace substituting, ignore dropping, surrogateescape round tripping])

`surrogateescape` is the handler for bytes that are not valid utf-8 but
must survive a round trip, filenames on unix being the classic case. The
mutable side and the zero copy view follow:

#listing("python/samples/src/Ch05/bytesio.py", first: 47, last: 60, caption: [memoryview sharing the buffer, bytes refusing mutation, bytearray accepting it])

`memoryview` is the read or write window over another object's buffer
without copying, the buffer protocol that c extensions and `struct` speak.
`struct` closes the section by making byte order explicit instead of
inherited:

#listing("python/samples/src/Ch05/bytesio.py", first: 62, last: 68, caption: [pinned little endian packing, cross checked against the machine's order])

#callout("warning", "never let the encoding be ambient", [
  Every `open()`, `encode`, and `decode` in this book names its encoding,
  because the alternative is a platform default, and windows and the
container this code ships to may disagree. The `errors=` policy deserves
the same explicitness: strict unless the bytes are somebody else's
problem, `surrogateescape` when they must round trip. The files chapter
makes `encoding=` a mandatory argument in every example,
#xref-to("python", "files").
])

#diagram([one word through encode and decode, and where each error policy lands], length: 13pt, {
  cdraw.rect((0.6, 5.6), (6.2, 6.8), fill: luma(205), radius: 0.02)
  cdraw.content((3.4, 6.2), [`str`: `héllo`, 5 code points], wrap: text.with(size: 6pt))
  cdraw.content((9.9, 7.3), [`.encode("utf-8")`], wrap: text.with(size: 6pt))
  cdraw.content((9.9, 4.9), [`.encode("latin-1")`], wrap: text.with(size: 6pt))
  let cellx = (7.6, 9.0, 10.4, 11.8, 13.2, 14.6)
  let utf8 = ("68", "c3", "a9", "6c", "6c", "6f")
  for (i, t) in utf8.enumerate() {
    cdraw.rect((cellx.at(i), 6.2), (cellx.at(i) + 1.2, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((cellx.at(i) + 0.6, 6.6), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((11.4, 5.8), [6 bytes, é is c3 a9], wrap: text.with(size: 6pt))
  let lat = ("68", "e9", "6c", "6c", "6f")
  for (i, t) in lat.enumerate() {
    cdraw.rect((7.6 + i * 1.4, 3.8), (8.8 + i * 1.4, 4.6), fill: luma(235), radius: 0.02)
    cdraw.content((8.3 + i * 1.4, 4.2), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((11.0, 3.4), [5 bytes, é is e9], wrap: text.with(size: 6pt))
  cdraw.line((4.4, 6.8), (8.2, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.4, 5.6), (8.2, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.4, 7.6), [decode back, #linebreak() strict default], wrap: text.with(size: 6pt))
  cdraw.content((18.4, 6.5), [`b"\\x80"`: #linebreak() UnicodeDecodeError], wrap: text.with(size: 6pt))
  cdraw.content((18.4, 5.6), [`replace`: one U+FFFD], wrap: text.with(size: 6pt))
  cdraw.content((18.4, 4.9), [`ignore`: bad bytes dropped], wrap: text.with(size: 6pt))
  cdraw.content((18.4, 3.8), [`surrogateescape`: #linebreak() byte in, same byte out], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 2.2), [memoryview: a window over the buffer, writes through, #linebreak() bytearray: the mutable bytes, item assignment by int], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 1.0), [struct pins the byte order: `"\<I"` for 1 is 01 00 00 00, #linebreak() matching this little endian machine but true on any machine], wrap: text.with(size: 6pt))
})

== re in practice

Three entry points anchor every regex question: `match` anchors at the
start, `search` scans, `fullmatch` demands the whole text:

#listing("python/samples/src/Ch05/rex.py", first: 19, last: 32, caption: [one pattern compiled once, and the three anchoring answers])

Compiling once matters when the pattern is reused, both for the cache and
for readability. Groups come positional and named, and `finditer` walks
every match with its spans:

#listing("python/samples/src/Ch05/rex.py", first: 34, last: 45, caption: [named groups reading back by word, and finditer's span list])

Substitution accepts a function run per match, which is how casing,
lookups, and escaping decisions get made per hit:

#listing("python/samples/src/Ch05/rex.py", first: 47, last: 51, caption: [a function title casing each word])

The quantifier temperament is the classic regex trap, and raw strings are
the discipline that keeps backslashes sane:

#listing("python/samples/src/Ch05/rex.py", first: 53, last: 69, caption: [greedy against lazy on the same input, raw patterns, and re.escape for foreign text])

`<.*>` eats both tags because `.` and `*` are greedy by default, `.*?`
stops at the first `>`. In a plain string literal `"\\d"` is the only way
to hand the engine `\d`, while `r"\d"` hands it over directly, which is
why regexes are written raw. When the pattern must contain user text,
`re.escape` quotes its metacharacters.

#diagram([choosing the matcher, and the two quantifier temperaments], length: 13pt, {
  cdraw.rect((0.6, 5.6), (6.6, 6.8), fill: luma(205), radius: 0.02)
  cdraw.content((3.6, 6.2), [text and a pattern], wrap: text.with(size: 6.5pt))
  let opt(x, y, t) = {
    cdraw.rect((x, y), (x + 6.6, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.3, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  opt(15.0, 8.2, [`.match`: anchored #linebreak() at the start])
  opt(15.0, 6.9, [`.search`: first match anywhere])
  opt(15.0, 5.6, [`.fullmatch`: the whole #linebreak() text, nothing more])
  for y in (8.7, 7.4, 6.1) {
    cdraw.line((6.6, 6.2), (15.0, y), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  }
  cdraw.content((9.4, 7.9), [where must it sit?], wrap: text.with(size: 6pt))
  cdraw.content((4.4, 4.6), [on `<a><b>`], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 3.0), (6.6, 4.2), fill: luma(248), radius: 0.02)
  cdraw.content((3.6, 3.6), [`<.*>`: `<a><b>`, greedy], wrap: text.with(size: 6pt))
  cdraw.rect((7.6, 3.0), (13.6, 4.2), fill: luma(248), radius: 0.02)
  cdraw.content((10.6, 3.6), [`<.*?>`: `<a>`, lazy], wrap: text.with(size: 6pt))
  cdraw.content((5.6, 2.4), [the engine backtracks a greedy star down to the last fit, #linebreak() a lazy star stops at the first fit], wrap: text.with(size: 6pt))
  cdraw.content((17.0, 1.6), [`sub(fn)` calls a function #linebreak() per match, `re.escape` quotes], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 1.0), [compile once per reused pattern, write patterns raw], wrap: text.with(size: 6pt))
})

== formatting

Four mechanisms coexist, each a generation. F-strings are the working
default, and their `=` specifier is the debugging form:

#listing("python/samples/src/Ch05/fmt.py", first: 19, last: 29, caption: [the = specifier keeping the expression text, !r, and the numeric specs])

The space around `=` survives into the output, which is the point. Since
3.12 the tokenizer owns f-strings (PEP 701), so a nested field may reuse
the outer quotes:

#listing("python/samples/src/Ch05/fmt.py", first: 31, last: 33, caption: [the same quote nesting inside the field])

That check compiles its source through a string, because the formatter
normalizes the nested quote spelling when it appears as a literal, the
same listing stability discipline chapter 2 applies to line joins. The
format spec mini language is shared by every mechanism, and a class hooks
it through `__format__`:

#listing("python/samples/src/Ch05/fmt.py", first: 36, last: 48, caption: [a class receiving its spec verbatim, and str.format filling both field kinds])

The older pair, printf style `%` and `string.Template`, still pays rent in
old code and in user supplied templates:

#listing("python/samples/src/Ch05/fmt.py", first: 50, last: 55, caption: [% still working, and safe_substitute leaving unknown slots alone])

3.14 adds a fifth mechanism, the template string (PEP 750). A `t` prefix
builds a `Template` object instead of a `str`, holding the literal parts
and the unevaluated interpolations side by side:

#listing("python/samples/src/Ch05/fmt.py", first: 57, last: 70, caption: [t-strings separating literal text from values, with the expression source intact])

The value is evaluated, but no formatting decision has been made yet:
the consumer of the template chooses how to render, which is what makes
sql and html escaping possible. An f-string is a finished string, a
t-string is a request.

#diagram([five formatting mechanisms, one per generation], length: 13pt, {
  let rows = (
    ([f-string], [evaluated now, the default for display], [`f"{x:03}"`]),
    ([format spec], [fill, align, sign, width, precision, type], [`f"{1234.5:,.1f}"`]),
    ([`__format__`], [a class answers the spec itself], [`format(obj, "x")`]),
    ([`str.format`], [fields filled by position or name], [`"{0} {name}"`]),
    ([`%`], [printf style, legacy glue], [`"%s-%03d" % t`]),
    ([Template], [user editable templates, safe substitute], [`"hi $who"`]),
    ([t-string], [3.14, structure before rendering], [`t"hi {name}"`]),
  )
  for (i, row) in rows.enumerate() {
    let y = 8.0 - i * 1.12
    cdraw.rect((0.6, y - 0.48), (5.0, y + 0.48), fill: luma(235), radius: 0.02)
    cdraw.content((2.8, y), row.at(0), wrap: text.with(size: 6.5pt))
    cdraw.rect((5.2, y - 0.48), (14.4, y + 0.48), fill: luma(248), radius: 0.02)
    cdraw.content((9.8, y), row.at(1), wrap: text.with(size: 6pt))
    cdraw.rect((14.6, y - 0.48), (21.6, y + 0.48), fill: luma(248), radius: 0.02)
    cdraw.content((18.1, y), row.at(2), wrap: text.with(size: 6pt))
  }
  cdraw.content((11.1, 0.2), [an f-string renders immediately, a t-string hands the pieces to code that decides], wrap: text.with(size: 6pt))
})

#callout("verify", "44 checks, and one formatter fight", [
  The samples ran green on their first execution, but not on their first
  formatting pass: `ruff format` collapsed the nested same-quote f-string
  into single-quoted inner keys and would have silently deleted the PEP
  701 demonstration. The check moved into a `compile()` probe, the same
  treatment the lexical chapter gives its line joins, and the pinned
  listing shows the mechanism instead of the formatter's preference.
  Sample behavior verified by `make verify-py`, 44 checks in chapter 5 of
  the samples suite.
])

sources: docs.python.org/3/library/stdtypes.html (str, bytes, bytearray,
memoryview and the buffer protocol),
docs.python.org/3/howto/unicode.html (code points, normalization
practice), docs.python.org/3/library/unicodedata.html (normalize,
combining), docs.python.org/3/library/re.html (match, search, fullmatch,
groups, finditer, sub, escaping, greedy against lazy),
docs.python.org/3/reference/lexical_analysis.html (f-strings, format
specs, the t prefix), docs.python.org/3/library/string.html (Template,
the format spec mini language), docs.python.org/3/library/struct.html
(byte order characters), docs.python.org/3/whatsnew/3.14.html (t-strings,
PEP 750), peps.python.org/pep-0701/ and pep-0750/, all accessed
2026-09-12; the ascii literal rejection, the decode handler outputs, the
struct byte order, and the formatter behavior were probed on this machine
the same day. Sample behavior verified by `make verify-py`, 44 checks in
chapter 5.
