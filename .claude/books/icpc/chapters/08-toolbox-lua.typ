// book 10, chapter 8: the lua toolbox. nine modules plus their own
// lib.lua in books/icpc/samples-lua/, one runner, listings sliced
// from the landed files
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= the lua toolbox

Lua is the language where the machine's arithmetic is the least
honest, integers are 64-bit and wrap silently, so the Lua toolbox is
built around saying that out loud and then refusing to depend on it.
Nine modules live in `books/icpc/samples-lua/`, 1088 lines, each
returning a table of named test functions that a single `run.lua`
executes and counts: 45 checks across the nine, 7 for bigint down to
4 for heap, deque, and strutil. This chapter walks each module the
way #xref-to("icpc", "toolbox-c") walks the C headers, and the two
chapters cross-cite wherever the same structure teaches differently.
The C chapter's dilemma was a link failure, a 128-bit product that
would not link. Lua's is quieter and worse: the product computes
fine and answers wrong.

== modules, assertions, and the runner

Every module follows one shape: helpers at the top, then a returned
table of `{name = ..., fn = ...}` test blocks. The runner requires
each module by name, runs each block under `pcall`, prints one line
per module with the pass count, and exits nonzero on any failure.
Assertions come from a `lib.lua` that the suite carries its own copy
of: `run.lua` prepends `./?.lua` to `package.path`, so `require("lib")`
resolves to the assertion module beside the samples, not to whatever
else the machine has. `T.eq` compares with Lua equality first and
structurally for tables, keys and values both, so a decoded json tree
can be checked against a literal in one call. `T.ok` is the plain
assertion, and `T.throws` requires an error whose message contains a
given substring, which is how the json module's named errors are
tested. The interpreter is the repo's vendored Lua 5.5.1, and the
suites under it are pure: no network, no clock, no unseeded
randomness, the same discipline every suite in this book runs under.

#diagram([one module's shape: helpers, a returned table of named test blocks, one runner line per module], length: 12pt, {
  cdraw.content((9.6, 4.6), [helpers, then a table of named tests, then run.lua], size: 6.5pt)
  cdraw.content((9.6, 3.5), [one count line per module, 45 checks over nine], size: 6.5pt, fill: luma(100))
  cdraw.content((0.6, 2.2), [lib.lua supplies eq, ok, throws], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.6, 1.1), [package.path ./?.lua first], size: 6.5pt, fill: luma(100), anchor: "west")
})

The dry run: no suite file carries `run.lua`, nothing requires it, so
this walk is hand-derived from the fixtures it loads. It meets
`ch07_heap`, whose returned table holds 4 blocks, and prints the
module's line.

+ The require resolves through the prepended `./?.lua` to
  `ch07_heap.lua`, which returns its 4 blocks: default order,
  reversed comparator, tuple comparator, interleaved.
+ Each `fn` runs under `pcall`, all four pass, and `cpass` ends at 4.
+ The line prints through `string.format("%-22s %d/%d", name, cpass,
  #mod)`, the name padded to 22 then `4/4`.
+ The same loop over the chapter's nine modules adds 7 + 4 + 4 + 5 +
  5 + 4 + 5 + 5 + 6 = 45 passed, 0 failed, and exits 0.
+ Had a block raised, `pcall` returns false, the error goes to stderr
  beside the module and block name, `failed` gains 1, and the run
  ends in `os.exit(1)`.

#diagram([one module through the runner loop, from require to the printed line], length: 12pt, {
  let box(x, y, w, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, size: 6pt)
  }
  box(0.6, 3.4, 2.8, [require])
  box(4.2, 3.4, 3.0, [pcall x 4], fill: luma(244))
  box(8.0, 3.4, 2.6, [cpass 4])
  box(11.4, 3.4, 4.4, [ch07_heap 4/4], fill: luma(225))
  cdraw.line((3.4, 3.95), (4.2, 3.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.2, 3.95), (8.0, 3.95), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.6, 3.95), (11.4, 3.95), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.6, 1.8), [a raised block lands on stderr by name, failed grows, the run exits 1], size: 6.5pt, fill: luma(100), anchor: "west")
})

One ok line per module is the whole output contract, `ch07_heap 4/4`
among them, and the two listings below are the files that produce it.

Two files close the runner story. `lib.lua` is the assertion module
the opening paragraph describes, the `T.eq`, `T.ok`, and `T.throws`
the module tests call, and the most required file in the suite, 82
modules load it. `run.lua` is the top of the graph and is required by
nothing: it loads each `chNN` module as its table of `(name, fn)`
blocks, runs each block's asserts under `pcall`, and prints one ok
line per module with the pass count over the block count, exiting
nonzero on any failure. With both printed, every `require` the book's
lua solvers make now resolves to a printed file.

#listing("icpc/samples-lua/lib.lua", first: 17, last: 48, caption: [lua: the assertion library, deep through tables for eq, ok as the plain gate, throws demanding the named error])

#listing("icpc/samples-lua/run.lua", first: 88, last: 108, caption: [lua: the runner engine, path prepend, one pcall per block, one count line per module, exit 1 on failure])

== big integers over limb tables

The bigint keeps the same representation as the C twin, sign and
magnitude over base one billion limbs, least significant first, but
the limbs live in a plain Lua table that grows without a declared
budget, and zero is `sign = 0`, where C pins zero at sign plus one.
Parsing walks the decimal string nine digits at a time from the
right, `tonumber` on each slice, and printing zero-pads every limb
but the top with `%09d`, the same reassembly trick the C chapter
shows. The zero-detection at parse time is a small honesty of its
own: an all-zero input like `-000` parses to the zero sign, never to
a negative zero.

The dry run: the module's test `small division with pinned quotient
and remainder` feeds `smalldiv(parse("10000000000000000000"), 7)` and
asserts the pair with `T.eq(tostr(q), "1428571428571428571")` and
`T.eq(r, 3)`.

+ Parse cuts the twenty-digit string nine at a time from the right:
  three limbs, `{0, 0, 10}` little-endian, the top limb carrying the
  `10` and the two zero limbs the eighteen trailing zeros.
+ Division starts at the top limb with `rem = 0`: `cur = 0 x
  1000000000 + 10 = 10`, quotient limb `10 // 7 = 1`, `rem = 10 % 7
  = 3`.
+ One limb down: `cur = 3 x 1000000000 + 0 = 3000000000`, quotient
  limb `3000000000 // 7 = 428571428`, `rem = 3000000000 % 7 = 4`.
