#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= store

The service has run so far on maps, which tests love and restarts
hate. The obvious answer is an embedded database, and the jdk does
not have one: `java.sql` is a driver surface with no driver for any
local engine behind it, and the last bundled database, java db, the
rebranded derby, left the distribution after java 8. The corpus lane
is stdlib exclusive anyway, so this chapter owns the machinery
outright in `javabook.store`: a write-ahead log of crc32c framed
records, replay that recovers state and tolerates a torn tail,
transaction markers that make groups atomic, snapshot compaction with
an atomic rename, and the `UserStore` port from chapter 21
implemented over it all behind the same interface, no handler any
the wiser. The go book built the same engine on the same reasoning
when its dependency ruling retired the sqlite driver,
#xref-to("go", "store"), and that chapter's depth is the bar this
one aims at, with java's own shapes: no `defer`, so close is the
rollback, no `crc32` table to build, the Castagnoli polynomial ships
in `java.util.zip` since 9, and no sorted slice to maintain by hand,
a `TreeMap` is the sorted key view.

== the frame

One log record is one frame: an eight byte header, payload length
then its crc32c, wrapped around a payload of version byte, op byte,
and the op's fields, every length little endian so a payload can
carry a full request body. The op set is four: put, tombstone, and
the two transaction markers, and the version byte is the codec's
contract with the future, a frame this build cannot parse stops the
walk rather than being guessed at:

#listing("java/api/src/javabook/store/Wal.java", first: 91, last: 113, caption: [the payload writer: version, op, and the op's fields, lengths u32 little endian])

#diagram([one frame: the checksum covers exactly the payload, the payload carries its own version], length: 13pt, {
  cdraw.rect((0.6, 6.2), (5.4, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 7.7), [u32 length], size: 6.5pt)
  cdraw.content((3.0, 6.8), [payload bytes], size: 6pt)
  cdraw.rect((6.2, 6.2), (11.0, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((8.6, 7.7), [u32 crc32c], size: 6.5pt)
  cdraw.content((8.6, 6.8), [of the payload], size: 6pt)
  cdraw.rect((11.8, 6.2), (22.6, 8.4), fill: luma(222), radius: 0.02)
  cdraw.content((17.2, 7.7), [payload: version, op, fields], size: 6.5pt)
  cdraw.content((17.2, 6.8), [put: key len, key, value len, value], size: 6pt)
  cdraw.content((17.2, 5.9), [tombstone: key. markers: u64 sequence], size: 6pt)
  cdraw.content((11.5, 4.6), [crc32c is castagnoli, java.util.zip since 9, hardware backed], size: 6pt)
  cdraw.content((11.5, 3.5), [little endian everywhere: one byte order, no per-field story], size: 6pt)
})

Decoding walks frames until the bytes run out or a frame is torn: a
remaining tail shorter than the header, a length that overruns, a
checksum that lies, or a payload this build cannot parse, and the
walk stops there without an error, exactly what recovery wants. A
torn tail is the crash artifact the design accepts, not a corruption
event:

#listing("java/api/src/javabook/store/Wal.java", first: 116, last: 140, caption: [the walk: every refusal is the same stop, the offset names where])

The appender is the write side, one channel opened for append with
groups written whole, one buffer per group in as few write calls as
the channel takes, because a channel write may write partially and
the loop is the honesty. `sync` is `force`, the durability point a
commit means when the caller wants it promised.

== replay, the recovery story

Open reads the log and rebuilds memory from it, and the rule that
makes groups atomic is the marker pair: ops apply only between a
begin and its matching commit, an orphan group whose commit never
arrived is discarded whole, and the sequence resumes past the last
begin seen so a reopened engine never reuses a committed number:

#listing("java/api/src/javabook/store/Engine.java", first: 60, last: 80, caption: [open: snapshot first when one stands, then the committed groups replayed over it])

#listing("java/api/src/javabook/store/Engine.java", first: 368, last: 392, caption: [replay: no marker pair, no application, the whole group dies together])

