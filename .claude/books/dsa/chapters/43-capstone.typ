#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= capstone: storage engine toolkit

The capstone is a log-structured storage engine with a live dashboard:
puts and deletes, crash recovery, prefix scans, compaction, and an
htmx 4 web face over it. Every piece is a chapter of this book doing
its job under a real workload, and every file sits under 260 lines.

== the integrity layer

Every byte written to disk gets a CRC-32 frame, the table-driven
reflected polynomial, so bit rot and torn writes are detected rather
than silently parsed:

#listing("dsa/capstone/src/Engine/Crc32.cs", first: 4, last: 39, caption: [crc 32 with the extension form for multi frame checksums])

Above it sits the bloom filter. Chapter 25 teaches the structure
from scratch, double hashing with two FNV-1a seeds through the
kirsch-mitzenmacher sum, so this chapter keeps only the engine-grade
half: the sizing math that picks bits and hashes from the target
false positive rate, about one percent here, and the byte
serialization that carries the filter inside every segment, header
plus raw words. No false negatives ever is the property the read
path leans on, one memory probe replacing an index search:

#listing("dsa/capstone/src/Engine/Bloom.cs", first: 12, last: 54, caption: [sizing from the false positive rate, serialization to bytes and back])

The tests pin the reference vectors, walk every single-bit flip of a
sample buffer, verify no false negative over ten thousand keys, and
measure the realized false positive rate against the design point.

#diagram([the two defenses stacked, the bloom filters point reads, the crc detects what actually opens], length: 13pt, {
  // a point read enters the bloom, a maybe falls to the framed entry
  cdraw.content((11.0, 8.0), [two defenses, distinct jobs], size: 6.5pt)
  cdraw.line((1.0, 6.6), (2.4, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.0, 7.35), [point read], size: 6pt)
  let bits = (2, 5, 6, 9, 13)
  for i in range(16) {
    cdraw.rect((2.6 + i * 0.55, 6.375), (3.15 + i * 0.55, 6.825), fill: if i in bits { luma(205) } else { luma(235) }, radius: 0.02)
  }
  cdraw.content((16.5, 6.6), [filters point reads first], size: 6pt)
  cdraw.line((3.4, 6.3), (3.4, 5.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.1, 5.8), [a maybe falls through], size: 6pt)
  cdraw.rect((2.6, 4.625), (3.85, 5.175), fill: luma(235), radius: 0.02)
  cdraw.content((3.225, 4.9), [len], size: 6pt)
  cdraw.rect((3.85, 4.625), (5.1, 5.175), fill: luma(235), radius: 0.02)
  cdraw.content((4.475, 4.9), [crc], size: 6pt)
  cdraw.rect((5.1, 4.625), (11.4, 5.175), fill: luma(205), radius: 0.02)
  cdraw.content((8.25, 4.9), [payload], size: 6pt)
  cdraw.content((16.5, 4.9), [detects rot and torn writes], size: 6pt)
  cdraw.content((11.0, 3.5), [no false negatives, about 1 percent false positives], size: 6pt)
  cdraw.content((11.0, 2.4), [detect and filter are different jobs], size: 6pt)
  cdraw.content((11.0, 1.3), [one memory probe replaces an index search], size: 6pt)
  cdraw.content((11.0, 0.2), [nine of ten segments never open], size: 6pt)
})

== the write-ahead log

Writes append framed records to a log before anything else happens:
`[len][crc][payload]`, payload carrying the operation, the key, and
the value. The flush call is `FileStream.Flush(flushToDisk: true)`,
the durability flag, not the buffer-only flush:

#listing("dsa/capstone/src/Engine/Wal.cs", first: 5, last: 24, caption: [the record and the op vocabulary])

#listing("dsa/capstone/src/Engine/Wal.cs", first: 48, last: 86, caption: [append one durable frame, read back with truncation tolerance])

The reader is where crash semantics live. A frame whose length runs
past the end of the file is a torn tail, a crash mid append, and it
is ignored. A frame whose crc fails is corruption, and everything
after it is untrusted. The tests simulate both by truncating and
flipping bytes in a written log, and recovery keeps exactly the
records that were intact.