+ The bottom limb: `cur = 4 x 1000000000 + 0 = 4000000000`, quotient
  limb `4000000000 // 7 = 571428571`, `rem = 4000000000 % 7 = 3`.
+ `tostr` prints the top quotient limb bare and zero-pads the rest
  with `%09d`, so `1`, `428571428`, `571428571` concatenate to 19
  digits.

#table(
  columns: (auto, auto, 1.2fr, auto, auto),
  inset: 4pt,
  table.header([*step*], [*limb*], [*cur = rem x 10^9 + limb*], [*out*], [*rem*]),
  [1], [cut], [20 digits, right to left], [`{0, 0, 10}`], [0],
  [2], [10], [10], [1], [3],
  [3], [0], [3000000000], [428571428], [4],
  [4], [0], [4000000000], [571428571], [3],
  [5], [print], [1, 428571428, 571428571], [1428571428571428571], [3],
)

Every row is one division step or one pad, and the last row is what
the two checks read: quotient `1428571428571428571`, remainder 3.

#listing("icpc/samples-lua/ch07_bigint.lua", first: 24, last: 49, caption: [lua: parse cuts nine digits from the right into a limb table, tostring reassembles with the zero pad])

Signed addition dispatches on the signs with two shortcuts C does not
need: an operand with `sign == 0` returns the other operand
unchanged, and equal opposite magnitudes collapse to zero explicitly.
Subtraction is addition of a negated copy, the negation copying the
limb table so the original is never mutated.

#listing("icpc/samples-lua/ch07_bigint.lua", first: 99, last: 121, caption: [lua: signed add with the zero shortcuts and the magnitude dispatch, sub as add of negated])

Multiplication is schoolbook with the carry folded inline, limb i of
a times limb j of b accumulating at `i + j - 1`, one-based, the carry
spilling into the next column as each row completes. The C twin
accumulates all columns first and carries once at the end. The
comment in the code is the whole safety argument: a product of two
base one billion limbs is under 10^18 and under the 2^62 wrap line,
so the limb-level arithmetic a bigint needs never wraps even though
the machine will wrap a careless product happily.

#listing("icpc/samples-lua/ch07_bigint.lua", first: 124, last: 139, caption: [lua: schoolbook mul, carry folded per row, the under-2^62 comment carrying the safety argument])

Small division walks from the top limb down, remainder times base
plus limb, and its bound is stated beside the multiplication's: the
running value stays under d times a billion, still under 2^62. The
fixtures differ from C's on purpose, each language pins its own
mini-inputs: here `10^19` over 7 leaves quotient
`1428571428571428571` and remainder 3, and `-100` over 7 truncates to
`-14` with the magnitude remainder 2, the sign riding the quotient
alone, where the C suite pins `10^21` over 7 with
remainder 6. The property test is the one worth stealing: multiply
distributes over add, `c*(a+b) == c*a + c*b`, checked at magnitudes
past what any int64 holds.

#listing("icpc/samples-lua/ch07_bigint.lua", first: 142, last: 151, caption: [lua: small division top-down with the remainder, the bound stated where it is used])

#diagram([why the toolbox needs a bigint: the 4e9 squared product sits past the int64 ceiling, and the machine says nothing], length: 12pt, {
  let box(x, y, w, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(0.6, 5.2, 3.4, [4000000000])
  box(4.8, 5.2, 1.6, [x], fill: luma(248))
  box(7.2, 5.2, 3.4, [4000000000])
  box(11.8, 5.2, 2.0, [=], fill: luma(248))
  box(14.6, 5.2, 8.0, [16000000000000000000], fill: luma(225))
  cdraw.line((8.9, 4.4), (8.9, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.6, 2.6), [int64 ceiling 9223372036854775807], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.line((0.6, 2.2), (18.6, 2.2), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.content((0.6, 1.2), [the machine wraps above the line, silently], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.6, 0.3), [the bigint carries it, 20 digits, no wrap], size: 6.5pt, fill: luma(100), anchor: "west")
})

== the heap with a comparator

The Lua heap is the same array-backed binary min-heap as the C one,
sift up on push and smaller-child sift down on pop, with one design
difference that buys a lot: the comparator is injected at
construction. The default is plain `<`, a reversed comparator turns
the same structure into a max-heap, and a tuple comparator over
`(cost, id)` pairs breaks ties on the id, which is exactly the shape
a Dijkstra frontier wants. The C twin hard-codes the order by key
type instead, and the year chapters pick per language accordingly.

