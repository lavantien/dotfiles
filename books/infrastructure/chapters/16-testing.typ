#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= testing without docker

Chapter 1 drew the line: `make verify` never needs the daemon, and
anything that does is gated behind `make verify-infra-docker` where
absence is a loud red. This chapter is what makes that split honest
rather than aspirational, because the hard part is not the rule, it is
building a system whose tests mostly do not want docker.

The numbers first: the docker-free gate runs 103 go tests, 61 in the
capstone module and 42 in the chapter probe module, and the probe
module splits by lane, 25 compiler-free tests under plain
`go test ./...` and 17 duckdb-tagged tests behind the pinned dll,
zero skipped, and none of them ask for the engine. The docker gate
runs 4 more that ask for nothing but the web port.

== the three substitutions

Every technology the capstone uses has a docker-free stand-in that is
not a mock of the technology:

#listing("infrastructure/capstone/internal/testnats/server.go", first: 18, last: 45, caption: [the broker: the real server, embedded, on a random port with a temp store])

Sqlite is its own substitution, a file in `t.TempDir()` that the test
framework deletes. Mongo is the one fake, and it is a fake at a seam,
the `Store` interface, not a fake mongodb, and
#xref-to("infrastructure", "mocks") puts it under the microscope.
Duckdb needs no substitution at all: it embeds the way sqlite does,
one file per test in a temp directory, so the analytics service runs
its real sql in the same one-process stack.

With those three, the whole system assembles in one process. The web
suite is the demonstration: real chat service with a real sqlite file,
real presence and notify and history over the embedded broker, fake
store behind history, real http handlers, real clients:

#listing("infrastructure/capstone/internal/web/web_test.go", first: 24, last: 52, caption: [the capstone minus containers: every service real except the mongo seam])

#diagram([the whole system in one process, one of the four a double], length: 13pt, {
  let quad(x0, y0, title, l1, l2) = {
    cdraw.rect((x0, y0), (x0 + 10.8, y0 + 3.2), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 5.4, y0 + 2.7), [#title], size: 6.5pt)
    cdraw.content((x0 + 5.4, y0 + 1.6), [#l1], size: 6pt)
    cdraw.content((x0 + 5.4, y0 + 0.5), [#l2], size: 6pt)
  }
  quad(0.0, 5.2, [sqlite, real], [a file in t.TempDir], [deleted by the framework])
  quad(12.0, 5.2, [nats, real], [the embedded server], [random port, temp store])
  quad(0.0, 1.4, [mongo, the one fake], [at the Store seam], [not a fake mongodb])
  quad(12.0, 1.4, [web, real], [real handlers], [real http clients])
  cdraw.content((11.4, 0.1), [one process, one of the four is a double], size: 6.5pt)
})

That one stack answers the questions a mock-heavy suite cannot: does
a send reach sqlite and the stream and the notifier and another
user's fragment, through the actual wire formats. It runs in about
two seconds, which is why there is no pressure to skip it locally.

== the gate itself is a build tag

The docker-gated suite is the same module with one file carrying a
tag:

#listing("infrastructure/capstone/integration/stack_test.go", first: 1, last: 8, caption: [the tag that keeps these tests out of every run that does not ask for them])

#diagram([the compiler is the gatekeeper: three ways to run, one passes the tag], length: 13pt, {
  cdraw.rect((0.0, 7.0), (6.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.3, 7.5), [go test ./...], size: 6.5pt)
  cdraw.line((6.6, 7.5), (8.0, 7.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.0, 7.0), (17.4, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((12.7, 7.5), [the file is not compiled], size: 6pt)

  cdraw.rect((0.0, 5.0), (8.0, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 5.5), [go test -tags docker], size: 6pt)
  cdraw.line((8.0, 5.5), (9.4, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((9.4, 5.0), (18.8, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((14.1, 5.5), [it compiles and runs], size: 6pt)

  cdraw.rect((0.0, 3.0), (9.4, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((4.7, 3.5), [make verify-infra-docker], size: 6pt)
  cdraw.line((9.4, 3.5), (10.8, 3.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((10.8, 3.0), (20.4, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((15.6, 3.5), [the only tag passer], size: 6pt)

  cdraw.content((10.0, 1.8), [the suite's first act fails loudly], size: 6pt)
  cdraw.content((10.0, 0.7), [against a missing stack], size: 6pt)
})

`go test ./...` never compiles the file, `go test -tags docker` only
runs it, and the make target is the only thing that passes the tag.
The suite's first act is to reach the web port and fail loudly if the
stack is not there, so running it bare, without compose, is a red
test with a clear message, not a misleading green. The two-gate rule
enforced by a compiler switch and a preflight, not by convention.

== what each gate proves

The split is not arbitrary, it follows what each dependency can
honestly verify. The docker-free gate proves the capstone's logic:
schema and migrations, transaction and locking behavior, fanout and
ack discipline, offset resumption, http fragments, escaping, the fake
store's plumbing. The docker gate proves the seams the fakes cannot:
the real mongo pipelines behind `history.stats`, the compose
healthcheck graph, service discovery through the bridge, the published
image behavior end to end. A red in either gate points at a different
class of bug, and knowing which gate is red is the first line of
diagnosis.

#diagram([what each gate proves, and what a red in each one means], length: 13pt, {
  cdraw.content((5.5, 8.9), [docker-free proves], size: 6.5pt)
  cdraw.content((17.5, 8.9), [docker proves], size: 6.5pt)
  cdraw.line((0.6, 8.3), (22.0, 8.3), stroke: luma(220))
  cdraw.line((11.5, 3.0), (11.5, 8.3), stroke: luma(220))

  cdraw.content((5.5, 7.1), [schema, migrations], size: 6pt)
  cdraw.content((17.5, 7.1), [real mongo pipelines], size: 6pt)
  cdraw.content((5.5, 5.9), [transactions, locking], size: 6pt)
  cdraw.content((17.5, 5.9), [the healthcheck graph], size: 6pt)
  cdraw.content((5.5, 4.7), [fanout, offsets], size: 6pt)
  cdraw.content((17.5, 4.7), [bridge discovery], size: 6pt)
  cdraw.content((5.5, 3.5), [fragments, escaping], size: 6pt)
  cdraw.content((17.5, 3.5), [published images], size: 6pt)

  cdraw.line((0.6, 2.9), (22.0, 2.9), stroke: luma(220))
  cdraw.content((11.5, 1.8), [a red in each column is a different bug class], size: 6pt)
})

#callout("warning", "flaky is a bug, not a setting", [
  Every wait in the docker-free suite is a bounded eventually with a
  condition, five seconds at the outside, and the conditions assert
  content, not just progress. A test that intermittently times out is
  telling you about a race the capstone shipped, and the answer is to
  find it, the way the nak and ttl stories in
  #xref-to("infrastructure", "jetstream") were found by exactly such
  a timeout.
])

sources: pkg.go.dev for the embedded nats server options and go's
build constraints, accessed 2026-09-10. Verified by `make verify`,
103 go tests green, and `make verify-infra-docker`, 4 tagged tests
green, both run 2026-09-20.
