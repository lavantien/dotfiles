#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the java toolbox

Java enters the contest between go and c\# in the corpus reading order,
and its toolbox is the seventh. The standard library is deep enough
that nothing here hand-builds a container: the heap, the ring deque,
the hash map, and the balanced tree all ship, arbitrary precision ships
as `BigInteger`, and the work is fluency plus two measured disciplines.
One is input: `Scanner` is banned on judge inputs because its regex
machinery costs 1.4 to 1.6 times the buffered pair over a 4 MB fixture
on a quiet box, 2.4 to 2.8 under load, so the reader is `BufferedReader`
under a word-configured `StreamTokenizer` and the writer is a
`StringBuilder` flushed by one write. The other is the 64-bit boundary: products that can leave long
range travel as `Math.multiplyHigh` plus the low half with a
shift-subtract remainder, the same lane the dsa book opened, and
`BigInteger` appears exactly where c writes `__int128`. The kit is 771
non-blank lines over 6 files carrying 50 ok-line checks, every number
in this chapter measured on this machine under the pinned oracle jdk
27.

== fast input and output

The reader is two objects deep. `BufferedReader` amortizes the syscalls
into 8 KB characters, and a `StreamTokenizer` over it, configured
word-style, splits on whitespace and hands every token back as a string
in `sval`. The configuration is the whole trick: by default the
tokenizer parses digit runs into the double `nval`, and a double loses
the low bits of any long past 2^53, so the kit calls `resetSyntax`,
declares digits, the minus sign, and letters to be word characters, and
parses numbers itself through `Long.parseLong`. `Scanner` looks like
the same job and is not: every `hasNextLong` runs its delimiter regex
over the stream.

The dry run: `Fastio` builds a 4154731-byte fixture of 420000 numbers,
ten per line, from the corpus lcg, then reads it both ways.

+ Both readers return the identical checksum, the sum of all 420000
  values, pinned against the value tracked while generating.
+ Warm, then the minimum of 3 timed passes, three fresh JVMs, on a
  quiet box: Scanner 95.5 to 114.8 ms against the buffered pair's
  65.9 to 70.9 ms.
+ The ratio holds at 1.4 to 1.6x: the extra ~35 ms per input is real
  wall clock, multiplied by every case file a finals submission reads,
  and the gap widens under load, the same fixture measuring 2.4 to
  2.8x while four sibling suites compile on the same machine.

#table(
  columns: (1.5fr, 1fr, 1.2fr, 1.2fr, 1.2fr),
  inset: 4pt,
  table.header([*fixture*], [*tokens*], [*scanner*], [*buffered*], [*verdict*]),
  [4154731 bytes, lcg], [420000], [95.5 to 114.8 ms], [65.9 to 70.9 ms], [1.4 to 1.6x quiet, 2.4 to 2.8x loaded, Scanner banned],
)

The writer is the mirror discipline, the one-write law: accumulate
everything into a `StringBuilder`, convert once, write once, flush
once. Interactive problems are the exception the year chapters handle
with an explicit flush per turn, never by abandoning the builder.

#listing("icpc/samples-java/src/Ch04/Fastio.java", first: 38, last: 51, caption: [the word config, digits and minus and letters become words, nval never fires])

#listing("icpc/samples-java/src/Ch04/Fastio.java", first: 53, last: 71, caption: [nextToken nulls at TT_EOF, hasNext peeks through pushBack, longs parse exactly])

#listing("icpc/samples-java/src/Ch04/Fastio.java", first: 81, last: 101, caption: [the one-write writer, one StringBuilder, one flush, byte count known])

The timed main pins the law in checks rather than in prose: both
readers must return the checksum, and the one-write flush must carry
exactly the builder's bytes:

#listing("icpc/samples-java/src/Ch04/Fastio.java", first: 157, last: 176, caption: [the timed comparison and the one-write check, min of 3 after warmup])

== the token scanner discipline

