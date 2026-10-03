#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= sqlite: schemas and normalization

The chat service persists to one sqlite file, and the schema it uses
is a small normalization argument in sql. The naive chat table is one
wide row per message: sender text, room text, body, timestamp. It
works on day one and rots on day two, because a sender's display name
is stored on every message they ever sent, and changing it means
rewriting history instead of one row.

The normalized shape stores each name once and references it by id:

#listing("infrastructure/capstone/internal/migrate/migrations/0001_init.sql", first: 1, last: 21, caption: [the first migration: names live once, messages reference them])

#diagram([the wide row against the normalized shape, and what a rename costs], length: 13pt, {
  cdraw.content((5.1, 10.0), [one wide table], size: 6.5pt)
  let cell(x0, x1, y, label, head) = {
    cdraw.rect((x0, y), (x1, y + 0.9), fill: if head { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content(((x0 + x1) / 2, y + 0.45), [#label], size: 6pt)
  }
  cell(0.4, 2.8, 8.3, [sender], true)
  cell(2.8, 5.6, 8.3, [room], true)
  cell(5.6, 9.8, 8.3, [body], true)
  cell(0.4, 2.8, 7.0, [alice], false)
  cell(2.8, 5.6, 7.0, [general], false)
  cell(5.6, 9.8, 7.0, [hi], false)
  cell(0.4, 2.8, 5.7, [alice], false)
  cell(2.8, 5.6, 5.7, [random], false)
  cell(5.6, 9.8, 5.7, [yo], false)
  cell(0.4, 2.8, 4.4, [alice], false)
  cell(2.8, 5.6, 4.4, [general], false)
  cell(5.6, 9.8, 4.4, [gm], false)
  cdraw.content((5.1, 3.2), [rename alice: rewrite history], size: 6pt)
  cdraw.content((5.1, 2.1), [names repeated per message], size: 6pt)

  cdraw.line((11.3, 1.8), (11.3, 10.2), stroke: luma(220))

  cdraw.content((17.9, 10.0), [normalized, three tables], size: 6.5pt)
  cdraw.rect((12.4, 8.2), (15.8, 9.1), fill: luma(235), radius: 0.02)
  cdraw.content((14.1, 8.65), [users], size: 6pt)
  cdraw.rect((17.2, 8.2), (20.6, 9.1), fill: luma(235), radius: 0.02)
  cdraw.content((18.9, 8.65), [rooms], size: 6pt)
  cdraw.rect((14.6, 5.5), (21.0, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((17.8, 7.35), [messages], size: 6pt)
  cdraw.content((17.8, 6.25), [user_id, room_id], size: 6pt)
  cdraw.line((15.6, 7.9), (14.4, 8.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((19.8, 7.9), (18.7, 8.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((17.9, 4.4), [a rename is one update on users], size: 6pt)
  cdraw.content((17.9, 3.3), [fk errors need the pragma on], size: 6pt)
})

One detail in the `id integer primary key` columns matters beyond
this chapter: every sqlite table has a hidden rowid, a row number the
storage b-tree keys on, and a column declared `integer primary key`
is that rowid, so an id is the row's position, not a second stored
copy. A `without rowid` table, the keyed store's shape in
#xref-to("infrastructure", "sqlite-production"), drops the hidden
column and clusters the b-tree on the declared primary key instead.

Three tables, and the cost of the join is paid back twice. A rename is
one update on `users`. Room membership queries count distinct ids
instead of comparing text. And the foreign key clauses, `references
rooms(id)`, turn a class of application bugs, messages pointing at a
room that does not exist, into database errors, but only if the
connection asks for them:

#listing("infrastructure/capstone/internal/store/store.go", first: 43, last: 47, caption: [foreign key enforcement is a per-connection pragma, not a file property])

That listing is the trap most sqlite schemas hit once. The `references`
clause is parsed always and enforced never, unless the connection sets
`pragma foreign_keys=on`. The capstone's `store.Open` sets it on every
open, and the test that pins it inserts a message with invented ids
and expects the rejection.

== the second migration, additive by design

Schemas change after data exists. The second migration ships what a
live database can absorb without a rewrite:

#listing("infrastructure/capstone/internal/migrate/migrations/0002_rollup.sql", first: 1, last: 13, caption: [an index the recent query wants, and a rollup view over the join])

#diagram([migration 0002 lands on a live database, adding without touching a row], length: 13pt, {
  cdraw.rect((0.0, 5.6), (5.0, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.5, 6.1), [create index], size: 6.5pt)
  cdraw.line((5.0, 6.1), (7.3, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.15, 7.2), [add], size: 6pt)

  cdraw.rect((7.4, 4.6), (16.6, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((12.0, 7.5), [the live database], size: 6.5pt)
  cdraw.content((12.0, 6.4), [users, rooms, messages], size: 6pt)
  cdraw.content((12.0, 5.3), [rows untouched], size: 6pt)

  cdraw.line((18.4, 6.1), (16.7, 6.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((17.55, 7.2), [add], size: 6pt)
  cdraw.rect((18.4, 5.6), (23.4, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((20.9, 6.1), [create view], size: 6.5pt)

  cdraw.rect((5.0, 1.2), (19.0, 3.6), fill: luma(235), radius: 0.02)
  cdraw.content((12.0, 3.05), [when a rewrite is unavoidable], size: 6.5pt)
  cdraw.content((12.0, 1.95), [copy into a new table, one transaction], size: 6pt)
})

The index serves the exact access path the chat service runs, newest
messages of one room, which is a range scan on `(room_id, id)`. The
view is a named query, and the chapter's probes exercise it through
the migration suite, which asserts the view returns one row after one
message lands. Neither statement touches existing rows, which is the
rule for migrations on live files: add, never rewrite, and when a
rewrite is unavoidable, do it as a copy into a new table inside one
transaction, the pattern #xref-to("infrastructure", "migrations")
builds the runner for.

The normalized shape also travels.
#xref-to("infrastructure", "duckdb-sqlite") takes this exact schema,
both migrations verbatim, attaches the file to duckdb, and asks the
attached tables the same questions the view answers. The two engines
must agree on every row, which is the cheapest proof that
normalization bought nothing at the price of portability.

#callout("note", "denormalize on purpose or not at all", [
  Normalization is the default because it is the safe default. The
  capstone denormalizes nowhere: message counts are computed, rooms
  are joined. If a room counter column ever became worth it, the
  chapter's rule would be to add it as a maintained, derived column
  written in the same transaction as the message, never as a second
  source of truth the application remembers to update.
])

sources: sqlite.org pragma reference for the per-connection
foreign_keys behavior, accessed 2026-09-10, and sqlite.org lang
pages for index and view semantics. Verified by the migrate and store
suites, 10 tests, including the foreign key rejection and the view
row count, run green under `make verify` 2026-09-10.
