#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= sqlite: wal, locking, crash semantics

Rollback mode's commit waits for readers,
#xref-to("infrastructure", "sqlite-transactions") established that.
Write-ahead logging removes the wait by changing where the commit
writes: instead of modifying the database file in place under an
exclusive lock, a wal writer appends the changed pages to a sidecar
`-wal` file and returns. Readers walk the database file plus the sidecar,
each transaction pointed at the point-in-time snapshot it started at.
One writer at a time still, but readers never block a writer and a
writer never blocks readers.

== the mode is a property of the file

#listing("infrastructure/samples/ch08/wal_test.go", first: 33, last: 65, caption: [wal on, the sidecar appears on write, and a fresh open reports wal unprompted])

#diagram([the wal trio on disk, and the one pragma that refuses to queue], length: 13pt, {
  cdraw.rect((0.0, 8.0), (5.0, 9.0), fill: luma(205), radius: 0.02)
  cdraw.content((2.5, 8.5), [chat.db], size: 6.5pt)
  cdraw.rect((0.0, 6.5), (5.0, 7.5), fill: luma(235), radius: 0.02)
  cdraw.content((2.5, 7.0), [chat.db-wal], size: 6.5pt)
  cdraw.rect((0.0, 5.0), (5.0, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((2.5, 5.5), [chat.db-shm], size: 6.5pt)

  cdraw.content((14.0, 8.5), [header carries journal_mode=wal], size: 6pt)
  cdraw.content((14.0, 7.0), [appears on first write, appends], size: 6pt)
  cdraw.content((14.0, 5.5), [shared memory index], size: 6pt)

  cdraw.content((11.0, 3.9), [a fresh open reports wal, unprompted], size: 6.5pt)
  cdraw.line((11.0, 3.4), (11.0, 2.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((5.0, 0.6), (17.0, 2.4), fill: luma(235), radius: 0.02)
  cdraw.content((11.0, 1.85), [the mode switch cannot queue], size: 6.5pt)
  cdraw.content((11.0, 0.75), [store.Open retries the switch], size: 6pt)
})

The reopen assertion matters operationally: `journal_mode` is stored
in the database header, so setting it once is enough for every future
connection, including ones made by tools that never ran the pragma.
That is why `store.Open` can set it defensively on every open at zero
cost:

#listing("infrastructure/capstone/internal/store/store.go", first: 23, last: 53, caption: [open: wal with a retry, busy timeout, foreign keys, then migrations])

The retry loop around the switch is the one place sqlite refuses to
queue: the journal-mode change cannot wait behind another connection,
so two services racing to create the same fresh file retry briefly
instead of failing.

== checkpointing, the price of the sidecar

The sidecar grows until something folds it back. Sqlite checkpoints
automatically when it reaches a threshold, and the operator's lever is
the explicit form:

#listing("infrastructure/samples/ch08/wal_test.go", first: 69, last: 106, caption: [truncate checkpoint resets the sidecar without losing a row])

#diagram([the sidecar before and after a truncate checkpoint], length: 13pt, {
  cdraw.content((3.0, 9.8), [grown], size: 6.5pt)
  cdraw.rect((0.0, 4.4), (2.8, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((1.4, 4.9), [chat.db], size: 6pt)
  cdraw.rect((3.6, 1.6), (5.6, 9.0), fill: luma(235), radius: 0.02)
  for y in range(18) {
    cdraw.line((3.7, 2.0 + y * 0.4), (5.5, 2.0 + y * 0.4), stroke: luma(220))
  }
  cdraw.content((4.6, 1.0), [-wal], size: 6pt)

  cdraw.line((6.4, 5.2), (11.4, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((8.9, 6.3), [truncate], size: 6pt)

  cdraw.content((15.0, 9.8), [after checkpoint], size: 6.5pt)
  cdraw.rect((12.0, 4.4), (14.8, 5.4), fill: luma(205), radius: 0.02)
  cdraw.content((13.4, 4.9), [chat.db], size: 6pt)
  cdraw.rect((15.6, 3.9), (17.6, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((16.6, 3.3), [-wal, reset], size: 6pt)

  cdraw.content((9.0, 0.4), [all 100 rows survive], size: 6.5pt)
  cdraw.content((12.0, -0.7), [a reader on an old snapshot reports busy], size: 6pt)
})

The probe asserts the sidecar shrinks and all hundred rows survive.
The `busy` return value is the other lesson, and a second probe pins
both halves: a checkpoint cannot finish while a reader holds an old
snapshot, reported as nonzero busy, and the same checkpoint returns
zero busy once the reader releases, the rare case where wal still
makes someone wait.

== backup without a backup api

`VACUUM INTO` writes a consistent snapshot of the whole database to a
fresh path, in one statement, without holding locks on the target and
without driver-specific backup machinery:

#listing("infrastructure/samples/ch08/wal_test.go", first: 110, last: 150, caption: [vacuum into: the backup opens, passes integrity_check, and carries no sidecar])

#diagram([vacuum into: the live trio against the one-file backup], length: 13pt, {
  cdraw.content((2.0, 8.2), [the live trio], size: 6.5pt)
  cdraw.rect((0.0, 6.4), (4.0, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((2.0, 6.9), [chat.db], size: 6pt)
  cdraw.rect((0.0, 4.9), (4.0, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((2.0, 5.4), [chat.db-wal], size: 6pt)
  cdraw.rect((0.0, 3.4), (4.0, 4.4), fill: luma(235), radius: 0.02)
  cdraw.content((2.0, 3.9), [chat.db-shm], size: 6pt)

  cdraw.line((4.0, 5.4), (9.4, 5.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.7, 6.5), [vacuum into], size: 6pt)

  cdraw.rect((9.4, 4.4), (15.8, 6.6), fill: luma(205), radius: 0.02)
  cdraw.content((12.6, 6.05), [backup.db], size: 6.5pt)
  cdraw.content((12.6, 4.95), [standalone file], size: 6pt)

  cdraw.content((12.6, 3.4), [integrity_check ok], size: 6pt)
  cdraw.content((12.6, 2.3), [no sidecar], size: 6pt)
  cdraw.content((12.6, 1.2), [restore: copy one file], size: 6pt)
})

The last assertion is the easy one to forget: a snapshot taken this
way is a standalone database, not a wal trio, so restoring it is
copying one file.

== crash semantics, by experiment

The durability claim, a crash leaves the old state or the new, never
half, is testable. The probe forks a child process that opens the
database, begins, inserts, and exits hard, `os.Exit(3)`, no commit, no
close. It is as close to pulling power as a test suite honestly gets:

#listing("infrastructure/samples/ch08/wal_test.go", first: 156, last: 199, caption: [parent seeds, child dies mid transaction, parent reopens and checks])

#diagram([the crash experiment, parent and child on one timeline], length: 13pt, {
  cdraw.rect((1.6, 9.0), (6.4, 9.9), fill: luma(205), radius: 0.02)
  cdraw.content((4.0, 9.45), [parent], size: 6.5pt)
  cdraw.rect((13.6, 9.0), (18.4, 9.9), fill: luma(205), radius: 0.02)
  cdraw.content((16.0, 9.45), [child], size: 6.5pt)
  cdraw.line((4.0, 9.0), (4.0, 0.6), stroke: luma(220))
  cdraw.line((16.0, 9.0), (16.0, 0.6), stroke: luma(220))

  cdraw.rect((3.85, 7.65), (4.15, 7.95), fill: luma(100))
  cdraw.content((6.9, 7.8), [seeds, closes], size: 6pt)
  cdraw.rect((15.85, 6.25), (16.15, 6.55), fill: luma(100))
  cdraw.content((12.0, 6.4), [opens, begins, inserts], size: 6pt)
  cdraw.rect((15.85, 4.85), (16.15, 5.15), fill: luma(100))
  cdraw.content((12.0, 5.0), [exit(3), no commit], size: 6pt)
  cdraw.content((19.7, 5.0), [tail frame ignored], size: 6pt)
  cdraw.rect((3.85, 3.45), (4.15, 3.75), fill: luma(100))
  cdraw.content((6.0, 3.6), [reopens], size: 6pt)
  cdraw.rect((3.85, 2.05), (4.15, 2.35), fill: luma(100))
  cdraw.content((8.9, 2.2), [row intact, integrity ok], size: 6pt)
  cdraw.rect((3.85, 0.65), (4.15, 0.95), fill: luma(100))
  cdraw.content((7.9, 0.8), [new writes accepted], size: 6pt)

  cdraw.content((11.0, -0.6), [the durability knob: synchronous off, normal, full, extra], size: 6.5pt)
})

The parent then asserts three things in order: the committed row is
still there, `integrity_check` says ok, and the database accepts new
writes, meaning recovery actually ran, not merely that nothing broke.
Behind the scenes the reopening connection found the sidecar, saw an
uncommitted tail frame, and ignored it, which is the entire crash
safety story in one sentence.

The `synchronous` pragma is the knob that trades commit latency
against how fanatical the fsyncs are, and the probe pins the readback
values for all four levels, off through extra, so the settings in
prose always mean something concrete:

#listing("infrastructure/samples/ch08/wal_test.go", first: 230, last: 252, caption: [the four synchronous levels and their numeric readback])

The capstone runs the default, full, because a chat log is not worth
a data race against physics, and the raft store in the patterns book
makes the same choice for harder reasons.

#callout("note", "wal is not a server", [
  Wal mode adds reader and writer concurrency inside one process
  boundary, many connections in one or several processes on one
  machine. It does not turn sqlite into a networked database, and the
  file must stay on a filesystem with working locking semantics,
  which is why the compose stack gives the chat service a named
  volume and exactly one writer.
])

sources: sqlite.org wal.html for the architecture, checkpoints, and
the reader and writer concurrency guarantees, lockingv3 for the
comparison ladder, lang/vacuum for `VACUUM INTO`, accessed 2026-09-10.
Verified by the ch08 probe suite, 6 tests including the subprocess
crash and the reader-blocked checkpoint, green under `make verify`
2026-09-10.