Three contracts live in `Tokens.java`. The first is the `nval` trap
stated as a check: the default syntax reads 9007199254740993, which is
2^53 + 1, and hands back 9007199254740992, the double one ulp below
it. The word config reads the same token through `Long.parseLong` and
spans the full signed range, `Long.MAX_VALUE` and `Long.MIN_VALUE`
round-tripping exactly.

The dry run: the mixed-type fixture `3 alpha -7 12 beta`, then the
nine-line group fixture the go toolbox pins.

+ The count-first loop reads 3, then consumes exactly three typed
  fields, a word length and two numbers, summing 5, -7, 2.
+ `pushBack` rewinds one token, the peek idiom `hasNext` is built on,
  and the third read past the last token returns `TT_EOF`.
+ Nine lines with three blanks fold to three groups, `a1 a2`, `b1`,
  `c1 c2 c3`, the doubled blank opening nothing.
+ Two blanks alone fold to zero groups, never one empty group, and a
  page with no trailing blank still flushes its last group.

#table(
  columns: (1.6fr, 1.5fr, 1.3fr),
  inset: 4pt,
  table.header([*token*], [*default nval, cast to long*], [*word config*]),
  [9007199254740993], [9007199254740992, one ulp low], [exact, 2^53 + 1],
  [9223372036854775807], [9.223372036854778e18, saturating cast], [exact by parse],
  [-9223372036854775808], [-9.223372036854778e18, saturating cast], [exact by parse],
)

#listing("icpc/samples-java/src/Ch04/Tokens.java", first: 22, last: 43, caption: [the trap demonstrated on the default syntax, then the word config that avoids it])

#listing("icpc/samples-java/src/Ch04/Tokens.java", first: 56, last: 75, caption: [blank lines are seams, maximal non-blank runs become groups])

Blank-line groups are the shape the 2019 chapter's board pairs and the
2022 chapter's multi-test blocks parse with, and `readLines` keeps the
blanks because the splitter needs them, the same refusal to lose
information the go toolbox states. The wider io story, channels and
streams and encodings, belongs to #xref-to("java", "io").

== big integers, the 128-bit roads

Java is the only toolbox in this set with arbitrary precision in the
standard library, so the c `__int128` sites, and the javascript `BigInt`
sites beside them, map to `BigInteger` directly. The contest law is
narrower: long arithmetic everywhere it fits, the 128-bit product as
`Math.multiplyHigh` plus the wrapped low half, and the remainder
through a 128-step unsigned shift-subtract loop. That loop is the dsa
book's mulmod lane restated for contest shape, built there with
`BigInteger.mod` as referee and the same anchor, 2^100 mod 1e9 + 7 =
976371285.