The dry run: the module's test `interleaved pushes and pops keep the
winner on top` mixes 7, 1, 3, and 0 through the default comparator
and asserts every return, five `T.eq` pops and peeks closing on
`T.eq(Heap.size(h), 0)`.

+ `Heap.push(h, 7)` leaves `[7]`; `Heap.push(h, 1)` appends then
  sifts once, 1 under 7 swaps them to `[1, 7]`.
+ `Heap.pop(h)` returns 1, the last element 7 takes the root with no
  challenger below, and the array is `[7]`.
+ `Heap.push(h, 3)` sifts to `[3, 7]`; `Heap.push(h, 0)` appends to
  `[3, 7, 0]` then swaps twice, 0 past 3 into the root, `[0, 7, 3]`.
+ `Heap.peek(h)` reads that root, 0.
+ The drain pops 0, 3, then 7, the last element walking rootward each
  time, until the array empties and `Heap.size(h)` reads 0.

#diagram([the array after each interleaved operation, root shaded, the winner never leaving the top], length: 12pt, {
  let state(x, y, vals) = {
    for (i, v) in vals.enumerate() {
      cdraw.rect((x + i * 1.3, y), (x + i * 1.3 + 1.2, y + 1.0), fill: if i == 0 { luma(225) } else { luma(240) }, radius: 0.02)
      cdraw.content((x + i * 1.3 + 0.6, y + 0.5), v, size: 6.5pt)
    }
  }
  state(0.8, 4.4, ([1], [7]))
  state(4.6, 4.4, ([7],))
  state(7.4, 4.4, ([3], [7]))
  state(11.2, 4.4, ([0], [7], [3]))
  cdraw.rect((16.0, 4.4), (17.2, 5.4), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((2.0, 3.5), [pushes 7, 1], size: 6pt, fill: luma(100))
  cdraw.content((5.2, 3.5), [pop 1], size: 6pt, fill: luma(100))
  cdraw.content((8.6, 3.5), [push 3], size: 6pt, fill: luma(100))
  cdraw.content((13.1, 3.5), [push 0], size: 6pt, fill: luma(100))
  cdraw.content((16.6, 3.5), [drained], size: 6pt, fill: luma(100))
})

The winner sits on top after every push and pops in exactly the order
the asserts pin, 1 then 0 then 3 then 7, ending at the empty heap's
size 0.

#listing("icpc/samples-lua/ch07_heap.lua", first: 8, last: 41, caption: [lua: heap with an injected comparator, default `<`, sift up and sift down])

The fixture suite runs the default order ascending over `5 3 8 1 9
2`, reverses the comparator for the max-heap, and pins the tuple
order: `(4,20)`, `(2,99)`, `(4,10)`, `(2,7)` pushed in that order pop
as `(2,7)`, `(2,99)`, `(4,10)`, `(4,20)`. Interleaved pushes and pops
keep the winner on top throughout. The module is 91 lines against
the C header's 77, and the difference is the comparator plumbing plus
Lua's voice, one function per operation instead of one `static
inline` block.

#diagram([the tuple comparator at work: four pushed pairs and the pop order, cost first, id breaking ties], length: 12pt, {
  let pair(x, y, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + 3.6, y + 0.9), fill: fill, radius: 0.02)
    cdraw.content((x + 1.8, y + 0.45), t, size: 6.5pt)
  }
  cdraw.content((4.0, 5.0), [pushed, in arrival order], size: 6.5pt, fill: luma(100))
  pair(0.6, 3.6, [(4, 20)])
  pair(4.8, 3.6, [(2, 99)])
  pair(9.0, 3.6, [(4, 10)])
  pair(13.2, 3.6, [(2, 7)])
  cdraw.line((9.0, 3.4), (9.0, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.0, 2.2), [popped, cost then id], size: 6.5pt, fill: luma(100))
  pair(0.6, 0.6, [(2, 7)], fill: luma(225))
  pair(4.8, 0.6, [(2, 99)], fill: luma(225))
  pair(9.0, 0.6, [(4, 10)], fill: luma(225))
  pair(13.2, 0.6, [(4, 20)], fill: luma(225))
})

== the ring deque, rotating

The deque mirrors the C ring, head index, count, modulo on both ends,
growth by doubling with a rebase to logical index zero, and it adds
the one instrument the C header leaves implicit: a `copies` counter
that grows by the live count on every doubling. The test reads it
directly, a four-slot ring that fills, wraps across the seam, and
doubles holds six entries with exactly 4 copies paid, the number the
amortized argument predicts for that growth.

The dry run: the module's test `rotate left and right by steps` loads
1 through 5 into a cap 8 ring and asserts the array after each of
three rotations with `T.eq(Deque.to_array(q), ...)`.

+ Five `push_back` land at slots 1 through 5 with head 0, count 5,
  the array `{1, 2, 3, 4, 5}`.
+ `rotate(q, 2)` runs `n = 2 % 5 = 2` pop-front push-back rounds: the
  1 moves to slot 6, the 2 to slot 7, head ends at 2, and `to_array`
  reads slots 3 through 7 as `{3, 4, 5, 1, 2}`.
+ `rotate(q, -2)` takes the floored `n = -2 % 5 = 3`, three rounds
  the other way: 3 to slot 8, 4 to slot 1, 5 to slot 2, head ends at
  5, and the array is `{1, 2, 3, 4, 5}` again.
+ `rotate(q, 5)` computes `n = 5 % 5 = 0` and runs no rounds at all,
  the pinned full turn that changes nothing.

#diagram([the cap 8 slots across the three rotations, live entries and the head, the values wrapping the seam], length: 12pt, {
  let ring(y, vals, lab, hi) = {
    for (i, t) in vals.enumerate() {
      cdraw.rect((0.8 + i * 1.25, y), (1.95 + i * 1.25, y + 1.0), fill: if t == [] { luma(250) } else { luma(238) }, radius: 0.02)
      if t != [] { cdraw.content((1.38 + i * 1.25, y + 0.5), t, size: 6.5pt) }
    }
    cdraw.content((1.38 + hi * 1.25, y + 1.75), [head], size: 6pt, fill: luma(100))
    cdraw.line((1.38 + hi * 1.25, y + 1.55), (1.38 + hi * 1.25, y + 1.05), stroke: luma(100), mark: (end: ">"))
    cdraw.content((12.2, y + 0.5), lab, size: 6pt, fill: luma(100), anchor: "west")
  }
  ring(4.8, ([], [], [3], [4], [5], [1], [2], []), [rotate 2: n = 2], 2)
  ring(2.6, ([4], [5], [], [], [], [1], [2], [3]), [rotate -2: n = 3], 5)
  ring(0.4, ([4], [5], [], [], [], [1], [2], [3]), [rotate 5: no rounds], 5)
})

The ring ends where it began, `{1, 2, 3, 4, 5}`, after two steps
left, two right, and a full turn, the three asserts in order.

#listing("icpc/samples-lua/ch07_deque.lua", first: 11, last: 33, caption: [lua: doubling growth with the copies counter, both pushes wrapping by modulo])

Both pops return `nil` on empty, Lua's refusal shape where C returns
0 through an out parameter, and rotation is defined once instead of
left to the caller: pop front, push back, `n % count` times, so
negative steps rotate right and a full turn changes nothing. The
rotate fixture walks `1 2 3 4 5` left two steps to `3 4 5 1 2`, back
right two, and around once, ending where it started. The emptying
slots are `nil`-ed rather than overwritten, which matters to Lua's
`#` and to any iteration that would otherwise see stale values.

