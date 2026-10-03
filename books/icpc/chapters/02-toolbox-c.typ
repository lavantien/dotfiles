// book 9, chapter 2: the c toolbox. ten modules over eleven
// headers in books/icpc/samples-c/src/Ch02/, one test program per
// module, all listings sliced from the landed files
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= the c toolbox

C is where the year chapters pay the highest price for convenience, so
the C toolbox pays it once. Eleven headers live in
`books/icpc/samples-c/src/Ch02/`, every function `static inline`,
no translation units, no build file: a year chapter includes what it
needs and compiles one file. Each module ships with a `_test.c`
program that runs crafted fixtures with hand-computed answers, and the
gate compiles all of them under `-Werror` with the format and address
sanitizer legs on top. Ten programs, 251 internal checks, 1125 lines
of header. This chapter walks each module with its test, and where a
design decision has a story, the story is told here once so the year
chapters can just cite it. The Lua twin of this chapter is
#xref-to("icpc", "toolbox-lua"), and the two cross-cite freely:
same structures, different machines underneath.

== header-only, under the compiler's eye

Every declaration is `static inline` in a header guarded by an
`#ifndef`. That choice keeps the toolbox trivial to import, one
include line per module, and it also means every including translation
unit sees every function body, so the compiler inlines what is small
and warns about what is unused or wrong at the call site, and
`-Werror` turns every warning into a build failure. The ucrt adds a
twist the tests have to live with: the platform marks the unbounded
byte helpers, `strcpy`, `strcat`, the `fopen` family, as deprecated,
and under `-Werror` a deprecation attribute is fatal. The toolbox does
not silence that globally. It does two narrower things: `io.h`
defines `_CRT_SECURE_NO_WARNINGS` before any standard header lands,
because that module genuinely wants the portable `fopen`, and the
modules that copy bytes, `map.h` and `json.h`, carry their own bounded
copy loops so no deprecated call exists to warn about. The test
harness itself is one macro used by all ten programs.

The dry run: `bigint_test.c`'s 36 checks are the count the chapter's
close pins for the module, and the walk is the ledger of how `n`
climbs to the line that prints it.

+ The opening block pins one parse seven ways: the parse itself, the
  round-trip string, `a.n` = 3, the limbs 567890123, 678901234,
  12345 from least to most significant, and sign 1; `n` stands at 7.
+ The carry fixture adds 3, parse, printed sum, and limb count, `n`
  at 10.
+ Plain `123 + 456` and `456 - 123` add 2 string compares, `n` at 12.
+ The signed group adds 6, the `-100` parse and its sign, two `-60`
  prints, the `0` print, and the positive zero sign, `n` at 18.
+ Comparisons add 7 over `bi_cmp`, `n` at 25.
+ Multiply adds 5, two parses per product and both string compares,
  `n` at 30.
+ Small division adds 3, parse, quotient string, remainder, `n` at 33.
+ The three garbage refusals close the file, `n` at 36, and the final
  `printf` prints `ok 36 bigint`.

#diagram([one program under the check macro: every true condition bumps the count, the final printf carries it], length: 12pt, {
  let box(x, y, w, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0.8, 3.2, 3.6, [36 conditions])
  box(5.6, 3.2, 3.2, [n++ each], fill: luma(244))
  box(10.0, 3.2, 4.6, [ok 36 bigint], fill: luma(225))
  cdraw.line((4.4, 3.7), (5.6, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.8, 3.7), (10.0, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.8, 1.8), [the opening block alone is 7 checks over one 23-digit parse], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.8, 0.8), [nothing else prints, the count rides to the end silently], size: 6.5pt, fill: luma(100), anchor: "west")
})

The count lands whole in `ok 36 bigint`, and the macro doing the
counting is the listing below.

#listing("icpc/samples-c/src/Ch02/bigint_test.c", first: 9, last: 18, caption: [c: the check macro every module test is built on, counting as it passes])

A failed check prints the file and line and returns nonzero, the
runner reports one ok line per program, and the internal count rides
in the `n` that the final `printf` carries. The assertions are the
documentation: a fixture like `4 9 1 7 3 8 6 5 2` pushed into the
heap and popped back as `1` through `9` says more about the heap than
a paragraph would.

== big integers, split in two headers

The finals hand out numbers past 64 bits often enough that the toolbox
carries its own bigint rather than reaching for anything external. The
representation is sign-magnitude over base one billion limbs, least
significant limb first, twelve limbs, 108 decimal digits of headroom.
Zero is a magnitude with the positive sign, and the sign rule is
enforced at every exit: zero never carries a minus. The arithmetic
core, compare, add, subtract, multiply, small division, lives in
`bigint.h`, and parsing and printing live in `bigint_io.h`. The split
is deliberate: a year chapter that only needs arithmetic on values it
built from `unsigned long long` includes one header, and the parse and
print half, with its 25-bytes-per-limb buffer contract, stays out of
the way.

The dry run: the module's carry fixture, `99999999999999999999 + 1`
in `bigint_test.c`, asserts the printed sum and the limb count.

+ `bi_parse` cuts the twenty nines into three limbs from the right:
  limb 0 = 999999999, limb 1 = 999999999, limb 2 = 99, sign +1,
  `a.n` = 3.
+ `bi_from_u64(&b, 1)` is the single limb 1.
+ The magnitude add folds limb 0: 999999999 + 1 = 1000000000, one
  full base, so the limb records 1000000000 - 1000000000 = 0 and
  carries 1.
+ Limb 1 the same: 999999999 + 1 = 1000000000, limb 1 records 0,
  carry 1.
+ Limb 2: 99 + 1 = 100, under the base, no carry, and `r.n` stays 3.
+ `bi_to_string` prints the top limb 100 bare and pads the two below
  to nine digits, 3 + 9 + 9 = 21 characters concatenating to
  `100000000000000000000`, the pinned string.

#diagram([the carry chain across all three limbs: each full base records a zero limb and passes one up, the top limb absorbs the last], length: 12pt, {
  let cell(x, y, w, t, fill) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6.5pt)
  }
  cell(0.8, 4.4, 4.6, [999999999], luma(238))
  cell(0.8, 3.1, 4.6, [+ 1], luma(248))
  cell(0.8, 1.8, 4.6, [0, carry 1], luma(225))
  cell(6.6, 4.4, 4.6, [999999999], luma(238))
  cell(6.6, 3.1, 4.6, [+ carry 1], luma(248))
  cell(6.6, 1.8, 4.6, [0, carry 1], luma(225))
  cell(12.4, 4.4, 4.6, [99], luma(238))
  cell(12.4, 3.1, 4.6, [+ carry 1], luma(248))
  cell(12.4, 1.8, 4.6, [100, carry 0], luma(225))
  cdraw.content((3.1, 5.8), [limb 0], size: 6pt, fill: luma(100))
  cdraw.content((8.9, 5.8), [limb 1], size: 6pt, fill: luma(100))
  cdraw.content((14.7, 5.8), [limb 2, sign +1], size: 6pt, fill: luma(100))
  cdraw.line((5.4, 2.3), (6.6, 2.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.2, 2.3), (12.4, 2.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, 0.6), [print: 100 then 000000000 000000000], size: 6.5pt, fill: luma(100), anchor: "west")
})