#diagram([routing a product past 64 bits: the fast lane when hi is zero, the shift-subtract lane for mulmod, BigInteger when the value itself overflows], length: 13pt, {
  cdraw.content((11.2, 8.1), text(size: 6.5pt)[a product of two longs])
  cdraw.rect((7.2, 5.5), (15.2, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((11.2, 6.6), text(size: 6pt)[multiplyHigh plus the low half])
  cdraw.content((11.2, 5.95), text(size: 6pt)[the exact 128-bit product, no allocation])
  cdraw.content((11.2, 5.1), text(size: 6pt)[does the value itself fit a long?])
  cdraw.line((8.2, 4.85), (3.4, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.2, 4.85), (19.0, 3.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.2, 5.2), text(size: 6pt)[yes])
  cdraw.content((17.0, 5.2), text(size: 6pt)[no])
  cdraw.rect((0.4, 1.8), (6.4, 3.9), fill: luma(205), radius: 0.02)
  cdraw.content((3.4, 3.5), text(size: 6pt)[hi = 0 certifies it])
  cdraw.content((3.4, 2.85), text(size: 6pt)[plain longs from there])
  cdraw.content((3.4, 2.15), text(size: 6pt)[mulmod only when a modulus waits])
  cdraw.rect((15.0, 1.8), (22.8, 3.9), fill: luma(205), radius: 0.02)
  cdraw.content((18.9, 3.5), text(size: 6pt)[BigInteger])
  cdraw.content((18.9, 2.85), text(size: 6pt)[the c `__int128` sites, 25! onward])
  cdraw.content((18.9, 2.15), text(size: 6pt)[value, not intermediate, overflows])
  cdraw.rect((7.0, 0.4), (14.4, 1.7), fill: luma(245), radius: 0.02)
  cdraw.content((10.7, 1.3), text(size: 6pt)[the shift-subtract lane])
  cdraw.content((10.7, 0.65), text(size: 6pt)[128 steps, unsigned compare, zero allocations])
  cdraw.line((6.4, 2.15), (8.6, 1.7), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
})

The dry run: `Big.java` runs the roads against each other.

+ `modpow(2, 100, 1e9+7)` returns 976371285 and `BigInteger.TWO.pow(100)
  .mod(...)` agrees, the anchor every language pins.
+ 200 lcg pairs under 1e9+7: the shift-subtract `mulmod` matches the
  `BigInteger` referee on every one.
+ `multiplyHigh` plus the low half rebuilds 123456789 x 987654321
  exactly, the low half joining through its unsigned decimal, because
  `or`-ing a negative `BigInteger` is the infinite-sign trap.
+ `hi = 0` certifies a product that fit, and plain longs take over.
+ The unsigned laws: `parseUnsignedLong` reads 2^64 - 1 into a negative
  long, `toUnsignedString` prints it back, `remainderUnsigned` divides
  the past-2^63 long correctly, and a `compareUnsigned` comparator
  puts 2^64 - 1 after 5.

#listing("icpc/samples-java/src/Ch04/Big.java", first: 19, last: 42, caption: [multiplyHigh plus the low half, then the 128-step unsigned shift-subtract remainder])

#listing("icpc/samples-java/src/Ch04/Big.java", first: 43, last: 53, caption: [modpow rides mulmod, squaring never truncates])

#listing("icpc/samples-java/src/Ch04/Big.java", first: 104, last: 118, caption: [the unsigned laws as checks, parse, print, divide, order])

The from-scratch limb machinery the c and lua toolboxes build, because
their libraries ship nothing, is chapter material here too:
#xref-to("icpc", "toolbox-c") carries the base-1e9 limb dissection and
#xref-to("icpc", "fastarith") ports it to java in this wave. The number
theory underneath the anchor belongs to #xref-to("dsa", "numtheory"),
and the language-level treatment of the type lives in
#xref-to("java", "types").

== collections mapping

The mapping is one-to-one because the library did the work:
`PriorityQueue` is the binary heap behind c's hand-rolled one,
comparator-injected; `ArrayDeque` is stack, queue, and sliding window
in one ring; `HashMap` counts; `TreeMap` iterates sorted with successor
queries. Two laws come with them. The heap is not stable, so equal
priorities drain in arbitrary order unless a sequence counter rides in
the comparator, the same counter idiom the python toolbox pins.
And boxed collections cost: sorting 200000 values runs 0.11 to 0.12 ms
on `int[]` against 0.36 ms on `Integer[]`, about 3x, so hot paths take
primitive arrays.

The dry run: `Coll.java` drains its heaps and windows.

+ The min-heap of tasks zoe 2, mia 1, lea 2, ada 1 drains ada, mia,
  lea, zoe, priority first with the name breaking ties.
+ `Comparator.reverseOrder()` makes the max-heap: 3, 1, 4, 1, 5 yields
  the top three 5, 4, 3.
+ Four equal-priority tasks drain a, b, c, d under the seq counter,
  first-in-first-out, the order the bare heap does not promise.
+ The window over 4, 2, 6, 1, 5 tracks the running max 4, 4, 6, 6, 6.
+ Two equal `Pt(2, 3)` records collapse to one map entry at value 9,
  while the array-keyed map misses the lookup entirely, identity
  equality against value equality.

#diagram([equal priorities, the sequence decides: the bare heap leaves equal elements in arbitrary order, the stamped comparator restores arrival order], length: 12pt, {
  cdraw.content((5.6, 8.2), text(size: 6.5pt)[equal priorities, fifo anyway])
  let rows = ((1, 0, "a"), (1, 1, "b"), (1, 2, "c"), (1, 3, "d"))
  for (i, r) in rows.enumerate() {
    cdraw.rect((1.0, 6.8 - i * 0.95), (6.6, 7.7 - i * 0.95), fill: luma(235), radius: 0.02)
    cdraw.content((3.8, 7.25 - i * 0.95), text(size: 6pt)[(prio 1, seq #(r.at(1)), #r.at(2))])
  }
  cdraw.content((9.6, 6.3), text(size: 6pt)[same priority])
  cdraw.content((9.6, 5.35), text(size: 6pt)[the tick decides])
  cdraw.content((5.6, 3.6), text(size: 6pt)[pops: a, then b, then c, then d])
  cdraw.content((5.6, 2.7), text(size: 6pt)[no arbitrary order between equals])

  cdraw.content((18.4, 8.2), text(size: 6.5pt)[records key by value])
  cdraw.rect((12.4, 6.0), (15.0, 7.0), fill: luma(225), radius: 0.02)
  cdraw.content((13.7, 6.5), text(size: 6pt)[Pt(2, 3)])
  cdraw.rect((15.4, 6.0), (18.0, 7.0), fill: luma(225), radius: 0.02)
  cdraw.content((16.7, 6.5), text(size: 6pt)[Pt(2, 3)])
  cdraw.line((15.0, 6.5), (15.4, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.4, 5.2), text(size: 6pt)[two literals, one entry, value 9])
  cdraw.rect((12.4, 3.0), (15.0, 4.0), fill: luma(245), radius: 0.02)
  cdraw.content((13.7, 3.5), text(size: 6pt)[int[]{2, 3}])
  cdraw.rect((15.4, 3.0), (18.0, 4.0), fill: luma(245), radius: 0.02)
  cdraw.content((16.7, 3.5), text(size: 6pt)[int[]{2, 3}])
  cdraw.content((18.4, 2.2), text(size: 6pt)[identity equals, the lookup misses])
  cdraw.content((18.4, 1.3), text(size: 6pt)[records give the tuple for free])
})

#listing("icpc/samples-java/src/Ch04/Coll.java", first: 40, last: 59, caption: [the min-heap by record fields, reversed order for the max-heap])

#listing("icpc/samples-java/src/Ch04/Coll.java", first: 60, last: 72, caption: [the seq counter, equal priorities drain first-in-first-out])

#listing("icpc/samples-java/src/Ch04/Coll.java", first: 106, last: 122, caption: [records key by value, array keys by identity, the pitfall closed])

The heap under `PriorityQueue`, sift up and sift down, is built from
scratch in #xref-to("dsa", "heaps"), and the full container tour,
including the streams this kit does not need, is
#xref-to("java", "collections"). Records themselves are
#xref-to("java", "classes") material.

== the judge invocation and the jvm facts

Every java solver in the year chapters carries one main with two modes.
An argument means judge mode: read the file at `args[0]`, solve, print
the answer exactly as the judge expects, one single write, no ok lines.
Bare means self-check mode: the same solve core over crafted fixtures,
one `ok N name` line per passing check, exit 1 on the first failure.
The harness compiles the chapter directory once with the pinned jdk
under `tools/jdk27` and invokes `java -cp build/ChNN Class case.in` per
case, byte-comparing stdout against the `.ans` file, so the one-write
law is the whole output contract.

The dry run: `Judge.java` demonstrates both legs on a sum-the-input
core.

+ The bare leg runs the core through string readers: 7 -2 5 to 10,
  2^63 - 1 exactly, the empty case to 0.
+ The argv leg writes a temp file `100 200 300 -50`, reads it back
  through the same `solveSum`, and prints 550.
+ The proof goes one level deeper: the file spawns `java -cp ... Judge
  tmp.in` as a real process, and the captured stdout is 550 and
  nothing else, no ok lines, exit 0.

#listing("icpc/samples-java/src/Ch04/Judge.java", first: 24, last: 37, caption: [the solve core every mode shares, count line then longs])

#listing("icpc/samples-java/src/Ch04/Judge.java", first: 49, last: 57, caption: [the dual-mode dispatch, one argument means judge mode])

#listing("icpc/samples-java/src/Ch04/Judge.java", first: 74, last: 91, caption: [the process-level proof, a spawned judge run byte-compared])

The JVM facts ride the same file's sibling `Jvm.java`, measured here,
never estimated:

#table(
  columns: (1.5fr, 1.7fr, 1.5fr),
  inset: 4pt,
  table.header([*probe*], [*command*], [*measured*]),
  [bare startup], [`java -version`, median of 5], [53 ms],
  [default stack], [recurse to overflow, child jvm], [22774 frames],
  [deep stack], [`-Xss512m`, same probe], [33506905 frames],
  [collectors], [the GarbageCollectorMXBeans], [G1 Young, Concurrent, Old],
  [serial fallback], [`-XX:+UseSerialGC` on the churn], [52 ms against 51 ms],
)

#listing("icpc/samples-java/src/Ch04/Jvm.java", first: 37, last: 57, caption: [the spawn helper, child jvms so parent frames never pollute the counts])

#listing("icpc/samples-java/src/Ch04/Jvm.java", first: 110, last: 125, caption: [the probes as checks, startup, depth, collectors])

Startup at 53 ms means the JVM appears once per case file and the
budget holds. The default stack dies at 22774 frames, so the deep dfs
families that recurse per cell take `-Xss512m`, worth three orders of
magnitude here. The default collector reports as G1 through the MXBeans
and `-XX:+UseSerialGC` is the fallback: parity on this box's churn,
52 against 51 ms, single-threaded and lower-footprint where the
default's threads contend. The deeper runtime story, memory model and
GC mechanics, is #xref-to("java", "runtime"); the jdk pin itself is
#xref-to("java", "toolchain").

== built here, cited elsewhere

Six kit files, 771 non-blank lines, 50 checks, and the split between
what this toolbox owns and what the standard library already ships:

#table(
  columns: (1.7fr, 1.2fr, 1.9fr),
  inset: 4pt,
  table.header([*piece*], [*status*], [*where*]),
  [buffered reader, one-write writer], [built, `Fastio.java`], [5 checks, Scanner measured and banned],
  [token discipline, group seams], [built, `Tokens.java`], [9 checks, the nval trap pinned],
  [128-bit product roads], [built, `Big.java`], [12 checks, `multiplyHigh` over the shift-subtract lane],
  [heap, deque, maps, records], [cited], [`PriorityQueue` and friends, 11 checks in `Coll.java`],
  [dual-mode judge demo], [built, `Judge.java`], [8 checks, the spawned-run proof],
  [jvm facts], [built, `Jvm.java`], [5 checks, startup, stack, collectors measured],
)

The comparison against the other six toolboxes: c and lua hand-build
heaps, deques, big integers, and md5 because their libraries ship
none of it, go wraps `container/heap` and `math/big` behind generics,
c\# leans on `System.Numerics` and LINQ, javascript writes its own
heap and ring, and python imports its way past all of it. Java's kit
is the second lightest after python's, and its two hand-built pieces
are disciplines rather than containers: the measured input pair and
the measured invocation contract.

sources: docs.oracle.com envelope pages for `StreamTokenizer`,
`Scanner`, `BigInteger`, `Math.multiplyHigh`, the unsigned `Long`
family, `PriorityQueue`, `ArrayDeque`, `HashMap`, `TreeMap`, and
records in the java 27 api specification, accessed 2026-10-06. Contest
context from the ICPC Foundation, icpc.global world finals problem
pages, accessed 2026-10-06. Sample behavior verified by
`pwsh -NoProfile -File tools/run-java-samples.ps1 -SampleRoot
books/icpc/samples-java/src -Chapter Ch04`, 50 checks across the 6 kit
files (Fastio 5, Tokens 9, Big 12, Coll 11, Judge 8, Jvm 5).