The flush path obeys the same discipline in the other direction:
`WriteRun` fsyncs a finished segment before the engine truncates
the wal that covers it, because a reset wal over a lost segment
loses writes with no error anywhere. The fsync itself is not
unit-assertable from user code, so the test pins the invariant it
protects: it deletes the wal by hand after a flush and reopens, and
every flushed key still reads.

#diagram([the wal frame anatomy and the reader's two refusals, a torn tail stops the read, a bad crc untrusts the rest], length: 13pt, {
  // [len][crc][payload] over [op][klen][key][vlen][value], then a log with a torn third frame
  cdraw.content((11.0, 8.0), [the frame and its two refusals], size: 6.5pt)
  cdraw.rect((2.6, 6.75), (3.7, 7.25), fill: luma(235), radius: 0.02)
  cdraw.content((3.15, 7.0), [len], size: 6pt)
  cdraw.rect((3.7, 6.75), (4.8, 7.25), fill: luma(235), radius: 0.02)
  cdraw.content((4.25, 7.0), [crc], size: 6pt)
  cdraw.rect((4.8, 6.75), (14.1, 7.25), fill: luma(205), radius: 0.02)
  cdraw.content((9.45, 7.0), [payload], size: 6pt)
  let seg = (x0, x1, s) => {
    cdraw.rect((x0, 5.85), (x1, 6.35), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 6.1), s, size: 6pt)
  }
  seg(4.8, 6.1, [op])
  seg(6.1, 8.1, [klen])
  seg(8.1, 9.8, [key])
  seg(9.8, 11.8, [vlen])
  seg(11.8, 14.1, [value])
  cdraw.content((11.0, 5.1), [the flush call is flushToDisk, not buffer only], size: 6pt)
  cdraw.rect((2.6, 3.65), (5.4, 4.15), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 3.9), [frame 1], size: 6pt)
  cdraw.rect((5.4, 3.65), (8.2, 4.15), fill: luma(235), radius: 0.02)
  cdraw.content((6.8, 3.9), [frame 2], size: 6pt)
  cdraw.rect((8.2, 3.65), (9.4, 4.15), fill: luma(235), radius: 0.02)
  cdraw.rect((9.4, 3.65), (10.8, 4.15), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((8.8, 3.9), [f3], size: 6pt)
  cdraw.content((4.0, 2.9), [a torn tail is a crash mid append], size: 6pt)
  cdraw.content((4.0, 1.8), [stop there, keep the intact prefix], size: 6pt)
  cdraw.rect((12.3, 1.5), (15.5, 2.0), stroke: luma(100), radius: 0.02)
  cdraw.line((12.3, 1.5), (15.5, 2.0), stroke: luma(160))
  cdraw.line((12.3, 2.0), (15.5, 1.5), stroke: luma(160))
  cdraw.rect((12.45, 1.6), (15.35, 1.9), fill: white)
  cdraw.content((13.9, 1.75), [bad crc], size: 6pt)
  cdraw.content((16.5, 3.9), [recovery keeps the intact records], size: 6pt)
  cdraw.content((19.4, 1.75), [a failed crc untrusts], size: 6pt)
  cdraw.content((17.0, 0.65), [everything after it], size: 6pt)
  cdraw.content((16.5, -0.45), [tested by truncation and bit flips], size: 6pt)
})

== the memtable

Live writes land in a skip list keyed by raw bytes. Chapter 25
teaches the structure itself, the tower heights and the search
walk, so this chapter keeps the engine-grade half: a dictionary
alongside the spine answers latest-write queries in constant time,
size accounting tracks the bytes a flush will emit so the 256 KiB
rollover is honest, and `Sorted()` plus `SortedFrom()` stream the
run in byte order for flushes and for scans that seek:

#listing("dsa/capstone/src/Engine/MemTable.cs", first: 42, last: 82, caption: [put with size accounting, get from the dictionary, sorted walks from a lower bound])

The towers carry a war story. `RandomLevel` drew one xorshift value
and reused it for the whole climb, so every tower was height one or
max, half and half, while its own comment claimed p = 1/2 per
promotion. Chapter 25's teaching twin measured the lane widths,
caught the degeneracy, and the fix is the idiom that chapter
teaches, a fresh flip per promotion, now pinned here the same way:
level 2 holds about half the nodes, level 5 about a sixteenth.

