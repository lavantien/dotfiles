#import "../../theme/lib.typ": callout, cdraw, diagram, xref-to

= the toolchain: docker on windows

This book is the third engineering handbook in the row. It takes the three
things a backend or a game server actually sits on, containers, databases,
and tests, and builds one system out of them: a peer to peer chat and
notification microservice suite that comes up with a single `docker compose
up -d`. Every chapter before the capstone is one layer of that system, and
every layer obeys one rule about verification: it either runs without the
docker daemon, or it is explicitly gated behind the daemon and never silently
skipped.

== what runs where

Two gates, and the split is a design rule, not a convenience.

- `make verify` runs everywhere and touches no docker daemon. Persistence is
  SQLite or DuckDB on a temp directory, messaging is an embedded in-process
  NATS server, and the mongo consumer runs against an in-memory fake. A
  test that needs the real daemon does not belong in this gate.
- `make verify-infra-docker` preflights `docker info` and refuses to skip.
  With the daemon present it brings the capstone up with
  `docker compose up -d --wait`, runs the docker-tagged suite against the
  running stack, and tears down with `down -v` even on failure. With the
  daemon absent it exits nonzero with a plain message saying what to start.

#diagram([the two-gate split as a routing decision, and neither gate silently skips], length: 13pt, {
  cdraw.rect((-1.0, 4.8), (5.6, 6.9), fill: luma(205), radius: 0.02)
  cdraw.content((2.3, 6.4), [every test], size: 6.5pt)
  cdraw.content((2.3, 5.3), [needs the daemon?], size: 6pt)

  cdraw.rect((7.0, 6.6), (18.6, 9.9), fill: luma(235), radius: 0.02)
  cdraw.content((12.8, 9.3), [make verify, everywhere], size: 6.5pt)
  cdraw.content((12.8, 8.15), [temp sqlite, embedded nats], size: 6pt)
  cdraw.content((12.8, 7.0), [in-memory fake store], size: 6pt)

  cdraw.rect((7.0, -0.2), (18.6, 5.3), fill: luma(235), radius: 0.02)
  cdraw.content((12.8, 4.85), [tagged docker], size: 6.5pt)
  cdraw.content((12.8, 3.7), [make verify-infra-docker], size: 6pt)
  cdraw.content((12.8, 2.55), [present: up --wait, suite,], size: 6pt)
  cdraw.content((12.8, 1.4), [down -v even on failure], size: 6pt)
  cdraw.content((12.8, 0.25), [absent: exit nonzero, say why], size: 6pt)

  cdraw.line((5.6, 6.1), (7.0, 8.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.1, 7.5), [no], size: 6pt)
  cdraw.line((5.6, 5.5), (7.0, 3.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.0, 4.3), [yes], size: 6pt)

  cdraw.content((12.8, -1.15), [never silently skipped], size: 6.5pt)
})

== the compiler-free lane, and its one exception

Every sqlite driver in this repo is chosen so that no consumer needs a C
compiler at build or test time.

- Go uses `modernc.org/sqlite`, a pure Go translation of the SQLite
  amalgamation (the single-file C source sqlite publishes). It is the
  first third-party dependency this repo's go modules ever took, spent
  deliberately: the sqlite lanes keep `CGO_ENABLED=0`
  true and cross compilation stays boring.
- C\# uses `Microsoft.Data.Sqlite` with the `SQLitePCLRaw.bundle_e_sqlite3`
  package, which ships a prebuilt native engine next to the managed driver.
- JavaScript uses `node:sqlite`, built into node 26, so the capstone adds no
  dependency at all.
- Lua uses LuaJIT's FFI over a dll this repo builds itself with mingw.

The analytical engine is the one exception, and it is fenced. Duckdb's go
driver is cgo by nature, so the duckdb lanes build against the pinned
official dll from `make duckdb-tools`, confined to the `duckdb_use_lib`
tagged sample packages and one debian compose stage in the capstone, with
zig standing in as the cgo compiler on the host because the driver's
prebuilt static engine libraries are MSVC objects. On linux, which is what
that compose stage builds, the driver's default static bindings compile
with no tag and no dll. A plain `go test ./...` compiles none of it, so
every lane that is not deliberately duckdb stays compiler-free.

