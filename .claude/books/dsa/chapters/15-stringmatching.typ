#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= string matching

Finding a pattern in text has a naive quadratic answer and a family
of linear and near-linear machines that each precompute something
about the pattern: borders, skip tables, rolling hashes, or a whole
automaton. This chapter builds them in order, seven languages deep,
ending with the multi-pattern machine that scans once for every
pattern at once.

== the naive baseline

The quadratic matcher every clever machine is measured against. Every
alignment is tried, every character compared from the front, and the
cost is exactly countable: a window that matches costs the pattern
length, a window that fails on the first character costs one. On
`abab` in `abababab` that is three full matches at 4 comparisons plus
two immediate mismatches, 14 total, and the overlapping hits at 0, 2,
and 4 all surface because nothing is ever skipped.

The dry run: the C\# fixture is `abc` over `abcabcabc` with the meter
pinned at 13, and C, JavaScript, and Lua pin the same rule on the
overlapping anchor, `abab` in `abababab` at 14.

+ Seven windows open over `abcabcabc`.
+ Windows 0, 3, and 6 read `abc` exactly, three comparisons each,
  3 + 3 + 3 = 9, hits at 0, 3, and 6.
+ Windows 1, 2, 4, and 5 fail on the first character, b or c against
  a, one comparison each, 4 in total.
+ The meter closes at 9 + 4 = 13, pinned.
+ The near-miss twin `abc` over `abababab` pays 3 + 1 + 3 + 1 +
  3 + 1 = 12, two characters agreeing wherever the text alternates
  and the third never, also pinned.
+ The overlap anchor `abab` in `abababab` collects 0, 2, and 4 with
  nothing skipped, and the ground-truth tests replay `IndexOf` and
  `str.find` in the C\# and Python suites.

