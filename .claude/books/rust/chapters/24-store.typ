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

The service has run on maps, which tests love and restarts hate.
The corpus lane is zero-dependency, so this chapter owns the
machinery outright in `rustapi::store`: a write-ahead log of
crc32c-framed records, replay that rebuilds memory and buries a
torn tail, compaction that rewrites the live records and swaps
atomically, and chapter 21's `UserStore` port implemented over it
all behind the same interface, no handler any the wiser, the user
and authz tests green unchanged. The go book built the same engine
when its dependency ruling retired the sqlite driver,
#xref-to("go", "store"), the java book the same on the same
reasoning, #xref-to("java", "store"), and the bar this lane aims at
is their recovery argument with rust's own shapes: the crc table is
a `const fn` computed at compile time, the log is the only file
format, and one frame is one whole record, which deletes the
transaction machinery rather than implementing it.

== the frame, crc32c by hand

One log record is one frame: an eight byte header, payload length
then its crc32c, wrapped around a payload of version byte, op byte,
and the op's fields, every length little endian. The checksum is
Castagnoli, the polynomial `0x1EDC6F41` reflected to `0x82F63B78`,
and std ships no crc at all, so the table is built by a `const fn`
the compiler evaluates once rather than a static list typed in:
both siblings carried the table as data, go building it at init,
java importing it from `java.util.zip`, and the const evaluation is
rust's own third answer to the same problem:

#listing("rust/api/src/store/wal.rs", first: 40, last: 77, caption: [the castagnoli table as a const fn, the reflected update loop, and the little-endian helpers])

#listing("rust/api/src/store/wal.rs", first: 80, last: 98, caption: [the payload writer: version, op, and the op's fields, key then value for put, key alone for tombstone])

