#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the go toolbox

Go enters the contest with a small standard library that trusts the
programmer: a heap package that ships an interface instead of a
container, a big-integer package that never overflows, and not one
puzzle-shaped helper anywhere. So this toolbox is the largest of the
six, 399 non-blank lines over 7 files with 29 tests, and it is the one
place where generics earn their keep, because a heap of `Coord` ordered
by distance and a heap of `int` should share one implementation. The
integer story: `int64` and `uint64` are the working types, products that
can leave 64-bit range go through `math/bits.Mul64`, which returns the
128-bit product as two halves, and everything unbounded goes to
`math/big` rather than hoping. Nothing wraps silently by accident.

== a generic heap over container/heap

`container/heap` has not changed since it landed: it drives any type
that implements five methods, and it keeps the ordering logic in the
package while the data lives in yours. The adapter below is that
contract, a slice plus a `less` function, with `Push` and `Pop` talking
the package's `any`-typed protocol.

The dry run: `TestHeapOfStructsByField` in `heap_test.go` pushes
four workers, zoe 2, mia 1, lea 2, ada 1, and asserts the drain
against the pinned `want` slice.

+ Push zoe, priority 2, lands alone; push mia, priority 1, appends
  then sifts once, 1 under 2 swapping them to `[mia, zoe]`.
+ Push lea, priority 2, lands under the root's 1 and stays,
  `[mia, zoe, lea]`.
+ Push ada, priority 1, sifts twice: past zoe on the priority,
  then past mia on the name, `ada < mia`, into the root,
  `[ada, mia, lea, zoe]`.
+ The drain pops ada and mia, the two 1s, then lea before zoe, the
  2s broken by name, exactly the asserted `want`.

#diagram([four workers in arrival order, the drain order out, priority first and the name breaking ties], length: 12pt, {
  let w(x, y, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + 2.9, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + 1.45, y + 0.5), t, size: 6.5pt)
  }
  cdraw.content((4.2, 5.7), [pushed, arrival order], size: 6.5pt, fill: luma(100))
  w(0.6, 4.2, [zoe 2])
  w(3.8, 4.2, [mia 1])
  w(7.0, 4.2, [lea 2])
  w(10.2, 4.2, [ada 1])
  cdraw.line((6.6, 4.2), (6.6, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.3, 3.5), [the heap orders by priority, the name breaks ties], size: 6.5pt, fill: luma(100), anchor: "west")
  w(0.6, 1.7, [ada 1], fill: luma(225))
  w(3.8, 1.7, [mia 1], fill: luma(225))
  w(7.0, 1.7, [lea 2], fill: luma(225))
  w(10.2, 1.7, [zoe 2], fill: luma(225))
  cdraw.content((4.4, 0.5), [popped, the pinned want slice], size: 6.5pt, fill: luma(100))
})

The drain runs ada, mia, lea, zoe, the order the test pins, and
the listings below build the machinery that produces it.

#listing("icpc/samples-go/heap.go", first: 16, last: 31, caption: [the interface dance, five methods over a slice and a less function])

The typed front door hides it. `Heap[T]` is generic over any type with
a caller-supplied ordering, so the same code is a min-heap of ints, a
max-heap by reversed `less`, or a frontier ordered by path cost, and the
type assertions `x.(T)` never leak past the adapter:

#listing("icpc/samples-go/heap.go", first: 46, last: 60, caption: [the generic front door, push and pop return real types])

`Pop` returns `(T, bool)` so an empty heap reports itself instead of
inventing a zero value, the same refusal the other toolboxes enforce.
`Peek` and `Len` close the api. What the package does under these five
methods, sift up, sift down, the textbook heap shape, is built from
scratch in #xref-to("dsa", "heaps"), and the type-parameter machinery
itself is the subject of #xref-to("go", "generics").

