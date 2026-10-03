#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= arrays, spans, memory layout

The array is the base structure every later one is judged against:
contiguous, indexed in constant time, brutal to grow. This chapter
pins its layout facts, row-major order, cache line sharing, bounds
checks, and the span vocabulary that works on arrays without copying
them.

== row major order

Every language in this book that stores a matrix as one block stores
it the same way, consecutive rows, so cell (r, c) lives at flat
offset `r * cols + c`. C proves the layout with pointer arithmetic
and prices both walks with a one-line cache simulator.

The dry run: the fixture is the 4x4 grid holding r × 4 + c + 1,
walked in both orders, asserted by the C, JavaScript, and Lua suites.
C\# flattens a 2x3 grid instead, Go prices a 4x4 of int64 four
elements per line, and Python builds a two-slot toy cache.

+ Cell (2, 3) lives at flat offset 2 × 4 + 3 = 11, the address law
  the suites check cell by cell.
+ The row walk visits offsets 0 through 15 in storage order, one slot
  per step.
+ The column walk starts 0, 4, 8, 12: column neighbors sit 4 slots,
  16 bytes, apart.
+ Its fifth visit wraps from slot 12 back to slot 1: 1 - 12 = -11.
+ Both orders touch every cell exactly once, and both sums land 136,
  pinned twice by each suite.

#diagram([both walks as visit sequences over the same sixteen slots, the column hops stride and wrap], length: 13pt, {
  let strip = (y, title, order, hot: ()) => {
    cdraw.content((3.4, y + 0.75), title, size: 6pt)
    for (k, off) in order.enumerate() {
      let x = 3.4 + k * 1.13
      cdraw.rect((x, y), (x + 1.08, y + 0.7), fill: if k in hot { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + 0.54, y + 0.35), [#off], size: 6pt)
    }
  }
  strip(5.6, [row walk: storage order], range(16), hot: (0,))
  strip(2.4, [column walk: visit order], (0, 4, 8, 12, 1, 5, 9, 13, 2, 6, 10, 14, 3, 7, 11, 15), hot: (0, 4))
  cdraw.content((11.0, 1.5), [+4 between column neighbors], size: 6pt)
  cdraw.content((11.0, 0.8), [the 12 to 1 hop is the wrap, -11], size: 6pt)
  cdraw.content((11.0, 0.1), [both strips hold the same cells, both sum 136], size: 6pt)
})

Both walks land the same 136, and the listings below walk both orders
in six languages.

#listing("dsa/samples-c/src/Ch02/rowmajor.c", first: 17, last: 32, caption: [c, line touches counted for either walk order])

.NET stores a two dimensional `int[,]` the same way. Flatten and
unflatten are that arithmetic with no library help:

#listing("dsa/samples/src/Ch02/Arrays.cs", first: 3, last: 44, caption: [row-major flatten, unflatten, both traversal orders])

Row-major and column-major summation return the same value, the test
asserts it, and yet they are not the same code. The order in which
memory is touched differs, which is invisible to correctness and
decisive for speed. That gap is where this chapter goes next.

Four more languages pin the same walk pair:

#listing("dsa/samples-go/ch02/rowmajor.go", first: 25, last: 50, caption: [go, both walks over a flattened matrix, touches counted per stride])

#listing("dsa/samples-js/src/ch02-rowmajor.mjs", first: 12, last: 38, caption: [javascript, both offset orders plus the line simulator])

#listing("dsa/samples-py/src/Ch02/rowmajor.py", first: 21, last: 34, caption: [python, the address formula and a two-slot toy cache])

#listing("dsa/samples-lua/ch02_rowmajor.lua", first: 8, last: 20, caption: [lua, the same line simulator in floor-division arithmetic])

On the 64x64 fixture C, JavaScript, and Lua price the row walk at 256
line touches and the column walk at 4096. Go works a 4x4 of int64
values with a four-element stand-in line, 4 touches for the row walk
against 16 for the column walk, and checks both sums against an
independent closed form. Python builds a two-slot direct-mapped toy
cache, 4 misses on the row walk, 16 on the column walk, and 4 again
once four slots make it fully associative. C\# counts analytically,
4096 sequential ints fill exactly 256 lines.

== the cache cost model