The single place that owns a compiler is the toolchain. `make sqlite-tools`
builds SQLite 3.53.4 and LuaJIT from pinned source with mingw, the same
compiler that builds Lua 5.5 for book 8, and `make duckdb-tools` fetches
the duckdb 1.5.5 cli and libduckdb with sha256 pins against
install.duckdb.org, warming the sqlite extension into the home cache for
the attach chapter. The outputs live in `tools/sqlite/build/`,
`tools/luajit/build/`, and `tools/duckdb/build/`, all gitignored, and the
build scripts assert their versions before they finish, so a wrong
download fails the build instead of producing a quietly different engine.

#diagram([four runtimes, two pinned engines, the compilers confined to the toolchain box], length: 13pt, {
  let tier(x0, title, sub) = {
    cdraw.rect((x0, 5.9), (x0 + 5.9, 8.3), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.95, 7.7), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.95, 6.6), [#sub], size: 6pt)
  }
  tier(0.2, [go], [modernc + duckdb-go])
  tier(6.2, [c\#], [bundled engine])
  tier(12.2, [javascript], [node:sqlite 3.53.4])
  tier(18.2, [lua], [luajit ffi])

  cdraw.line((3.15, 5.9), (3.3, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((5.8, 5.9), (7.8, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.15, 5.9), (9.9, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((15.15, 5.9), (13.8, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((21.15, 5.9), (15.6, 4.2), stroke: luma(100), mark: (end: ">>"))

  cdraw.rect((0.4, 3.0), (6.2, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((3.3, 3.6), [duckdb 1.5.5, analytical], size: 6.5pt)
  cdraw.rect((7.0, 3.0), (16.8, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.9, 3.6), [sqlite 3.53.4, transactional], size: 6.5pt)

  cdraw.line((6.0, 1.6), (3.3, 3.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.7, 2.35), [fetches], size: 6pt)
  cdraw.line((11.5, 1.6), (11.9, 3.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((13.1, 2.3), [builds], size: 6pt)
  cdraw.rect((2.0, -1.7), (19.0, 1.6), fill: luma(235), radius: 0.02)
  cdraw.content((10.5, 1.1), [tools/ toolchain, the only compilers], size: 6.5pt)
  cdraw.content((10.5, 0.0), [make sqlite-tools: mingw builds], size: 6pt)
  cdraw.content((10.5, -1.1), [make duckdb-tools: sha256-pinned 1.5.5], size: 6pt)
})

#callout("note", "why 3.53.4 and 1.5.5, pinned once each", [
  Pinning one version per engine across every runtime keeps the database
  chapters honest. When #xref-to("infrastructure", "sqlite-features") says
  a JSON function or an ALTER TABLE capability exists, it exists in the
  engine the Go, C\#, and Lua suites assert on. Node ships its own
  sqlite build rather than the pinned amalgamation: it read 3.53.1 on
  node 26.3.0, the one measured delta, and reads 3.53.4 on node
  26.10.0, caught up to the pin, and the javascript capstone asserts
  that exact string either way, because driver-bundled engines drift.
  The duckdb chapters do the same for
  1.5.5: the go module tag encodes it, and the probes assert `select
  version()` returns it exactly. Driver-bundled engines drift. The pinned
  amalgamation and the pinned dll do not.
])

== lua, two runtimes, never crossed

Book 8 teaches Lua 5.5 from the manual and its runner is a 5.5 interpreter
built from lua.org source. This book adds LuaJIT for exactly one job, the
sqlite wrapper in the persistence chapters, and LuaJIT speaks Lua 5.1. The
split is a rule the make targets enforce: the 5.5 runner never executes FFI
code, the LuaJIT runner never executes the 5.5 samples, and the wrapper
itself stays 5.1 clean. No goto, no integer division, nothing from 5.2 and
later.

#diagram([two fenced lua lanes, the wrapper confined to the 5.1 subset], length: 13pt, {
  cdraw.rect((0.0, 3.6), (10.2, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.1, 7.5), [lua 5.5 runner], size: 6.5pt)
  cdraw.content((5.1, 6.4), [built from lua.org source], size: 6pt)
  cdraw.content((5.1, 5.3), [runs the book 8 samples], size: 6pt)
  cdraw.content((5.1, 4.2), [never executes ffi code], size: 6pt)

  cdraw.line((11.0, 1.4), (11.0, 8.0), stroke: luma(100))
  cdraw.content((11.0, 8.75), [the fence, make targets enforce it], size: 6pt)

  cdraw.rect((11.8, 3.6), (22.0, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((16.9, 7.5), [luajit runner, lua 5.1], size: 6.5pt)
  cdraw.content((16.9, 6.4), [the sqlite wrapper, one job], size: 6pt)
  cdraw.content((16.9, 5.3), [never runs the 5.5 samples], size: 6pt)

  cdraw.line((16.9, 3.6), (16.9, 3.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((3.0, -0.1), (19.0, 3.1), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 2.55), [the wrapper stays 5.1 clean], size: 6.5pt)
  cdraw.content((11.0, 1.45), [no goto, no integer division], size: 6pt)
  cdraw.content((11.0, 0.35), [nothing from 5.2 and later], size: 6pt)
})

== the road through the book

Chapters 2 through 5 build the container half: what an image is, what a
container actually is on the host, how compose wires a multi-service system,
and how the bridge network and embedded DNS let the services find each
other. Chapters 6 through 12 are the storage half: sqlite from schema design
and normalization through transactions, WAL, and the 3.53 feature set into
production, then duckdb as the embedded analytical engine and the two
engines run together under one choosing rule. Chapters 13 through 15 add
the other two stores: MongoDB for aggregation pipelines, NATS for messaging,
and JetStream for the durable log and key value layers, with Kafka treated
as the comparison it needs to be rather than a second implementation.
Chapters 16 through 18 are the testing half: what runs docker-free, when a
mock is the right call and when it is a lie, and a migration runner built
test first.

#diagram([four halves stack up and converge on the capstone], length: 13pt, {
  let row(y, title, sub) = {
    cdraw.rect((0.2, y), (12.4, y + 2.4), fill: luma(235), radius: 0.02)
    cdraw.content((6.3, y + 1.85), [#title], size: 6.5pt)
    cdraw.content((6.3, y + 0.75), [#sub], size: 6pt)
  }
  row(6.6, [containers, ch 2-5], [images, containers, compose])
  row(4.2, [engines, ch 6-12], [sqlite, duckdb, choosing])
  row(1.8, [other stores, ch 13-15], [mongo, nats, jetstream, kafka])
  row(-0.6, [testing, ch 16-18], [gates, mocks, migrations])

  cdraw.rect((16.6, 0.6), (23.4, 5.2), fill: luma(205), radius: 0.02)
  cdraw.content((20.0, 4.55), [the capstone], size: 6.5pt)
  cdraw.content((20.0, 3.45), [ch 19-20], size: 6pt)
  cdraw.content((20.0, 2.35), [the chat and], size: 6pt)
  cdraw.content((20.0, 1.25), [notification suite], size: 6pt)

  cdraw.line((12.4, 7.8), (16.6, 4.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.4, 5.4), (16.6, 4.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.4, 3.0), (16.6, 3.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.4, 0.6), (16.6, 2.4), stroke: luma(100), mark: (end: ">>"))

  cdraw.content((12.0, -1.3), [every chapter before the capstone is one layer of the one system], size: 6.5pt)
})

Then the capstone, #xref-to("infrastructure", "capstone1") and
#xref-to("infrastructure", "capstone2"), composes all of it into the chat
and notification suite.
