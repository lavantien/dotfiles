// chapter 41: one problem in eight lanes, byte-identical output, the
// corpus method turned on a performance question
#import "../../theme/lib.typ": listing, callout, xref-to, diagram, cdraw

= the one billion row challenge

One problem, eight lanes, one line of output. The 1brc challenge
aggregates a billion `station;temperature` rows into a single sorted
map of minimum, mean, and maximum per station, and this chapter runs
it in c, go, java, c sharp, javascript, python, lua, and sqlite,
stdlib only in every lane, 21 variants in all, with identical output
bytes on every artifact any of them is pinned against. Every claim
elsewhere in this book was proven with a test. Here the test still
comes first, a byte diff against a pinned oracle for every variant,
and only then a stopwatch explains what correctness already bought.

The order is the order the work demands. The contract and its
arithmetic come first, because one wrong rounding rule costs more
than any speedup. The sqlite lane follows, where the aggregate lives
in a query instead of a loop. Then the seven program lanes in the
corpus canonical order, each walking its own decision ladder with
the measured ratios attached. The full-scale table closes, where the
memory shape of each road decides who finishes at all.

== the challenge and its rules [DRILL]

The contest lives at 1brc.dev with the repository at
github.com/gunnarmorling/1brc, both accessed 2026-10-08 and cited in
the sources footer. The input is a text file of rows, one per line,
`name;value`, where the value carries exactly one fractional digit
and lands in [-99.9, 99.9], and the name is UTF-8, 1 to 100 bytes
long, containing no `;` and no newline, with at most 10k distinct
names. The output is
exactly one line, here the committed fixture's own opening:

{Abha=-0.8/16.9/28.9, Abidjan=-3.6/24.0/42.0, ...}

Stations sort by name, every number carries one decimal digit, and
`, ` separates entries. The contest scored wall time on a fixed
box. This chapter scores something else first: byte-exactness
against the official output contract, then wall time as commentary.

The official artifacts are pinned verbatim under `tools/1brc/ref/`,
fetched from the repository at main with sha256 records:
`CreateMeasurements.java`, the data generator, 413 hardcoded
`WeatherStation(name, mean)` records with the station drawn
uniformly per row and the value `round(gaussian(mean, 10) * 10) /
10` from ThreadLocalRandom, which cannot be seeded. Then
`CalculateAverage_baseline.java`, the reference solution whose
rounding shape pins the output contract, plus the 12 official sample
pairs under `ref/samples/` that this corpus validates against. The
repository also keeps an earlier pre-fix rounding variant of the
reference solution, explicitly history, not the spec.

Our generator mirror is `tools/1brc/create_measurements.py`. It
keeps the official semantics, uniform station draw, gaussian
centered on the station mean with standard deviation 10, rounded to
tenths with the same half-up rule, but drives them from the corpus
64-bit Knuth LCG `x' = 6364136223846793005 * x +
1442695040888963407 mod 2^64` with Box-Muller for the gaussian, so
every run is byte-identical, which ThreadLocalRandom cannot offer.
Two divergences are stated rather than hidden: the LCG plus
Box-Muller replaces `nextGaussian`, and the station pick takes the
full state mod 413, a bias below 2^-52. The 413-station corpus is
transcribed once into `stations.csv`.

The tier ladder keeps honest scale discipline. The committed gate
fixture is 10k rows over the 413-station corpus,
`ch41-fixture/measurements-10k.txt` with its byte-exact expected
twin, plus the edge battery `edges.txt`, 37 rows over 11 stations,
pinning the exact-half asymmetry, minus zero, both range rails, BMP
sort order, prefix families, and the solo station. Two more
batteries closed the blind attack round at the end of the wave:
`edges-astral.txt`, 5 rows, separates supplementary-plane names
from a private-use name so codepoint order and UTF-16 unit order
disagree and the gate sees which one each lane actually sorts by,
and `edges-malformed.txt`, one semicolon-less row among valid ones,
which every lane must reject with a nonzero exit and empty stdout.
The 10^7 tier is
generated on demand under the gitignored data dir and never
regenerated mid-wave. The 10^9 input, 13795438436 bytes, about
13.8 GB, is built once on measurement day, verified, and deleted.
Gates never touch it, the sizing discipline of
#xref-to("repertoire", "estimation-answers") applied to a test
ladder.

Every lane gates the same way: byte diff against the committed
fixtures, the comparison trimming the line terminator on both sides
because text-mode stdio on windows ends the line with `\r\n` in
nine of the lanes, a split the divergence paragraph below pins. The
c, java, lua, and sqlite variants ride `tools/run-1brc.ps1`, which
compiles or invokes each lane, diffs stdout against all three
fixtures, and adds two must-fail legs: every runner variant has to
reject `edges-malformed.txt` with a nonzero exit and empty stdout,
and the two fixed-window tuned roads, c and java, have to reject a
generated row longer than their 1 MiB window instead of silently
folding it and dropping the rest of the file. The go, c sharp,
and javascript lanes ride the book's wildcard suites with real test
files, 15 go test functions under vet and the race detector, 29
xunit facts expanding to 33 cases, 35 node --test cases, and the
python lane carries 60 plain asserts in `test_onebrc.py` executed
by the runner's py leg.