A cache line is 64 bytes on current x64 and arm hardware, 16 ints.
Walking ints sequentially touches one line per 16 elements. Walking
with a stride of 16 ints or more touches one line per element, a 16
fold inflation in memory traffic for the same arithmetical work. The
cost model makes that countable without timing anything.

The dry run: the fixture is 4096 sequential ints and strided walks of
1000 touches, asserted by all six suites on the same integers. Every
tree computes the model in integer ceiling arithmetic, no float
touches the state anywhere.

+ Sequential ints pack 4096 × 4 = 16384 bytes, and 16384 / 64 = 256
  lines for the whole grid.
+ Forty ints span 160 bytes and straddle a third line: 3, packing
  has a ragged tail.
+ Stride 16 ints: 16 × 4 = 64 bytes per hop, a full line, so every
  touch lands on a fresh line and 1000 touches buy 1000 lines.
+ Stride 8 ints: 8 × 4 = 32 bytes, two touches share each line, and
  1000 / 2 = 500.
+ Stride 1 degenerates to the sequential count, the suites assert
  both counters agree at 4096.
+ A 64x64 column walk is the degenerate stride, 64 ints = 256 bytes
  per hop: 64 touches, 64 lines, no sharing at all.

#diagram([which touches share a line at each stride, the pinned totals on the right], length: 13pt, {
  let lbox = (x, y, w, body, hot) => {
    cdraw.rect((x, y - 0.3), (x + w, y + 0.3), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + w / 2, y), body, size: 6pt)
  }
  cdraw.content((0.5, 6.3), [stride 1], size: 6pt)
  lbox(3.6, 6.3, 4.4, [touches 1 .. 16], true)
  lbox(8.4, 6.3, 4.4, [17 .. 32], false)
  cdraw.content((13.4, 6.3), [...], size: 6pt)
  cdraw.content((19.2, 6.3), [4096 ints: 256 lines], size: 6pt)
  cdraw.content((0.5, 4.5), [stride 8], size: 6pt)
  lbox(3.6, 4.5, 1.9, [1  2], true)
  lbox(5.9, 4.5, 1.9, [3  4], false)
  lbox(8.2, 4.5, 1.9, [5  6], false)
  cdraw.content((10.6, 4.5), [...], size: 6pt)
  cdraw.content((19.2, 4.5), [1000 touches: 500 lines], size: 6pt)
  cdraw.content((0.5, 2.7), [stride 16], size: 6pt)
  lbox(3.6, 2.7, 1.9, [1], true)
  lbox(5.9, 2.7, 1.9, [2], false)
  lbox(8.2, 2.7, 1.9, [3], false)
  cdraw.content((10.6, 2.7), [...], size: 6pt)
  cdraw.content((19.2, 2.7), [1000 touches: 1000 lines], size: 6pt)
  cdraw.content((11.5, 1.0), [a line is 64 bytes, stride 16 ints leaves nothing to share], size: 6.5pt)
})

The 256 against the 1000-line degenerate stride are both pinned, and
the listing below is the counter that computes them.

#listing("dsa/samples/src/Ch02/Arrays.cs", first: 46, last: 67, caption: [deterministic cache line counts for sequential and strided walks])

The other five languages carry the same two counters as pure integer
arithmetic:

#listing("dsa/samples-c/src/Ch02/cache.c", first: 17, last: 33, caption: [c, the two line counters over one integer ceiling helper])

#listing("dsa/samples-go/ch02/cache.go", first: 3, last: 32, caption: [go, both counters over the line and int constants])

#listing("dsa/samples-js/src/ch02-cache.mjs", first: 4, last: 24, caption: [javascript, both counters, the floor of the padded numerator])

#listing("dsa/samples-py/src/Ch02/cache.py", first: 14, last: 29, caption: [python, both counters in floor division])

#listing("dsa/samples-lua/ch02_cache.lua", first: 6, last: 25, caption: [lua, both counters over the floor division operator])

