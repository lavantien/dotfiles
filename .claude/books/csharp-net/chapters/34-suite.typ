#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= the test suite

The service part ends with the thing that keeps it honest. This
chapter reads the suite as a whole: what it already holds, the
property targets that turn random inputs into invariants, the cache
driven as a state machine against a reference model, forgery
resistance as a loop over mutations, the strict hand-rolled doubles
and the libraries the vehicle deliberately declines, the xunit
surface and the truths it hides, and the coverage lane that stays
opt-in. One ruling from the contract governs all of it: the
platform's native randomized mechanism, which for c\# is the seeded
`Random` loop, so every property here is deterministic by
construction and zero tests sleep.

== what the suite already holds

The solution carries 379 tests under `Api.slnx` and 6 wire tests in
the integration project outside it. The families own their slices:
the kernel's byte-identity pins, the middleware stack order, the
resource and auth lanes replaying the frozen vectors in process, the
store's migration and isolation suites, the concurrency duel, the
cache, the limiter, the observability exposition, and the deploy
probe. The property folder added by this chapter holds 18 more. The
support doubles consolidated here to one of each kind: one stepped
clock, one vector loader, one recording logger, scripted sources
that fail on overdraw, a strict response-feature double, and the
shared harness that boots composed slices of the app in memory.

The consolidation itself is a chapter ruling: two clocks and two
vector loaders had accumulated across lanes, and the suite keeps one
of each. `SteppedTimeProvider` is the clock that stayed, because its
timers fire inside `Advance`, and the plain two-line `StepClock`
folded into it, every call site migrated mechanically. A test that
needs time to pass performs one addition, and a timer that the
production code armed through `TimeProvider.CreateTimer` fires on
the caller's thread, deterministically, in schedule order:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Support/SteppedTimeProvider.cs", first: 27, last: 46, caption: [the one clock: time moves by addition, timers fire inside the step])

#diagram([the suite's shape: three legs, one contract, zero sleeps], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 5.0), (x + w, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.7), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.7), sub, size: 6pt)
  }
  box(0.8, 6.4, [in process, 379], [families, vectors, properties])
  box(7.9, 6.4, [over the wire, 6], [compose stack, real clock])
  box(15.0, 7.2, [opt-in lanes], [coverage, docker gated])
  cdraw.content((11.5, 3.9), [one stepped clock, one vector loader], size: 6pt)
  cdraw.content((11.5, 2.9), [the frozen bytes decide every dispute], size: 6pt)
  cdraw.content((11.5, 1.9), [no test sleeps, anywhere, ever], size: 6pt)
})

== properties as seeded theories

C\# has no native fuzzing hook in the sdk test stack, so the
platform-native answer is the seeded pseudorandom loop: a property
is one `[Theory]` whose inputs are seeds, each seed drives hundreds
of iterations of `Random`, and the seed is the whole input, so a
failure names the exact loop that broke and replays on demand. This
mirrors the corpus ruling that each lane carries properties via its
own native randomized mechanism, and it composes with the toolchain:
the theories are plain tests, they run in every suite pass, and
nothing behind a flag can rot.

The envelope property is the shape lesson. For random codes,
messages, and request ids, every envelope serializes, deserializes,
and round-trips all four members, and the member order never moves,
`message` before `details` before `request_id`, with `details`
absent unless present. The wire contract is a property of every
possible value, not of the sixteen the vectors froze, and the loop
says so in 500 iterations per seed:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Properties/EnvelopeJsonProperties.cs", first: 17, last: 44, caption: [the seed is the whole input: hundreds of envelopes per theory case])

