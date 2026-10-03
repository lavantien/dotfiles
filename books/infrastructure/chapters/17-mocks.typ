#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= mocks, seeding, contract tests

The word mock covers too much. This chapter separates three tools
that get confused: the embedded real thing, the fake at a seam, and
the mock proper, and takes a position on when each one is honest.

== the ladder, best first

The strongest test double is no double. The embedded nats server from
#xref-to("infrastructure", "nats") is the real dispatcher in-process,
so subject routing, queue semantics, and jetstream behavior in the
tests are the production behavior. Second best is a fake at a seam:
the history `Store` interface is two methods, and the in-memory fake
implements them with real aggregation logic, real grouping, real
sorting. Weakest is the interaction mock, an object that records calls
and replays expectations, and the capstone contains none, because
every place a mock would go either has the real thing or has a fake
with behavior.

The rule of thumb the capstone follows: mock or fake only at
boundaries you do not own and cannot embed, and when you fake, fake
behavior, not call sequences. A fake whose `Stats` groups and sorts
the same way the real one does can be wrong in interesting ways, and
those wrongs are assertions. A mock that expects "Insert then Stats"
can only be wrong about what you already typed.

#diagram([the test-double ladder, best first, and where the capstone stands], length: 13pt, {
  cdraw.line((3.0, 0.6), (3.0, 8.6), stroke: luma(100))
  cdraw.line((3.0, 7.4), (3.8, 7.4), stroke: luma(100))
  cdraw.line((3.0, 4.6), (3.8, 4.6), stroke: luma(100))
  cdraw.line((3.0, 1.8), (3.8, 1.8), stroke: luma(100))

  cdraw.rect((3.8, 6.2), (16.6, 8.6), fill: luma(205), radius: 0.02)
  cdraw.content((10.2, 8.05), [embedded real thing], size: 6.5pt)
  cdraw.content((10.2, 6.95), [production behavior], size: 6pt)

  cdraw.rect((3.8, 3.4), (16.6, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((10.2, 5.25), [fake at a seam], size: 6.5pt)
  cdraw.content((10.2, 4.15), [behavior, checked], size: 6pt)

  cdraw.rect((3.8, 0.6), (16.6, 3.0), fill: luma(235), radius: 0.02)
  cdraw.content((10.2, 2.45), [interaction mock], size: 6.5pt)
  cdraw.content((10.2, 1.35), [only what you typed], size: 6pt)

  cdraw.content((19.0, 7.4), [best], size: 6pt)
  cdraw.content((19.0, 4.6), [checked], size: 6pt)
  cdraw.content((19.0, 1.8), [weakest], size: 6pt)
  cdraw.content((10.2, -0.5), [the capstone: top two rungs, zero mocks], size: 6.5pt)
})

== the fake earns its keep by being checked

The fake is not trusted. Its aggregation is a transcription of the
mongo pipelines, and two tests hold it to that. The first is a manual
count against known input:

#listing("infrastructure/capstone/internal/history/history_test.go", first: 113, last: 139, caption: [three documents, hand computed totals, hour bucket, and word ranking])