#diagram([three layers, the generic type on top, the any-typed adapter in the middle, the stdlib algorithm below], length: 13pt, {
  cdraw.content((11.2, 8.35), text(size: 6.5pt)[a heap in three layers])
  cdraw.rect((1.0, 6.4), (21.4, 7.95), fill: luma(205), radius: 0.02)
  cdraw.content((11.2, 7.5), text(size: 6pt)[Heap[T], Push(x T), Pop() (T, bool), Peek])
  cdraw.content((11.2, 6.85), text(size: 6pt)[one less function decides min, max, or by-field])
  cdraw.rect((1.0, 4.15), (21.4, 5.7), fill: luma(225), radius: 0.02)
  cdraw.content((11.2, 5.25), text(size: 6pt)[heapAdapter[T]: Len Less Swap Push(any) Pop() any])
  cdraw.content((11.2, 4.6), text(size: 6pt)[items []T plus less, the any boundary lives here])
  cdraw.rect((1.0, 1.9), (21.4, 3.45), fill: luma(245), radius: 0.02)
  cdraw.content((11.2, 3.0), text(size: 6pt)[container/heap: Push Pop Init Fix])
  cdraw.content((11.2, 2.35), text(size: 6pt)[sift up and sift down, shipped in the stdlib])
  cdraw.line((6.0, 6.4), (6.0, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.4, 6.4), (16.4, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 4.15), (6.0, 3.45), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.4, 4.15), (16.4, 3.45), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.2, 1.1), text(size: 6pt)[the assertions x.(T) never escape the middle box])
  cdraw.content((11.2, 0.2), text(size: 6pt)[an empty Pop returns (zero, false), never fiction])
})

== reading input the scanner way

Go has no `String.split` culture around files, it has `io.Reader` and
`bufio.Scanner`, and the toolbox embraces that: every reader takes a
reader. `ReadLines` drains it into one string per line and keeps every
line it saw, blank or not, because the blank lines are paragraph
boundaries and dropping them here would lose information the group
splitter needs later.

The dry run: `TestSplitGroups` in `input_test.go` hands the
splitter nine lines with three blanks and asserts the three
groups, plus nil for a blanks-only page.

+ The fixture lines run `a1, a2, blank, b1, blank, blank, c1, c2,
  c3`, the shape `ReadLines` leaves behind.
+ The first group opens at a1 and takes a2, two lines.
+ The blank at index 2 flushes it; b1 opens the second group alone.
+ Two blanks follow: the first flushes b1's group, the second meets
  an empty pending group and opens nothing, so no empty group
  appears between them.
+ c1, c2, c3 fill the third group, and the return is the asserted
  three, `a1 a2`, `b1`, `c1 c2 c3`.
+ On two blanks alone every line is a seam, nothing ever pends,
  and the return is nil, the pinned refusal.

#diagram([nine lines, three seams, three groups: a blank that meets an empty pending group opens nothing], length: 12pt, {
  let cell(x, t, seam) = {
    cdraw.rect((x, 4.2), (x + 1.1, 5.3), fill: if seam { luma(222) } else { luma(240) }, radius: 0.02)
    if t != [] { cdraw.content((x + 0.55, 4.75), t, size: 6pt) }
  }
  cdraw.content((0.6, 5.9), [nine lines, blanks shaded], size: 6.5pt, fill: luma(100), anchor: "west")
  cell(0.6, [a1], false)
  cell(1.85, [a2], false)
  cell(3.1, [], true)
  cell(4.35, [b1], false)
  cell(5.6, [], true)
  cell(6.85, [], true)
  cell(8.1, [c1], false)
  cell(9.35, [c2], false)
  cell(10.6, [c3], false)
  cdraw.content((12.1, 4.75), [the doubled seam flushes once, then opens nothing], size: 6.5pt, fill: luma(100), anchor: "west")
  let g(x, w, t) = {
    cdraw.rect((x, 1.6), (x + w, 2.6), fill: luma(225), radius: 0.02)
    cdraw.content((x + w / 2, 2.1), t, size: 6pt)
  }
  cdraw.line((1.75, 4.2), (1.75, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.9, 4.2), (4.9, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.9, 4.2), (9.9, 2.6), stroke: luma(100), mark: (end: ">"))
  g(0.6, 2.35, [a1 a2])
  g(4.35, 1.1, [b1])
  g(8.1, 3.6, [c1 c2 c3])
  cdraw.content((0.6, 0.6), [two blanks alone: nil, never one empty group], size: 6.5pt, fill: luma(100), anchor: "west")
})

Nine lines fold to three groups, and a blanks-only page returns
nil, in the listings below.

