#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the javascript toolbox

JavaScript has one number type for everything, a 64-bit double whose
integers stop being exact at 2^53, and no syntax error warns you when a
computation walks past that line. So this toolbox is the integer story
chapter of the set: every structure that stays under the wall, the heap,
the deque, the grid, the input kit, runs on plain `Number` arrays, and
the number kit does not go near `Number` at all, it is written entirely
on `BigInt` with the conversion points pushed to the api edges. The
suite is 239 non-blank lines over 6 files with 36 tests, private fields
for the invariants, and the same cross-language anchors the other
toolboxes pin. The semantics of the wall itself, doubles, safe
integers, `BigInt`, belong to #xref-to("javascript", "lexical"), this
chapter is where the policy pays off in contest code.

== the min-heap, comparator included

The heap stores its elements in a plain array, children of i at 2i + 1
and 2i + 2, with the ordering injected as a function so one class
serves every puzzle. Push sifts up by swapping with the parent while
the comparator says so.

The dry run: the `objects order by a field: dijkstra-style entries`
block in `test/heap.test.mjs` pushes three entries through a dist
comparator and asserts the pop order by vertex.

+ Push `{v: 2, dist: 7}` lands alone; push `{v: 1, dist: 3}`
  appends then sifts up, 3 under 7 swapping them to `[3, 7]`.
+ Push `{v: 3, dist: 5}` appends at index 2, where the parent's 3
  wins, no swap, `[3, 7, 5]`.
+ Pop returns v 1; the last entry, 5, takes the root, and its only
  child, 7, does not beat it, `[5, 7]`.
+ The next two pops return v 3 then v 2, dists 5 and 7, the
  asserted `[1, 3, 2]`.

#diagram([the array under the dist comparator, one state per operation, the root always the smallest dist], length: 12pt, {
  let st(x, y, vals, lab) = {
    for (i, v) in vals.enumerate() {
      cdraw.rect((x + i * 1.3, y), (x + i * 1.3 + 1.2, y + 1.0), fill: if i == 0 { luma(225) } else { luma(240) }, radius: 0.02)
      cdraw.content((x + i * 1.3 + 0.6, y + 0.5), v, size: 6.5pt)
    }
    cdraw.content((x + 0.6, y + 1.6), lab, size: 6pt, fill: luma(100))
  }
  st(0.8, 4.2, ([7],), [push v2])
  st(3.9, 4.2, ([3], [7]), [push v1, swap])
  st(7.0, 4.2, ([3], [7], [5]), [push v3])
  st(10.1, 4.2, ([5], [7]), [pop v1])
  cdraw.content((0.8, 2.0), [pops return v1, v3, v2, dists 3, 5, 7], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.8, 1.1), [the root holds the smallest dist after every step], size: 6.5pt, fill: luma(100), anchor: "west")
})

The frontier pops by dist in order, 3, 5, 7, the asserted vertices
1, 3, 2 in the listings below.

#listing("icpc/samples-js/src/heap.mjs", first: 4, last: 31, caption: [the class head and push, sifting up one swap at a time])

Pop lifts the last element to the root and sifts down into the smaller
child, and both operations return before the heap invariant can break,
which the test asserts directly, every parent no greater than its
children under the comparator after a shuffled fill:

#listing("icpc/samples-js/src/heap.mjs", first: 33, last: 53, caption: [pop sifts down into the better child, values dumps the array])

The default comparator is numeric ascending, so pushes of 5, 3, 8, 1,
9, 2 pop back as 1, 2, 3, 5, 8, 9, one line flips it to a max-heap, and
a third test orders objects by a cost field, the dijkstra shape, which
is exactly how the frontier in #xref-to("dsa", "shortestpaths") would
use it. The from-scratch derivation of the sift arithmetic lives in
#xref-to("dsa", "heaps").

