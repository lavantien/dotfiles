#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the c\# toolbox

Every finals lands the same four jobs: read the input, walk a grid, queue
work at both ends, do arithmetic past the range a machine word pretends to
have. C\# starts from an unusual position here because the base class
library already ships most of it, so this toolbox builds only what the BCL
genuinely lacks and cites the rest by chapter. The integer story: `long`
is the working type, signed 64-bit, with `checked` arithmetic where a
silent wrap would poison an answer and `System.Numerics.BigInteger`
waiting one overload away when products leave long range. Nothing in this
suite allocates a file handle, every parse runs over strings the caller
already owns, and the whole toolbox is 324 non-blank lines across 4 files
with 26 tests behind it.

== input, the shapes puzzles ship in

Puzzle text arrives in four shapes: lines, scattered integers, character
grids, and blank-line separated groups. One reader feeds all four, and the
reader is deliberately boring, split on newlines, trim the carriage
returns, drop the phantom empty line a trailing newline would invent.

The dry run: `InputTests` pins the reader's edge behavior and the
signed scan, `1,-2\n3 -4` and the range `2-4,6-8` among the asserts.

+ `Lines("a\r\nb\nc\n")` splits to four pieces, trims the `\r`, and
  drops the empty tail: a, b, c, asserted.
+ `Lines("a\n\nb")` keeps the interior blank, and `Lines("\r\n")`
  is one genuinely blank line where `Lines("")` is none, all three
  asserted.
+ The scan opens `1,-2\n3 -4`: the `1` yields 1, the minus before
  the `2` has a digit after it and no digit or letter before it, so
  it signs, -2, then 3 and -4, the asserted four.
+ On `2-4,6-8` both minuses sit between digits and read as dashes:
  2, 4, 6, 8, asserted.
+ `x=-17; y=3` yields -17 then 3, and `1000000000000` parses as one
  long, past int range, asserted.

#diagram([the minus rule at character level: a sign needs a digit after and nothing alphanumeric before, a dash has a digit before it], length: 12pt, {
  let ch(x, y, t, hot) = {
    cdraw.rect((x, y), (x + 1.4, y + 1.1), fill: if hot == 1 { luma(210) } else if hot == 2 { luma(228) } else { luma(242) }, radius: 0.02)
    cdraw.content((x + 0.7, y + 0.55), t, size: 6.5pt)
  }
  ch(0.8, 4.2, [1], 0)
  ch(2.4, 4.2, [,], 0)
  ch(4.0, 4.2, [-], 1)
  ch(5.6, 4.2, [2], 0)
  cdraw.content((4.7, 6.0), [sign: digit follows, comma precedes], size: 6.5pt, fill: luma(100))
  cdraw.line((4.7, 5.7), (4.7, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.4, 3.0), [the yield is -2], size: 6pt, fill: luma(100))
  ch(10.4, 4.2, [2], 0)
  ch(12.0, 4.2, [-], 2)
  ch(13.6, 4.2, [4], 0)
  cdraw.content((12.7, 6.0), [dash: a digit precedes], size: 6.5pt, fill: luma(100))
  cdraw.line((12.7, 5.7), (12.7, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.4, 3.0), [two yields, 2 then 4], size: 6pt, fill: luma(100))
})

The scan yields the pinned 1, -2, 3, -4 and reads the range as four
numbers, and the listings below are the reader and the scanner.

#listing("icpc/samples/src/Input.cs", first: 10, last: 35, caption: [the line reader and the three shapes it feeds])

The interesting function is the signed number scanner underneath
`Longs`. Contest inputs hide minus signs in prose (`x=-17`), in ranges
(`2-4` is two numbers, not a subtraction), and in hyphenated noise, so a
minus only starts a number when a digit follows it and no digit or letter
precedes it:

#listing("icpc/samples/src/Input.cs", first: 56, last: 75, caption: [the signed scan, a minus is a sign only in sign position])