The invariant is named in the test that proves it, exhaustively
rather than by fuzz: for any truncation of a framed log, replaying
the decodable prefix answers exactly the state of the transactions
committed inside that prefix. The test builds a three transaction
log and asserts it twice over. At every frame boundary the recovered
state is compared against a hand-computed expectation, eleven
boundaries from the empty log to the full one, written out in the
test so the oracle is not the implementation agreeing with itself.
And between the boundaries, at every byte length from zero to the
whole file, the reopened engine is compared against a decode of the
same prefix, so a torn tail changes nothing anywhere else. A crash
mid-frame, mid-group, mid-header, all one geometry, and geometry is
not timing. Open also creates the log's parent directories, one
line, because a boot into a fresh directory should not die on a
missing folder:

#diagram([a log recovers to the last committed group, whatever the cut], length: 13pt, {
  cdraw.content((2.0, 8.9), [begin 1], size: 6pt)
  cdraw.content((5.2, 8.9), [put a, put b], size: 6pt)
  cdraw.content((9.0, 8.9), [commit 1], size: 6pt)
  cdraw.content((12.6, 8.9), [begin 2], size: 6pt)
  cdraw.content((15.8, 8.9), [put a'], size: 6pt)
  cdraw.content((19.0, 8.9), [commit 2], size: 6pt)
  cdraw.line((0.8, 8.2), (21.4, 8.2), stroke: luma(140))
  cdraw.line((10.8, 7.9), (10.8, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.8, 5.9), [cut here], size: 6pt)
  cdraw.rect((0.8, 3.4), (10.6, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.7, 4.7), [tx 1 applies whole], size: 6.5pt)
  cdraw.content((5.7, 3.9), [a=1, b=2 survive], size: 6pt)
  cdraw.rect((11.0, 3.4), (21.4, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((16.2, 4.7), [tx 2 never lands], size: 6.5pt)
  cdraw.content((16.2, 3.9), [no commit marker arrived], size: 6pt)
  cdraw.content((11.0, 2.3), [any cut inside a frame: same answer, the frame decodes or it does not], size: 6pt)
})

== the transaction, append then mutate

One shape covers every write: take the transaction, run, commit. The
write side holds the engine's full lock from begin to finish, so
exactly one writer holds a group at a time and every read inside it
is current without a second mechanism. Commit is append then mutate:
the group's frames, the begin marker, the ops, the commit marker, go
out in one write, and only then does memory take the group, values
copied so nothing aliases the caller's array:

#listing("java/api/src/javabook/store/Engine.java", first: 187, last: 222, caption: [the commit order: the group's frames append in one write, then memory mutates])

The order is the guarantee. The log is always at least as current as
memory, so a crash between the append and the mutation recovers to
the committed state, and the inverse order would leave memory holding
a state the log cannot rebuild, the exact failure recovery exists to
prevent. The write reaches the operating system but is not forced,
the line sqlite's synchronous NORMAL draws: durable across
application crashes, relaxed about power loss, with `sync` as the
operator's stronger call.

Java has no `defer`, and the discard lane is the idiom that fills
the gap: the transaction is `AutoCloseable`, and close without a
commit is the rollback. Every caller is a try-with-resources block,
so the normal exit, the early throw, the store's own conflict
exception, and a panic unwinding through all land in the same close,
the group discarded with nothing to undo because nothing was appended
until commit:

And the append can fail. A disk that throws mid-group leaves a torn
frame in the file and the channel positioned after it, and any
commit that landed later would bury that tear under frames recovery
stops before ever reaching, memory silently ahead of the readable
log. The engine refuses that outcome by construction: a failed
append poisons it, the lock is released, memory stays untouched, and
every later `begin` answers `IllegalStateException` until the
process restarts and recovers to the last whole group. Fail closed,
stated plainly, because the alternative is the one inconsistency the
design cannot repair.

#listing("java/api/src/javabook/store/FileStore.java", first: 45, last: 57, caption: [the caller's shape: one tx, three ops, commit inside try-with-resources])

#diagram([a transaction's exits, every one of them clean], length: 13pt, {
  cdraw.rect((0.4, 5.4), (6.2, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 6.6), [write tx, full lock], size: 6pt)
  cdraw.content((3.3, 5.8), [ops gather in the group], size: 6pt)
  cdraw.line((3.3, 5.3), (3.3, 4.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.4, 3.0), (6.2, 4.5), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 4.0), [stage, check, commit], size: 6pt)
  cdraw.content((3.3, 3.3), [or throw anywhere], size: 6pt)
  pane(8.6, 14.6, 4.5, [commit returns], [frames append in one write], [then memory takes the group])
  cdraw.line((6.4, 3.7), (8.4, 3.7), stroke: luma(100), mark: (end: ">>"))
  pane(15.8, 21.8, 4.5, [any throw], [close is the rollback], [nothing was appended])
  cdraw.line((14.8, 3.7), (15.6, 3.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((3.3, 1.9), [java's defer is the try-with-resources close], size: 6pt)
  cdraw.content((3.3, 0.8), [the log stays at least as current as memory], size: 6pt)
})

== the read view

A read takes one clone of the key space under the read lock and keeps
it for its whole life: no dirty reads, because memory only mutates
after a group is logged, no non-repeatable reads within one
transaction, because the view never moves. That is snapshot
isolation, built here rather than configured, and the demo is
deterministic single threaded code, the statement order is the
schedule, no thread, no barrier, no sleep: pin a view, commit past
it, read again, still the old bytes, a fresh view sees the new ones.
Writers serialize on the full lock, one at a time, and the
concurrency test races eight virtual threads through ten groups each
and finds eighty whole groups and 240 frames, every one accounted
for. The clone is the stated price, a tree map copied per read, and
at book scale, a few hundred entries, that is cheap enough to keep
the engine plain.

== compaction

The log only grows, and compaction is the answer: write the current
state to a snapshot file, then rotate the log. The snapshot is a
tiny format, magic, codec version, the last committed sequence
number, and a crc32c of the body, and the body is the entries in
sorted key order, so the bytes are deterministic. The sequence rides
the header because the open sequence's no-reuse promise must survive
compaction too: a post-compaction reopen resumes numbering where the
old log stopped instead of restarting it, and the test pins the
number walking across a compact and two reopens. The write lands on
a tmp file, is forced, and is moved over atomically, `Files.move`
with `ATOMIC_MOVE`, replace-existing on this build's windows and
posix alike, and only then does the log rotate, rename to `.old`,
create fresh, remove `.old`. Every interruption of that order is
recoverable by the open sequence, because the snapshot already
subsumes everything the old log held:

#listing("java/api/src/javabook/store/Engine.java", first: 248, last: 289, caption: [compact: force, atomic move, then the rotation whose recovery argument relies on the order])

#callout("note", "the one loss the design accepts", [
  A snapshot that arrives torn despite the force is not trusted: the
  open sequence falls back to log-only recovery, and the
  pre-compaction state is gone, because the rotation already removed
  the log that held it. The torn-snapshot test documents exactly
  this, the old key missing, the post-compaction writes back, and
  the alternative, trusting a checksum that failed, is not an
  alternative at all.
])

Measured by the suite on this machine, dated 2026-10-05: sixty
superseded puts grow the log to 3770 bytes, compaction leaves a
fresh log of 0 bytes and a 43 byte snapshot holding the one
surviving value, and a thousand users, three thousand records and
300,010 log bytes, reopen by replay in 10.1 to 11.9 ms, while the
compacted form, a 234,036 byte snapshot, reloads in 7.1 to 9.0 ms.
Compaction is a call the operator or the wiring makes, not a
background thread, and the honesty is the point: nothing in the
engine wakes up on its own.

== the user store over the engine

The adapter implements chapter 21's port, `create`, `get`,
`getByEmail`, `list`, and the key scheme is the documentation the
keys enforce. The record lives under `u:rec:`, the email uniqueness
claim under `u:email:`, and the keyset order index under `u:ord:`,
where the creation millisecond rides sign-flipped fixed width hex
beside the id, exactly the pair the pagination cursor carries, so
storage order and keyset order are one notion of position:

#listing("java/api/src/javabook/store/FileStore.java", first: 93, last: 100, caption: [the order key: sign-flipped millis keep ascending time ascending in hex, the id tiebreak beside it])

The stored form is not the wire form, and the split is worth naming.
The record serializes all six components including the password hash,
because the store must verify logins after a restart, while the wire
writer chapter 21 pinned lists five and never the hash: the hash is
stored, never served, and the test asserts both directions, the
stored bytes contain it, the wire bytes do not. The etag story closes
the loop: the etag is sha256 over the wire bytes, the wire writer is
deterministic, so the same record yields the same etag forever, and
the restart test asserts the bytes did not move across a close and
reopen:

#listing("java/api/src/javabook/store/FileStore.java", first: 72, last: 91, caption: [the list walk: one view, the range after the cursor, the id tiebreak free from the key])

The grants ride the same engine under `r:grant:`, one json array per
user in sorted order, with the never-zero-admins invariant checked
inside revoke against the engine's own live keys, and one detail
worth its ink: the emptied set is a tombstone, not a row, so the key
drops and the log gets to carry a `TOMBSTONE` frame, the op earning
its keep.

== the wiring and the reboot proof

`Main` swaps `MemStore` and `MemGrants` for the engine-backed pair,
one engine, one wal, one snapshot, both key spaces, opened at a
directory from `JBAPI_DATA` with a shutdown hook closing it, and
nothing else in the program changes: the first-admin decorator wraps
the file store now, the policy table reads it, the handlers cannot
tell. The end to end test is the chapter's proof: boot the whole api
over a temp directory, register, login, list, then close everything,
open a fresh engine and a fresh app over the same directory, and the
second login verifies against the persisted hash, the second list
answers the persisted user, and the token minted before the restart
still carries the persisted admin role, because roles are store
truth, chapter 23's rule, and the store now survives:

#diagram([the reboot proof: two processes, one directory, everything comes back], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 5.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.8, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.8, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.8, 5.9), l2, size: 6pt)
  }
  stage(0.4, [boot one], [register, login, list], [wal grows], luma(235))
  stage(6.6, [close], [engine close], [nothing lost], luma(235))
  stage(12.8, [boot two], [fresh engine, same dir], [replay rebuilds], luma(235))
  stage(19.0, [assert], [login 200, list 200], [old token admin], luma(222))
  cdraw.line((6.2, 6.9), (6.4, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.4, 6.9), (12.6, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.6, 6.9), (18.8, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.5, 4.4), [one directory, two lifetimes, zero lost users], size: 6pt)
})