The unsigned byte-order comparer at the bottom of the file is the
one total order a binary key space has, prefix before longer,
exactly what chapter 9's trie assumed too.

#diagram([the skip list spine with towers from a seeded xorshift, the level 0 chain streams sorted bytes], length: 13pt, {
  // head plus 01 07 1f a3 ff, towers on 01 1f ff, express lanes above
  let cell = (x, y, s, w) => {
    cdraw.rect((x, y - 0.24), (x + w, y + 0.24), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y), s, size: 6pt)
  }
  let arrow = (x0, x1, y) => cdraw.line((x0, y), (x1, y), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.85, 7.95), [the spine and its express lanes], size: 6.5pt)
  cdraw.content((15.2, 7.55), [the dictionary alongside], size: 6pt)
  cdraw.rect((13.2, 6.2), (17.2, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((15.2, 6.5), [latest write], size: 6pt)
  cdraw.content((15.5, 5.5), [skip list from chapter 25], size: 6pt)
  arrow(2.65, 6.15, 6.5)
  cell(0.9, 6.5, [head], 1.7)
  cell(6.2, 6.5, [1f], 0.9)
  arrow(2.65, 2.95, 5.5)
  arrow(3.95, 6.15, 5.5)
  arrow(7.15, 9.35, 5.5)
  cell(0.9, 5.5, [head], 1.7)
  cell(3.0, 5.5, [01], 0.9)
  cell(6.2, 5.5, [1f], 0.9)
  cell(9.4, 5.5, [ff], 0.9)
  arrow(2.65, 2.95, 4.5)
  arrow(3.95, 4.55, 4.5)
  arrow(5.55, 6.15, 4.5)
  arrow(7.15, 7.75, 4.5)
  arrow(8.75, 9.35, 4.5)
  cell(0.9, 4.5, [head], 1.7)
  cell(3.0, 4.5, [01], 0.9)
  cell(4.6, 4.5, [07], 0.9)
  cell(6.2, 4.5, [1f], 0.9)
  cell(7.8, 4.5, [a3], 0.9)
  cell(9.4, 4.5, [ff], 0.9)
  for x in (1.75, 3.45, 6.65, 9.85) {
    cdraw.line((x, 4.74), (x, 5.26), stroke: luma(160))
  }
  for x in (1.75, 6.65) {
    cdraw.line((x, 5.74), (x, 6.26), stroke: luma(160))
  }
  cdraw.content((15.5, 4.4), [level 0 streams in byte order], size: 6pt)
  cdraw.content((15.5, 3.3), [get asks the dictionary], size: 6pt)
  cdraw.content((15.5, 2.2), [sorted walks the spine], size: 6pt)
  cdraw.content((15.5, 1.1), [unsigned byte order, one total order], size: 6pt)
  cdraw.content((15.5, 0.0), [flush writes the run], size: 6pt)
})

== the sorted run

A flush writes the memtable as an immutable sstable: crc framed
entries, the bloom bytes, a sparse index block with every sixteenth
key pointing at its offset, and a twenty byte footer holding the
index offset, bloom length, and a magic. Opening reads only that
tail, footer first then bloom and index backward from it; the data
region stays on disk and is fetched block by block:

#listing("dsa/capstone/src/Engine/SSTable.cs", first: 49, last: 87, caption: [open reads only the tail: footer, bloom, and sparse index])

The stride 16 index already defines the blocks: block i spans
`[Index[i].Offset, Index[i+1].Offset)`, the last ends where the
bloom begins, so blocks needed no format change, only a different
unit of reading. A point read is the book in miniature, the bloom
answers first, the index is binary searched with chapter 14's lower
bound, and the bracketing block is decoded and walked until sorted
order says the key was passed. A range scan takes the same lower
bound with no bloom gate, because a point filter cannot answer a
range, chapter 21's query shape streaming over chapter 14's bound:

#listing("dsa/capstone/src/Engine/SSTable.cs", first: 89, last: 145, caption: [read all uncached, get and seek over blocks, the lower bound])

Reading one block is three moves: seek to its index point, read the
span up to the next one, decode the frames into entries, routed
through the cache when one is attached and around it for `ReadAll`,
because a compaction scan is sequential and would only evict useful
blocks:

#listing("dsa/capstone/src/Engine/SSTable.cs", first: 147, last: 198, caption: [the block plumbing: span read, frame decode, cache routing])

The frames themselves come from `EntryCodec`, shared by the writer
and every reader so the bytes have exactly one definition:

#listing("dsa/capstone/src/Engine/EntryCodec.cs", first: 11, last: 31, caption: [one entry as len, crc, payload, the codec both sides share])

The cache is chapter 25's LRU in its teaching shape, a dictionary
for the hit test and a doubly linked list for recency: a hit moves
the node to the head, an insert past capacity evicts from the tail.
The engine owns one cache across every segment and rebuilds it when
compaction retires the old paths:

#listing("dsa/capstone/src/Engine/BlockCache.cs", first: 37, last: 73, caption: [get and put, move to front, evict from the tail])

The tests grew the sparse-index logic honestly: an early version
excluded the boundary entry at the next index point and failed on
`key016` of a hundred-key run, the off-by-one chapter 14 warned
about, caught on real bytes. Blocks brought one documented behavior
change: a bit flipped inside an entry frame used to be refused at
`Open`, which walked every entry to count them, and is now refused
when the block holding it is read. `Open` trusts the footer, the
bloom, and the index; the data region earns its trust per block,
crc first.

#diagram([the sorted run as one byte map, entries bracketed into blocks by the index points, an lru cache row under the read path], length: 13pt, {
  // entries in blocks of four (index points shaded), bloom, index, 20 byte footer, lru cache row
  cdraw.content((11.0, 8.45), [the sorted run as blocks], size: 6.5pt)
  for i in range(12) {
    cdraw.rect((2.1 + i * 0.7, 7.0), (2.8 + i * 0.7, 7.45), fill: if i in (0, 4, 8) { luma(205) } else { luma(235) }, radius: 0.02)
  }
  cdraw.rect((10.7, 7.0), (13.1, 7.45), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 7.225), [bloom], size: 6pt)
  cdraw.rect((13.3, 7.0), (17.7, 7.45), fill: luma(235), radius: 0.02)
  cdraw.content((15.5, 7.225), [sparse index], size: 6pt)
  cdraw.rect((17.9, 7.0), (21.5, 7.45), fill: luma(205), radius: 0.02)
  cdraw.content((19.7, 7.225), [footer 20b], size: 6pt)
  // each index point starts a block, the bracket spans to the next
  let bracket = (x0, x1, s) => {
    cdraw.line((x0, 6.95), (x0, 6.55), stroke: luma(100))
    cdraw.line((x0, 6.6), (x1, 6.6), stroke: luma(100))
    cdraw.line((x1, 6.95), (x1, 6.55), stroke: luma(100))
    cdraw.content(((x0 + x1) / 2, 6.3), s, size: 6pt)
  }
  bracket(2.1, 4.9, [block 0])
  bracket(4.9, 7.7, [block 1])
  bracket(7.7, 10.5, [block 2])
  cdraw.content((10.3, 5.3), [dark: every sixteenth key indexed], size: 6pt)
  cdraw.line((17.9, 6.95), (16.3, 5.9), stroke: luma(220))
  cdraw.line((21.5, 6.95), (22.9, 5.9), stroke: luma(220))
  let fcell = (x0, x1, s) => {
    cdraw.rect((x0, 5.35), (x1, 5.85), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 5.6), s, size: 6pt)
  }
  fcell(16.0, 18.6, [offset])
  fcell(18.6, 21.2, [length])
  fcell(21.2, 23.5, [magic])
  cdraw.content((17.3, 4.9), [8], size: 6pt)
  cdraw.content((19.9, 4.9), [8], size: 6pt)
  cdraw.content((22.35, 4.9), [4], size: 6pt)
  cdraw.content((11.45, 4.3), [the read path], size: 6.5pt)
  let step = (x0, x1, s) => {
    cdraw.rect((x0, 2.95), (x1, 3.45), fill: luma(235), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 3.2), s, size: 6pt)
  }
  step(1.0, 5.9, [bloom gate])
  step(6.5, 11.1, [lower bound])
  step(11.7, 16.3, [read block])
  step(16.9, 22.1, [passed: stop])
  cdraw.line((5.95, 3.2), (6.45, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.15, 3.2), (11.65, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.35, 3.2), (16.85, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.0, 2.1), [a bloom miss is final, no false negatives], size: 6pt)
  cdraw.content((11.0, 1.0), [blocks tile the region, no gaps to extend over], size: 6pt)
  // the cache row: head on the left, eviction on the right
  cdraw.content((11.45, 0.15), [the lru cache row], size: 6.5pt)
  let cblock = (x, s, hot) => {
    cdraw.rect((x, -0.85), (x + 2.3, -0.2), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 1.15, -0.525), s, size: 6pt)
  }
  cblock(5.2, [block 2], true)
  cblock(7.8, [block 0], false)
  cblock(10.4, [block 7], false)
  cdraw.content((2.7, -0.525), [head], size: 6pt)
  cdraw.line((3.4, -0.525), (5.1, -0.525), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.9, -0.525), (13.9, -0.525), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.7, -0.525), [evict], size: 6pt)
  cdraw.content((11.0, -1.7), [a hit moves its block to the head], size: 6pt)
  cdraw.content((11.0, -2.8), [read all bypasses the cache, compaction scans in order], size: 6pt)
  cdraw.content((11.0, -3.9), [footer: 8 + 8 + 4 = 20 bytes], size: 6pt)
})