Measured across the suites: all six pin 256 lines for 4096 sequential
ints, 3 for 40, 1000 lines for 1000 touches at stride 16, 500 at
stride 8, and the column walk of the 64x64 grid at 64 lines against
the row walk. The five new trees also pin the small counts, 4 lines
for 64 ints and 1 for one, with stride 1 equal to the sequential
count everywhere. The C and Lua files add property lanes, line counts
never dip below the sequential packing, never exceed one line per
touch, and never shrink as the stride grows. Every ceiling is
(a + b - 1) / b integer division.

The column walk of a 64x64 row-major grid strides one row per step,
64 ints or 256 bytes: 64 lines touched for 64 additions, against 4
lines for the row walk.
This is why the standard advice holds, traverse multidimensional data
in storage order, and why a jagged `int[][]`, one row per inner array,
localizes that damage better than `int[,]` when rows are processed
independently. The BCL sorts jagged arrays per row cheaply for the
same reason.

#diagram([row-major layout, the flat strip, and what a column walk costs], length: 13pt, {
  // a 4x4 grid, cell text is the flat offset r * 4 + c, column 1 shaded
  for r in range(4) {
    for c in range(4) {
      let f = if c == 1 { luma(205) } else { luma(235) }
      cdraw.rect((c * 1.5, 4.4 + r * 0.9), (c * 1.5 + 1.5, 5.3 + r * 0.9), fill: f, radius: 0.02)
      cdraw.content((c * 1.5 + 0.75, 4.85 + r * 0.9), [#(r * 4 + c)], size: 6pt)
    }
  }
  cdraw.content((-0.6, 7.55), [r3], size: 6pt)
  cdraw.content((-0.6, 4.85), [r0], size: 6pt)
  cdraw.content((2.6, 3.5), [cell r, c = flat r × 4 + c], size: 6.5pt)

  // the same 16 ints as one flat strip, one cache line wide
  for i in range(16) {
    let f = if calc.rem(i, 4) == 1 { luma(205) } else { luma(235) }
    cdraw.rect((9.0 + i * 0.95, 4.4), (9.0 + (i + 1) * 0.95, 5.3), fill: f, radius: 0.02)
  }
  cdraw.line((9.0, 5.7), (24.2, 5.7))
  cdraw.line((9.0, 5.7), (9.0, 5.95)); cdraw.line((24.2, 5.7), (24.2, 5.95))
  cdraw.content((16.6, 6.2), [one cache line, 16 ints], size: 6.5pt)
  cdraw.content((16.6, 3.6), [shaded cells are column 1: one line per row touched], size: 6.5pt)
})

#callout("note", "the model counts lines, not nanoseconds", [
  `LinesTouchedStrided` is a cost model, a deterministic function used
  in tests, not a cache simulator. Real caches prefetch sequential
  streams, so the measured speed gap is smaller than the line-count
  gap. The counts are still the right thing to assert because they
  are exact and directionally honest.
])

== spans over arrays

The span is the same contiguous memory without a promise of ownership.
Slicing takes a view, copying goes through it, and the line-walking
count from the cache model becomes a zero allocation loop.

The dry run: the fixture is a 200 byte buffer seeded with 0xAB at
offsets 0, 64, 128, 192, and 199, walked by CountByLine, asserted by
all six suites on the same values. The span is per-tree vocabulary, a
pointer plus length struct in C, real slices in Go, subarray windows
in JavaScript, explicit (start, length) helpers in Python, offset math
in Lua, and the out of range lane uses each tree's own refusal
mechanism.

+ The first window slices bytes 0..63 and finds the seed at offset 0:
  one hit.
+ The walk advances one line at a time: windows 64..127 and 128..191
  each add one hit at their first byte, three so far.
+ The tail window is 192..199, eight bytes: both 192 and 199 hit,
  3 + 2 = 5.
+ The C\# meter differenced around the whole walk reports exactly 0
  bytes allocated, no window ever copies, the other trees carry no
  countable meter and claim nothing.
+ MiddleSlice(10, 4) then hands back 10, 11, 12, 13, a view
  materialized only by the final ToArray.

