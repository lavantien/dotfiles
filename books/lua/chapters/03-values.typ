#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= values, metatables, metamethods

Lua is dynamically typed: variables hold anything, values carry the
type. Eight types exist and the stock interpreter exposes all eight
without leaving lua code, because `io.stdout` is userdata and a
coroutine is a thread:

#listing("lua/samples/ch03_values.lua", first: 5, last: 14, caption: [the eight types, each observed through a live value])

#diagram([the eight types, each reachable from plain lua, and the two falsy ones], length: 13pt, {
  let row1 = ("nil", "boolean", "number", "string")
  let row2 = ("table", "function", "userdata", "thread")
  let cell(x, y, name, hot) = {
    let f = if hot { luma(205) } else { luma(235) }
    cdraw.rect((x, y), (x + 4.5, y + 1.0), fill: f, radius: 0.02)
    cdraw.content((x + 2.25, y + 0.5), [#name], size: 6pt)
  }
  for (i, n) in row1.enumerate() { cell(0.5 + i * 5.1, 8.6, n, i < 2) }
  for (i, n) in row2.enumerate() { cell(0.5 + i * 5.1, 6.6, n, false) }
  cdraw.line((12.95, 6.6), (12.95, 6.0), stroke: luma(120))
  cdraw.line((18.05, 6.6), (18.05, 6.0), stroke: luma(120))
  cdraw.content((12.95, 5.5), [like io.stdout], size: 6pt)
  cdraw.content((18.05, 5.5), [like a coroutine], size: 6pt)
  cdraw.content((10.8, 4.2), [shaded: nil and false are the only falsy values], size: 6.5pt)
  cdraw.content((10.8, 2.9), [nil in a table is an absent key,], size: 6.5pt)
  cdraw.content((10.8, 1.7), [false is present with the value false], size: 6.5pt)
})

Only `nil` and `false` are falsy. Zero, the empty string, and NaN all
count as true. The distinction between nil and false is structural,
not just truthiness: nil in a table means the key is absent, false
means present with value false, which is why `next` sees one and not
the other.

== numbers: one type, two subtypes

`type` says number for both, `math.type` splits them. `1 == 1.0` is
true and they make the same table key, but `tostring` keeps the
subtype visible, `1` versus `1.0`, and a float with no integer
representation cannot cross into `%d`:

#listing("lua/samples/ch03_values.lua", first: 32, last: 41, caption: [equal but distinguishable, and the format boundary])

#diagram([one runtime type, two tagged representations behind every number], length: 13pt, {
  // the value 1 and the value 1.0 as tagged cells, boxes sized for the text
  let seg(x0, x1, txt, fill) = {
    cdraw.rect((x0, 5.0), (x1, 6.6), fill: fill, radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 5.8), txt, size: 6pt)
  }
  seg(3.0, 5.6, [number], luma(235))
  seg(5.6, 8.4, [integer], luma(205))
  seg(8.4, 9.3, [1], luma(235))
  seg(12.1, 14.7, [number], luma(235))
  seg(14.7, 16.9, [float], luma(205))
  seg(16.9, 18.1, [1.0], luma(235))
  cdraw.content((10.7, 5.8), [==], size: 7pt)
  cdraw.content((10.55, 3.9), [shaded: the subtype tag], size: 6.5pt)
  cdraw.content((10.55, 2.7), [math.type splits on it, type reports number for both], size: 6.5pt)
  cdraw.content((10.55, 1.5), [equal values, one table key, tostring keeps the subtype, %d wants an integer], size: 6.5pt)
})

== strings and keys

Strings are immutable byte sequences, 8 bit clean, and encoding
agnostic: an embedded zero is just a byte, and two strings differing
only in that byte are different keys. Table keys accept anything
except nil and NaN, and float keys holding exact integer values are
normalized to integers so `t[2.0]` and `t[2]` are one entry:

#listing("lua/samples/ch03_values.lua", first: 53, last: 64, caption: [key normalization, infinity as a key, nil and NaN rejected])

