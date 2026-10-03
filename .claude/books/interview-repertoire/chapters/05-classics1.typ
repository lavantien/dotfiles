#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= classics part 1: warmup, arrays, hashing

The warmup classics are table stakes: solve them clean, narrate the
cost, and bank the time for the harder rounds. Every problem here
exists in Go and in C\#, tests first, one problem per file, under
`make verify`.

== the string reverser and the palindrome [TDD]

The reverser's whole trick is runes versus bytes. Reversing a byte
slice splits multi byte characters, reversing code points does not,
and the test feeds `héllo` through to prove the difference:

#listing("interview-repertoire/samples/ch05-go/strings.go", first: 3, last: 29, caption: [rune-wise reverse, then the outside-in palindrome with cleaning])

#diagram([runes are code points: the pair stays whole, the bytes do not], length: 13pt, {
  // the same input reversed two ways, once per rune, once per byte
  let cells(x, y, items, broken: false) = {
    for i in range(items.len()) {
      let f = if broken and (i == 3 or i == 4) { luma(205) } else { luma(235) }
      cdraw.rect((x + i * 1.15, y), (x + i * 1.15 + 1.15, y + 1.0), fill: f, radius: 0.02)
      cdraw.content((x + i * 1.15 + 0.575, y + 0.5), items.at(i), size: 6.5pt)
    }
  }
  cdraw.content((2.4, 6.4), [input], size: 6pt)
  cells(4.5, 6.0, ("h", "é", "l", "l", "o"))
  cdraw.content((0.8, 4.5), [reverse bytes], size: 6pt)
  cells(4.5, 4.1, ("o", "l", "l", "¿", "¿", "h"), broken: true)
  cdraw.content((19.5, 4.6), [the two byte halves of é], size: 6pt)
  cdraw.content((19.5, 3.5), [land apart, undecodable], size: 6pt)
  cdraw.content((1.0, 2.2), [reverse runes], size: 6pt)
  cells(4.5, 1.8, ("o", "l", "l", "é", "h"))
  cdraw.content((19.5, 2.3), [é travels as one unit], size: 6pt)
  cdraw.content((19.5, 1.2), [and stays readable], size: 6pt)
})

The palindrome is the two-pointer pattern with a cleaning twist:
skip non-alphanumerics in place, compare lowercased pairs, never
allocate a filtered copy. The `0P` case in the table is the one
that catches solutions that compare letters only.

== primes, by trial and by sieve [TDD]

Trial division to the square root with evens skipped is the answer
for one number. The sieve is the answer for all of them, and the
suite cross-checks the two implementations under 1000 so neither
can drift:

#listing("interview-repertoire/samples/ch05-go/primes.go", first: 20, last: 42, caption: [the sieve marks composites and keeps the unmarked])

#diagram([each prime starts crossing at p times p, the smaller multiples are gone], length: 13pt, {
  // the strip 2..16: light strokes crossed by 2, dark strokes first crossed by 3
  let nums = range(2, 17)
  for i in range(nums.len()) {
    let v = nums.at(i)
    let x = 2.2 + i * 1.35
    cdraw.content((x, 4.6), str(v), size: 6pt)
    if calc.rem(v, 2) == 0 and v > 2 {
      cdraw.line((x - 0.25, 5.35), (x + 0.25, 5.75), stroke: luma(170))
    }
    if v == 9 or v == 15 {
      cdraw.line((x - 0.25, 5.35), (x + 0.25, 5.75), stroke: luma(40))
    }
    if v == 2 or v == 3 {
      cdraw.circle((x, 4.6), radius: 0.3, stroke: luma(120))
      cdraw.content((x, 4.6), str(v), size: 6pt)
    }
  }
  cdraw.line((1.6, 4.0), (23.3, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.6, 2.9), [3 starts at 9 = 3 × 3], size: 6pt)
  cdraw.content((5.6, 1.8), [6 and 12 already gone], size: 6pt)
  cdraw.content((17.0, 2.9), [the sieve: n log log n], size: 6pt)
  cdraw.content((17.0, 1.8), [trial division: sqrt each], size: 6pt)
})

The line worth narrating: marking starts at `p * p`, because every
smaller multiple of p already got marked by a smaller prime.