== the exact arithmetic [TDD]

The official reference solution is a double pipeline. Values parse
with `Double.parseDouble`, min, max, and sum accumulate as doubles,
the mean is `sum / count`, and printing applies `round(x) =
Math.round(x * 10.0) / 10.0`, where `Math.round` is `floor(v +
0.5)`, half-up toward plus infinity. A float pipeline over money
would be a defect, and the money-is-cents law of
#xref-to("repertoire", "db-answers") says why. Here the same shape
is exact, and the proof is the chapter's first discovery.

Every input is `k/10` for an integer `k`, so the running double sum
tracks the exact rational `sum_tenths / 10`. The exact mean is a
rational whose denominator is the
station's row count, so it either sits exactly on a half integer or
keeps a distance of at least `1 / (2 * count)` from one. At the
official sample scale the accumulated noise sits orders of magnitude
below that gap. At the full 10^9 scale the honest statement is
narrower: per-station sums reach the 1e8 range, where the worst-case
bound for a pathological summation order tightens to the gap's own
order, while the random arrival order a real stream produces keeps
the drift about four orders below it, and the official evaluation
produced its own expected output through this same double pipeline,
so no artifact either side can check separates the two roads.
`round(sum * 10.0)` therefore lands
on the exact integer tenths sum on every input a fixture can pin,
and the printed mean is always `floor(sum_tenths / count
+ 1/2)`. The double pipeline is exact rational arithmetic in
disguise at any checkable scale, so every lane computes it in
integers and removes the question entirely:

`mean_tenths = (2 * sum_tenths + count) // (2 * count)`

Floor division, exact, and order-independent, since integer sums
commute and merge order cannot move a byte of output. The oracle
`tools/1brc/reference_average.py` implements exactly this and
validates byte-exact against all 12 official sample pairs,
re-verified 12 of 12 while writing this chapter. The oracle is
binary end to end for a reason the wave itself hit: its first
text-mode version crashed on a cp1252 console that refused the
station names and wrote `\r\n` under a windows redirect, so it now
reads bytes and writes through `sys.stdout.buffer`, byte-exact by
construction on any console and any redirect, which is what lets
the 12-of-12 claim say byte and mean it.

The floor is asymmetric on purpose. `floor(x + 0.5)` rounds halves
toward plus infinity: a mean of +0.05 prints 0.1 while -0.05 prints
0.0. The edge battery pins it twice over, station `a` with rows 0.0
and 0.1 printing 0.1 against station `aa` with rows -0.1 and 0.0
printing 0.0, and the six-row mix pair doing the same at three
tenths above and below zero. This is neither banker's rounding nor
half away from zero, and the sqlite lane below shows a database
whose `round()` does the latter, which is why the REAL column road
is banned there.

Minus zero needs one sanitation rule. A `-0.0` row parses to the
integer 0, integer tenths carry no negative zero, and 0 formats as
`0.0`, never `-0.0`. In the reference solution the same effect
arrives for free because `Math.round` returns a long, and a long has
no negative zero either.

Floor division is load-bearing in languages that truncate. C, java,
c sharp, and javascript divide integers toward zero, so each lane
bumps the quotient when the remainder is negative, `Math.floorDiv`
in java, a hand-written `floor_div` in c. The `neg` station in the
edge battery is the pin: rows 1.2, -3.4, and 0.1 sum to -21 tenths
over 3 rows, the numerator is -39 over 6, truncation says -0.6, the
floor says -0.7, and the pinned output is -0.7.

Sorting is byte order in disguise. Stations sort by codepoint
order, which equals UTF-8 byte order on well-formed input, which is
what `memcmp`, go and python byte comparison, and sqlite BINARY
collation all already do. The trap belongs to three languages whose
native string comparison walks UTF-16 code units: java, c sharp, and
javascript all equal codepoint order for BMP names and split from it
for supplementary characters, where a surrogate pair sorts below
U+E000. The first cuts of this chapter's java naive, c sharp naive,
and both javascript variants sorted that way, caught by the closing
attack round: on supplementary names they disagreed with the byte
lanes, and java and c sharp even disagreed with their own tuned
variants. Every variant now ends in a byte or codepoint comparison,
the tuned lanes over raw UTF-8, java naive through
`Arrays.compareUnsigned` on the encoded bytes, c sharp naive through
a UTF-8 byte comparer, javascript through an allocation-free
`codePointAt` walk. The official corpus and the
fixture are BMP-only, and `measurements-20` among the official samples
carries supplementary characters, emoji and a racing car appended to 19
station names, but as an identical suffix on every name, a shape where
UTF-16 unit order still coincides with codepoint order, so no official
artifact distinguishes the two orders. The committed astral battery
does, and the gate runs it on every variant. The edge battery that
pins the rest of this is 37
lines:

#listing("interview-repertoire/samples/ch41-fixture/edges.txt", first: 1, last: 37, caption: [the edge battery: the half asymmetry in a against aa and mix against mixn, minus zero, both rails, bmp sort, prefix families, the solo station])

== the sqlite lane [TDD]

The aggregate can live in a query. Both scripts import the text
file through the official 3.53.4 shell and print the one-line map,
byte-diffed by the runner against both fixtures. The import shape
is shared: `.mode csv` with `.separator ';'` splits each row, UTF-8
names pass through as raw bytes, and the import is wrapped in one
`BEGIN`/`COMMIT` because per-row autocommit would fsync per row,
the file-level locking story of #xref-to("infrastructure",
"sqlite-transactions"). Both schemas also declare their columns
`NOT NULL`, which makes this the loud lane on malformed rows: a
line with no `;` imports a NULL temperature, the constraint
rejects it, and `.bail on` aborts the throwaway build with a
nonzero exit and empty stdout instead of aggregating NULL tenths
into silent garbage.

The textbook road is banned before it starts. A REAL temperature
column finished with `round(avg(temp), 1)` is wrong twice: sqlite's
`round()` is half-away-from-zero, so +0.05 prints 0.1 while -0.05
prints -0.1 against the contract's 0.1 and 0.0, and `avg()` sums
binary floats, which the aggregate contract forbids. Storing REAL
and re-deriving tenths is no escape either, since
`CAST(temp * 10 AS INTEGER)` truncates a product that can sit an
ulp below the integer. So both scripts keep the value as TEXT and
parse it with `CAST(digit-text AS INTEGER)`, an exact
decimal-text-to-integer conversion, plus `unicode(digit) - 48` for
the single fractional digit.

The parse carries a sign trap. `-99.9` is `-(99*10 + 9) = -999`,
not `-99*10 + 9 = -981`, so the whole tenths value is negated,
never the integral part alone. The `-0.0` row hides the bug, 0
either way, and the `-99.9` row exposes it. Both ride the edge
battery. Integer division is the second trap, probed on the pinned
shell: `/` on two integers truncates toward zero and `%` takes the
dividend's sign, so the mean is `quot - (rem < 0)`, the same bump
every other lane writes. The naive script parses at query time:

#listing("interview-repertoire/samples/ch41-sqlite/naive.sql", first: 66, last: 101, caption: [query-time tenths from text, the floored mean with the remainder bump, group_concat in station order])

The tuned script's junction is where the tenths parse runs. A
`GENERATED ALWAYS AS ... STORED` column declared in the schema
makes `.import` itself produce the integer, computed once per row
at insert, so the query becomes a pure integer scan and the
database artifact is worth keeping. The two alternatives were
measured at the 10^7 tier and rejected: a staging pass into a
`WITHOUT ROWID` table lands the same pure scan but pays a second
full write pass and leaves the dropped staging table's pages at
the high-water mark, a 422 MB file against the shipped shape's
232 MB, and a covering index
on `(station, tenths)` makes the GROUP BY stream in index order
but costs more to build than the sort it saves, 27.82 s total
against the shipped shape. `temp_store = MEMORY` was screened too,
21.94 s, 61 percent over the shipped total, rejected because the
full-scale sort spill would then sit in RAM.

#listing("interview-repertoire/samples/ch41-sqlite/tuned.sql", first: 62, last: 81, caption: [the pragma ladder, the stored tenths column, one transaction around the import])

The pragma ladder is three lines and every one is load-bearing.
`page_size = 8192` before the first table trims about one level
off the b-tree depth for a wide append, `cache_size = -262144`
holds 256 MiB of pages,
and `synchronous = OFF` drops the per-commit fsync a throwaway,
rebuildable database does not need. `journal_mode` and
`locking_mode` are skipped for a stricter reason than speed: they
are row-returning pragmas, they print result rows, and
`journal_mode = off` also refuses to engage in-script on this
shell build, printing `delete`, so emitting either would corrupt
the one-line stdout contract.

Measured at 10^7 on the re-measured box: naive 13.9 s total against
tuned 14.5 s, the two totals inside box variance of each other at
this tier, though the stream-day box had tuned ahead, 13.67 against
16.03. The phases still tell the tuned story: run as separate
import and query halves, naive spends 5.39 s importing and 9.20 s
querying while tuned spends 7.24 s importing and 4.13 s querying,
the stored column moving about 1.9 s of parsing from query to
import and cutting the query to less than half, the same trade a
materialized view makes. The tuned halves sum under the one-process
total because a standalone query rides the page cache the import
just warmed, one more reason the full-scale run, one process per
variant, is the number that decides: 1923 s against 2400 s there,
0.80x, with database files of
23.6 GB against 21.1 GB, the stored column's price.

== c: the window and the table [EWC]

C has no standard hash map, and that absence is the lane's story.
The naive road, 100 sloc, is `fopen` plus `fgets` one line at a
time, `sscanf` for the value, a flat station array walked by
`strcmp` on every row, `qsort` at the end: 5.473 s at 10^7 and
808.4 s at 10^9, match both times, exact arithmetic throughout,
since the contract forbids binary floats even on the slow road.