The three limbs print back as the pinned `100000000000000000000`,
and the listings below carry the representation, the add, and the
parse that produce it.

#listing("icpc/samples-c/src/Ch02/bigint.h", first: 11, last: 30, caption: [c: the bigint struct, sign-magnitude over 12 base-1e9 limbs, and the trim that keeps zero positive])

Comparison is magnitude-first, limb count then limb values from the
top, and the signed wrapper only flips the sense when both signs are
negative. Addition of same signs is the magnitude add with the shared
sign, opposite signs route through the magnitude subtract with the
larger operand's sign, and subtraction is addition of a negated copy.
The carry past the twelfth limb is dropped on the floor, documented,
and the tests stay inside the buffer. Multiply is schoolbook, limb
times limb accumulated into a `unsigned long long` column array, then
one carry pass. A limb product is at most the square of 999999999, just
under a quintillion, and the accumulator survives several of those
plus a carry inside 64 bits, which is exactly why the base is a
billion and not a trillion.

#listing("icpc/samples-c/src/Ch02/bigint.h", first: 136, last: 154, caption: [c: schoolbook multiply into a 64-bit column accumulator, one carry pass at the end])

Parsing cuts the decimal string into limbs of nine digits from the
right, so `12345678901234567890123` parses to three limbs, 12345,
678901234, 567890123 from most to least significant, and the test pins
that exact layout. Printing is the reverse: the top limb bare, every
limb below it nine digits wide with `%09u`, so the zero padding is
what makes the concatenation a correct decimal. The pins are the
language-neutral anchors of this toolbox: `123456789 * 987654321`
lands at `121932631112635269`, crossing out of one limb, and `10^21`
divided by 7 leaves quotient `142857142857142857142` and remainder 6.

#listing("icpc/samples-c/src/Ch02/bigint_io.h", first: 9, last: 53, caption: [c: parse by cutting limbs of nine from the right, print with the nine-digit zero pad])

#diagram([the 23-digit fixture as three limbs, least significant first, and the nine-digit print width that reassembles it], length: 12pt, {
  let limb(x, t, hi) = {
    cdraw.rect((x, 1.0), (x + 5.6, 2.2), fill: if hi {luma(225)} else {luma(240)}, radius: 0.02)
    cdraw.content((x + 2.8, 1.6), t, size: 6.5pt)
  }
  limb(0.6, [567890123], false)
  limb(6.8, [678901234], false)
  limb(13.0, [12345], true)
  cdraw.content((3.4, 0.3), [limb 0], size: 6pt, fill: luma(100))
  cdraw.content((9.6, 0.3), [limb 1], size: 6pt, fill: luma(100))
  cdraw.content((15.8, 0.3), [limb 2, sign +1], size: 6pt, fill: luma(100))
  cdraw.content((9.6, 4.6), [12345678901234567890123], size: 6.5pt)
  cdraw.content((0.6, 3.7), [parse: nine digits at a time from the right], size: 6pt, fill: luma(100), anchor: "west")
  cdraw.content((0.6, 2.9), [print: %09u per limb], size: 6pt, fill: luma(100), anchor: "west")
})

Measured against the Lua twin: the arithmetic core plus io is 171 + 55
lines here against one 221-line Lua module that also embeds its tests,
36 internal checks against 7 Lua test blocks, and the same anchors,
the 121932631112635269 product and the remainder-6 division, hold in
both languages. Lua's version keeps limbs in a plain table and leans
on the fact that a billion-base limb product stays under the 62-bit
wrap line, which is true on Lua's 64-bit integers and would be false
with a trillion base.

== the string map

The map is open addressing, strings to `long long`, with linear
probing over a power-of-two capacity. The hash is FNV-1a 64, offset
basis 14695981039346656037, prime 1099511628211, the constants from
the Fowler, Noll, Vo reference. Keys are copied into fixed 24-byte
cells with the bounded copy loop from the introduction, which is what
keeps the module free of the ucrt's deprecated calls. Deletion writes
a tombstone rather than an empty marker, because a probe walk that
stops at a hole would walk past a deleted slot and lose keys that
probed through it.

The dry run: the suite's opening block in `map_test.c` walks the
basic contract, three keys in, every get back, an overwrite that
leaves `used` pinned at 3.

+ A fresh 16-slot map takes `alpha` 1, `beta` 2, `gamma` 3:
  `used` = 3, `tombs` = 0.
+ The gets return with the values 1, 2, and 3, and `delta`, never
  inserted, misses with `map_get` returning 0.
+ `map_put("alpha", 10)` walks the probe to the live key and
  overwrites in place: the next get returns 10 and `used` still
  reads 3, the asserted balance.
+ The load check reads live plus tombstones, 3 + 0 = 3, against
  12, three quarters of the 16 slots, so no rehash fires anywhere
  in the block.

#table(
  columns: (auto, auto, auto, 1.4fr),
  inset: 4pt,
  table.header([*op*], [*used*], [*tombs*], [*the assert reads*]),
  [3 puts], [3], [0], [gets return 1, 2, 3],
  [get delta], [3], [0], [miss, returns 0],
  [put alpha 10], [3], [0], [get returns 10, count unchanged],
  [load check], [3], [0], [3 + 0 against 12 of 16],
)

An overwrite never grows the table, the live count pinned at 3 on
both sides of it, and the listings below are the hash and the put
that keep it.

#listing("icpc/samples-c/src/Ch02/map.h", first: 26, last: 41, caption: [c: fnv-1a 64 and the bounded key copy, no deprecated byte helpers anywhere])

Insertion asks the probe walk for two things at once, the live key if
it exists or the first tombstone seen on the way, and reinsertion into
a tombstone consumes it: the test deletes `beta`, watches `used` fall
and `tombs` rise, reinserts `beta`, and asserts the tombstone count is
back to zero. The load check counts live entries plus tombstones
against three quarters of capacity, so a delete-heavy workload still
triggers the rehash, and growth doubles the capacity and rehashes only
the live entries, which clears the tombstones for free.

#listing("icpc/samples-c/src/Ch02/map.h", first: 86, last: 110, caption: [c: put with the overwrite balance, tombstone reuse, and the 75 percent growth trigger])

The growth fixture is 200 keys with square values inserted from a
16-slot start: the capacity ends at 256 or more, four doublings, all
200 lookups return, `key42` holds exactly 1764, deleting the hundred
even keys leaves every odd value intact. Lua needs no map module at all,
its tables are the primitive, and that asymmetry is the honest
comparison: C spends 130 lines buying what Lua was born with.

#diagram([one probe walk serving both find and reinsert: the first tombstone is remembered, the walk only ends at a true empty], length: 12pt, {
  let cell(x, t, fill) = {
    cdraw.rect((x, 1.2), (x + 3.2, 2.6), fill: fill, radius: 0.02)
    cdraw.content((x + 1.6, 1.9), t, size: 6pt)
  }
  cell(0.6, [hash i], luma(238))
  cell(4.2, [tomb], luma(210))
  cell(7.8, [key m], luma(238))
  cell(11.4, [empty], luma(252))
  cdraw.content((5.8, 3.6), [tombstone stashed], size: 6pt, fill: luma(100))
  cdraw.line((5.8, 3.3), (5.8, 2.6), stroke: luma(100))
  cdraw.content((13.0, 3.6), [ends at empty], size: 6pt, fill: luma(100))
  cdraw.line((13.0, 3.3), (13.0, 2.6), stroke: luma(100))
  cdraw.content((6.6, 0.4), [the answer is the tombstone if the key is absent], size: 6.5pt, fill: luma(100))
})

