#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= stdlib 2: table, math, io, os

The table library is five functions over the one data structure.
`insert` appends or shifts, `remove` returns what it removed,
`concat` joins a range and errors on holes with the index in the
message, `move` copies a range that may overlap itself, and
`pack`/`unpack` are the table shaped view of an argument list, with
`n` as the only honest length when the list holds nil:

#listing("lua/samples/ch12_stdlib2.lua", first: 5, last: 40, caption: [the five table operations])

#diagram([the five table operations over the array part], length: 13pt, {
  // one row per operation: name and quirk left, before cells, arrow, after cells
  let cells(y, x0, vals, hot) = {
    for (i, v) in vals.enumerate() {
      let f = if hot.at(i) { luma(205) } else { luma(235) }
      cdraw.rect((x0 + i * 1.22, y - 0.5), (x0 + i * 1.22 + 1.12, y + 0.5), fill: f, radius: 0.02)
      cdraw.content((x0 + i * 1.22 + 0.56, y), v, size: 6pt)
    }
  }
  let name(y, call, quirk) = {
    cdraw.content((2.55, y + 0.4), call, size: 6pt)
    cdraw.content((2.55, y - 0.68), quirk, size: 6pt)
  }
  let arrow(y) = cdraw.line((11.1, y), (12.3, y), stroke: luma(100), mark: (end: ">"))
  name(10.7, [insert(2, 15)], [shifts up])
  cells(10.7, 4.9, ([10], [20], [30]), (false, false, false))
  arrow(10.7)
  cells(10.7, 12.5, ([10], [15], [20], [30]), (false, true, false, false))
  name(8.4, [remove(2)], [returns it])
  cells(8.4, 4.9, ([10], [15], [20], [30]), (false, true, false, false))
  arrow(8.4)
  cells(8.4, 12.5, ([10], [20], [30]), (false, false, false))
  name(6.1, [concat(sep)], [no holes])
  cells(6.1, 4.9, ([a], [b], [nil], [c]), (false, false, true, false))
  arrow(6.1)
  cdraw.rect((12.5, 5.6), (17.5, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((15.0, 6.1), [error, index 3], size: 6pt)
  name(3.8, [move(1, 3, 2)], [overlap ok])
  cells(3.8, 4.9, ([10], [20], [30], [40], [50]), (false, false, false, false, false))
  arrow(3.8)
  cells(3.8, 12.5, ([10], [10], [20], [30], [50]), (false, true, true, true, false))
  name(1.5, [pack, unpack], [n is honest])
  cells(1.5, 4.9, ([1], [nil], [3]), (false, false, false))
  arrow(1.5)
  cells(1.5, 12.5, ([1], [nil], [3]), (false, false, false))
  cdraw.rect((16.4, 1.0), (18.4, 2.0), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 1.5), [n = 3], size: 6pt)
})

`sort` takes a comparator or defaults to `<`, is not stable, and
detects inconsistent comparators, an always true function is an
error, though small inputs can slip through undetected, which is why
the probe sorts twenty elements:

#listing("lua/samples/ch12_stdlib2.lua", first: 42, last: 51, caption: [numeric sort of strings, invalid order detection])

== math

The subtype rules here changed in 5.5 and the suite pins them:
`math.floor`, `math.ceil`, and `math.modf` return an integer when
the result fits the integer range and a float otherwise, where 5.4
always returned floats. `math.abs` follows its argument's subtype.
`math.fmod` truncates toward zero while the `%` operator floors, so
`fmod(-7, 3)` is `-1` against `2`:

#listing("lua/samples/ch12_stdlib2.lua", first: 53, last: 71, caption: [integer returning floors, modf, fmod versus percent])

#diagram([the math library's subtype rules, one call each], length: 13pt, {
  cdraw.rect((0.5, 2.6), (21.5, 11.6), stroke: luma(150), radius: 0.02)
  cdraw.line((0.5, 10.4), (21.5, 10.4), stroke: luma(150))
  cdraw.line((5.5, 2.6), (5.5, 11.6), stroke: luma(150))
  for y in (9.1, 7.8, 6.5, 5.2, 3.9) {
    cdraw.line((0.5, y), (21.5, y), stroke: luma(220))
  }
  cdraw.content((3.0, 11.0), [call], size: 6.5pt)
  cdraw.content((13.5, 11.0), [5.5 rule], size: 6.5pt)
  let row(y, call, rule) = {
    cdraw.content((3.0, y), call, size: 6pt)
    cdraw.content((13.5, y), rule, size: 6pt)
  }
  row(9.75, [floor, ceil, modf], [integer when the result fits, 5.4 always floated])
  row(8.45, [abs], [follows its argument's subtype])
  row(7.15, [fmod], [truncates toward zero, -7 fmod 3 is -1, \% floors to 2])
  row(5.85, [tointeger], [nil on failure, numeric strings coerce])
  row(4.55, [ult], [the unsigned view, 1 is below -1 under it])
  row(3.25, [min, max], [compare with \<, reject non numbers])
})