The tuned ladder, 186 sloc, makes three decisions. Reading: one
1 MiB `fread` window swept in place, `memchr` to each newline and
semicolon, the partial tail carried to the front on refill so a
name is never split across window edges. Parsing: character
arithmetic into integer tenths, no float, no libc call. The
dictionary: an open-addressing table with FNV-1a over the raw name
bytes and linear probing, built insert-or-find only, because
names repeat all day and a station is never deleted, so there are
no tombstones and no delete path at all:

#listing("interview-repertoire/samples/ch41-c/onetuned.c", first: 49, last: 74, caption: [insert-or-find with linear probing, the name copied into the arena once on first sight, the 65k length cap dying loudly])

Each name is copied into a 4 MiB byte arena exactly once, on first
sight, and the slot arrays are parallel, offset and length apart
from the accumulators, so a probe walk touches cache lines that
hold nothing but keys. The window sweep that feeds it:

#listing("interview-repertoire/samples/ch41-c/onetuned.c", first: 157, last: 204, caption: [the fread window: memchr to the newline, the partial tail carried to the front, the one-byte probe past a full window, the final line without its newline])

The window guards its own edges, a defect class the closing attack
round exposed in three lanes: when a full window holds no newline,
a one-byte probe past it decides between a true end of file, which
folds the window as one final line, and more file, which dies as a
row longer than the window instead of silently discarding
everything after it. The same round found the arena's 16-bit slot
length silently truncating names past 65535 bytes, which now dies
too, far outside the contract's 100-byte bound.

`floor_div` is load-bearing exactly as the arithmetic section
pinned, c's `/` truncates toward zero and the `neg` station needs
the bump. `_CRT_SECURE_NO_WARNINGS` silences the ucrt deprecation
warnings the clang plus msvc-header lane emits. The ladder stops
at the serial tuned road: 0.423 s at 10^7, 12.9x over naive, and
58.6 s at 10^9. The window-plus-carry shape below is the one the
whole chapter shares, the pattern the c sharp and javascript lanes
would adopt mid-wave when their whole-file roads hit the wall:

#diagram([one window swept in place, the tail carried forward, cuts snapped past newlines], length: 13pt, {
  // top: the input strip with nominal cuts snapped forward past newlines
  cdraw.rect((0.6, 8.5), (22.8, 9.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((11.7, 8.95), [the input, one long strip of rows], size: 6pt)
  for x in (6.4, 12.2, 18.0) {
    cdraw.line((x, 8.5), (x, 7.8), stroke: (paint: luma(170), dash: "dashed"))
    cdraw.line((x, 8.0), (x + 1.0, 8.0), stroke: luma(100), mark: (end: ">"))
    cdraw.circle((x + 1.0, 8.0), radius: 0.09, fill: luma(60))
  }
  cdraw.content((11.7, 7.3), [a nominal cut snaps just past the next newline, no row is ever split], size: 6pt)
  // bottom left: one window, carried tail plus one read
  cdraw.line((4.2, 6.6), (4.2, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.9, 6.15), [swept in place], size: 6pt)
  cdraw.rect((0.8, 3.0), (14.8, 5.4), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.rect((0.8, 3.0), (3.4, 5.4), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((2.1, 4.2), [carried tail], size: 6pt)
  cdraw.content((9.1, 4.85), [one read, up to 1 MiB], size: 6pt)
  cdraw.content((9.1, 3.9), [complete rows parsed in place], size: 6pt)
  cdraw.rect((13.0, 3.0), (14.8, 3.7), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((18.6, 4.6), [the partial row], size: 6pt)
  cdraw.content((18.6, 3.8), [rides the next sweep], size: 6pt)
  cdraw.line((13.9, 3.0), (13.9, 2.3), stroke: luma(100))
  cdraw.line((13.9, 2.3), (2.1, 2.3), stroke: luma(100))
  cdraw.line((2.1, 2.3), (2.1, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.7, 1.7), [c fread, go Read, java readNBytes, cs FileStream, js readSync,], size: 6pt)
  cdraw.content((11.7, 1.0), [py read, lua read: the same shape in every lane], size: 6pt)
})

== go: map against table, measured [EWC]

The go ladder keeps both dictionary roads and measures the gap
instead of asserting it. The naive road, 110 sloc, is
`bufio.Scanner` handing one allocated string per line to
`strings.Cut` and a stdlib map, 0.670 s at 10^7 and 91.6 s at 10^9,
match both times. The tuned scan is the chapter's shared window in
go form, one 1 MiB raw `Read` walked with `bytes.IndexByte`, the
carry `copy` moving the partial tail to the front, and the buffer
doubling whenever a pathological single line fills it without a
newline:

#listing("interview-repertoire/samples/ch41-go/onetuned.go", first: 39, last: 87, caption: [one raw window walked with indexByte, the carry memmove, the doubling escape for a line longer than the window])

`scanLines` takes an `io.Reader` and consumes it with plain `Read`,
which is what lets the sharded road hand it an `io.SectionReader`
over the same file with zero changes. The value folds into integer
tenths by byte arithmetic at the scan site, zero allocation per
line. The dictionary junction: `OnetunedMap` keeps the stdlib map,
probing with `agg[string(name)]`, the one compiler-blessed
allocation-free bytes-to-string conversion, while `Onetuned` swaps
in a slice-backed open-addressing table with FNV-1a, linear
probing, and an append-only name arena:

#listing("interview-repertoire/samples/ch41-go/onetuned.go", first: 148, last: 176, caption: [the slice-backed table: fnv probe, arena span, grow on load, the entry pointer stable across appends])

Measured at 10^7 on the re-measured quiet box, the scan and parse
swap bought 51 percent, naive
0.670 s down to the map road's 0.326 s, and the table swap lost
ground right there, 0.378 s, 16 percent behind the map. The
stream-day box, loaded by a foreign six-core process, had flipped
the tier the other way, table 0.519 s ahead of the map's 0.587 s,
and full scale put the map back ahead, 42.1 s against 53.3 s on
the same 413-station input. Two boxes, two orderings at the tier:
dictionary micro-tuning is load- and tier-sensitive, so measure at
the scale and on the box you ship. Both variants stay gated, which
is why the flips were seen
at all.

The final junction is `OnetunedSharded`, 325 sloc total for the
tuned file. Nominal cuts at `size * i / shards` snap forward past
the next newline with 4 KiB probes, one scanner goroutine per
GOMAXPROCS slot scans its `io.SectionReader` shard through the same
`scanLines`, and `mergeFrom` folds shard tables by exact integer
sums, race-clean under `go test -race`, the goroutine discipline of
#xref-to("repertoire", "go-runtime"). 0.057 s at 10^7, 11.8x over
naive, and 7.7 s at 10^9.

== java: byte windows and a pinned charset [EWC]

The java naive road, 63 sloc, is `Files.readString` plus `split`
plus a `HashMap<String, long[]>`: 1.557 s at 10^7, then dead in
0.3 s at 10^9 with `Required array size too large`, the 2^31 cap
on a single array. The tuned road, 236 sloc, reads through a
`FileChannel` behind a 1 MiB window, probes stations by raw name
bytes with FNV-1a and parallel slot arrays, and parses tenths by
byte arithmetic.

Output is a charset decision before it is a speed decision.
`System.out` encodes with the platform codepage when redirected,
so the naive variant pins a UTF-8 `PrintStream` over
`FileDescriptor.out` and the tuned variant writes raw bytes
straight through `System.out.write`, untouched by any charset.
The fixture stations include non-ASCII names, so this pin is not
cosmetic: the same class of failure surfaced while re-verifying
the oracle for this chapter, a cp1252 console refusing the station
names until the interpreter ran UTF-8.

The parallel junction splits the file into byte ranges, one
`scanRange` per worker on an `ExecutorService` fixed pool above a
4 MiB threshold. The align rule is the subtlety: a worker with a
nonzero start must land on a line boundary first, and reading from
`start - 1` makes a boundary already sitting on a line start eat
one byte instead of one line:

#listing("interview-repertoire/samples/ch41-java/Onetuned.java", first: 138, last: 164, caption: [the align rule: read from start minus one, discard through the newline, the window carried like the c lane's])

Merging absorbs each shard table by exact integer sums, so shard
arrival order cannot move the output:

#listing("interview-repertoire/samples/ch41-java/Onetuned.java", first: 41, last: 60, caption: [absorb folds a finished shard by exact integer sums, min and max widened, sums and counts added])

The window carries the same guard the c lane learned: a full
window with no newline probes one byte past it through the
channel, and a byte there means a row longer than the window, an
`IOException`, never a silent fold that drops the rest of the
file.

Measured: 0.159 s wall at 10^7 with the 20-thread junction on,
9.8x over naive, spending 1.484 s of cpu, roughly three and a half
times the c lane's cpu for two fifths of its wall, the junction's
whole story. At 10^9 on a loaded box, 7 s wall against 84 s cpu.

== c sharp: byte keys and snapped cuts [EWC]

The c sharp naive road streams: `File.ReadLines` yields per-line
strings into a `Dictionary`, 0.921 s at 10^7 and 69.7 s at 10^9,
match both times, because `ReadLines` never holds the file. The
tuned road, 288 sloc, opens a `FileStream` with `bufferSize: 1`,
so the window reads go straight to the OS without a second
buffering layer, sweeps a 1 MiB window with span `IndexOf` for
the newline and semicolon, and folds tenths by byte arithmetic.

The dictionary is byte-keyed: FNV-1a over the raw UTF-8 name
bytes, linear probing, 16384 slots for the 10k-station contract,
load factor near 0.61 before any growth. Each slot keeps the
canonical `byte[]` and its decoded `string` as a pair, both
allocated on first sight and never per row, and the final sort
compares the UTF-8 bytes directly, which is codepoint order, no
detour needed:

#listing("interview-repertoire/samples/ch41-cs/src/Onetuned.cs", first: 282, last: 301, caption: [the byte-keyed probe and fnv-1a over utf-8 name bytes, the pair claimed on the empty slot])

The final junction snaps and merges. Nominal cuts walk forward to
the byte after a newline through small positional reads, rows are
short so one 4 KiB probe is almost always enough and the loop only
exists for honesty, then `Parallel.For` scans each part through
its own window and table, and the calling thread merges with exact
integer arithmetic, `Console.Out.Write` all the way, never
`WriteLine`:

#listing("interview-repertoire/samples/ch41-cs/src/Onetuned.cs", first: 85, last: 122, caption: [snapped line bounds, parallel.for over per-part windows and tables, merge on the calling thread])

This lane paid for the chapter's sharpest lesson. Its first tuned
road, like javascript's, read the whole file, and the 2 GB cap on
a single array only speaks up at 10^9: the fix rebuilt both lanes
on the c lane's windowed chunks with carry regressions added to
the suites, told with the full-scale table below. Measured after
the fix, Release builds: 0.363 s tuned at 10^7, 2.5x over naive,
0.114 s parallel, 8.1x, and at 10^9, 26.7 s tuned, 2.7 s parallel.

== javascript: the map that stays [EWC]

The javascript naive road, 84 sloc, is `readFileSync` as one utf8
string, `split` per line and per field, a `Map` keyed by station.
At 10^9 it does not die quickly, it dies slowly, killed at the
commit cap mid grind with 14.9 GB resident, the slow-death version
of the read-all wall. The tuned road, 213 sloc, keeps the same
`Map` and changes everything around it: positional `readSync` into
a 1 MiB `Buffer` window, `Buffer.indexOf` riding memchr for the
newline and the semicolon, tenths off the raw byte codes, and the
name decoded to a string once per row as the map key:

#listing("interview-repertoire/samples/ch41-js/src/onetuned.mjs", first: 139, last: 179, caption: [one row: the semicolon bounded inside the row, the value shape checked in the fold, tenths off byte codes, the map keyed by the decoded name])

Both roads validate the row shape as they parse, a hardening the
closing attack round forced. The first tuned cut searched for the
semicolon without bounding it to the row, so a semicolon-less line
made it invent station names containing newlines and exit 0, and
the naive cut spun forever on a value with no dot, `charCodeAt`
past the end returning NaN forever. The semicolon now has to land
inside the row, the value has to be an optional minus, digits, one
dot, one digit, then the row end, and anything else dies loudly
with a nonzero exit.

The per-row decode is deliberate, and it is the lane's measured
negative result: v8 hashes a string once and caches the hash on
the canonical instance, so the built-in `Map` answers each probe
without rehashing, and a javascript-level open-addressing table
re-implements interning the runtime already provides, loses, and
costs sloc. The other lanes' table builds buy real cache locality
on parallel slot arrays, and this lane's honest tuned:naive is
1.05x, 2.005 s against 2.098 s at 10^7, v8's string machinery
already at the floor: the serial tuned road pays for its window
with the same per-row decode the naive road gets nearly for free
from `split`, and the serial ladder buys essentially nothing until
the worker junction.

The final junction is `worker_threads`: bounds snapped forward
past newlines by the parent with one small `readSync` window per
cut, each worker reading its isolated range into its own buffer,
the parent merging exact integer sums, `process.stdout.write`,
never `console.log`. Workers are capped at 8. Measured: 0.374 s at
10^7, 5.6x over naive, and 38.1 s wall against 301.4 s cpu at
10^9.

== python: bytes windows, processes at the end [EWC]

The python naive road, 65 sloc, is text-mode `readlines`, one
`str` per line into a dict, exact integer tenths all the way.
9.035 s at 10^7, then `MemoryError` at 99.7 s at 10^9. The tuned
road, 173 sloc, reads 1 MiB bytes chunks, finds `;` and `\n` with
`bytes.find`, and folds the value into tenths straight from the
bounds, never materializing the value as a slice. The dict is
keyed by the bytes name slice, hashed as bytes, skipping the UTF-8
decode for all but the 10k first sights, and decoded once per
station at render:

#listing("interview-repertoire/samples/ch41-py/onetuned.py", first: 49, last: 90, caption: [absorb folds a line by bounds with no value slice, scan walks chunks with find and a carry])

The serial ladder buys 1.16x, 7.771 s at 10^7. That is the honest
ceiling of pure-python parsing, the interpreter is the floor, and
the measurement says so instead of hiding it. The win is the final
junction: `--parallel` snaps spans past newlines with a 4096-byte
probe, one process per span on a `ProcessPoolExecutor`, the gil
forcing the process boundary the other lanes do not need,
#xref-to("repertoire", "python-answers"). 1.381 s at 10^7, 6.5x
wall, while cpu inflates to 14.4 s across 20 workers, wall time
bought with cpu. At 10^9: 138 s parallel against 1222.6 s serial.

== lua: interning is the hash map [EWC]

Lua's lane, 44 and 88 sloc, is the smallest, and its decisions are
mostly about what not to build. The naive road is `io.lines`, one
string per row behind the stdio buffer, `string.match` for the
split, `tonumber` on digit text as an exact text-to-integer
conversion, a plain table, `table.sort` at the end: 8.589 s at
10^7 and 1271.9 s at 10^9, match both times, because `io.lines`
streams.

The tuned road reads 1 MiB blocks with `file:read(CHUNK)` and
scans them with plain-mode `string.find`, which runs at C speed
over the block while the interpreter pays per row only for the
handful of bytes that matter. The value parses from `string.byte`
arithmetic into lua 5.5 integers, no substring, no `tonumber`, no
float. The map is a plain table keyed by the station string, and
that is the junction: lua interns short strings, up to 40 bytes,
and every corpus name fits, so the per-row `sub` either finds the
interned copy or interns it once, and the stats lookup rides an
already-hashed key. A custom open-addressing map keyed by the raw
byte range would save one `sub` per row and re-implement the
intern table the language already gives, measured not worth it in
stdlib lua:

#listing("interview-repertoire/samples/ch41-lua/onetuned.lua", first: 56, last: 115, caption: [plain-mode find over the block, string.byte tenths validated in the fold, the interned table key, the carry returned as the tail])

Formatting is integer math end to end, `magnitude // 10` and
`magnitude % 10`, never a float, and the sort rides `string <`,
which is strcmp byte order in every lua, locale never involved,
verified by
file probe on this box. Two divergences are stated: argv with
non-ASCII bytes is mojibake here, so the fixture is referenced by
path only, and the parallel road is honestly absent. Stdlib lua
5.5 has no threads and no process spawning, and coroutines are
cooperative on one OS thread, so they cannot shorten wall time.
The tuned fold validates the value shape now, the closing attack
round's fix for a fold that once read the next row's first byte
as the fraction digit, and the strictness costs about 0.19 s at
this tier, measured against the pre-validation binary on the same
box.
The ladder tops out at 3.202 s at 10^7, 2.7x over naive, and
422.1 s at 10^9, serial. That absence is the lane's own lesson:
the final junction belongs to the language, and lua's stdlib
simply does not carry one.

== the full-scale table [TDD]

Two tables, two disciplines. The 10^7 tier is best of 3,
re-measured wholesale on a quiet box the day the closing hardening
round ended, so every cell shares one day and one box, the number
a reader can reproduce on any machine with the generator; the
streams' first pass had run on a box loaded by a foreign six-core
process, where cells ran up to nearly 80 percent slower, the
memory-bound lanes most. The 10^9 measurement day is one run per
variant on that loaded box,
the number that tells the truth about memory shape. The input is
13795438436 bytes, the expected line from the reference
aggregator. Wall seconds, sloc is non-comment non-blank:

#table(
  columns: (auto, auto, auto, auto, auto, auto, auto),
  inset: 4.5pt,
  align: (left, right, right, right, right, right, center),
  table.header[*lane*][*naive s*][*tuned s*][*tuned:naive*][*parallel s*][*parallel:naive*][*sloc n/t*],
  [c], [5.473], [0.423], [12.9x], [-], [-], [100/186],
  [go], [0.670], [0.378], [1.8x], [0.057], [11.8x], [110/325],
  [java], [1.557], [0.159], [9.8x], [(same build)], [(same)], [63/236],
  [c sharp], [0.921], [0.363], [2.5x], [0.114], [8.1x], [88/288],
  [javascript], [2.098], [2.005], [1.05x], [0.374], [5.6x], [84/213],
  [python], [9.035], [7.771], [1.16x], [1.381], [6.5x], [65/173],
  [lua], [8.589], [3.202], [2.7x], [absent], [-], [44/88],
  [sqlite], [13.9], [14.5], [0.96x], [-], [-], [44/46],
)

Three rows carry footnotes. The java tuned figure is the 20-thread
junction already on, the 10^7 file clears the 4 MiB threshold. The
go tuned figure is the table variant, with the map intermediate at
0.326 s. The sqlite figures are one-process totals, with the
import and query halves measured separately at 5.39 plus 9.20 for
naive and 7.24 plus 4.13 for tuned, the query alone at 0.45x. C
sharp rows are Release builds, the Debug numbers on the stream-day
box for the record are 117.8, 104.5, and 9.8.

The full-scale table, one run per variant, wall and cpu seconds,
tree cpu for the parallel lanes:

#table(
  columns: (auto, auto, auto, auto, 1.3fr),
  inset: 4.5pt,
  align: (left, left, right, right, left),
  table.header[*lane*][*variant*][*wall s*][*cpu s*][*outcome*],
  [c], [onenaive], [808.4], [803.3], [match],
  [c], [onetuned], [58.6], [58.2], [match],
  [java], [Onenaive], [0.3], [-], [out of memory: Files.readString, required array size too large],
  [java], [Onetuned], [7], [84], [match, 20-thread junction],
  [go], [onenaive], [91.6], [94.1], [match],
  [go], [onetuned-map], [42.1], [41.5], [match],
  [go], [onetuned-table], [53.3], [53], [match, map wins at full scale],
  [go], [onetuned-sharded], [7.7], [71], [match],
  [c sharp], [onenaive], [69.7], [68.8], [match, streaming ReadLines, Release],
  [c sharp], [onetuned], [26.7], [26], [match, windowed chunks, Release],
  [c sharp], [onetuned-parallel], [2.7], [43.6], [match, snapped Parallel.For cuts, Release],
  [javascript], [onenaive], [824], [818.5], [killed at the commit cap, 14.9 GB resident mid read-all grind],
  [javascript], [onetuned], [194.2], [191.4], [match, windowed chunks],
  [javascript], [onetuned-workers], [38.1], [301.4], [match, windowed worker shards],
  [python], [onenaive], [99.7], [94.4], [MemoryError at readlines],
  [python], [onetuned], [1222.6], [1213.6], [match],
  [python], [onetuned-parallel], [138], [1968.4], [match],
  [lua], [onenaive], [1271.9], [1265], [match],
  [lua], [onetuned], [422.1], [419.9], [match],
  [sqlite], [naive], [2400], [2209.8], [match, db 21.1 GB],
  [sqlite], [tuned], [1923], [1895], [match, db 23.6 GB, 0.80x total],
)

The read-all wall is this table's own lesson. Java dies in 0.3 s on
the 2^31 array cap, javascript grinds at 14.9 GB resident until
killed, python hits `MemoryError` at 99.7 s, while the streaming
naive roads, c `fgets`, go scanner, c sharp `ReadLines`, lua
`io.lines`, and every streaming import finish. The challenge is a
memory-shape problem before it is a speed problem.

One dating note: these rows are the measurement-day binaries,
taken before the closing attack round's parse validation, window
guards, and sort comparators landed. The 10^7 table above carries
the hardened binaries, where lua's added validation costs about 6
percent, isolated against the pre-validation binary in
back-to-back runs on the same box, and the c and java guards run
once per file and the comparators once per station, below noise.

#callout("pitfall", "the tier a gate never sees", [
  The tuned c sharp and javascript roads originally read the whole
  file too. Both passed every gate, both measured clean at the
  10^7 tier, and both were wrong about the only tier that counts:
  the 2 GB caps on a single array and a single Buffer only speak
  up at 10^9. The fix, commits `9bc2b19f` and `c386646e`, rebuilt
  both on the c lane's windowed chunks and added small-window
  carry regressions to the suites, 28 of 28 and 25 of 25 then,
  33 of 33 and 35 of 35 after the closing round's astral and
  malformed cases, so the
  failure class now fails small. A fixture gate cannot see what
  only the full-scale input exposes, which is why the measurement
  day exists and why these rows name their dead honestly.
])

