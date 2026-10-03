// book 12: written map grows chapter by chapter
#import "../theme/lib.typ": book
#import "manifest.typ": infrastructure

#let written = (
  "toolchain": "chapters/01-toolchain.typ",
  "images": "chapters/02-images.typ",
  "containers": "chapters/03-containers.typ",
  "compose": "chapters/04-compose.typ",
  "networking": "chapters/05-networking.typ",
  "sqlite-schema": "chapters/06-sqlite-schema.typ",
  "sqlite-transactions": "chapters/07-sqlite-transactions.typ",
  "sqlite-wal": "chapters/08-sqlite-wal.typ",
  "sqlite-features": "chapters/09-sqlite-features.typ",
  "sqlite-production": "chapters/10-sqlite-production.typ",
  "duckdb": "chapters/11-duckdb.typ",
  "duckdb-sqlite": "chapters/12-duckdb-sqlite.typ",
  "mongo": "chapters/13-mongo.typ",
  "nats": "chapters/14-nats.typ",
  "jetstream": "chapters/15-jetstream.typ",
  "testing": "chapters/16-testing.typ",
  "mocks": "chapters/17-mocks.typ",
  "migrations": "chapters/18-migrations.typ",
  "capstone1": "chapters/19-capstone1.typ",
  "capstone2": "chapters/20-capstone2.typ",
)

#book(infrastructure.meta, {
  for ch in infrastructure.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
