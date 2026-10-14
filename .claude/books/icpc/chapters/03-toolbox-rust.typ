#import "../../theme/lib.typ": listing, diagram, cdraw, xref-to

= the rust toolbox

Rust enters the contest third in the corpus reading order, between C
and Go, and its toolbox is the eighth. Eleven files live in
`books/icpc/samples-rust/src/Ch03/`, one module per file, each
self-contained with its check harness embedded: 1362 non-blank lines
carrying 278 checks, zero dependencies, every structure either std or
built here, compiled per file under a pinned rustc 1.99.0 with
`--edition 2024 -D warnings`. The module list mirrors chapter 2 file
for file, bigint through json, with one addition, the token scanner
`scan.rs`, which C never needed and Go's `input.go` is the sibling of.
The integer story is the reversal of C's. Where C reaches for
`__uint128_t` and the link fails, rust owns `u128` as a first-class
type and the wide product is one expression. The trap moves to
overflow: a plain rustc build keeps overflow checks on, arithmetic
that wraps silently in C aborts here, so every wraparound site says
`wrapping_` or `checked_` out loud, and a green run is the proof that
nothing wraps unannounced.

== one file, one gate

The sample contract is the corpus one, stated in rust terms. Every
file embeds the same helper: a static `AtomicUsize` counter and an
`ok(cond, name)` that prints `ok N name` on a pass, prints `FAIL:
name` to stderr and exits 1 on the first failure. A module-scope
counter in rust must be atomic to exist at all, safe shared state is
the only kind the language offers, and the suites stay
single-threaded regardless. The runner `tools/run-rust-samples.ps1`
resolves the rustup-managed stable msvc toolchain from `RUSTUP_HOME`
or `~/.rustup`, asserts the version line begins `rustc 1.99.0
(b940084d7` and names the install command otherwise, then compiles
each file, runs the binary, and counts lines matching `^ok \d+`. Zero
checks is red, a FAIL line is red, a nonzero exit is red, and the
nightly toolchain this machine also carries never satisfies the gate.
No cargo, no clippy, no rustfmt anywhere in the lane: one file, one
compiler call, one binary, the same shape a contest judge performs.
The toolchain resolution story is the subject of
#xref-to("rust", "toolchain").

The dry run: the opening block of `scan.rs`, nine checks over one
five-token fixture, is the ledger of how the counter climbs.

+ `Scanner::load` reads `"3 42\n-7\t0 18446744073709551615"` whole
  and splits it on whitespace: five tokens. `has_next` passes, ok 1,
  and the token count asserts 5, ok 2.
+ `next_u64` takes the `3`, ok 3, then the `42`, ok 4.
+ `next_i64` takes the `-7`, ok 5, then the `0`, ok 6.
+ `next_u64` takes the last token and parses all twenty digits to
  `u64::MAX`, 18446744073709551615, ok 7.
+ `has_next` now reads false, ok 8, and `next` returns `None` at the
  end, ok 9, the refusal on record before anything else runs.

#diagram([the gate chain: toolchain assert, per-file compile under -D warnings, run, count ok lines, red on any failure], length: 12pt, {
  let box(x, y, w, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0.6, 3.2, 4.0, [resolve rustup stable])
  box(5.2, 3.2, 4.6, [assert 1.99.0 prefix], fill: luma(225))
  box(10.4, 3.2, 5.0, [rustc --edition 2024 -D warnings])
  box(16.0, 3.2, 3.6, [run, count ^ok], fill: luma(225))
  cdraw.line((4.6, 3.7), (5.2, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.8, 3.7), (10.4, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.4, 3.7), (16.0, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.6, 1.8), [zero ok lines, a FAIL line, a nonzero exit, each one red], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.6, 0.8), [nightly on the machine never satisfies the gate], size: 6.5pt, fill: luma(100), anchor: "west")
})

Nine checks print, and the helper doing the counting is the listing
below, identical bytes in all eleven files.

#listing("icpc/samples-rust/src/Ch03/vec.rs", first: 1, last: 11, caption: [the helper every module embeds, one atomic counter, one ok line per check, exit 1 on the first failure])

`-D warnings` is the discipline's teeth: an unused import or a dead
variable is a build failure, so the tree carries nothing it does not
use. The check names ride the ok lines to the runner, and the
per-module counts in this chapter's footer were measured there.

== input over a locked stdin

`io.rs` reads the whole source into one `String` through `impl Read`,
so a file handle, a cursor over bytes, and the standard input are the
same call, and errors travel as `io::Result`: the missing-path check
asserts the error instead of a sentinel. `read_lines` splits the whole
buffer on `\n`, pops the single empty piece a trailing newline leaves,
and strips one `\r` per line, so windows text needs no pre-pass.