#diagram([one theory, two seeds, a thousand random inputs, one invariant], length: 13pt, {
  let step(x0, w, top, sub) = {
    cdraw.rect((x0, 4.6), (x0 + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x0 + w / 2, 5.3), sub, size: 6pt)
  }
  step(0.8, 4.2, [the seed], [theory data, 2 cases])
  cdraw.line((5.1, 5.8), (5.7, 5.8), stroke: luma(100), mark: (end: ">>"))
  step(5.9, 4.6, [Random(seed)], [deterministic stream])
  cdraw.line((10.6, 5.8), (11.2, 5.8), stroke: luma(100), mark: (end: ">>"))
  step(11.4, 4.6, [500 iterations], [round-trip, member order])
  cdraw.line((16.1, 5.8), (16.7, 5.8), stroke: luma(100), mark: (end: ">>"))
  step(16.9, 5.3, [one verdict], [any failure names its seed])
  cdraw.content((11.5, 3.5), [the cursor, the bucket, and the etag carry the same shape of target], size: 6pt)
})

== the cache as a state machine

The strongest property target drives the ttl lru cache as a state
machine: a seeded stream of set, get, and remove operations runs
against both the real cache and a reference model built from plain
dictionaries, and every observation must agree. Writing the model
forced the structure's semantics into sentences the chapter can
state: expiry is stamped at set time and a read never extends it, an
expired entry lingers in the structure until a read contacts it and
it evicts itself, capacity evicts by touch order over live and dead
entries alike, and a read refreshes recency without refreshing age.

One lesson cost a debugging round and stays in prose: the model's
first eviction ordering used wall-clock timestamps, and two touches
inside one clock step tied, while the structure's list keeps event
order. The model now carries a monotonic touch sequence, the tick of
the op stream, and the divergence disappeared. A reference model is
a spec you execute, and it is wrong exactly where your understanding
is:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Properties/CacheStateMachineProperties.cs", first: 51, last: 90, caption: [the op switch: every operation mirrored, every observation compared])