#listing("icpc/samples-go/input.go", first: 14, last: 25, caption: [drain an io.reader, one string per line, blanks kept])

`ReadInts` is the column reader. Contest inputs hand out numbers one per line
as often as several per line, so it splits each line on whitespace and
parses field by field, failing loudly with the offending field in the
error:

#listing("icpc/samples-go/input.go", first: 26, last: 42, caption: [whitespace-separated integers, one or many per line])

The test pins the honesty: input `alpha beta <blank> gamma <blank>`
comes back as five lines including both trailing blanks, and `ReadInts`
refuses a non-integer field instead of skipping it. That trailing-blank
behavior is a deliberate difference from the C\# toolbox, which trims
the phantom last line at parse time, and it exists because
`SplitGroups` consumes blanks as seams rather than noise.

#diagram([one scanner, three downstream shapes], length: 13pt, {
  cdraw.content((11.0, 8.2), text(size: 6.5pt)[one scanner, three shapes])
  cdraw.rect((8.3, 6.05), (13.7, 7.65), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 7.18), text(size: 6pt)[io.Reader])
  cdraw.content((11.0, 6.52), text(size: 6pt)[puzzle text, any source])
  cdraw.line((11.0, 6.05), (11.0, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.2, 4.0), (14.8, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 5.13), text(size: 6pt)[bufio.Scanner])
  cdraw.content((11.0, 4.47), text(size: 6pt)[ReadLines: every line, blanks kept])
  cdraw.line((9.0, 4.0), (3.3, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.0, 4.0), (10.1, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.0, 4.0), (16.9, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.3, 2.1), (6.3, 3.7), fill: luma(205), radius: 0.02)
  cdraw.content((3.3, 3.23), text(size: 6pt)[ReadInts])
  cdraw.content((3.3, 2.57), text(size: 6pt)[Fields + Atoi, loud errors])
  cdraw.rect((7.1, 2.1), (13.1, 3.7), fill: luma(205), radius: 0.02)
  cdraw.content((10.1, 3.23), text(size: 6pt)[GridFromLines])
  cdraw.content((10.1, 2.57), text(size: 6pt)[rows must agree in length])
  cdraw.rect((13.9, 2.1), (19.9, 3.7), fill: luma(205), radius: 0.02)
  cdraw.content((16.9, 3.23), text(size: 6pt)[SplitGroups])
  cdraw.content((16.9, 2.57), text(size: 6pt)[blank seams cut paragraphs])
  cdraw.content((10.1, 1.2), text(size: 6pt)[trailing blanks survive ReadLines on purpose])
  cdraw.content((10.1, 0.3), text(size: 6pt)[SplitGroups on only blanks returns nil, not one empty group])
})

== coordinates on the grid

A grid is a slice of equal-length rows plus coordinate arithmetic, and
Go structs make that arithmetic explicit. `Coord` is row then column,
`Index` flattens into a row-major offset, and the inverse `CoordAt`
rebuilds the coordinate, with the test round-tripping every cell of a
small grid and pinning (2, 3) at 5 columns to index 13.

The dry run: `TestNeighborsCornerOf3x3` in `grid_test.go` walks
`Coord{0, 0}` on a 3 by 3 fixture under both delta sets and
asserts the survivor lists in order.

+ The corner sits at row 0, column 0, where `InBounds` rejects any
  index below 0.
+ `Deltas4` offers its four steps in order: (-1, 0) and (0, -1)
  step outside and die, (0, 1) survives as `Coord{0, 1}` and
  (1, 0) as `Coord{1, 0}`, the asserted pair.
+ `Deltas8` offers eight, row by row: the three with row -1 all
  die, (0, -1) dies with them, (0, 1) joins, then of row +1 the
  (1, -1) dies while (1, 0) and (1, 1) join.
+ The 8-delta walk ends with `Coord{0, 1}`, `Coord{1, 0}`,
  `Coord{1, 1}`, three survivors of the eight offered.