The dry run: the fixture is chapter 2's 31 bytes, the cross-language
anchor, and the walk is the split over it.

+ `alpha` 5, newline 1, `beta` 4, newline 1, the empty line's newline
  1, `gamma delta` 11, newline 1, `epsilon` 7: 5 + 1 + 4 + 1 + 1 + 11
  + 1 + 7 = 31, the asserted length, and the corner reads pin byte 0
  as `a` and byte 30 as the final `n`.
+ The split walks the four newlines at byte indexes 5, 10, 11, and 23
  and leaves five pieces: the unterminated `epsilon` still counts, and
  no trailing newline exists for the pop to remove.
+ `lines[2]` is the empty string between the newlines at 10 and 11,
  the blank kept as data, the same reading Go's `ReadLines` pins and
  C's splitter arrives at from the byte side.
+ The crlf rewrite `one\r\ntwo\r\n` splits to two lines with both
  carriage returns stripped, and the empty file reads 0 bytes and 0
  lines.
+ `"x\n"` splits to `x` and one empty, the pop fires, and the count is
  1: no phantom final line, a check C's walker never needed because
  its count came from the newline walk itself.

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
  cdraw.content((0.6, 0.1), [line 2 is the kept blank, line 5 lacks a newline], size: 6.5pt, fill: luma(100), anchor: "west")
})

The read returns the pinned 31 and the split the pinned five lines,
and the listings below are the splitter and the blocking lane.

#listing("icpc/samples-rust/src/Ch03/io.rs", first: 25, last: 37, caption: [split the whole UTF-8 buffer, pop the trailing empty, strip one carriage return per line])

The stdin lane reads through `std::io::stdin().lock()` into the same
splitter, and the whole path sits behind an argv gate, `--stdin`. The
runner executes every binary with no arguments, and a bare run that
locked stdin would sit waiting on a console that never feeds it, so
the blocking lane exists only when asked for. The file's last check
writes its own ok line through a locked stdout handle, the output side
of the same discipline.

#listing("icpc/samples-rust/src/Ch03/io.rs", first: 39, last: 50, caption: [the locked-stdin lane behind an argv gate, the bare runner never blocks])

One divergence against the C twin is the walker itself. C's splitter
is `strlen`-based, so a NUL byte in the buffer would end its text, and
the rust split walks every byte of the `String`, NUL included, because
a rust string holds them and UTF-8 input arrives whole. Both walkers
produce the same five lines on this fixture, and the difference shows
only on input no judge would send. The Go twin's trailing-blank
behavior is the same deliberate reading, stated in
#xref-to("icpc", "toolbox-go").

== the token scanner

`scan.rs` is the one module with no C twin. C's year chapters parse
out of the line list with `sscanf`, and the sibling is Go's
`input.go`, whose `ReadInts` returns a whole vector of numbers or an
error. The Scanner is a cursor between those readings: `load` reads
any `Read` once and splits on whitespace into owned strings, then
`has_next`, `next`, `next_u64`, and `next_i64` pull tokens one at a
time, every take an `Option`, so an exhausted stream or a malformed
token is `None` instead of an exception, a zero, or a sentinel
position.

The dry run: the refusal block and the mixed-whitespace block close
the file, 10 checks from the garbage fixture to the last token.

+ `"-1 12x3"`: `next_u64` refuses the sign, ok 10, and `next_i64`
  refuses the letters, ok 11, both refusals asserted, not skipped.
+ The boundaries parse exactly: `i64::MIN` and `i64::MAX`, ok 12 and
  13.
+ `"1\r\n2"`: the carriage return is whitespace to the splitter, so
  the pair parses as 1 then 2, ok 14 and 15, no crlf special case in
  the token lane at all.
+ `"  lead\ttrail\n\nmid  "`: leading, trailing, tab, and doubled
  newline runs all collapse, three tokens, ok 16, then `lead`,
  `trail`, `mid`, ok 17 through 19, the file's end.

#diagram([the mixed-whitespace buffer: every run of whitespace is a seam, three tokens come out], length: 12pt, {
  let tok(x, w, t, fill: luma(238)) = {
    cdraw.rect((x, 3.0), (x + w, 4.1), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, 3.55), t, size: 6.5pt)
  }
  tok(0.6, 3.0, [lead], fill: luma(225))
  tok(4.4, 3.0, [trail], fill: luma(225))
  tok(8.2, 2.4, [mid], fill: luma(225))
  let seam(x, w, t) = {
    cdraw.rect((x, 3.0), (x + w, 4.1), fill: luma(246), radius: 0.02)
    if t != [] { cdraw.content((x + w / 2, 3.55), t, size: 5.5pt, fill: luma(120)) }
  }
  seam(3.6, 0.8, [])
  seam(7.4, 0.8, [])
  seam(10.6, 0.8, [])
  cdraw.content((0.6, 1.8), [space, tab, newline, carriage return: all one class to split_whitespace], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.6, 0.8), [the scanner owns its tokens as strings, the numeric read is parse().ok()], size: 6.5pt, fill: luma(100), anchor: "west")
})