#flow(
  [what a table accepts as a key, the two rejections and the float normalization],
  node((0, 0), [a value used as a key]),
  node((0, 1.6), [nil or NaN?]),
  node((-2.2, 1.6), [rejected: nil would #linebreak() mean an absent key]),
  node((0, 3.2), [a float with an exact #linebreak() integer value?]),
  node((-2.2, 3.2), [normalized, t\[2.0\] #linebreak() is t\[2\]]),
  node((0, 4.8), [stored as is, inf works, #linebreak() zero bytes tell strings apart]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (-2.2, 1.6), "-|>", label: [yes]),
  edge((0, 1.6), (0, 3.2), "-|>", label: [no]),
  edge((0, 3.2), (-2.2, 3.2), "-|>", label: [yes]),
  edge((0, 3.2), (0, 4.8), "-|>", label: [no]),
)

Tables are references: two names on one table alias, and fresh tables
are never equal. Functions compare by identity, so the same C function
equals itself and two closures from the same factory do not.

== metatables

Any value may carry a metatable. Tables get theirs from
`setmetatable`, other types share one per type and only C or the
debug library can change those, which is why the string library can
give every string an `__index` pointing at the `string` table and
`("abc"):len()` works, the colon passing the string as `self`, the
sugar chapter 6 defines. `getmetatable` returns the `__metatable` field
instead of the real table when present, which is the standard
protection idiom.

#callout("note", "address format is the platform's", [
  `tostring` of a table is its type name, a colon, and the `%p` of
  the pointer. On this windows build that prints without an `0x`
  prefix, `table: 00000187...`. The suite matches only the prefix
  `table: ` because the format belongs to the C runtime, not to lua.
])

#diagram([where metatables live, per value for tables, one shared per type for the rest], length: 13pt, {
  // the two storage regimes as stacked layers, two-line labels need tall bands
  cdraw.rect((0.5, 8.8), (21.5, 11.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 9.9), [tables: a metatable per value, #linebreak() setmetatable and getmetatable from lua], size: 6pt)
  cdraw.rect((0.5, 6.0), (21.5, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 7.1), [every other type: one shared metatable, #linebreak() changeable only from c or the debug library], size: 6pt)
  // the string example riding on the shared layer
  cdraw.line((4.25, 6.0), (4.25, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.5, 3.6), (8.0, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((4.25, 4.4), [the string type's #linebreak() shared metatable], size: 6pt)
  cdraw.line((8.0, 4.4), (12.0, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.0, 4.9), [\_\_index], size: 6pt)
  cdraw.rect((12.0, 3.6), (21.5, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((16.75, 4.4), [the string table, #linebreak() len, sub, format], size: 6pt)
  cdraw.content((11.0, 2.5), [so ("abc"):len() is an index miss walked to the string table], size: 6.5pt)
  cdraw.content((11.0, 1.3), [\_\_metatable returns a stand-in, \_\_name names values in messages], size: 6.5pt)
})

`__name` feeds the same machinery: a table with `__name = "Widget"`
prints as `Widget: ...` and error messages say "on a Widget value"
instead of "on a table value":

#listing("lua/samples/ch03_values.lua", first: 84, last: 93, caption: [name in tostring and in error messages])

== the arithmetic and comparison events

Arithmetic metamethods search the first operand first, then the
second, and receive the operands in original order. Unary operators
pass a dummy second operand equal to the first, an internal
simplification the manual reserves the right to remove. Bitwise
metamethods fire only when a float operand cannot coerce to integer,
so `3.0 & 1` is plain machine arithmetic while `1.5 | 2` is an error
without a metamethod:

#listing("lua/samples/ch03_values.lua", first: 109, last: 121, caption: [operand order pinned by capture])

#flow(
  [metamethod lookup for a binary operation, the first operand's event first],
  node((0, 0), [a op b]),
  node((0, 1.6), [first operand has #linebreak() the event?]),
  node((-2.2, 1.6), [it runs, operands in #linebreak() original order]),
  node((0, 3.2), [second operand has it?]),
  node((-2.2, 3.2), [the second one runs]),
  node((0, 4.8), [primitive op, #linebreak() or an error]),
  node((3.1, 1.6), [unary passes the #linebreak() operand twice]),
  node((3.1, 3.2), [bitwise fires only when a float #linebreak() cannot coerce to integer]),
  node((3.1, 4.8), [\_\_eq needs two tables, #linebreak() \_\_lt and \_\_le any pair]),
  edge((0, 0), (0, 1.6), "-|>"),
  edge((0, 1.6), (-2.2, 1.6), "-|>", label: [yes]),
  edge((0, 1.6), (0, 3.2), "-|>", label: [no]),
  edge((0, 3.2), (-2.2, 3.2), "-|>", label: [yes]),
  edge((0, 3.2), (0, 4.8), "-|>", label: [no]),
)
#listing("lua/samples/ch03_values.lua", first: 134, last: 140, caption: [the bitwise coercion boundary])

`__eq` is the picky one: it runs only between two tables, or two full
userdata, that are not primitively equal. `__lt` and `__le` are wider,
any mixed pair qualifies, and both convert the metamethod result to
boolean, so a numeric `0` return means true:

#listing("lua/samples/ch03_values.lua", first: 151, last: 171, caption: [eq's both tables rule versus order's mixed pairs])

== access and call

`__index` and `__newindex` fire only when the access is not a table
or the key is absent. The metavalue can be a function, a table, or
any value with its own metavalue, and the follow up access is
regular, so metatables chain. Assignments routed through `__newindex`
never perform the primitive store, `rawset` exists for that:

#listing("lua/samples/ch03_values.lua", first: 172, last: 188, caption: [function, table, and chained index metavalue])
#listing("lua/samples/ch03_values.lua", first: 189, last: 204, caption: [newindex as function and as backing table])

#flow(
  [a miss walking the \_\_index chain, rawget exits the walk],
  node((0, 0), [t.k missing]),
  node((2.2, 0), [metatable]),
  node((4.4, 0), [\_\_index table]),
  node((6.6, 0), [next metatable]),
  edge((0, 0), (2.2, 0), "-|>", label: [miss]),
  edge((2.2, 0), (4.4, 0), "-|>", label: [\_\_index]),
  edge((4.4, 0), (6.6, 0), "-|>", label: [miss]),
  node((1.4, 1.8), [rawget(t, k)]),
  edge((0, 0), (1.4, 1.8), "-|>", bend: 35deg, label: [no walk]),
)

`__call` is the only multimethod-return metamethod: the callee is
prepended to the argument list and every result passes through. And a
metavalue does not need to be a function, any callable works, which
lets a callable table serve as `__add`:

#listing("lua/samples/ch03_values.lua", first: 205, last: 215, caption: [call passes everything through])
#listing("lua/samples/ch03_values.lua", first: 216, last: 224, caption: [a callable table as the add metamethod])

The remaining reserved keys, `__gc`, `__close`, and `__mode`, belong
to their own machinery and get chapters later: finalization with the
collector, to-be-closed variables, and weak tables.

sources: lua.org manual 5.5 sections 2.1, 2.4, accessed 2026-09-08.
Metamethod behavior verified live with lua 5.5.1, 21 tests green
through `make verify-lua`.