#diagram([the corner's eight offered steps: three survive, five cross the edge], length: 12pt, {
  for r in range(3) {
    for c in range(3) {
      let f = luma(248)
      if r == 0 and c == 0 { f = luma(210) }
      if (r == 0 and c == 1) or (r == 1 and c == 0) or (r == 1 and c == 1) { f = luma(228) }
      cdraw.rect((1.0 + c * 1.3, 5.6 - r * 1.3), (2.3 + c * 1.3, 6.9 - r * 1.3), fill: f, radius: 0.02)
    }
  }
  cdraw.line((1.65, 6.25), (2.95, 6.25), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  cdraw.line((1.65, 6.25), (1.65, 4.95), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  cdraw.line((1.65, 6.25), (2.95, 4.95), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  cdraw.line((1.65, 6.25), (1.65, 7.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.65, 6.25), (0.3, 6.25), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.65, 6.25), (0.3, 7.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.65, 6.25), (0.3, 4.95), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((1.65, 6.25), (2.95, 7.5), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((5.2, 6.6), [solid: the three survivors], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((5.2, 5.7), [deltas4 returns (0, 1), then (1, 0)], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((5.2, 4.8), [deltas8 appends (1, 1)], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((5.2, 3.9), [dashed: five steps cross the edge], size: 6.5pt, fill: luma(100), anchor: "west")
})

Three of eight survive, the pinned corner lists, and the listings
below hold the walk.

#listing("icpc/samples-go/input.go", first: 43, last: 56, caption: [equal-length rows become a byte grid, ragged input refused])

#listing("icpc/samples-go/grid.go", first: 23, last: 44, caption: [the two delta sets and the in-bounds neighbor walk])

`Deltas4` and `Deltas8` are the entire topology of grid puzzles,
orthogonal steps for mazes and floods, all eight for visibility and
diagonal movement, and `Neighbors` filters them through `InBounds` so
every walk starts from a safe enumeration instead of an `if` ladder at
each step. The center-cell test pins both neighborhoods exactly, four
neighbors under `Deltas4`, eight under `Deltas8`, and a corner keeps
only the three that exist.

#diagram([row-major flattening and the two neighborhoods], length: 13pt, {
  cdraw.content((5.4, 8.2), text(size: 6.5pt)[row major, index = row \* cols + col])
  for r in range(0, 3) {
    for c in range(0, 5) {
      cdraw.rect((1.6 + c * 1.05, 6.6 - r * 0.95), (2.65 + c * 1.05, 7.55 - r * 0.95), fill: if r == 2 and c == 3 { luma(205) } else { luma(240) }, radius: 0.02)
      cdraw.content((2.125 + c * 1.05, 7.07 - r * 0.95), text(size: 5.5pt)[#(r * 5 + c)])
    }
  }
  cdraw.content((5.9, 3.6), text(size: 6pt)[the dark cell is (2, 3), Index(5) = 13])
  cdraw.content((5.9, 2.7), text(size: 6pt)[CoordAt(13, 5) walks back to (2, 3)])
  cdraw.content((5.9, 1.8), text(size: 6pt)[InBounds rejects corners before the walk starts])

  cdraw.content((18.2, 8.2), text(size: 6.5pt)[four orthogonal, eight total])
  cdraw.rect((16.6, 4.1), (17.8, 5.3), fill: luma(205), radius: 0.02)
  cdraw.content((17.2, 4.7), text(size: 6pt)[c])
  for d in ((-1, 0), (1, 0), (0, -1), (0, 1)) {
    cdraw.line((17.2 + d.at(0) * 0.55, 4.7 + d.at(1) * 0.55), (17.2 + d.at(0) * 1.0, 4.7 + d.at(1) * 1.0), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  }
  for d in ((-1, -1), (1, -1), (-1, 1), (1, 1)) {
    cdraw.line((17.2 + d.at(0) * 0.55, 4.7 + d.at(1) * 0.55), (17.2 + d.at(0) * 1.0, 4.7 + d.at(1) * 1.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  }
  cdraw.content((14.6, 3.0), text(size: 6pt)[solid: Deltas4, mazes and floods])
  cdraw.content((15.0, 2.1), text(size: 6pt)[dashed: the diagonals of Deltas8])
  cdraw.content((15.4, 1.2), text(size: 6pt)[Neighbors filters both through InBounds])
})

== the math/big wing

When a number will not fit 64 bits, Go's answer is not a trap but a
type: `big.Int`, arbitrary-precision limbs with the same operator feel
as the rest of the package library. The toolbox keeps thin wrappers so
puzzle code says `BigPow` and never allocates limb slices by hand.

The dry run: `TestBigFactorialAndChoose` in `big_test.go` pins
`BigChoose(52, 5)` at 2598960, the poker hands, and symmetry
keeps k = 5 the shorter side against 52 - 5 = 47, so i runs 0
through 4.

+ i = 0: multiply by 52, divide by 1, running value 52.
+ i = 1: 52 x 51 = 2652, then ÷ 2 = 1326.
+ i = 2: 1326 x 50 = 66300, then ÷ 3 = 22100.
+ i = 3: 22100 x 49 = 1082900, then ÷ 4 = 270725.
+ i = 4: 270725 x 48 = 12994800, then ÷ 5 = 2598960, the pinned
  poker-hands count.
+ Every division lands exact, each running value itself a binomial
  coefficient, and the test cross-checks the same shape against
  the factorial identity at 30 choose 12.

#table(
  columns: (auto, auto, auto, auto),
  inset: 4pt,
  table.header([*i*], [*x (52 - i)*], [*÷ (i + 1)*], [*running*]),
  [0], [52], [1], [52],
  [1], [51], [2], [1326],
  [2], [50], [3], [22100],
  [3], [49], [4], [270725],
  [4], [48], [5], [2598960],
)

The fold ends at 2598960 with no factorial ever formed, and the
listings below hold the wrapper.

#listing("icpc/samples-go/big.go", first: 11, last: 16, caption: [exp with no modulus, limbs grow as needed])

#listing("icpc/samples-go/big.go", first: 32, last: 48, caption: [the binomial coefficient, multiplicative form, symmetry first])

`BigChoose` is the tour's teaching moment: factorials are honest but
the multiplicative form, multiply by (n - i), divide by (i + 1), working
from the shorter side, keeps every intermediate an exact integer and an
order of magnitude smaller. The tests pin the classics, 2^100 as its 31
digits, 10! as 3628800, 52 choose 5 as 2598960, the poker hands, and
cross-check choose against the factorial identity. Parsing meets the
same standard, decimal, `0x` hex, and `0b` binary all accepted, garbage
refused, hex round-tripping through `BigToHex`:

#listing("icpc/samples-go/big.go", first: 49, last: 57, caption: [decimal, hex, and binary in, 0x-prefixed hex out])

`BigInverse` wraps `big.Int.ModInverse` and returns nil when no inverse
exists, gcd 2 for 2 mod 4 in the test, and `BigFactorial` completes the
set. The from-scratch limb machinery, sign-magnitude arrays in base 1e9,
is built and dissected in #xref-to("icpc", "toolbox-c") and
#xref-to("icpc", "toolbox-lua"), which need it because C and Lua ship
nothing comparable.

#diagram([routing an integer job, the 64-bit fast path against the unbounded wing], length: 13pt, {
  cdraw.content((11.0, 8.0), text(size: 6.5pt)[routing an integer job])
  cdraw.rect((7.4, 5.45), (14.6, 7.05), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 6.58), text(size: 6pt)[the job])
  cdraw.content((11.0, 5.92), text(size: 6pt)[pow, inverse, choose, parse])
  cdraw.content((11.0, 4.95), text(size: 6pt)[does every value and product fit 64 bits?])
  cdraw.line((8.4, 4.7), (3.4, 3.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.6, 4.7), (18.6, 3.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.9, 5.05), text(size: 6pt)[yes])
  cdraw.content((17.6, 4.5), text(size: 6pt)[no, or not sure])
  cdraw.rect((0.4, 1.65), (6.4, 3.75), fill: luma(205), radius: 0.02)
  cdraw.content((3.4, 3.4), text(size: 6pt)[uint64 fast path])
  cdraw.content((3.4, 2.75), text(size: 6pt)[bits.Mul64, GCD, CRT])
  cdraw.content((3.4, 2.05), text(size: 6pt)[num.go])
  cdraw.rect((15.6, 1.65), (22.8, 3.75), fill: luma(205), radius: 0.02)
  cdraw.content((19.2, 3.4), text(size: 6pt)[math/big wing])
  cdraw.content((19.2, 2.75), text(size: 6pt)[BigPow, ModInverse, BigChoose])
  cdraw.content((19.2, 2.05), text(size: 6pt)[big.go])
  cdraw.content((11.0, 0.9), text(size: 6pt)[the anchor 2^100 mod 1e9+7 is 976371285, raw 2^100 has 31 digits])
})

== modular arithmetic through bits

The modular core runs on one observation: `math/bits.Mul64` multiplies
two uint64 values and returns the 128-bit product as a high and a low
half, and `bits.Div64` divides that pair back down. `MulMod` is
therefore three lines, exact for any modulus, no 128-bit type needed.

The dry run: `TestCRTClassicAndRejection` in `num_test.go` folds
the system 2 mod 3, 3 mod 5, 2 mod 7 and asserts the pair
(23, 105), then both non-coprime branches.

+ The moduli 3 and 5 are coprime, so the first merge combines them
  into 3 x 5 = 15; the class 8 works, 8 = 2 + 3 x 2 and 8 = 3 +
  5 x 1.
+ The second merge combines 15 with 7 into 15 x 7 = 105; the class
  23 works, 23 = 8 + 15 x 1 and 23 = 21 + 2, and the test reads
  back (23, 105).
+ Shared factors in agreement: 5 mod 8 already says 1 mod 4, so
  the pair collapses to 5 mod 8, the lcm class the test pins.
+ Shared factors in conflict: 3 mod 8 says 3 mod 4, not 1, and
  the fold refuses the system.

#diagram([the fold: two merges land the pinned class, and a shared-factor pair either collapses or is refused], length: 12pt, {
  let c(x, y, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + 2.4, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + 1.2, y + 0.5), t, size: 6.5pt)
  }
  c(0.6, 4.6, [2 mod 3])
  c(0.6, 3.2, [3 mod 5])
  c(4.6, 3.9, [8 mod 15])
  c(8.6, 3.9, [23 mod 105], fill: luma(225))
  c(8.6, 5.4, [2 mod 7])
  cdraw.line((3.0, 5.1), (4.6, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.0, 3.7), (4.6, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.0, 4.4), (8.6, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.8, 5.4), (9.8, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.8, 3.2), [3 x 5 = 15], size: 6pt, fill: luma(100))
  cdraw.content((9.8, 3.2), [15 x 7 = 105], size: 6pt, fill: luma(100))
  cdraw.content((0.6, 2.0), [agreeing shared factors: 5 mod 8 says 1 mod 4, merges to 5 mod 8], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.6, 1.1), [clashing: 3 mod 8 says 3 mod 4, the system is refused], size: 6.5pt, fill: luma(100), anchor: "west")
})