#diagram([the wrapped four-ring that grows: six live entries land contiguous, the copies counter reading exactly 4], length: 12pt, {
  let slot(x, y, t, fill) = {
    cdraw.rect((x, y), (x + 1.7, y + 1.2), fill: fill, radius: 0.02)
    cdraw.content((x + 0.85, y + 0.6), t, size: 6.5pt)
  }
  cdraw.content((5.6, 5.0), [cap 4, wrapped], size: 6.5pt, fill: luma(100))
  slot(0.6, 3.2, [5], luma(210))
  slot(2.3, 3.2, [2], luma(238))
  slot(4.0, 3.2, [3], luma(238))
  slot(5.7, 3.2, [4], luma(238))
  cdraw.content((3.15, 2.2), [head], size: 6pt, fill: luma(100))
  cdraw.line((3.15, 2.5), (3.15, 3.2), stroke: luma(100), mark: (end: ">"))
  slot(9.2, 3.2, [2], luma(210))
  slot(10.9, 3.2, [3], luma(238))
  slot(12.6, 3.2, [4], luma(238))
  slot(14.3, 3.2, [5], luma(238))
  slot(16.0, 3.2, [6], luma(238))
  slot(17.7, 3.2, [7], luma(238))
  cdraw.content((13.4, 5.0), [after grow: cap 8, copies 4], size: 6.5pt, fill: luma(100))
  cdraw.line((8.2, 3.8), (9.2, 3.8), stroke: luma(100), mark: (end: ">"))
})

== the set, deterministic iteration

A set over a Lua table is membership by presence, `items[v] = true`,
with a count kept beside it, and the two interesting decisions are
both about honesty. `has` checks `items[v] == true` rather than
truthiness, because a set holding `false` stores `true` in its slot
and a naive lookup would report the member missing. And iteration is
sorted: Lua's `pairs` order is unspecified, so a set whose walk order
matters, and puzzle code almost always wants a reproducible walk,
collects the keys and sorts them by string form before yielding them.
Union and intersect are one pass each over the operands.

