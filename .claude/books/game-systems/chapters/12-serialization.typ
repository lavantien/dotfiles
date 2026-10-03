#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= serialization and save systems

A replay and a save file are the same question at different sizes:
how does game state cross bytes without losing the determinism the
previous five chapters built. The answer here is the input log. A
match is recorded as its seed plus one entry per turn, and playback
re-runs the same simulation on the same inputs, so the file is
dozens of bytes and the state hash at the end, a 64-bit fold of the
whole world that chapter 13 builds, proves the run matched. The alternative, snapshotting the whole world every turn,
spends kilobytes per turn and buys a second, driftier
representation of the game to keep in sync.

== the format is the contract

#listing("game-systems/samples/src/Ch12/ReplayCodec.cs", first: 21, last: 38, caption: [magic, version, length prefixed fields, twelve bytes per turn])

Every field is fixed width, big endian, written with
`BinaryPrimitives`, and the sizes are stated where they are used.
The magic answers "is this our file", the version answers "can
this build read it", and the version policy is the part that keeps
replays loadable: version 1 files load forever, later formats
migrate forward, and nothing is ever parsed by guessing. The tests
treat the codec as a protocol implementation, not a convenience:
wrong magic, unknown version, and a turn list that claims more
entries than the bytes hold are each rejected with a message
naming the field that broke.

#diagram([the replay file as one byte map, 21 of header, 12 per turn], length: 13pt, {
  // 0.95 units per byte, fields light, header ends at byte 21
  let b0 = 1.0
  let w = 0.95
  let fields = ((0, 4, [magic, 4]), (4, 5, []), (5, 9, [width, 4]), (9, 17, [seed, 8]), (17, 21, [count, 4]))
  for (s, e, t) in fields {
    cdraw.rect((b0 + s * w, 5.6), (b0 + e * w, 7.0), fill: luma(235), radius: 0.02)
    if t != [] { cdraw.content((b0 + (s + e) / 2 * w, 6.3), t, size: 6pt) }
  }
  cdraw.content((b0 + 4.5 * w, 7.7), [version, 1], size: 6pt)
  cdraw.line((b0 + 4.5 * w, 7.4), (b0 + 4.5 * w, 7.0), stroke: luma(100))
  for tick in (0, 4, 5, 9, 17, 21) {
    cdraw.line((b0 + tick * w, 5.6), (b0 + tick * w, 5.35), stroke: luma(100))
    cdraw.content((b0 + tick * w, 4.7), [#tick], size: 6pt)
  }
  cdraw.content((11.5, 7.7), [21 bytes of header], size: 6pt)

  let turns = ((0, 4, [player, 4]), (4, 8, [angle, 4]), (8, 12, [power, 4]))
  for (s, e, t) in turns {
    cdraw.rect((b0 + s * w, 1.6), (b0 + e * w, 3.0), fill: luma(235), radius: 0.02)
    cdraw.content((b0 + (s + e) / 2 * w, 2.3), t, size: 6pt)
  }
  for tick in (0, 4, 8, 12) {
    cdraw.line((b0 + tick * w, 1.6), (b0 + tick * w, 1.35), stroke: luma(100))
    cdraw.content((b0 + tick * w, 0.7), [#tick], size: 6pt)
  }
  cdraw.content((14.2, 3.55), [12 bytes per turn], size: 6pt)
  cdraw.content((6.7, -0.3), [big endian, fixed width, binaryprimitives], size: 6pt)
})

#listing("game-systems/samples/src/Ch12/ReplayCodec.cs", first: 40, last: 66, caption: [load validates before it allocates, reads exactly what save wrote])

Two properties the tests pin are worth defending in review. The
round trip is byte deterministic, the same replay saves to the same
bytes every time, which is what lets a hash of the file stand in
for a hash of the match. And the input log size test is the whole
argument for the design, four turns cost 69 bytes against 16
kilobytes of per turn terrain snapshots, more than two orders of
magnitude, and the gap widens with match length because the log
grows per turn while snapshots grow per turn times world size.

#callout("warning", "when snapshots are the right answer", [
  Input logs require the simulation to be a function of its inputs.
  The capstone is, by construction, that is what deterministic math,
  owned randomness, and deferred structural changes buy. The
  moments a game stops being a pure function, a network correction
  rewinds state, a patch changes balance constants, the input log
  replays the wrong match, and the honest fix is periodic
  checkpoints inside the log, a full state snapshot every N turns
  so playback resynchronizes instead of drifting. Version the
  constants file like the format. The capstone exercises both
  predictions of this callout: its replay v2 bumped the magic and
  widened the turn record when weapons joined the log, and the
  character profile saves as a checkpoint, chapter 14's codec.
])

== the capstone save file

The capstone's checkpoint rides the same discipline on SQLite: one
file, six tables, written whole inside one transaction, a schema
version standing where the binary codecs keep their magic.
`Campaign.Save(path)` records the sheet, the loadout, the upgrade
levels, the pets in slot order, the stages cleared per expedition,
and the profile seed, because a loaded campaign has to draw the
futures the seed always drew. Every call opens the file, commits,
and closes, pooling off, so no handle outlives a save or a load and
the writer can be gone by the time the reader arrives. The paged inventory grid that chapter 15 builds is
the delicate rebuild. Add fills the next empty cell and Take empties
the first stacks, so the restore replays the cell vector through
both, reserving each hole with a sentinel id until the real stacks
sit where they belong, holes and page count included.

#listing("game-systems/capstone/src/Persistence/SaveStore.cs", first: 240, last: 268, caption: [the grid rebuilds through the public add and take, sentinel holes first, exact for every layout the game produces])

The round trip tests play a scripted campaign, hat bought and
equipped so a hole stays behind, boss cleared, egg hatched, weapon
upgraded, save, load, and assert the two campaigns agree cell for
cell, pet for pet, counter for counter, and on the state hash, which
covers the grid layout. A pinned bundle keeps the engine at sqlite
3.53.4, asserted by `select sqlite_version()` in the suite.

#flow(
  [the save as one transaction, the grid rebuilt through add and take],
  node((0, 0), [save: six tables,#linebreak()one transaction]),
  node((2, 0), [load: rows by cell]),
  node((4, 0), [sentinels fill#linebreak()the gaps]),
  node((4, 1.7), [stacks added#linebreak()in order]),
  node((2, 1.7), [sentinels taken]),
  node((0, 1.7), [grid exact,#linebreak()holes intact]),
  edge((0, 0), (2, 0), "-|>"),
  edge((2, 0), (4, 0), "-|>"),
  edge((4, 0), (4, 1.7), "-|>"),
  edge((4, 1.7), (2, 1.7), "-|>"),
  edge((2, 1.7), (0, 1.7), "-|>"),
)

sources: length prefixed binary framing and magic plus version
discipline follow conventional protocol practice, cross checked
against System.Buffers.Binary.BinaryPrimitives on
learn.microsoft.com for the exact size span contract that bit this
chapter's first draft, accessed 2026-09-08. Verified by `dotnet
test books/game-systems/samples/GameSystemsBook.slnx`, 6 tests in
`GameSystems.Samples.Tests.Ch12`.