The tests pin the trap cases: `1,-2\n3 -4` parses to 1, -2, 3, -4, the
range `2-4,6-8` yields 2, 4, 6, 8 because those minuses sit between
digits, and `1000000000000` survives because the scan yields `long`, never
`int`. `Groups` splits on blank lines and keeps interior blanks per group,
which is what paragraph-shaped inputs actually need.

#diagram([one reader, four shapes, the scanner decides what a minus means], length: 13pt, {
  // left: the raw text, right: the three consumers, arrows fan to stacked rows
  cdraw.content((11.2, 8.0), text(size: 6.5pt)[input, one reader four shapes])
  cdraw.rect((0.4, 4.15), (4.6, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((2.5, 6.45), text(size: 6pt)[puzzle text])
  cdraw.content((2.5, 5.8), text(size: 6pt)[1,-2 #h(0.4em) 3 -4])
  cdraw.content((2.5, 5.15), text(size: 6pt)[ab #h(0.4em) cd])
  cdraw.rect((5.9, 4.8), (9.7, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((7.8, 6.0), text(size: 6pt)[Lines])
  cdraw.content((7.8, 5.35), text(size: 6pt)[trims \\r])
  cdraw.line((4.6, 5.65), (5.9, 5.65), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.0, 6.6), (22.0, 7.5), fill: luma(205), radius: 0.02)
  cdraw.content((16.5, 7.05), text(size: 6pt)[Longs: 1 #h(0.2em) -2 #h(0.2em) 3 #h(0.2em) -4])
  cdraw.rect((11.0, 4.9), (22.0, 5.8), fill: luma(205), radius: 0.02)
  cdraw.content((16.5, 5.35), text(size: 6pt)[Grid: character rows ab, cd])
  cdraw.rect((11.0, 3.2), (22.0, 4.1), fill: luma(205), radius: 0.02)
  cdraw.content((16.5, 3.65), text(size: 6pt)[Groups: a b / c d])
  cdraw.line((9.7, 6.05), (11.0, 7.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.7, 5.65), (11.0, 5.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.7, 5.2), (11.0, 3.65), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 2.2), text(size: 6pt)[the scan walks chars, a minus between digits is a dash])
  cdraw.content((11.0, 1.3), text(size: 6pt)[so 2-4,6-8 reads as 2, 4, 6, 8])
  cdraw.content((11.0, 0.4), text(size: 6pt)[and every yield is a long, 1000000000000 fits])
})

== the grid vector

Grid puzzles want a two-component integer that adds, subtracts, scales,
and hashes by content. A `readonly record struct` gives all of it at
declaration: value semantics, structural equality, and a free hash code
that `HashSet` and `Dictionary` accept without ceremony, the same ground
#xref-to("dsa", "hashing") builds from scratch to teach what a hash set
is.

The dry run: `VecTests` pins the component arithmetic, the dot and
manhattan family, and the quarter-turn cycle on (3, -7).

+ The component asserts: (2, 3) + (1, -1) = (3, 2) and (2, 5) -
  (1, 1) = (1, 4), both asserted.
+ The dot product of (2, 3) with (4, -1) folds 2 x 4 = 8 and
  3 x (-1) = -3, 8 - 3 = 5, asserted, and the length squared of
  (3, 4) reads 9 + 16 = 25.
+ Manhattan: (2, -3) reads 2 + 3 = 5, and `ManhattanTo` from
  (-2, -3) to (1, 1) splits 1 - (-2) = 3 over and 1 - (-3) = 4 up,
  3 + 4 = 7, asserted.
+ Left maps (x, y) to (-y, x): (1, 0) turns to (0, 1) and (0, 1)
  to (-1, 0); right maps to (y, -x), (1, 0) to (0, -1), all
  asserted.
+ Four lefts on (3, -7) cycle (7, 3), (-3, 7), (-7, -3), and back
  to (3, -7), the asserted identity.

#diagram([the four quarter turns on one vector: each left applies (-y, x), the fourth lands home], length: 12pt, {
  let box(x, y, t, hot: false) = {
    cdraw.rect((x, y), (x + 3.0, y + 1.0), fill: if hot { luma(225) } else { luma(240) }, radius: 0.02)
    cdraw.content((x + 1.5, y + 0.5), t, size: 6.5pt)
  }
  box(0.6, 2.6, [(3, -7)], hot: true)
  box(4.8, 2.6, [(7, 3)])
  box(9.0, 2.6, [(-3, 7)])
  box(13.2, 2.6, [(-7, -3)])
  cdraw.line((3.6, 3.1), (4.8, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.8, 3.1), (9.0, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.0, 3.1), (13.2, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.2, 2.4), (16.9, 2.4), stroke: luma(100))
  cdraw.line((16.9, 2.4), (16.9, 1.3), stroke: luma(100))
  cdraw.line((16.9, 1.3), (2.1, 1.3), stroke: luma(100))
  cdraw.line((2.1, 1.3), (2.1, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.5, 0.7), [the fourth left lands home], size: 6.5pt, fill: luma(100))
  cdraw.content((4.2, 4.2), [each arrow is one (-y, x)], size: 6pt, fill: luma(100))
})

Four quarter turns land where they started, (3, -7), and the
listings below are the operators that move it.

#listing("icpc/samples/src/Vec.cs", first: 6, last: 23, caption: [arithmetic plus manhattan distance, value semantics for free])

Turns are where hand-rolled vectors earn their keep. `R`, `U`, `L`, `D`
instructions from wiring and walking puzzles become one multiply-free
step: a quarter turn counter-clockwise maps (x, y) to (-y, x), clockwise
to (y, -x), and composing those two covers every 90-degree facing a puzzle
asks for:

#listing("icpc/samples/src/Vec.cs", first: 25, last: 42, caption: [quarter turns both ways, then the two neighbor delta sets])

The tests pin the pairings, turn (1, 0) left for (0, 1), right for
(0, -1), and the manhattan family: from (2, 3) to (-1, 5) the distance is
5, three over plus two up, which is the metric every maze step cost
assumes.

#diagram([quarter turns and the manhattan corner path], length: 13pt, {
  // left: the turn map around origin; right: an L path from (2,3) to (-1,5)
  cdraw.content((4.6, 7.5), text(size: 6.5pt)[one quarter turn each way])
  cdraw.line((0.8, 4.0), (8.4, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.6, 1.4), (4.6, 6.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.6, 4.0), (7.3, 4.0), stroke: luma(60), width: 1.2pt, mark: (end: ">"))
  cdraw.content((7.9, 4.65), text(size: 6pt)[(1, 0)])
  cdraw.line((4.6, 4.0), (4.6, 5.9), stroke: (paint: luma(60), dash: "dashed"), mark: (end: ">"))
  cdraw.content((5.7, 6.3), text(size: 6pt)[(0, 1)])
  cdraw.line((4.6, 4.0), (4.6, 2.1), stroke: (paint: luma(120), dash: "dotted"), mark: (end: ">"))
  cdraw.content((5.7, 2.0), text(size: 6pt)[(0, -1)])
  cdraw.content((2.3, 6.5), text(size: 6pt)[left: (-y, x)])
  cdraw.content((2.0, 1.3), text(size: 6pt)[right: (y, -x)])
  cdraw.content((4.6, 0.4), text(size: 6pt)[two turns compose every 90 degree facing])

  cdraw.content((18.4, 7.5), text(size: 6.5pt)[manhattan is the corner path])
  let gx = c => 11.8 + (c + 2) * 1.05
  let gy = r => 7.0 - r * 1.15
  for c in range(-2, 3) {
    cdraw.circle((gx(c), gy(1)), radius: 0.04, fill: luma(220))
    cdraw.circle((gx(c), gy(3)), radius: 0.04, fill: luma(220))
    cdraw.circle((gx(c), gy(5)), radius: 0.04, fill: luma(220))
  }
  cdraw.circle((gx(2), gy(3)), radius: 0.12, fill: luma(100))
  cdraw.content((gx(2) + 1.0, gy(3) + 0.75), text(size: 6pt)[(2, 3)])
  cdraw.circle((gx(-1), gy(5)), radius: 0.12, fill: luma(100))
  cdraw.content((gx(-1) - 1.3, gy(5) + 0.5), text(size: 6pt)[(-1, 5)])
  cdraw.line((gx(2), gy(3)), (gx(-1), gy(3)), stroke: luma(60), width: 1.2pt)
  cdraw.line((gx(-1), gy(3)), (gx(-1), gy(5)), stroke: luma(60), width: 1.2pt)
  cdraw.content((gx(0.5), gy(3) + 0.5), text(size: 6pt)[3 over])
  cdraw.content((gx(-1) + 0.75, (gy(3) + gy(5)) / 2), text(size: 6pt)[2 up])
  cdraw.content((20.2, 0.4), text(size: 6pt)[manhattan 5 = |dx| + |dy|])
  cdraw.content((20.2, -0.6), text(size: 6pt)[the metric a per-step cost assumes])
})

== the deque the bcl never shipped

Here is the one real hole. The BCL has `Queue<T>` and `Stack<T>` and, since
.NET 6, `PriorityQueue<TElement, TPriority>`, whose chapter is
#xref-to("dsa", "shortestpaths"). It has no both-end deque, and the contest
wants one constantly, sliding windows, worklists that grow at the front,
spinners. So the toolbox builds the ring deque that
#xref-to("dsa", "stacksqueues") teaches from first principles, minus the
lecture, plus production manners.

The dry run: `RingTests`' rotate fixture walks `abcd` through five
asserted states, the step normalization visible in each.

+ The four pushes land `a`, `b`, `c`, `d` at slots 0 through 3,
  head 0, count 4.
+ `Rotate(1)` computes ((1 % 4) + 4) % 4 = 1, one PopFront-PushBack
  pair moves the `a`, and `ToList` reads `b c d a`, asserted.
+ `Rotate(-1)` reads the C\# remainder -1 % 4 = -1, so
  ((-1 % 4) + 4) % 4 = 3, three pairs move b, c, d and land back at
  `a b c d`, asserted.
+ `Rotate(4)` computes ((4 % 4) + 4) % 4 = 0 and runs no pairs, the
  identity, and `Rotate(0)` the same, both asserted.
+ `Rotate(-5)` normalizes ((-5 % 4) + 4) % 4 = 3, three pairs
  again, landing `d a b c`, the last asserted state.

#diagram([the rotation cycle of the fixture: each arrow is one pop-front push-back pair, the normalization picks how many run], length: 12pt, {
  let box(x, y, t, hot: false) = {
    cdraw.rect((x, y), (x + 3.2, y + 1.0), fill: if hot { luma(225) } else { luma(240) }, radius: 0.02)
    cdraw.content((x + 1.6, y + 0.5), t, size: 6.5pt)
  }
  box(0.6, 2.6, [a b c d], hot: true)
  box(5.0, 2.6, [b c d a])
  box(9.4, 2.6, [c d a b])
  box(13.8, 2.6, [d a b c])
  cdraw.line((3.8, 3.1), (5.0, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.2, 3.1), (9.4, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.6, 3.1), (13.8, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.0, 2.4), (17.7, 2.4), stroke: luma(100))
  cdraw.line((17.7, 2.4), (17.7, 1.3), stroke: luma(100))
  cdraw.line((17.7, 1.3), (2.2, 1.3), stroke: luma(100))
  cdraw.line((2.2, 1.3), (2.2, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.6, 0.7), [each arrow is one move], size: 6.5pt, fill: luma(100))
  cdraw.content((9.5, 4.4), [rotate 1 runs one, rotate -1 and -5 run three, rotate 4 runs none], size: 6pt, fill: luma(100))
})

