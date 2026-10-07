#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw
#import "../../theme/xref.typ": xref-to

= string algorithms ii

Chapter 15 built the first matching course, naive scanning, kmp
borders, rolling hashes, and aho-corasick, and chapter 9 built the
sorted suffix array with kasai lcp and binary-search substring
lookup. This chapter owns the linear-time machines that come after
them. The z-function reads a string against itself and answers
occurrence questions from one array. Manacher finds every palindrome
in one pass. The suffix automaton and the suffix tree compress all
substrings of a string into structures that answer counting and
location queries by walking, and lyndon factorization splits a string
into its sorted pieces, which hands over the least rotation and the
repetition scan. The chapter 15 machines answer does p occur, the
machines here answer how many distinct substrings exist, where is the
deepest repeat, and what is the minimal rotation, all with the
queries rather than the construction as the teaching point.

== the z-function

For a string s, z[i] is the length of the longest common prefix of s
and s[i:], with z[0] = n pinned as the convention and no caller ever
reading it. The build keeps a z-box, the interval \[l, r) of the most
recent position whose prefix match reached furthest right. A new
position i inside the box can copy homework: the box is always a
substring of the prefix, so the match starting at i - l inside the
prefix tells us z[i] is at least min(r - i, z[i - l]), the cap
stopping the reuse from reading past r where nothing is known. Beyond
the cap the loop extends by direct comparison, and whenever i + z[i]
passes r the box re-anchors at i. Each character of s is matched
against a character further left only while r advances, so the whole
build is O(n).

The dry run: the fixture is abacaba, whose z array 7, 0, 1, 0, 3,
0, 1 is asserted by the C\# suite alongside its brute twin, and the
other six suites pin the same array.

+ z\[0\] = 7 is the convention, and i = 1 dies on the first
  compare, b against a: z\[1\] = 0 with the box still empty.
+ i = 2 sits outside the empty box and extends by compare, a
  matches then b stops at c, z\[2\] = 1, and 2 + 1 = 3 past r
  re-anchors the box to \[2, 3).
+ i = 3 lands outside again: a against c stops at once, z\[3\] = 0.
+ i = 4 extends three, a, b, a, before c stops it, z\[4\] = 3, and
  4 + 3 = 7 re-anchors the box to \[4, 7), the deepest reach of the
  run.
+ i = 5 copies z\[5 - 4\] = z\[1\] = 0 with the cap r - i = 2
  slack, and the confirming compare b against a dies: z\[5\] = 0.
+ i = 6 copies min(r - i = 1, z\[2\] = 1) = 1, and with
  i + 1 = 7 = n the cap was exact: z\[6\] = 1 at zero compares.