== the divergences that stay [TDD]

Malformed input is out of contract, and the fleet's answer to it
is pinned rather than assumed. Structurally broken rows, a missing
semicolon, a value with no dot, a row longer than a fixed window,
die loudly everywhere: the runner's must-fail leg holds a nonzero
exit and empty stdout for all ten variants it gates, and the c
sharp and javascript suites carry the same cases. Value text that
violates only the shape splits the fleet, and the split is the
lesson: the oracle, python, and go reject `1.20` outright,
javascript and lua tuned reject it after the hardening, while the
c, java, and c sharp tuned roads fold it to 1.2 and sqlite reads
only the final digit, so the one-fractional-digit rule is enforced
by the lanes that parse text strictly and merely survived by the
rest. Blank lines are rejected by the oracle and silently skipped
by the naive java and javascript roads, one more reason the
contract, not the lane, is the arbiter.

Two splits ride the input's bytes rather than its rows. A `\r`
inside a station name is legal by the official letter and divides
text-mode line readers, where c, c sharp, and python naive, plus
the oracle's first text-mode cut, died, from the byte readers that
keep it as data. A leading BOM is stripped by c sharp naive's
`File.ReadLines` while every byte lane keeps it in the first
name. So the chapter pins LF-terminated, BOM-free files as the
input shape it teaches. The final newline splits by stdout mode:
nine lanes write through windows text-mode streams and end
`}\r\n` when redirected, c both, java naive, python both, lua
both, and sqlite both, while the byte-writing lanes, tuned java,
go, c sharp, and javascript, end `}\n` like every official
sample. That is why the gate's diff trims the terminator on both
sides and why the byte claim in this chapter's opening lives on
the payload.

sources: the challenge rules, the reference solution, the data
generator, the shell wrappers, and all 12 sample pairs are pinned
verbatim from 1brc.dev and github.com/gunnarmorling/1brc at main,
both accessed 2026-10-08, kept under `tools/1brc/ref/` with sha256
records. sqlite behavior was probed directly on the corpus-pinned
3.53.4 shell rather than read from documentation, the lua collation
claim was verified by file probe, and every language claim in the
lane sections is pinned by the lane's own source under
`samples/ch41-*/` and its gate. No other online source was
consulted for this chapter.