The fold ends at the pinned pair, 23 with modulus 105, in the
listings below.

#listing("icpc/samples-go/num.go", first: 35, last: 60, caption: [mulmod through the 128-bit halves, then square-and-multiply])

`ModPow` rides `MulMod` at every step, so squaring never truncates, and
the suite pins the cross-language anchor, 2^100 mod 1e9+7 is 976371285.
The inverse goes through `big.Int.ModInverse`, wrapped with a gcd guard
so shared factors report an error instead of a nil dereference, and
that choice buys composite moduli for free, where Fermat's little
theorem would only work on primes.

#listing("icpc/samples-go/num.go", first: 80, last: 110, caption: [the crt fold, shared factors must agree or the system is refused])

`CRT` folds congruences pairwise: coprime moduli combine into their
product, shared factors merge through the lcm when the residues agree
and are refused when they do not, with the disagreement reported naming
both statements. The test pins the classic, 2 mod 3, 3 mod 5, 2 mod 7
folds to 23 mod 105, exactly the value the C\# and JavaScript toolboxes
pin, and the teaching derivation of every piece used here lives in
#xref-to("dsa", "numtheory").

#diagram([the 128-bit product split into halves, divided back to a remainder], length: 13pt, {
  cdraw.content((11.2, 8.0), text(size: 6.5pt)[one multiply, three registers])
  cdraw.rect((7.0, 5.55), (15.4, 7.15), fill: luma(235), radius: 0.02)
  cdraw.content((11.2, 6.68), text(size: 6pt)[a \* b, both < m])
  cdraw.content((11.2, 6.02), text(size: 6pt)[two uint64 inputs])
  cdraw.line((11.2, 5.55), (11.2, 4.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.6, 5.55), text(size: 6pt)[bits.Mul64])
  cdraw.rect((4.6, 3.5), (11.0, 4.95), fill: luma(205), radius: 0.02)
  cdraw.content((7.8, 4.5), text(size: 6pt)[hi, the high 64])
  cdraw.content((7.8, 3.85), text(size: 6pt)[0 when a \* b fits])
  cdraw.rect((11.4, 3.5), (17.8, 4.95), fill: luma(205), radius: 0.02)
  cdraw.content((14.6, 4.5), text(size: 6pt)[lo, the low 64])
  cdraw.content((14.6, 3.85), text(size: 6pt)[a truncated uint64])
  cdraw.line((9.6, 3.5), (10.8, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.0, 3.5), (13.0, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.6, 3.15), text(size: 6pt)[the 128-bit product])
  cdraw.rect((7.6, 1.45), (14.8, 2.9), fill: luma(245), radius: 0.02)
  cdraw.content((11.2, 2.5), text(size: 6pt)[bits.Div64(hi, lo, m)])
  cdraw.content((11.2, 1.85), text(size: 6pt)[remainder < m, always exact])
  cdraw.content((11.2, 0.6), text(size: 6pt)[modpow squares through here, so nothing ever truncates])
})