== compaction

Segments accumulate, so compaction merges them: the cursor-array
k-way merge from chapter 8, runs given oldest first so the newest
version of a key wins, tombstones dropped only when every run is
being merged because only then is nothing older below:

#listing("dsa/capstone/src/Engine/Compaction.cs", first: 4, last: 62, caption: [the full merge, heads array, equal-key advancement])

#diagram([compaction, the cursor merge oldest first, equal keys advance every cursor and the newest run wins], length: 13pt, {
  // newest a b* c, middle a b d, oldest b c e: out a c d e, the tombstone drops
  let cell = (x, y, s, kind) => {
    cdraw.rect((x, y - 0.24), (x + 0.9, y + 0.24), fill: if kind == "out" { luma(205) } else if kind == "tomb" { none } else { luma(235) }, stroke: if kind == "tomb" { luma(100) }, radius: 0.02)
    cdraw.content((x + 0.45, y), s, size: 6pt)
  }
  cdraw.content((0.8, 7.0), [newest], size: 6pt)
  cell(2.2, 7.0, [a], "")
  cell(3.1, 7.0, [b], "tomb")
  cell(4.0, 7.0, [c], "")
  cdraw.content((0.8, 6.0), [older], size: 6pt)
  cell(2.2, 6.0, [a], "")
  cell(3.1, 6.0, [b], "")
  cell(4.0, 6.0, [d], "")
  cdraw.content((0.8, 5.0), [oldest], size: 6pt)
  cell(2.2, 5.0, [b], "")
  cell(3.1, 5.0, [c], "")
  cell(4.0, 5.0, [e], "")
  cdraw.content((0.8, 3.4), [out], size: 6pt)
  cell(2.2, 3.4, [a], "out")
  cell(3.1, 3.4, [c], "out")
  cell(4.0, 3.4, [d], "out")
  cell(4.9, 3.4, [e], "out")
  cdraw.content((13.5, 7.0), [runs are given oldest first], size: 6pt)
  cdraw.content((13.5, 5.85), [equal keys: the newest survives], size: 6pt)
  cdraw.content((13.5, 4.7), [every cursor on the key advances], size: 6pt)
  cdraw.content((13.5, 3.4), [tombstones drop only at the bottom], size: 6pt)
  cdraw.content((13.5, 2.3), [nothing older can remain below], size: 6pt)
  cdraw.content((13.5, 1.2), [chapter 8's k way merge again], size: 6pt)
  cdraw.content((13.5, 0.1), [outlined box: a tombstone, dropped], size: 6pt)
})

The merge itself is only half of compaction. Writing the merged run
and then deleting the old segments is a two-step mutation of the
directory, and a crash between the steps leaves the tombstone-dropped
merge coexisting with stale runs, which glob-order opening reads as
newest: a deleted key resurrects. The fix is a manifest, a json list
of the live segment files swapped atomically:

#listing("dsa/capstone/src/Engine/Manifest.cs", first: 15, last: 50, caption: [load with the legacy glob fallback, save as a fsynced tmp plus rename])