#diagram([two runtimes, one op stream, one verdict per step], length: 13pt, {
  cdraw.content((5.2, 7.7), [the seeded op stream], size: 6.5pt)
  cdraw.content((5.2, 7.0), [#"set / get / remove + clock steps"], size: 6pt)
  cdraw.line((5.2, 6.4), (5.2, 5.8), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 10.0, 5.6, [the real cache], [#"TtlLruCache + SteppedTimeProvider"], [the shipped code])
  pane(0.4, 10.0, 2.8, [the reference model], [value, setAt, touch tick], [plain dictionaries])
  cdraw.line((10.2, 4.2), (12.0, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(12.2, 22.8, 5.6, [agreement], [found, value, count], [every step, every run])
  cdraw.content((17.5, 2.6), [40 runs x 200 ops x 2 seeds], size: 6pt)
})

== forgery resistance as a target

The jwt property turns the security claim into a loop: for random
claims and random 32-byte secrets, sign, then mutate exactly one
character in each of the three segments in turn, and every forged
token must fail verification with a named failure, the wrong secret
must fail, and the untampered token must round-trip its exact
claims. The mutation maps back into the base64url alphabet so the
forgery stays well formed enough to reach the signature check,
which is the point: the property hunts a scheme where a tamper
survives, not a parser that quits early.

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Properties/JwtForgeryProperties.cs", first: 29, last: 53, caption: [sign, tamper each segment one character, demand rejection])

#diagram([the mutation loop: three segments, one flip each, zero survivors], length: 13pt, {
  let step(x0, w, top, sub) = {
    cdraw.rect((x0, 4.6), (x0 + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x0 + w / 2, 5.3), sub, size: 6pt)
  }
  step(0.8, 4.0, [sign], [random claims, secret])
  cdraw.line((4.9, 5.8), (5.5, 5.8), stroke: luma(100), mark: (end: ">>"))
  step(5.7, 4.6, [mutate], [one char per segment])
  cdraw.line((10.4, 5.8), (11.0, 5.8), stroke: luma(100), mark: (end: ">>"))
  step(11.2, 4.8, [read back], [#"ReadHS256, named failure"])
  cdraw.line((16.1, 5.8), (16.7, 5.8), stroke: luma(100), mark: (end: ">>"))
  step(16.9, 5.3, [plus], [wrong secret, exact claims])
  cdraw.content((11.5, 3.5), [40 rounds x 3 segments x 2 seeds, no tamper survives], size: 6pt)
})

== strictness without a framework

Every double in the suite is hand-rolled and strict: the scripted
source dequeues its values and fails the test the moment it is drawn
past its script, the fake hasher counts its verifies so the timing
test can prove the unknown-email path runs the same hash work as the
wrong-password path, the recording logger captures level, message,
structured values, and exception for assertion, and the response
feature double pins `HasStarted` so started-response guards run
under the unit host. None of them implement a framework interface
beyond what the production code already consumes, and all of them
fit in one sitting:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Support/Scripted.cs", first: 8, last: 19, caption: [the scripted source: overdraw fails the test, the script is the spec])

The libraries the ecosystem reaches for are dated meta, stated once
and declined on stated criteria. NSubstitute sits at 6.2.0,
FluentAssertions at 8.11.0, whose 8.0 line moved the license and the
community forked, AwesomeAssertions at 9.6.0 with the fork carrying
tens of millions of downloads, FsCheck at 3.4.0, SharpFuzz at 2.3.0,
all versions read off nuget's own index the day this chapter was
written. The vehicle declines them for the reason the contract
rules: a substitute library generates doubles whose failure modes
the suite cannot see, a fluent assertion layer wraps the asserts the
xunit analyzer already checks, FsCheck's shrinking is excellent and
the seeded loop already replays, and SharpFuzz needs a coverage
build this lane does not carry. None of that is a ban, it is an
adoption bar: the day a double costs more than forty lines or a
property needs shrinking, the meta paragraph names where to reach.

#diagram([the double set: one of each kind, strict by construction], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.75), (x + w / 2, y + 0.75), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.25), l1, size: 6pt)
    cdraw.content((x, y - 0.4), l2, size: 6pt)
  }
  cell(5.9, 7.6, 10.4, [SteppedTimeProvider], [clock + timers, one of one])
  cell(17.1, 7.6, 10.4, [Vectors], [the one loader, raw plus model])
  cell(5.9, 5.8, 10.4, [RecordingLogger], [level, values, exception])
  cell(17.1, 5.8, 10.4, [Scripted and FakeHasher], [overdraw fails, verifies counted])
  cell(5.9, 4.0, 10.4, [StartedResponseFeature], [HasStarted pinned true])
  cell(17.1, 4.0, 10.4, [ApiHarness], [composed slices, in memory])
  cdraw.rect((1.2, 2.0), (21.8, 3.0), fill: luma(222), radius: 0.02)
  cdraw.content((11.5, 2.5), [no mocking library, no assertion layer, dated meta instead], size: 6pt)
})

== the xunit surface and the truths it hides

The suite runs on xunit 2.9.3 with the visualstudio runner, and the
surface the vehicle uses is deliberately small: `[Fact]` for one
case, `[Theory]` with `InlineData` for parameterized ones, and the
assert methods, nothing else, no `IAsyncLifetime`, no custom
framework attributes. The truths the surface hides deserve prose.
Xunit parallelizes across test classes by default, which is why a
static `HttpClient` or a process-wide environment variable is a
hazard first and a convenience second: the lane suite owns one
static client because the lane runs alone, and the probe tests parse
urls through an injectable overload rather than touching
`ASPNETCORE_URLS` in a shared process. The runner also builds the
test host in a separate process, so environment variables set for
`dotnet test` reach the tests only by inheritance, which once cost
this wave a debugging afternoon. And there is no `TestMain`: the
entry point is the attribute, which is why every fixture work
happens in constructors and lazy singletons:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Properties/TokenBucketProperties.cs", first: 14, last: 40, caption: [the whole surface in one method: theory, seeds, loop, assert])

#diagram([what the runner does with one theory], length: 13pt, {
  let step(x0, w, top, sub) = {
    cdraw.rect((x0, 4.6), (x0 + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x0 + w / 2, 5.3), sub, size: 6pt)
  }
  step(0.8, 4.4, [discovery], [theories split by case])
  cdraw.line((5.3, 5.8), (5.9, 5.8), stroke: luma(100), mark: (end: ">>"))
  step(6.1, 4.6, [parallel classes], [collection at a time])
  cdraw.line((10.8, 5.8), (11.4, 5.8), stroke: luma(100), mark: (end: ">>"))
  step(11.6, 4.8, [separate host], [env by inheritance])
  cdraw.line((16.5, 5.8), (17.1, 5.8), stroke: luma(100), mark: (end: ">>"))
  step(17.3, 5.0, [no TestMain], [ctors and lazy state])
  cdraw.content((11.5, 3.5), [statics are shared across a class's cases, not across classes], size: 6pt)
})

== coverage without ceremony

Coverage rides the platform's own collector: `coverlet.collector`
6.0.4 sits in the test project, pinned, and the opt-in lane is one
make target that runs the suite with collection on and drops the
reports under a coverage directory. It is a lane, never a gate: the
corpus rule keeps percentages out of prose and out of `verify`, and
the number the load chapter defends is p99 over the wire, not a
line-count proxy. The runner merges nothing by itself, one profile
per project, and the lane is exactly as honest as that:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/CsharpBook.Api.Tests.csproj", first: 9, last: 14, caption: [the pinned collector, the only coverage dependency])

#diagram([the lane: collect, report, never gate], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 5.0), (x + w, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.7), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.7), sub, size: 6pt)
  }
  box(0.8, 6.0, [make csapi-cover], [opt-in, never in verify])
  box(7.5, 6.8, [collect:"XPlat Code Coverage"], [coverlet collector])
  box(15.0, 7.2, [coverage/], [cobertura per project])
  cdraw.line((6.9, 6.2), (7.3, 6.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.4, 6.2), (14.8, 6.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.9), [percentages are a lane, not a promise], size: 6pt)
  cdraw.content((11.5, 2.9), [p99 over the wire is the number the book defends], size: 6pt)
})