The dry run: the module's test `union and intersect on the fixture
sets` builds `a = {1, 2, 3, 4}` and `b = {3, 4, 5, 6}` and asserts
both results as sorted arrays and counts, four `T.eq` calls.

+ `Set.union` starts empty and adds `a`'s four keys, count 4.
+ `b`'s keys follow: 3 and 4 are members already and `add` skips
  them, 5 and 6 join, 4 + 2 = 6 members.
+ `Set.intersect` walks `a`'s four keys and keeps the ones `b` has:
  1 and 2 fail `has`, 3 and 4 pass, 2 kept.
+ `to_array` sorts by string form, so the asserts read
  `{1, 2, 3, 4, 5, 6}` with count 6 and `{3, 4}` with count 2.

#table(
  columns: (auto, auto, auto, auto, auto),
  inset: 4pt,
  table.header([*value*], [*in a*], [*in b*], [*union keeps*], [*intersect keeps*]),
  [1], [yes], [no], [yes, from a], [no],
  [2], [yes], [no], [yes, from a], [no],
  [3], [yes], [yes], [yes, from a], [yes],
  [4], [yes], [yes], [yes, from a], [yes],
  [5], [no], [yes], [yes, from b], [no],
  [6], [no], [yes], [yes, from b], [no],
)

All six values reach the union and only the shared 3 and 4 survive
the intersect, the counts 6 and 2 the last two asserts pin.

#listing("icpc/samples-lua/ch07_set.lua", first: 29, last: 59, caption: [lua: sorted each for a deterministic walk, union and intersect in one pass each])

The fixtures cover the arithmetic, `{1,2,3,4}` union `{3,4,5,6}` is
all six and the intersect is `3,4`, the disjoint intersect is empty
and union with empty is identity, and the boolean members test pins
the `== true` rule with `false` itself in the set. The C twin has no
set module at all: its map with ignored values is the set, and the
year chapters use whichever shape their language gave them.

#diagram([union and intersect of the two fixture sets, the two shared members in the middle], length: 12pt, {
  cdraw.circle((8.0, 3.0), radius: 3.2, stroke: luma(120), fill: luma(244))
  cdraw.circle((12.0, 3.0), radius: 3.2, stroke: luma(120), fill: luma(244))
  cdraw.content((6.2, 3.0), [1, 2], size: 6.5pt)
  cdraw.content((10.0, 3.0), [3, 4], size: 6.5pt)
  cdraw.content((13.8, 3.0), [5, 6], size: 6.5pt)
  cdraw.content((6.6, -0.9), [union: all six], size: 6.5pt, fill: luma(100))
  cdraw.content((13.4, -0.9), [intersect: 3, 4], size: 6.5pt, fill: luma(100))
})

== the grid

The grid module parses a list of row strings into one concatenated
string and keeps `rows` and `cols` beside it, the same row-major
flattening the C header performs on a byte buffer, and the same index
law, `r * cols + c`, zero-based, with bounds checks and the two delta
tables. The difference is what the neighbor walk returns: C counts
the in-bounds neighbors, Lua returns the in-bounds coordinate pairs
themselves in delta order, which is what a flood fill or a walk loop
consumes directly.

The dry run: the module's test `parse flattens row-major: at() reads
through the index math` parses `{"abc", "def"}` and asserts the
corners and the raw law itself with `T.eq(Grid.idx(g, 1, 2), 5)`.

+ `Grid.parse` concats the rows, `cells = "abcdef"`, with `rows = 2`
  and `cols = 3`.
+ `at(0, 0)` computes `idx = 0 x 3 + 0 = 0` and reads `sub(1, 1)`,
  the `a`.
+ `at(0, 2)` computes `0 x 3 + 2 = 2`, reads `sub(3, 3)`, the `c`;
  `at(1, 0)` computes `1 x 3 + 0 = 3`, reads the `d`.
+ `at(1, 2)` computes `1 x 3 + 2 = 5`, the assert that pins the law,
  and reads `sub(6, 6)`, the `f`.

#diagram([the two rows flatten to one string, every (r, c) landing at r x cols + c], length: 12pt, {
  let cell(x, y, t) = {
    cdraw.rect((x, y), (x + 1.5, y + 1.2), fill: luma(244), radius: 0.02)
    cdraw.content((x + 0.75, y + 0.6), t, size: 6.5pt)
  }
  cell(1.0, 4.6, [a])
  cell(2.6, 4.6, [b])
  cell(4.2, 4.6, [c])
  cell(1.0, 3.2, [d])
  cell(2.6, 3.2, [e])
  cell(4.2, 3.2, [f])
  cdraw.content((6.6, 4.4), [rows 2, cols 3], size: 6.5pt, fill: luma(100), anchor: "west")
  for (i, ch) in ([a], [b], [c], [d], [e], [f]).enumerate() {
    cdraw.rect((1.0 + i * 1.6, 1.0), (2.6 + i * 1.6, 2.0), fill: if i == 5 { luma(224) } else { luma(238) }, radius: 0.02)
    cdraw.content((1.8 + i * 1.6, 1.5), ch, size: 6.5pt)
    cdraw.content((1.8 + i * 1.6, 0.3), [#i], size: 6pt, fill: luma(100))
  }
  cdraw.line((4.95, 3.2), (9.6, 2.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.4, 3.6), [at(1, 2): idx 5], size: 6.5pt, fill: luma(100))
})

Every read lands on its pinned letter through the one law, the `f`
at `idx = 5` closing the walk.

#listing("icpc/samples-lua/ch07_grid.lua", first: 7, last: 42, caption: [lua: parse by concat, the index law, both delta tables, neighbors as coordinate pairs])

The delta orders are documented per language and they differ: both
toolboxes walk the 4-set as up, down, left, right, but the C 8-table
lists the four axis steps first and the diagonals after, while the
Lua 8-table goes around the cell row by row. Neither order is wrong,
each is pinned by its own tests, and the year chapters cite the order
they rely on instead of assuming one. The corner fixtures are
geometry: a 3 by 3 grid gives the center all eight, a corner three, a
1 by 1 grid none at all.

#diagram([the lua 8-neighbor order around a center cell, walked row by row, against the c axis-first order], length: 12pt, {
  let cell(x, y, t, fill) = {
    cdraw.rect((x, y), (x + 1.6, y + 1.6), fill: fill, radius: 0.02)
    cdraw.content((x + 0.8, y + 0.8), t, size: 6.5pt)
  }
  for c in range(3) {
    for r in range(3) {
      cell(0.8 + c * 1.8, 4.6 - r * 1.8, [], luma(244))
    }
  }
  cell(0.8, 4.6, [1], luma(228))
  cell(2.6, 4.6, [2], luma(228))
  cell(4.4, 4.6, [3], luma(228))
  cell(0.8, 2.8, [4], luma(228))
  cell(2.6, 2.8, [], luma(210))
  cell(4.4, 2.8, [5], luma(228))
  cell(0.8, 1.0, [6], luma(228))
  cell(2.6, 1.0, [7], luma(228))
  cell(4.4, 1.0, [8], luma(228))
  cdraw.content((8.0, 3.4), [lua: row by row, 1 through 8], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((8.0, 2.2), [c: axis steps, then diagonals], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((8.0, 1.0), [the shaded cell is (0, 0) here], size: 6.5pt, fill: luma(100), anchor: "west")
})

== string utilities, concat not squares

Four helpers cover what the puzzles keep doing to text. `split` walks
a literal separator with `find` in plain mode and keeps empty fields,
so `a,b,,c` splits to four strings with the hole preserved, the
behavior token-counting loops want. `trim` is one anchored `gsub`.
`mapchars` drives character substitution through a table, rot13 being
the fixture, and `build` is the idiom this section exists for:
assemble a parts table in the loop and `table.concat` once, because
every `..` in a loop body allocates a fresh string and a loop of
concatenations squares the byte count it moves.

The dry run: the module's test `split keeps empty fields and returns
the tail` walks `"a,b,,c"` with `find` in plain mode and pins the
walk with `T.eq(split("a,b,,c", ","), {"a", "b", "", "c"})`.

+ The cursor opens at `pos = 1`; the first comma sits at 2, the
  field is `sub(1, 1) = "a"`, and the cursor moves past it to 3.
+ The comma at 4 yields `sub(3, 3) = "b"`, cursor 5.
+ At 5 the next comma is immediate: the field is `sub(5, 4)`, an
  empty range, the kept hole, cursor 6.
+ `find` meets no comma from 6, so the tail `sub(6, 6) = "c"` is the
  fourth field and `split` returns.

#diagram([the cursor over a,b,,c: three commas, four fields, the adjacent pair at 4 and 5 leaving the hole], length: 12pt, {
  let ch(x, y, t, sep) = {
    cdraw.rect((x, y), (x + 1.2, y + 1.1), fill: if sep { luma(220) } else { luma(242) }, radius: 0.02)
    cdraw.content((x + 0.6, y + 0.55), t, size: 6.5pt)
  }
  let cs = (([a], false), ([,], true), ([b], false), ([,], true), ([,], true), ([c], false))
  for (i, p) in cs.enumerate() {
    ch(0.8 + i * 1.35, 4.0, p.first(), p.last())
    cdraw.content((1.4 + i * 1.35, 5.6), [#(i + 1)], size: 6pt, fill: luma(100))
  }
  let fields = (([a], [sub(1,1)]), ([b], [sub(3,3)]), ([], [sub(5,4)]), ([c], [sub(6,6)]))
  for (i, p) in fields.enumerate() {
    cdraw.rect((0.8 + i * 2.0, 1.4), (2.0 + i * 2.0, 2.5), fill: if i == 2 { luma(224) } else { luma(242) }, radius: 0.02)
    cdraw.content((1.4 + i * 2.0, 2.0), p.first(), size: 6.5pt)
    cdraw.content((1.4 + i * 2.0, 0.5), p.last(), size: 6pt, fill: luma(100))
  }
})

Three commas cut four fields, the hole sitting between the adjacent
pair, and the pinned table keeps all four.

#listing("icpc/samples-lua/ch07_strutil.lua", first: 7, last: 19, caption: [lua: split on a literal separator, empty fields kept, the tail returned])

#listing("icpc/samples-lua/ch07_strutil.lua", first: 22, last: 41, caption: [lua: trim by anchored gsub, table-driven char map, build through table.concat])

The fixtures pin all four: the split holes, a trim that never touches
interior whitespace, rot13 turning `Hello, World!` into `Uryyb,
Jbeyq!` with digits untouched, and `build` assembling `<1><2><3>` in
one concat. C has no equivalent module, its string.h idiom is
pointers and `strchr`, and the honest comparison is that Lua's string
helpers exist because Lua strings are immutable and every operation
returns a new one, so the toolbox teaches the allocation-conscious
pattern up front.

#diagram([two loops over four pieces: a dot in the loop body allocates four fresh strings, the parts table pays one concat], length: 12pt, {
  let box(x, y, w, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, size: 6pt)
  }
  cdraw.content((5.0, 5.4), [s = s .. piece, in the loop], size: 6.5pt, fill: luma(100))
  for i in range(4) {
    box(0.8 + i * 2.4, 3.8, 2.0, [#(i + 1)])
    if i < 3 { cdraw.line((2.8 + i * 2.4, 4.25), (3.2 + i * 2.4, 4.25), stroke: luma(140)) }
  }
  cdraw.content((12.6, 3.8), [4 allocations], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((5.0, 2.4), [`parts[#parts+1] = piece`, once at the end], size: 6.5pt, fill: luma(100))
  for i in range(4) {
    box(0.8 + i * 2.4, 0.8, 2.0, [#(i + 1)], fill: luma(245))
    if i < 3 { cdraw.line((2.8 + i * 2.4, 1.25), (3.2 + i * 2.4, 1.25), stroke: luma(140)) }
  }
  cdraw.content((12.6, 0.8), [1 concat], size: 6.5pt, fill: luma(100), anchor: "west")
})

== number theory, wrap stated then avoided

The number module opens by committing the crime it exists to prevent.
Its first test asserts `math.maxinteger * 2 == -2`, the wrap made
visible: the largest int64 doubled is minus two, two's complement
running off the end, and no error, no warning, nothing but a wrong
number. That single line is the whole argument for everything below
it. The mulmod is the same add-and-double the C chapter landed on,
doubling one operand with a reduction every step, arrived at from the
opposite direction: C could not link a 128-bit remainder, Lua cannot
trust a 64-bit product.

The dry run: the module's test `the wrap boundary stated, then
avoided` opens by asserting the wrap, `T.eq(math.maxinteger * 2, -2)`,
then pins the two anchors with `T.eq(mulmod(6000000000, 6000000000,
1000000007), 1764)` and `T.eq(modpow(2, 100, 1000000007),
976371285)`.

+ The wrap stated: `2^63 - 1` doubled runs off the int64 end and the
  machine reports `-2`, no error anywhere.
+ One reduction: `10^9 = 1000000007 - 7`, so `6 x 10^9` is congruent
  to `6 x (-7) = -42`, and `-42 + 1000000007 = 999999965`.
+ The product never forms: `(-42) x (-42) = 1764`, already under the
  modulus, the pinned mulmod answer.
+ Inside the loop every intermediate stays under one modulus plus
  itself, `1000000007 + 1000000007 = 2000000014`, far under the
  `2^62` wrap line.
+ `modpow(2, 100, 1000000007)` chains the same mulmod through its
  squarings and lands on the pinned 976371285.

#table(
  columns: (auto, 1.7fr, auto),
  inset: 4pt,
  table.header([*step*], [*line*], [*value*]),
  [wrap], [`(2^63 - 1) x 2`], [`-2`],
  [reduce], [`10^9 = 1000000007 - 7`, so `6 x 10^9 = 6 x (-7)`], [`-42`],
  [normalize], [`-42 + 1000000007`], [`999999965`],
  [square], [`(-42) x (-42)`, under the modulus], [`1764`],
  [pow], [`2^100 mod 1000000007`, pinned], [`976371285`],
)

The fold reads 1764 off a congruence and 976371285 off the pinned
power, both asserts satisfied without one wide product ever forming.

#listing("icpc/samples-lua/ch07_num.lua", first: 12, last: 32, caption: [lua: the doubling mulmod and modpow, a reduction after every add and every double])

The anchors match the C suite exactly, the values every language in
this book must agree on: `mulmod(6000000000, 6000000000,
1000000007)` is 1764 by the congruence a billion is minus seven, and
`modpow(2, 100, 1000000007)` is 976371285. The inverse guard returns
`nil` when the gcd is not one, Lua's refusal shape again, and the
crt merge is a closed form through a recursive extended euclid, where
the C twin scans residues linearly until one fits both congruences.
Different algorithms, same answers, and both accept a consistent
non-coprime pair, `1 mod 4` with `5 mod 6` resolving to `5 mod 12`,
while rejecting the contradiction.

#listing("icpc/samples-lua/ch07_num.lua", first: 48, last: 64, caption: [lua: pairwise merge by the extended-euclid closed form, crt folding the list])

#diagram([the wrap, stated as a number line: maxinteger doubled runs off the end and reappears at minus two], length: 12pt, {
  cdraw.line((1.0, 2.6), (18.2, 2.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.6, 2.3), (16.6, 2.9), stroke: luma(100))
  cdraw.content((16.6, 3.6), [maxinteger], size: 6.5pt, fill: luma(100))
  cdraw.content((16.6, 1.6), [2^63 - 1], size: 6.5pt, fill: luma(100))
  cdraw.content((18.2, 1.9), [wrap], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.line((1.4, 2.3), (1.4, 2.9), stroke: luma(100))
  cdraw.content((1.4, 1.6), [minus 2], size: 6.5pt, fill: luma(100))
  cdraw.content((2.6, 3.6), [the doubled value lands here], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.line((16.6, 4.4), (17.6, 4.4), stroke: luma(140))
  cdraw.line((17.6, 4.4), (17.6, 5.0), stroke: luma(140))
  cdraw.line((17.6, 5.0), (1.6, 5.0), stroke: luma(140))
  cdraw.line((1.6, 5.0), (1.6, 3.0), stroke: luma(140), mark: (end: ">"))
  cdraw.content((9.6, 5.5), [x2], size: 6.5pt, fill: luma(100))
})

== md5 on 64-bit integers

The md5 module is the RFC 1321 construction again, and the Lua
interest is arithmetic, not structure: Lua integers are 64-bit
signed, there is no uint32 to compute in, so every operation that
must land in 32 bits is masked back with `& 0xFFFFFFFF`, the rotate
included, `((x << n) | (x >> (32 - n))) & M32`. The complement in
the round functions is safe only because it is immediately
intersected with a 32-bit value: `~b` alone is 64 bits of mostly
ones, `~b & d` is back in range. The shift schedule is stored
compressed, sixteen entries, and indexed `i//16*4 + i%4 + 1`, where
the C header spells out all sixty-four.

The dry run: the module's test `md5 of the empty string, the rfc
vector` runs the whole construction on zero bytes and pins it with
`T.eq(md5(""), "d41d8cd98f00b204e9800998ecf8427e")`.

+ The message is empty, so `bitlen = 0 x 8 = 0` and padding begins
  with the single `0x80` byte, the table at 1 entry.
+ Zeros follow while `#bytes % 64 ~= 56`, which from 1 entry means
  56 - 1 = 55 zeros.
+ Eight little-endian length bytes of zero follow, 56 + 8 = 64, one
  chunk exactly.
+ The sixteen words are all zero except `M[0]`, which reads the
  `0x80` little-endian, the value 128.
+ The 64 rounds fold the accumulators with every add masked back to
  32 bits, and the four words print little-endian in a b c d order.

#diagram([the empty message's one chunk: one 0x80 byte, zeros to 56 mod 64, eight zero length bytes], length: 12pt, {
  let box(x, y, w, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, size: 6pt)
  }
  box(0.6, 3.2, 3.2, [0x80], fill: luma(224))
  box(4.4, 3.2, 7.4, [55 zeros])
  box(12.4, 3.2, 7.4, [8 length bytes, 0])
  cdraw.content((2.2, 4.9), [byte 0], size: 6pt, fill: luma(100))
  cdraw.content((8.1, 4.9), [bytes 1 to 55, to 56 mod 64], size: 6pt, fill: luma(100))
  cdraw.content((16.1, 4.9), [bytes 56 to 63, bitlen], size: 6pt, fill: luma(100))
  cdraw.content((0.6, 1.7), [M[0] reads the 0x80 as 128, words 1 to 15 are zero], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((0.6, 0.6), [digest d41d8cd98f00b204e9800998ecf8427e], size: 6.5pt, fill: luma(100), anchor: "west")
})