Compaction writes the merged run durably, saves the manifest as a
tmp file that is fsynced and renamed over the old one, and only
then deletes the retired segments. A crash anywhere in the
sequence leaves at worst ignored garbage, never two competing
truths. The regression test plants a pre-compaction segment back
under a stale name and asserts the deleted key stays deleted.

== the engine

The orchestrator wires the pieces into the lsm shape: writes hit
the wal then the memtable, flushes cut segments, reads walk the
memtable then segments newest first, and reopening replays the wal.
Opening reads segments through the manifest, so any `.sst` outside
the live list is garbage from an interrupted swap, never a run to
merge. Three knobs shape the machine, the memtable flush size at
256 KiB, the compaction threshold at 4 segments, the block cache at
64 blocks, and the threshold bounds the segment count with no
caller discipline: a flush that brings the count to the threshold
merges inside the same call:

#listing("dsa/capstone/src/Engine/Engine.cs", first: 4, last: 101, caption: [open with recovery, put and get through the level stack, prefix scan])

#listing("dsa/capstone/src/Engine/Engine.cs", first: 103, last: 166, caption: [flush cuts a segment and widens the manifest, the threshold merge swaps it atomically])

The scan merges every level oldest first with the memtable last,
so fresh writes and deletes win, a run-order bug the tests caught
when a deleted key resurrected from an older segment. Every run
now seeks to the prefix first, so a scan reads nothing below the
range and stops at the first key past it.

#flow(
  [the write path through the engine, a segment count at the threshold folds back into a merge],
  node((0, 0), [put or delete]),
  node((1.5, 0), [wal append, fsync]),
  node((3.0, 0), [memtable skip list]),
  node((3.0, -1.2), [flush at 256 KiB]),
  node((1.5, -1.2), [sst segment]),
  node((0, -1.2), [count at threshold]),
  node((0, -2.4), [compaction merge]),
  edge((0, 0), (1.5, 0), "-|>"),
  edge((1.5, 0), (3.0, 0), "-|>"),
  edge((3.0, 0), (3.0, -1.2), "-|>"),
  edge((3.0, -1.2), (1.5, -1.2), "-|>"),
  edge((1.5, -1.2), (0, -1.2), "-|>"),
  edge((0, -1.2), (0, -2.4), "-|>"),
)

== cross-examined against sqlite

A suite written against the engine alone can share the engine's blind
spots, so a comparator suite answers every question twice: 512 keys
and values from pure functions of the index load into both this
engine and sqlite 3.53.4 through `Microsoft.Data.Sqlite` with the
`SQLitePCLRaw.bundle_e_sqlite3` pin, and every answer the two stores
can disagree on is asserted identical, point reads over the full
keyspace, negative lookups on both sides, deletes and overwrites,
prefix scans against an ordered select over blob keys, and a full
reopen of both. The engine version itself is asserted, and the
per-side clocks are printed to the test output, never asserted,
because timings describe the machine more than the code:

#listing("dsa/capstone/tests/Engine.Tests/SqliteComparatorTests.cs", first: 134, last: 171, caption: [one deterministic op stream replayed through both engines, per-side clocks])

Determinism can only walk the paths its author imagined, so a fuzz
suite adds the paths nobody would: three seeded random op streams,
400 ops over a 64 key space each, weighted puts and deletes with a
flush every twenty-five ops, a compaction every hundred, and a
dispose-and-reopen every hundred fifty, mirrored op for op into the
file-backed sqlite. Every fifty ops the whole keyspace is probed on
both sides and a full engine scan is compared against an ordered
select over blob keys. A disagreeing seed is a reproducer, the
whole point of seeding:

#listing("dsa/capstone/tests/Engine.Tests/SqliteFuzzTests.cs", first: 33, last: 72, caption: [one seeded op stream, flushes, compactions, reopens, checkpoints every fifty ops])