#diagram([the abacaba build as stacked frames, one row per position, the shading the current box, the stroked cell the position being computed], length: 13pt, {
  // frames: (i, l, r, z[i]) over s = abacaba
  let s = ("a", "b", "a", "c", "a", "b", "a")
  let frames = (
    (1, 1, 1, 0),
    (2, 2, 3, 1),
    (3, 2, 3, 0),
    (4, 4, 7, 3),
    (5, 4, 7, 0),
    (6, 4, 7, 1),
  )
  for (f, (i, l, r, zi)) in frames.enumerate() {
    let y = 6.9 - f * 1.02
    cdraw.content((0.95, y + 0.4), [#i], size: 6pt)
    for k in range(7) {
      let x = 1.7 + k * 1.02
      cdraw.rect((x, y), (x + 1.02, y + 0.8), fill: if k >= l and k < r { luma(215) } else { luma(238) }, stroke: if k == i { luma(60) } else { none }, radius: 0.02)
      cdraw.content((x + 0.51, y + 0.4), s.at(k), size: 6pt)
    }
    cdraw.content((9.65, y + 0.4), [z = #zi], size: 6pt)
  }
  cdraw.content((1.7, 0.5), [z lands 7, 0, 1, 0, 3, 0, 1], size: 6.5pt)
  cdraw.content((9.65, 0.5), [shaded = box \[l, r), stroked = i], size: 6pt)
})

The array lands 7, 0, 1, 0, 3, 0, 1 exactly as pinned, and the
listings below build it in seven languages.

#listing("dsa/samples-c/src/Ch33/zfunc.c", first: 26, last: 66, caption: [c, the z-box build loop, the brute twin, and the separator search])

#listing("dsa/samples-go/ch33/zfunc.go", first: 7, last: 45, caption: [go, the build with the min cap spelled out, the search, the rotation test below])

#listing("dsa/samples-java/src/Ch33/Zfunc.java", first: 26, last: 61, caption: [java, the z-box build, the brute twin, and the separator search over the \\x01 join])

#listing("dsa/samples/src/Ch33/Zfunc.cs", first: 11, last: 58, caption: [c\#, the build, the brute cross-check, and the search reading z against the pattern length])

#listing("dsa/samples-js/src/ch33-zfunc.mjs", first: 9, last: 35, caption: [javascript, the build and the search, the same two functions])

#listing("dsa/samples-py/src/Ch33/zfunc.py", first: 17, last: 50, caption: [python, the build, the brute lcp per position, the search])

#listing("dsa/samples-lua/ch33_zfunc.lua", first: 8, last: 57, caption: [lua, 1-based storage over 0-based positions, the build and the search])

Two queries ride the array. The separator search concatenates
pat + '\\x01' + text, a separator ordered below every real character so
it can never match, and builds z over the combined string: position m
+ 1 + i holds exactly m exactly when the pattern occurs at text
offset i, overlaps included, O(n + m) total, the same contract the
kmp of #xref-to("dsa", "stringmatching") fills with borders. The
rotation test follows: t is a rotation of s exactly when s occurs in
t + t, so one separator search over the doubled text decides it.

The fixtures pin the same arrays in all seven languages: z(aaaaa) =
5, 4, 3, 2, 1; z(abacaba) = 7, 0, 1, 0, 3, 0, 1; z(aabaa) = 5, 1, 0,
2, 1; z(ababab) = 6, 0, 4, 0, 2, 0; z(abab) = 4, 0, 2, 0;
z(acacacb) = 7, 0, 4, 0, 2, 0, 0. The search family pins ab in
ababab at 0, 2,
4, ana in banana at 1, 3, abab in abababab at 0, 2, 4, abc in aabbcc
nowhere, and a in aaaa at 0, 1, 2, 3. The rotation family pins
(abcab, bcaba), (abab, baba), and (abc, abc) as rotations and
(abc, acb) as not. The edges read z of the empty string as empty, z
of a as 1, z of aa as 2, 1, and every suite keeps a brute
longest-common-prefix-per-position twin agreeing on the whole batch.

The application is icpc world finals 2023 problem F (book 10,
chapter 12), tilting tiles, whose per-cycle reasoning matches a
pattern against the
doubled cycle, exactly the separator search shape, with the chapter
15 kmp as the alternate machine for the same job.

#diagram([the z-box jumping over aabaa, the position-3 box copying the prefix, the reuse arrow at position 4, the hits ledger underneath], length: 13pt, {
  // aabaa: z = [5,1,0,2,1]; box [3,5) copies prefix [0,2); i=4 reuses z[1]=1
  let s = ("a", "a", "b", "a", "a")
  for (i, c) in s.enumerate() {
    let x = 1.6 + i * 1.5
    // the prefix copy shading: positions 0-1 and 3-4 share one fill
    let pref = i <= 1 or i >= 3
    cdraw.rect((x, 6.3), (x + 1.5, 7.2), fill: if pref { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 6.75), c, size: 8pt)
    cdraw.content((x + 0.75, 5.9), [z=#(if i == 0 { 5 } else if i == 1 { 1 } else if i == 2 { 0 } else if i == 3 { 2 } else { 1 })], size: 6.5pt)
  }
  // the box: bracket over [3,5) tied back to the prefix [0,2)
  cdraw.rect((1.6, 7.35), (4.6, 7.7), fill: none, stroke: luma(100), radius: 0.02)
  cdraw.content((3.1, 7.55), [prefix], size: 6pt)
  cdraw.rect((6.1, 7.35), (9.1, 7.7), fill: none, stroke: luma(100), radius: 0.02)
  cdraw.content((7.6, 7.55), [box \[3,5) = copy of \[0,2)], size: 6pt)
  // reuse arrow: at i=4 inside the box, z[4] reuses z[4-3] = z[1] = 1
  cdraw.line((2.35, 5.35), (7.85, 5.35), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((5.1, 5.6), [i = 4 reuses z\[i - l\] = z\[1\] = 1, capped by r - i], size: 6pt)
  // the i=3 direct extension that re-anchored the box
  cdraw.content((7.85, 4.9), [i = 3 extended by compare to 2, re-anchored], size: 6pt)
  // hits ledger: separator search of aa in aabaa, combined z values below
  cdraw.content((1.0, 3.6), [search: z over aa \\x01 aabaa], size: 6.5pt)
  let ledger = (2, 1, 0, 2, 1)
  for (i, c) in ("a", "a", "b", "a", "a").enumerate() {
    let x = 1.6 + i * 1.5
    let hit = i == 0 or i == 3
    cdraw.rect((x, 2.4), (x + 1.5, 3.3), fill: if hit { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 2.85), c, size: 8pt)
    cdraw.content((x + 0.75, 2.0), [#ledger.at(i)], size: 6.5pt)
  }
  cdraw.content((1.0, 1.2), [combined z: 2 1 0 2 1, hits where it reaches the pattern length 2], size: 6pt)
  cdraw.content((13.8, 6.9), [z\[0\] = n pinned, never read], size: 6pt)
  cdraw.content((13.8, 5.9), [reuse never reads past r], size: 6pt)
  cdraw.content((13.8, 4.9), [one pass, O(n) build], size: 6pt)
  cdraw.content((13.8, 3.9), [separator \\x01 ordered below all], size: 6pt)
  cdraw.content((13.8, 2.9), [search O(n + m), overlaps kept], size: 6pt)
  cdraw.content((13.8, 1.9), [rotation: s occurs in t + t], size: 6pt)
})

== manacher's two passes

Every palindrome has a center, a single character for odd lengths or
a gap between characters for even ones, and manacher computes one
radius array per kind in a single linear pass each. The odd array d1
counts the odd palindromes centered at each i, so d1[i] is the radius
plus one, and the even array d2 counts the even palindromes
straddling the i - 1 and i boundary. Both passes keep a mirrored
interval [l, r], the furthest-reaching palindrome seen so far. A new
center i inside the interval has a mirror at l + r - i, and the
palindrome around that mirror is already known, so the radius starts
at min(d[mirror], r - i + 1) instead of zero: the mirror's radius is
trusted only as far as the interval reaches, and the expansion loop
takes over from there. Whenever the palindrome around i reaches past
r, the interval re-anchors.

The dry run: the fixture is aabbaa, whose even array 0, 1, 0, 3, 0,
1 and total 11 are asserted by the C\# suite, identical in the
other six.

+ Center 0 has no left neighbor: d2\[0\] = 0 without a compare.
+ Center 1 matches the pair a, a and runs out of string: d2\[1\] =
  1, the palindrome aa, and the interval re-anchors to \[0, 1\].
+ Center 2 sits outside: the boundary a, b mismatches at once,
  d2\[2\] = 0.
+ Center 3, outside the small interval, expands on its own: b = b,
  a = a, a = a climbs the radius to 3, the whole string aabbaa, and
  the interval jumps to \[0, 5\].
+ Center 4 mirrors to 0 + 5 - 4 + 1 = 2 and starts at
  min(d2\[2\] = 0, 5 - 4 + 1 = 2) = 0, the boundary b, a confirming
  it: d2\[4\] = 0.
+ Center 5 mirrors to index 1 and starts at min(d2\[1\] = 1, 1) =
  1: the pair a, a holds and the string ends, so the cap was exact,
  d2\[5\] = 1.
+ d2 reads 0, 1, 0, 3, 0, 1 at sum 5, the odd pass contributes 11 -
  5 = 6 single characters, and the longest runs 2 × 3 = 6, the
  string itself.

#diagram([the even pass over aabbaa one center at a time, the straddling pair above, the landing d2 below, dashed arrows the mirror reuse, the two intervals spanned underneath], length: 13pt, {
  // s = aabbaa, d2 = 0, 1, 0, 3, 0, 1
  let s = ("a", "a", "b", "b", "a", "a")
  let d2 = (0, 1, 0, 3, 0, 1)
  let cx = i => 2.0 + i * 2.5
  for i in range(6) {
    let c = cx(i)
    cdraw.content((c, 7.3), [#i], size: 6pt)
    cdraw.rect((c - 0.95, 6.3), (c + 0.95, 7.0), fill: if i == 3 { luma(205) } else { luma(238) }, radius: 0.02)
    cdraw.content((c, 6.65), if i > 0 { [#s.at(i - 1) | #s.at(i)] } else { [edge] }, size: 7pt)
    cdraw.rect((c - 0.5, 3.0), (c + 0.5, 3.75), fill: if d2.at(i) > 0 { luma(205) } else { luma(240) }, radius: 0.02)
    cdraw.content((c, 3.38), [#d2.at(i)], size: 7pt)
  }
  cdraw.line((cx(2), 4.85), (cx(4), 4.85), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((cx(3), 5.1), [i = 4 mirrors 2], size: 6pt)
  cdraw.line((cx(1), 4.15), (cx(5), 4.15), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((cx(3) + 1.4, 4.4), [i = 5 mirrors 1], size: 6pt)
  cdraw.line((cx(0) - 0.5, 2.55), (cx(1) + 0.5, 2.55), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((cx(0) - 0.6, 2.3), [interval \[0, 1\]], size: 6pt)
  cdraw.line((cx(0) - 0.5, 1.95), (cx(5) + 0.5, 1.95), stroke: (paint: luma(160), dash: "dashed"))
  cdraw.content((cx(5) + 0.1, 1.7), [interval \[0, 5\]], size: 6pt)
  cdraw.content((2.0, 0.6), [sum 5, total 11, longest 2 × 3 = 6], size: 6.5pt)
})

The 0, 1, 0, 3, 0, 1 array and the 11 are pinned across the suites,
and the listings below run both passes in seven languages.

#listing("dsa/samples-c/src/Ch33/manacher.c", first: 26, last: 52, caption: [c, the odd pass and the even pass side by side over the same string])

#listing("dsa/samples-go/ch33/manacher.go", first: 9, last: 48, caption: [go, both passes inside one function, total and longest computed after])

#listing("dsa/samples-java/src/Ch33/Manacher.java", first: 24, last: 48, caption: [java, the odd pass and the even pass side by side, charAt reads throughout])

#listing("dsa/samples/src/Ch33/Manacher.cs", first: 10, last: 50, caption: [c\#, odd and even as twin methods, totals by sum, longest by max])

#listing("dsa/samples-js/src/ch33-manacher.mjs", first: 17, last: 41, caption: [javascript, the two loops with their own l and r, the queries after])

#listing("dsa/samples-py/src/Ch33/manacher.py", first: 14, last: 39, caption: [python, the two passes, the mirror index shifted by one in the even case])

#listing("dsa/samples-lua/ch33_manacher.lua", first: 7, last: 43, caption: [lua, both passes in 1-based indices, the same mirrored interval])

The queries fall out of the two arrays by arithmetic. The number of
palindromic substrings with multiplicity is sum(d1) + sum(d2), since
d1[i] counts the odd palindromes at center i one per radius and d2[i]
counts the even ones, and the longest palindromic substring has
length max over both arrays of 2 d1[i] - 1 and 2 d2[i]. The fixtures
pin abababa with d1 = 1, 2, 3, 4, 3, 2, 1 and d2 all zeros, 16
palindromic substrings, the string itself longest; abacabadabacaba
with d1 = 1, 2, 1, 4, 1, 2, 1, 8, 1, 2, 1, 4, 1, 2, 1 and total 32;
the even anchors aabaa with d2 = 0, 1, 0, 0, 1 at total 9, abba with
d2 = 0, 0, 2, 0 at total 6, aabbaa with d2 = 0, 1, 0, 3, 0, 1 at
total 11; and the small case aaa pinning both arrays, d1 = 1, 2, 1
and d2 = 0, 1, 1, at total 6. The edge family reads the empty string
at 0, a at 1, and ab at 2 with the first singleton winning ties, and
every suite cross-checks the whole batch against a brute
all-substring palindrome scan.

#diagram([aabaa centers on a rail, d1 and d2 as towers, the mirror reuse arrow from center 1 to center 3, even towers hanging between cells], length: 13pt, {
  // aabaa: d1 = [1,1,3,1,1], d2 = [0,1,0,0,1]; interval [0,4] from center 2
  let d1 = (1, 1, 3, 1, 1)
  let rail = 5.9
  for (i, c) in ("a", "a", "b", "a", "a").enumerate() {
    let x = 1.8 + i * 1.7
    let cx = x + 0.85
    cdraw.rect((x, rail), (x + 1.7, rail + 0.9), fill: luma(235), radius: 0.02)
    cdraw.content((cx, rail + 0.45), c, size: 8pt)
    cdraw.content((cx, rail - 0.35), [#i], size: 6pt)
    // odd towers above the rail, height d1[i]
    cdraw.rect((cx - 0.28, rail + 0.9), (cx + 0.28, rail + 0.9 + 0.9 * d1.at(i)), fill: if i == 2 { luma(205) } else { luma(222) }, radius: 0.02)
    cdraw.content((cx, rail + 1.15 + 0.9 * d1.at(i)), [#d1.at(i)], size: 6pt)
    // even towers hanging below the rail, straddling the i-1, i boundary
    if i > 0 {
      let ev = (0, 1, 0, 0, 1).at(i)
      let bx = x - 0.85
      cdraw.rect((bx - 0.26, rail - 0.9 * ev - 0.05), (bx + 0.26, rail - 0.05), fill: luma(215), radius: 0.02)
      if ev > 0 {
        cdraw.content((bx, rail - 0.5 - 0.9 * ev), [#ev], size: 6pt)
      }
    }
  }
  cdraw.content((5.2, rail + 4.35), [d1 towers above the rail, d2 hanging between cells], size: 6.5pt)
  // the mirrored interval [0,4] from center 2's palindrome aabaa
  cdraw.line((1.8, rail - 1.35), (10.3, rail - 1.35), stroke: (paint: luma(120), dash: "dashed"))
  cdraw.content((6.0, rail - 1.05), [interval \[l, r\] = \[0, 4\] from center 2's aabaa], size: 6pt)
  // reuse arrow: center 3's radius starts from the mirror at center 1
  cdraw.line((3.65, rail - 2.1), (8.75, rail - 2.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.2, rail - 2.45), [d1\[3\] starts at min(d1\[1\], r - 3 + 1) = 1], size: 6pt)
  cdraw.content((5.2, rail - 3.5), [total = sum(d1) + sum(d2) = 7 + 2 = 9], size: 6pt)
  cdraw.content((5.2, rail - 4.4), [longest = max(2*3 - 1, 2*1) = 5: aabaa], size: 6pt)
  cdraw.content((15.4, 5.0), [two linear passes, one per parity], size: 6pt)
  cdraw.content((15.4, 4.0), [mirror trusted only to r], size: 6pt)
  cdraw.content((15.4, 3.0), [counts with multiplicity], size: 6pt)
})

== the suffix automaton

A suffix automaton is the smallest dag whose paths from the start
spell exactly the substrings of s, built online one character at a
time. Each state is an equivalence class of right-extensions, the
endpos set, and carries three fields: len, the longest substring in
the class, link, a pointer to the class of the longest proper suffix
with a strictly larger endpos set, and a transition map by character.
Appending one character walks the suffix links from the last state
adding the new transition wherever it is missing. When the walk stops
on a state p that already has the character to some q, the split
decides the shape: if len[p] + 1 equals len[q] the classes nest
cleanly and the new state links to q, otherwise q is too fat, and a
clone with len[p] + 1, q's transitions, and q's old link is created,
every transition to q along the walk is redirected to the clone, and
both q and the new state link to it. The construction is O(n) total
and never creates more than 2n - 1 states.

The dry run: the fixture is abab, whose 5 states, 7 distinct
substrings, and occurrence counts a 2, b 2, ab 2 and its reversal 1,
aba 1, bab 1, abab 1 are asserted by the C\# suite, identical in the
other six.

+ The first a creates state 1, longest a at len 1, linked to the root.
+ The first b walks state 1 to the root adding the missing
  transitions and creates state 2, ab at len 2, linked to the root.
+ The second a stops the walk at the root's existing a into state
  1, and len 0 + 1 = 1 = len\[1\] nests cleanly: state 3 is aba at
  len 3 linked to 1, no clone.
+ The final b stops at state 1's existing b into state 2, len 1 +
  1 = 2 = len\[2\]: state 4 is abab at len 4 linked to 2, 5 states.
+ Distinct substrings telescope down the links, 1 - 0 = 1, 2 - 0 =
  2, 3 - 1 = 2, 4 - 2 = 2, and 1 + 2 + 2 + 2 = 7.
+ Occurrences bubble up the same tree: reading ab lands on state 2,
  its own append plus state 4's pushed 1 counting 1 + 1 = 2, and
  reading a lands on state 1 for 1 + 1 = 2 the same way.

#diagram([the abab automaton growing one append per frame, solid edges the transitions, dashed edges the suffix links, the new state shaded], length: 13pt, {
  // states 0..4 fixed layout, each frame shows the states alive so far
  let pos = ((2.1, 6.4), (0.9, 4.9), (3.3, 4.9), (1.8, 3.3), (3.9, 1.9))
  let trans = ((0, 1, [a]), (0, 2, [b]), (1, 2, [b]), (2, 3, [a]), (3, 4, [b]))
  let links = ((1, 0), (2, 0), (3, 1), (4, 2))
  let caps = ([after a], [after ab], [after aba], [after abab])
  for f in range(4) {
    let ox = 0.5 + f * 4.9
    let p = i => (pos.at(i).at(0) + ox, pos.at(i).at(1))
    for (a, b, lab) in trans {
      if b <= f + 1 {
        cdraw.line(p(a), p(b), stroke: luma(120))
        cdraw.content(((p(a).at(0) + p(b).at(0)) / 2 + 0.18, (p(a).at(1) + p(b).at(1)) / 2 + 0.12), lab, size: 6pt)
      }
    }
    for (a, b) in links {
      if a <= f + 1 { cdraw.line(p(a), p(b), stroke: (paint: luma(190), dash: "dashed")) }
    }
    for i in range(f + 2) {
      cdraw.circle(p(i), radius: 0.3, fill: if i == f + 1 { luma(205) } else { luma(240) }, stroke: luma(120))
      cdraw.content(p(i), [#i], size: 6pt)
    }
    cdraw.content((2.1 + ox, 7.2), caps.at(f), size: 6.5pt)
  }
  cdraw.content((0.6, 0.6), [lens 1, 2, 3, 4, telescope 1 + 2 + 2 + 2 = 7 distinct], size: 6pt)
  cdraw.content((0.6, -0.2), [the clone branch never fires on this fixture], size: 6pt)
})

The 5 states and the 7 close the build exactly as pinned, and the
listings below extend the automaton in seven languages.

#listing("dsa/samples-c/src/Ch33/suffixautomaton.c", first: 38, last: 67, caption: [c, the build with the clone split, the per-character loop])

#listing("dsa/samples-go/ch33/suffixautomaton.go", first: 26, last: 67, caption: [go, the loop with the clone branch inside])

#listing("dsa/samples-java/src/Ch33/Suffixautomaton.java", first: 39, last: 70, caption: [java, the build with the clone split, the clone copying q's 26-way transition array])

#listing("dsa/samples/src/Ch33/SuffixAutomaton.cs", first: 29, last: 65, caption: [c\#, the same loop in the constructor, the clone copying q's transitions])

#listing("dsa/samples-js/src/ch33-suffixautomaton.mjs", first: 26, last: 58, caption: [javascript, the extend method with the clone split])

#listing("dsa/samples-py/src/Ch33/suffixautomaton.py", first: 29, last: 56, caption: [python, extend as a method, the clone split in the else branch])

#listing("dsa/samples-lua/ch33_suffixautomaton.lua", first: 31, last: 64, caption: [lua, the same extend with 1-based state ids])

Two counts ride the structure. Distinct substrings telescope along
the link tree: state v contributes len[v] - len[link[v]] new
substrings, the ones whose first occurrence of their class boundary
lands in v, so the total is that difference summed over all non-root
states. Occurrence counts live on the same tree as subtree sums:
each extend state counts one endpos, clones count zero, and
processing states in decreasing len order pushes every count into its
link parent, after which walking the transitions for any t lands on
the state whose count is the number of occurrences, with membership
as count above zero. The fixtures pin the canonical machine, identical
in all seven languages: abab builds 5 states and 7 distinct substrings
with occurrences a 2, b 2, ab 2 and its reversal 1, aba 1, bab 1,
abab 1, and abc 0; aab builds 4 states, 5 distinct; banana builds 10 states, 15
distinct, with a 3, an 2, ana 2, na 2, nan 1, ban 1, banana 1, nab 0;
aa builds 3 states and 2 distinct; the scale anchors run abababa at 8
states and 13 distinct with aba occurring 3 times, and mississippi
at 18 states and 53 distinct with issi, ssi, and iss twice. The edges
read the empty string as 1 state, 0 distinct, matching nothing, and
a as 2 states, 1 distinct, and every suite cross-checks distinct
against a brute set of all substrings and occurrences against a
brute sliding count.

#diagram([the banana link tree with len labels, occurrence counts bubbling up, the endpos classes of a, ana, and na bracketed], length: 13pt, {
  // SAM(banana): 10 states; link tree with len and cnt
  let n = (x, y, lab, hot: false) => {
    cdraw.circle((x, y), radius: 0.42, fill: if hot { luma(205) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, y), lab, size: 6pt)
  }
  let e = (p, q) => cdraw.line(p, q, stroke: luma(190))
  // level layout: root 0; children 1(len1), 5(len1), 7(len2); 5 -> 2(len2), 9(len3); 9 -> 4, 8; 7 -> 3, 6
  e((9.5, 7.6), (3.2, 6.2)); e((9.5, 7.6), (7.0, 6.2)); e((9.5, 7.6), (13.4, 6.2))
  e((7.0, 6.2), (4.6, 4.8)); e((7.0, 6.2), (9.4, 4.8))
  e((9.4, 4.8), (7.7, 3.2)); e((9.4, 4.8), (11.1, 3.2))
  e((13.4, 6.2), (12.3, 4.8)); e((13.4, 6.2), (15.0, 4.8))
  n(9.5, 7.6, [0\ len0])
  n(3.2, 6.2, [1\ len1], hot: false)
  n(7.0, 6.2, [5\ len1], hot: true)
  n(13.4, 6.2, [7\ len2], hot: true)
  n(4.6, 4.8, [2\ len2])
  n(9.4, 4.8, [9\ len3], hot: true)
  n(7.7, 3.2, [4\ len4])
  n(11.1, 3.2, [8\ len6])
  n(12.3, 4.8, [3\ len3])
  n(15.0, 4.8, [6\ len5])
  // count labels bubbling
  cdraw.content((3.2, 5.55), [cnt 1: "b"], size: 6pt)
  cdraw.content((7.0, 5.55), [cnt 3: "a"], size: 6pt)
  cdraw.content((13.4, 5.55), [cnt 2: "na"], size: 6pt)
  cdraw.content((4.6, 4.15), [cnt 1: #("b" + "a")], size: 6pt)
  cdraw.content((9.4, 4.15), [cnt 2: "na", "ana"], size: 6pt)
  cdraw.content((7.7, 2.55), [cnt 1: "bana", "nana"], size: 6pt)
  cdraw.content((11.1, 2.55), [cnt 1: "banana"], size: 6pt)
  cdraw.content((12.3, 4.15), [cnt 1: "ban", "nan"], size: 6pt)
  cdraw.content((15.0, 4.15), [cnt 1: "anana"], size: 6pt)
  // brackets: endpos classes
  cdraw.content((7.0, 6.85), [( class of a )], size: 6pt)
  cdraw.content((9.4, 5.45), [( class of ana )], size: 6pt)
  cdraw.content((13.4, 6.85), [( class of na )], size: 6pt)
  cdraw.content((4.0, 0.9), [clone states 5, 7, 9 count 0, sums bubble up by decreasing len], size: 6pt)
  cdraw.content((4.0, 0.1), [distinct = sum(len[v] - len[link[v]]) = 15], size: 6pt)
  cdraw.content((17.6, 6.2), [walk transitions, read cnt], size: 6pt)
  cdraw.content((17.6, 5.2), [10 states, at most 2n - 1], size: 6pt)
  cdraw.content((17.6, 4.2), [clone keeps the classes honest], size: 6pt)
})

== the suffix tree

The suffix tree is the edge-compressed suffix trie: insert every
suffix of s + '\$' in order, and whenever a walk stops in the middle
of an edge label, split the edge at that character and hang both
tails off the new node. Nodes hold a child map keyed by the first
character of each edge, edges hold (l, r) index pairs into s, and no
substring is ever copied, which is what keeps seven implementations of
the same insertion order byte-identical in their node counts. The
terminal character makes the tree explicit, no suffix is a prefix of
another, so every leaf ends a full suffix and the tree has exactly
len(s) leaves. The build here is the honest simple one, O(n^2) worst
case, the same ruling as the suffix array of #xref-to("dsa", "tries")
at its O(n^2 log n); Ukkonen's algorithm builds the same tree in O(n)
and gets the citation rather than the port, because the queries, not
the construction, are the teaching point.

The dry run: the fixture is abab\$, whose 8 nodes, edge sum 12, 5
leaves, and 7 distinct substrings are asserted by the C\# suite,
identical in the other six.

+ The suffix abab\$ hangs whole off the root, one edge of length 5,
  and bab\$ keys on b as a fresh root child: three nodes.
+ The suffix ab\$ walks the a edge and dies at offset 2, \$ against
  a, so the edge splits into \[0, 2) plus \[2, 5), the mid node
  gains a \$ leaf, and the count reaches five nodes.
+ The suffix b\$ dies the same way on the b edge at offset 1, \$
  against a: \[1, 5) splits into \[1, 2) plus \[2, 5\), seven nodes.
+ The lone \$ is a third root child, closing at 8 nodes and 5
  leaves, with the edge sum 2 + 3 + 1 + 1 + 3 + 1 + 1 = 12.
+ Distinct substrings read 12 - 5 = 7, and the first mid node sits
  at string depth 2: ab is the longest repeat, occurring 2 times.

#diagram([the abab\$ tree growing one suffix per frame, edges labeled by the strings their index pairs spell, the two split nodes shaded], length: 13pt, {
  // one canonical layout, nodes 0..7, each frame draws the states alive so far
  let ns = ((0, 0), (-0.9, -1.6), (1.0, -1.6), (-1.6, -3.2), (-0.3, -3.2), (0.3, -3.2), (1.6, -3.2), (2.8, -1.6))
  let node = (p, kind) => cdraw.circle(p, radius: if kind == 0 { 0.15 } else { 0.22 },
    fill: if kind == 2 { luma(205) } else { luma(240) }, stroke: luma(120))
  let edge = (p, q, lab) => {
    cdraw.line(p, q, stroke: luma(130))
    cdraw.content(((p.at(0) + q.at(0)) / 2 + 0.42, (p.at(1) + q.at(1)) / 2), lab, size: 6pt)
  }
  let frames = (
    ((2.6, [3 nodes]), ((0, 1, [abab\$], 0), (0, 2, [bab\$], 0))),
    ((7.4, [5, split at \$ vs a]),
      ((0, 1, [ab], 2), (0, 2, [bab\$], 0), (1, 3, [ab\$], 0), (1, 4, [\$], 0))),
    ((12.6, [7, split again]),
      ((0, 1, [ab], 1), (0, 2, [b], 2), (1, 3, [ab\$], 0), (1, 4, [\$], 0),
       (2, 5, [ab\$], 0), (2, 6, [\$], 0))),
    ((18.0, [8 nodes, 5 leaves]),
      ((0, 1, [ab], 1), (0, 2, [b], 1), (0, 7, [\$], 0), (1, 3, [ab\$], 0),
       (1, 4, [\$], 0), (2, 5, [ab\$], 0), (2, 6, [\$], 0))),
  )
  for ((rx, cap), es) in frames {
    let at = i => (rx + ns.at(i).at(0), 6.7 + ns.at(i).at(1))
    node(at(0), 1)
    for (f, t, lab, kind) in es {
      edge(at(f), at(t), lab)
      node(at(t), kind)
    }
    cdraw.content((rx, 7.4), cap, size: 6.5pt)
  }
})

The 8 nodes, the 12, and the depth-2 ab close the run as pinned,
and the listings below insert the suffixes in seven languages.

#listing("dsa/samples-c/src/Ch33/suffixtree.c", first: 52, last: 77, caption: [c, the suffix insertion walk with the mid-edge split])

#listing("dsa/samples-go/ch33/suffixtree.go", first: 36, last: 65, caption: [go, insertSuffix with the edge relabel on split])

#listing("dsa/samples-java/src/Ch33/Suffixtree.java", first: 56, last: 80, caption: [java, insertSuffix with the mid-edge split, child arrays keyed by first character])

#listing("dsa/samples/src/Ch33/SuffixTree.cs", first: 18, last: 55, caption: [c\#, the constructor loop, the split allocating the mid node and two edges])

#listing("dsa/samples-js/src/ch33-suffixtree.mjs", first: 13, last: 44, caption: [javascript, the build loop, edges as index pairs, mid node wired in place])

#listing("dsa/samples-py/src/Ch33/suffixtree.py", first: 22, last: 49, caption: [python, build_suffix_tree, the split at k with two fresh edges])

#listing("dsa/samples-lua/ch33_suffixtree.lua", first: 21, last: 51, caption: [lua, the insertion loop inside the constructor, edges as {l, r} pairs])

Three queries ride the explicit tree. Distinct substrings are the sum
of all edge lengths minus the leaves, because each leaf edge donates
exactly the terminal character, which no real substring contains.
Occurrences of q are the leaves under the node where the walk for q
ends, a walk that stops mid-edge still counts the child's leaves.
The longest repeated substring is the label down to the deepest
internal node by string depth, since a node with two children is
exactly a substring occurring at least twice with different
continuations. The fixtures pin banana\$ at 11 nodes, edge sum 22, 7
leaves, 15 distinct, and ana as the deepest repeat at depth 3, with
occurrences a 3, ana 2, an 2, nan 1, ban 1, banana 1; abab\$ at 8
nodes, sum 12, 5 leaves, 7 distinct, ab the repeat; aaa\$ at 7 nodes,
sum 7, 4 leaves, 3 distinct, aa the repeat; and the scale anchor
mississippi\$ at 19 nodes, sum 65, 12 leaves, 53 distinct, issi the
repeat at depth 4. The lone terminal "\$" builds 2 nodes, edge sum 1,
1 leaf, 0 distinct, and every suite asserts the leaves equal len(s)
invariant and cross-checks distinct and occurrences against brute.

#diagram([the banana\$ compressed tree with (l, r) edge labels, the terminal \$ leaves ticked, the ana branch shaded as the deepest repeat], length: 13pt, {
  // tree: root{b:(0,6), a:(1,1) mid3, n:(2,4) mid2, \$:(6,6)}
  // mid3{n:(2,3) mid1, \$:(6,6)}; mid1{n:(4,6), \$:(6,6)}; mid2{a:(5,6), \$:(6,6)}
  let leaf = (x, y, lab) => {
    cdraw.circle((x, y), radius: 0.22, fill: luma(240), stroke: luma(120))
    cdraw.content((x, y), lab, size: 6pt)
  }
  let node = (x, y, lab, hot: false) => {
    cdraw.circle((x, y), radius: 0.3, fill: if hot { luma(205) } else { luma(240) }, stroke: luma(120))
    cdraw.content((x, y), lab, size: 6pt)
  }
  let el = (p, q, lab, hot: false) => {
    cdraw.line(p, q, stroke: if hot { luma(60) } else { luma(150) })
    let mx = (p.at(0) + q.at(0)) / 2
    let my = (p.at(1) + q.at(1)) / 2
    cdraw.content((mx + 0.45, my + 0.12), lab, size: 6pt)
  }
  let R = (9.0, 8.3)
  node(..R, [])
  // b leaf and \$ leaf
  el(R, (2.6, 6.7), [(0,6) b..\$])
  leaf(2.6, 6.7, [\$])
  el(R, (15.9, 6.7), [(6,6) \$])
  leaf(15.9, 6.7, [\$])
  // a branch: root a:(1,1) -> mid3
  el(R, (6.6, 6.7), [(1,1) a])
  node(6.6, 6.7, [], hot: true)
  el((6.6, 6.7), (4.9, 5.1), [(2,3) na], hot: true)
  node(4.9, 5.1, [], hot: true)
  el((6.6, 6.7), (8.4, 5.1), [(6,6) \$])
  leaf(8.4, 5.1, [\$])
  el((4.9, 5.1), (3.4, 3.5), [(4,6) na\$], hot: true)
  leaf(3.4, 3.5, [\$])
  el((4.9, 5.1), (6.4, 3.5), [(6,6) \$])
  leaf(6.4, 3.5, [\$])
  // n branch: root n:(2,4) -> mid2
  el(R, (12.3, 6.7), [(2,4) na])
  node(12.3, 6.7, [])
  el((12.3, 6.7), (11.3, 5.1), [(5,6) a\$])
  leaf(11.3, 5.1, [\$])
  el((12.3, 6.7), (13.7, 5.1), [(6,6) \$])
  leaf(13.7, 5.1, [\$])
  cdraw.content((4.9, 4.45), [mid: depth 3, the ana repeat], size: 6pt)
  cdraw.content((9.0, 9.0), [11 nodes, edge sum 22], size: 6.5pt)
  cdraw.content((17.8, 8.3), [edges are (l, r) into s], size: 6pt)
  cdraw.content((17.8, 7.3), [leaves = len(s) = 7], size: 6pt)
  cdraw.content((17.8, 6.3), [distinct = 22 - 7 = 15], size: 6pt)
  cdraw.content((17.8, 5.3), [occ(q) = leaves under arrival], size: 6pt)
  cdraw.content((17.8, 4.3), [built O(n^2) here, ukkonen O(n)], size: 6pt)
  cdraw.content((1.0, 2.2), [ticked circles are the \$ leaves], size: 6pt)
})

== lyndon factorization, least rotation, and repetitions

Three tools share one file because they share one outlook, that a
string compares against its own rotations. A lyndon word is a string
strictly smaller than every nontrivial rotation of itself, and duval's
algorithm factors s into lyndon words in non-increasing order in one
linear scan with three pointers: i opens the current factor, j walks
ahead, and k tracks the period inside the candidate. On a strict rise
s[k] below s[j] the candidate is still lyndon and k resets to i, on
an equal pair k advances with j, and when the scan stops at a fall
the factor closes with length j - k.

The dry run: the fixture is banana, whose least rotation abanan at
start 5 is asserted by the C\# suite against the brute minimum over
all rotations, identical in the other six. Duval's own walk over
abacaba stays with the figure below, this run takes the duel.

+ The duel opens at i = 0, j = 1 over the doubled banana: offset 0
  compares b against a, 0 loses at once and skips to 0 + 0 + 1 = 1,
  colliding with j, so j moves to 2.
+ Candidate 2 falls next, a against n at offset 0: j skips to 2 +
  0 + 1 = 3.
+ Candidates 1 and 3 agree through three offsets, a a, n n, a a,
  and break at offset 3, n against b: 1 loses its whole matched
  window and lands at 1 + 3 + 1 = 5.
+ Candidates 5 and 3 break at offset 1, b against n: 3 skips to 3 +
  1 + 1 = 5, collides with i, and the scan ends with the survivor
  5.
+ The rotation at 5 spells s\[5\] then s\[0..5\]: a b a n a n,
  abanan, the pinned pair.

#diagram([the least-rotation duel on doubled banana, four knockouts with the breaking pair named, each loser skipping past its matched window, the survivor shaded], length: 13pt, {
  // t = bananabanana, candidate starts 0..5
  let t = ("b", "a", "n", "a", "n", "a", "b", "a", "n", "a", "n", "a")
  for (k, c) in t.enumerate() {
    let x = 1.1 + k * 1.32
    cdraw.rect((x, 6.3), (x + 1.32, 7.1), fill: if k == 5 { luma(205) } else { luma(238) }, radius: 0.02)
    cdraw.content((x + 0.66, 6.7), c, size: 7pt)
    if k < 6 { cdraw.content((x + 0.66, 5.9), [#k], size: 6pt) }
  }
  cdraw.content((1.1, 7.7), [starts 0 through 5 of the doubled string], size: 6.5pt)
  // knockouts: (loser, winner, offset, the breaking pair)
  let kos = ((0, 1, 0, [b vs a]), (2, 1, 0, [a vs n]), (1, 3, 3, [n vs b]), (3, 5, 1, [b vs n]))
  for (j, ko) in kos.enumerate() {
    let (loser, winner, k, pair) = ko
    let y = 4.9 - j * 0.95
    cdraw.line((1.1 + loser * 1.32 + 0.66, y), (1.1 + winner * 1.32 + 0.66, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((9.8, y), [#loser falls to #winner at k = #k, #pair], size: 6pt)
  }
  cdraw.content((1.1, 0.8), [survivor 5: abanan, pinned], size: 6.5pt)
  cdraw.content((9.8, 0.8), [a loser skips k + 1 starts], size: 6pt)
})

The survivor 5 and its abanan are pinned by every suite, and the
listings below carry all three tools in seven languages.

#listing("dsa/samples-c/src/Ch33/lyndon.c", first: 28, last: 47, caption: [c, duval's three-pointer loop, the factor closing at the fall])

#listing("dsa/samples-go/ch33/lyndon.go", first: 8, last: 26, caption: [go, duval, reset k to i on a strict rise])

#listing("dsa/samples-java/src/Ch33/Lyndon.java", first: 26, last: 43, caption: [java, duval's three-pointer loop, charAt reads, the factor closing at the fall])

#listing("dsa/samples/src/Ch33/Lyndon.cs", first: 11, last: 33, caption: [c\#, the same scan, the reset and the equal-run walk commented])

#listing("dsa/samples-js/src/ch33-lyndon.mjs", first: 11, last: 31, caption: [javascript, the duval loop])

#listing("dsa/samples-py/src/Ch33/lyndon.py", first: 14, last: 30, caption: [python, duval, the two branches inside the rise-or-equal guard])

#listing("dsa/samples-lua/ch33_lyndon.lua", first: 8, last: 27, caption: [lua, the same loop in 1-based indices])

The least rotation runs the same three pointers as a duel on s + s:
two candidate starts i and j compare character by character at
offset k, and whichever loses is skipped past its whole matched
window, k + 1 positions, because none of those starts can win
either. First index wins ties, and the survivor after the duel is the
minimal rotation. The repetition scanner reads equal-pair rails: for
each period p, find the maximal segments where s[t] equals s[t + p],
and a segment \[a, b) with b - a at least p is the maximal repetition
(a, b + p - a, p) with length at least 2p. That scan is O(n^2) worst
case here, with the main-lorentz algorithm cited for O(n log n),
the same cost ruling as the suffix tree above.

The fixtures pin all three pieces identically. Duval factors ababab
into ab, ab, ab; abacaba into abac, ab, a; banana into b, an, an, a;
acacab into ac, ac, ab; and aab stays whole. The duel returns
abanan from banana at 5, ababc from abcab at 3, abacac from acacab
at 4, aketeanteaketete from teaketeteaketean at 9, and aaaa at 0.
The repetitions read banana as (1, 5, 2), the run anana; abab as
(0, 4, 2); aabaab as (0, 2, 1), (0, 6, 3), (3, 2, 1); aaaa as
(0, 4, 1) and (0, 4, 2), period 1 and period 2 both maximal; and
abcabcabc as (0, 9, 3). The cross-checks are the strictest in the
chapter: every emitted factor is verified lyndon against its own
rotations, the factor sequence non-increasing, the duel against the
brute minimum over all rotations, and the repetition scan against an
independent brute
enumerator, with the javascript suite adding its own 150 seeded
random strings on top. Java runs the brute twins over its named
families: every duel checked inside checkRotation against the
minimum over all rotations, every repetition table against the
independent enumerator.

The application is icpc world finals 2022 problem Y (book 10,
chapter 11), compression, where a square-free reachability argument is the contest
face of repetition detection; the problem's answer reasoning stays
with the icpc book.

#diagram([duval's three pointers walking abacaba with the three factors boxed, and the p = 2 equal-pair rail of banana highlighting anana as the repetition (1, 5, 2)], length: 13pt, {
  // abacaba -> [abac, ab, a]
  let s = ("a", "b", "a", "c", "a", "b", "a")
  for (i, c) in s.enumerate() {
    let x = 1.4 + i * 1.5
    let band = if i < 4 { 0 } else if i < 6 { 1 } else { 2 }
    cdraw.rect((x, 6.3), (x + 1.5, 7.2), fill: (luma(235), luma(215), luma(228)).at(band), radius: 0.02)
    cdraw.content((x + 0.75, 6.75), c, size: 8pt)
  }
  cdraw.content((1.4 + 1.5 * 2, 5.85), [abac], size: 6.5pt)
  cdraw.content((1.4 + 1.5 * 5 + 0.75, 5.85), [ab], size: 6.5pt)
  cdraw.content((1.4 + 1.5 * 6 + 0.75, 5.85), [a], size: 6.5pt)
  // pointer rail mid-scan: i = 0, k = 1, j = 3, the moment a < c resets k
  cdraw.content((1.4 + 0.75, 5.1), [i], size: 6.5pt)
  cdraw.content((1.4 + 1.5 * 1 + 0.75, 5.1), [k], size: 6.5pt)
  cdraw.content((1.4 + 1.5 * 3 + 0.75, 5.1), [j], size: 6.5pt)
  cdraw.content((8.6, 4.4), [equal pairs b = b, a = a advance k with j], size: 6pt)
  cdraw.content((8.6, 3.6), [the strict rises a < b, then b < c reset k = i], size: 6pt)
  cdraw.content((8.6, 2.8), [j runs off the end with k = 3: the factor is length j - k = 4, abac], size: 6pt)
  // banana rail: p = 2 equal pairs, anana shaded
  let b = ("b", "a", "n", "a", "n", "a")
  for (i, c) in b.enumerate() {
    let x = 1.4 + i * 1.5
    let hot = i >= 1
    cdraw.rect((x, 1.4), (x + 1.5, 2.3), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 0.75, 1.85), c, size: 8pt)
  }
  // equal-pair marks: s[t] == s[t+2] for t = 1..4
  for t in range(1, 5) {
    let x1 = 1.4 + t * 1.5 + 0.75
    let x2 = 1.4 + (t + 2) * 1.5 + 0.75
    cdraw.line((x1, 1.25), (x2, 1.25), stroke: (paint: luma(120), dash: "dashed"))
  }
  cdraw.content((5.5, 0.7), [segment \[1, 5) with b - a = 4 >= p = 2], size: 6pt)
  cdraw.content((5.5, 0.0), [repetition (1, 4 + 2 - 1, 2) = (1, 5, 2): anana], size: 6pt)
  cdraw.content((16.2, 6.75), [factors: lyndon, non-increasing], size: 6pt)
  cdraw.content((16.2, 5.75), [duval and the duel: O(n)], size: 6pt)
  cdraw.content((16.2, 4.75), [repetition scan O(n^2) here], size: 6pt)
  cdraw.content((16.2, 3.75), [main-lorentz: O(n log n), cited], size: 6pt)
  cdraw.content((16.2, 1.85), [length >= 2p per repetition], size: 6pt)
})

== across the seven languages

Featured build size counted as non-blank, non-comment lines of the
chapter's five sample files per language, go test files excluded:

#table(
  columns: (auto, auto, 1.5fr, 2.2fr),
  inset: 4pt,
  table.header([*language*], [*build sloc*], [*container dependency*], [*boundary note*]),
  [c], [848], [static arrays, 26-way transition table], [z and manacher over fixed buffers, the sam child array per state, insertion-order suffix tree],
  [go], [404], [slices, `sort.Slice`], [sam link-tree order sorted by len, the duel and scan as free functions],
  [java], [805], [jdk 27 stdlib, String.charAt walks], [per-state int[26] sam transitions cloned by array copy, the \\x01 separator as a char constant, insertion-order suffix tree over child arrays],
  [c\#], [397], [`List<Dictionary<char,int>>`, linq], [long z arrays, occurrence counts precomputed in the constructor],
  [javascript], [304], [`Map` transitions, private class fields], [plain string compare throughout, the randomized cross-check family seeded by an lcg],
  [python], [564], [dict transitions, inline asserts], [the extend method split out, brute twins per family],
  [lua], [654], [tables, string.byte keys], [1-based storage over 0-based reported positions, the shift documented at the boundary],
)

sources: cp-algorithms, "Z-function",
cp-algorithms.com/string/z-function.html, "Manacher's Algorithm -
Finding all sub-palindromes in O(N)",
cp-algorithms.com/string/manacher.html, "Suffix Automaton",
cp-algorithms.com/string/suffix-automaton.html, "Suffix Tree",
cp-algorithms.com/string/suffix-tree-ukkonen.html, whose linear-time
ukkonen construction is cited in prose while the naive insertion is
what ships, "Lyndon factorization",
cp-algorithms.com/string/lyndon_factorization.html, covering duval
and the least-rotation duel, and "Finding repetitions",
cp-algorithms.com/string/main_lorentz.html, the O(n log n) reference
for the period scan, all accessed 2026-09-20, cc by-sa 4.0, our own
words and code throughout. Application sources: icpc world finals
2023 problem F and 2022 problem Y (book 10). Sample behavior verified
by the seven suite gates scoped to chapter 33: c 5 files and 147
checks, go 16 test functions, java 5 files and 147 checks under
run-java-samples, c\# 24 facts, javascript 19 tests and
119 asserts, python 5 files and 333 asserts, lua 19 checks, zero
skipped.