== permutations, generated and detected [TDD]

Heap's algorithm generates every ordering with one swap per step,
no ordering ever rebuilt from scratch, and the count test demands
exactly factorial many distinct outputs, empty input included:

#listing("interview-repertoire/samples/ch05-go/perm.go", first: 5, last: 24, caption: [heap's algorithm, single-swap generation])

#diagram([one swap per step, factorial many orderings, nothing rebuilt], length: 13pt, {
  // four states of heap's walk over three letters, each edge is one swap
  let state(x, letters) = {
    for i in range(3) {
      cdraw.rect((x + i * 0.85, 4.2), (x + i * 0.85 + 0.85, 5.2), fill: luma(235), radius: 0.02)
      cdraw.content((x + i * 0.85 + 0.425, 4.7), letters.at(i), size: 6.5pt)
    }
  }
  let xs = (1.0, 6.8, 12.6, 18.4)
  state(xs.at(0), ("a", "b", "c"))
  state(xs.at(1), ("b", "a", "c"))
  state(xs.at(2), ("c", "a", "b"))
  state(xs.at(3), ("a", "c", "b"))
  let swap(x, t) = {
    cdraw.line((x, 4.7), (x + 2.45, 4.7), stroke: luma(100), mark: (end: ">"))
    cdraw.content((x + 1.2, 5.5), t, size: 6pt)
  }
  swap(3.55, [swap 0, 1])
  swap(9.35, [swap 0, 2])
  swap(15.15, [swap 0, 1])
  cdraw.content((12.7, 2.9), [three letters, six orderings], size: 6pt)
  cdraw.content((12.7, 1.8), [every step one swap, none rebuilt from scratch], size: 6pt)
})

The anagram question is the detection half, rune counting in one
map, early exit the moment a count goes negative.

== linked list operations [TDD]

Reverse, middle, cycle detection: three two-pointer dances over the
same node type. The tortoise and hare cycle test builds an actual
loop, `1 -> 2 -> 3 -> 2`, plus a self-loop single node, the two
shapes a misspelled check survives by accident:

#listing("interview-repertoire/samples/ch05-go/listops.go", first: 39, last: 66, caption: [middle by 1x and 2x pointers, floyd cycle detection])