`math.tointeger` and `math.type` answer with nil on failure, and
`tointeger` also accepts numeric strings, following the language's
string to number coercion. `math.ult` is the one place lua exposes
the unsigned view of integers, so `-1` is above everything:
`ult(1, -1)` is true. `max` and `min` compare with the language's
`<` and reject non numbers outright. `math.random` returns a float
in `[0, 1)` bare, an integer with bounds given, and `randomseed`
makes runs reproducible:

#listing("lua/samples/ch12_stdlib2.lua", first: 73, last: 109, caption: [tointeger coercion, ult, min max, seeded random])
#listing("lua/samples/ch12_stdlib2.lua", first: 95, last: 109, caption: [seeded reproducibility and bounds])

The trigonometric and logarithmic surface is complete with
`math.atan(y, x)` as the two argument arc tangent, `math.log` with a
base, and hyperbolic and `atan2` functions gone, removed back in
5.4.

== io

Two styles: implicit handles through `io.read` and `io.write`, and
explicit handles from `io.open`, which is everything this book uses.
Read formats are `"n"` number, `"l"` line without newline, `"L"` line
with, `"a"` rest of file, and nil at end. `io.type` reports `"file"`
or `"closed file"`, and file handles carry a `__close` metamethod,
so `<close>` manages them:

#listing("lua/samples/ch12_stdlib2.lua", first: 111, last: 136, caption: [read formats, seek positions, closed handles])

#flow(
  [a file handle's life, from open cursor to closed],
  node((0, 0), [io.open, or the implicit handle]),
  node((0, 1.6), [a read cursor at the start]),
  node((0, 3.2), [reads: "n" a number, #linebreak() "l" a line, "L" keeps the newline, #linebreak() "a" the rest]),
  node((-2.9, 3.2), [seek repositions it]),
  node((0, 4.8), [end of file, reads return nil]),
  node((0, 6.4), [closed, io.type says "closed file"]),
  node((3.0, 0), [implicit io.read versus #linebreak() explicit io.open handles]),
  node((3.0, 4.8), [io.lines returns the iterator #linebreak() and the handle, closing #linebreak() on exhaustion]),
  node((3.0, 6.4), [\<close\> manages a handle's life]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (0, 3.2), "-|>"),
  edge((0, 3.2), (-2.9, 3.2), "-|>"),
  edge((0, 3.2), (0, 4.8), "-|>"),
  edge((0, 4.8), (0, 6.4), "-|>"),
)
#listing("lua/samples/ch12_stdlib2.lua", first: 137, last: 146, caption: [files as to be closed values])

`io.lines` returns four values, the iterator, two nil placeholders
for generic for compatibility, and the file handle as the closing
value, so the file closes when the loop ends, a broken loop
included:

#listing("lua/samples/ch12_stdlib2.lua", first: 148, last: 161, caption: [lines closes its file, the four value return])

== os

`os.time` is an integer now and builds from a date table with hour
defaulting to noon, `os.date` formats with c strftime rules plus the
`"!*t"` table forms, `!` forcing utc, `difftime` returns a float,
and `os.getenv` yields nil for missing variables rather than an
error. `os.rename` and `os.remove` report true or nil plus a
message, the file error convention `assert` pairs with:

#listing("lua/samples/ch12_stdlib2.lua", first: 163, last: 185, caption: [time and date forms, environment, filesystem round trip])

#diagram([the os library's wall clock surface], length: 13pt, {
  cdraw.rect((0.5, 3.9), (21.5, 11.6), stroke: luma(150), radius: 0.02)
  cdraw.line((0.5, 10.4), (21.5, 10.4), stroke: luma(150))
  cdraw.line((6.0, 3.9), (6.0, 11.6), stroke: luma(150))
  for y in (9.1, 7.8, 6.5, 5.2) {
    cdraw.line((0.5, y), (21.5, y), stroke: luma(220))
  }
  cdraw.content((3.25, 11.0), [call], size: 6.5pt)
  cdraw.content((13.75, 11.0), [shape], size: 6.5pt)
  let row(y, call, rule) = {
    cdraw.content((3.25, y), call, size: 6pt)
    cdraw.content((13.75, y), rule, size: 6pt)
  }
  row(9.75, [os.time], [an integer, built from a date table, hour defaults to noon])
  row(8.45, [os.date], [strftime rules, ! forces utc, !\*t builds a table])
  row(7.15, [os.difftime], [a float difference])
  row(5.85, [os.getenv], [nil for a missing variable, never an error])
  row(4.55, [rename, remove], [true, or nil plus a message, what assert pairs with])
})

sources: lua.org manual 5.5 sections 6.7, 6.8, 6.9, 6.10, accessed
2026-09-08. Floor and ceil integer returns, tointeger string
coercion, and io.lines arity verified live with lua 5.5.1, 17 tests
green through `make verify-lua`.
