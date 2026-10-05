#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= sqlite in production: embedded kvs and game saves

"Sqlite in production" draws a knowing smile from people who have
only met it as the thing under their phone. The honest position is
narrower and stronger: sqlite is the answer whenever the data belongs
to one machine, one writer, one process family, and it is a liability
the moment that stops being true. Four capstones across this corpus
make the argument concrete, this book's chat file the fourth to ship
a sqlite file.

== three stores, one engine, three shapes

The raft store in the patterns book,
#xref-to("patterns", "capstone"), persists
the consensus triple, term, vote, and log, as two tables over a wal
file with `synchronous=full`, because a replicated log's promise is
"the acknowledged entry survives the crash", and the store opens with
the same `busy_timeout` retry dance this book's `store.Open` uses.
The interesting design choice is honesty about write shape: the log
can truncate and diverge, so the store rewrites the log table whole
inside one transaction instead of maintaining a mirroring tail that
can drift.

The game save store, #xref-to("game-systems", "serialization"),
writes the whole campaign state, sheet, pets, loadout, upgrades,
counters, into six tables in one transaction, drops and recreates on
every save, and opens read-only for loads. A save file wants snapshot
semantics, not incremental mutation, and the transaction gives the
atomicity the temp-file rename trick used to provide. The profile seed
rides along so a loaded run draws the same futures a never-saved run
would have, determinism preserved across persistence.

And the dsa capstone, #xref-to("dsa", "capstone"), uses sqlite as the
reference implementation in a comparator suite: the lsm engine and
sqlite loaded with the same deterministic keyspace must answer
identically on every key and every negative, which makes the database
an executable specification for a storage engine, the most demanding
use of the three.

