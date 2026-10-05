#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= tries and suffix structures

Hash tables answer point queries. Tries answer queries about
structure: which keys share this prefix, how many, what stored key
matches the longest run of this input. The cost is per byte walked,
never a comparison between whole keys, and no hash can do any of it.

== the byte-wise trie

Each node is a map from one byte to the next node, and a key is the
path spelling its bytes. End markers turn shared paths into distinct
keys. Several of the six builds carry a subtree size on every node,
which is what makes count queries constant after the walk.

The dry run: the fixture is cat, car, cart, asserted by the C\#
suite, while C, JavaScript, and Lua build cat car cart dog done do
and walk the same queries.

+ Insert cat: root grows c, a, t, the end marker lands on t,
  count 1.
+ Insert car: the walk reuses c and a, extends one r, marker on r,
  count 2.
+ Insert cart: the walk reuses c, a, r and the marker already
  there, extends one t, count 3.
+ Contains walks without inserting: car and cart hit their
  markers, ca stops at a node holding no marker, carts runs past
  the last node.
+ Remove("car") clears the marker on r and keeps the node, cart's
  path still passes through: count 2, and a second Remove("car")
  returns false.
+ The size counters track the same story on ab, abc: SizeOfPrefix
  of a reads 2, and Remove(ab) drops it to 1.

#diagram([the three inserts as path frames, shared nodes reused and new nodes shaded, then the removal that keeps the path], length: 13pt, {
  // four frames: the path spelled per key, fresh nodes shaded, end markers dotted
  let frame = (y, label, letters, fresh, marked, cleared, count) => {
    cdraw.content((0.6, y), label, size: 6.5pt)
    for (i, ch) in letters.enumerate() {
      let x = 2.6 + i * 1.1
      cdraw.rect((x, y - 0.4), (x + 1.0, y + 0.4), fill: if i in fresh { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + 0.5, y), ch, size: 6.5pt)
      if i in marked { cdraw.circle((x + 0.5, y - 0.62), radius: 0.09, fill: luma(100)) }
      if i in cleared { cdraw.circle((x + 0.5, y - 0.62), radius: 0.09, stroke: luma(100)) }
    }
    cdraw.content((9.3, y), count, size: 6pt)
  }
  frame(7.3, [insert cat], ("c", "a", "t"), (0, 1, 2), (2,), (), [count 1])
  frame(5.9, [insert car], ("c", "a", "r"), (2,), (2,), (), [count 2])
  frame(4.5, [insert cart], ("c", "a", "r", "t"), (3,), (2, 3), (), [count 3])
  frame(3.1, [remove car], ("c", "a", "r", "t"), (), (3,), (2,), [count 2])
  cdraw.content((2.6, 1.9), [the marker clears, the node stays on cart's path], size: 6pt)
  cdraw.content((2.6, 1.1), [shared prefixes share nodes, one new node per step above], size: 6pt)
  cdraw.content((2.6, 0.3), [ab, abc: size(a) 2, remove ab drops it to 1], size: 6pt)
})

The count landing at 2 with cart intact is the pinned pair, and
the listings below build and unbuild the same paths.

#listing("dsa/samples-c/src/Ch09/trie.c", first: 40, last: 71, caption: [c, a 26-wide child array from a static pool, insert, walk, the three queries])

#listing("dsa/samples/src/Ch09/Tries.cs", first: 4, last: 54, caption: [c\#, insert, remove, contains, size-of-prefix, keys-with-prefix])

#listing("dsa/samples-go/ch09/trie.go", first: 23, last: 59, caption: [go, insert, search, starts-with, count by recursion])

#listing("dsa/samples-js/src/ch09-trie.mjs", first: 7, last: 46, caption: [javascript, insert with per-node counters, the walk, search and count])

#listing("dsa/samples-py/src/Ch09/trie.py", first: 26, last: 56, caption: [python, slotted nodes, idempotent insert, walk, the queries])

#listing("dsa/samples-lua/ch09_trie.lua", first: 9, last: 44, caption: [lua, one-character string keys, insert, walk, the queries])