== digests and json leaves

Two contest staples are one-liners once the imports are right, and the
toolbox keeps them that way. MD5 is broken as security and the contest
does not care, the puzzles use it as a deterministic scrambler, so
`MD5Hex` is `crypto/md5` plus `encoding/hex` with a prefix helper for
the mining shape, first n hex characters compared against zeros.

The dry run: `TestDecodeStruct` in `json_test.go` unmarshals the
passport fixture through the field tags and asserts every mapped
field.

+ The document carries id `p7`, issued 2020, tags `north` and
  `east`, a nested validity with year 2024 and ok true, and one
  `extra` key no struct field declares.
+ `DecodeStruct` maps tag to field: `p.ID` reads `p7` and
  `p.Issued` reads 2020.
+ `Tags` lands as a slice of 2, with `Tags[1]` the pinned `east`.
+ `Validity` nests one level down, `Year` 2024 and `OK` true,
  both asserted.
+ The `extra` key finds no destination and is dropped, and the
  sibling test refuses garbage with an error instead of guessing.

#diagram([the passport through the field tags: four keys map, the undeclared one drops], length: 12pt, {
  cdraw.rect((6.2, 1.0), (9.4, 6.2), fill: luma(238), radius: 0.02)
  cdraw.content((7.8, 5.8), [field tags], size: 6.5pt)
  let row(y, l, r, dead: false) = {
    cdraw.content((0.6, y), l, size: 6pt, anchor: "west")
    cdraw.content((14.2, y), r, size: 6pt, anchor: "west")
    cdraw.line((5.4, y), (6.2, y), stroke: if dead { (paint: luma(150), dash: "dashed") } else { luma(100) }, mark: (end: ">"))
    if not dead { cdraw.line((9.4, y), (13.8, y), stroke: luma(100), mark: (end: ">")) }
  }
  row(5.4, [id "p7"], [ID "p7"])
  row(4.4, [issued 2020], [Issued 2020])
  row(3.4, [tags north east], [Tags, 2 entries, east last])
  row(2.4, [validity 2024 ok], [Year 2024, OK true])
  row(1.4, [extra "ignored by the struct"], [dropped, no field], dead: true)
})