One chunk, one nonzero word, sixty-four masked rounds, and the digest
is the RFC's own `d41d8cd98f00b204e9800998ecf8427e`.

#listing("icpc/samples-lua/ch07_md5.lua", first: 36, last: 59, caption: [lua: pad to 56 mod 64, the bit length little-endian, sixteen words per chunk])

#listing("icpc/samples-lua/ch07_md5.lua", first: 61, last: 88, caption: [lua: the 64 rounds, every add masked back to 32 bits, the schedule indexed by round and step])

The pinned vectors are the RFC set and they match the C suite's
exactly, both languages reading one standard: the empty string, `a`,
`abc`, `message digest`, the alphabet, and the 80-digit input whose
padding crosses into a second block,
`57edf4a22be3c955ac49da2e2107b67a`. Determinism is checked with the
contest's own name in the input,
`md5("icpc world finals")` twice, and one extra letter separating
digests. Where the C chapter's suite pins ten checks, this one pins
five blocks, the same vectors with fewer intermediate assertions, and
that split is itself the honest comparison: the C tests assert each
vector separately where Lua's blocks group them.

#diagram([the sixteen-entry shift schedule against the four rounds: every round reuses the same four shifts], length: 12pt, {
  let box(x, y, w, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + w, y + 0.9), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.45), t, size: 6pt)
  }
  for (i, s) in ((0, [7]), (1, [12]), (2, [17]), (3, [22])) {
    box(0.8 + i * 3.4, 4.2, 2.8, s, fill: luma(228))
  }
  cdraw.content((7.6, 5.8), [the schedule, four shifts], size: 6.5pt, fill: luma(100))
  for r in range(4) {
    box(0.8, 2.4 - r * 1.1, 7.4, [rounds #(r * 16 + 1) to #(r * 16 + 16)], fill: luma(244))
  }
  cdraw.line((0.4, 4.2), (0.4, -0.4), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((11.0, 2.0), [`i//16` picks the round], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((11.0, 0.9), [`i%4` picks the shift], size: 6.5pt, fill: luma(100), anchor: "west")
})

== json to plain tables

The json decoder is where the two toolboxes diverge the most, because
the languages start from opposite places. C needs a node pool, tags,
and child arrays to hold a tree at all, 244 lines of it. Lua is
given tables, so the decoder walks the text once and returns plain
Lua tables directly, objects with string keys, arrays with
consecutive integers, and the whole `decode_value` is one function
whose arms are the grammar.

The dry run: the module's test `the numeric-leaf sum walks objects
and arrays alike` decodes `{"a": 1, "b": [2, 3.5, true]}` and pins
the total with `T.eq(JSON.sum_numbers(...), 6.5)`.

+ `decode` meets `{`, reads key `a`, and its value `1` converts
  through `tonumber` as an integer; key `b` opens the array
  `[2, 3.5, true]`, both pinned by the earlier `T.eq(v.a, 1)` and
  `T.eq(v.b, {2, 3.5, true})`.
+ The sum opens at 0; the object's pair `a` yields its leaf, total
  `0 + 1 = 1`.
+ The pair `b` walks the array: 2 makes `1 + 2 = 3`, 3.5 makes
  `3 + 3.5 = 6.5`, and `true` is not a number and adds nothing.
+ The nested fixture `[1, [2, [3, [4]]]]` folds the same way,
  `1 + 2 + 3 + 4 = 10`, a bare string sums to 0, and a bare 7 to 7.

#diagram([the decoded table, numeric leaves shaded, the walk adding 1 + 2 + 3.5 = 6.5 and skipping true], length: 12pt, {
  let box(x, y, w, t, fill: luma(244)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(7.2, 4.8, 4.8, [object, two pairs])
  cdraw.line((8.6, 4.8), (3.6, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.6, 4.8), (12.6, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.6, 4.4), [a], size: 6.5pt, fill: luma(100))
  cdraw.content((12.2, 4.4), [b], size: 6.5pt, fill: luma(100))
  box(2.2, 2.6, 2.8, [1], fill: luma(224))
  box(10.0, 2.6, 1.6, [2], fill: luma(224))
  box(11.8, 2.6, 2.0, [3.5], fill: luma(224))
  box(14.0, 2.6, 2.2, [true], fill: luma(248))
  cdraw.content((1.0, 1.0), [1 + 2 + 3.5 = 6.5, true adds 0], size: 6.5pt, fill: luma(100), anchor: "west")
})

The three numeric leaves total 6.5 and the walk returns it, the
pinned sum the year chapters keep calling for.

#listing("icpc/samples-lua/ch07_json.lua", first: 48, last: 99, caption: [lua: the whole value grammar in one function, objects, arrays, strings, literals, numbers])

Two decisions inside it carry the module. Null becomes a sentinel
table with a tostring of `null`, because a Lua field holding `nil`
does not exist, and a decoded `{"a": null}` must distinguish absent
from null, which the C tree gets for free from its explicit tags.
And numbers are matched with `^-?%d+%.?%d*` and converted with
`tonumber`, so `42` stays an integer and `3.5` a float, where C's
`strtod` makes every number a double. The escapes include `\uXXXX`,
decoded to two-byte UTF-8 inside the BMP, which the C twin does not
attempt, and an unknown escape raises by name, where C passes it
through verbatim.

#listing("icpc/samples-lua/ch07_json.lua", first: 101, last: 116, caption: [lua: the entry point refusing trailing garbage, and the numeric-leaf sum walk])

The fixtures pin the decode shapes, the escapes, the sentinel, the
integer-or-float distinction, five malformed inputs each refused by
name, and the sum walk that this book's year chapters keep calling:
`{"a": 1, "b": [2, 3.5, true]}` sums to 6.5, nested arrays to 10, a
bare string to 0. The C fixture sums to 2.5 with its own crafted
document, and the two suites agree on the method, walk every table,
add every number, ignore everything else, while pinning their own
mini-inputs, exactly the fixture policy chapter 1 states.

#diagram([the same grammar, two destinations: c parses into a tagged node pool, lua returns the tables the language already has], length: 12pt, {
  let box(x, y, w, t, fill: luma(238)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  box(7.0, 5.6, 6.0, [the json text])
  box(0.8, 3.4, 8.0, [c: node pool, tags], fill: luma(225))
  box(10.8, 3.4, 8.0, [lua: plain tables], fill: luma(225))
  cdraw.line((8.5, 5.6), (4.8, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.5, 5.6), (14.8, 4.4), stroke: luma(100), mark: (end: ">"))
  box(2.3, 1.4, 5.0, [244 lines], fill: luma(245))
  box(12.3, 1.4, 5.0, [167 lines], fill: luma(245))
  cdraw.line((4.8, 3.4), (4.8, 2.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.8, 3.4), (14.8, 2.4), stroke: luma(100), mark: (end: ">"))
})

== across the seven languages

The C chapter closes with the structure table from its side, and this
chapter closes with the same table from Lua's. The rows are the same
structures, the approaches are what the two chapters showed, and the
reasons are the machine facts each language lives under.

#table(
  columns: (1.2fr, 1.6fr, 1.6fr, 1.6fr),
  inset: 4pt,
  table.header([*structure*], [*c builds it as*], [*lua builds it as*], [*why they differ*]),
  [bigint], [sign-magnitude struct, 12 fixed limbs], [sign plus limb table, unbounded], [c pins the digit budget, lua lets tables grow],
  [map and set], [open addressing, fnv-1a, tombstones], [the table primitive, sorted walks], [c has no hash map, lua has nothing else],
  [min heap], [typed array of key-value pairs], [array plus injected comparator], [one c type order, any lua order],
  [deque], [ring with head index and count], [ring with head, count, copies], [the lua test reads the copy count directly],
  [grid], [pure index functions over a buffer], [parse to one string, neighbors as pairs], [same law, lua hands back coordinates],
  [strings], [pointers and strchr], [split, trim, concat idiom], [lua strings are immutable, allocation is visible],
  [modular num], [add-and-double, the link refused the wide product], [add-and-double, the wrap is proven first], [different diseases, same cure],
  [md5], [uint32 arithmetic], [int64 masked to 32 bits], [lua has no 32-bit integers to use],
  [json], [node pool with tags], [plain tables, null sentinel], [c needs the tree, lua is the tree],
)

Java's chapter 4 contributes the seam no row above carries: the jvm's
default stack dies at 22774 frames where `-Xss512m` holds 33506905, a
measured fact its judge invocation pins before any deep recursion
runs.

Verified by `make verify-lua`: 9 modules, 45 checks, bigint 7, heap
4, deque 4, set 5, grid 5, strutil 4, num 5, md5 5, json 6, on the
repo's vendored Lua 5.5.1 interpreter.

sources: R. Rivest, RFC 1321, The MD5 Message-Digest Algorithm, April
1992, the constants, schedule, and test vectors both this suite and
the C suite pin; the wrap behavior, the interpreter version, and the
per-module check counts are output from the suite run and the
vendored interpreter on this machine, 2026-09-14. The C comparisons
cite the landed `books/icpc/samples-c/src/Ch02/` headers read the
same day.