#diagram([the byte-wise trie, shared prefixes share nodes, every node carries its subtree size], length: 13pt, {
  // keys car, cart, cat, dog: letter above, subtree size below, ends filled
  let node = (x, y, letter, size, end, half: 0.5) => {
    cdraw.rect((x - half, y - 0.55), (x + half, y + 0.55), fill: if end { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y + 0.18), letter, size: 7pt)
    cdraw.content((x, y - 0.3), [#size], size: 6pt)
  }
  let edges = (((2.2, 6.8), (2.2, 5.2)), ((2.2, 6.8), (6.8, 5.2)), ((2.2, 5.2), (2.2, 3.6)), ((2.2, 3.6), (1.2, 2.0)), ((2.2, 3.6), (3.4, 2.0)), ((1.2, 2.0), (1.2, 0.4)), ((6.8, 5.2), (6.8, 3.6)), ((6.8, 3.6), (6.8, 2.0)))
  for e in edges { cdraw.line(e.at(0), e.at(1), stroke: luma(220)) }
  node(2.2, 6.8, [root], 4, false, half: 0.9)
  node(2.2, 5.2, [c], 3, false)
  node(6.8, 5.2, [d], 1, false)
  node(2.2, 3.6, [a], 3, false)
  node(6.8, 3.6, [o], 1, false)
  node(1.2, 2.0, [r], 2, true)
  node(3.4, 2.0, [t], 1, true)
  node(6.8, 2.0, [g], 1, true)
  node(1.2, 0.4, [t], 1, true)

  cdraw.content((15.5, 6.8), [every node carries its subtree size], size: 6.5pt)
  cdraw.content((15.5, 5.6), [filled = end of a key], size: 6.5pt)
  cdraw.content((15.5, 4.4), [keys: car, cart, cat, dog], size: 6.5pt)
  cdraw.content((15.5, 3.2), [one node per shared prefix], size: 6.5pt)
})

Insertion walks or extends the path, then bumps the size counters
down that path, one line each way. `KeysWithPrefix` walks to the
prefix node and collects everything below it:

#listing("dsa/samples/src/Ch09/Tries.cs", first: 57, last: 124, caption: [c\#, longest matching prefix, the two walk contracts, size maintenance, sorted collect])

`LongestPrefixOf` is the router's question, the longest stored route
matching an address, answered by walking the query and remembering
the last end marker seen. The tests pin all the boundary behaviors:
removing `car` leaves `cart` intact, the empty key is legal, and
binary keys work byte for byte with no text encoding involved, which
matters because the capstone indexes arbitrary byte keys exactly this
way.

#callout("note", "one node per distinct prefix", [
  A trie of n keys of length L costs at most n times L nodes and
  usually far less when keys share prefixes. The cost of the whole
  family is memory shape: a node with 256 byte children as an array
  is fast and enormous, as a dictionary it is compact with one more
  indirection. The version here uses the dictionary form and the
  collect sorts children explicitly rather than trusting dictionary
  iteration order, a lesson from book 5's collection semantics.
])

== the prefix scan

The count says how many, the scan says which: enumerate every stored
key under a prefix, in lexicographic order, without sorting anything
after the fact. The walk descends to the prefix node, then emits
depth-first with children visited in ascending order, so the output
is sorted by construction and a word always precedes its own
extensions.

The dry run: the fixture is banana, band, bandana, bar, bee,
asserted by the C\# suite, while C, JavaScript, and Lua scan cat
car cart dog done do and Go pins app apple apron under ap.

+ Build the five keys; nothing is sorted anywhere yet.
+ The scan under ban walks root, b, a, n and lands on the ban
  node.
+ Below it the children split a, carrying banana, and d, carrying
  band and bandana, and a sorts first.
+ The depth-first walk emits banana off the a branch, then band
  and bandana off the d branch, a word before its own extension.
+ The output reads banana, band, bandana with no sort pass, the
  pinned order.