== the min heap

The heap is an array of key and value pairs ordered by the
`unsigned long long` key, doubling its allocation when full. Push
sifts up while the parent's key is larger, pop moves the last element
to the root and sifts down into the smaller child. Values travel with
keys, so a year chapter can push distances with node ids attached and
get both back in order. Nothing here is stable by contract, but equal
keys come out in insertion order on the fixtures because the sift
compares strictly, and the test says so out loud for the two 9s that
precede the 10.

The dry run: the suite's first block in `heap_test.c` pushes 5, 1,
3, then 2 and 4, and asserts every pop plus the peeks between.

+ Pushing 5 leaves `[5]`; pushing 1 appends then sifts once, the 5
  and 1 swap, `[1, 5]`; pushing 3 finds its parent 1 already smaller,
  `[1, 5, 3]`, and the asserts read size 3, peek key 1.
+ Pushing 2 sifts past the 5 to `[1, 2, 3, 5]`; pushing 4 finds its
  parent 2 smaller and stays appended, `[1, 2, 3, 5, 4]`.
+ The first pop returns 1: the last element 4 takes the root, the
  smaller child 2 swaps up, and 4 settles over the 5, `[2, 4, 3, 5]`.
+ The second pop returns 2: the 5 takes the root, swaps once with
  the smaller child 3, and rests beside the 4, `[3, 4, 5]`, and the
  peek assert reads 3.
+ Pops return 3 leaving `[4, 5]`, then 4 leaving `[5]`, then 5, and
  `heap_empty` reads true.

#diagram([the array after each operation, root shaded, the pops draining it in the asserted order], length: 12pt, {
  let state(x, y, vals) = {
    for (i, v) in vals.enumerate() {
      cdraw.rect((x + i * 1.3, y), (x + i * 1.3 + 1.2, y + 1.0), fill: if i == 0 { luma(225) } else { luma(240) }, radius: 0.02)
      cdraw.content((x + i * 1.3 + 0.6, y + 0.5), v, size: 6.5pt)
    }
  }
  state(0.8, 4.4, ([1], [5], [3]))
  state(5.6, 4.4, ([1], [2], [3], [5]))
  state(11.6, 4.4, ([1], [2], [3], [5], [4]))
  cdraw.content((2.7, 5.8), [pushes 5, 1, 3], size: 6pt, fill: luma(100))
  cdraw.content((8.2, 5.8), [push 2], size: 6pt, fill: luma(100))
  cdraw.content((14.8, 5.8), [push 4], size: 6pt, fill: luma(100))
  state(0.8, 2.2, ([2], [4], [3], [5]))
  state(7.0, 2.2, ([3], [4], [5]))
  state(11.8, 2.2, ([4], [5]))
  state(15.2, 2.2, ([5],))
  cdraw.content((2.7, 0.8), [pop 1], size: 6pt, fill: luma(100))
  cdraw.content((8.9, 0.8), [pop 2, peek 3], size: 6pt, fill: luma(100))
  cdraw.content((12.4, 0.8), [pop 3], size: 6pt, fill: luma(100))
  cdraw.content((15.8, 0.8), [pop 4, then 5], size: 6pt, fill: luma(100))
})

The five pops land 1, 2, 3, 4, 5 exactly as asserted, and the
listing below is the sift pair that produces them.

#listing("icpc/samples-c/src/Ch02/heap.h", first: 39, last: 75, caption: [c: sift up on push, smaller-child sift down on pop, one struct per element])

The fixture suite is 27 checks: shuffled pushes popped ascending,
values tracked through both operations, duplicates, interleaved push
and pop holding the minimum on top, a heapsort pass over `4 9 1 7 3 8
6 5 2` that pops `1` through `9` with each value ten times its key,
and a growth run to 40 entries from capacity 8. The Go twin makes the
same structure generic with `Heap[T]`, and the Lua twin takes a
comparator so one heap serves min and max order, 91 lines against
this 77-line header, and all three pop the same fixtures in order.

#diagram([one pop, drawn on the heapsort fixture: the last element takes the root and sifts down three times], length: 12pt, {
  let node(x, y, t, hot) = {
    cdraw.rect((x - 0.55, y - 0.4), (x + 0.55, y + 0.4), fill: if hot {luma(210)} else {luma(240)}, radius: 0.02)
    cdraw.content((x, y), t, size: 6.5pt)
  }
  node(9.0, 6.0, [1], false)
  node(6.2, 4.4, [3], false)
  node(11.8, 4.4, [2], false)
  node(4.8, 2.8, [7], false)
  node(7.6, 2.8, [4], true)
  node(10.4, 2.8, [5], false)
  node(13.2, 2.8, [6], false)
  cdraw.line((9.0, 5.6), (6.2, 4.8), stroke: luma(140))
  cdraw.line((9.0, 5.6), (11.8, 4.8), stroke: luma(140))
  cdraw.line((6.2, 4.0), (4.8, 3.2), stroke: luma(140))
  cdraw.line((6.2, 4.0), (7.6, 3.2), stroke: luma(140))
  cdraw.line((11.8, 4.0), (10.4, 3.2), stroke: luma(140))
  cdraw.line((11.8, 4.0), (13.2, 3.2), stroke: luma(140))
  cdraw.content((16.2, 6.0), [pop takes the 1], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((16.2, 5.0), [the 4 rises to the root], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((16.2, 4.0), [and sifts down to its place], size: 6.5pt, fill: luma(100), anchor: "west")
})

== the ring deque

The deque is a ring buffer of `long long` with a head index and a
count: the back writes at `(head + count) % cap`, the front walks the
head backward, and both pops refuse on empty by returning 0 with an
out parameter, no exceptions in C, so refusal is a return value and
the test asserts it on both ends. Growth doubles the capacity and
rebases: the new buffer is written from logical index zero, so a deque
wrapped across the seam lands contiguous again with head at slot 0.

The dry run: the suite's wrap fixture in `deque_test.c` pushes 1, 2,
3 to the back, then 9 and 8 to the front, and asserts the pops read
8, 9, 1.

+ Three back pushes land at slots 0, 1, and 2 of the cap 8 ring,
  head 0, count 3.
+ `deque_push_front(9)` walks the head to (0 + 8 - 1) % 8 = 7 and
  writes slot 7, count 4.
+ `deque_push_front(8)` walks again to (7 + 8 - 1) % 8 = 6 and
  writes slot 6, count 5.
+ The pops read slot 6 then slot 7, returning 8 then 9, the head
  arriving back at 0.
+ The third pop reads slot 0, the 1, the asserted order across the
  seam.