Three tokens of four seams, and the listing is the whole scanner.

#listing("icpc/samples-rust/src/Ch03/scan.rs", first: 15, last: 51, caption: [split_whitespace once into owned strings, then a cursor whose every take is an Option])

Owning the token list up front is the cost: the whole input lives in
memory twice, once as text and once as tokens, the price of a cursor
with no borrow entanglement, and a contest input is small. The
`--scan-stdin` argv gate repeats io's rule for the same reason, and
the numeric conversion behind `next_u64` is the std parse, so the
refusal channel and the parse channel are one.

== the collections, borrowed whole

C builds its vector, deque, and heap by hand. Rust borrows all three
from std and asserts them from the outside, and the honest comparison
is contract against contract. `Vec` growth is amortized by contract:
the std's collections page marks push with the amortized star and says
the vector allocates a substantially larger array when it does grow,
so the tests assert floors, capacity at least 4 through the first four
pushes, at least 5 at the fifth, at least 9 at the ninth, where
chapter 2 pinned the exact staircase 4, 8, 16. Same pushes, same
eight-value sort fixture `5 3 9 1 7 2 8 6`, 4 skipped so an
off-by-one cannot hide, sorted both directions, and the same
`reserve(100)` jump past the doublings with the length held at 8.

#listing("icpc/samples-rust/src/Ch03/vec.rs", first: 14, last: 27, caption: [capacity asserted as a floor: growth is amortized by contract, not pinned doubling])

The deque fixtures are C's. The wrap block pushes 1, 2, 3 to the back
then 9 and 8 to the front and pops 8, 9, 1 across the seam, the growth
block interleaves 50 pushes at each end from capacity 2 and drains
-50 through -1 then 1 through 50 in order, and the rotation block
restores order after six pop-front-push-back cycles. The container is
`VecDeque`, all std, so the listing is the fixture, not the machinery:

#listing("icpc/samples-rust/src/Ch03/deque.rs", first: 48, last: 56, caption: [the wrap fixture: two front pushes cross the seam, the pops read 8, 9, 1])

The heap is where the borrowing needs one adapter. `BinaryHeap` is a
max-heap by its own description, the biggest first, so the min-heap
this toolbox wants is `Reverse` over a `(u64, i64)` tuple, and the
tuple is the tiebreak: where C's heap compares keys only and equal
keys come out in insertion order by the accident of a strict compare,
the rust adapter orders equal keys by the value field, on purpose.

The dry run: the duplicate block pushes three pairs and pins the
tiebreak.

+ Push (10, 1000), then (9, 91): under `Reverse` the max-heap's
  greatest is the smallest tuple, so the 9-pair sits on top.
+ Push (9, 92): equal key 9, and the tuple compares the value next, 91
  before 92, so (9, 91) stays on top.
+ The pops return (9, 91), then (9, 92), then (10, 1000), the pinned
  order with the tie broken by value, not by arrival.

#diagram([three layers: the std max-heap at the bottom, reverse flipping it, the tuple breaking ties], length: 13pt, {
  cdraw.content((11.2, 8.2), text(size: 6.5pt)[one adapter, three decisions])
  cdraw.rect((1.0, 6.2), (21.4, 7.75), fill: luma(205), radius: 0.02)
  cdraw.content((11.2, 7.3), text(size: 6pt)[MinHeap = `BinaryHeap<Reverse<(u64, i64)>>`])
  cdraw.content((11.2, 6.65), text(size: 6pt)[push, pop, peek unwrap the Reverse at the door])
  cdraw.rect((1.0, 3.95), (21.4, 5.5), fill: luma(225), radius: 0.02)
  cdraw.content((11.2, 5.05), text(size: 6pt)[Reverse: the greatest wrapper is the smallest inner])
  cdraw.content((11.2, 4.4), text(size: 6pt)[a max-heap of reverses is a min-heap])
  cdraw.rect((1.0, 1.7), (21.4, 3.25), fill: luma(245), radius: 0.02)
  cdraw.content((11.2, 2.8), text(size: 6pt)[the tuple: keys first, then values])
  cdraw.content((11.2, 2.15), text(size: 6pt)[equal keys break by value, c breaks by arrival])
  cdraw.line((6.0, 6.2), (6.0, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.4, 6.2), (16.4, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 3.95), (6.0, 3.25), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.4, 3.95), (16.4, 3.25), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.2, 0.9), text(size: 6pt)[an empty pop is None, never fiction])
})