The struct fills, id `p7`, issued 2020, tags 2, validity 2024,
and the listings below hold both halves of the section.

#listing("icpc/samples-go/digest.go", first: 11, last: 16, caption: [the scrambler, digest to lowercase hex, prefix sliced])

The digest tests pin the standard vectors, the empty string and `abc`,
the same constants the from-scratch C and Lua implementations pin, so
the three toolboxes cross-check each other, and `MD5Prefix("abc", 5)`
is 90015. The json half carries one fact that must be stated out loud:
`encoding/json` decodes every number into `float64`, so a schema-free
walk over decoded values sees floats at the leaves, integers included:

#listing("icpc/samples-go/json.go", first: 44, last: 64, caption: [the recursive walk, numeric leaves at any depth, bool string nil contribute zero])

`SumNumbers` recurses through maps and arrays and adds every numeric
leaf, and the test pins the honesty of the walk on a crafted document:
scores 1, 2, 3 and a deeply nested 4.5 sum to 10.5, while a `true`
flag and a null contribute nothing. For typed shapes the same package
fills structs through field tags, `DecodeStruct` maps the passport
fixture field by field, and the wider json story, including the v2
api, belongs to #xref-to("go", "stdlib2").

#diagram([the walk sums float64 leaves, the boolean and null are zeros], length: 13pt, {
  cdraw.content((11.4, 8.35), text(size: 6.5pt)[every numeric leaf, one sum])
  cdraw.rect((8.6, 6.05), (14.2, 7.65), fill: luma(235), radius: 0.02)
  cdraw.content((11.4, 7.18), text(size: 6pt)[root object])
  cdraw.content((11.4, 6.52), text(size: 6pt)[decoded map[string]any])
  cdraw.rect((0.6, 3.8), (7.0, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((3.8, 4.93), text(size: 6pt)[scores: [1, 2, 3]])
  cdraw.content((3.8, 4.27), text(size: 6pt)[three float64 leaves])
  cdraw.rect((8.2, 3.8), (14.6, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.4, 4.93), text(size: 6pt)[nested.deep.val: 4.5])
  cdraw.content((11.4, 4.27), text(size: 6pt)[one leaf, any depth])
  cdraw.rect((15.8, 3.8), (22.6, 5.4), fill: luma(245), radius: 0.02)
  cdraw.content((19.2, 4.93), text(size: 6pt)[flag: true])
  cdraw.content((19.2, 4.27), text(size: 6pt)[nothing: null, both zero])
  cdraw.line((10.0, 6.05), (3.8, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.4, 6.05), (11.4, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.8, 6.05), (19.2, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.8, 3.8), (9.6, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.4, 3.8), (11.4, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.4, 1.55), (15.4, 3.0), fill: luma(225), radius: 0.02)
  cdraw.content((11.4, 2.6), text(size: 6pt)[SumNumbers])
  cdraw.content((11.4, 1.95), text(size: 6pt)[1 + 2 + 3 + 4.5 = 10.5, pinned])
  cdraw.content((11.4, 0.7), text(size: 6pt)[json hands the walk float64 leaves, integers included])
})