#diagram([three two-pointer dances over one node type], length: 13pt, {
  // reverse: cur rewires onto prev; middle: slow and fast; cycle: the lap
  let ball(x, y, t) = {
    cdraw.circle((x, y), radius: 0.3, fill: luma(235), stroke: luma(120))
    cdraw.content((x, y), [#t], size: 6pt)
  }
  // panel 1: reverse
  cdraw.content((4.0, 7.4), [reverse], size: 6.5pt)
  ball(1.6, 6.3, "a"); ball(4.0, 6.3, "b"); ball(6.4, 6.3, "c")
  cdraw.line((1.9, 6.0), (3.7, 6.0), (3.7, 5.7), stroke: luma(60), mark: (end: ">"))
  cdraw.content((1.6, 5.2), [prev], size: 6pt)
  cdraw.content((4.0, 5.2), [cur], size: 6pt)
  cdraw.line((4.0, 5.6), (4.0, 6.0), stroke: luma(160))
  // panel 2: middle of four, second middle wins
  cdraw.content((12.8, 7.4), [middle], size: 6.5pt)
  for i in range(4) { ball(9.6 + i * 2.1, 6.3, str(i + 1)) }
  cdraw.line((10.0, 6.3), (11.4, 6.3), stroke: luma(120))
  cdraw.line((12.1, 6.3), (13.5, 6.3), stroke: luma(120))
  cdraw.line((14.2, 6.3), (15.6, 6.3), stroke: luma(120))
  cdraw.content((13.8, 5.2), [slow], size: 6pt)
  cdraw.content((16.0, 5.2), [fast], size: 6pt)
  cdraw.line((13.8, 5.6), (13.8, 6.0), stroke: luma(160))
  cdraw.line((16.0, 5.6), (16.0, 6.0), stroke: luma(160))
  // panel 3: the loop 1 -> 2 -> 3 -> 2
  cdraw.content((21.0, 7.4), [cycle], size: 6.5pt)
  ball(19.4, 6.3, "1"); ball(21.6, 6.3, "2"); ball(23.0, 5.0, "3")
  cdraw.line((19.7, 6.3), (21.3, 6.3), stroke: luma(120), mark: (end: ">"))
  cdraw.line((21.8, 6.0), (22.8, 5.3), stroke: luma(120), mark: (end: ">"))
  cdraw.line((22.7, 4.75), (21.8, 5.9), stroke: luma(120), mark: (end: ">"))
  cdraw.content((20.6, 4.1), [tortoise at 1], size: 6pt)
  cdraw.content((20.6, 3.0), [meeting = loop], size: 6pt)
  cdraw.content((8.5, 3.0), [even length: fast's last hop], size: 6pt)
  cdraw.content((8.5, 1.9), [lands on the second middle], size: 6pt)
})

The `Middle` contract to state unprompted: for even lengths it
returns the second middle, because the fast pointer's last hop
lands there.

== two sum, both ways [TDD]

The hash map answer is one pass: each number asks whether its
complement already passed by, and the second operand of any pair is
always seen before the pair completes. The sorted-input follow-up
is two pointers walking inward:

#listing("interview-repertoire/samples/ch05-go/twosum.go", first: 5, last: 32, caption: [one pass with a map, then the two-pointer walk])

#flow([sorted input walks two pointers inward, otherwise the complement map in one pass],
  node((0, 0), [a two sum input]),
  node((2.6, 1.2), [sorted]),
  node((2.6, -1.2), [unsorted]),
  node((5.6, 1.2), [two pointers,#linebreak()walk inward]),
  node((5.6, -1.2), [one pass, ask the map#linebreak()for target - x]),
  edge((0, 0), (2.6, 1.2), "-|>", label: [yes]),
  edge((0, 0), (2.6, -1.2), "-|>", label: [no]),
  edge((2.6, 1.2), (5.6, 1.2), "-|>"),
  edge((2.6, -1.2), (5.6, -1.2), "-|>"),
)

The duplicate-pair test, `[3 3]` targeting 6, kills the variant
that stores the index and then looks up the same slot twice. The
C\# mirror returns `(int First, int Second)?`, the nullable tuple
spelling of "no answer", shown beside its map walk:

#listing("interview-repertoire/samples/ch05-cs/src/Searches.cs", first: 5, last: 18, caption: [the C\# one pass, nullable tuple result])

== isolated islands [TDD]

Island counting is flood fill wearing a costume: scan the grid,
and every time the scan steps on land it has not visited, increment
and sink the whole island. Each cell is touched a constant number
of times, so the cost is linear in cells:

#listing("interview-repertoire/samples/ch05-go/islands.go", first: 5, last: 38, caption: [scan, sink, count: dfs on a grid])

#diagram([the scan counts once per island, the sink claims the whole thing], length: 13pt, {
  // two 5x5 grids: the island before the scan reaches it, and after the sink
  let grid(ox, wet) = {
    for r in range(5) {
      for c in range(5) {
        let land = (r == 1 and c == 1) or (r == 2 and c == 1) or (r == 2 and c == 2)
        let f = if land and not wet { luma(205) } else { luma(240) }
        cdraw.rect((ox + c * 0.85, 2.8 - r * 0.85), (ox + c * 0.85 + 0.85, 3.65 - r * 0.85), fill: f, stroke: luma(210), radius: 0.0)
      }
    }
  }
  grid(1.0, false)
  cdraw.content((3.1, 4.6), [land, before], size: 6pt)
  cdraw.line((7.6, 3.2), (9.9, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.75, 3.8), [sink], size: 6pt)
  grid(10.3, true)
  cdraw.content((12.4, 4.6), [counted once, sunk], size: 6pt)
  cdraw.content((17.5, 4.4), [each cell is touched a constant], size: 6pt)
  cdraw.content((17.5, 3.3), [number of times, so the cost], size: 6pt)
  cdraw.content((17.5, 2.2), [is linear in cells], size: 6pt)
})

The suite guards the representation copy: the input strings are
copied to byte slices before any sinking, and the caller's grid
comes back untouched.

sources: verified by `go test` and `dotnet test` through `make
verify`, 17 Go tests and 29 C\# tests, chapter ids `ch05-go` and
`ch05-cs`.
