#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= duckdb: the embedded analytical engine

The sqlite half of this book, chapters 6 through 10, answered the
transactional question: many small reads and writes, one writer at a
time, correctness measured per transaction. This chapter opens the
analytical half with the engine this repo pins for it, duckdb 1.5.5,
released 2026-07-22 and the current stable 1.x, with 1.4.5 carrying
the long term support line. Like sqlite it is embedded, one library
inside the process, no server and no wire protocol. Unlike sqlite its
storage is columnar and its execution is vectorized, built for scans
and aggregates over millions of rows instead of point access to a
handful.

== olap is a different question

An oltp workload touches a few rows and wants each transaction
durable. An olap workload touches most of the table and wants a
number: revenue per region, messages per hour, distinct senders per
room. The queries are fewer and heavier, and the storage layout that
serves them is not the one sqlite chose.

#diagram([the same four rows, row store pages against columnar runs], length: 13pt, {
  cdraw.content((5.1, 10.6), [row store], size: 6.5pt)
  let rowc(y, label) = {
    cdraw.rect((0.2, y), (10.0, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((5.1, y + 0.5), [#label], size: 6pt)
  }
  rowc(8.8, [1 | general | alice | 10])
  rowc(7.6, [2 | general | bob | 20])
  rowc(6.4, [3 | random | alice | 30])
  rowc(5.2, [4 | random | carol | 40])
  cdraw.content((5.1, 4.3), [a row's fields share a page], size: 6pt)
  cdraw.content((5.1, 3.2), [sum(cents) reads every page], size: 6pt)

  cdraw.line((11.0, 6.6), (12.4, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.7, 7.7), [repack], size: 6pt)

  cdraw.content((18.7, 10.6), [columnar], size: 6.5pt)
  let col(x0, name, vals, hot) = {
    cdraw.rect((x0, 5.2), (x0 + 2.6, 9.6), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x0 + 1.3, 9.1), [#name], size: 6pt)
    for (i, v) in vals.enumerate() {
      cdraw.content((x0 + 1.3, 8.3 - i * 0.8), [#v], size: 6pt)
    }
  }
  col(13.0, [id], ([1], [2], [3], [4]), false)
  col(15.8, [room], ([gen], [gen], [rnd], [rnd]), false)
  col(18.6, [sender], ([alice], [bob], [alice], [carol]), false)
  col(21.4, [cents], ([10], [20], [30], [40]), true)
  cdraw.content((18.7, 4.3), [one run per column], size: 6pt)
  cdraw.content((18.7, 3.2), [sum(cents) reads one run], size: 6pt)
})

A row store keeps a row's fields together on the page, so summing one
column means reading every page of the table to collect a few values
from each. A columnar store keeps each column's values together, so
the same sum reads one contiguous run and never loads the rest.
Vectorized execution finishes the argument: the engine walks columns
in fixed size batches through tight loops over a single type, which
is why a group by over two million rows of a two column file answers
in milliseconds. The trade sits on the other side of the ledger:
touching whole rows one at a time, the oltp shape, means reassembling
them from column runs, which is why this book carries both engines
instead of replacing one with the other.

== embedded from go, pinned

The driver is `github.com/duckdb/duckdb-go/v2` at tag `v2.10505.0`,
and the tag encodes the engine: 10505 is 1.5.5. It registers the
`database/sql` driver name `duckdb`, takes a DSN like
`store.duckdb?threads=2` or, for a read only seat at a file somebody
else owns, `store.duckdb?threads=2&access_mode=read_only`, and speaks
the same Query, Exec, and placeholder api as every other driver in
this book.

One platform fact shapes the sample lane. The driver's prebuilt
static engine libraries are MSVC objects, so on windows the probes
ride the `duckdb_use_lib` build tag and link the pinned official dll
from `make duckdb-tools`, with zig as the cgo compiler because it
speaks gcc flags while emitting msvc objects. On linux, which is what
the analytics docker image in the capstone builds, the default static
bindings compile with no tag and no dll. The plain `go test ./...`
lane compiles none of it, so the compiler-free property the toolchain
chapter claims survives everywhere except the deliberate duckdb lanes.

The first probe is the pin itself, the same discipline the sqlite
chapters apply to `sqlite3_libversion`:

#listing("infrastructure/samples/ch11/duckdb_test.go", first: 42, last: 54, caption: [the engine version pin, exact string, the same dll the cli lane links])

`make duckdb-tools` also installs the pinned `duckdb.exe`, and the cli
is the interactive face of the same engine: point it at a file,
describe it, summarize it, pipe a script's csv output somewhere else.
The cli gets its own probe in the next chapter, and the version string
it prints when a script asks is asserted there too, so the dll, the
driver, and the cli cannot drift apart quietly.

== parquet in, parquet out

Parquet is the columnar file format the analytical world already
agreed on, and duckdb treats it as a first class citizen: `COPY` any
query to a parquet file, read one back with `read_parquet`, and never
hand marshal a row. The round trip probe writes four rows with a
stated compression and reads them back:

#listing("infrastructure/samples/ch11/parquet_test.go", first: 13, last: 73, caption: [copy to parquet with zstd, read back with read_parquet, compared row for row])

Two details in that probe earn their lines. The compression is stated,
`COMPRESSION zstd`, because the columnar win is half layout and half
encoding, and this corpus pins the encoder instead of trusting a
default. And the timestamp is cast to varchar on the way out: duckdb
timestamp columns scan into go as `time.Time`, so a probe that wants a
plain string assert casts inside the query rather than formatting in
the test.

The write side has a partitioned form that changes where a column
lives. `PARTITION_BY` writes one subdirectory per key value and drops
the partition column from the files, and `hive_partitioning` reads the
directory names back as a column, so the round trip restores what the
write removed:

#listing("infrastructure/samples/ch11/parquet_test.go", first: 75, last: 124, caption: [partition by writes g into the path, hive partitioning reads it back])

The partition column ends up stored exactly once per directory name,
which is what makes partition pruning work: a query filtering on `g`
can skip whole directories without opening a file. The probe asserts
the recovered mapping and that the three distinct values produced three
directories.

== csv, sniffed then pinned

Real analytical data arrives as csv, and duckdb's answer is the
sniffer: `read_csv_auto` infers delimiter, quoting, and types from the
file itself, and the inference is assertable because `describe` works
over the sniffed relation:

#listing("infrastructure/samples/ch11/csv_test.go", first: 15, last: 81, caption: [the sniffer infers bigint, varchar, date, and the quoted and null cases survive])

The inferred types are real: `id` comes back BIGINT, `hired` comes
back DATE, quoted commas and doubled quotes survive, and a trailing
empty field reads as null rather than the empty string. The sniffer is
a guess, though, and the second probe is the file where it guesses
wrong:

#listing("infrastructure/samples/ch11/csv_test.go", first: 83, last: 142, caption: [semicolons, single quotes, and backslash-N: the sniffer keeps score as varchar holding the literal text])

The sniffer finds the delimiter but nothing told it what null looks
like, so `score` stays VARCHAR holding the literal text `\N`, and the
probe asserts the wrongness before fixing it. The fix is three
explicit options, `delim`, `quote`, and `nullstr`, and the column goes
back to BIGINT with real nulls. The rule the pair of probes encodes:
sniff first, describe the result, and pin options the moment the sniff
is wrong, because a silent VARCHAR where a number should be poisons
every downstream aggregate.

== scans that never load the file

The claim that separates duckdb from an in-memory table is that the
file is the table. The scan probe never creates one: it generates two
million rows with `range()`, writes them once as parquet, and then
groups and sums straight off disk:

#listing("infrastructure/samples/ch11/scan_test.go", first: 15, last: 73, caption: [two million rows, no table ever created, the aggregate streams the file])

On this machine the 2 million row parquet file writes in 121ms and the
grouped scan answers in 17.6ms, and the engine is free to spill to
temp files when a query's working set exceeds memory, which is the
out-of-core behavior the chapter title promises. The correctness half
is the honest half: the per group sums are checked against closed
form arithmetic, `200000*g + 199999000000`, computed in the test and
nowhere near the engine, so a fast wrong answer still fails.

== meeting the data: describe and summarize

Exploration is a query genre of its own. `DESCRIBE` reports the
column shape of any relation, and `SUMMARIZE` scans the values and
reports min, max, average, count, and null share per column. Both are
plain result sets, which makes them assertable, and `SUMMARIZE` works
as a subquery with cells castable to varchar:

#listing("infrastructure/samples/ch11/explore_test.go", first: 57, last: 94, caption: [summarize as a subquery: min, max, avg, count, and the 25 percent null share on column b])

Four rows of known data, and the probe checks the whole row of
statistics against hand computed values, including the empty average
cell for the varchar column with a null. The habit this probe models
costs nothing on real files: point `SUMMARIZE` at a parquet path you
just received and the shape of the data, types, ranges, and ragged
null shares, is one query away.

== the appender, the fast way in

Inserts are the slow path into a columnar engine because every
statement pays parse, plan, and row reassembly. The appender is the
fast path: it streams go values straight into columnar storage,
reached through the driver as `sql.Conn.Raw` to a `*duckdb.Conn`, then
`NewAppenderFromConn`. The probe loads the same 200,000 rows both
ways:

#listing("infrastructure/samples/ch11/load_test.go", first: 57, last: 89, caption: [the appender: one raw connection, rows appended, one flush])

#listing("infrastructure/samples/ch11/load_test.go", first: 91, last: 142, caption: [the same rows through 1,000 row batched Exec, then checksums against values computed in the test])

Measured on this machine: the appender loads 200,000 rows in 71ms,
2,809,297 rows per second, against 58,895 rows per second for the same
rows through 1,000 row batched Exec statements, about 48 times. Both
loads must checksum identically, against each other and against the
sums the test computes itself, so the fast path is proven to load the
same data, not just load something quickly. The batched lane is not a
strawman either: 1,000 row multi value inserts are what a reasonable
`database/sql` program does, and the number is the size of the gap the
appender closes.

== mvcc, readers that never wait

The busy ladder chapter, #xref-to("infrastructure",
"sqlite-transactions"), built sqlite's side: in rollback mode a
writer's commit parks behind any reader holding a shared lock, and
`busy_timeout` is the knob that turns the failure into a bounded wait.
Duckdb's file mvcc is the deliberate
opposite. One writer and any number of readers coexist without
blocking, because readers read a snapshot and the writer appends
versions nothing points at yet. The probe holds a write transaction
open on one connection and reads through a second the whole time:

#listing("infrastructure/samples/ch11/mvcc_test.go", first: 3, last: 85, caption: [the writer's transaction stays open, the reader reads, nothing parks])

#diagram([the same interleaving the busy ladder chapter timed, here with no wait anywhere], length: 13pt, {
  cdraw.rect((1.6, 9.0), (6.4, 9.9), fill: luma(205), radius: 0.02)
  cdraw.content((4.0, 9.45), [reader], size: 6.5pt)
  cdraw.rect((13.6, 9.0), (18.4, 9.9), fill: luma(205), radius: 0.02)
  cdraw.content((16.0, 9.45), [writer], size: 6.5pt)
  cdraw.line((4.0, 9.0), (4.0, 0.6), stroke: luma(220))
  cdraw.line((16.0, 9.0), (16.0, 0.6), stroke: luma(220))

  cdraw.rect((15.85, 7.65), (16.15, 7.95), fill: luma(100))
  cdraw.content((11.4, 7.8), [begin, insert row 2], size: 6pt)
  cdraw.rect((3.85, 6.25), (4.15, 6.55), fill: luma(100))
  cdraw.content((8.6, 6.4), [count = 1, no error], size: 6pt)
  cdraw.rect((3.85, 4.85), (4.15, 5.15), fill: luma(100))
  cdraw.content((9.0, 5.0), [reader begin, snapshot], size: 6pt)
  cdraw.rect((15.85, 3.45), (16.15, 3.75), fill: luma(100))
  cdraw.content((11.4, 3.6), [commit], size: 6pt)
  cdraw.rect((3.85, 2.05), (4.15, 2.35), fill: luma(100))
  cdraw.content((8.4, 2.2), [still 1, its snapshot], size: 6pt)
  cdraw.rect((3.85, 0.65), (4.15, 0.95), fill: luma(100))
  cdraw.content((7.4, 0.8), [fresh read sees 2], size: 6pt)

  cdraw.content((11.0, -0.6), [no shared lock, no busy ladder, one writer at a time still], size: 6.5pt)
})

Three assertions land in order. The reader on a second connection sees
the pre transaction snapshot while the write transaction is open, with
no error and no wait. A reader transaction started before the commit
keeps seeing its snapshot after it, the same repeatable read the sqlite
probe pinned, just without the ladder underneath. And a fresh read on
the same reader connection sees the commit. Writers still serialize
with each other, one writer at a time is as true here as it is in
sqlite, so the difference is narrower than the marketing: it is
readers against writers, which for an analytical workload, many long
scans beside an occasional load, is exactly the contention that
matters.

#callout("note", "the version pin fails loudly, in three places", [
  The go module is pinned by tag `v2.10505.0`, whose number encodes
  the engine: 10505 is 1.5.5. The probe asserts `select version()`
  returns exactly `v1.5.5`, the cli script lane in the next chapter
  asserts the same string from the same pinned binary, and the c row
  cruncher in the c-os-cloud book links the same dll from the same
  `make duckdb-tools` output. When any leg drifts, one exact string
  check breaks first, which is the cheap end of the failure. The next
  chapter turns this into a re-pin checklist for the v2.0 preview
  already on the horizon.
])

sources: duckdb.org documentation for the parquet import and export
page, the csv auto-detection page, and the c api appender page,
install.duckdb.org for the 1.5.5 binaries, and pkg.go.dev for the
duckdb-go v2 driver, all accessed 2026-09-20. Verified by the ch11
probe suite, 10 tests behind the `duckdb_use_lib` tag against the
pinned 1.5.5 dll with zig as the cgo compiler, green under `make
verify-go` 2026-09-20.