The drain runs the tiebreak, and the listing is the adapter whole.

#listing("icpc/samples-rust/src/Ch03/heap.rs", first: 15, last: 27, caption: [binaryheap is a max-heap, reverse makes it min, the tuple breaks ties by value])

The rest of the heap fixtures repeat C's: the values travel with the
keys, the interleaved block holds the minimum on top through pushes
and pops, the heapsort pass over `4 9 1 7 3 8 6 5 2` pops 1 through 9
with each value ten times its key, and a growth run to 40 entries
peeks (1, 39) with the value intact. Two extra checks state the
borrowing out loud: the plain heap pops 9 first, the max-heap as
documented, and the reversed one pops 3. The sift machinery under all
of it, up and down, is #xref-to("dsa", "heaps") territory, built from
scratch there.

== index math

The grid module is the one container-shaped piece built rather than
borrowed, because it is not a container: pure index arithmetic over
`i32` coordinates, the law `r * cols + c` computed in `i64`, the
inverse split, the bounds predicate, and the two delta tables as
const arrays. The fixture set is chapter 2's, check for check, the
same 33: the 5 by 7 grid, the far corner 4 x 7 + 6 = 34 decoding back
to row 4 column 6, all 35 cells round-tripping, the neighbor counts 4
and 8 at the interior, 3 and 5 at an edge, 2 and 3 at a corner, the
degree sums 80 and 144 over 5 by 5, both derivable by counting shared
edges and half-diagonals by hand, and the degenerate one-row and
one-column grids pinning 1 at an end and 2 in the middle.

#diagram([the degenerate grids: a 1 by 4 row keeps 1 neighbor at each end and 2 in the middle, a 4 by 1 column the same], length: 12pt, {
  for i in range(4) {
    let cnt = if i == 0 or i == 3 { [1] } else { [2] }
    cdraw.rect((0.8 + i * 1.5, 3.4), (2.2 + i * 1.5, 4.8), fill: if cnt == [1] { luma(228) } else { luma(240) }, radius: 0.02)
    cdraw.content((1.5 + i * 1.5, 4.1), cnt, size: 6.5pt)
  }
  cdraw.content((3.7, 5.6), [1 by 4, the 4-neighbor counts], size: 6.5pt, fill: luma(100))
  for i in range(4) {
    let cnt = if i == 0 or i == 3 { [1] } else { [2] }
    cdraw.rect((9.4, 4.8 - i * 1.4), (10.8, 6.2 - i * 1.4), fill: if cnt == [1] { luma(228) } else { luma(240) }, radius: 0.02)
    cdraw.content((11.4, 5.5 - i * 1.4), cnt, size: 6.5pt, fill: luma(100), anchor: "west")
  }
  cdraw.content((10.1, 6.9), [4 by 1], size: 6.5pt, fill: luma(100))
  cdraw.content((14.2, 3.4), [sum 6 either way, edges only], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((14.2, 2.4), [idx = r \* cols + c, computed in i64], size: 6.5pt, fill: luma(100), anchor: "west")
})

#listing("icpc/samples-rust/src/Ch03/grid.rs", first: 13, last: 47, caption: [the two delta tables, the index law and its inverse, and the filtered neighbor count])

The law is the same one every toolbox in this book pins, the Go twin
round-trips a 3 by 3 on it and the C twin a 5 by 7, and the
`grid_neighbor_count` shape, a filter over the delta table through the
bounds predicate, replaces the C loop ladder with the same arithmetic
under it.

== the ordered map, not the hash map

The map is one line of type, `BTreeMap<String, i64>`, against the 130
lines of FNV-1a open addressing chapter 2 spends, and the choice of
tree over hash is a ruling, not a taste. The std `HashMap` hashes with
a random seed per process, so iteration order changes run to run, and
a suite or solver that walked one into its output would pin a coin
flip. The std's own page says it plainly: the ordered collections
yield their items in sorted order. So the toolbox map is the ordered
one, and its determinism is testable in a way a hash map's never is.

The dry run: the 200-key workload, the sorted lane, and the deletion
sweep.

+ Inserts `key0` through `key199` with square values: length 200,
  every lookup returns, `key42` holds 1764, `key200` misses.
+ The keys vector equals its own sorted copy, asserted directly:
  iteration order is key order, no sort performed.