The last state lands `d a b c` off three moves, and the listings
below are the ring that turns it.

#listing("icpc/samples/src/Ring.cs", first: 17, last: 50, caption: [push and pop at both ends, underflow refuses])

Refusal is a design decision worth stating. An empty pop that returned
`default` would invent a zero that flows into an answer silently, so both
pops and `Rotate` throw `InvalidOperationException` on an empty ring. The
wraparound test walks the seam exactly: fill four slots, pop the front,
push a back value into the freed slot, push a front value over the seam,
and the contents stay ordered.

#listing("icpc/samples/src/Ring.cs", first: 71, last: 89, caption: [doubling growth rebases the ring at slot zero])

Growth is where naive rings break. Doubling allocates the fresh array and
copies elements back to slot 0 in logical order, so `_head` resets and the
modulo arithmetic restarts from a clean base, exactly the rebase the dsa
chapter pins with its capacity 4, 8, 16, 32 sequence. `Rotate` closes the
suite by moving the front to the back one step at a time after normalizing
the step count into range, the shape circular-buffer puzzles reach for
when a full turn must be the identity.

#diagram([the seam and the rebase, two moments a ring must survive], length: 13pt, {
  // left: the tail wraps from the last slot back to slot 0
  cdraw.content((5.0, 7.7), text(size: 6.5pt)[the seam])
  let vals = ("13", "", "", "", "", "10", "11", "12")
  for (i, v) in vals.enumerate() {
    cdraw.rect((1.0 + i * 0.95, 5.4), (1.95 + i * 0.95, 6.3), fill: if v == "" { luma(245) } else if i == 0 { luma(205) } else { luma(225) }, radius: 0.02)
    if v != "" { cdraw.content((1.475 + i * 0.95, 5.85), text(size: 6pt)[#v]) }
    cdraw.content((1.475 + i * 0.95, 5.05), text(size: 5.5pt, fill: luma(255))[#i])
  }
  cdraw.content((1.475 + 5 * 0.95, 3.95), text(size: 6pt)[head])
  cdraw.line((1.475 + 5 * 0.95, 4.15), (1.475 + 5 * 0.95, 4.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.45, 6.9), (1.475, 6.9), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((8.45, 6.9), (8.45, 6.4), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((1.475, 6.9), (1.475, 6.4), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.content((5.0, 2.9), text(size: 6pt)[the next push lands at (5 + 3) mod 8 = 0])
  cdraw.content((5.0, 2.0), text(size: 6pt)[pop front steps head forward, mod 8])

  // right: growth copies back to slot 0, head resets
  cdraw.content((17.4, 7.7), text(size: 6.5pt)[the rebase])
  let old = ("7", "", "", "5", "6")
  for (i, v) in old.enumerate() {
    cdraw.rect((12.4 + i * 0.95, 5.4), (13.35 + i * 0.95, 6.3), fill: if v == "" { luma(245) } else { luma(225) }, radius: 0.02)
    if v != "" { cdraw.content((12.875 + i * 0.95, 5.85), text(size: 6pt)[#v]) }
  }
  cdraw.content((12.875 + 3 * 0.95, 4.5), text(size: 6pt)[head at 3])
  cdraw.line((12.875 + 3 * 0.95, 4.75), (12.875 + 3 * 0.95, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.4, 5.85), (11.4, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.4, 6.25), text(size: 6pt)[grow 2x])
  let fresh = ("5", "6", "7", "", "", "", "", "", "", "")
  for (i, v) in fresh.enumerate() {
    cdraw.rect((12.4 + i * 0.95, 3.1), (13.35 + i * 0.95, 4.0), fill: if v == "" { luma(245) } else { luma(205) }, radius: 0.02)
    if v != "" { cdraw.content((12.875 + i * 0.95, 3.55), text(size: 6pt)[#v]) }
    if i < 3 { cdraw.content((12.875 + i * 0.95, 2.75), text(size: 5.5pt, fill: luma(255))[#i]) }
  }
  cdraw.content((17.4, 1.3), text(size: 6pt)[copy in logical order, head resets to 0])
  cdraw.content((17.4, 0.4), text(size: 6pt)[underflow always throws, never invents])
})

== modular arithmetic, long and biginteger

Modular arithmetic is the backbone of contest math, and the BCL meets it
halfway: `BigInteger.ModPow` exists and is cited here rather than rebuilt,
while the `long` fast path, the modular inverse, and the chinese remainder
fold are worth owning. The suite pins the same anchor the other five
languages pin, 2^100 mod 1e9+7 is 976371285, and cross-checks every `long`
modpow against the BCL overload.

The dry run: `NumTests` pins the modpow anchor, the inverse
identities, and the classic crt fold with its arithmetic.

+ The anchor: `ModPow(2, 100, Prime)` returns 976371285 and equals
  `BigInteger.ModPow(2, 100, Prime)`, the cross-check assert, with
  the loop edges pinned, exponent 0 returning 1 and exponent 1
  returning the base.
+ `ModInv(3, Prime)` is 333333336, and the asserted product reads
  3 x 333333336 = 1000000008 = 1000000007 + 1, one over the
  modulus.
+ `ModInv(7, 26)` is 15: 7 x 15 = 105 and 105 - 4 x 26 = 1;
  `ModInv(3, 11)` is 4 with 3 x 4 = 12 = 11 + 1.
+ `ModInv(4, 8)` finds gcd(4, 8) = 4 and throws, the asserted
  refusal.
+ The crt fold: 2 mod 3 with 3 mod 5 combines to 8 mod 15, then
  8 + 15 = 23 at modulus 15 x 7 = 105, the asserted pair, and the
  consistent non-coprime merge lands 5 mod 12.
+ Past long range, 2^40 against 3^30, the long fold throws
  `OverflowException` where the biginteger fold returns the product
  modulus with both congruences verified.

#table(
  columns: (auto, 1.7fr, auto),
  inset: 4pt,
  table.header([*step*], [*line*], [*value*]),
  [anchor], [`ModPow(2, 100, Prime)`], [976371285],
  [inverse], [3 x 333333336], [1000000008, one over m],
  [inverse], [7 x 15], [105 = 4 x 26 + 1],
  [inverse], [3 x 4], [12 = 11 + 1],
  [fold], [(2, 3), (3, 5), (2, 7)], [23 mod 105],
  [boundary], [2^40 against 3^30], [long throws, biginteger returns],
)

Every inverse reads one over its modulus and the fold lands 23 mod
105, and the listings below are the loops that compute them.

#listing("icpc/samples/src/Num.cs", first: 12, last: 36, caption: [square and multiply on long, then the bcl biginteger version])

The inverse goes through extended Euclid rather than Fermat, because
puzzle moduli are composite as often as prime. `ModInv(3, 1000000007)` is
333333336, `ModInv(7, 26)` is 15, and a non-coprime pair throws with the
gcd in the message:

#listing("icpc/samples/src/Num.cs", first: 39, last: 57, caption: [inverse via extended euclid, long and biginteger overloads])

The CRT fold is the piece that makes giant-cycle puzzles tractable, and it
carries the chapter's sharpest integer lesson. The `long` version runs
under `checked`, so when a combined modulus leaves long range it fails
with `OverflowException` instead of wrapping, and the answer is to switch
to the `BigInteger` overload, same fold, unbounded limbs:

#listing("icpc/samples/src/Num.cs", first: 64, last: 89, caption: [the checked long fold, consistent non-coprime moduli merge])

#listing("icpc/samples/src/Num.cs", first: 92, last: 117, caption: [the biginteger fold for moduli past long range])

The classic fixture agrees everywhere: congruences 2 mod 3, 3 mod 5, 2
mod 7 fold to 23 mod 105, consistent non-coprime pairs merge through the
lcm, contradictions throw. The overflow test uses 2^40 against 3^30,
whose lcm sits near 2.3e26: the long fold throws, the biginteger fold
returns with both congruences verified, and the difference between those
two outcomes is the entire argument for keeping both overloads. The
teaching version of this material, square-and-multiply derived, binary
gcd, the small-primes machinery, lives in #xref-to("dsa", "numtheory").

#diagram([the crt fold, pairwise combine grows the modulus toward the lcm], length: 13pt, {
  cdraw.content((11.5, 7.5), text(size: 6.5pt)[three congruences, two folds, one answer])
  cdraw.rect((0.7, 5.25), (5.3, 6.95), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 6.5), text(size: 6pt)[2 mod 3])
  cdraw.content((3.0, 5.85), text(size: 6pt)[modulus 3])
  cdraw.rect((0.7, 3.35), (5.3, 5.05), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 4.6), text(size: 6pt)[3 mod 5])
  cdraw.content((3.0, 3.95), text(size: 6pt)[modulus 5])
  cdraw.rect((8.4, 4.35), (14.2, 6.05), fill: luma(205), radius: 0.02)
  cdraw.content((11.3, 5.6), text(size: 6pt)[8 mod 15])
  cdraw.content((11.3, 4.95), text(size: 6pt)[lcm 15])
  cdraw.line((5.3, 6.1), (8.4, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.3, 4.2), (8.4, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.7, 1.45), (5.3, 3.15), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 2.7), text(size: 6pt)[2 mod 7])
  cdraw.content((3.0, 2.05), text(size: 6pt)[modulus 7])
  cdraw.line((5.3, 2.3), (16.2, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.2, 3.85), (22.8, 5.55), fill: luma(205), radius: 0.02)
  cdraw.content((19.5, 5.1), text(size: 6pt)[23 mod 105])
  cdraw.content((19.5, 4.45), text(size: 6pt)[the pinned anchor])
  cdraw.line((14.2, 5.4), (16.2, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.5, 0.7), text(size: 6pt)[checked long throws past 9.2e18, biginteger carries on])
})

== built here, cited elsewhere

The chapter's contract in one table. Four files, 324 non-blank lines, 26
tests, and a strict rule for what did not get rebuilt:

#table(
  columns: (1.6fr, 1.1fr, 1.9fr),
  inset: 4pt,
  table.header([*piece*], [*status*], [*where*]),
  [input shapes, signed scan], [built, `Input.cs`], [5 tests, minus-in-sign-position rule],
  [2D vector, turns, deltas], [built, `Vec.cs`], [6 tests, value-type equality],
  [both-end ring deque], [built, `Ring.cs`], [7 tests, teaching build in #xref-to("dsa", "stacksqueues")],
  [priority queue], [cited], [#xref-to("dsa", "shortestpaths"), `PriorityQueue` since .NET 6],
  [hash sets, dictionaries], [cited], [#xref-to("dsa", "hashing"), record struct hashing rides the BCL],
  [modpow, modinv, crt], [built, `Num.cs`], [8 tests, `BigInteger.ModPow` cross-checks],
  [unbounded integers], [cited], [#xref-to("dsa", "numtheory"), `System.Numerics.BigInteger`],
)

The from-scratch bigint and md5 stories live in
#xref-to("icpc", "toolbox-c") and #xref-to("icpc", "toolbox-lua"),
which need them because their standard libraries do not ship them.
Java's chapter 4 sits at this chapter's pole too, BigInteger native,
and still builds the 128-bit roads by hand beside the object,
`Math.multiplyHigh` plus the shift-subtract lane, because the
mechanism is the lesson.

sources: learn.microsoft.com, `BigInteger.ModPow`,
`BigInteger.GreatestCommonDivisor`, and `PriorityQueue<TElement, TPriority>`
api pages, accessed 2026-09-14. Contest context from the ICPC Foundation,
icpc.global world finals problem pages, accessed 2026-09-14. Sample
behavior verified by `make verify-csharp`, 26 tests in the icpc toolbox
suite (Input 5, Vec 6, Ring 7, Num 8).