#diagram([one frame: the checksum covers exactly the payload, the payload carries its own version], length: 13pt, {
  cdraw.rect((0.6, 6.2), (5.4, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 7.7), [u32 length], size: 6.5pt)
  cdraw.content((3.0, 6.8), [of the payload], size: 6pt)
  cdraw.rect((6.2, 6.2), (11.0, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((8.6, 7.7), [u32 crc32c], size: 6.5pt)
  cdraw.content((8.6, 6.8), [of the payload], size: 6pt)
  cdraw.rect((11.8, 6.2), (22.6, 8.4), fill: luma(222), radius: 0.02)
  cdraw.content((17.2, 7.7), [payload: version, op, fields], size: 6.5pt)
  cdraw.content((17.2, 6.8), [put: key len, key, value len, value], size: 6pt)
  cdraw.content((17.2, 5.9), [tombstone: key. version byte pinned at 1], size: 6pt)
  cdraw.content((11.5, 4.6), [check values 0xE3069283 and 0x8A9136AA, rfc 3720's own], size: 6pt)
  cdraw.content((11.5, 3.5), [little endian everywhere, one byte order, no per-field story], size: 6pt)
})

The version byte is the codec's contract with the future: replay
refuses a frame it cannot read rather than guessing, so a future
format bumps the byte and old binaries fail closed. The two check
values in the test are not derived from this implementation at all,
they are the published crc32c constants, `"123456789"` to
`0xE3069283` and thirty-two zero bytes to `0x8A9136AA`, the numbers
rfc 3720 carries for exactly this purpose.

== replay and the torn tail

Decoding walks frames until the bytes run out or a frame is torn: a
remaining tail shorter than the header, a length that overruns, a
checksum that lies, or a payload this build cannot parse, and every
refusal is the same stop, the offset naming where:

#listing("rust/api/src/store/wal.rs", first: 100, last: 153, caption: [the payload checks and the walk: every refusal stops the decode, the records before it stand])

#listing("rust/api/src/store/mod.rs", first: 29, last: 60, caption: [open: parent directories, decode, and the torn tail truncated away before the appender ever positions after it])

The truncation is the chapter's own answer to a failure both
siblings had to fence separately: an append that lands after a torn
tail is unreachable forever, because replay stops at the tear and
never reaches the frames behind it. Java poisoned the engine after
a failed append, go relied on the writer never tearing, and here
the open sequence simply buries the artifact, `set_len` to the last
good offset, so the appender's position after recovery always
points at readable bytes. The test writes the tear, opens, appends
past it, reopens, and finds both the survivor and the new record.

The exhaustive test is java's geometry, and geometry is not timing:
a four-frame log of seventy-five bytes, three puts and a tombstone,
reopened at every one of its seventy-six byte lengths, from the
empty file to the whole one. At the five frame boundaries the
recovered state is compared against a hand-computed expectation
written out in the test, so the oracle is not the implementation
agreeing with itself, and between the boundaries the reopened state
must equal the state at the last boundary, which is frame
atomicity, the whole point of the checksum:

#diagram([a log recovers to the last whole frame, whatever the cut], length: 13pt, {
  cdraw.content((2.0, 8.9), [put a=1], size: 6pt)
  cdraw.content((6.0, 8.9), [put b=2], size: 6pt)
  cdraw.content((10.0, 8.9), [put a=3], size: 6pt)
  cdraw.content((14.6, 8.9), [drop b], size: 6pt)
  cdraw.line((0.8, 8.2), (17.4, 8.2), stroke: luma(140))
  cdraw.line((12.2, 7.9), (12.2, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.2, 5.9), [cut here], size: 6pt)
  cdraw.rect((0.8, 3.4), (12.0, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 4.7), [three frames apply whole], size: 6.5pt)
  cdraw.content((6.4, 3.9), [a=3, b=2 survive], size: 6pt)
  cdraw.rect((12.4, 3.4), (21.4, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((16.9, 4.7), [the tombstone never lands], size: 6.5pt)
  cdraw.content((16.9, 3.9), [b stays alive], size: 6pt)
  cdraw.content((11.5, 2.3), [cut anywhere inside a frame: same answer, the frame decodes or it does not], size: 6pt)
})

== append then mutate, one writer

One mutex is the engine's whole concurrency story, the same
contract sqlite's wal mode gives at harder cost. A write appends
the frame, and only then mutates the map, so the log is always at
least as current as memory: a crash between the two recovers to the
committed state, and the inverse order would leave memory holding a
state the log cannot rebuild, the exact failure recovery exists to
prevent:

#listing("rust/api/src/store/mod.rs", first: 62, last: 89, caption: [append then mutate, under one lock, and delete only writes a tombstone for a key that stands])

One design decision deletes a whole subsystem the siblings carried:
go and java wrapped multi-record groups in begin and commit markers
so a group applied atomically, because their adapters wrote several
keys per user. Here one record is one frame, the user with all its
indexes rides a single json value under a single key, so the frame
is the atomicity unit and the marker pair would be machinery
without a customer. The cost is stated too: a whole record rewrites
on every change, fine at book scale, and the compaction section is
what keeps the rewrites from growing without bound.

The write reaches the operating system but is not forced, the line
sqlite's synchronous NORMAL draws: durable across application
crashes, relaxed about power loss, with `sync` as the operator's
stronger call, one method on the engine nobody in this chapter's
wiring calls automatically.

== compaction, rewrite and atomic swap

The log only grows, and compaction is the answer. The compacted
form is the same format, the live records as fresh put frames in
key order, written to a tmp file, forced, closed, and moved over
the live log atomically, `std::fs::rename`, which on windows rides
`MoveFileEx` with replace-existing and on posix is rename(2), both
atomic for this purpose. Only then does the appender reopen on the
new file:

#listing("rust/api/src/store/compact.rs", first: 1, last: 28, caption: [the whole compaction: live puts to tmp, force, rename over the log, reopen])

Every interruption of that order recovers by replay, because the
file on disk is always a complete wal: a torn tmp never gets
renamed, the next open ignores it and the next compaction truncates
it, and a rename that landed simply leaves the compacted log for
the next open. Go needed a snapshot file plus a rotation dance
because its snapshot also carried a migration registry, a second
channel this engine does not have, the wal is the only format and
one swap suffices. Measured on this machine, dated 2026-10-13, by
the test's own sequence: one surviving key beside sixty put and
sixty delete frames grows the log to 3170 bytes, and compaction
leaves 25 bytes holding the survivor, with the post-compaction put
replaying over the swapped file on reopen.

== the user store over the engine

The adapter implements chapter 21's port, `create`, `get`, `list`,
and the key scheme is the documentation the keys enforce. The
record lives under `u:rec:`, its key the creation millisecond
sign-flipped into fixed-width hex beside the id, exactly the pair
the pagination cursor carries, so storage order and keyset order
are one notion of position and the b-tree hands the pages over
without a sort:

#listing("rust/api/src/store/users.rs", first: 27, last: 40, caption: [the order key: sign-flipped millis keep ascending time ascending in hex, the id tiebreak beside it, the cursor bound one byte past])

#listing("rust/api/src/store/users.rs", first: 110, last: 159, caption: [the port: email claim and bootstrap rules under one lock, engine first then index, and list as a range strictly after the cursor])

The stored form is not the wire form, and the split is worth
naming. The record serializes all seven components including the
password hash, because the store must verify logins after a
restart, while the wire writer chapter 21 pinned lists five and
never the hash: the hash is stored, never served, and the restart
test asserts the stronger form, the same record yields the same
etag forever, because the writer is deterministic and the bytes did
not move across a close and reopen. The by-id and by-email indexes
are derived state, rebuilt by the replay scan on open and
maintained inside create under the same lock that checked the
claim, engine written first, index published second, so a reader
either misses both or sees both. The bootstrap rule and the
conflict semantics are the mem store's, error for error, and the
keyset test drives both implementations over the same three
records, ties included, and asserts the same page.

One expectation the port cannot say: an io failure inside create
answers through the panic lane, recover's 500, because chapter 21
froze two outcomes and this chapter does not touch a landed module.
The expect is stated in the code's own message rather than hidden
in a `unwrap`.

== the wiring and the reboot proof

`main` swaps the mem store for the engine-backed one at
`RUSTAPI_DATA/users.wal`, three lines and an error lane that exits
like the bind lane does, and nothing else in the program changes:
the roles table adopts from the recovered records, the handlers
cannot tell. Sessions stay in memory this chapter, stated as the
staging it is: the `SessionStore` port froze in chapter 22 for
exactly this moment, and a later wave implements it over the engine
without a handler learning of the change:

#listing("rust/api/src/main.rs", first: 59, last: 70, caption: [the seam switch: the engine store at the configured path, the grants table adopted from the recovered records])

The end-to-end test is the chapter's proof, two boots over one
directory through the full guarded stack: register ada, log in,
shut down, open a fresh engine and a fresh stack over the same wal,
and the second login verifies against the persisted hash, the
fetched record answers the first boot's etag byte for byte, and the
list holds one item. A pre-restart token dies with the memory
session family, which is the staging above, not a loss:

#diagram([the reboot proof: two processes, one directory, everything but the sessions comes back], length: 13pt, {
  let stage(x0, title, l1, l2, fill) = {
    cdraw.rect((x0, 5.6), (x0 + 5.6, 8.2), fill: fill, radius: 0.02)
    cdraw.content((x0 + 2.8, 7.6), title, size: 6.5pt)
    cdraw.content((x0 + 2.8, 6.7), l1, size: 6pt)
    cdraw.content((x0 + 2.8, 5.9), l2, size: 6pt)
  }
  stage(0.4, [boot one], [register, login], [wal grows], luma(235))
  stage(6.6, [close], [handle dropped], [file closed], luma(235))
  stage(12.8, [boot two], [fresh engine], [replay rebuilds], luma(235))
  stage(19.0, [assert], [login 200, etag equal], [list of one], luma(222))
  cdraw.line((6.2, 6.9), (6.4, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.4, 6.9), (12.6, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.6, 6.9), (18.8, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.5, 4.4), [one directory, two lifetimes, zero lost users], size: 6pt)
})