+ The first key is `key0` and the last is `key99`: the names are digit
  strings and the tree orders them as text, so `key99` sorts after
  `key199`, the reading the check pins on purpose.
+ Deleting the hundred even keys halves the map, and all hundred odd
  squares survive.
+ The `BTreeSet` half: insert reports true then false on the
  duplicate, iteration collects 3, 5, 9 in order, and remove mirrors
  the refusal.

#diagram([the iteration strip: digit strings sorted as text, key99 last, a hash map would reshuffle this row every run], length: 12pt, {
  let names = ([key0], [key1], [key10], [key100], [key199], [key2], [key20], [key98], [key99])
  for (i, n) in names.enumerate() {
    let last = i == names.len() - 1
    cdraw.rect((0.8 + i * 2.35, 3.0), (2.9 + i * 2.35, 4.1), fill: if last { luma(222) } else { luma(238) }, radius: 0.02)
    cdraw.content((1.85 + i * 2.35, 3.55), n, size: 6.5pt)
  }
  cdraw.content((1.85, 2.2), [first], size: 6pt, fill: luma(100))
  cdraw.content((20.6, 2.2), [last], size: 6pt, fill: luma(100), anchor: "east")
  cdraw.line((1.85, 2.5), (1.85, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.6, 2.5), (20.6, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.8, 1.1), [text order: key99 after key199, the pinned reading], size: 6.5pt, fill: luma(100), anchor: "west")
})

Deletion is where the C comparison is sharpest. Open addressing cannot
empty a slot a probe walked through, so chapter 2 writes tombstones,
counts them against the load factor, and consumes them on reinsertion.
The tree just deletes: `remove` returns the old value, a reinsert is
an ordinary insert, and there is no tombstone surface anywhere to
test. The block below pins that absence by behavior, the counts before
and after.

#listing("icpc/samples-rust/src/Ch03/map.rs", first: 31, last: 42, caption: [remove returns the value and is gone, reinsert is insert, no tombstone surface anywhere])

#listing("icpc/samples-rust/src/Ch03/map.rs", first: 60, last: 65, caption: [the determinism lane: iteration is key order, first and last read without sorting])

The wider std collections story, including the hash map this chapter
deliberately declines, belongs to #xref-to("rust", "stdlib").

== big integers, the same twelve limbs

Rust's standard library ships no bigint, and the zero-dependency lane
bars the crate that would provide one, so the toolbox builds the same
limbs C builds, a deliberate mirror rather than a private rederivation:
sign-magnitude over 12 limbs of base one billion, least significant
first, 108 decimal digits of headroom, zero positive at every exit.
The anchors are the language-neutral ones, the 23-digit parse into
567890123, 678901234, 12345 from least to most significant, the carry
fixture, `123456789 * 987654321` landing at `121932631112635269`
across the limb boundary, and `10^21` over 7 leaving quotient
`142857142857142857142` and remainder 6.

The dry run: the carry fixture `99999999999999999999 + 1`, the same
walk chapter 2 traces.

+ The parse cuts twenty nines into three limbs, 999999999, 999999999,
  99, sign +1.
+ The magnitude add folds limb 0: 999999999 + 1 = 1000000000, one
  full base, the limb records 0 and carries 1. Limb 1 the same.
+ Limb 2: 99 + 1 = 100, under the base, no carry, three limbs still.
+ The print gives the top limb bare and pads the two below to nine
  digits, 3 + 9 + 9 = 21 characters, `100000000000000000000`, the
  pinned string.

#listing("icpc/samples-rust/src/Ch03/bigint.rs", first: 16, last: 39, caption: [the bigint struct, sign-magnitude over 12 base-1e9 limbs, the trim that keeps zero positive])

Multiply is the same schoolbook shape as C's, limb times limb into a
`u64` column array, one carry pass at the end, and the base stays a
billion for the same reason: a limb product stops near `10^18`, and
`u64` holds several of those plus a carry with room left.

#listing("icpc/samples-rust/src/Ch03/bigint.rs", first: 158, last: 179, caption: [schoolbook multiply into a u64 column accumulator, one carry pass])

The parse is where the twin diverges. C's `bi_parse` returns 0 on
garbage, a status the caller checks, and rust's returns `Option`,
`None` for the letter-bearing string, the bare minus, and the empty
string, all three asserted. The 128-digit cap is shared: C refuses
once its digit count passes 128, and rust at `rest.len() > 128`, a
sanity ceiling above the 108 digits the twelve limbs hold. The limb
cut keeps the least significant 108, so a 109-to-128-digit input
parses as its low 108 digits, the same truncation both trees inherit
from the shared budget.