The test story is the chapter's spine: the codec round trip and its
refusals, corruption, a future codec version under an honest
checksum, a lying length and a near-INT_MAX one that must not wrap
into a two gigabyte allocation, every truncation at the codec level
and every truncation again through a real reopen with the
hand-computed boundary oracle, the orphan group, the rolled-back
group, the poisoned engine after a failed append with its lock
released, the sequence surviving compaction, the pinned view,
concurrent writers, compaction shrinking with the state intact and
the post-compaction writes replaying over the snapshot, the torn
snapshot falling back to the log, the parent directory created on
open, the store's round trips, the surviving email claim, the stable
etag, the pagination walk with the tie, the grants surviving with
their invariant and their tombstone, and the reboot. Twenty-four
tests this chapter, green three consecutive runs in a module now
numbering 92, and the whole engine is four files, 904 lines
including javadoc, small enough to be read whole, which is the point
of owning it.

sources: the jdk's own sources for `java.util.zip.CRC32C` (since 9,
the castagnoli polynomial), `FileChannel.force`, `Files.move` and
`ATOMIC_MOVE`, and `ByteBuffer`'s byte orders, read from
`tools/jdk27/build/jdk-27/lib/src.zip`, oracle jdk 27 ga build
27+35-2325. The java db removal from the jdk stated against oracle's
own migration guide, "removed tools and components" at
docs.oracle.com/en/java/javase/26/migrate/, which says java db was
bundled with jdk 7 and 8 and is no longer included, accessed
2026-10-05. The wal and synchronous NORMAL analogy follows the go
book's store chapter, book 3, chapter 23, and the sqlite
documentation it cited. Verified live 2026-10-05 by the
`javabook.store` tests under the vendored junit 6.1.3 lane, 24 tests
green three consecutive runs in a module of 92, with the
measurements above printed by the runs: compaction 3770 to 0 bytes
of wal beside a 43 byte snapshot, a thousand users replaying 300,010
bytes in 10.1 to 11.9 ms, the 234,036 byte compacted snapshot
reloading in 7.1 to 9.0 ms.
