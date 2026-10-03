#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= types

Go's type system is nominal with structural moments: types are
declared, not inferred shapes, conversions are always explicit, and
the two composite workhorses, slices and maps, are reference typed
headers whose mutation semantics every Go bug report eventually
touches. The sample package exercises each rule with a test.

== the inventory

Booleans, signed `int` plus `int8` through `int64`, unsigned `uint8`
through `uint64` and `uintptr`, `float32` and `float64`, `complex64`
and `complex128`, strings, arrays, slices, maps, structs, pointers,
functions, channels, interfaces. Two aliases matter: `byte` is
`uint8` and `rune` is `int32`, a name for a code point, not a type of
its own. `int` is 64 bit on every platform this book targets and
`strconv.IntSize` says so portably:

#listing("go/samples/ch03/types.go", first: 32, last: 50, caption: [sizes from unsafe.sizeof, rune is 4 bytes as int32])

#diagram([the inventory by kind: widths, composites, and two aliases], length: 13pt, {
  pane(0.3, 5.2, 8.0, [bool], [one byte, true or false])
  pane(5.8, 14.6, 8.0, [integers], [#"int8 .. int64"], [#"uint8 .. uint64"], [widths 1 to 8 bytes])
  pane(15.2, 23.4, 8.0, [float, complex], [float32, float64], [complex64, complex128])
  pane(0.3, 11.3, 3.6, [strings + composites], [string: read only bytes], [slice, map, struct, array])
  pane(12.5, 23.4, 3.6, [aliases], [#"byte = uint8, rune = int32"], [names, not separate types])
  cdraw.content((11.8, -0.7), [unsafe.sizeof reads the widths: bool 1, int64 8, any pointer 8], size: 6pt)
})

== zero values, no uninitialized anything

There is no uninitialized state in Go. Storage is zeroed, every type
has a zero value, and declaration without assignment means zero. This
is why Go has no constructors as a language feature: a struct whose
zero value is usable needs none.

#listing("go/samples/ch03/types.go", first: 14, last: 30, caption: [one field per kind, all zero])

The consequence reaches deep: `sync.Mutex` is a usable zero value,
`bytes.Buffer` too, and a nil slice or map is a readable, rangeable
empty one, with the map write exception below.

#diagram([zero values: every field of a fresh struct starts at zero], length: 13pt, {
  cdraw.rect((0.5, 0.4), (12.5, 7.4), fill: luma(240), radius: 0.02)
  cdraw.content((6.5, 6.9), [a struct with one field per kind], size: 6.5pt)
  let row(y, name, val) = {
    cdraw.line((0.9, y - 0.45), (12.1, y - 0.45), stroke: luma(220))
    cdraw.content((3.2, y), [#name], size: 6pt)
    cdraw.content((9.2, y), [#val], size: 6pt)
  }
  row(5.9, [Bool], [false])
  row(4.9, [Int], [0])
  row(3.9, [Float64], [0.0])
  row(2.9, [Str], [#"\"\""])
  row(1.9, [Slice], [nil])
  row(0.9, [Map], [nil])
  pane(13.5, 23.4, 6.9, [why no constructors], [sync.Mutex zero is], [unlocked and usable], [bytes.Buffer works], [from var alone])
  cdraw.content((11.8, -0.7), [declaration without assignment means zero, always], size: 6pt)
})

== pointers, arrays, slices

Pointers exist, `*T`, with no arithmetic. Arrays are values: passing
one copies it, and `[3]int` and `[4]int` are different types. Slices
are the everyday type, a three word header of pointer, length, and
capacity over an array, and the header is the value while the backing
array is shared:

#listing("go/samples/ch03/types.go", first: 54, last: 69, caption: [append writes through the header, two slices share one array])

`OverwriteViaAppend` is the canonical surprise: the slice has length 2
and capacity 3, so `append` does not reallocate, it writes index 2 of
the original array, and `[3]int{1, 2, 3}` comes back as `[1, 2, 99]`.
`ShareBacking` shows the same aliasing between two slices cut from
one. Every slice gotcha, from `append` surprises to `sort` mutating
the caller's data, is this one fact.

#diagram([a slice is a three word header over a shared array], length: 13pt, {
  cdraw.rect((0.5, 3.2), (5.0, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((2.75, 7.4), [s], size: 7pt)
  cdraw.content((2.75, 6.3), [ptr], size: 6pt)
  cdraw.content((2.75, 5.1), [len 2], size: 6pt)
  cdraw.content((2.75, 3.9), [cap 3], size: 6pt)
  cdraw.line((5.0, 6.3), (6.1, 5.7), stroke: luma(100), mark: (end: ">>"))
  for i in range(3) {
    let f = if i == 2 { luma(225) } else { luma(205) }
    cdraw.rect((6.3 + i * 2.8, 5.0), (9.1 + i * 2.8, 6.4), fill: f, radius: 0.02)
    cdraw.content((7.7 + i * 2.8, 5.9), [#(("1", "2", "spare").at(i))], size: 6pt)
    cdraw.content((7.7 + i * 2.8, 4.55), [#i], size: 6pt)
  }
  cdraw.rect((16.0, 4.6), (21.0, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((18.5, 7.4), [#"s2 = s[1:]"], size: 7pt)
  cdraw.content((18.5, 6.1), [len 1], size: 6pt)
  cdraw.content((18.5, 4.9), [cap 2], size: 6pt)
  cdraw.line((16.0, 6.85), (10.5, 6.55), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.5, 3.3), [append(s, 99) writes index 2], size: 6pt)
  cdraw.content((10.5, 2.2), [no realloc: [1 2] becomes [1 2 99]], size: 6pt)
  cdraw.content((11.8, 1.1), [two slices cut from one array alias each other], size: 6pt)
})

== maps

A map is a hash table with no declared element order, iteration order
is deliberately randomized, and the three verbs are read with comma
ok, `delete`, and since go 1.21 `clear`:

#listing("go/samples/ch03/types.go", first: 71, last: 100, caption: [comma ok, delete, clear, and the nil map rules])

The nil map is the exam question: reads succeed and report missing,
writes panic. The test covers both sides. Map keys must be comparable,
which excludes slices, maps, and functions, and the comparability of
any struct type is itself queryable at run time:

#listing("go/samples/ch03/types.go", first: 117, last: 131, caption: [reflect reports which structs can sit behind ==])

A struct with a slice, map, or func field cannot be a map key or be
compared with `==`, and `reflect.TypeOf(v).Comparable()` says so
before the compile error does for values built at run time.

#diagram([a map is a hash table: hash to a bucket, nil is readable but unwritable], length: 13pt, {
  cdraw.rect((0.5, 5.4), (3.1, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((1.8, 6.0), [key], size: 6.5pt)
  cdraw.line((3.1, 6.0), (4.1, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((4.1, 5.4), (7.9, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 6.0), [hash], size: 6.5pt)
  cdraw.line((7.9, 6.0), (9.3, 6.0), stroke: luma(100), mark: (end: ">>"))
  for i in range(4) {
    let f = if i == 1 { luma(205) } else { luma(235) }
    cdraw.rect((9.3 + i * 2.05, 5.4), (11.35 + i * 2.05, 6.6), fill: f, radius: 0.02)
  }
  cdraw.content((12.4, 6.0), [go], size: 6pt)
  cdraw.content((12.9, 4.85), [buckets, random start], size: 6pt)
  pane(18.3, 23.4, 6.6, [nil map], [read: zero,], [missing], [write: panic])
  cdraw.content((11.8, 1.5), [comma ok read, delete, clear since 1.21], size: 6pt)
  cdraw.content((11.8, 0.4), [keys comparable: no slice, map, or func], size: 6pt)
  cdraw.content((11.8, -0.7), [iteration order randomized on purpose], size: 6pt)
})

== structs, embedding, and the 1.27 literal keys

Structs are field records with no inheritance and no methods in the
declaration. Composition is embedding, an anonymous field whose
fields and methods are promoted to the outer type:

#listing("go/samples/ch03/types.go", first: 102, last: 115, caption: [embedding with promotion, and go 1.27 promoted literal keys])

`Node` embeds `Point`, so `n.X`, `n.Y`, and `n.Norm2()` all resolve
through the promotion. Before 1.27 a literal had to nest explicitly,
`Node{Point: Point{X: 1, Y: 2}, Label: "origin"}`, asymmetric with
the dotted access the same value supports. Go 1.27 fixed the
asymmetry: a composite literal key may now be any valid field
selector for the struct type, and the shortest selector for a
promoted field is its plain name, so `Node{X: 1, Y: 2, Label:
"origin"}` compiles. Qualified spellings like `Point.X` remain
invalid, promotion conflicts at the same depth stay errors, and
mixing a promoted key with an explicit `Point:` entry that sets the
same field is a duplicate field error.

#diagram([composite literal keys before and after 1.27 promotion], length: 13pt, {
  pane(0.3, 11.3, 6.8, [before 1.27], [#"Node{Point: Point{"], [#"  X: 1, Y: 2},"], [#"  Label: \"origin\"}"])
  cdraw.line((11.6, 4.0), (12.4, 4.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.0, 4.6), [1.27], size: 6pt)
  pane(12.7, 23.3, 6.8, [1.27 promoted keys], [#"Node{X: 1, Y: 2,"], [#"  Label: \"origin\"}"])
  cdraw.content((11.8, 0.6), [still errors: qualified Point.X keys, depth conflicts, duplicates], size: 6pt)
})

== defined types, aliases, conversions

`type Celsius float64` creates a new type with the same underlying
representation but a distinct identity: no implicit conversion
between them in either direction, methods attach to `Celsius` alone.
`type Alias = float64` creates nothing, it is another name for the
same type, usable interchangeably:

#listing("go/samples/ch03/types.go", first: 133, last: 147, caption: [defined type versus alias, distinguished at run time])

The general rule has no exceptions and no user defined conversions:
values convert only where assignment compatibility holds, identical
underlying types, named and unnamed pairs, or an explicit `T(x)`.
Numeric conversions truncate, and `string(int)` converts the integer
as a code point, which is why vet flags it.

#diagram([three relations: defined type, alias, explicit conversion], length: 13pt, {
  pane(0.3, 7.7, 6.8, [defined type], [type Celsius], [float64], [new identity,], [same bits inside])
  pane(8.0, 15.4, 6.8, [alias], [#"type Alias = float64"], [nothing created:], [one type, two names])
  pane(15.7, 23.1, 6.8, [conversion], [Celsius(37.5)], [explicit, always], [no implicit path], [exists anywhere])
})

== strings

A string is a read only slice of bytes, utf-8 by convention not by
type, and indexing yields bytes while `range` yields runes:

#listing("go/samples/ch03/types.go", first: 149, last: 152, caption: [len is bytes, rune count is characters])

`"héllo" + "thế"` is 11 bytes and 8 runes: two accents cost one extra
byte each, one costs two. Conversions move between worlds: `[]byte(s)`
copies into a mutable buffer, `[]rune(s)` decodes once into code
points, `string(r)` encodes a single rune, and `string(bs)` where `bs`
is `[]byte` copies back. Invalid utf-8 does not panic any of this,
it decodes as `U+FFFD`, the replacement character, one per bad byte.

#diagram([eleven bytes, eight runes: indexing walks bytes, range decodes runes], length: 13pt, {
  let cells = (("h", 1), ("c3", 1), ("a9", 1), ("l", 1), ("l", 1), ("o", 1), ("t", 1), ("h", 1), ("e1", 1), ("ba", 1), ("bf", 1))
  let shaded = (true, true, false, false, false, false, false, false, true, true, true)
  for (i, c) in cells.enumerate() {
    let f = if shaded.at(i) { luma(225) } else { luma(235) }
    cdraw.rect((1.4 + i * 1.4, 4.4), (2.8 + i * 1.4, 5.6), fill: f, radius: 0.02)
    cdraw.content((2.1 + i * 1.4, 5.0), [#c.first()], size: 6pt)
  }
  cdraw.line((1.4, 5.9), (17.0, 5.9), stroke: luma(100))
  cdraw.line((1.4, 5.9), (1.4, 6.15)); cdraw.line((17.0, 5.9), (17.0, 6.15))
  cdraw.content((9.2, 6.6), [len: 11 bytes], size: 6pt)
  cdraw.line((4.2, 4.1), (7.0, 4.1), stroke: luma(100))
  cdraw.line((4.2, 4.1), (4.2, 3.85)); cdraw.line((7.0, 4.1), (7.0, 3.85))
  cdraw.content((5.6, 3.5), [é], size: 6.5pt)
  cdraw.line((14.0, 4.1), (17.0, 4.1), stroke: luma(100))
  cdraw.line((14.0, 4.1), (14.0, 3.85)); cdraw.line((17.0, 4.1), (17.0, 3.85))
  cdraw.content((15.5, 3.5), [ế], size: 6.5pt)
  cdraw.content((9.2, 2.5), [range: 8 runes, one per cell or bracket], size: 6pt)
  pane(18.6, 23.4, 5.4, [the sum], [#"héllo: 5 runes"], [#"thế: 3 runes"], [8 runes total])
  cdraw.content((11.8, 0.15), [invalid bytes decode as one U+FFFD each, never panic], size: 6pt)
})

sources: go.dev/ref/spec, types, composite literals, and conversions
sections, go 1.27 release notes for the promoted literal keys,
accessed 2026-09-08. Behavior verified by `go/samples/ch03` tests,
including the compiler acceptance of promoted keys on go1.27.0.