#diagram([the fake is not trusted: two checks hold its Stats honest], length: 13pt, {
  cdraw.rect((6.4, 6.6), (16.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 7.1), [the fake's Stats], size: 6.5pt)

  cdraw.line((9.5, 6.6), (4.5, 5.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((13.5, 6.6), (18.4, 5.6), stroke: luma(100), mark: (end: ">>"))

  cdraw.rect((0.0, 3.2), (9.0, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.5, 5.05), [manual count], size: 6.5pt)
  cdraw.content((4.5, 3.95), [three known documents], size: 6pt)

  cdraw.rect((13.4, 3.2), (23.4, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((18.4, 5.05), [the contract pair], size: 6.5pt)
  cdraw.content((18.4, 3.95), [both gates fill wire.Stats], size: 6pt)

  cdraw.content((11.0, 2.0), [not trusted, checked], size: 6pt)
})

The second is the contract pair from #xref-to("infrastructure",
"mongo"): the docker-free suite proves plumbing against the fake, the
docker gate runs the same questions against real aggregation, and the
wire shape, `wire.Stats`, is what both must fill identically.

== seeding to reach the rare paths

Some behaviors only happen with history or damage already present,
and waiting for a test to grow them is slow and flaky. Seeding is the
answer, and the capstone seeds through the real interfaces, never
behind their backs:

#listing("infrastructure/capstone/internal/history/history_test.go", first: 55, last: 71, caption: [a pre-inserted row replays the crash between insert and ack])

#diagram([seeding replays the crash window, through the real interface], length: 13pt, {
  cdraw.rect((0.0, 5.0), (7.6, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 5.5), [seed via Store.Insert], size: 6pt)
  cdraw.line((7.6, 5.5), (9.0, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((9.0, 5.0), (17.0, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((13.0, 5.5), [stream delivers again], size: 6pt)
  cdraw.line((17.0, 5.5), (18.4, 5.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((18.4, 5.0), (23.4, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((20.9, 5.5), [count = 1], size: 6.5pt)

  cdraw.content((11.0, 3.8), [the upsert collapses the duplicate], size: 6pt)
  cdraw.content((11.0, 2.6), [the crash window replayed deliberately], size: 6pt)
  cdraw.content((11.0, 1.5), [seeded through the real interface], size: 6pt)
})

That test simulates the exact crash window from
#xref-to("infrastructure", "jetstream") by inserting the row and then
letting the stream deliver it again, and the assertion is that the
count settles at one, not two. The seed went through `Store.Insert`,
so the test reads as the scenario it is, a redelivery after a partial
failure, instead of reaching into private state.

== contract tests, names both sides answer to

Two services that talk over a subject agree on a string. A rename
refactor will not break the string silently if the string is pinned
once, in a constant, and asserted on both sides:

#listing("infrastructure/capstone/internal/notify/notify_test.go", first: 218, last: 223, caption: [the subject the notifier calls is the subject the presence service serves])

#diagram([one string, two packages, one pin], length: 13pt, {
  cdraw.rect((0.0, 5.0), (7.0, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.5, 5.5), [notify, calls it], size: 6.5pt)
  cdraw.line((7.0, 5.8), (8.5, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.6, 4.6), (15.4, 7.0), fill: luma(205), radius: 0.02)
  cdraw.content((12.0, 6.45), [RosterSubject], size: 6.5pt)
  cdraw.content((12.0, 5.35), [the subject string], size: 6pt)
  cdraw.line((15.5, 5.8), (16.9, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((17.0, 5.0), (23.8, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((20.4, 5.5), [presence, serves it], size: 6.5pt)

  cdraw.content((12.0, 3.4), [one pin, both packages], size: 6.5pt)
  cdraw.content((12.0, 2.3), [a rename fails a test, not production], size: 6pt)
  cdraw.content((12.0, 1.2), [the same pattern pins the bus envelope], size: 6pt)
})

That is the whole contract test: cheap, honest, and it converted a
would-be production outage, notify silently requesting a subject
nobody serves, into a compile-adjacent failure. The same pattern pins
the wire envelope in the bus package, where the round-trip test
catches any encoding drift between caller and responder in one place.

#callout("note", "when a mock is the right call", [
  The ladder has a top rung for mocks: third-party services you do
  not own, cannot embed, and pay by the call, an sms gateway, a
  payment provider. There the interface should be yours and thin, the
  fake minimal, and the mock confined to the adapter that speaks the
  vendor's protocol, because that adapter is the only code whose
  interaction with reality a mock can faithfully check. Nothing in
  the capstone reached that rung, which is itself the finding.
])

sources: no external sources, the positions here are argued from the
capstone's own suites. Verified by the tests named in this chapter,
the history suite's seeding and contract tests, 5 tests, and the
notify roster pin, green under `make verify` 2026-09-10.