#diagram([the run as one card per window, the three hits shaded, the cost written on each], length: 13pt, {
  let wins = ((0, 3, true), (1, 1, false), (2, 1, false), (3, 3, true), (4, 1, false), (5, 1, false), (6, 3, true))
  for (i, w) in wins.enumerate() {
    let x = 0.7 + i * 3.1
    cdraw.rect((x, 4.2), (x + 2.6, 5.6), fill: if w.at(2) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.3, 5.15), [start #(w.at(0))], size: 6pt)
    cdraw.content((x + 1.3, 4.65), [#(w.at(1)) cmp], size: 6pt)
    cdraw.content((x + 1.3, 3.5), if w.at(2) { [hit] } else { [first char fails] }, size: 6pt)
  }
  cdraw.content((10.7, 2.4), [9 + 4 = 13 comparisons, pinned], size: 6pt)
  cdraw.content((10.7, 1.5), [hits at 0, 3, 6], size: 6pt)
  cdraw.content((10.7, 0.6), [the abc twin over abababab: 12], size: 6pt)
})

The 13 with its 12 twin is the pinned meter pair, and the listings
below count the same walk in seven languages.

#listing("dsa/samples-c/src/Ch15/naive.c", first: 20, last: 36, caption: [c, every alignment tried, comparisons counted globally])

#listing("dsa/samples-go/ch15/naive.go", first: 5, last: 19, caption: [go, whole-window substring compare, the ground truth list])

#listing("dsa/samples-java/src/Ch15/Naive.java", first: 21, last: 51, caption: [java, charAt walk with the meter running, indexOf the referee for non-empty needles])

#listing("dsa/samples/src/Ch15/Naive.cs", first: 6, last: 38, caption: [c\#, the hit list, then the same walk with the comparison count exposed])

#listing("dsa/samples-js/src/ch15-naive.mjs", first: 4, last: 30, caption: [javascript, the plain walk and the counted walk side by side])

#listing("dsa/samples-py/src/Ch15/naive.py", first: 13, last: 21, caption: [python, the two-loop scan, empty pattern matches everywhere])

#listing("dsa/samples-lua/ch15_naive.lua", first: 7, last: 21, caption: [lua, byte compares over 0-based windows of a 1-based string])

Measured across the suites: every language pins the overlapping
anchor, `abab` in `abababab` at 0, 2, and 4. The comparison meter
splits three ways. C, Java, JavaScript, and Lua pin the 14 for that
fixture, C\# pins the same counting rule on its own fixtures, 13 for
`abc` in `abcabcabc` and 12 for `abc` in `abababab`, and Go compares
whole substrings so it pins positions only. Python cross-checks every
hit list against `str.find` advanced one past each hit, the same
ground-truth move the C\# suite makes with `IndexOf`, and Java does
it with `indexOf` over non-empty needles only, because `indexOf`
clamps an empty needle's start to the text length instead of ending
the scan.

#diagram([the naive scan over abababab for abab, matching windows shaded, the comparison ledger under each], length: 13pt, {
  let txt = ("a", "b", "a", "b", "a", "b", "a", "b")
  for (i, ch) in txt.enumerate() {
    cdraw.rect((1.2 + i, 5.4), (2.2 + i, 6.3), fill: luma(235), radius: 0.02)
    cdraw.content((1.7 + i, 5.85), [#ch], size: 6pt)
  }
  let win = (start, y, cost, hot) => {
    for k in range(4) {
      cdraw.rect((1.2 + start + k, y), (2.2 + start + k, y + 0.9), fill: if hot { luma(205) } else { luma(248) }, stroke: if hot { luma(100) }, radius: 0.02)
    }
    cdraw.content((1.7 + start, y - 0.42), [start #(start)], size: 6pt)
    cdraw.content((5.9, y + 0.45), [#cost], size: 6pt)
  }
  win(0, 3.7, [4, full match], true)
  win(1, 2.5, [1, first char fails], false)
  win(2, 1.3, [4, full match], true)
  win(3, 0.1, [1, first char fails], false)
  win(4, -1.1, [4, full match], true)
  cdraw.content((9.6, 5.85), [text], size: 6pt)
  cdraw.content((9.6, 2.6), [hits: 0, 2, 4], size: 6.5pt)
  cdraw.content((9.6, 1.5), [4 + 1 + 4 + 1 + 4 = 14 comparisons], size: 6pt)
  cdraw.content((9.6, 0.4), [five windows, nothing skipped], size: 6pt)
})

== kmp

The naive matcher restarts from scratch after every mismatch. KMP
precomputes, for every prefix of the pattern, the longest proper
border, prefix that is also suffix, and uses it to never move the
text pointer backwards.

The dry run: the fixtures are the pinned tables of `ababa`, `aaaab`,
and `abc` from the C\# suite, and the scan `abab` over `abababab`
that every suite carries.

+ The table of `ababa` builds in one pass: b against a misses for 0,
  then a, b, a each extend the border one more, 1, 2, 3, the last
  aba equal to the first.
+ `aaaab` climbs 1, 2, 3 and falls to 0 at the b through the long
  fallback chain, and `abc` never leaves 0, both pinned.
+ The scan climbs the matched length to 4 by index 3, reports hit 0,
  then sets it to the border of `abab`, the 2 the pinned table
  carries one slot before its own 3, not 0.
+ Two characters lift it back to 4 at index 5, hit 2, it falls to 2
  again, and the same pair lifts it to hit 4 at index 7.
+ The text pointer read 8 cells, one comparison each, and never moved
  backward: the hits read 0, 2, 4, pinned.

#diagram([the matched length under each text cell, hitting 4 three times, falling to the border 2 after each hit], length: 13pt, {
  let txt = ("a", "b", "a", "b", "a", "b", "a", "b")
  let js = (1, 2, 3, 4, 3, 4, 3, 4)
  let hits = (3, 5, 7)
  let px = i => 1.2 + i * 2.55
  let py = j => 1.4 + j * 0.95
  cdraw.line(..range(8).map(i => (px(i) + 1.1, py(js.at(i)))), stroke: luma(180))
  for i in range(8) {
    cdraw.rect((px(i), 6.0), (px(i) + 2.2, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((px(i) + 1.1, 6.8), [#txt.at(i)], size: 6.5pt)
    cdraw.content((px(i) + 1.1, 6.3), [#i], size: 6pt)
    cdraw.circle((px(i) + 1.1, py(js.at(i))), radius: 0.15, fill: if i in hits { luma(205) } else { luma(100) })
    cdraw.content((px(i) + 1.1, 0.55), [#js.at(i)], size: 6pt)
  }
  cdraw.line((px(3) + 1.1, 5.05), (px(3) + 1.1, py(2)), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((px(3) + 1.1, 2.6), [j falls to 2], size: 6pt)
  cdraw.content((11.0, -0.4), [the cells are the text, index under each], size: 6pt)
  cdraw.content((11.0, -1.2), [the track is j, the matched length], size: 6pt)
  cdraw.content((11.0, -2.0), [8 reads, 3 hits, i never back], size: 6pt)
})

The 0, 2, 4 off eight forward reads is the pinned scan, and the
listings below build the table in seven languages.

#listing("dsa/samples-c/src/Ch15/kmp.c", first: 18, last: 49, caption: [c, the failure table, then the single-pass scan])

#listing("dsa/samples-go/ch15/kmp.go", first: 3, last: 43, caption: [go, the table builder and the scan that never backs up])

#listing("dsa/samples-java/src/Ch15/Kmp.java", first: 20, last: 53, caption: [java, the border table, the scan, the hit slides k to the border])

#listing("dsa/samples/src/Ch15/Strings.cs", first: 4, last: 44, caption: [c\#, the failure table, then the linear scan])

#listing("dsa/samples-js/src/ch15-kmp.mjs", first: 5, last: 31, caption: [javascript, the border fallback chain and the scan])

#listing("dsa/samples-py/src/Ch15/kmp.py", first: 14, last: 39, caption: [python, the table, then the scan with the border sliding on])

#listing("dsa/samples-lua/ch15_kmp.lua", first: 6, last: 36, caption: [lua, byte-indexed borders on a 1-based pattern])

The table test uses `ababa`, borders 0 0 1 2 3, and `aaaab`, the
all-same prefix that makes the fallback chain long. The matching
test overlaps: `abab` in `abababab` hits at 0, 2, and 4, and the
ground-truth test cross-checks against `IndexOf` scanning.

Every suite pins the same two anchors: the `ababa` table 0 0 1 2 3
and the overlapping hits 0, 2, 4. The ground-truth partner differs
by ecosystem, C\# and Python replay `IndexOf` and `str.find`, C,
Java, and Lua carry a private naive counter, and Go and JavaScript
hold the scan against table-driven window lists. After a hit every
version
sets the matched length to its own border rather than zero, which is
what keeps the overlapping occurrences arriving.

#diagram([kmp, the failure table is borders and the text pointer never moves backward], length: 13pt, {
  // left: ababa, borders 0 0 1 2 3, the last aba equals the first;
  // right: abab in abababab, hits 0 2 4
  cdraw.content((5.5, 7.6), [the failure table is borders], size: 6.5pt)
  let pat = ("a", "b", "a", "b", "a")
  for (i, ch) in pat.enumerate() {
    cdraw.rect((2.4 + i, 5.85), (3.4 + i, 6.75), fill: if i < 3 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((2.9 + i, 6.3), [#ch], size: 6pt)
  }
  cdraw.content((0.9, 6.3), [whole], size: 6pt)
  let suf = ("a", "b", "a")
  for (i, ch) in suf.enumerate() {
    cdraw.rect((2.4 + i, 4.75), (3.4 + i, 5.65), fill: luma(205), radius: 0.02)
    cdraw.content((2.9 + i, 5.2), [#ch], size: 6pt)
  }
  cdraw.content((0.9, 5.2), [suffix], size: 6pt)
  cdraw.content((9.5, 6.3), [the last aba], size: 6pt)
  cdraw.content((9.5, 5.15), [equals the first], size: 6pt)
  cdraw.content((9.5, 4.2), [so the border is 3], size: 6pt)
  let table = (0, 0, 1, 2, 3)
  for (i, v) in table.enumerate() {
    cdraw.rect((2.4 + i, 2.85), (3.4 + i, 3.75), fill: luma(235), radius: 0.02)
    cdraw.content((2.9 + i, 3.3), [#v], size: 6pt)
  }
  cdraw.content((0.9, 3.3), [table], size: 6pt)
  cdraw.content((9.5, 2.85), [0 0 1 2 3], size: 6pt)
  cdraw.content((5.5, 1.7), [on mismatch: j = table[j - 1]], size: 6pt)
  cdraw.content((5.5, 0.55), [the text pointer i never moves back], size: 6pt)

  cdraw.content((18.0, 7.6), [the scan, abab in abababab], size: 6.5pt)
  let txt = ("a", "b", "a", "b", "a", "b", "a", "b")
  for (i, ch) in txt.enumerate() {
    cdraw.rect((13.0 + i, 5.85), (14.0 + i, 6.75), fill: luma(235), radius: 0.02)
    cdraw.content((13.5 + i, 6.3), [#ch], size: 6pt)
  }
  let wins = ((0, 3, 5.5, [hit 0]), (2, 5, 4.4, [hit 2]), (4, 7, 3.3, [hit 4]))
  for w in wins {
    let (a, b, y, lab) = w
    cdraw.line((13.0 + a, y), (13.0 + b + 1, y), stroke: luma(100))
    cdraw.line((13.0 + a, y), (13.0 + a, y - 0.15), stroke: luma(100))
    cdraw.line((13.0 + b + 1, y), (13.0 + b + 1, y - 0.15), stroke: luma(100))
    cdraw.content((22.3, y), lab, size: 6pt)
  }
  cdraw.content((18.0, 2.2), [overlapping hits all reported], size: 6pt)
  cdraw.content((18.0, 1.1), [after a hit j = table[j - 1], not 0], size: 6pt)
  cdraw.content((18.0, 0.0), [ground truth: IndexOf cross check], size: 6pt)
})

== horspool

Horspool is Boyer-Moore reduced to one table: align at the end,
compare backwards, and on mismatch skip by the table entry of the
window's last character. Rare tail characters skip whole pattern
lengths.

The dry run: the C\# anchor returns first indexes only, 10 for
`ababd` in its text, so the walk follows the C suite's skip fixture,
`abc` over `abdbcabc`, every shift and comparison pinned, with the
Python and Lua twins carrying the same numbers.

+ The table charges `a` 2 and `b` 1, absent characters the whole 3,
  the same rule as the pinned `abab` twin, `a` 1, `b` 2, else 4.
+ Window one reads `abd` against `abc`, the tail d fails c at one
  comparison, and d is absent: skip 3, the pinned first shift.
+ Window two reads `bca`, the tail a fails c, one comparison again,
  and `a` charges 2, the pinned second shift.
+ Window three reads `abc` backwards, c, b, a, three comparisons, the
  hit at 5 against the text edge.
+ The meter closes at 1 + 1 + 3 = 5, one hit, both pinned.
+ The overlap twin `abab` over `abababab` matches all three
  alignments and shifts by the b rule twice, both 2, reporting
  0, 2, 4 at 12 comparisons, also pinned.

#diagram([the run as three window frames over the text, two tail mismatches, the skips 3 and 2 landing the hit], length: 13pt, {
  let txt = ("a", "b", "d", "b", "c", "a", "b", "c")
  for (i, ch) in txt.enumerate() {
    cdraw.rect((1.0 + i * 1.5, 6.3), (2.5 + i * 1.5, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((1.75 + i * 1.5, 6.75), [#ch], size: 6.5pt)
  }
  let pat = ("a", "b", "c")
  let frame = (x0, y, hot, note) => {
    for k in range(3) {
      cdraw.rect((x0 + k * 1.5, y), (x0 + (k + 1) * 1.5, y + 0.9), fill: if hot { luma(205) } else { luma(248) }, stroke: luma(100), radius: 0.02)
      cdraw.content((x0 + k * 1.5 + 0.75, y + 0.45), [#pat.at(k)], size: 6pt)
    }
    cdraw.content((x0 + 2.25, y - 0.45), note, size: 6pt)
  }
  frame(1.0, 4.9, false, [tail d fails c, skip 3])
  frame(5.5, 3.4, false, [tail a fails c, skip 2])
  frame(8.5, 1.9, true, [c, b, a match, hit at 5])
  cdraw.line((4.6, 5.1), (5.9, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.4, 3.6), (10.4, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.2, 5.4), [the tail character prices the shift], size: 6pt)
  cdraw.content((15.2, 3.9), [absent character, whole pattern], size: 6pt)
  cdraw.content((15.2, 2.4), [1 + 1 + 3 = 5 comparisons], size: 6pt)
  cdraw.content((15.2, 0.9), [after a hit this suite keeps shifting], size: 6pt)
})

The 5 comparisons with shifts 3 then 2 is the pinned ledger, and the
listings below carry the after-hit split in seven languages.

#listing("dsa/samples-c/src/Ch15/horspool.c", first: 20, last: 58, caption: [c, the skip table, tail-aligned compare, shifts recorded])

#listing("dsa/samples-go/ch15/horspool.go", first: 8, last: 46, caption: [go, bad character table, then the stats-bearing scan])

#listing("dsa/samples-java/src/Ch15/Horspool.java", first: 24, last: 61, caption: [java, the skip table, tail compare, every shift logged, hits keep shifting])

#listing("dsa/samples/src/Ch15/Strings.cs", first: 45, last: 66, caption: [c\#, one table, one pass, first index back])

#listing("dsa/samples-js/src/ch15-horspool.mjs", first: 6, last: 42, caption: [javascript, map-backed table, a match clears the whole pattern])

#listing("dsa/samples-py/src/Ch15/horspool.py", first: 14, last: 41, caption: [python, dict table, the mismatching pair also costs a compare])

#listing("dsa/samples-lua/ch15_horspool.lua", first: 9, last: 45, caption: [lua, table of 256 chars, tail compare leftward])

The suites disagree on purpose about what happens after a hit, and
the disagreement is worth reading twice. C, Java, Python, and Lua
keep shifting by the tail character's table entry even after a full
match, so `abab` in `abababab` reports the overlapping 0, 2, 4 at 12
comparisons, Java through a mismatch-style exit that reuses the tail
rule after every hit. Go and JavaScript advance the whole pattern
after a hit, the classic textbook advance, so the same fixture
yields 0 and 4 and the skip counts pin instead. C\# returns the
first hit index only. On the miss side all seven agree: an absent
tail character jumps
the full pattern length, and the pinned skip sequences, like 3 then
2 for `abc` in `abdbcabc`, are the whole point of the table.

#diagram([horspool skips by the tail character, x is absent so the whole pattern length goes at once], length: 13pt, {
  // abcxabcd against abcd, tail x is absent, skip the whole length
  cdraw.content((8.0, 7.6), [skip on the tail character], size: 6.5pt)
  let txt = ("a", "b", "c", "x", "a", "b", "c", "d")
  for (i, ch) in txt.enumerate() {
    cdraw.rect((1.0 + i * 0.95, 6.25), (1.95 + i * 0.95, 7.15), fill: luma(235), radius: 0.02)
    cdraw.content((1.475 + i * 0.95, 6.7), [#ch], size: 6pt)
  }
  cdraw.content((0.1, 6.7), [text], size: 6pt)
  let pat = ("a", "b", "c", "d")
  for (i, ch) in pat.enumerate() {
    cdraw.rect((1.0 + i * 0.95, 4.85), (1.95 + i * 0.95, 5.75), fill: luma(235), radius: 0.02)
    cdraw.content((1.475 + i * 0.95, 5.3), [#ch], size: 6pt)
  }
  cdraw.content((4.325, 6.0), [!=], size: 6pt)
  for (i, ch) in pat.enumerate() {
    cdraw.rect((4.8 + i * 0.95, 3.65), (5.75 + i * 0.95, 4.55), fill: luma(205), radius: 0.02)
    cdraw.content((5.275 + i * 0.95, 4.1), [#ch], size: 6pt)
  }
  cdraw.content((9.3, 4.1), [hit], size: 6pt)
  cdraw.line((3.6, 4.75), (5.1, 4.25), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.4, 4.5), [skip 4], size: 6pt)
  cdraw.content((8.0, 2.9), [compare from the tail leftward], size: 6pt)
  cdraw.content((8.0, 1.8), [mismatch: jump by table[tail char]], size: 6pt)
  cdraw.content((8.0, 0.7), [x is absent: skip the whole pattern], size: 6pt)
  cdraw.content((8.0, -0.4), [c, python, lua: 0, 2, 4 overlaps kept], size: 6pt)
  cdraw.content((8.0, -1.5), [go, javascript: a match clears m, 0 and 4], size: 6pt)
})

== rabin-karp

Rabin-Karp hashes the pattern and a sliding window with a polynomial
rolling hash, subtract the leaving character times the high power,
add the entering one, and verifies with a real comparison on hash
hits. On its own it is average-linear with hash collision risk, and
it is the multi-pattern and two-dimensional workhorse for the same
rolling reason.

The dry run: the C\# suite pins index agreement with `IndexOf` on its
own text, so the walk follows the C and Lua hand-computed anchor,
`abab` under the 1e9+7 modulus, every number below pinned.

+ The pattern hash is a polynomial in base 256:
  ((97 x 256 + 98) x 256 + 97) x 256 + 98 = 1633837410, and one
  reduction, 1633837410 - 1000000007 = 633837403, pins the pair.
+ Window one `abab` hashes equal, the verification compares four
  characters, and hit 0 lands.
+ Each slide subtracts the leaving a times 256^3, shifts, adds the
  entering character, and the suite pins every rolled window equal to
  a from-scratch hash of the same letters.
+ Only the `abab` windows hash equal across `abababab`: three
  verifications, hits 0, 2, 4, zero spurious, all pinned.
+ The `aaaa` twin hashes equal at every alignment and still reports
  0, 1, 2 with nothing spurious, and the absent `xyz` verifies
  nothing, both pinned.

#diagram([the pass over abababab as five windows, the three hash-equal ones shaded and verified, the two others skipped untouched], length: 13pt, {
  let wins = (
    ([abab], true, [verify 4 chars, hit 0]),
    ([baba], false, [no hash hit]),
    ([abab], true, [verify 4 chars, hit 2]),
    ([baba], false, [no hash hit]),
    ([abab], true, [verify 4 chars, hit 4]),
  )
  for (i, w) in wins.enumerate() {
    let x = 0.8 + i * 4.5
    cdraw.rect((x, 4.2), (x + 3.7, 5.4), fill: if w.at(1) { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.85, 4.95), w.at(0), size: 6.5pt)
    cdraw.content((x + 1.85, 4.45), [#i], size: 6pt)
    cdraw.content((x + 1.85, 3.4), w.at(2), size: 6pt)
    if i < 4 { cdraw.line((x + 3.9, 4.8), (x + 4.3, 4.8), stroke: luma(100), mark: (end: ">")) }
  }
  cdraw.content((11.0, 2.3), [hash(abab) = 633837403, pinned], size: 6pt)
  cdraw.content((11.0, 1.4), [3 verifications, 0 spurious], size: 6pt)
  cdraw.content((11.0, 0.5), [every roll cross-checked from scratch], size: 6pt)
})

The 633837403 with three verifications and none spurious is the
pinned ledger, and the listings below roll the same window in seven
languages.

#listing("dsa/samples-c/src/Ch15/rabinkarp.c", first: 30, last: 65, caption: [c, modulus 1e9+7, products stay under 2^64, verify on hit])

#listing("dsa/samples-go/ch15/rabinkarp.go", first: 13, last: 60, caption: [go, mersenne 2^61-1 modulus, mulmod through bits.Mul64])

#listing("dsa/samples-java/src/Ch15/Rabinkarp.java", first: 20, last: 71, caption: [java, modulus 1e9+7 on plain long, every product under 2^63, prime added back on the roll])

#listing("dsa/samples/src/Ch15/Strings.cs", first: 68, last: 97, caption: [c\#, the roll on long, negative sums patched back up])

#listing("dsa/samples-js/src/ch15-rabinkarp.mjs", first: 4, last: 46, caption: [javascript, the whole hash on BigInt past the 2^53 boundary])

#listing("dsa/samples-py/src/Ch15/rabinkarp.py", first: 14, last: 40, caption: [python, native ints, hash hits and verified hits counted apart])

#listing("dsa/samples-lua/ch15_rabinkarp.lua", first: 8, last: 49, caption: [lua, small modulus keeps every product below 2^62])

The rolling hash is the chapter's first real integer-semantics
checkpoint, and the seven suites take four different roads through
it. C and Lua hold the modulus at 1e9+7, where both operands of
every product stay below about 1e9 and the product below 2^62, so a
plain multiply and remainder is safe, in Lua specifically because
its integers wrap silently at 64 bits. C\# and Java run the same
modulus on a signed 64-bit long, where the subtraction can leave the
window hash negative, so the roll adds the prime back first. Go
prefers the Mersenne prime 2^61-1, which needs a genuine 128-bit
product from `math/bits.Mul64`. JavaScript puts the entire hash on
BigInt with a comment at the boundary, because base 256 to the
window length passes 2^53 after a handful of characters. Python
needs no ceremony at all. C, Java, and Lua pin the same
hand-computed hash, `abab` at 1633837410 reducing to 633837403, and
every suite reports 3 verifications and 0 spurious hits on the
overlapping fixture.

#diagram([rabin karp rolls the hash, the leaving and entering characters carry the update, every hit verified], length: 13pt, {
  cdraw.content((11.0, 7.6), [roll the hash one cell at a time], size: 6.5pt)
  let txt2 = ("a", "b", "r", "a", "c", "a")
  for (i, ch) in txt2.enumerate() {
    cdraw.rect((4.0 + i, 6.25), (5.0 + i, 7.15), fill: luma(235), radius: 0.02)
    cdraw.content((4.5 + i, 6.7), [#ch], size: 6pt)
  }
  cdraw.content((3.1, 6.7), [text], size: 6pt)
  let w1 = ("a", "b", "r")
  for (i, ch) in w1.enumerate() {
    cdraw.rect((4.0 + i, 5.05), (5.0 + i, 5.95), fill: if i == 0 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((4.5 + i, 5.5), [#ch], size: 6pt)
  }
  let w2 = ("b", "r", "a")
  for (i, ch) in w2.enumerate() {
    cdraw.rect((5.0 + i, 3.55), (6.0 + i, 4.45), fill: if i == 2 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((5.5 + i, 4.0), [#ch], size: 6pt)
  }
  cdraw.content((11.0, 5.5), [hash(a b r)], size: 6pt)
  cdraw.content((11.0, 4.0), [hash(b r a)], size: 6pt)
  cdraw.line((7.5, 4.95), (7.5, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.2, 2.85), [(h - out \* high) \* b + in], size: 6pt)
  cdraw.content((11.0, 1.7), [dark: the leaving and entering chars], size: 6pt)
  cdraw.content((11.0, 0.55), [hash hit: verify with a real compare], size: 6pt)
  cdraw.content((3.6, 2.5), [c, lua: 1e9+7, products under 2^62], size: 6pt)
  cdraw.content((3.6, 1.4), [go: 2^61-1 through bits.Mul64], size: 6pt)
  cdraw.content((3.6, 0.3), [javascript: BigInt, c\#: long plus prime], size: 6pt)
})

== aho-corasick

Many patterns, one pass. The machine is a trie of the patterns,
chapter 9, plus failure links computed breadth first, which are
exactly KMP borders generalized to the trie.

The dry run: the machine is `he`, `she`, `his`, `hers` over
`ushershehished`, all eight hits pinned by the C\# suite, and the C
and Lua twins pin the machine itself, 10 nodes and the four named
failure links.

+ The text reads u s h e r s h e h i s h e d, and the walk opens at
  the root with no output until the first e.
+ Position 3 sits on she and emits twice, she with he riding its
  failure link, the nested hit, count 2.
+ Position 5 closes hers, count 3, and position 7 brings the second
  she with its he, count 5.
+ Position 10 fires his after the walk fell back to the root and
  re-entered through h and hi, count 6.
+ Position 12 closes the third she with its he, count 8, one output
  per pattern ending, nested included, the pinned total.

#diagram([the pass as five emission stops, each column the position, the patterns fired there, and the running count], length: 13pt, {
  let stops = (
    (3, ([she], [he]), [2 so far]),
    (5, ([hers],), [3 so far]),
    (7, ([she], [he]), [5 so far]),
    (10, ([his],), [6 so far]),
    (12, ([she], [he]), [8 so far]),
  )
  for (i, s) in stops.enumerate() {
    let x = 0.8 + i * 4.5
    cdraw.rect((x, 3.4), (x + 3.8, 6.0), fill: if i == 4 { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.9, 5.55), [position #s.at(0)], size: 6.5pt)
    for (j, chip) in s.at(1).enumerate() {
      cdraw.content((x + 1.9, 4.9 - j * 0.75), chip, size: 6pt)
    }
    cdraw.content((x + 1.9, 3.85), s.at(2), size: 6pt)
  }
  cdraw.content((11.5, 2.5), [he rides she's failure link at all three she stops], size: 6pt)
  cdraw.content((11.5, 1.6), [no output anywhere else], size: 6pt)
  cdraw.content((11.5, 0.7), [nested hits included, 8 total, pinned], size: 6pt)
})

The 8 hits with he inside she at all three of its stops is the pinned
pass, and the listings below build the machine in seven languages.

#listing("dsa/samples-c/src/Ch15/aho.c", first: 41, last: 73, caption: [c, the trie, then breadth-first failure links])

#listing("dsa/samples-go/ch15/aho.go", first: 21, last: 56, caption: [go, the trie build and map-carrying nodes])

#listing("dsa/samples-java/src/Ch15/Aho.java", first: 37, last: 90, caption: [java, the int-array trie, breadth-first fail links, the scan walks the fail chain])

#listing("dsa/samples/src/Ch15/Strings.cs", first: 101, last: 152, caption: [c\#, add patterns, then the build that hangs outputs on fail chains])

#listing("dsa/samples-js/src/ch15-aho.mjs", first: 4, last: 37, caption: [javascript, node array, sorted breadth-first link pass])

#listing("dsa/samples-py/src/Ch15/aho.py", first: 25, last: 57, caption: [python, the build and the single-pass search, deque for the bfs])

#listing("dsa/samples-lua/ch15_aho.lua", first: 14, last: 66, caption: [lua, node table, fail links, the scan with its output chain])

Each output node also carries its fail node's outputs, so the scan
reports every pattern ending at each position, nested matches
included, `he` inside `she` inside `hers`. The test builds the
classic four-pattern machine and pins all eight hits of one text.
This is the spam filter, virus scanner, and censorship library
algorithm, and it is the last structure the capstone's key index
could borrow from, prefix queries over a dictionary of stored keys.

All seven suites build `he`, `she`, `his`, `hers` and pin the same
eight hits over `ushershehished`. The output machinery splits two
ways, and both are correct: C, Java, JavaScript, and Lua walk the
fail chain at search time looking for nodes that end patterns, while
C\#, Go, and Python fold the fail node's output list into the node
during the build, buying a flat scan with one append per link. C,
Java, and Lua also pin the machine itself, 10 nodes and the four
named failure links, and Python borrows `collections.deque` for the
breadth-first queue, the one supporting container in the chapter.

#diagram([aho-corasick, a trie with failure links, one pass reports every pattern including he inside she], length: 13pt, {
  // patterns he, she, his, hers over ushershehished: eight hits
  let text = ("u", "s", "h", "e", "r", "s", "h", "e", "h", "i", "s", "h", "e", "d")
  for (i, ch) in text.enumerate() {
    cdraw.rect((2.2 + i * 0.62, 6.25), (2.82 + i * 0.62, 7.15), fill: luma(235), radius: 0.02)
    cdraw.content((2.51 + i * 0.62, 6.7), [#ch], size: 6pt)
  }
  let span = (a, b, y) => {
    cdraw.line((2.2 + a * 0.62, y), (2.2 + (b + 1) * 0.62, y), stroke: luma(100))
    cdraw.line((2.2 + a * 0.62, y), (2.2 + a * 0.62, y - 0.12), stroke: luma(100))
    cdraw.line((2.2 + (b + 1) * 0.62, y), (2.2 + (b + 1) * 0.62, y - 0.12), stroke: luma(100))
  }
  span(1, 3, 5.8)
  span(5, 7, 5.8)
  span(10, 12, 5.8)
  cdraw.content((1.2, 5.8), [she], size: 6pt)
  span(2, 3, 4.8)
  span(6, 7, 4.8)
  span(11, 12, 4.8)
  cdraw.content((1.2, 4.8), [he], size: 6pt)
  span(2, 5, 3.8)
  cdraw.content((1.2, 3.8), [hers], size: 6pt)
  span(8, 10, 2.8)
  cdraw.content((1.2, 2.8), [his], size: 6pt)
  cdraw.content((6.5, 1.7), [eight hits in one left to right pass], size: 6pt)
  cdraw.content((6.5, 0.55), [he rides she's failure link], size: 6pt)

  // the machine: trie of he, she, his, hers, dashed failure links
  let box = (pos, name, out) => {
    cdraw.rect((pos.at(0) - 0.75, pos.at(1) - 0.28), (pos.at(0) + 0.75, pos.at(1) + 0.28), fill: if out { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content(pos, name, size: 6pt)
  }
  let edge = (a, b) => cdraw.line(a, b, stroke: luma(100))
  edge((15.8, 1.45), (14.4, 2.65))
  edge((15.8, 1.45), (17.2, 2.65))
  edge((14.4, 2.65), (12.9, 3.85))
  edge((14.4, 2.65), (15.1, 3.85))
  edge((17.2, 2.65), (17.6, 3.85))
  edge((15.1, 3.85), (15.1, 5.05))
  edge((17.6, 3.85), (17.6, 5.05))
  edge((17.6, 5.05), (18.3, 6.25))
  edge((18.3, 6.25), (19.0, 7.45))
  cdraw.line((17.02, 3.63), (14.98, 2.87), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((16.99, 4.89), (13.51, 4.01), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.line((15.52, 4.57), (16.78, 3.13), stroke: (paint: luma(160), dash: "dashed"))
  box((15.8, 1.45), [root], false)
  box((14.4, 2.65), [h], false)
  box((17.2, 2.65), [s], false)
  box((12.9, 3.85), [he], true)
  box((15.1, 3.85), [hi], false)
  box((17.6, 3.85), [sh], false)
  box((15.1, 5.05), [his], true)
  box((17.6, 5.05), [she], true)
  box((18.3, 6.25), [sher], false)
  box((19.0, 7.45), [hers], true)
  cdraw.content((11.5, -0.75), [dashed: failure links, shaded nodes inherit their fail node's outputs], size: 6pt)
})

== across the seven languages

The build sizes count non-comment source lines over this chapter's
five featured files per language, checks included where they share
the file, which is the C and Lua convention, and excluded where a
separate test project carries them:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [363], [libc only], [unsigned char casts index the 256-slot skip table, counts in long long, 83 checks ride in main],
  [c\#], [190], [bcl only], [the rolling hash runs on long and adds the prime back after a subtract, horspool returns the first index],
  [go], [199], [math/bits], [rabin karp mods the mersenne 2^61-1, mulmod through bits.Mul64, a match advances the whole pattern],
  [java], [476], [jdk 27 stdlib], [the 1e9+7 hash stays on plain long, every product under 2^63, the indexOf referee is non-empty-needles-only because it clamps an empty needle],
  [javascript], [182], [node stdlib], [the hash is BigInt with a comment at the 2^53 boundary, horspool skips overlaps by design],
  [python], [274], [stdlib only], [native ints, str.find is the ground truth, collections.deque is the one borrowed container, for the bfs],
  [lua], [339], [lib.lua harness], [modulus 1e9+7 keeps products under 2^62 so the silent int64 wrap never fires here],
)

sources: learn.microsoft.com, `string.IndexOf` overloads used as
ground truth, `MemoryExtensions.SequenceEqual`, `Array.Fill`,
accessed 2026-09-08, go.dev/pkg/math/bits for `Mul64`, accessed
2026-09-14, plus the KMP, Boyer-Moore, and Aho-Corasick literature
cited in the chapter text. Sample behavior verified by
`make verify-csharp`, 11 tests in chapter 15 of the samples suite.
The seven-language layer verifies the same way: 5 C programs with 83
embedded checks under `make verify-c`, 5 Ch15 java programs with 83
checks under `run-java-samples`, 17 Go tests, 20 `node --test`
cases, 49 Python checks across 5 files, and 21 Lua checks under
`run.lua`.