#diagram([the walk over the 200 byte buffer, four windows, the running hits under each], length: 13pt, {
  // four 64 byte lines, the fourth cut 8 bytes in at 200, seeds marked hot
  let bx = (k) => 0.8 + k * 4.35
  for k in range(4) {
    cdraw.rect((bx(k), 5.0), (bx(k) + 4.2, 5.9), fill: if k < 3 { luma(235) } else { none }, stroke: luma(160), radius: 0.02)
    cdraw.content((bx(k) + 2.1, 6.35), [bytes #(k * 64)..#(k * 64 + 63)], size: 6pt)
  }
  let cut = bx(3) + 4.2 * 8 / 64
  cdraw.line((cut, 4.9), (cut, 6.0), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.content((bx(3) + 2.1, 4.5), [the buffer ends at 200], size: 6pt)
  for (off, k) in ((0, 0), (64, 1), (128, 2), (192, 3)) {
    cdraw.rect((bx(k) + 0.04, 5.25), (bx(k) + 0.3, 5.65), fill: luma(205), radius: 0.02)
  }
  cdraw.circle((bx(3) + 4.2 * 7.5 / 64, 5.45), radius: 0.09, fill: luma(205))
  let hits = (1, 2, 3, 5)
  for k in range(4) {
    let ww = if k < 3 { 4.2 } else { 4.2 * 8 / 64 }
    cdraw.rect((bx(k), 2.4), (bx(k) + ww, 3.3), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
    cdraw.content((bx(k) + 2.6, 2.85), [window #(k + 1)], size: 6pt)
    cdraw.content((bx(k) + 2.6, 1.95), [hits: #hits.at(k)], size: 6pt)
    cdraw.line((bx(k) + 2.1, 3.35), (bx(k) + 2.1, 4.85), stroke: (paint: luma(220), dash: "dashed"))
  }
  cdraw.content((9.5, 0.9), [5 hits, 0 bytes allocated, no window copies], size: 6.5pt)
})

The 5 hits on 0 allocated bytes is the pinned pair, and the listing
below is the walk itself.

#listing("dsa/samples/src/Ch02/Arrays.cs", first: 69, last: 120, caption: [slice views, the allocation free line walk, span copies])

The other five languages walk the same windows with their own slice
vocabulary:

#listing("dsa/samples-c/src/Ch02/spans.c", first: 42, last: 90, caption: [c, a pointer plus length span, the bounds guard, the line walk, fold])

#listing("dsa/samples-go/ch02/spans.go", first: 22, last: 67, caption: [go, real slices, the line walk, the panicking middle slice, fold])

#listing("dsa/samples-js/src/ch02-spans.mjs", first: 19, last: 52, caption: [javascript, subarray windows and explicit bounds, the line walk, fold])

#listing("dsa/samples-py/src/Ch02/spans.py", first: 17, last: 48, caption: [python, explicit start and length helpers, the line walk, fold])

#listing("dsa/samples-lua/ch02_spans.lua", first: 20, last: 53, caption: [lua, offset math with hand checked bounds, the line walk, fold])

Measured across the suites: doubled turns 1, 2, 3 into 2, 4, 6 with
the input unchanged, the fold of 0..14 reads (105, 15), the line walk
lands 5 hits on the seeded buffer, the copy round trip equals its
source as a distinct object, and the (10, 4) window of 0..99 hands
back 10, 11, 12, 13. The error lane refuses out of range start and
length pairs per tree, a return code in C, a panic in Go, a throw in
JavaScript and Python, an error in Lua.
`CountByLine` walks a 200 byte buffer 64 bytes at a time and only C\#
proves zero allocation while doing it, the chapter 1 meter put to
work. `CopyViaSpan` is `Array.Copy` in modern dress, same semantics,
no overlap allowed between source and target views.

#diagram([the span as a window over the array block, slicing copies nothing, CopyTo goes through], length: 13pt, {
  // the array: one contiguous block of bytes
  for i in range(16) {
    cdraw.rect((0.5 + i * 0.72, 5.0), (1.22 + i * 0.72, 5.7), fill: luma(235), radius: 0.02)
  }
  cdraw.line((0.5, 6.1), (12.0, 6.1), stroke: luma(100))
  cdraw.line((0.5, 6.1), (0.5, 6.3), stroke: luma(100)); cdraw.line((12.0, 6.1), (12.0, 6.3), stroke: luma(100))
  cdraw.content((6.25, 6.6), [the array, one contiguous block], size: 6.5pt)

  // the span: a dashed window over part of it, no new memory
  cdraw.rect((3.38, 4.8), (9.14, 5.9), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((6.25, 4.3), [span slice: start + length, a view, no copy], size: 6.5pt)
  cdraw.line((6.25, 4.55), (6.25, 4.8), stroke: luma(220))

  // CopyTo streams through the view into a second buffer
  cdraw.line((6.25, 3.9), (6.25, 3.3), stroke: luma(100), mark: (end: ">"))
  for i in range(8) {
    cdraw.rect((2.66 + i * 0.72, 2.4), (3.38 + i * 0.72, 3.1), fill: luma(205), radius: 0.02)
  }
  cdraw.content((6.25, 2.05), [CopyTo walks the block through the view], size: 6.5pt)
  cdraw.content((6.25, 0.85), [CountByLine reads the same window 64 bytes at a time, zero allocated], size: 6.5pt)
})

== bounds and safety

#flow(
  [bounds checks as a gate, three refusals and what the contract buys],
  node((0, 0), [an index reaches a container]),
  node((-2.8, -1.7), [negative constant: #linebreak() compile error]),
  node((0, -1.7), [runtime index out of range: #linebreak() IndexOutOfRangeException]),
  node((2.8, -1.7), [bad span range: #linebreak() ArgumentOutOfRangeException]),
  node((0, -3.6), [the contract is the point: safe code #linebreak() builds a hash table that cannot #linebreak() corrupt memory]),
  edge((0, 0), (-2.8, -1.7), "-|>"),
  edge((0, 0), (0, -1.7), "-|>"),
  edge((0, 0), (2.8, -1.7), "-|>"),
  edge((0, -1.7), (0, -3.6), "-|>"),
)

The runtime checks every array index against the length. A negative
index is a compile error when the compiler can see the constant and an
`IndexOutOfRangeException` when it cannot, and the test pins the
runtime side with an index smuggled through a local. `Span` carries
the same discipline, `AsSpan(start, length)` throws
`ArgumentOutOfRangeException` on bad ranges. These checks are not
overhead to curse at: they are why this book can build a hash table in
safe code that never corrupts memory, in any language with the same
guarantee.

All six suites build the guard by hand, a checked accessor plus an
insertion-point search. For five of them it is necessity, their
runtimes wrap, clamp, or trust the index, while C\# mirrors the check
its runtime already runs. C returns a refusal code before the read
is ever formed.

The dry run: the fixture is the sorted run 1, 3, 5, 7 behind the
checked accessor and the insertion point, asserted by the C\#, C,
JavaScript, and Lua suites. Go pins the same semantics over 10, 20,
30, and Python's gate exists to refuse its own wrap habits.

+ The gate passes 2, 0 <= 2 < 4, and the read forms: 5. Index 0
  returns 1 the same way.
+ The gate refuses 4, one past the end, and -1 and 1000000 with it:
  no read is ever formed outside the array.
+ The insertion point of 4 starts lo = 0, hi = 4: midpoint 2 holds
  5, not below 4, so hi = 2.
+ Midpoint 1 holds 3 < 4, so lo = 2, and lo == hi = 2: absent 4
  belongs at index 2.
+ The neighbors land 0 at 0, 8 past the end at 4, and duplicate 5 on
  its twin at 2.
+ InsertAt(2, 4) shifts 5 and 7 right one and lands 1, 3, 4, 5, 7 at
  length 5.

#diagram([the insertion point of 4 as a narrowing bracket over the run, then the tail shift], length: 13pt, {
  let vals = (1, 3, 5, 7)
  let cx = (i) => 1.6 + i * 2.1
  for (i, v) in vals.enumerate() {
    cdraw.rect((cx(i), 6.7), (cx(i) + 1.9, 7.6), fill: luma(235), radius: 0.02)
    cdraw.content((cx(i) + 0.95, 7.15), [#v], size: 6pt)
    cdraw.content((cx(i) + 0.95, 6.35), [#i], size: 6pt)
  }
  let br = (y, lo, hi, mid, verdict) => {
    cdraw.line((cx(lo), y), (cx(hi), y), stroke: luma(100))
    cdraw.line((cx(lo), y), (cx(lo), y - 0.16), stroke: luma(100))
    cdraw.line((cx(hi), y), (cx(hi), y - 0.16), stroke: luma(100))
    cdraw.circle((cx(mid) + 0.95, y), radius: 0.1, fill: luma(205))
    cdraw.content((16.8, y), verdict, size: 6pt)
  }
  br(5.3, 0, 4, 2, [mid 2 holds 5, so hi = 2])
  br(4.1, 0, 2, 1, [mid 1 holds 3, so lo = 2])
  cdraw.line((cx(2), 3.0), (cx(2) + 1.9, 3.0), stroke: luma(100))
  cdraw.line((cx(2), 3.0), (cx(2), 2.84), stroke: luma(100))
  cdraw.line((cx(2) + 1.9, 3.0), (cx(2) + 1.9, 2.84), stroke: luma(100))
  cdraw.content((16.8, 3.0), [lo == hi = 2: 4 goes here], size: 6pt)
  let after = (1, 3, 4, 5, 7)
  for (i, v) in after.enumerate() {
    let x = 1.6 + i * 1.72
    cdraw.rect((x, 1.3), (x + 1.55, 2.2), fill: if i == 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.775, 1.75), [#v], size: 6pt)
  }
  cdraw.content((1.6, 0.7), [insert 4 at 2: 5 and 7 shift right one, length 5], size: 6pt)
})

Absent 4 lands at index 2 in every suite that runs the fixture, and
the listings below build the guard six ways.

#listing("dsa/samples-c/src/Ch02/bounds.c", first: 17, last: 36, caption: [c, checked accessor and insertion point, no undefined access])

#listing("dsa/samples/src/Ch02/Bounds.cs", first: 9, last: 36, caption: [c\#, refusal accessor and insertion point, the runtime check underneath])

#listing("dsa/samples-go/ch02/bounds.go", first: 9, last: 30, caption: [go, a returned error that names the range, and the insertion point])

#listing("dsa/samples-js/src/ch02-bounds.mjs", first: 7, last: 22, caption: [javascript, gate first, read second, insertion point by binary search])

#listing("dsa/samples-py/src/Ch02/bounds.py", first: 25, last: 36, caption: [python, a gate against negative wrap and clamping insert])

#listing("dsa/samples-lua/ch02_bounds.lua", first: 7, last: 20, caption: [lua, nil refusal over one-based tables])

Anchors: C, C\#, JavaScript, and Lua run the insertion-point search
over 1, 3, 5, 7 and pin absent 4 at index 2, 0 at 0, 8 past the end
at 4, and duplicate 5 on its twin at 2. Go pins the same semantics
over 10, 20, 30 with a five-case table. Python's fixture is its own
warning, negative indices wrap and the builtin insert clamps far
positions, so its gate refuses both habits. JavaScript's accessor
also rejects 1.5, an integer check C does not need. C\#'s runtime
check stays the default guard, its tests pin the array and span
exceptions alongside the same anchors.

== across the six languages

Build sizes count non-comment source lines over the featured files;
bundled checks count where the language puts them in the same file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [279], [libc only], [pointer arithmetic proves the layout, refusal codes instead of exceptions, 52 checks in 4 files],
  [c\#], [132], [bcl only], [the accessor mirrors the guard the runtime already runs, the span walk's zero-allocation proof is the chapter 1 meter at work],
  [go], [121], [fmt for errors], [no unchecked mode exists, the choice is a panic or a returned error],
  [javascript], [95], [node stdlib], [the gate rejects non-integer indices too, insertAt rebuilds through spread],
  [python], [177], [stdlib only], [negative indices wrap by design, the gate exists to refuse that habit],
  [lua], [257], [lib.lua harness], [1-based tables shift the insertion-point bounds and its return by one],
)

sources: learn.microsoft.com, single dimensional arrays,
multidimensional arrays, jagged arrays, `Span<T>` and `ReadOnlySpan<T>`
api pages, `Array.Copy`, `Memory<T> and Span<T>` usage guidelines,
accessed 2026-09-08. Sample behavior verified by `make verify-csharp`,
18 tests in chapter 2 of the samples suite. The six-language layer
verifies the same way: 4 C programs with 52 embedded checks, 16 Go
tests, 18 `node --test` cases, 40 Python checks across 4 files, and 21
Lua checks under `run.lua`.