+ SizeOfPrefix reads cached counters on the same walk: ban 3, zz
  0, and b at 5, the whole vocabulary.

#diagram([the scan under ban, the walk to the prefix node, then the depth-first emission with the a branch ahead of d], length: 13pt, {
  // phase 1: the walk cells
  for (i, ch) in ("b", "a", "n").enumerate() {
    let x = 0.8 + i * 1.15
    cdraw.rect((x, 6.4), (x + 1.05, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.525, 6.8), ch, size: 6.5pt)
    if i < 2 { cdraw.line((x + 1.05, 6.8), (x + 1.15, 6.8), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((0.8, 5.7), [the walk lands on the ban node], size: 6pt)
  // phase 2: the two branches below ban
  cdraw.content((3.2, 4.6), [a branch: banana], size: 6pt)
  cdraw.content((7.8, 4.6), [d branch: two keys], size: 6pt)
  cdraw.line((3.9, 4.25), (3.9, 3.85), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.0, 4.25), (6.0, 3.85), stroke: luma(100), mark: (end: ">"))
  // phase 3: the emissions in walk order
  let out = (([banana], [a branch]), ([band], [d branch]), ([bandana], [d branch]))
  for (i, o) in out.enumerate() {
    let x = 0.8 + i * 3.4
    cdraw.rect((x, 2.7), (x + 3.1, 3.6), fill: if i == 0 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.55, 3.35), o.at(0), size: 6pt)
    cdraw.content((x + 1.55, 2.95), [#(i + 1)], size: 6pt)
    cdraw.content((x + 3.65, 3.15), o.at(1), size: 6pt)
  }
  cdraw.content((0.8, 2.0), [a word precedes its own extension, band before bandana], size: 6pt)
  cdraw.content((0.8, 1.2), [size(ban) 3, size(zz) 0, size(b) 5: counters, not walks], size: 6pt)
})

The banana, band, bandana order off scrambled input is the pinned
scan, and the listings below emit it without sorting anything.

#listing("dsa/samples-c/src/Ch09/prefixscan.c", first: 62, last: 85, caption: [c, depth-first emit over the a-to-z child array, scan walks to the prefix])

#listing("dsa/samples/src/Ch09/Tries.cs", first: 45, last: 54, caption: [c\#, keys-with-prefix walks then collects])

#listing("dsa/samples/src/Ch09/Tries.cs", first: 115, last: 123, caption: [c\#, the recursive collect, children sorted for the guarantee])

#listing("dsa/samples-go/ch09/prefixscan.go", first: 9, last: 31, caption: [go, the closure scan, edges sorted so map order cannot leak])

#listing("dsa/samples-js/src/ch09-prefixscan.mjs", first: 7, last: 17, caption: [javascript, the emit closure over sorted object keys])

#listing("dsa/samples-py/src/Ch09/prefixscan.py", first: 31, last: 46, caption: [python, walk, then descend with sorted children])

#listing("dsa/samples-lua/ch09_prefixscan.lua", first: 21, last: 44, caption: [lua, emit with a shared path buffer, sorted child keys])

Measured across the suites: C, JavaScript, and Lua scan a build
inserted as cat car cart dog done do and pin car cart cat under ca,
do dog done under do, and all six keys sorted under the empty prefix,
the insertion order deliberately scrambled against the output. Python
scans banana band bandana bin bard, ban yields banana band bandana,
and Go pins app apple apron under ap on its own fixture. The order is
structural everywhere: ascending children make the depth-first walk
lexicographic, and no suite calls a sort on its result.

#diagram([the prefix scan under ca, depth-first with children visited a to z emits car, cart, cat], length: 13pt, {
  // the subtree under the ca node, word ends shaded, emission numbered
  let node = (x, y, t, word, num) => {
    cdraw.rect((x - 0.42, y - 0.42), (x + 0.42, y + 0.42), fill: if word { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x, y), t, size: 6.5pt)
    if num != none { cdraw.content((x, y - 0.95), [#num], size: 6.5pt) }
  }
  cdraw.content((2.4, 7.5), [the ca node], size: 6.5pt)
  node(2.4, 6.4, [a], false, none)
  cdraw.line((2.4, 6.0), (4.2, 5.4), stroke: luma(140))
  cdraw.line((2.4, 6.0), (6.8, 5.4), stroke: luma(140))
  cdraw.line((4.2, 4.6), (5.2, 4.1), stroke: luma(140))
  node(4.2, 5.0, [r], true, [1])
  node(5.2, 3.7, [t], true, [2])
  node(6.8, 5.0, [t], true, [3])

  // the emission below the tree, already ordered
  let out = ([car], [cart], [cat])
  for (i, w) in out.enumerate() {
    cdraw.rect((2.6 + i * 1.6, 1.1), (2.6 + (i + 1) * 1.6 - 0.15, 1.9), fill: luma(235), radius: 0.02)
    cdraw.content((2.6 + i * 1.6 + 0.73, 1.5), w, size: 6pt)
  }
  cdraw.content((5.5, 0.3), [already lexicographic, no sort pass], size: 6pt)

  cdraw.content((15.0, 6.6), [children visit a to z], size: 6pt)
  cdraw.content((15.0, 5.6), [r sorts before t], size: 6pt)
  cdraw.content((15.0, 4.6), [a word precedes], size: 6pt)
  cdraw.content((15.0, 3.9), [its own extensions], size: 6pt)
  cdraw.content((15.0, 2.9), [the empty prefix], size: 6pt)
  cdraw.content((15.0, 2.2), [scans every key], size: 6pt)
})

== the suffix array

The complementary structure indexes one text's suffixes rather than
many keys. Sorting the start positions of all suffixes lexicographically
gives an array where any substring query becomes a range of adjacent
suffixes.

The dry run: the fixtures are banana, aaaa, abab, and mississippi,
asserted by all six suites on the same two arrays. The tie contract
runs the whole table on repeated characters, a before aa, and the
Kasai walk is checked against direct adjacent-pair comparison
everywhere.

+ The six suffixes by start: 0 banana, 1 anana, 2 nana, 3 ana,
  4 na, 5 a.
+ Sorted lexicographically the starts read 5, 3, 1, 0, 4, 2: a,
  ana, anana, banana, na, nana, the pinned array.
+ Kasai walks text order, not sorted order: at start 0, banana's
  sorted predecessor anana shares nothing, h = 0.
+ At start 1, anana meets its predecessor ana and the loop climbs
  a, n, a: h = 3, then h-- carries 2 forward.
+ At start 2 the carried 2 is already the whole answer against na,
  and at start 3 the carried 1 is the answer against a: no
  climbing, h-- each time.
+ At start 4, na meets banana, nothing shared, and start 5's
  suffix is first in the array with no predecessor.
+ The lcp lands 1, 3, 0, 0, 2 in sorted order, pinned, and the h
  walk 0, 3, 2, 1, 0 climbs once and only steps down.

#diagram([kasai's walk in text order, h climbing once to 3 then stepping down 2, 1, 0, each carried value already the answer], length: 13pt, {
  // five lanes: start, suffix, sorted predecessor, the h value
  let rows = (
    ([0], [banana], [anana], [0]),
    ([1], [anana], [ana], [3]),
    ([2], [nana], [na], [2]),
    ([3], [ana], [a], [1]),
    ([4], [na], [banana], [0]),
  )
  for (r, row) in rows.enumerate() {
    let y = 6.6 - r * 1.02
    cdraw.content((0.8, y), row.at(0), size: 6pt)
    cdraw.content((1.9, y), row.at(1), size: 6pt)
    cdraw.content((5.2, y), [vs], size: 6pt)
    cdraw.content((6.4, y), row.at(2), size: 6pt)
    cdraw.rect((9.6, y - 0.3), (10.4, y + 0.3), fill: if r > 0 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((10.0, y), row.at(3), size: 6pt)
    if r > 0 {
      cdraw.line((10.0, y + 0.36), (10.0, y + 0.66), stroke: (paint: luma(160), dash: "dashed"), mark: (end: ">"))
    }
  }
  cdraw.content((10.0, 7.4), [h], size: 6pt)
  cdraw.content((14.6, 5.6), [the only climb: a, n, a], size: 6pt)
  cdraw.content((14.6, 4.5), [after it, h-- per step], size: 6pt)
  cdraw.content((14.6, 3.4), [sorted-order lcp: 1 3 0 0 2], size: 6pt)
  cdraw.content((14.6, 2.3), [telescopes to linear], size: 6pt)
})

The 1, 3, 0, 0, 2 is the pinned array and the climb-then-step-down
is the reason it costs one pass, the listing below carries both.

#listing("dsa/samples/src/Ch09/Tries.cs", first: 127, last: 170, caption: [c\#, suffix array by sorted indices, kasai lcp])

The other five languages build the same two arrays:

#listing("dsa/samples-c/src/Ch09/suffixarray.c", first: 23, last: 67, caption: [c, the length-aware suffix comparator, the sorted array, kasai])

#listing("dsa/samples-go/ch09/suffixarray.go", first: 23, last: 70, caption: [go, index sort by full suffix order, kasai's walk])

#listing("dsa/samples-js/src/ch09-suffixarray.mjs", first: 5, last: 44, caption: [javascript, code-unit suffix compare, the sorted array, kasai])

#listing("dsa/samples-py/src/Ch09/suffixarray.py", first: 14, last: 55, caption: [python, the suffix key sort, kasai, and the fixture checks])

#listing("dsa/samples-lua/ch09_suffixarray.lua", first: 7, last: 49, caption: [lua, byte-wise suffix order, the array, kasai over 0-based starts])

Measured across the suites: banana lands 5, 3, 1, 0, 4, 2 with lcp
1, 3, 0, 0, 2 in all six languages. The five new trees also pin aaaa
at 3, 2, 1, 0 with lcp 1, 2, 3 plus the abab and mississippi tables,
and every tree recomputes each adjacent-pair lcp by direct character
comparison and asserts it equals Kasai's output, the h-1 invariant on
trial. The comparators compare characters to the end and then
length, so on repeated characters the shorter suffix with an equal
prefix sorts first.

Every build here sorts indices with full suffix comparison, honest
about its worst case, quadratic comparisons, right for teaching
sizes, while production builds use prefix doubling or SA-IS for
linear time. Kasai's LCP is the beautiful part: when moving from one
suffix to its neighbor in text order, the shared prefix with the
previous sorted neighbor can only shrink by one character, so the
total work telescopes to linear. The suites brute-force every
adjacent pair and check the whole array.

#diagram([the suffix array of banana, start positions in sorted order, adjacent lcp values from kasai's walk], length: 13pt, {
  // the text, one cell per character, index under each
  let text = ("b", "a", "n", "a", "n", "a")
  for (i, ch) in text.enumerate() {
    cdraw.rect((0.6 + i * 1.0, 6.5), (0.6 + (i + 1) * 1.0, 8.1), fill: luma(235), radius: 0.02)
    cdraw.content((0.6 + i * 1.0 + 0.5, 7.75), ch, size: 7pt)
    cdraw.content((0.6 + i * 1.0 + 0.5, 6.85), [#i], size: 6pt)
  }
  cdraw.content((14.5, 7.3), [suffix = text from that start], size: 6.5pt)

  // the sorted starts, prefix-aligned, with the lcp against the row above
  let rows = (("a", 5, none), ("ana", 3, 1), ("anana", 1, 3), ("banana", 0, 0), ("na", 4, 0), ("nana", 2, 2))
  cdraw.content((1.0, 5.95), [sorted suffixes], size: 6pt)
  cdraw.content((5.4, 5.95), [pos], size: 6pt)
  cdraw.content((7.3, 5.95), [lcp], size: 6pt)
  for (r, row) in rows.enumerate() {
    let (suf, pos, lcp) = row
    let y = 4.9 - r * 1.05
    cdraw.content((1.0 + suf.len() * 0.2, y), suf, size: 6pt)
    cdraw.content((5.4, y), [#pos], size: 6pt)
    if lcp != none { cdraw.content((7.3, y), [#lcp], size: 6pt) }
  }

  cdraw.content((14.3, 5.35), [moving in text order, the lcp], size: 6pt)
  cdraw.content((14.3, 4.25), [drops by at most one per step,], size: 6pt)
  cdraw.content((14.3, 3.15), [so the total telescopes linear], size: 6pt)
})

== substring search by binary search

With the suffix array, finding a pattern is two binary searches over
suffixes. This version uses one lower bound plus a scan, bounded by
the run of suffixes that start with the pattern.

The dry run: the fixtures are ana, the whole word, nab, and the
empty pattern over banana, aa over aaaa, and the, th, xyz over the
long text, asserted by all six suites. Hits come out in suffix order
everywhere, never ascending position, and the hit set is checked
against a naive contains scan.

+ The lower bound halves 0..6: mid 3 holds banana, not less than
  ana, mid 1 holds ana itself, mid 0 holds a, less.
+ Three probes land lo at row 1, the first suffix that does not
  sort before ana.
+ The scan walks the run: ana at start 3 matches, anana at start 1
  matches, banana diverges on the first character and stops it.
+ The occurrences read 3 then 1, ordered 1 3, pinned.
+ banana lands its own row exactly at 0, and nab slides between na
  and nana to an empty run, no hits.
+ The empty pattern prefixes every suffix and collects all six
  starts, 0 through 5.

#diagram([pattern ana end to end, three probes of the lower bound, the run of two suffixes, the starts collected], length: 13pt, {
  // phase 1: the probes with their interval verdicts
  let probes = (([mid 3: banana], [hi = 3]), ([mid 1: ana], [hi = 1]), ([mid 0: a < ana], [lo = 1]))
  for (i, pr) in probes.enumerate() {
    let y = 6.9 - i * 0.8
    cdraw.content((0.8, y), pr.at(0), size: 6pt)
    cdraw.content((6.8, y), pr.at(1), size: 6pt)
  }
  cdraw.content((0.8, 4.2), [row 1 is the run start], size: 6pt)
  // phase 2: the run, matching rows shaded
  let rows = (([ana], [start 3], true), ([anana], [start 1], true), ([banana], [start 0], false))
  for (r, row) in rows.enumerate() {
    let y = 3.1 - r * 0.78
    if row.at(2) { cdraw.rect((0.7, y - 0.3), (6.0, y + 0.3), fill: luma(205), radius: 0.02) }
    cdraw.content((1.0, y), row.at(0), size: 6pt)
    cdraw.content((4.6, y), row.at(1), size: 6pt)
  }
  // phase 3: the collected starts
  cdraw.content((8.8, 3.1), [scan collects 3 then 1], size: 6pt)
  cdraw.content((8.8, 2.2), [ordered: 1 3, pinned], size: 6pt)
  cdraw.content((8.8, 1.3), [banana: its own row at 0], size: 6pt)
  cdraw.content((8.8, 0.4), [empty pattern: all six starts], size: 6pt)
})

The 1 3 for ana is the pinned find, and the listing below runs the
same two phases on the longer text against IndexOf.

#listing("dsa/samples/src/Ch09/Tries.cs", first: 171, last: 201, caption: [c\#, lower bound over suffixes, then the prefix-matching run])

The other five languages run the same two phases:

#listing("dsa/samples-c/src/Ch09/suffixsearch.c", first: 41, last: 76, caption: [c, the bounded suffix compare, the lower bound, the run])

#listing("dsa/samples-go/ch09/suffixsearch.go", first: 3, last: 54, caption: [go, suffix versus pattern, the lower bound, the prefix run])

#listing("dsa/samples-js/src/ch09-suffixsearch.mjs", first: 5, last: 34, caption: [javascript, the suffix compare, the lower bound, the run scan])

#listing("dsa/samples-py/src/Ch09/suffixsearch.py", first: 18, last: 44, caption: [python, the lower bound and run over slice compares, fixtures pinned])

#listing("dsa/samples-lua/ch09_suffixsearch.lua", first: 22, last: 47, caption: [lua, suffix less than pattern, the lower bound, the run])

Each probe compares the pattern against a suffix, so a search costs
pattern length times log of text length. Measured across the suites:
ana emits 3 then 1 for the pinned suffix order and the empty pattern
returns the whole array in all six languages, and the five new trees
also pin aaaa's double a at 2, 1, 0 and the long text's 41-entry
array with the runs for the and th in suffix order. Every tree checks
the hit set against a naive scan, IndexOf in C\#, while the emission
order stays suffix order, and the degenerate empty pattern, which
prefixes every suffix, is legal input everywhere.

#diagram([substring search as a lower bound over the sorted suffixes, the run that starts with the pattern], length: 13pt, {
  // pattern an over banana: three probes, then the prefix-matching run
  cdraw.content((7.0, 7.55), [pattern: an], size: 6.5pt)
  let rows = (("a", 5, false), ("ana", 3, true), ("anana", 1, true), ("banana", 0, false), ("na", 4, false), ("nana", 2, false))
  for (r, row) in rows.enumerate() {
    let (suf, pos, hit) = row
    let y = 6.5 - r * 1.05
    if hit { cdraw.rect((6.3, y - 0.45), (11.4, y + 0.45), fill: luma(205), radius: 0.02) }
    cdraw.content((7.0 + suf.len() * 0.2, y), suf, size: 6pt)
    cdraw.content((10.4, y), [#pos], size: 6pt)
  }

  // the probes of the lower bound, aligned with the row each one compared
  cdraw.content((3.4, 6.5), [0: a < an, lo = 1], size: 6pt)
  cdraw.content((3.4, 5.45), [1: ana >= an], size: 6pt)
  cdraw.content((3.4, 4.4), [2: anana >= an], size: 6pt)

  cdraw.content((15.5, 5.45), [lower bound lands on], size: 6pt)
  cdraw.content((15.5, 4.4), [the run start], size: 6pt)
  cdraw.content((15.5, 2.3), [the scan walks the run], size: 6pt)
  cdraw.content((15.5, 1.0), [cost |p| log |t|], size: 6pt)
})

What each structure buys: the trie for many keys and prefix
questions, the suffix array for one long text and substring
questions. Databases build b-tree range indexes, routers build
tries, search engines and genome tools live in suffix arrays, and
the capstone's prefix scans ride the trie in this listing.

== across the six languages

The build sizes count non-comment source lines over this chapter's
four featured files per language. Every child map here is the
language's own table type, no trie shipped from anyone's stdlib:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [395], [libc only], [26-wide child arrays from a 64-node static pool, lower-case words, checks share the file with main, 45 of them],
  [c\#], [165], [bcl only], [byte-wise Dictionary children, remove supported, subtree sizes, the suffix array rides the same file, 11 tests],
  [go], [183], [slices for sorting], [map of byte to node, counts by recursion, duplicate inserts ignored by Len, 13 tests],
  [javascript], [108], [node stdlib], [object-as-map children with per-node counters, a duplicate insert counts again, 17 tests],
  [python], [222], [stdlib only], [slotted nodes, dict children, the insert climbs the spine only on first store, 62 checks],
  [lua], [338], [lib.lua harness], [table children keyed by one-character strings, a duplicate insert counts again, 20 checks],
)

sources: learn.microsoft.com, `Dictionary<TKey,TValue>` iteration
semantics, `MemoryExtensions.SequenceCompareTo` and `StartsWith`
span pages, accessed 2026-09-08, plus the kasai and suffix array
literature cited in the chapter text. Sample behavior verified by
`make verify-csharp`, 11 tests in chapter 9 of the samples suite.
The six-language layer verifies the same way: 4 C programs with 45
embedded checks under `make verify-c`, 13 Go tests, 17 `node --test`
cases, 62 Python checks across 4 files, and 20 Lua checks under
`run.lua`.