#flow(
  [the comparator, one stream through two engines, answers asserted identical, clocks only printed],
  node((0, 0), [the op stream, #linebreak() 512 pure keys]),
  node((1.5, 0.9), [this engine]),
  node((1.5, -0.9), [sqlite]),
  node((3.0, 0), [asserted identical]),
  node((4.4, 0), [clocks printed only]),
  edge((0, 0), (1.5, 0.9), "-|>"),
  edge((0, 0), (1.5, -0.9), "-|>"),
  edge((1.5, 0.9), (3.0, 0), "-|>"),
  edge((1.5, -0.9), (3.0, 0), "-|>"),
  edge((3.0, 0), (4.4, 0), "-|>"),
)

== htmx, taught before it is used

The dashboard needs interactivity, and the tool chosen for it is
htmx 4, pinned at 4.0.0 from the npm registry and vendored into
`wwwroot/htmx.min.js`. The vendored file's SHA-384 base64 digest is
`BvJpBiO8Kh31EqtJe5DRIeWrHWnCGkwytKs9NKFi86Hhw96dEqdEMzZDeK9iEGTc`,
byte identical to the package's published CDN integrity value, so
the local copy is the published artifact, not a transcription. The
npm `latest` tag still points at 2.0.10, 4.0.0 rides the `next`
tag, which is worth knowing before pinning.

The whole idea fits in five attributes. `hx-get` and `hx-post`
issue an ajax request to a url:

#snippet(
  "<button hx-post=\"/compact\" hx-swap=\"none\">compact segments</button>\n",
  lang: "html",
)

`hx-target` picks where the response goes, a css selector, and
`hx-swap` picks how it lands, `innerHTML` the default, and
`outerHTML`, `afterbegin`, `beforebegin`, `beforeend`, `afterend`,
`delete`, or `none`. `hx-trigger` replaces the default event, click
for buttons and submit for forms, and its modifiers carry real
logic: `every 2s` polls, `delay:`, `throttle:`, `changed`, `once`:

#snippet(
  "<section id=\"stats\" hx-get=\"/stats\" hx-trigger=\"every 2s\" hx-swap=\"innerHTML\">\n"
  + "  <!-- the server re-renders these cards every two seconds -->\n"
  + "</section>\n",
  lang: "html",
)

The last piece is `hx-swap-oob`, out of band swaps. A response can
carry elements that update targets elsewhere on the page: htmx
takes any element with `hx-swap-oob` and swaps it into the element
with the matching id, while the rest of the response goes to the
original target. That is how the compact button refreshes the stats
without touching anything else.