#listing("icpc/samples-rust/src/Ch03/bigint.rs", first: 195, last: 210, caption: [parse as option: sign prefixes, the shared 128-digit cap, ascii digits only, None for garbage])

Comparison and the signed routes are the C logic in rust's idiom, the
magnitude compare limb count then limb values from the top, `Ordering`
returned instead of a sign convention, addition of opposite signs
routing through the magnitude subtract with the larger operand's sign,
and subtraction as addition of a negated copy, a `Copy` struct so the
negation is a stack byte copy rather than an allocation.

== number theory with a native u128

This is the module where rust's story inverts C's. C's mulmod is
add-and-double because the 128-bit product compiles and then fails to
link, `__umodti3` absent from the MSVC plus lld lane. Go assembles the
wide product from `bits.Mul64` halves. Java builds it from
`Math.multiplyHigh` plus a shift-subtract lane. Rust widens into a
type the machine and the language both carry, and the whole mulmod is
one expression: widen both operands to `u128`, multiply, reduce,
narrow. The suite pins the type itself before trusting it:

#table(
  columns: (1.5fr, 2.4fr, 1.8fr),
  inset: 4pt,
  table.header([*check*], [*expression*], [*pinned*]),
  [square of max], [`u64::MAX as u128` squared], [340282366920938463426481119284349108225],
  [mulmod at max], [`num_mulmod(u64::MAX, u64::MAX, MOD)`], [the direct u128 reduction],
  [overflow refused], [`(1 << 127).checked_add(1 << 127)`], [`None`],
  [widening boundary], [`u64::MAX as u128 + 1`], [`1 << 64`],
)

The square is the 39-digit product no 64-bit sibling can form without
help, the `checked_add` is the same overflow the plain operator would
panic on under this lane's build, and the widening boundary is the
arithmetic the narrowing rides back on. Four checks with `u128` in
their names, and every one green means the type behaves at its edges.

#diagram([the u128 register: the product of two 64-bit maxima fills it past the halfway line, the u64 boundary sits far left], length: 12pt, {
  cdraw.rect((0.8, 3.0), (21.6, 4.6), fill: luma(238), radius: 0.02)
  cdraw.content((11.2, 4.05), text(size: 6pt)[u128, the square of u64::MAX spans nearly all of it])
  cdraw.rect((0.8, 3.0), (11.2, 3.7), fill: luma(225), radius: 0.02)
  cdraw.content((6.0, 3.35), text(size: 6pt)[u64::MAX sup 2 = 2^128 - 2^65 + 1])
  cdraw.line((0.8, 2.4), (0.8, 4.9), stroke: luma(100))
  cdraw.content((1.4, 5.1), [bit 0], size: 6pt, fill: luma(100))
  cdraw.line((10.9, 2.4), (10.9, 4.9), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((11.5, 5.1), [bit 64, the u64 boundary], size: 6pt, fill: luma(100))
  cdraw.line((21.3, 2.4), (21.3, 4.9), stroke: luma(100))
  cdraw.content((20.7, 5.1), [bit 127], size: 6pt, fill: luma(100))
  cdraw.content((0.8, 1.2), [mulmod: widen, multiply, reduce, narrow, one expression], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.8, 0.3), [checked_add refuses where the plain operator would panic], size: 6.5pt, fill: luma(100), anchor: "west")
})

#listing("icpc/samples-rust/src/Ch03/num.rs", first: 31, last: 46, caption: [mulmod is one line of native u128, modpow squares through it])

`modpow` rides that mulmod at every step, and the anchor is the one
every language in this book agrees on, `2^100 mod 1000000007` at
976371285, with the fermat lane `2^(MOD-1)` at 1 and the degenerate
modulus 1 pinning 0. The inverse goes through extended euclid with a
gcd guard that returns 0 on shared factors, the one sentinel refusal
in this toolbox, and the 97 sweep cross-checks it against mulmod for
every unit below the prime. The euclid chain and the bezout identity
for 240 and 46, x = -9 and y = 47, are chapter 2's pins exactly, and
the teaching derivation lives in #xref-to("dsa", "numtheory").

The crt fold carries the wave's one caught defect. The pairwise
combine needs the residue difference `(r2 mod m1) - (r1 mod m1)`,
which is negative whenever the second residue is the smaller, and the
plain `u64` form of the normalization panics on that underflow under
the lane's overflow checks. The fix widens the normalization through
`u128`, add `m1` before subtracting, reduce, narrow, and the blind
review that caught it is the reason the wrapped-difference fixtures
exist:

+ The classic fold: 2 mod 3 with 3 mod 5 combines to 8 mod 15, then
  with 2 mod 7 to 23 mod 105, the asserted pair.
+ Shared factors in agreement: 1 mod 6 with 3 mod 10 resolves to 13
  mod 30. In conflict: refused.
+ The wrapped difference, crt(7, 10, 0, 3): the difference 0 - 7 is
  negative, the normalization reads (0 + 10 - 7) mod 10 = 3, and the
  scan from x = 7 by steps of 10 finds 27, 27 mod 3 = 0, the pair (27,
  30). Its refusal twin, crt(9, 10, 0, 5), dies on the gcd test: 1 is
  not divisible by 5.

#listing("icpc/samples-rust/src/Ch03/num.rs", first: 80, last: 95, caption: [the residue difference normalized through u128, the scan to the combined class, None on conflict])

#listing("icpc/samples-rust/src/Ch03/num.rs", first: 154, last: 161, caption: [the showcase block: the square of max pinned in full, checked add refusing, the widening boundary])

== md5 and json leaves

The digest module is RFC 1321 again, the same K and S tables chapters
2 and 9 carry, little-endian Merkle-Damgard over 512-bit blocks, 64
rounds in four passes, and the same vector set including the 80-digit
input whose digest `57edf4a22be3c955ac49da2e2107b67a` crosses the
block boundary, plus determinism and avalanche, `abcd` against
`abce`. The padding arithmetic differs in shape only: one expression,
`((len + 8) / 64 + 1) * 64`, computes the padded length where C
counted zeros to 56 mod 64, and on the 80 digits it gives (80 + 8) /
64 = 1, plus 1, times 64, 128 bytes, two blocks.

The round math is the tree's one deliberate wrap site. C's `uint32`
wraps by definition and Lua masks to 32 bits after every operation,
and rust must say the same thing out loud, `wrapping_add` at every
add of the round and every fold into the chaining state, because the
algorithm is defined on the wrap and a plain rustc build would panic
on the first real input without the names.

#listing("icpc/samples-rust/src/Ch03/md5.rs", first: 59, last: 81, caption: [the 64 rounds with wrapping adds, folded into the state, the one wrap site in the tree])

#diagram([the 80-digit input pads into two blocks: 64 message bytes, then 16 message, the pad, 39 zeros, and the length], length: 12pt, {
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
  cdraw.content((0.6, 1.0), [padded = ((80 + 8) / 64 + 1) \* 64 = 128], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.6, 0.1), [bit length 640, little-endian, the digest is the two-block vector], size: 6.5pt, fill: luma(100), anchor: "west")
})

The json module is a recursive-descent parser into an enum tree,
`Null`, `Bool`, `Number`, `String`, `Array`, `Object`, `Option`
through the whole parse, all-or-nothing with trailing content
refused, so `{`, `[1, 2`, `tru`, and `1 2` all return `None`. Two
bounds the C twin arrived at from the pool side arrive here from the
recursion side: C's node pool is 128 nodes so depth is bounded by
construction, and rust allocates freely, so the parser charges depth
per container and refuses at 128, the same number, with the seam
pinned both ways, 200-deep refused and 100-deep accepted.

The dry run: the crafted fixture is chapter 2's walk document, and the
leaves fold the same sum.

+ `{"a": 1, "b": [2, 3.5, true, null, "x"], "c": {"d": -4}}` parses to
  a three-member object, keys `a`, `b`, `c` in order.
+ The array under `b` holds five children by index: 2, 3.5, `true`,
  `null`, `"x"`, order kept, and the escape fixture decodes quote,
  backslash, newline in place.
+ The variant counts read 4 numbers, 1 array, 2 objects, 1 boolean, 1
  null, and the numeric-leaf sum folds 1 + 2 + 3.5 - 4 = 2.5, the
  pinned value the C and Lua walks also print.
+ The scalars parse alone, `42`, `true`, `null`, `"solo"`, the empty
  containers parse, and the depth seam holds: 100 brackets accepted,
  200 refused.

#diagram([the depth gate: recursion charges per container, 100 deep parses, 200 deep is refused at 128], length: 12pt, {
  cdraw.rect((8.2, 5.2), (14.0, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.1, 6.3), text(size: 6pt)[parse_value])
  cdraw.content((11.1, 5.65), text(size: 6pt)[depth +1 per container])
  cdraw.line((11.1, 5.2), (11.1, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.4, 3.2), (9.0, 4.7), fill: luma(205), radius: 0.02)
  cdraw.content((5.7, 4.2), text(size: 6pt)[depth 100: accepted])
  cdraw.content((5.7, 3.55), text(size: 6pt)[the parsed tree returns])
  cdraw.rect((12.6, 3.2), (19.8, 4.7), fill: luma(225), radius: 0.02)
  cdraw.content((16.2, 4.2), text(size: 6pt)[depth 200: refused])
  cdraw.content((16.2, 3.55), text(size: 6pt)[the gate fires at 128])
  cdraw.line((9.4, 5.0), (5.7, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.2, 5.0), (16.2, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.1, 2.2), text(size: 6pt)[c's pool of 128 nodes bounds depth by construction])
  cdraw.content((11.1, 1.3), text(size: 6pt)[rust allocates freely, so the gate is explicit])
})