#diagram([one engine, four production shapes], length: 13pt, {
  let quad(x0, y0, title, l1, l2, l3) = {
    cdraw.rect((x0, y0), (x0 + 11.4, y0 + 4.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 5.7, y0 + 3.7), [#title], size: 6.5pt)
    cdraw.content((x0 + 5.7, y0 + 2.6), [#l1], size: 6pt)
    cdraw.content((x0 + 5.7, y0 + 1.5), [#l2], size: 6pt)
    cdraw.content((x0 + 5.7, y0 + 0.45), [#l3], size: 6pt)
  }
  quad(0.0, 5.2, [raft hard state], [2 tables, synchronous full], [the log table rewritten whole], [inside one transaction])
  quad(12.2, 5.2, [game saves], [6 tables, one transaction], [drop and recreate per save], [read-only loads])
  quad(0.0, 0.4, [dsa comparator], [same deterministic keyspace], [lsm and sqlite must agree], [an executable specification])
  quad(12.2, 0.4, [this book's chat file], [the service's only durable state], [one file on one volume], [one writer, busy_timeout])
})

== the embedded key value shape

Stripped of sql, sqlite is a b-tree keyed store with transactions,
and a `create table kv(k text primary key, v blob) without rowid`
table over it is a durable kv with single-digit-millisecond writes and
crash safety for free. The raft hard state table is exactly this
shape, two rows wide. The rules that make the shape production-grade
are the ones this book already built:

#snippet("wal on open, one writer process, busy_timeout for the\n"
  + "administrative second writer, vacuum into for backups, and the\n"
  + "crash probe from sqlite-wal in the test suite so the guarantee is\n"
  + "asserted, not assumed.", lang: "text")

#diagram([a without-rowid table is a durable kv, two rows wide in the raft case], length: 13pt, {
  cdraw.rect((0.0, 4.2), (14.0, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((7.0, 8.1), [kv table, without rowid], size: 6.5pt)
  cdraw.rect((0.4, 6.9), (7.0, 7.8), fill: luma(205), radius: 0.02)
  cdraw.content((3.7, 7.35), [k text, primary key], size: 6pt)
  cdraw.rect((7.0, 6.9), (13.6, 7.8), fill: luma(205), radius: 0.02)
  cdraw.content((10.3, 7.35), [v blob], size: 6pt)
  cdraw.rect((0.4, 5.75), (7.0, 6.65), fill: white, radius: 0.02)
  cdraw.content((3.7, 6.2), [term], size: 6pt)
  cdraw.rect((7.0, 5.75), (13.6, 6.65), fill: white, radius: 0.02)
  cdraw.content((10.3, 6.2), [7], size: 6pt)
  cdraw.rect((0.4, 4.6), (7.0, 5.5), fill: white, radius: 0.02)
  cdraw.content((3.7, 5.05), [vote], size: 6pt)
  cdraw.rect((7.0, 4.6), (13.6, 5.5), fill: white, radius: 0.02)
  cdraw.content((10.3, 5.05), [node-b], size: 6pt)
  cdraw.content((7.0, 3.5), [one b-tree, keyed by k], size: 6pt)

  cdraw.content((18.9, 8.7), [production rules], size: 6.5pt)
  cdraw.line((14.9, 3.1), (14.9, 8.0), stroke: luma(100))
  cdraw.line((14.0, 7.5), (14.9, 7.5), stroke: luma(100))
  cdraw.line((14.0, 3.6), (14.9, 3.6), stroke: luma(100))
  cdraw.content((19.0, 7.5), [wal on open], size: 6pt)
  cdraw.content((19.0, 6.4), [one writer], size: 6pt)
  cdraw.content((19.0, 5.3), [busy_timeout], size: 6pt)
  cdraw.content((19.0, 4.2), [vacuum into backups], size: 6pt)
  cdraw.content((19.0, 3.1), [crash probe in suite], size: 6pt)
})

== where it ends

The boundary is equally plain. One machine: the file is a file, and
nothing in it survives the machine's disk dying, so durability beyond
the machine is replication, which is why the raft store exists and why
it does not try to be a networked sql server. One writer at a time:
wal lets readers pile on, but writes serialize, and a second writer
arriving over the network is a sign the design wanted a client-server
database. And no nfs, no cloud-synced folder, nothing that breaks the
locking semantics the wal chapter quietly depends on.

The analytical workload is the fourth crossing, and it stays
embedded. When the questions stop being point lookups and become scans
and aggregates over the same data, the answer is still not a server,
it is the other embedded engine:
#xref-to("infrastructure", "duckdb-sqlite") draws the decision table,
and the capstone runs both engines side by side, each behind its own
service and its own file.

#diagram([where sqlite ends, and what owns the far side of each line], length: 13pt, {
  cdraw.content((5.0, 9.0), [three boundary conditions], size: 6.5pt)

  cdraw.rect((0.0, 7.1), (9.2, 8.1), fill: luma(235), radius: 0.02)
  cdraw.content((4.6, 7.6), [the machine's disk dies], size: 6pt)
  cdraw.line((9.2, 7.6), (10.6, 7.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((10.6, 7.1), (20.0, 8.1), fill: luma(205), radius: 0.02)
  cdraw.content((15.3, 7.6), [replication, raft's job], size: 6.5pt)

  cdraw.rect((0.0, 5.0), (9.8, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.9, 5.5), [a networked second writer], size: 6pt)
  cdraw.line((9.8, 5.5), (11.2, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((11.2, 5.0), (20.0, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((15.6, 5.5), [a client-server db], size: 6.5pt)

  cdraw.rect((0.0, 2.9), (10.0, 3.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 3.4), [nfs, cloud-synced folders], size: 6pt)
  cdraw.line((10.0, 3.4), (11.4, 3.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((11.4, 2.9), (20.0, 3.9), fill: luma(205), radius: 0.02)
  cdraw.content((15.7, 3.4), [keep it local], size: 6.5pt)

  cdraw.content((10.0, 1.7), [each crossing names the tool on the other side], size: 6pt)
})

#callout("note", "the register's claim, graded", [
  The analysis book's employment claims track where the resume says
  sqlite and the repos say sqlite, and the embedded stores in this
  chapter's three cross references are the evidence: a replicated
  log, a game save, and an engine comparator are three different
  production loads on the same library, each with the failure modes
  probed rather than assumed. The capstone adds the fourth: a
  service's only durable state, one file on one volume.
])

sources: sqlite.org wal.html and the crash semantics chapters behind
the probes already cited, accessed 2026-09-10; the three cross
referenced stores live in books 9, 11, and 14 and are tested by their
own suites under `make verify`. Verified by the capstone store suite,
4 tests, and the ch07 and ch08 probes, green 2026-09-10.