== built here, cited elsewhere

Seven files, 399 non-blank lines, 29 tests, and the split between what
this toolbox owns and what the standard library already did well:

#table(
  columns: (1.7fr, 1.2fr, 1.7fr),
  inset: 4pt,
  table.header([*piece*], [*status*], [*where*]),
  [generic heap], [built, `heap.go`], [over `container/heap`, sift logic in #xref-to("dsa", "heaps")],
  [input readers], [built, `input.go`], [5 tests, blanks kept on purpose],
  [coords, deltas, neighbors], [built, `grid.go`], [4 tests, index round trip pinned],
  [big integer wrappers], [built, `big.go`], [over `math/big`, from-scratch limbs in #xref-to("icpc", "toolbox-c")],
  [mulmod, modpow, crt], [built, `num.go`], [`math/bits` halves, inverse via `ModInverse`],
  [md5], [cited], [`crypto/md5`, from-scratch in chapters 2 and 7],
  [json decode and walk], [built, `json.go`], [over `encoding/json`, typed shapes via tags],
  [gcd, lcm, sieve], [built where puzzle-shaped], [full treatment in #xref-to("dsa", "numtheory")],
)

sources: pkg.go.dev, `container/heap`, `math/bits`, `math/big`,
`crypto/md5`, and `encoding/json` package pages, accessed 2026-09-14.
Contest context from the ICPC Foundation, icpc.global world finals
problem pages, accessed 2026-09-14. Sample behavior verified by
`make verify-go` in `books/icpc/samples-go`, 29 tests in the toolbox
module (heap 3, input 5, grid 4, num 4, big 4, digest 4, json 5).
