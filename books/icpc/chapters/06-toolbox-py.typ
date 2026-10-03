#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the python toolbox

Python carries the lightest toolbox of the six languages, and that is
the point: the standard library already won. A priority queue is
`heapq`, a deque is `collections.deque`, memoization is one `@cache`
line, the combinatorial loops are `itertools`, the parsing is `re`, and
arbitrary-precision integers are not a library at all, they are the
int type, so `pow(2, 100, 1_000_000_007)` is a builtin call with no
boundary to respect. What this chapter builds is therefore not
containers, it is fluency: 274 non-blank lines of idiom checks over 6
files, 67 asserts, every pattern pinned to a fact, and every deeper
treatment cited to the python book rather than repeated here. The other
five toolboxes in this set exist because their languages made the
 contest jobs hard. This one exists to show what it looks like when
they are easy.

== queues, two import lines

The heap is not a class, it is a discipline over a plain list:
`heappush` maintains the invariant, `heap[0]` is always the minimum,
and `heappop` drains in order. `heapify` builds the invariant in one
in-place pass, `nlargest` answers top-k without ceremony, and the
a-star tie-breaker idiom rides along, a counter in the tuple keeps
equal priorities first-in-first-out because tuples compare left to
right.

The dry run: `queues.py` pushes 7, 2, 9, 4 and drains 2, 4, 7,
then feeds `heapify` the scattered list 8, 1, 6, 3 and checks the
root it leaves.

+ The four `heappush` calls leave `heap[0]` at 2, the file's
  first check, and three pops read 2, 4, 7 in order.
+ `heapify` sifts down from the last parent, index 1: its only
  child, the 3 at index 3, does not beat 1, no swap.
+ Index 0 holds 8 over children 1 and 6: the smaller, 1, swaps
  up, leaving `[1, 8, 6, 3]`.
+ The sift continues at index 1: the 3 at index 3 swaps up,
  leaving `[1, 3, 6, 8]`, and the check reads `scattered[0] == 1`.
+ `nlargest(2, ...)` over the 8-element fixture returns 9 and 6,
  the pinned top two.

#diagram([heapify's two sifts over 8, 1, 6, 3: the 1 rises, then the 3, the root ending at 1], length: 12pt, {
  let st(x, y, vals, lab) = {
    for (i, v) in vals.enumerate() {
      cdraw.rect((x + i * 1.15, y), (x + i * 1.15 + 1.05, y + 1.0), fill: if i == 0 { luma(225) } else { luma(240) }, radius: 0.02)
      cdraw.content((x + i * 1.15 + 0.52, y + 0.5), v, size: 6.5pt)
    }
    cdraw.content((x + 0.52, y - 0.9), lab, size: 6pt, fill: luma(100))
  }
  st(0.8, 4.6, ([8], [1], [6], [3]), [scattered])
  st(6.4, 4.6, ([1], [8], [6], [3]), [1 swaps up])
  st(12.0, 4.6, ([1], [3], [6], [8]), [3 swaps up])
  cdraw.line((5.2, 5.1), (6.4, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.8, 5.1), (12.0, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.8, 1.4), [the root ends at 1, the pinned check, and nlargest keeps 9 and 6], size: 6.5pt, fill: luma(100), anchor: "west")
})

Two swaps leave the root at 1 and the drain at 2, 4, 7, both
pinned, in the listings below.

#listing("icpc/samples-py/src/Ch06/queues.py", first: 16, last: 34, caption: [the heap discipline, top-k, and the counter tie-breaker])

The deque half is one constructor argument with a personality:
`maxlen` turns the deque into a sliding window that silently evicts
the far end, and `rotate` moves the whole contents with wraparound in
both directions, the operation the C\# and JavaScript chapters build by
hand:

#listing("icpc/samples-py/src/Ch06/queues.py", first: 36, last: 47, caption: [the maxlen window evicts silently, rotate wraps both ways])

The checks pin the exact behaviors: pushes of 7, 2, 9, 4 drain as 2,
4, 7, `nlargest(2)` over the fixture returns 9 and 6, a `maxlen=3`
window fed 1 through 5 keeps 3, 4, 5 and an `appendleft(2)` evicts
from the right back to 2, 3, 4, and `rotate(1)` on 1, 2, 3, 4 gives
4, 1, 2, 3. How these containers are implemented, and when a list is
the wrong answer, is the material of
#xref-to("python", "collections").

