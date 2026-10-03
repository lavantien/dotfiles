#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= duckdb and sqlite together: choosing the engine

This book now embeds two engines, and the interesting question is
which workload each one owns. This chapter runs both in one process,
attached to each other through duckdb's sqlite extension, pins what
crosses the boundary and what breaks on it, proves the two engines
agree on this repo's real schema, and closes with the selection rule
the capstone follows and the v2.0 preview already visible on the
horizon.

== attach, two engines in one process

Duckdb speaks sqlite through an extension, and the whole integration
is two statements:

#snippet("INSTALL sqlite;\nATTACH 'chat.db' AS s (TYPE sqlite);", lang: "sql")

`make duckdb-tools` warms the extension into the home cache so the
install is a no-op offline, and the attach gives full read and write
access to the file, transactions included, with the tables addressable
as `s.things`. The samples keep the ownership split deliberate:
modernc creates and owns the sqlite files, duckdb attaches them:

#diagram([one process, two engines, one file, no server in sight], length: 13pt, {
  cdraw.rect((0.0, 6.8), (9.0, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.5, 8.25), [duckdb], size: 6.5pt)
  cdraw.content((4.5, 7.15), [joins, aggregates, copy out], size: 6pt)
  cdraw.rect((0.0, 3.8), (9.0, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.5, 5.25), [modernc sqlite], size: 6.5pt)
  cdraw.content((4.5, 4.15), [creates the schema, referees], size: 6pt)

  cdraw.line((9.0, 7.8), (12.6, 7.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.3, 8.5), [attach, TYPE sqlite], size: 6pt)
  cdraw.line((9.0, 4.8), (12.6, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((10.4, 4.0), [owns], size: 6pt)
  cdraw.rect((12.7, 4.6), (21.9, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((17.3, 7.05), [one sqlite file], size: 6.5pt)
  cdraw.content((17.3, 5.95), [read and written by both], size: 6pt)

  cdraw.content((11.0, 3.0), [no export step, no server, one process], size: 6.5pt)
  cdraw.content((11.0, 1.9), [the extension is engine-version specific], size: 6pt)
})

The canonical shape is dimensions in sqlite, facts in duckdb, and one
query reading both without either engine copying data to the other by
hand:

#listing("infrastructure/samples/ch12/attach_test.go", first: 64, last: 128, caption: [the join across the engine boundary, inner drops the unmatched region, left join counts it])

The `ap` charge with no row in sqlite is the join semantics made
assertable: an inner join drops it, a left join keeps it with a null
name, and the probe checks both.

== writing back through the attach

Reads are half the claim. The attach is a full citizen, duckdb can
insert into the sqlite file, and the referee is a fresh modernc
connection opened after, one that never talked to duckdb and only
reads the file:

#listing("infrastructure/samples/ch12/writeback_test.go", first: 12, last: 66, caption: [duckdb writes two rows, modernc reads three, and the sqlite rowids continue where modernc left off])

The rowid detail matters more than it looks: duckdb's inserts continue
sqlite's `integer primary key` sequence from where the owner left it,
so the file's keying discipline survives a second writer engine. The
same transactionality the sqlite chapters probed belongs to the file,
and both engines see it.

== affinity, loose typing meets strict columns

Sqlite's typing is advisory, `INT` suggests, storage decides, and
duckdb's columns are strict, so the attach needs a mapping. The probe
pins it:

#listing("infrastructure/samples/ch12/affinity_test.go", first: 38, last: 70, caption: [INT, TEXT, REAL become BIGINT, VARCHAR, DOUBLE, and the scan delivers int64, string, float64])

The mapped types are not cosmetic, they are what the go scan delivers:
int64, string, float64, exactly as if the table had been created in
duckdb. The mapping is also where ragged data breaks, because sqlite
happily stores text in an int column and duckdb will not:

#listing("infrastructure/samples/ch12/affinity_test.go", first: 72, last: 139, caption: [the ragged column fails with an error that names its own fix, then sqlite_all_varchar reads it as text])

Two outcomes, both asserted. A plain attach fails the read with a
Mismatch Type Error whose message names `sqlite_all_varchar`, an error
that documents its own escape hatch. And the setting must come before
the attach: `SET GLOBAL sqlite_all_varchar = true` on a fresh
connection, then attach, and every column reads as varchar, the three
rows arriving as the strings `1`, `oops`, `3`. The operational reading:
when a legacy file is ragged, take it as text and cast the columns you
trust, one at a time, where the values are used.

== one statement to parquet

The archival path for a live operational database is a single `COPY`
through the attach, sqlite table in, parquet file out:

#listing("infrastructure/samples/ch12/copyout_test.go", first: 12, last: 41, caption: [the ledger built by modernc, then one copy statement through the attach])

The probe reads the parquet back row for row against a referee read
straight from sqlite after the copy, and the two row sets must match
exactly. Then the part sqlite never could do on its own:

#listing("infrastructure/samples/ch12/copyout_test.go", first: 67, last: 105, caption: [the referee agrees, and the archive itself answers aggregates])

The copy closes the loop this chapter keeps drawing: the operational
engine owns the writes, the analytical engine owns the scans, and the
boundary between them is a file format both speak.

== two engines, one answer

Companionability earns trust when the two engines can be checked
against each other on a real schema rather than a toy. The parity
probe builds the capstone's actual migrations, `0001_init.sql` and
`0002_rollup.sql` verbatim, in sqlite through modernc, loads a known
fixture, and asserts the foreign key still rejects a ghost room:

#listing("infrastructure/samples/ch12/parity_test.go", first: 31, last: 89, caption: [the capstone schema and fixture, built exactly as the migrations build it])

Then the same question, top rooms by message count, is answered twice:
sqlite through the 0002 view, duckdb with its own group by over the
attached tables, the sqlite-defined view never consulted:

#listing("infrastructure/samples/ch12/parity_test.go", first: 91, last: 163, caption: [the view, the group by, and the hand-derived expectation must all agree])

Three parties, one truth: the view, the group by over the attach, and
the counts derived by hand in the test. The schema crosses the
boundary with the data, duckdb can even read `s.room_counts`, the
sqlite-defined view, directly. One dialect edge is worth naming while
it is cheap: this works because sqlite runs the schema verbatim.
Porting DDL the other way, running sqlite's `create table` statements
in duckdb directly, hits small disagreements, `at` is a reserved word
in duckdb DDL where sqlite accepts it as a column name, so parity
through the attach is the safer instrument than translation.

== the cli lane, same binary

The pinned `duckdb.exe` from `make duckdb-tools` is the same 1.5.5 the
dll lane links, and it runs plain sql scripts with csv output, the
shape a shell pipeline consumes:

#listing("infrastructure/samples/ch12/cli_test.go", first: 17, last: 67, caption: [one script, csv mode, headers and rows on stdout, version asserted])

Two small truths are pinned there. The script's last statement is
`select version()`, so the cli lane asserts the same pin the go lane
does. And the windows cli emits CRLF, which the probe normalizes
before comparing lines, because a pipeline that forgot would match
nothing and fail loudly, which is the right direction for that
surprise.

== choosing the engine

Four durable stores appear across this book's capstone, and the
selection rule is a question about the workload:

#diagram([the workload picks the engine, embedded before server], length: 13pt, {
  cdraw.rect((0.6, 9.0), (23.0, 10.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.8, 9.6), [what does the workload ask for], size: 6.5pt)

  let lane(x0, engine, ask, owns) = {
    cdraw.line((x0 + 2.7, 9.0), (x0 + 2.7, 8.2), stroke: luma(100), mark: (end: ">>"))
    cdraw.rect((x0, 5.2), (x0 + 5.4, 8.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.7, 7.6), [#engine], size: 6.5pt)
    cdraw.content((x0 + 2.7, 6.5), [#ask], size: 6pt)
    cdraw.content((x0 + 2.7, 5.6), [#owns], size: 6pt)
  }
  lane(0.0, [sqlite], [point writes, one writer], [the chat file])
  lane(6.0, [duckdb], [scans, aggregates, files], [the analytics file])
  lane(12.0, [mongo], [shared documents, pipelines], [the history collection])
  lane(18.0, [nats kv], [ephemeral, ttl expiry], [the presence bucket])

  cdraw.content((11.0, 3.9), [embedded first, a server only when sharing forces it], size: 6.5pt)
  cdraw.content((11.0, 2.8), [attach is the bridge, not a fifth store], size: 6pt)
})

Sqlite owns the transactional seat: point access, single digit writes,
one writer with the busy ladder from
#xref-to("infrastructure", "sqlite-transactions") keeping commits
honest. Duckdb owns the analytical seat: scans, group bys, parquet and
csv, and a reader concurrency model where nobody parks, the mvcc
contrast #xref-to("infrastructure", "duckdb") probed against that same
ladder. Mongo earns a server when the documents are shared by many
services and the aggregation runs where the data lives, the
#xref-to("infrastructure", "mongo") trade. And nats kv is not a
database at all: presence wants ttl expiry and watch semantics, and
holding it in a durable store would mean sweeping stale rows forever,
the exact sweep #xref-to("infrastructure", "jetstream") had to write
anyway.

The rule the diagram encodes: embedded first, and a server only when
sharing forces it. The attach is a bridge between the two embedded
engines, useful for the parity and archival shapes this chapter
probed, and it is not a fifth home for data.

== the capstone, four stores named

The capstone's topology is the decision applied. The chat service
writes sqlite, one file, one writer, `busy_timeout` for the
administrative second writer. The analytics service, new beside it,
consumes the same CHAT stream through its own `analysts` durable and
writes one duckdb file, its own offset, its own engine, lagging or
replaying without history's cursor moving. History keeps mongo and its
pipelines, because its consumers share the collection. Presence stays
in the nats kv bucket with the ttl doing the expiry. Each store has
exactly one writer service, which is the whole reason no two writers
share a lock domain, and #xref-to("infrastructure", "capstone1") draws
the picture.

== the v2.0 horizon

Version 2.0, "Cyanoptera", exists today only as a feature-frozen
preview: the `v2.0-cyanoptera` branch publishes rolling tarball
artifacts to artifacts.duckdb.org with no tagged release, and the final
is announced for October 2026. What it brings is a client-server
protocol named Quack, async I/O, rewritten recursive CTEs, and faster
parquet scans. Two gaps matter for this repo specifically: the windows
extensions are not yet published for the 2.0 client, which would leave
the sqlite attach lane of this chapter dead on windows, and the go
module tag will move to a v2.20000.x-style encoding of the core
version. Until the release lands, 1.5.5 stays the pin and 1.4.5 is the
line if a longer support window ever matters more than the features.

#callout("note", "the re-pin checklist, written while it is cheap", [
  Five things make a future re-pin a chore instead of an incident.
  Keep the exact-string `version()` asserts centralized, one per
  module, so a drift breaks in one obvious place. Re-run the sqlite
  extension warm in `tools/build-duckdb.sh`, because the extension is
  engine-version specific and a new engine will not load yesterday's
  binary. Move the go.mod tag to the new v2.20000.x-style encoding and
  let the version test confirm the decoding. Re-record the cli and
  libduckdb sha256s in `tools/build-duckdb.sh` against the release's
  published digests. And recheck windows extension availability before
  promising the attach lane there, because today's 2.0 preview ships
  none.
])

sources: duckdb.org documentation for the sqlite extension and attach
scanner settings, the csv and parquet pages already cited in the
previous chapter, install.duckdb.org for the 1.5.5 binaries, the
duckdb-go repository and tag list, and the artifacts.duckdb.org
v2.0-cyanoptera preview channel, all accessed 2026-09-20. Verified by
the ch12 probe suite, 7 tests behind the `duckdb_use_lib` tag against
the pinned 1.5.5 dll and modernc 3.53.4, green under `make verify-go`
2026-09-20.