#listing("icpc/samples-rust/src/Ch03/json.rs", first: 75, last: 92, caption: [the RFC-narrow number scan, ten characters, then the f64 parse])

The number grammar is a reported divergence. The scanner admits the
ten characters the RFC grammar uses, digits, minus, plus, dot, `e`,
`E`, and the `f64` parse behind it refuses everything else, where C's
`strtod` accepts the C locale's wider forms, hexadecimal floats among
them. Numbers land in `f64`, the same 53-bit mantissa Go's `float64`
leaves land in, so chapter 4's integer-honesty note applies here
unchanged.

#listing("icpc/samples-rust/src/Ch03/json.rs", first: 94, last: 104, caption: [the depth gate at 128, recursion charged per container, None past it])

== built here, cited elsewhere

Eleven files, 1362 non-blank lines, 278 checks, zero dependencies, and
the split between what this toolbox builds and what it borrows:

#table(
  columns: (1.7fr, 1.5fr, 1.9fr),
  inset: 4pt,
  table.header([*piece*], [*status*], [*where*]),
  [input over any reader], [built, `io.rs`], [full-buffer split, argv-gated locked stdin],
  [token scanner], [built, `scan.rs`], [no c twin, go's `input.go` the sibling],
  [vector], [std, asserted], [growth amortized by contract, c pins exact doubling],
  [deque], [std, asserted], [the wrap fixture 8, 9, 1 matches c's ring],
  [heap], [std plus adapter], [reverse tuples break ties by value, c compares keys],
  [map and set], [std `BTreeMap`], [sorted iteration pinned, no tombstone, c hand-rolls fnv],
  [grid], [built, `grid.rs`], [the index law, degree sums 80 and 144],
  [bigint], [built, `bigint.rs`], [std has none, crates barred, parse `Option` vs c's 0],
  [mulmod, modpow, crt], [built, `num.rs`], [native u128, the residue normalized through u128],
  [md5], [built, `md5.rs`], [rfc 1321, wrapping adds at the round math],
  [json], [built, `json.rs`], [depth gate 128, rfc-narrow numbers vs strtod],
  [size], [1362 non-blank, non-comment], [1523 raw lines, 11 files],
  [dependencies], [none], [per-file rustc, no Cargo.toml, std only],
  [the integer boundary], [`u128` native], [wrapping where c wraps, crt through u128, md5 the one wrap site],
)

Chapter 2 and this one mirror module for module, and the divergences
are named where they teach rather than hidden in the fixtures. Go's
chapter 4 splits the same substrate the library way, thin wrappers
over `math/big` and `math/bits`, and the Lua twin of chapter 9 builds
everything C builds over tables. Java's chapter 5 sits at the opposite
pole from all three: `BigInteger` ships, and the kit still builds the
wide product from `Math.multiplyHigh` because the language stops at 64
bits. Rust is the pole where the wide lane is simply there.

Verified by `make verify-rust`, whose book-suite leg compiles and runs
`books/icpc/samples-rust/src`: 11 files, 278 checks, rustc 1.99.0
pinned, bigint 26, deque 20, grid 33, heap 30, io 17, json 32, map 38,
md5 9, num 34, scan 19, vec 20.

sources: doc.rust-lang.org, the standard library pages for `Vec`,
`VecDeque`, `BinaryHeap`, `BTreeMap`, and `BTreeSet`, accessed
2026-10-14, the amortized-growth contract, the max-heap description,
and the sorted-iteration guarantee read from the collections overview;
R. Rivest, RFC 1321, April 1992, the K table, shift schedule, and test
vectors this suite pins, the same reference chapters 2 and 9 build
from. The overflow-checks behavior is the lane's own fact: an
unoptimized rustc build aborts on arithmetic overflow, and the
suite's green run, with `wrapping_` only at the md5 round math and the
crt fix through `u128`, is the recorded proof. The C and Go
comparisons cite the landed `books/icpc/samples-c/src/Ch02/` headers
and `books/icpc/samples-go/` modules, read 2026-10-14.