#diagram([the tie-breaker rides tuple comparison, the window forgets the far end], length: 13pt, {
  cdraw.content((5.6, 8.2), text(size: 6.5pt)[equal priorities, fifo anyway])
  let rows = ((5, 0, "a"), (5, 1, "b"), (5, 2, "c"))
  for (i, r) in rows.enumerate() {
    cdraw.rect((1.0, 6.7 - i * 0.95), (6.6, 7.6 - i * 0.95), fill: luma(235), radius: 0.02)
    cdraw.content((3.8, 7.15 - i * 0.95), text(size: 6pt)[(5, #(r.at(1)), #r.at(2))])
  }
  cdraw.content((9.6, 6.2), text(size: 6pt)[same priority])
  cdraw.content((9.6, 5.25), text(size: 6pt)[the tick decides])
  cdraw.content((5.6, 3.5), text(size: 6pt)[pops: a, then b, then c])
  cdraw.content((5.6, 2.6), text(size: 6pt)[no arbitrary order between equals])

  cdraw.content((18.4, 8.2), text(size: 6.5pt)[the maxlen window])
  let win = ("1", "2", "3", "4", "5")
  for (i, v) in win.enumerate() {
    let inside = i >= 2
    cdraw.rect((12.6 + i * 1.15, 6.1), (13.75 + i * 1.15, 7.0), fill: if inside { luma(225) } else { luma(245) }, radius: 0.02)
    if inside { cdraw.content((13.175 + i * 1.15, 6.55), text(size: 6pt)[#v]) }
  }
  cdraw.content((18.4, 5.2), text(size: 6pt)[fed 1 through 5, keeps 3, 4, 5])
  cdraw.content((18.4, 4.3), text(size: 6pt)[appendleft(2) evicts the 5])
  cdraw.content((18.4, 3.4), text(size: 6pt)[the window is 2, 3, 4])
  cdraw.content((18.4, 2.5), text(size: 6pt)[silent eviction, no error, no choice])
  cdraw.content((18.4, 1.6), text(size: 6pt)[the size cap is the whole contract])
})

== memoization, three ways

The naive recursion trap, measured: `fib(24)` is 46368 and costs
150049 calls, because the call tree recomputes every subproblem
exponentially often. The manual dict memo pays 47 calls for the same
answer, linear, and the pair of counters in the check file makes the
difference an assertion rather than an observation.

The dry run: `memo.py` runs both recursions on fib(24) and
asserts the call counters, 150049 against 47, then the sized
cache's evictions.

+ The naive recursion answers 46368 at 150049 calls, both pinned
  by the opening checks.
+ The manual version descends k - 1 first: 24 entries, k = 24
  down to 1, the base case returning under 2 without recursing.
+ Each entry from k = 2 through 24 also calls k - 2 once: 23 more
  entries, every one a table hit on return.
+ 24 + 23 = 47, the pinned count, for the same 46368.
+ After `cache_clear`, `fib_cached(10)` reads 55 from an empty
  cache, the reset check.

#diagram([the manual recursion: one left spine of 24 entries, 23 second calls hitting the table], length: 12pt, {
  for i in range(6) {
    let k = if i == 5 { 1 } else { 24 - i * 5 }
    cdraw.rect((0.8, 5.6 - i * 1.0), (2.6, 6.5 - i * 1.0), fill: luma(240), radius: 0.02)
    cdraw.content((1.7, 6.05 - i * 1.0), [#k], size: 6.5pt)
    if i < 5 {
      cdraw.line((1.7, 5.6 - i * 1.0), (1.7, 5.5 - i * 1.0), stroke: luma(100), mark: (end: ">"))
      cdraw.line((2.6, 6.05 - i * 1.0), (6.2, 6.05 - i * 1.0), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
    }
  }
  cdraw.content((1.7, 0.6), [k - 1 spine], size: 6pt, fill: luma(100))
  cdraw.rect((6.2, 1.2), (9.8, 6.5), fill: luma(235), radius: 0.02)
  cdraw.content((8.0, 6.1), [the table], size: 6.5pt)
  cdraw.content((8.0, 5.2), [every k - 2 call], size: 6pt, fill: luma(100))
  cdraw.content((8.0, 4.4), [returns as a hit], size: 6pt, fill: luma(100))
  cdraw.content((11.0, 5.6), [24 spine entries], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((11.0, 4.7), [23 second calls, k = 2 through 24], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((11.0, 3.8), [24 + 23 = 47], size: 6.5pt, fill: luma(100), anchor: "west")
})

The same 46368 for 47 calls instead of 150049, both counters
pinned, in the listings below.

#listing("icpc/samples-py/src/Ch06/memo.py", first: 15, last: 41, caption: [the trap and the manual dict, 150049 calls against 47])

`functools.cache` is the same memo as a decorator, with
`cache_info` reporting hits and `cache_clear` resetting it, and
`functools.lru_cache(maxsize=2)` is the sized variant whose eviction
order the checks trace call by call, 3, 4, 5 computed, 3 evicted and
recomputed, 5 still resident, 4 evicted too:

#listing("icpc/samples-py/src/Ch06/memo.py", first: 44, last: 67, caption: [cache and the sized variant, evictions traced])

Which wrapper to reach for, and how decorators compose the wrapping
at definition time, is the subject of #xref-to("python", "functions").
The dynamic-programming tables this idiom replaces, and when the table
beats the memo, belong to the algorithms side of the house.

#diagram([one answer, three call counts], length: 13pt, {
  cdraw.content((11.2, 8.0), text(size: 6.5pt)[fib(24), the price of each shape])
  cdraw.line((2.0, 1.4), (21.6, 1.4), stroke: luma(100))
  cdraw.rect((2.4, 1.4), (4.0, 7.2), fill: luma(100), radius: 0.0)
  cdraw.rect((5.0, 1.4), (5.25, 2.6), fill: luma(160), radius: 0.0)
  cdraw.rect((6.2, 1.4), (6.3, 1.9), fill: luma(205), radius: 0.0)
  cdraw.content((3.2, 7.75), text(size: 6pt)[naive])
  cdraw.content((3.2, 0.9), text(size: 6pt)[naive])
  cdraw.content((8.8, 0.9), text(size: 6pt)[dict])
  cdraw.content((14.0, 0.9), text(size: 6pt)[cache])
  cdraw.content((14.6, 4.5), text(size: 6pt)[naive pays 150049 calls, dict 47])
  cdraw.content((14.6, 3.6), text(size: 6pt)[same answer everywhere: 46368])
  cdraw.content((14.6, 2.7), text(size: 6pt)[lru_cache adds the eviction order])
  cdraw.content((14.6, 1.8), text(size: 6pt)[maxsize 2, traced in the checks])
})

== the combinator iterators

Every brute-force finals solution is one `itertools` call.
`product` enumerates independent slots, `permutations` cares about
order, `combinations` does not, and `pairwise` yields the adjacent
gaps that turn positions into differences.

The dry run: `iter.py` splits the records fixture through
`groupby` under the key `line != ""` and asserts the three
records.

+ `splitlines` yields 7 lines: alpha, beta, blank, gamma, blank,
  blank, delta.
+ The key turns them into true, true, false, true, false, false,
  true.
+ `groupby` cuts at every key change: five groups, the doubled
  blank collapsing into one false group of 2 lines rather than
  two.
+ The `if key` filter drops both false groups, leaving the pinned
  records, `alpha beta`, `gamma`, `delta`.
+ Over the words a, b, b, c, c, c the same cut counts runs 1, 2, 3
  by `len(list(grp))`.

#diagram([seven lines, five groups, three records: the false groups never survive the filter], length: 12pt, {
  let ln(x, t, key) = {
    cdraw.rect((x, 4.6), (x + 2.0, 5.6), fill: if key { luma(240) } else { luma(222) }, radius: 0.02)
    if t != [] { cdraw.content((x + 1.0, 5.35), t, size: 6pt) }
    cdraw.content((x + 1.0, 4.85), if key { [T] } else { [F] }, size: 6pt, fill: luma(100))
  }
  ln(0.6, [alpha], true)
  ln(2.75, [beta], true)
  ln(4.9, [], false)
  ln(7.05, [gamma], true)
  ln(9.2, [], false)
  ln(11.35, [], false)
  ln(13.5, [delta], true)
  cdraw.content((0.6, 5.9), [blank lines shaded, the key underneath], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((6.0, 3.4), [dropped], size: 6pt, fill: luma(100))
  let rec(x, w, t) = {
    cdraw.rect((x, 1.2), (x + w, 2.2), fill: luma(225), radius: 0.02)
    cdraw.content((x + w / 2, 1.7), t, size: 6pt)
  }
  cdraw.line((2.7, 4.6), (2.7, 2.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.15, 4.6), (8.15, 2.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.5, 4.6), (14.5, 2.2), stroke: luma(100), mark: (end: ">"))
  rec(0.6, 4.15, [alpha beta])
  rec(7.05, 2.2, [gamma])
  rec(13.5, 2.0, [delta])
  cdraw.content((0.6, 0.4), [the doubled blank is one false group, never an empty record], size: 6.5pt, fill: luma(100), anchor: "west")
})

Seven lines fold to three records, the doubled blank never an
empty group, in the listings below.

#listing("icpc/samples-py/src/Ch06/iter.py", first: 15, last: 38, caption: [product, permutations, combinations, pairwise, pinned exactly])

The other half of the module that carries puzzle loops is `groupby`,
which groups consecutive runs under a key. Over lines classified as
blank or not, it splits blank-line separated records, and over a list
of words it counts runs, the run-length idiom the JavaScript chapter
writes by hand:

#listing("icpc/samples-py/src/Ch06/iter.py", first: 40, last: 57, caption: [groupby cuts records and counts runs])

The checks are exhaustive on small cases: `product("ab", repeat=2)` is
the four tuples in order, a three-slot base-4 space is exactly 64,
`permutations("abc", 2)` lists all six, `combinations("abcd", 2)` lists
its six in lexicographic order, and the records fixture with doubled
blank lines splits as `alpha beta`, `gamma`, `delta`. Iteration
itself, generators, laziness, and the protocols under these functions,
is the long form of #xref-to("python", "collections").

#diagram([four product tuples and three groupby runs], length: 13pt, {
  cdraw.content((5.2, 8.6), text(size: 6.5pt)[product is the lattice])
  let cells = ((0, 0, "aa"), (1, 0, "ab"), (0, 1, "ba"), (1, 1, "bb"))
  for c in cells {
    cdraw.rect((2.6 + c.at(0) * 1.2, 6.3 - c.at(1) * 1.2), (3.8 + c.at(0) * 1.2, 7.5 - c.at(1) * 1.2), fill: luma(235), radius: 0.02)
    cdraw.content((3.2 + c.at(0) * 1.2, 6.9 - c.at(1) * 1.2), text(size: 6pt)[#c.at(2)])
  }
  cdraw.content((1.0, 6.9), text(size: 6pt)[b])
  cdraw.content((1.0, 5.7), text(size: 6pt)[a])
  cdraw.content((3.2, 7.8), text(size: 6pt)[a #h(0.6em) b])
  cdraw.content((5.2, 4.5), text(size: 6pt)[permutations: order matters, 6 of them])
  cdraw.content((5.2, 3.6), text(size: 6pt)[combinations: 6 more, sorted])
  cdraw.content((5.2, 2.7), text(size: 6pt)[pairwise: 1, 3, 6, 10 has gaps 2, 3, 4])

  cdraw.content((17.6, 8.0), text(size: 6.5pt)[groupby counts the runs])
  let runs = ((0, 1, "a"), (1, 2, "b"), (3, 3, "c"))
  for r in runs {
    cdraw.rect((12.2 + r.at(0) * 1.15, 6.2), (12.2 + (r.at(0) + r.at(1)) * 1.15, 7.1), fill: luma(225), radius: 0.02)
  }
  cdraw.content((12.78, 6.65), text(size: 6pt)[a])
  cdraw.content((14.5, 6.65), text(size: 6pt)[b b])
  cdraw.content((17.35, 6.65), text(size: 6pt)[c c c])
  cdraw.content((19.4, 5.3), text(size: 6pt)[runs: a 1, b 2, c 3])
  cdraw.content((19.4, 4.4), text(size: 6pt)[blank lines split the records])
  cdraw.content((19.4, 3.5), text(size: 6pt)[consecutive only, sort first if needed])
  cdraw.content((19.4, 2.6), text(size: 6pt)[the js chapter writes this loop by hand])
})

== numbers and line parsing

The number idioms are short because the language does the work.
`math.gcd` and `math.lcm`, variadic since they gained the multi-argument
form, `divmod` returning the floored pair, and the three-argument
`pow` that hashes square-and-multiply into C, with a negative exponent
computing the modular inverse and a non-unit raising `ValueError`
instead of guessing.

The dry run: `num.py` pins the gcd and lcm fixtures, then the
three-argument `pow` family and `divmod`, check by check.

+ `gcd(48, 18)` reads 6, and the variadic `lcm(2, 3, 4)` folds
  pairwise, `lcm(lcm(2, 3), 4) = lcm(6, 4) = 12`.
+ The anchor `pow(2, 100, 1_000_000_007)` is 976371285;
  `pow(3, -1, 7)` is 5, verified by the multiply back, 3 x 5 = 15
  and 15 - 14 = 1.
+ `pow(2, -1, 4)` raises `ValueError`, 2 and 4 share the factor
  2, and the try block turns the refusal into a passing check.
+ `divmod(17, 5)` returns (3, 2): 3 x 5 = 15 and 17 - 15 = 2, the
  floored quotient beside its remainder.
+ `int("1_000_000")` reads 1000000, `int("z", 36)` reads 35, and
  the spaces around 42 are forgiven.

#diagram([divmod(17, 5) on a number line: three hops of 5, then 2 left over], length: 12pt, {
  cdraw.line((1.0, 3.0), (19.0, 3.0), stroke: luma(100), mark: (end: ">"))
  for k in range(4) {
    cdraw.line((1.0 + k * 4.5, 2.7), (1.0 + k * 4.5, 3.3), stroke: luma(100))
    cdraw.content((1.0 + k * 4.5, 2.1), [#(k * 5)], size: 6pt, fill: luma(100))
  }
  cdraw.line((16.3, 2.7), (16.3, 3.3), stroke: luma(100))
  cdraw.content((16.3, 2.1), [17], size: 6pt, fill: luma(100))
  for k in range(3) {
    cdraw.line((1.9 + k * 4.5, 3.9), (5.6 + k * 4.5, 3.9), stroke: luma(120), mark: (end: ">"))
  }
  cdraw.line((14.5, 3.9), (16.3, 3.9), stroke: luma(120), mark: (end: ">"))
  cdraw.content((7.75, 4.5), [q = 3: 3 x 5 = 15], size: 6.5pt, fill: luma(100))
  cdraw.content((15.4, 4.5), [r = 2], size: 6.5pt, fill: luma(100))
  cdraw.content((1.0, 1.1), [pow(3, -1, 7) = 5, and 3 x 5 = 15 reads 1 mod 7], size: 6.5pt, fill: luma(100), anchor: "west")
  cdraw.content((1.0, 0.2), [pow(2, -1, 4) refuses, no inverse guessed], size: 6.5pt, fill: luma(100), anchor: "west")
})

The quotient 3 meets its remainder 2, and the inverse multiplies
back to 1, in the listings below.

#listing("icpc/samples-py/src/Ch06/num.py", first: 15, last: 27, caption: [gcd, lcm, three-argument pow with the inverse extension])

#listing("icpc/samples-py/src/Ch06/num.py", first: 29, last: 41, caption: [divmod is the floored pair, int parses with base and separators])

The anchors match the other five languages, `pow(2, 100, 1_000_000_007)`
is 976371285, and `pow(3, -1, 7)` is 5, verified in the next line by
multiplying it back to 1. Parsing rides the same theme: `int` takes an
explicit base from 2 to 36, accepts underscore separators, forgives
surrounding whitespace, and `re` handles the structured lines,
`fullmatch` pins the whole shape, capture groups split it, `findall`
returns the pairs, and a dict comprehension pivots them:

#listing("icpc/samples-py/src/Ch06/lines.py", first: 25, last: 45, caption: [fullmatch, findall pairs, the dict pivot])

The `Game 7` fixture line ends as the dict blue 3, red 4, green 1, and
the same pattern pivots `x=3 y=14 z=-2` in one expression. The regex
language behind this, and the classic quantifier traps, are chapter
material in #xref-to("python", "strings"), and the numerics module by
module is #xref-to("python", "numerics").

#diagram([one builtin, three exponents, and the floored pair], length: 13pt, {
  cdraw.content((11.2, 8.0), text(size: 6.5pt)[three argument pow dispatches])
  cdraw.rect((6.6, 5.45), (15.8, 6.95), fill: luma(235), radius: 0.02)
  cdraw.content((11.2, 6.55), text(size: 6pt)[pow(base, exp, mod)])
  cdraw.content((11.2, 5.9), text(size: 6pt)[mod positive])
  cdraw.line((8.0, 5.45), (3.9, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.2, 5.45), (11.2, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.4, 5.45), (19.0, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 3.0), (7.4, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((3.2, 4.15), text(size: 6pt)[exp >= 0])
  cdraw.content((3.2, 3.5), text(size: 6pt)[square and multiply])
  cdraw.rect((8.6, 3.0), (15.4, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.2, 4.15), text(size: 6pt)[exp = -1])
  cdraw.content((11.2, 3.5), text(size: 6pt)[the modular inverse])
  cdraw.rect((16.6, 3.0), (22.6, 4.6), fill: luma(245), radius: 0.02)
  cdraw.content((19.5, 4.15), text(size: 6pt)[non-unit])
  cdraw.content((19.5, 3.5), text(size: 6pt)[ValueError, no guess])
  cdraw.content((4.0, 5.3), text(size: 6pt)[976371285])
  cdraw.content((19.8, 5.9), text(size: 6pt)[pow(2, -1, 4) refuses])
  cdraw.content((11.2, 2.1), text(size: 6pt)[divmod(-7, 2) is (-4, 1), floored not truncated])
  cdraw.content((11.2, 1.2), text(size: 6pt)[int reads base 2 to 36, underscores, whitespace])
})

== digests and json leaves

The digest idioms are two lines each: `hashlib.md5(b"hello")` pins the
famous constant, the streaming shape calls `update` twice and lands on
the same digest as the one-shot call, and one flipped byte flips the
whole digest, the avalanche the mining puzzles rely on.

The dry run: `digest.py` pins the one-shot and streaming digests
of `b"hello"`, the flipped byte beside them, and the json leaf
sums over the nested fixtures.

+ One shot, `hashlib.md5(b"hello")` is
  `5d41402abc4b2a76b9719d911017c592`, with the empty-string and
  sha1 vectors pinned beside it.
+ The streaming shape calls `update(b"hel")` then `update(b"lo")`,
  3 + 2 = 5 bytes, and the hexdigest equals the one-shot,
  asserted.
+ The avalanche check flips one byte, `b"hellp"` against
  `b"hello"`, and the digests differ.
+ The walk folds the nested list `1, 2, 3, 4` to 10, the
  strings-and-nulls document to 0, and a bare 42 document is
  itself.

#diagram([the same five bytes by two shapes, one shot and streamed as hel then lo, one digest], length: 12pt, {
  let b(x, y, w, t, fill: luma(244)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, size: 6pt)
  }
  b(2.0, 6.0, 3.0, [b"hello"])
  b(9.4, 6.9, 1.7, [b"hel"])
  b(11.2, 6.9, 1.7, [b"lo"])
  cdraw.line((3.5, 6.0), (6.6, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.25, 6.9), (7.6, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.05, 6.9), (8.4, 5.4), stroke: luma(100), mark: (end: ">"))
  b(5.4, 4.0, 4.2, [hashlib.md5])
  cdraw.line((7.5, 4.0), (7.5, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((0.6, 2.3), [5d41402abc4b2a76b9719d911017c592], size: 6.5pt, fill: luma(100), anchor: "west")
  b(13.0, 4.0, 2.4, [b"hellp"], fill: luma(248))
  cdraw.line((13.6, 4.0), (11.0, 2.7), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((11.1, 2.3), [a different digest], size: 6pt, fill: luma(100), anchor: "west")
})

Both shapes land on the same
`5d41402abc4b2a76b9719d911017c592`, and the listings below hold
both halves.

#listing("icpc/samples-py/src/Ch06/digest.py", first: 16, last: 40, caption: [the vectors, the streaming shape, the avalanche])

The json half walks a parsed document and sums the numeric leaves at
any depth, the same walk the Go toolbox pins at 10.5, here over a
fixture whose leaves sum to 15, with the two traps handled out loud,
`bool` is an `int` subclass and must be skipped explicitly, and digits
inside strings count for nothing:

#listing("icpc/samples-py/src/Ch06/digest.py", first: 50, last: 69, caption: [the recursive walk, bool skipped, string digits ignored])

The checks pin all four shapes: the nested fixture sums to 15,
`[1, [2, [3, [4]]]]` sums to 10, a document of strings and nulls sums
to 0, and a bare number document is itself. Where the stdlib's larger
streaming and serialization machinery lives is
#xref-to("python", "plumbing").

#diagram([the leaves sum to 15, the boolean is not a number], length: 13pt, {
  cdraw.content((11.2, 8.2), text(size: 6.5pt)[one document, one sum])
  cdraw.rect((8.4, 6.1), (14.0, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.2, 7.15), text(size: 6pt)[the doc])
  cdraw.content((11.2, 6.5), text(size: 6pt)[json.loads])
  cdraw.rect((0.6, 4.15), (6.4, 5.75), fill: luma(205), radius: 0.02)
  cdraw.content((3.5, 5.35), text(size: 6pt)[a: 1, b.c: 2, b.d: 3, 4])
  cdraw.content((3.5, 4.65), text(size: 6pt)[four leaves inside])
  cdraw.rect((7.4, 4.15), (13.4, 5.75), fill: luma(205), radius: 0.02)
  cdraw.content((10.4, 5.35), text(size: 6pt)[e.f.g: 5])
  cdraw.content((10.4, 4.65), text(size: 6pt)[depth is free])
  cdraw.rect((14.4, 4.15), (21.4, 5.75), fill: luma(245), radius: 0.02)
  cdraw.content((17.9, 5.35), text(size: 6pt)[ignore: x7, flag, null])
  cdraw.content((17.9, 4.65), text(size: 6pt)[strings, bool, none: zero])
  cdraw.line((9.8, 6.1), (3.5, 5.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.2, 6.1), (10.4, 5.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.6, 6.1), (17.9, 5.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.2, 3.2), text(size: 6pt)[1 + 2 + 3 + 4 + 5 = 15, pinned])
  cdraw.content((11.2, 2.3), text(size: 6pt)[bool is an int subclass, skipped on purpose])
  cdraw.content((11.2, 1.4), text(size: 6pt)[go pins the same walk at 10.5 on its own fixture])
  cdraw.content((11.2, 0.5), text(size: 6pt)[md5(b"hello") is 5d41402a..., the famous constant])
})

== the lightest toolbox

The whole contract in one table. Six check files, 274 non-blank lines,
67 asserts, and nothing built that the standard library does not
already ship:

#table(
  columns: (1.7fr, 1.1fr, 1.8fr),
  inset: 4pt,
  table.header([*idiom*], [*status*], [*deep treatment*]),
  [queues, heapq and deque], [stdlib, `queues.py`], [9 checks, #xref-to("python", "collections")],
  [memoization], [stdlib, `memo.py`], [12 checks, #xref-to("python", "functions")],
  [combinator iterators], [stdlib, `iter.py`], [9 checks, #xref-to("python", "collections")],
  [numbers, pow, divmod], [stdlib, `num.py`], [16 checks, #xref-to("python", "numerics")],
  [line parsing, regex], [stdlib, `lines.py`], [12 checks, #xref-to("python", "strings")],
  [digests and json walks], [stdlib, `digest.py`], [9 checks, #xref-to("python", "plumbing")],
)

The counterparts in the other five toolboxes are the comparison:
chapters 2 through 5 hand-build heaps, deques, big integers, modular
arithmetic, and md5 because C, C\#, Go, and JavaScript made them
work, and chapter 7 adds a bigint and an md5 to Lua for the same
reason. Python imports its way past all of it.

sources: docs.python.org for `heapq`, `collections.deque`,
`functools.cache`, `itertools`, `math.gcd`, `re`, `hashlib`, and the
builtin `pow` and `int` entries, accessed 2026-09-14. Contest context
from the ICPC Foundation, icpc.global world finals problem pages,
accessed 2026-09-14. Sample behavior verified by
`tools/run-py-samples.ps1 -SampleRoot
books/icpc/samples-py/src`, 67 asserts across the 6 check files
(queues 9, memo 12, iter 9, num 16, lines 12, digest 9).