#diagram([the cap 8 ring after both front pushes: the head walked backward past slot 0, the pops read 8, 9, 1], length: 12pt, {
  let vals = ([1], [2], [3], [], [], [], [8], [9])
  for (i, v) in vals.enumerate() {
    cdraw.rect((0.8 + i * 1.7, 3.0), (2.4 + i * 1.7, 4.2), fill: if v == [] { luma(250) } else if i >= 6 { luma(225) } else { luma(238) }, radius: 0.02)
    if v != [] { cdraw.content((1.6 + i * 1.7, 3.6), v, size: 6.5pt) }
    cdraw.content((1.6 + i * 1.7, 4.7), [#i], size: 6pt, fill: luma(100))
  }
  cdraw.content((1.6 + 6 * 1.7, 2.2), [head 6], size: 6pt, fill: luma(100))
  cdraw.line((1.6 + 6 * 1.7, 2.5), (1.6 + 6 * 1.7, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((0.4, 5.3), (0.4, 6.2), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((0.4, 6.2), (14.4, 6.2), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((14.4, 6.2), (14.4, 5.3), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((14.4, 5.3), (14.4, 4.4), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
  cdraw.content((7.4, 6.6), [the head walked 0 to 7 to 6, modulo both times], size: 6.5pt, fill: luma(100))
  cdraw.content((0.8, 1.2), [logical order: 8 9 1 2 3], size: 6.5pt, fill: luma(100), anchor: "west")
})

The pops cross the seam in the asserted order, 8, 9, 1, and the
listing below is the modulo pair that writes them.

#listing("icpc/samples-c/src/Ch02/deque.h", first: 27, last: 51, caption: [c: doubling growth rebases the ring to slot 0, both pushes wrap by modulo])

The growth fixture starts at capacity 2 and interleaves 50 pushes at
each end, and the drain asserts the whole logical order in one pass,
`-50` through `-1` then `1` through `50`, 100 elements that crossed
six doublings with their order intact. A full rotation, pop front and
push back six times over six elements, restores the original order,
which is the property the rotate-heavy puzzles lean on. The C\#
toolbox's `Ring.cs` grows the same way and the Lua twin carries a
`copies` counter the test reads directly, 4 copies when a 4-ring
doubles, and that counter is the honest little instrument this header
leaves implicit.

#diagram([a wrapped ring before and after growth: the logical order survives, the head rebases to slot 0], length: 12pt, {
  let slot(x, t, fill) = {
    cdraw.rect((x, 3.2), (x + 1.7, 4.4), fill: fill, radius: 0.02)
    cdraw.content((x + 0.85, 3.8), t, size: 6.5pt)
  }
  cdraw.content((6.0, 5.2), [cap 4, head at 3], size: 6.5pt, fill: luma(100))
  slot(0.6, [4], luma(238))
  slot(2.3, [2], luma(238))
  slot(4.0, [3], luma(238))
  slot(5.7, [1], luma(210))
  cdraw.line((6.4, 4.9), (5.7, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.4, 2.2), [logical: 1 2 3 4], size: 6.5pt)
  let s2(x, t, fill) = {
    cdraw.rect((x, 0.2), (x + 1.7, 1.4), fill: fill, radius: 0.02)
    cdraw.content((x + 0.85, 0.8), t, size: 6.5pt)
  }
  s2(10.6, [1], luma(210))
  s2(12.3, [2], luma(238))
  s2(14.0, [3], luma(238))
  s2(15.7, [4], luma(238))
  s2(17.4, [], luma(252))
  s2(19.1, [], luma(252))
  cdraw.content((14.8, 2.2), [after grow: head 0, cap 8], size: 6.5pt, fill: luma(100))
  cdraw.line((9.6, 2.2), (10.6, 1.4), stroke: luma(100), mark: (end: ">"))
})

== the vector and the sort idiom

The vector is the dynamic array of the series, `long long` elements,
capacity doubling through `reserve`, an insert that shifts the tail
right, and a pop that refuses on empty. The capacity pins in the test
are the amortized argument made concrete: 4 through the first four
pushes, 8 at the fifth, 16 at the ninth, and a `reserve(100)` that
jumps past several doublings in one realloc.

The dry run: the suite's insert block in `vec_test.c` walks the
capacity pins into the tail shift, then the sort fixture reloads
`5 3 9 1 7 2 8 6`.

+ Four pushes 1 through 4 sit inside capacity 4; the fifth doubles
  to 8 and pushes 9 through 12 double again to 16, both asserted;
  the pop returns 12, leaving the eight elements `1 2 3 4 5 9 10
  11`.
+ `vec_insert(&v, 2, 99)` shifts the six-element tail right one
  slot and lands 99 at index 2: size 8 + 1 = 9, and the asserts
  read `vec_get(2)` = 99 with `vec_get(3)` = 3, the old element's
  new home.
+ Two pops return 11 then 10.
+ The sort fixture pushes `5 3 9 1 7 2 8 6`; `qsort` over the
  exposed buffer with `cmp_ll` lands `1 2 3 5 6 7 8 9`, all eight
  positions asserted.
+ The negated comparator sorts the same buffer the other way, and
  `vec_reserve(&v, 100)` jumps capacity past 100 with size still 8.

#diagram([the insert at index 2: the six-element tail slides one slot right, 99 lands at the gap], length: 12pt, {
  let cell(x, y, t, fill) = {
    cdraw.rect((x, y), (x + 1.6, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + 0.8, y + 0.5), t, size: 6pt)
  }
  let vals = ([1], [2], [3], [4], [5], [9], [10], [11])
  for (i, v) in vals.enumerate() {
    cell(0.8 + i * 1.8, 4.2, v, if i >= 2 { luma(228) } else { luma(240) })
    cdraw.content((1.6 + i * 1.8, 5.6), [#i], size: 6pt, fill: luma(100))
  }
  cdraw.content((0.8, 6.2), [insert 99 at 2, the tail shifts right], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.line((1.6, 4.7), (1.6, 3.0), stroke: luma(100), mark: (end: ">"))
  let after = ([1], [2], [99], [3], [4], [5], [9], [10], [11])
  for (i, v) in after.enumerate() {
    cell(0.8 + i * 1.8, 1.6, v, if i == 2 { luma(210) } else if i >= 3 { luma(228) } else { luma(240) })
  }
  cdraw.content((0.8, 0.4), [size 9, the shifted tail keeps its order], size: 6.5pt, fill: luma(100), anchor: "west")
})

The shifted tail and the sorted buffer are the two idioms the
listing below exposes `buf` for, and the sorted read `1 2 3 5 6 7
8 9` is the pinned one.

#listing("icpc/samples-c/src/Ch02/vec.h", first: 28, last: 64, caption: [c: doubling reserve, refusing pop, and the tail-shifting insert])

The reason a raw buffer earns its place next to the structured
containers is `qsort`. The vec exposes `buf`, `size`, and the element
width, which is the whole interface `qsort` wants, and the comparator
idiom, subtract-free `(x > y) - (x < y)` so no overflow ever enters
the comparison, sorts the same buffer ascending through `cmp_ll` and
descending through its negation. The fixture `5 3 9 1 7 2 8 6`, eight
values with 4 skipped on purpose so an off-by-one cannot hide, sorts
to `1 2 3 5 6 7 8 9` both ways.

#diagram([size against capacity across the pinned pushes, the doubling staircase under every append], length: 12pt, {
  let bar(x, w, sz, fill) = {
    cdraw.rect((x, 1.0), (x + w, 1.0 + sz * 0.4), fill: fill, radius: 0.02)
  }
  bar(1.0, 1.0, 1, luma(220))
  bar(2.2, 1.0, 2, luma(220))
  bar(3.4, 1.0, 3, luma(220))
  bar(4.6, 1.0, 4, luma(220))
  bar(5.8, 2.1, 5, luma(205))
  bar(8.1, 1.0, 6, luma(220))
  bar(9.3, 1.0, 7, luma(220))
  bar(10.5, 1.0, 8, luma(220))
  bar(11.7, 1.0, 9, luma(205))
  bar(12.9, 4.2, 9, luma(240))
  cdraw.content((3.3, 5.6), [cap 4], size: 6.5pt, fill: luma(100))
  cdraw.content((8.7, 5.6), [cap 8], size: 6.5pt, fill: luma(100))
  cdraw.content((13.9, 5.6), [cap 16], size: 6.5pt, fill: luma(100))
  cdraw.content((15.0, 2.4), [reserve], size: 6pt, fill: luma(100))
  cdraw.content((9.0, 0.3), [pale bars: the capacity jumps at pushes 5 and 9], size: 6.5pt, fill: luma(100))
})

== grid index math

The grid module is the smallest header and the one every year chapter
touches first. A grid is a row-major buffer plus `rows` and `cols`,
the index law is `r * cols + c`, and the module supplies the inverse,
row and column from a flat index, the bounds predicate, and the two
delta tables, the 4-neighbor cross and the 8-neighbor square. There is
no allocation and no struct: the functions are pure index arithmetic,
which is why they can be `static inline` without a thought.

The dry run: the 5 by 7 fixture in `grid_test.c` pins the law and
its inverse on index 34, then the neighbor counts at an interior
cell, an edge, and a corner.

+ The far corner: `grid_idx(4, 6, 7)` computes 4 x 7 + 6 = 34,
  asserted.
+ The inverse splits it: 34 \/ 7 = 4 with 4 x 7 = 28, then
  34 - 28 = 6, row 4 column 6, both asserted.
+ Index 13 decodes the same way, 13 = 1 x 7 + 6, row 1 column 6,
  and the sweep round-trips all 5 x 7 = 35 cells.
+ The interior cell (2, 3) keeps every axis step in bounds, count
  4, and all eight with diagonals, count 8, the two asserted
  together.
+ The top edge (0, 3) loses the up step and the two up-diagonals,
  4 - 1 = 3 and 8 - 3 = 5, and the corner (0, 0) keeps 2 and 3, all
  six counts asserted.

#diagram([the 35 flat indices of the 5 by 7 fixture in five rows, the far corner shaded, the law and its inverse meeting there], length: 12pt, {
  for r in range(5) {
    for c in range(7) {
      let i = r * 7 + c
      cdraw.rect((0.8 + c * 1.15, 4.6 - r * 0.85), (1.85 + c * 1.15, 5.4 - r * 0.85), fill: if i == 34 { luma(210) } else { luma(240) }, radius: 0.02)
      cdraw.content((1.325 + c * 1.15, 5.0 - r * 0.85), [#i], size: 6pt)
    }
  }
  cdraw.content((9.4, 4.6), [idx = r x cols + c = 4 x 7 + 6 = 34], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((9.4, 3.6), [row = 34 \/ 7 = 4], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((9.4, 2.6), [col = 34 - 4 x 7 = 6], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((9.4, 1.6), [all 35 cells round-trip], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.line((9.0, 1.8), (7.9, 2.3), stroke: luma(100), mark: (end: ">"))
})

Every index decodes back to its cell, 34 the far corner both ways,
and the listing below is the law and its inverse.

#listing("icpc/samples-c/src/Ch02/grid.h", first: 6, last: 38, caption: [c: the delta tables, the index law and its inverse, and in-bounds neighbor counting])

The fixture grid is 5 by 7: index 34 decodes to row 4 column 6, every
cell's index round-trips, and the neighbor counts land where geometry
says, 4 and 8 at the interior, 3 and 5 at an edge, 2 and 3 at a
corner. The degree sums over a 5 by 5 grid are the quiet correctness
check: 80 directed 4-edges and 144 with diagonals, both derivable by
counting shared edges and half-diagonals by hand. The Lua twin returns
the in-bounds neighbor coordinates themselves rather than counting
them, coordinates a puzzle wants more often than a count, and its
tables live as plain Lua arrays.

#diagram([the 4- and 8-neighbor deltas around an edge cell, and what the edge removes], length: 12pt, {
  let cell(x, y, t, fill) = {
    cdraw.rect((x, y), (x + 1.5, y + 1.5), fill: fill, radius: 0.02)
    cdraw.content((x + 0.75, y + 0.75), t, size: 6.5pt)
  }
  for c in range(5) {
    for r in range(3) {
      cell(0.8 + c * 1.7, 3.6 - r * 1.7, [], luma(244))
    }
  }
  // edge cell at row 0, col 2: neighbors marked
  cell(0.8 + 2 * 1.7, 3.6, [], luma(215))
  cell(0.8 + 1 * 1.7, 3.6, [4], luma(228))
  cell(0.8 + 3 * 1.7, 3.6, [4], luma(228))
  cell(0.8 + 2 * 1.7, 3.6 - 1.7, [4], luma(228))
  cell(0.8 + 1 * 1.7, 3.6 - 1.7, [8], luma(236))
  cell(0.8 + 3 * 1.7, 3.6 - 1.7, [8], luma(236))
  cdraw.content((9.8, 4.2), [the shaded cell is on an edge], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((9.8, 3.3), [4-set: three survive], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((9.8, 2.4), [8-set: five survive], size: 6.5pt, fill: luma(100), anchor: "west")
})

== reading input

Every contest problem starts as a file, so `io.h` reads a whole file into
one buffer and splits it into lines. The module's first act is the
opt-out from the introduction, `_CRT_SECURE_NO_WARNINGS` defined
before `stdio.h` is included, because the portable `fopen` is what the
module wants and the define has to precede the header that carries the
deprecation attribute. `io_read_file` returns the byte count or -1
when the file cannot be opened, and the buffer is nul-terminated and
caller-freed.

The dry run: the suite in `io_test.c` writes the 31-byte fixture and
asserts the byte count, the five split lines, and the two edge
files.

+ The fixture counts 31 bytes: `alpha` 5, newline 1, `beta` 4,
  newline 1, the empty line's newline 1, `gamma delta` 11, newline
  1, `epsilon` 7, and 5 + 1 + 4 + 1 + 1 + 11 + 1 + 7 = 31, the
  asserted `len`.
+ The read nul-terminates past the bytes, so `buf[31]` reads 0,
  and the corner asserts read `buf[0]` as the `a` and `buf[30]` as
  the final `n`.
+ The splitter walks the four newlines at byte indexes 5, 10, 11,
  and 23, terminates each line in place, and stores five pointers,
  the asserted count.
+ `lines[2]` is the empty string between the newlines at 10 and 11,
  the kept blank, and `lines[4]` points at byte 24, the
  `epsilon` tail no newline terminates, still counted.
+ The missing path returns -1, the crlf rewrite splits 2 lines with
  the carriage returns stripped, and the empty file reads 0 bytes
  and 0 lines.

#diagram([the 31 bytes as a ruler: four newlines at 5, 10, 11, 23 cut five lines, the tail counts without one], length: 12pt, {
  let segs = ((5, [alpha], false), (1, [`\n`], true), (4, [beta], false), (1, [`\n`], true), (1, [`\n`], true), (11, [gamma delta], false), (1, [`\n`], true), (7, [epsilon], false))
  let cx = 0.6
  for s in segs {
    let w = s.at(0) * 0.55
    cdraw.rect((cx, 3.0), (cx + w, 4.1), fill: if s.at(2) { luma(210) } else { luma(240) }, radius: 0.02)
    if s.at(0) >= 4 { cdraw.content((cx + w / 2, 3.55), s.at(1), size: 6pt) }
    cx += w
  }
  let marks = (0, 5, 6, 10, 11, 12, 23, 24, 31)
  let px = i => 0.6 + i * 0.55
  for i in marks {
    let low = i == 6 or i == 11
    cdraw.line((px(i), 2.7), (px(i), 3.0), stroke: luma(140))
    cdraw.content((px(i), if low { 1.2 } else { 2.2 }), [#i], size: 6pt, fill: luma(100))
  }
  let starts = ((0, [line 0]), (6, [line 1]), (11, [line 2, empty]), (12, [line 3]), (24, [line 4, no newline]))
  for (i, t) in starts {
    cdraw.line((px(i), 4.1), (px(i), 4.6), stroke: luma(140))
    if i == 11 or i == 24 { cdraw.content((px(i), 5.0), t, size: 6pt, fill: luma(100)) }
  }
  cdraw.content((0.6, -0.1), [nul terminator at byte 31, past the text], size: 6.5pt, fill: luma(100), anchor: "west")
})

The read returns the pinned 31 and the split the pinned five lines,
and the listings below are the read and the walk.

#listing("icpc/samples-c/src/Ch02/io.h", first: 9, last: 31, caption: [c: the ucrt opt-out first, then the whole-file read with byte count])

The splitter walks for newlines and strips a trailing carriage return
per line, so crlf text from a windows editor is handled where it
should be, at the boundary. The fixture is 31 bytes,
`alpha`, `beta`, an empty line, `gamma delta`, and an unterminated
`epsilon`: five lines, the empty one kept, the tail counted. An empty
file is zero bytes and zero lines, and a final line without a newline
still counts, the two edge cases a puzzle input will eventually
exercise. The Go twin's `ReadLines` keeps trailing blanks, a
documented divergence between the twins, and the year chapters cite
whichever behavior their language's toolbox pins.

#listing("icpc/samples-c/src/Ch02/io.h", first: 35, last: 53, caption: [c: the newline walk, crlf strip, and the unterminated tail that still counts])

#diagram([the 31-byte fixture to five lines: splits at newlines, the blank survives, the tail counts without one], length: 12pt, {
  cdraw.rect((0.6, 4.2), (18.6, 5.6), fill: luma(242), radius: 0.02)
  cdraw.content((9.6, 4.9), [`alpha\nbeta\n\ngamma delta\nepsilon`], size: 6.5pt)
  let ys = (3.2, 2.35, 1.5, 0.65, -0.2)
  for (i, t) in ([alpha], [beta], [], [gamma delta], [epsilon]).enumerate() {
    let y = ys.at(i)
    cdraw.rect((0.6, y - 0.31), (6.2, y + 0.31), fill: luma(228), radius: 0.02)
    cdraw.content((3.4, y), t, size: 6pt)
  }
  cdraw.line((3.4, 4.2), (3.4, 3.51), stroke: luma(160))
  cdraw.content((7.4, 1.5), [line 3 is empty, kept], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((7.4, -0.2), [line 5 lacks a newline], size: 6.5pt, fill: luma(100), anchor: "west")
})

== number theory with an honest product

This is the module with the story. Modular exponentiation over 64-bit
values needs a multiplication whose product can exceed 64 bits, and C
offers `__uint128_t` for exactly that. On this toolchain the obvious
implementation compiles, clang 23 accepts the type and the arithmetic,
and then the link fails: `undefined symbol __umodti3`, the
compiler-rt helper that implements a 128-bit remainder, absent from
the MSVC plus lld link this machine performs. The chapter 16 probe of
the data structures book recorded the same failure through the real
gate, and the conclusion is binding here: the toolbox computes
products by add-and-double, doubling one operand and reducing modulo
`m` every step, so no intermediate ever exceeds two 64-bit values
added.

The dry run: `num_test.c` pins the euclid chain on 48 and 18, the
bezout identity for 240 and 46, and the classic three-congruence
fold.

+ `num_gcd(48, 18)` substitutes: 48 = 2 x 18 + 12, then 18 = 1 x
  12 + 6, then 12 = 2 x 6 + 0, gcd 6, asserted.
+ The lcm pins: 4 x 6 = 24 over gcd 2 leaves 12, and 21 x 6 = 126
  over gcd 3 leaves 42, both asserted.
+ `num_ext_gcd(240, 46, &x, &y)` returns gcd 2 with x = -9 and
  y = 47, and the asserted identity reads 240 x (-9) = -2160, 46 x
  47 = 2162, -2160 + 2162 = 2.
+ The crt fold: 2 mod 3 with 3 mod 5 combines to 8 mod 15, then 8 +
  15 = 23 at modulus 15 x 7 = 105, the asserted pair.
+ The non-coprime pair 1 mod 6 with 3 mod 10 resolves to 13 mod 30,
  asserted, and the contradiction is rejected by the gcd test with
  return 0.

#table(
  columns: (auto, 1.7fr, auto),
  inset: 4pt,
  table.header([*step*], [*line*], [*value*]),
  [euclid], [48 = 2 x 18 + 12], [12],
  [euclid], [18 = 1 x 12 + 6], [6],
  [euclid], [12 = 2 x 6 + 0], [gcd 6],
  [bezout], [240 x (-9) + 46 x 47], [-2160 + 2162 = 2],
  [crt], [(2, 3) then (3, 5)], [8 mod 15],
  [crt], [8 + 15, modulus 15 x 7], [23 mod 105],
  [crt], [1 mod 6 with 3 mod 10], [13 mod 30],
)

Both anchors hold, 2 as the bezout identity and 23 mod 105 as the
fold, and the listings below are the machinery that computes them.

#listing("icpc/samples-c/src/Ch02/num.h", first: 25, last: 51, caption: [c: the add-and-double mulmod and the modpow built on it, a reduction every step])

The test pins the machinery three ways. The identity case,
`mulmod(6000000000, 6000000000, 1000000007)`, is 1764, because a
billion is congruent to -7 modulo a billion and seven, so the product
is 36 times 49. The exponentiation anchor is `2^100 mod 1000000007` at
976371285, the value every language in this book agrees on. And the
chinese remainder theorem fixture is the classic, 2 mod 3, 3 mod 5,
2 mod 7 combining through 8 mod 15 to 23 mod 105, with the consistent
non-coprime pair, 1 mod 6 with 3 mod 10, resolving to 13 mod 30 and
the inconsistent pair rejected by the gcd test.

#listing("icpc/samples-c/src/Ch02/num.h", first: 87, last: 102, caption: [c: pairwise crt, the consistency check against gcd, and the scan to the combined residue])

The Lua twin arrives at the same add-and-double design from the
opposite direction. C never reaches a wraparound, the 128-bit product
simply fails to link, while Lua's integers wrap silently in hardware,
and #xref-to("icpc", "toolbox-lua") pins the proof in a test,
`math.maxinteger * 2 == -2`, before building the identical doubling
loop. One language cannot link the wide product, the other cannot
trust it, and the fix is the same seven lines in both.

#diagram([one mulmod as the add-and-double ladder: halve b, double a, add when the bit is set, reduce every step], length: 12pt, {
  let row(y, b, a, r) = {
    cdraw.content((2.4, y), [b = #b], size: 6.5pt, anchor: "east")
    cdraw.content((3.2, y), [a = #a], size: 6.5pt, anchor: "west")
    cdraw.content((11.0, y), [#r], size: 6.5pt, anchor: "west")
  }
  row(6.0, [13], [a], [bit set, r = a])
  row(4.8, [6], [2a mod m], [bit clear, r stays a])
  row(3.6, [3], [4a mod m], [bit set, r = 5a mod m])
  row(2.4, [1], [8a mod m], [bit set, r = 13a mod m])
  cdraw.content((3.2, 7.2), [halve b, double a, reduce every step], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((3.2, 1.2), [13a mod m, without one wide product], size: 6.5pt, fill: luma(100), anchor: "west")
})

== md5 from the RFC

Some days want a real hash, and the finals' favorite is md5, so the
toolbox builds it from RFC 1321 rather than linking a crypto library:
the little-endian Merkle-Damgard construction over 512-bit blocks,
sixteen words a block, 64 rounds in four nonlinear passes. The
padding is the standard, one `0x80` byte, zeros to 56 mod 64, then the
bit length in eight little-endian bytes, and each block is read as
sixteen 32-bit little-endian words.

The dry run: the suite's 80-digit vector in `md5_test.c` is the
two-block case, and the walk is its padding arithmetic.

+ The input is 80 decimal digits, asserted by `strlen`, so the bit
  length is 80 x 8 = 640.
+ The `0x80` pad byte takes the message to 80 + 1 = 81 bytes, 81 -
  64 = 17 bytes into the second block.
+ Zeros follow to 56 mod 64: 56 - 17 = 39 zeros, 17 + 39 = 56.
+ The bit length lands in eight little-endian bytes, 640 as `80 02`
  then six zero bytes, and 56 + 8 = 64 closes the second block,
  128 bytes total.
+ Two blocks fold through the 64 rounds each and the digest prints
  `57edf4a22be3c955ac49da2e2107b67a`, the pinned vector.

#diagram([the 80-digit input pads into two blocks: 64 message bytes fill the first, the second carries 16 message bytes, the pad, 39 zeros, and the length], length: 12pt, {
  let box(x, y, w, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  cdraw.content((9.0, 6.2), [block 1], size: 6.5pt, fill: luma(100))
  box(0.6, 4.8, 16.8, [64 message bytes])
  cdraw.content((9.0, 3.8), [block 2], size: 6.5pt, fill: luma(100))
  box(0.6, 2.4, 4.2, [16 message])
  box(5.2, 2.4, 2.1, [0x80], fill: luma(224))
  box(7.7, 2.4, 6.3, [39 zeros])
  box(14.4, 2.4, 3.0, [len 8 B], fill: luma(224))
  cdraw.content((0.6, 1.0), [bit length 640 = 80 x 8, little-endian 80 02 then zeros], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.6, 0.1), [56 + 8 = 64, the second block closes at 128 total], size: 6.5pt, fill: luma(100), anchor: "west")
})

The second block closes at 128 bytes and the digest lands on the
pinned `57edf4a22be3c955ac49da2e2107b67a`, the listings below.

#listing("icpc/samples-c/src/Ch02/md5.h", first: 39, last: 56, caption: [c: pad to 56 mod 64, length little-endian, load sixteen words per block])

The rounds are the four boolean functions of the RFC with their
message schedules, indices `i`, `5i+1`, `3i+5`, `7i` modulo 16, and
the left-rotation schedule, the dance of `a`, `b`, `c`, `d` that ends
by adding the working registers into the chaining state. The sine
table and shift table are the RFC's own constants.

#listing("icpc/samples-c/src/Ch02/md5.h", first: 57, last: 83, caption: [c: the 64 rounds, four passes with their word schedules, folded into the state])

The test suite is the RFC 1321 vector set: the empty string
`d41d8cd98f00b204e9800998ecf8427e`, `a`, `abc`, `message digest`, the
alphabet, and the 80-digit input that crosses the 64-byte block
boundary and forces the two-block padding path,
`57edf4a22be3c955ac49da2e2107b67a`. Determinism is asserted directly, same input twice,
and avalanche by one changed letter, `abcd` against `abce`, digests
differing. The Lua twin computes the same construction over 64-bit
integers masked to 32 bits after every operation, and all five of its
pinned vectors match this suite's, the same RFC read by two machines.

#diagram([merkle-damgard: pad once, then fold block after block into four chaining words], length: 12pt, {
  let box(x, y, w, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0.6, 4.6, 3.6, [message])
  cdraw.line((4.2, 5.1), (5.4, 5.1), stroke: luma(100), mark: (end: ">"))
  box(5.4, 4.6, 9.0, [pad: 0x80, then length])
  box(0.6, 2.6, 3.8, [block 1])
  box(5.2, 2.6, 3.8, [block 2])
  box(9.8, 2.6, 3.8, [block 3])
  cdraw.line((9.9, 4.6), (2.5, 3.6), stroke: luma(140))
  cdraw.line((9.9, 4.6), (7.1, 3.6), stroke: luma(140))
  cdraw.line((9.9, 4.6), (11.7, 3.6), stroke: luma(140))
  box(15.0, 2.6, 4.8, [h0 h1 h2 h3], fill: luma(225))
  cdraw.line((13.6, 3.1), (15.0, 3.1), stroke: luma(100), mark: (end: ">"))
  box(0.6, 0.4, 8.4, [64 rounds per block], fill: luma(245))
  cdraw.line((7.0, 2.6), (5.0, 1.4), stroke: luma(140))
  box(15.0, 0.4, 4.8, [the digest], fill: luma(245))
  cdraw.line((17.4, 2.6), (17.4, 1.4), stroke: luma(140))
})

== a json reader

The json module is a recursive-descent parser into a node tree from a
static pool, 128 nodes, 16 children per container, 64 bytes per
string, fixed bounds chosen for puzzle documents and stated in the
test rather than hidden behind allocation. Objects keep their member
names beside their children, arrays keep order, strings decode the
standard escapes, numbers go through `strtod`, and the three literals
become tags. The whole grammar hangs off one dispatch function.

The dry run: the crafted document `{"a": 1, "b": [2, 3.5, true,
null, "x"], "c": {"d": -4}}` is the suite's walk fixture, its
children asserted by index and its numeric leaves summed.

+ The parse returns a three-child object, `n_children` = 3 asserted,
  with the keys `a`, `b`, `c` in order.
+ The array under `b` holds five children asserted by index: the
  numbers 2 and 3.5, the true, the null, and the string `x`, order
  kept.
+ The nested object carries the `-4`, and the four numeric leaves
  fold through the sum walk: 1 + 2 = 3, 3 + 3.5 = 6.5, 6.5 - 4 =
  2.5, the pinned `json_sum_numbers`.
+ The escape fixture `{"k": "a\"b\\c\nd"}` decodes its three escape
  pairs to quote, backslash, newline, and the `strcmp` reads the
  seven-character result.
+ The scalars parse alone, `42` as a number, `true` as boolean 1,
  `null` as the tag, `"solo"` as the string.

#diagram([the escape decode: three pairs in the source become quote, backslash, and newline in the string, everything else passes through], length: 12pt, {
  let tok(x, y, t, hot) = {
    cdraw.rect((x, y), (x + 1.9, y + 0.9), fill: if hot { luma(224) } else { luma(240) }, radius: 0.02)
    cdraw.content((x + 0.95, y + 0.45), t, size: 6.5pt)
  }
  let src = ([a], [`\"`], [b], [`\\`], [c], [`\n`], [d])
  let dst = ([a], [`"`], [b], [`\`], [c], [newline], [d])
  for (i, t) in src.enumerate() {
    let hot = calc.rem(i, 2) == 1
    tok(0.8 + i * 2.2, 4.2, t, hot)
    tok(0.8 + i * 2.2, 1.8, dst.at(i), hot)
    if hot { cdraw.line((1.75 + i * 2.2, 4.2), (1.75 + i * 2.2, 2.7), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((0.8, 5.6), [the source characters], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.8, 0.6), [the decoded string, seven characters], size: 6.5pt, fill: luma(100), anchor: "west")
})

The leaves fold to the pinned 2.5 and the escapes decode in place,
and the listings below are the dispatch and the walks.

#listing("icpc/samples-c/src/Ch02/json.h", first: 169, last: 211, caption: [c: the value dispatch: containers recurse, literals match, numbers take strtod])

Parsing is all-or-nothing: a global `json_ok` flag drops on the first
malformed construct, and the entry point refuses trailing content, so
`{`, `[1, 2`, `tru`, and `1 2` all return a null pointer. The walk
helpers are where the puzzle value lives, a sum over every numeric
leaf and a count by tag, and the crafted fixture runs both: a document
holding `1`, an array of `2, 3.5, true, null, "x"`, and a nested `-4`
has four numbers summing to 2.5, one array, two objects, one boolean,
one null.

#listing("icpc/samples-c/src/Ch02/json.h", first: 225, last: 242, caption: [c: the numeric-leaf sum and the tag count, the walks the year chapters call])

The comparison with Lua is the sharpest in the book. C needs 244
lines, a node pool, and child arrays because it has no dynamic
structures of its own, and its null is a tag. Lua decodes the same
grammar straight into plain tables in 167 lines, its null is a
sentinel table so the value can sit in a field without vanishing into
nil, and its errors are raised by name, `expected ':'`, against this
module's silent null return. Both pin the same 2.5 walk and both
refuse the same malformed documents, each in its language's own
idiom, and #xref-to("icpc", "toolbox-lua") shows the other half of
the conversation.

#diagram([the crafted fixture as a node tree: numbers at the leaves, the walk sums 2.5], length: 12pt, {
  let node(x, y, t, fill: luma(238)) = {
    cdraw.rect((x - 1.75, y - 0.45), (x + 1.75, y + 0.45), fill: fill, radius: 0.02)
    cdraw.content((x, y), t, size: 6pt)
  }
  node(9.0, 6.2, [object], fill: luma(225))
  node(3.4, 4.4, [a: 1])
  node(9.0, 4.4, [b: array])
  node(14.6, 4.4, [c: object], fill: luma(225))
  node(2.0, 2.6, [2])
  node(5.6, 2.6, [3.5])
  node(9.2, 2.6, [true])
  node(12.8, 2.6, [null])
  node(16.4, 2.6, ["x"])
  node(19.0, 2.6, [d: -4])
  cdraw.line((9.0, 5.75), (3.4, 4.85), stroke: luma(140))
  cdraw.line((9.0, 5.75), (9.0, 4.85), stroke: luma(140))
  cdraw.line((9.0, 5.75), (14.6, 4.85), stroke: luma(140))
  for x in (2.0, 5.6, 9.2, 12.8, 16.4) {
    cdraw.line((9.0, 3.95), (x, 3.05), stroke: luma(140))
  }
  cdraw.line((14.6, 3.95), (19.0, 3.05), stroke: luma(140))
  cdraw.content((10.0, 1.2), [1 + 2 + 3.5 - 4 = 2.5], size: 6.5pt, fill: luma(100))
})

== across the six languages

This chapter owns C, and the honest close is the same table every
toolbox chapter closes with, the structure, how C builds it, how Lua
builds it, and why they differ. The other four languages carry their
own chapters, and their rows join the comparison there.

#table(
  columns: (1.2fr, 1.6fr, 1.6fr, 1.6fr),
  inset: 4pt,
  table.header([*structure*], [*c builds it as*], [*lua builds it as*], [*why they differ*]),
  [bigint], [sign-magnitude struct, 12 fixed limbs], [sign plus limb table, unbounded], [c pins the digit budget, lua lets tables grow],
  [map and set], [open addressing, fnv-1a, tombstones], [the table primitive itself], [c has no hash map, lua has nothing else],
  [min heap], [typed array of key-value pairs], [array plus injected comparator], [one c type order, any lua order],
  [deque], [ring with head index and count], [ring with head, count, copies], [the lua test reads the copy count directly],
  [grid], [pure index functions over a buffer], [parse to one string, index functions], [same law, lua keeps the cells as text],
  [input], [whole-file read, newline split], [line lists from the runner], [c owns its bytes, lua owns its strings],
  [modular num], [add-and-double, the link refused the wide product], [add-and-double, the wrap is proven], [different diseases, same cure],
  [md5], [uint32 arithmetic], [int64 masked to 32 bits], [lua has no 32-bit integers to use],
  [json], [node pool with tags], [plain tables, null sentinel], [c needs the tree, lua is the tree],
)

Verified by `make verify-c`: 10 programs, 251 internal checks, bigint
36, deque 20, grid 33, heap 27, io 15, json 34, map 26, md5 9, num 31,
vec 20, plus the format and address-sanitizer legs of the gate.

sources: R. Rivest, RFC 1321, The MD5 Message-Digest Algorithm, April
1992, the K table, shift schedule, and the test vectors this suite
pins; the FNV-1a constants from the Fowler, Noll, Vo reference hash
page; the `__umodti3` link outcome is the machine fact recorded by
the chapter 16 probe in book 8 and reconfirmed by this suite's gate
run, 2026-09-14. The Lua comparisons cite the landed
`books/icpc/samples-lua/` modules read the same day.