#flow(
  [the five htmx attributes as one request machine],
  node((0, 0), [hx-trigger, #linebreak() the event]),
  node((1.5, 0), [hx-get or post, #linebreak() the call]),
  node((3.0, 0), [hx-target, #linebreak() the destination]),
  node((4.5, 0), [hx-swap, #linebreak() the landing]),
  node((6.0, 0), [hx-swap-oob, #linebreak() elsewhere]),
  edge((0, 0), (1.5, 0), "-|>"),
  edge((1.5, 0), (3.0, 0), "-|>"),
  edge((3.0, 0), (4.5, 0), "-|>"),
  edge((4.5, 0), (6.0, 0), "-|>"),
)

One language note from building the page: the html lives in
interpolated raw strings, and a single-`$` raw string rejects two
consecutive braces as content, so a page holding a css block needs
the `$$` form, literal braces plain and interpolations doubled. The
compile error is `CS9006`, found the honest way.

== the dashboard

An ASP.NET Core minimal api serves fragments, one endpoint per
interaction, every body built by the `Ui` class:

#listing("dsa/capstone/src/Dashboard/Program.cs", first: 35, last: 76, caption: [the endpoints: stats poll, lookup, put and delete forms, oob compact])

#listing("dsa/capstone/src/Dashboard/EngineHosted.cs", first: 128, last: 157, caption: [the fragment builders: stats cards, tail row, server-rendered recent rows, lookup answer])

The put and delete forms return a table row targeted at
`#tail-row` with `afterbegin`, so the write log grows in place. The
stats section polls every two seconds. The compact button posts and
swaps `none` for itself while the response's out-of-band stats
block updates the cards.

The recent-writes ring earned its keep the honest way: chapter 5's
`Ring<T>` sat in the host as dead state for a whole draft,
enqueued on every write and read by nothing, until the overhaul
made `GET /` render the last sixteen receipts server-side so the
page shows real history before any htmx call fires. The ring grows
past its capacity rather than wrapping, so the host enforces the
bound itself, evicting the oldest receipt before the newest lands,
and because the ring exposes only enqueue and dequeue, the
snapshot rotates it once, dequeuing sixteen and re-enqueueing the
same sixteen, to read without destroying.

#diagram([the endpoint wiring as a matrix, what each route returns, where it lands, and how], length: 13pt, {
  // five endpoints against verb, returns, target, swap
  let xs = ((0.8, 4.2), (4.2, 5.9), (5.9, 9.5), (9.5, 13.2), (13.2, 17.4))
  let cell = (c, r, s, head) => {
    let (x0, x1) = xs.at(c)
    let y1 = 7.4 - r * 1.1
    cdraw.rect((x0, y1 - 1.1), (x1, y1), fill: if head { luma(235) } else if calc.even(r) { luma(245) } else { none }, stroke: luma(180))
    cdraw.content(((x0 + x1) / 2, y1 - 0.55), s, size: 6pt)
  }
  cell(0, 0, [endpoint], true)
  cell(1, 0, [verb], true)
  cell(2, 0, [returns], true)
  cell(3, 0, [target], true)
  cell(4, 0, [swap], true)
  cell(0, 1, [/stats], false)
  cell(1, 1, [get], false)
  cell(2, 1, [cards], false)
  cell(3, 1, [\#stats], false)
  cell(4, 1, [innerHTML], false)
  cell(0, 2, [/get], false)
  cell(1, 2, [get], false)
  cell(2, 2, [answer], false)
  cell(3, 2, [its form], false)
  cell(4, 2, [innerHTML], false)
  cell(0, 3, [/put], false)
  cell(1, 3, [post], false)
  cell(2, 3, [a row], false)
  cell(3, 3, [\#tail-row], false)
  cell(4, 3, [afterbegin], false)
  cell(0, 4, [/delete], false)
  cell(1, 4, [post], false)
  cell(2, 4, [a row], false)
  cell(3, 4, [\#tail-row], false)
  cell(4, 4, [afterbegin], false)
  cell(0, 5, [/compact], false)
  cell(1, 5, [post], false)
  cell(2, 5, [oob stats], false)
  cell(3, 5, [none], false)
  cell(4, 5, [oob], false)
  cdraw.content((9.1, -0.3), [stats polls every 2s, writes grow the tail row in place], size: 6pt)
  cdraw.content((9.1, -1.4), [compact swaps none itself, its oob block updates stats], size: 6pt)
  cdraw.content((9.1, -2.5), [each body is a fragment, the ring is chapter 5's], size: 6pt)
})

Integration tests run the real host through
`WebApplicationFactory`, per-test data directories via the
`DSA_DATA_DIR` setting, and assert what htmx will actually see: the
page carries the script tag and the wired attributes, the dist file
serves with `var htmx=` at its start and its bytes hash to the
published sha384 digest, form posts return row
fragments with the right content type, values are html escaped, a
put is visible to a later get, deletes remove keys, and data
survives a full host restart, and the recent-writes ring renders
its sixteen rows server-side and wraps at seventeen. Fourteen
dashboard tests over sixty-one engine tests, zero skipped.

The honest boundaries, stated rather than hidden: one engine
instance per data directory, single threaded, the file-level
locking is advisory. Reads are block oriented through the lru
cache now, no longer whole files in memory, though a block-decode
is still a full copy, right for the sizes this engine teaches at.
Every wal append fsyncs, and every flush fsyncs its segment before
the wal resets, durable and deliberately slow, milliseconds a
write on the dev machine. Compaction is crash safe through the
manifest and threshold triggered, but still full, not leveled,
and nothing is compressed anywhere. Every one of those lines is
where a production engine, rocksdb and its kin, spends its
complexity budget, and each is now a labeled door rather than a
mystery.

sources: htmx.org docs pages for attributes, swapping, triggers,
and the reference, the npm registry entry for `htmx.org@4.0.0` with
its published integrity digest, learn.microsoft.com minimal apis
fundamentals, `WebApplicationFactory`, `FileStream.Flush(Boolean)`,
`System.Text.Encodings.Web`, accessed 2026-09-08, learn.microsoft.com
`Microsoft.Data.Sqlite` parameters, `SqliteDataReader`, and
`ExecuteScalar`, accessed 2026-09-10. Verified by
`make verify-csharp`, 75 capstone tests plus the sample suite.