On the pinned 1.99.0 build, dated 2026-10-13, the store test file
carries 10 green tests: the two published crc32c check values, the
frame round trip with its six refusals from the lying checksum to
the future version under an honest one, the seventy-six-length
torn-tail walk with its hand-computed boundaries, the burial that
keeps later appends reachable, the restart durability with the
stable etag and the surviving email claim, the compaction swap with
its measured 3170 to 25 bytes and the post-compaction replay, the
adapter's keyset parity against the mem store over the same ties,
two hundred concurrent puts through eight threads all accounted
after a reopen, the reboot over the real guarded stack, and the
parent directory created on open. The whole engine is four files,
493 lines, small enough to be read whole, which is the point of
owning it, and the crate's whole is 102 tests this wave, the 66
landed ones green unchanged, which is the point of the seam.

sources: RFC 3720 section B.4 for the crc32c check values
`0xE3069283` over `"123456789"` and `0x8A9136AA` over thirty-two
zero bytes, at rfc-editor.org, accessed 2026-10-13. The castagnoli
reflected polynomial `0x82F63B78` verified against the same
document. `std::fs::rename`'s windows behavior read from the
offline 1.99.0 html share under
`~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html`,
accessed 2026-10-13. The wal framing, the torn-tail recovery
argument, the append-then-mutate order, the synchronous NORMAL
analogy, and the compaction trade from the sibling store chapters,
go book 4 chapter 23 and java book 4 chapter 24 of this corpus,
including go's begin and commit markers and java's poisoned engine,
the two mechanisms this lane's one-frame-per-record design does not
need. The byte measurements, 3170 to 25 and the 75-byte log walked
at 76 lengths, produced by `cargo test --locked` under
`CARGO_NET_OFFLINE=true` and a probe binary on the same machine,
dated 2026-10-13. All other measurements, 10 tests and the crate's
102 this wave, produced by `cargo test --locked` under
`CARGO_NET_OFFLINE=true` on the pinned build, dated 2026-10-13.