#diagram([the array is the tree, sift up on push, sift down on pop], length: 13pt, {
  cdraw.content((11.2, 8.0), text(size: 6.5pt)[one array, two repair walks])
  let vals = ("1", "3", "2", "8", "5", "9")
  for (i, v) in vals.enumerate() {
    cdraw.rect((1.2 + i * 1.35, 5.6), (2.55 + i * 1.35, 6.7), fill: luma(235), radius: 0.02)
    cdraw.content((1.875 + i * 1.35, 6.15), text(size: 6pt)[#v])
    cdraw.content((1.875 + i * 1.35, 5.25), text(size: 5.5pt, fill: luma(255))[.#(i)])
  }
  cdraw.content((11.2, 4.3), text(size: 6pt)[children of i live at 2i + 1 and 2i + 2])
  cdraw.content((11.2, 3.4), text(size: 6pt)[push: the new leaf swaps up while less than parent])
  cdraw.content((11.2, 2.5), text(size: 6pt)[pop: the last element takes the root and sinks])
  cdraw.content((11.2, 1.6), text(size: 6pt)[the comparator decides, numbers, reversed, or by field])
  cdraw.content((11.2, 0.7), text(size: 6pt)[an empty pop is undefined, never a fabricated value])
})

== the ring deque

The deque is the same ring the C\# chapter builds, slots plus head plus
count, growth that copies the logical contents back to slot 0, and it
is in this suite because sliding windows and both-end worklists appear
at every finals.

The dry run: the `the ring wraps: push front across the seam,
order survives` block in `test/deque.test.mjs` drives a cap 4 ring
through a backward wrap and asserts the drain.

+ pushBack 1, 2, 3 fill slots 0, 1, 2 with head 0, count 3.
+ pushFront 0 sets head to (0 - 1) mod 4 = 3, slot 3 holds 0, and
  the ring is full at count 4.
+ popBack reads slot (3 + 4 - 1) mod 4 = 2, the 3, and count
  drops to 3.
+ pushFront 9 sets head to (3 - 1) mod 4 = 2, slot 2 holds 9, the
  backward wrap past slot 0 the test's comment names.
+ The drain pops 9 from slot 2, 0 from slot 3, then 1 from slot 0,
  the asserted `[9, 0, 1]`.

#diagram([the cap 4 ring at the two wraps: slot 3 first, then the backward step to slot 2], length: 12pt, {
  let ring(x, vals, lab, hi) = {
    for (i, t) in vals.enumerate() {
      cdraw.rect((x + i * 1.15, 3.6), (x + i * 1.15 + 1.05, 4.6), fill: if t == [] { luma(250) } else { luma(238) }, radius: 0.02)
      if t != [] { cdraw.content((x + i * 1.15 + 0.52, 4.1), t, size: 6.5pt) }
      cdraw.content((x + i * 1.15 + 0.52, 3.1), [#i], size: 6pt, fill: luma(100))
    }
    cdraw.content((x + 0.52 + hi * 1.15, 5.4), [head], size: 6pt, fill: luma(100))
    cdraw.line((x + 0.52 + hi * 1.15, 5.1), (x + 0.52 + hi * 1.15, 4.65), stroke: luma(100), mark: (end: ">"))
    cdraw.content((x + 0.52, 2.2), lab, size: 6pt, fill: luma(100))
  }
  ring(0.8, ([1], [2], [3], [0]), [pushFront 0: head 3], 3)
  ring(7.4, ([1], [], [9], [0]), [pushFront 9: head 2], 2)
  cdraw.content((0.8, 0.9), [drain: 9 from slot 2, 0 from slot 3, 1 from slot 0], size: 6.5pt, fill: luma(100), anchor: "west")
})

Order survives both wraps, the drain reading `[9, 0, 1]`, in the
listings below.

#listing("icpc/samples-js/src/deque.mjs", first: 4, last: 38, caption: [slots, modulo wrap, doubling growth that rebases at slot zero])

#listing("icpc/samples-js/src/deque.mjs", first: 40, last: 54, caption: [both pops, an empty pop is undefined])

The refusal convention differs from C\# on purpose. Where the C\# ring
throws `InvalidOperationException` on underflow, this deque returns
`undefined`, which is JavaScript's native signal for absence, the same
value an empty heap pop returns, and the tests pin it for both ends.
The seam test pushes front across the wrap and keeps the order, the
growth tests fill from both ends past the initial capacity of 8 and
drain in perfect order.

#diagram([head steps backward on push front, the tail wraps into freed slots], length: 13pt, {
  cdraw.content((6.4, 7.9), text(size: 6.5pt)[the seam, modulo does the work])
  let vals = ("", "11", "12", "13", "", "", "", "10")
  for (i, v) in vals.enumerate() {
    cdraw.rect((1.0 + i * 1.0, 5.4), (2.0 + i * 1.0, 6.3), fill: if v == "" { luma(245) } else { luma(225) }, radius: 0.02)
    if v != "" { cdraw.content((1.5 + i * 1.0, 5.85), text(size: 6pt)[#v]) }
    cdraw.content((1.5 + i * 1.0, 5.05), text(size: 5.5pt, fill: luma(255))[.#(i)])
  }
  cdraw.content((1.5 + 7 * 1.0, 3.75), text(size: 6pt)[head])
  cdraw.line((1.5 + 7 * 1.0, 4.0), (1.5 + 7 * 1.0, 4.68), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.4, 6.9), (1.5, 6.9), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((9.4, 6.9), (9.4, 6.4), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((1.5, 6.9), (1.5, 6.4), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.content((5.5, 7.2), text(size: 6pt)[the next push front lands at (7 + 7) mod 8 = 6])
  cdraw.content((5.4, 2.9), text(size: 6pt)[count is the truth, slots are an illusion])
  cdraw.content((5.4, 2.0), text(size: 6pt)[growth copies logical order back to slot 0])

  cdraw.content((18.4, 7.9), text(size: 6.5pt)[underflow, two dialects])
  cdraw.rect((13.4, 5.15), (23.0, 6.55), fill: luma(235), radius: 0.02)
  cdraw.content((18.2, 6.15), text(size: 6pt)[pop on an empty ring])
  cdraw.content((18.2, 5.5), text(size: 6pt)[what comes back?])
  cdraw.line((16.4, 5.15), (15.1, 4.45), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.0, 5.15), (21.1, 4.45), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 2.95), (18.2, 4.45), fill: luma(205), radius: 0.02)
  cdraw.content((15.1, 4.05), text(size: 6pt)[undefined])
  cdraw.content((15.1, 3.4), text(size: 6pt)[this toolbox, and the heap])
  cdraw.rect((18.6, 2.95), (23.6, 4.45), fill: luma(205), radius: 0.02)
  cdraw.content((21.1, 4.05), text(size: 6pt)[throws])
  cdraw.content((21.1, 3.4), text(size: 6pt)[the c\# ring deque])
  cdraw.content((18.4, 2.0), text(size: 6pt)[both refuse to invent a zero])
})

== the number kit lives on bigint

Everything in `num.mjs` is `BigInt`, and the reason is a two-line test.
`Number(2n ** 53n)` and `Number(2n ** 53n + 1n)` are the same double,
the silent collision, while the BigInt values stay distinct, so any
modular arithmetic over puzzle-sized numbers has no business running on
`Number` at all.

The dry run: the `bezout holds and the classic coefficients pin`
block in `test/num.test.mjs` asserts `extGcd(240n, 46n)` deep-equal
to `{g: 2n, x: -9n, y: 47n}` and the identity beside it.

+ Euclid walks the magnitudes: 240 = 5 x 46 + 10, 46 = 4 x 10 + 6,
  10 = 1 x 6 + 4, 6 = 1 x 4 + 2, and 4 = 2 x 2 + 0, so g is 2.
+ Unwinding, one substitution per step: 2 = 6 - 4, then 2 = 2 x 6
  - 10, then 2 = 2 x 46 - 9 x 10, then 2 = 47 x 46 - 9 x 240.
+ The coefficients land where the assert pins them, x = -9 and
  y = 47.
+ The check multiplies back: 46 x 47 = 2162, 240 x 9 = 2160, and
  2162 - 2160 = 2, the asserted `a * x + b * y = g`.
+ The same identity check runs over 17 and 13, 0 and 7, then 7
  and 0, before the file moves to crt.

#diagram([the euclid staircase from 240 and 46 down to 2, each step one quotient and one remainder], length: 12pt, {
  let s(x, t, r) = {
    cdraw.rect((x, 3.4), (x + 2.6, 4.4), fill: if r { luma(225) } else { luma(240) }, radius: 0.02)
    cdraw.content((x + 1.3, 3.9), t, size: 6.5pt)
  }
  s(0.6, [240], false)
  s(4.0, [46], false)
  s(7.4, [10], false)
  s(10.8, [6], false)
  s(14.2, [4], false)
  s(17.6, [2], true)
  cdraw.line((3.2, 3.9), (4.0, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.6, 3.9), (7.4, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.0, 3.9), (10.8, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.4, 3.9), (14.2, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.8, 3.9), (17.6, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.3, 2.4), [5 x 46 + 10], size: 6pt, fill: luma(100))
  cdraw.content((5.7, 2.4), [4 x 10 + 6], size: 6pt, fill: luma(100))
  cdraw.content((9.1, 2.4), [1 x 6 + 4], size: 6pt, fill: luma(100))
  cdraw.content((12.5, 2.4), [1 x 4 + 2], size: 6pt, fill: luma(100))
  cdraw.content((15.9, 2.4), [2 x 2 + 0], size: 6pt, fill: luma(100))
  cdraw.content((0.6, 1.2), [unwound: 2 = 47 x 46 - 9 x 240, so x = -9, y = 47], size: 6.5pt, fill: luma(100), anchor: "west")
})

g is 2 with x = -9 and y = 47, the pinned Bezout pair, in the
listings below.

#listing("icpc/samples-js/src/num.mjs", first: 6, last: 27, caption: [gcd, lcm, square-and-multiply, all bigint end to end])

The inverse runs extended Euclid recursively and reports failure as
`null`, the same absence convention as the heap and the deque, composite
moduli included since Euclid does not care about primality:

#listing("icpc/samples-js/src/num.mjs", first: 30, last: 41, caption: [bezout coefficients, then the inverse, null on shared factors])

The crt fold accepts consistent non-coprime systems through the lcm and
returns `null` for contradictions and for empty or non-positive input:

#listing("icpc/samples-js/src/num.mjs", first: 44, last: 60, caption: [the fold, consistent non-coprime pairs merge, clashes return null])

The anchors are the shared ones: 2^100 mod 1e9+7 is 976371285,
extGcd(240, 46) gives coefficients -9 and 47 with gcd 2, the sun tzu
fixture folds to 23 mod 105, and 1 mod 4 with 5 mod 8 merges to 5
mod 8. Beyond the anchors, the suite goes where `Number` cannot:
3 to the 2^62 modulo 2^61 stays exact, the lcm of 2^32 and 3^23 towers
past 2^53, and a three-congruence system whose combined modulus
includes 2^61 - 1 verifies every residue. The mathematics being
exercised here is derived in #xref-to("dsa", "numtheory").

#diagram([the wall at 2^53, number collides, bigint keeps counting], length: 13pt, {
  cdraw.content((11.4, 8.3), text(size: 6.5pt)[the wall at 2^53])
  cdraw.line((2.0, 7.3), (21.4, 7.3), stroke: luma(100))
  cdraw.line((11.4, 3.4), (11.4, 7.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((12.15, 7.05), text(size: 6pt)[2^53])
  cdraw.rect((2.1, 5.05), (10.9, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((6.55, 6.25), text(size: 6pt)[number, exact here])
  cdraw.content((6.55, 5.55), text(size: 6pt)[every integer a double holds])
  cdraw.rect((11.9, 5.05), (20.8, 6.7), fill: luma(205), radius: 0.02)
  cdraw.content((16.3, 6.25), text(size: 6pt)[number, colliding])
  cdraw.content((16.3, 5.55), text(size: 6pt)[2^53 and 2^53 + 1 agree])
  cdraw.content((6.55, 4.1), text(size: 6pt)[bigint: 2n \*\* 53n + 1n])
  cdraw.content((16.3, 4.1), text(size: 6pt)[bigint: still distinct])
  cdraw.line((8.0, 4.6), (8.0, 5.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.6, 4.6), (17.6, 5.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.4, 2.9), text(size: 6pt)[the kit never converts mid-math])
  cdraw.content((11.4, 2.0), text(size: 6pt)[number lives at the api edges only])
  cdraw.content((11.4, 1.1), text(size: 6pt)[lcm(2^32, 3^23) is 11 digits past the wall, exact])
})

== grid and input, plain data

The grid kit is deliberately untyped: rows are arrays of single
character strings, coordinates are two-number arrays, and the two delta
sets are exported constants.

The dry run: the `4-neighbors of a center cell and a corner` block
in `test/grid.test.mjs` walks both cells of a nine-letter fixture
and asserts the neighbor lists with their order.

+ `parseGrid` builds 3 rows of 3 from the abc, def, ghi fixture.
+ From the center `[1, 1]`, N4 walks up, down, left, right, its
  exported order: `[0, 1]`, `[2, 1]`, `[1, 0]`, `[1, 2]`, all in
  bounds, the asserted list.
+ From the corner `[0, 0]`, up and left cross the edge; down gives
  `[1, 0]`, right gives `[0, 1]`, the asserted pair.
+ Under N8 the center keeps all 8 and the corner 3, `[0, 1]`,
  `[1, 0]`, `[1, 1]`, the exported lengths pinning 4 and 8.
+ `manhattan([0, 0], [3, 4])` adds 3 + 4 = 7, pinned beside the 4
  and 0 of the shorter pairs.

#diagram([the center's four steps in N4 order, up, down, left, right, and the corner keeping two], length: 12pt, {
  for r in range(3) {
    for c in range(3) {
      let f = luma(246)
      if r == 1 and c == 1 { f = luma(210) }
      if (r == 0 and c == 1) or (r == 1 and c == 0) or (r == 2 and c == 1) or (r == 1 and c == 2) { f = luma(230) }
      cdraw.rect((1.0 + c * 1.3, 5.8 - r * 1.3), (2.3 + c * 1.3, 7.1 - r * 1.3), fill: f, radius: 0.02)
    }
  }
  cdraw.line((1.65, 6.45), (1.65, 7.7), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  cdraw.content((0.3, 8.0), [1 up], size: 6pt, fill: luma(100))
  cdraw.line((1.65, 6.45), (1.65, 5.15), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  cdraw.content((0.3, 5.0), [2 down], size: 6pt, fill: luma(100))
  cdraw.line((1.65, 6.45), (0.35, 6.45), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  cdraw.content((0.3, 6.9), [3 left], size: 6pt, fill: luma(100))
  cdraw.line((1.65, 6.45), (2.95, 6.45), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  cdraw.content((3.1, 6.9), [4 right], size: 6pt, fill: luma(100))
  cdraw.content((5.2, 6.6), [the center keeps all four], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((5.2, 5.7), [the corner keeps down and right only], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((5.2, 4.8), [N8: 8 at the center, 3 at the corner], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((5.2, 3.9), [manhattan: 3 + 4 = 7], size: 6.5pt, fill: luma(100), anchor: "west")
})

The lists come back in delta order and manhattan reads 7, the
pinned values, in the listings below.

#listing("icpc/samples-js/src/grid.mjs", first: 5, last: 21, caption: [the two delta sets, four orthogonal, eight total])

#listing("icpc/samples-js/src/grid.mjs", first: 23, last: 45, caption: [parse tolerates crlf, neighbors stay in bounds, manhattan on tuples])

The input kit pairs with it. `splitLines` normalizes `\\r\\n` and the
trailing newline in one pass, `blankGroups` reduces the lines into
paragraphs, and `intsPerLine` is one regular expression, `/-?\\d+/g`,
run through `matchAll`, so every line without numbers yields an empty
array rather than a hole:

#listing("icpc/samples-js/src/input.mjs", first: 5, last: 31, caption: [lines, blank-line groups, signed integers per line])

Run-length pairs close the kit, decode expands `[[3, a], [2, b]]` to
`aaabb`, encode rebuilds the pairs, and both directions are pinned. The
crlf test mixes line endings in one document and the grid parse test
does the same, because puzzle files arrive from three operating systems
and only ever cause trouble on the third one.

#diagram([text to rows to cells, the deltas ready for the walk], length: 13pt, {
  cdraw.content((11.2, 8.0), text(size: 6.5pt)[text, rows, cells, neighbors])
  cdraw.rect((0.6, 4.85), (5.4, 6.95), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 6.6), text(size: 6pt)[ab\\r\\n])
  cdraw.content((3.0, 5.93), text(size: 6pt)[cd\\n])
  cdraw.content((3.0, 5.26), text(size: 6pt)[mixed endings])
  cdraw.line((5.4, 6.05), (6.6, 6.05), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.6, 4.85), (11.4, 6.95), fill: luma(235), radius: 0.02)
  cdraw.content((9.0, 6.6), text(size: 6pt)[[a, b],])
  cdraw.content((9.0, 5.93), text(size: 6pt)[[c, d]])
  cdraw.content((9.0, 5.26), text(size: 6pt)[two rows])
  cdraw.line((11.4, 6.05), (12.6, 6.05), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.6, 5.0), (17.6, 7.2), fill: luma(240), radius: 0.02)
  cdraw.content((13.3, 6.65), text(size: 6pt)[a])
  cdraw.content((15.0, 6.65), text(size: 6pt)[b])
  cdraw.content((13.3, 5.55), text(size: 6pt)[c])
  cdraw.content((15.0, 5.55), text(size: 6pt)[d])
  cdraw.line((15.55, 6.65), (16.35, 6.65), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  cdraw.line((13.3, 6.1), (13.3, 5.1), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  cdraw.content((19.9, 6.65), text(size: 6pt)[N4, orthogonal])
  cdraw.content((19.9, 5.5), text(size: 6pt)[N8 adds diagonals])
  cdraw.content((11.2, 3.9), text(size: 6pt)[intsPerLine: one regex, /-?\\d+/g, per line])
  cdraw.content((11.2, 3.0), text(size: 6pt)[blankGroups: the reduce carries the paragraphs])
  cdraw.content((11.2, 2.1), text(size: 6pt)[lines without numbers yield [], not holes])
  cdraw.content((11.2, 1.2), text(size: 6pt)[rle: [[3, a], [2, b]] to aaabb and back])
})

== md5 from node:crypto

Node ships md5 in `node:crypto` behind one line, `createHash("md5")`,
and the toolbox wraps exactly that, digest to lowercase hex plus a
prefix helper for the mining shape where a puzzle compares the first n
hex characters against zeros.

The dry run: the `the prefix helper slices the leading hex
characters` block in `test/md5.test.mjs` pins the three slice
widths over the `abc` digest the vector blocks already pinned.

+ The vectors land first: the empty string, `abc`, and `message
  digest` digest to their pinned constants, `abc` to
  `900150983cd24fb0d6963f7d28e17f72`.
+ `md5Prefix("abc")` takes the default width 8 and reads
  `90015098`.
+ `md5Prefix("abc", 5)` takes 5 and reads `90015`, the mining
  shape's own comparison.
+ `md5Prefix("abc", 32)` takes the full width, and a digest is
  exactly 32 lowercase hex characters, so the slice equals
  `md5Hex("abc")`.
+ The last block hashes `abcdef609043` against `abcdef609044`, one
  counter step apart, and the digests differ.

#diagram([the abc digest at three slice widths, 5, 8, and the full 32], length: 12pt, {
  for i in range(32) {
    let f = luma(244)
    if i < 8 { f = luma(232) }
    if i < 5 { f = luma(215) }
    cdraw.rect((0.8 + i * 0.58, 4.4), (0.8 + i * 0.58 + 0.54, 5.4), fill: f, radius: 0.01)
  }
  cdraw.content((0.8 + 2.5 * 0.58, 5.9), [5: 90015], size: 6pt, fill: luma(100))
  cdraw.content((0.8 + 6.5 * 0.58, 5.9), [8: 90015098], size: 6pt, fill: luma(100))
  cdraw.content((0.8 + 20 * 0.58, 5.9), [32: the whole digest], size: 6pt, fill: luma(100))
  cdraw.content((0.8, 2.8), [abcdef609043 and abcdef609044 digest apart, one counter step], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.8, 1.8), [every digest matches the 32 lowercase hex shape], size: 6.5pt, fill: luma(100), anchor: "west")
})

The width 5 slice reads `90015`, the pinned mining prefix, in the
listing below.

#listing("icpc/samples-js/src/md5.mjs", first: 6, last: 15, caption: [createhash, hex digest, the mined prefix slice])

The tests pin the canonical vectors, the empty string
`d41d8cd98f00b204e9800998ecf8427e`, `abc` as
`900150983cd24fb0d6963f7d28e17f72`, the RFC 1321 `message digest`
vector, and `md5Prefix("abc")` as `90015098`. Those same constants are
pinned by the from-scratch implementations in
#xref-to("icpc", "toolbox-c") and #xref-to("icpc", "toolbox-lua"),
so the three toolboxes cross-check each other with every test run, the
wrapped one against the hand-rolled two.

#diagram([the mining loop, hash the candidate, compare the leading hex], length: 13pt, {
  cdraw.content((11.2, 7.6), text(size: 6.5pt)[mine the prefix, one candidate at a time])
  cdraw.rect((0.6, 4.6), (5.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.1, 5.85), text(size: 6pt)[abcdef])
  cdraw.content((3.1, 5.2), text(size: 6pt)[key + counter])
  cdraw.line((5.6, 5.4), (6.8, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.8, 4.6), (12.0, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((9.4, 5.85), text(size: 6pt)[createHash])
  cdraw.content((9.4, 5.2), text(size: 6pt)[md5, hex])
  cdraw.line((12.0, 5.4), (13.2, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.2, 4.6), (21.6, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 5.85), text(size: 6pt)[90015098 3cd2...])
  cdraw.content((17.4, 5.2), text(size: 6pt)[prefix vs target])
  cdraw.line((17.4, 4.6), (17.4, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.0, 3.2), text(size: 6pt)[match: report the counter])
  cdraw.line((13.0, 3.2), (13.2, 4.9), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((17.6, 2.3), text(size: 6pt)[no match: counter up, hash again])
  cdraw.content((11.2, 1.2), text(size: 6pt)[md5 is a scrambler here, not a lock])
})

== built here, cited elsewhere

Six files, 239 non-blank lines, 36 tests, and what each piece leans on:

#table(
  columns: (1.7fr, 1.2fr, 1.7fr),
  inset: 4pt,
  table.header([*piece*], [*status*], [*where*]),
  [min-heap with comparator], [built, `heap.mjs`], [5 tests, sift logic derived in #xref-to("dsa", "heaps")],
  [ring deque], [built, `deque.mjs`], [5 tests, empty pops return undefined],
  [bigint number kit], [built, `num.mjs`], [10 tests, wall semantics in #xref-to("javascript", "lexical")],
  [grid tuples and deltas], [built, `grid.mjs`], [6 tests, crlf tolerated],
  [input and rle], [built, `input.mjs`], [4 tests, one regex for signed ints],
  [md5], [cited, `node:crypto`], [6 tests, from-scratch in #xref-to("icpc", "toolbox-c")],
  [crt mathematics], [built, `num.mjs`], [derived in #xref-to("dsa", "numtheory")],
)

Java's chapter 4 never meets the 2^53 wall: its long is a true 64-bit
word, so the only boundary it states is the 128-bit product,
`Math.multiplyHigh` plus the low half, with BigInteger held for the
values that outgrow the word.

sources: nodejs.org docs for `node:crypto`, `Number`, and `BigInt`,
developer.mozilla.org for `String.prototype.matchAll`, RFC 1321 for the
md5 test vectors, accessed 2026-09-14. Contest context from the ICPC
Foundation, icpc.global world finals problem pages, accessed 2026-09-14.
Sample behavior verified by `npm run verify` in `books/icpc/samples-js`,
36 tests in the toolbox suite (heap 5, deque 5, num 10, grid 6, input 4,
md5 6).