== what the suite proves

The suite closes the part the way the kernel opened it: everything
claimed in prose is a behavior some test observes. The counts on the
final tree are 379 tests under the solution, 18 of them the property
targets across six files, and 6 wire tests in the docker lane, five
green and the reports pair waiting on its route. The consolidation
left the support folder at eight files, one of each double, and the
two retirees live in git history where a reviewer can still read
them. The roadmap from here is the closeout's, not this chapter's:
the truth pass over all 15 chapters, the pdf rebuild, and the
attackers:

#listing("csharp-net/api/tests/CsharpBook.Api.Tests/Support/Vectors.cs", first: 17, last: 28, caption: [the one vector loader: the step model, and raw bytes when a test must compare them])

#diagram([the suite as one ledger: every row a test file family observes], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 7.9, 10.0, [vectors, byte for byte], [in process, injected clock])
  cell(17.1, 7.9, 10.0, [properties, seeded], [6 files, 18 tests])
  cell(5.9, 6.5, 10.0, [the duel, over the wire], [one 200, one 412])
  cell(17.1, 6.5, 10.0, [forgery, mutated], [no tamper survives])
  cell(5.9, 5.1, 10.0, [the cache, modeled], [40 runs x 200 ops])
  cell(17.1, 5.1, 10.0, [drain and admission], [readyz flips, cap holds])
  cell(5.9, 3.7, 10.0, [the exposition], [internal listener, over wire])
  cell(17.1, 3.7, 10.0, [consolidated support], [one clock, one loader])
  cdraw.rect((0.6, 2.2), (22.6, 3.2), fill: luma(225), radius: 0.02)
  cdraw.content((11.6, 2.7), [zero sleeps, zero skipped, zero framework doubles], size: 6pt)
})

sources: package versions read off nuget.org's flat container index
the day of writing, nsubstitute 6.2.0, fluentassertions 8.11.0,
awesomeassertions 9.6.0 as the fork of the fluent line, fscheck
3.4.0, sharpfuzz 2.3.0, accessed 2026-09-26, with the fork's
download count from nuget search the same day. xunit v2 behavior,
parallelism, theory discovery, and the separate test host verified
against xunit.github.io and against this suite's own runs. coverlet
usage against the coverlet github readme and the microsoft learn
code coverage page, also 2026-09-26. Verified by `dotnet test
Api.slnx`, 379 passed, and by the property filter alone, 18 of 18,
with the lane's five wire greens under `make verify-csapi-docker`.
