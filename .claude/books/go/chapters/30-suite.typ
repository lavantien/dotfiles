#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= the test suite

The service part ends with the service tested, and this chapter turns the suite around and
examines it as its own artifact. Chapter 14 taught the toolchain's test kinds, and every
service chapter applied one technique to its own component. What is left is the discipline the
whole suite runs on: invariants stated as properties and held by fuzz targets whose seeds ride
the plain gate for free, a strict recording double that gives hand fakes the one thing they
never had, the modern `testing.T` surface used where it earns its keep, and a merged coverage
lane that says what it measures and no more. One rule governs everything: no third party is
adopted, and every library the ecosystem reaches for by habit is taught as a dated fact
instead.

== what the suite already holds

The inventory first, because the chapter builds on all of it. The suite holds 182 test
functions, 6 fuzz targets, 1 example, and 2 benchmarks, and all sixteen frozen vectors are now
pinned by an in-process suite: the register pair in the concurrency chapter's flight tests, the
login and refresh family in authn, the cursor walk in users, the 429 in limit, the roles matrix
in authz, the metrics exposition in observability, the reports pair in analytics, with the
docker lane replaying the load bearing scenarios again over the real wire. Around the vectors
sit the techniques each chapter contributed, table tests with subtests, clocks and ids and
hashes injected as function fields, channel choreography that parks one request inside
another's window, synctest bubbles in the limiter and the janitor, and the child process race
canary behind the `GOAPI_CANARY_UNGUARDED` environment key. The youngest technique is the leak
check:

#listing("go/api/internal/loadtest/leak_test.go", first: 19, last: 33, caption: [the goroutineleak profile of go 1.27, asked directly after a real run])

The `goroutineleak` profile, new in go 1.27, has the runtime's collector decide reachability: a
goroutine blocked on a primitive nothing live references is a leak, and the profile's own write
runs the detection pass first, so the count reads the cycle that just happened. A closed
harness run against a closed server must leave exactly zero:

#diagram([the suite's layers, each against the one thing it proves], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [frozen vectors], [the wire contract, byte for byte])
  cell(17.1, 8.3, 10.0, [table tests], [the named cases, exhaustively])
  cell(5.9, 6.9, 10.0, [injected seams], [clock, ids, hash, randomness])
  cell(17.1, 6.9, 10.0, [channel parking], [concurrency on a leash])
  cell(5.9, 5.5, 10.0, [synctest bubbles], [time, without waiting])
  cell(17.1, 5.5, 10.0, [the race canary], [the detector, proven awake])
  cell(5.9, 4.1, 10.0, [the leak profile], [goroutines, all accounted])
  cell(17.1, 4.1, 10.0, [fuzz targets], [invariants, under mutation])
  cdraw.content((11.5, 2.7), [each layer proves one kind of fact], size: 6pt)
  cdraw.content((11.5, 1.8), [no layer substitutes for another], size: 6pt)
})

== properties as fuzz targets

A property is a sentence that must hold for every input, and the ecosystem's habit is a
property library: `rapid` v1.3.0 offers structured generators, shrinking, and state machine
tests, `gopter` is its older sibling, and `testing/quick` sits frozen in the standard library
as the ancestor nobody extends. None is adopted, on the program's standing rule: a third party
is a maintenance liability, and the toolchain already ships a property engine, a fuzz target
with an invariant inside its body. The seeds run as an ordinary table test under plain `go
test`, which is why all six targets ride `make verify` at zero cost, and `go test -fuzz` wakes
the coverage guided mutation engine on demand in the opt-in `api-fuzz` lane, never inside the
gate, because a search is not a gate:

#listing("go/api/internal/limit/bucket_fuzz_test.go", first: 18, last: 33, caption: [the bucket's arithmetic as a property: bounded, monotone, denial costs nothing])

The bucket is the cleanest demonstration because its invariants are its arithmetic: the level
lives in `[0, capacity]` at every observation, advancing the clock never lowers it, a denial at
a fixed instant costs nothing, and the decision's remaining never exceeds its limit. The seeds
are the fixed-draw vectors' own shapes, the login burst, the sustained refill, the register
rule's long idle, so plain `go test` re-runs the exact arithmetic the wire contract froze and
the engine explores around shapes that already matter. Degenerate parameters are guarded by an
early return rather than a skip, because a skipped invariant is an unproven one, and a failure
found under `-fuzz` graduates the chapter 14 way, the input landing in `testdata/fuzz` only
with a fix beside it:

#diagram([seed to mutation to verdict, the bounds band drawn through a refill trace], length: 13pt, {
  let stage(x0, w, top, sub) = {
    cdraw.rect((x0, 5.4), (x0 + w, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.8), top, size: 6.5pt)
    cdraw.content((x0 + w / 2, 5.9), sub, size: 6pt)
  }
  stage(0.6, 4.6, [seeds], [plain go test, table form])
  stage(6.0, 4.6, [mutation], [coverage guided inputs])
  stage(11.4, 4.6, [the property], [holds or fails loudly])
  stage(16.8, 4.6, [verdict], [failures land in testdata])
  cdraw.line((5.3, 6.4), (5.9, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.7, 6.4), (11.3, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.1, 6.4), (16.7, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((1.0, 4.4), (21.0, 4.4), stroke: luma(140))
  cdraw.content((1.4, 3.9), [0], size: 6pt)
  cdraw.content((21.0, 3.9), [capacity], size: 6pt)
  cdraw.line((4.0, 1.6), (4.0, 4.4), stroke: luma(100))
  cdraw.line((8.5, 2.6), (8.5, 4.4), stroke: luma(100))
  cdraw.line((13.0, 1.2), (13.0, 4.4), stroke: luma(100))
  cdraw.line((17.5, 2.2), (17.5, 4.4), stroke: luma(100))
  cdraw.content((11.5, 0.6), [the trace stays inside the band, whatever the schedule], size: 6pt)
})

== the cache as a state machine

The state machine is the property library's signature move, and the cache target expresses it
over the fuzz engine directly: each op byte dispatches by its low two bits to set, get, delete,
or advance the clock one full ttl, with the key taken from the bits above them, so every op
kind reaches every key and the engine chooses the collisions. The invariants read as a
contract, the bound holds after every operation, a hit
always answers the last write, and everything written before a tick is gone after it, because
expiry is a cliff. The model beside the machine is deliberately naive, a plain map maintained
in lockstep, since the point is a boring model that never agrees with a wrong implementation,
and divergence fails with both sides named. Two siblings complete the family: the cursor target
pins the codec's round trip and its refusal to decode a client string into a silently empty
key, the failure that would truncate a list walk at page two, and the envelope target is the
next section's subject. Beside the machine, one plain test runs the janitor's `Sweep` under
`t.Context()` in a synctest bubble, the context canceled at cleanup, so no defer is needed and
the sweep goroutine must be gone when the bubble closes:

#listing("go/api/internal/cache/cache_fuzz_test.go", first: 34, last: 58, caption: [the op dispatch: set, get, delete, or one full ttl of clock, bound checked after every step])

#diagram([ops and states with the bound guard under every step], length: 13pt, {
  cdraw.rect((1.0, 5.6), (6.2, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 6.9), [op byte], size: 6.5pt)
  cdraw.content((3.6, 6.1), [#"& 0x03 picks the move"], size: 6pt)
  let op(x, name, guard) = {
    cdraw.rect((x, 2.8), (x + 3.8, 4.8), fill: luma(222), radius: 0.02)
    cdraw.content((x + 1.9, 4.2), name, size: 6pt)
    cdraw.content((x + 1.9, 3.3), guard, size: 6pt)
  }
  op(7.4, [set], [last write recorded])
  op(11.8, [get], [hit = last write])
  op(16.2, [delete], [model forgets too])
  op(20.6, [tick], [ttl passes, all miss])
  cdraw.line((6.4, 6.6), (7.3, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((6.4, 6.6), (11.7, 4.9), stroke: luma(100))
  cdraw.line((6.4, 6.6), (16.1, 4.9), stroke: luma(100))
  cdraw.line((6.4, 6.6), (20.5, 4.9), stroke: luma(100))
  cdraw.rect((7.4, 0.6), (22.4, 2.0), fill: luma(205), radius: 0.02)
  cdraw.content((14.9, 1.3), [after every op: Len() <= max], size: 6pt)
})

== forgery resistance as a target

The authn targets attack the two things an attacker would. `FuzzJWTParse` holds the verifier to
its contract under mutation: `ParseHS256` either refuses with one of its five sentinels, a
closed set the body enforces with a default branch that fails the test on any sixth error, or
it accepted a token whose signature genuinely gates the bytes, which the body proves by
flipping each of the first eight signature bytes and demanding every mutant fail, because a
parse that survives a flipped signature byte was never checking the signature. The seeds are
the forged token table's own shapes, the tampered payload under the original signature, the alg
none header, an EdDSA token presented to the HS256 parser, truncations, four part splits, and
pure garbage. The envelope target holds both of the kernel's shapes at once. Its encoding leg
asserts a fixed point, marshal, unmarshal, re-marshal, byte identical, with a second decode
equal to the first, deliberately the claim rather than field equality, because a fuzzed string
can carry invalid UTF-8 that the codec legitimately sanitizes once, and the stable property is
that whatever the codec accepts it reproduces. Its ladder leg sends an arbitrary body and
content type through the strict `Bind` the handlers use and demands the outcome land on exactly
the closed set, clean decode, 415, 413, or 400, never a panic and never a raw error leaking
past the `errors.AsType` check. One construction detail earns its sentence: the oversize seed is
built before registration, because a seed only the mutation engine could synthesize would leave
the 413 leg unexercised under plain `go test`:

#listing("go/api/internal/authn/jwt_fuzz_test.go", first: 41, last: 65, caption: [refuse with a sentinel, or prove the signature gated the bytes])

#diagram([the verify ladder under attack at every rung], length: 13pt, {
  let rung(y, q, verdict) = {
    cdraw.content((6.2, y), q, size: 6pt)
    cdraw.content((16.8, y), verdict, size: 6pt)
    cdraw.line((6.2, y - 0.4), (6.2, y - 1.0), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.content((6.2, 8.6), [three parts, decodable], size: 6.5pt)
  rung(7.4, [alg is hs256?], [else ErrAlgMismatch])
  rung(5.8, [signature verifies?], [else ErrBadSignature])
  rung(4.2, [claims in window, issuer ours?], [else ErrExpired, ErrWrongIssuer])
  cdraw.content((6.2, 2.8), [accepted], size: 6pt)
  cdraw.content((16.8, 2.8), [then 8 flipped bytes all fail], size: 6pt)
  cdraw.content((11.5, 1.4), [the mutator strikes every rung, the ladder holds], size: 6pt)
})

== strictness without a framework

The suite's doubles were all stateful until now: `countingKeys` signals every lookup,
`countingHasher` proves the dummy verify ran, `countingMux` counts origin fills, `seqReader`
feeds deterministic randomness, `stubClient` stands in for the transport. What none could do is
fail a test for a call that should not have happened, or for an expected call that never
arrived, and the strict recording double closes exactly that gap: it wraps the real in-memory
session store, every call lands on a tape in arrival order, a call the test did not expect
fails on the spot, and a cleanup armed at construction fails the test again if an expected call
never came. Two interaction tests put it to work over the real routes, the logout test pinning
`Create`, `Get`, then `Revoke` in that order, and the refresh reuse test pinning `GetByRefresh`
before `Rotate`, twice through, with the reused token answering the family revocation's 401.
Sixty lines, hand-rolled, and it is the strictness generated mocks sell:

#listing("go/api/internal/authn/sessioncall_test.go", first: 42, last: 61, caption: [the strict double: cleanup armed at birth, the tape judged at death])

The landscape deserves its honest paragraph, because the ecosystem's habit is the reverse of
this choice. `golang/mock` was archived by google and reanimated as `go.uber.org/mock`, v0.6.0,
whose `mockgen` generates expectation-style mocks and whose workflow is the go 1.24 `tool`
directive plus a `go generate` line; `mockery`, `moq`, and `counterfeiter` generate doubles in
other dialects, and `testify` layers assertions over the plain surface. All of it is taught as
fact and adopted as nothing, on the maintenance rule: a generated file outlives the interface
churn it serves and a dependency's deprecation becomes your migration, while this module's
interfaces are small and stable enough that one readable file costs less than the generator it
replaces. The criteria are stated so the choice is a decision rather than a habit, a generated
mock earns its keep against wide churning interfaces, call-order contracts many consumers
assert, and teams large enough that uniformity beats reading sixty lines:

#diagram([hand fake, generated mock, assertion library, four axes], length: 13pt, {
  let col(x, name) = cdraw.content((x, 8.4), name, size: 6.5pt)
  let row(y, what, fake, gen, lib) = {
    cdraw.content((3.4, y), what, size: 6pt)
    cdraw.content((9.6, y), fake, size: 6pt)
    cdraw.content((15.4, y), gen, size: 6pt)
    cdraw.content((20.2, y), lib, size: 6pt)
  }
  col(3.4, [the axis])
  col(9.6, [hand fake])
  col(15.4, [generated mock])
  col(20.2, [assertion library])
  row(7.2, [strictness], [what you write], [expectations by default], [none, you assert])
  row(5.8, [drift], [visible, one file], [regenerate on churn], [assert strings drift])
  row(4.4, [readback], [the tape, in order], [violations reported], [failures, formatted])
  row(3.0, [dependency cost], [zero], [the toolchain plus a module], [one module])
  cdraw.content((11.5, 1.4), [this module: hand fake, zero cost, one file to read], size: 6pt)
})

== the testing.T surface and the generics truth

The `testing.T` type grew methods the suite uses where they fit. `t.Context` returns a context
canceled at cleanup, the whole lifetime contract in one call, and the sweep test uses it as the
janitor's cancellation. `t.Cleanup` registers a function that runs even after `t.Fatal` has
exited the test, which is why the strict double arms its tape judgment there rather than in a
defer the panic path could skip. `t.Attr` attaches key value pairs to the json event stream,
stamped inside the fuzz body on the `t` the engine hands it, so a failing input carries the
invariant it broke, and every target names exactly one. `t.Chdir` changes and restores the
working directory, the one method unused, because nothing here reads the cwd and forcing it
would be ceremony, the same rule the middleware chapter drew for its onion, adopt a layer when
the job exists. The generics inventory closes the accounting with the truth: the production
module uses the generic types `Cache[V]`, `entry[V]`, and `FillResult[V]`, the generic
functions `NewCache[V]`, `Bind[T]`, `Fill`, `GetOrFill`, and `OncePair`, the constructor
fixes `V` once and every later method call rides it, exactly one constrained generic,
`NearestRank[T cmp.Ordered]`, and zero generic methods, because a method declaring its own type
parameter cannot satisfy an interface and every seam this service defines is an interface a
store or a fake implements. The one generic method in the module lives in test code, the strict
double's `stamp[T hashArg]`, which needs no interface satisfaction. Production zero, tests one,
and the reason is structural:

#listing("go/api/internal/authn/sessioncall_test.go", first: 72, last: 79, caption: [the tape judged against the queue head, one call at a time])

#diagram([the modern T methods against the defer habit, and the generics count], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(4.6, 8.3, 8.0, [#"t.Context"], [canceled at cleanup])
  cell(13.4, 8.3, 8.0, [#"t.Cleanup"], [runs even after Fatal])
  cell(4.6, 6.9, 8.0, [#"t.Attr"], [rides the json stream])
  cell(13.4, 6.9, 8.0, [#"t.Chdir"], [restores the cwd, unused])
  cell(4.6, 5.0, 8.0, [defer], [the habit, still right often])
  cell(13.4, 5.0, 8.0, [generic methods], [production 0, tests 1])
  cdraw.content((9.0, 3.2), [adopted where the job exists, never to be modern], size: 6pt)
  cdraw.content((9.0, 2.1), [the one test helper needs no interface], size: 6pt)
})

== coverage without ceremony

Coverage answers what the suite executes, and the honest lane is opt-in exactly like the bench
lane, never inside `make verify`, because a percentage measures the machine and the tree, not
the code. The mechanism is two text profiles and a merge: the unit leg runs `go test -cover`
over the module, the docker leg brings the compose stack up with the ship chapter's `--wait`
contract and `down -v` trap, then runs the tagged integration suite with `-coverpkg` over the
whole module, and the merge sums execution counts per block, the same semantics `go tool
covdata merge` applies to binary profiles. The text route and not the binary one is a toolchain
fact stated plainly: `GOCOVERDIR` collects from binaries built with `go build -cover`, and `go
test` never routes its own collection through it. Two boundaries keep the number honest, the
containerized server is an uninstrumented release binary so the report covers what the two host
test binaries execute, a fact written in the script's own header, and no percentage appears
anywhere in this book, because the figure moves with every edit and a pinned number would be a
lie with a date on it:

#listing("go/api/cover.sh", first: 16, last: 24, caption: [both legs, the merge, and the honest total printed once])

#diagram([two legs, two profiles, one merged summary], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.4), sub, size: 6pt)
  }
  box(0.8, 4.2, [unit leg], [#"go test -cover ./..."])
  box(5.6, 4.6, [docker leg], [tagged replay, coverpkg])
  box(10.8, 4.6, [merge], [counts summed per block])
  box(16.0, 4.2, [summary], [cover -func, tail -1])
  cdraw.line((5.1, 5.9), (5.5, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.3, 5.9), (10.7, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((15.5, 5.9), (15.9, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.6), [the server in the container: not instrumented], size: 6pt)
  cdraw.content((11.5, 2.7), [the number moves, so no number is pinned], size: 6pt)
  cdraw.content((11.5, 1.8), [make api-cover, opt-in like bench], size: 6pt)
})

== what the suite proves

The closer maps each layer to the fact it establishes, chapter 29's readiness table one chapter
later: the vectors prove the wire contract, the tables the named cases, the injected seams
determinism, the channel choreography that the concurrency windows close, the synctest bubbles
the time dependent logic, the canary that the race detector is awake, the leak profile that the
goroutines are accounted, the fuzz targets that the invariants survive mutation, and the strict
double that the call orders hold. This surface is contract, not preference, every lane of the
program carries it per the testing minimums, and the store direction is a decision already
executed: the module owns an append-only write ahead log engine with torn tail recovery and a
hand-rolled `database/sql` driver over it, its one community dependency modernc.org/sqlite
gone from go.mod, while `golang.org/x/crypto`, `x/time`, and `x/sync` stay under
the platform-official ruling, taught through the primitives they compose. The suite's last
artifact is its quietest, the module's first example, an `Example` with an `// Output:` comment
that pins the cursor's wire bytes as a test, executable documentation that cannot rot without
failing the gate, and the existence of it answers the inventory's opening question, a suite
that runs tests, examples, seed corpora, and benchmarks has no kind left unexercised:

#listing("go/api/internal/user/pagination_fuzz_test.go", first: 42, last: 52, caption: [the module's first example: the cursor's wire bytes, pinned as output])

#diagram([the layer to property to where proven grid, closing the part], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [vectors: contract], [user, authn, conc, limit])
  cell(17.1, 8.3, 10.0, [properties: invariants], [the six fuzz targets])
  cell(5.9, 6.9, 10.0, [orders: the tape], [logout, refresh reuse])
  cell(17.1, 6.9, 10.0, [time: bubbles], [wait mode, janitor, sweep])
  cell(5.9, 5.5, 10.0, [races: canary awake], [child process, env key])
  cell(17.1, 5.5, 10.0, [leaks: zero], [the 1.27 profile])
  cell(5.9, 4.1, 10.0, [wire: docker lane], [compose up, tagged replay])
  cell(17.1, 4.1, 10.0, [doc: the example], [cursor bytes, output pinned])
  cdraw.content((11.5, 2.7), [every lane of the program carries this surface], size: 6pt)
  cdraw.content((11.5, 1.8), [contract minimums, not preferences], size: 6pt)
})

sources: pkg.go.dev/testing for `F.Fuzz`, `F.Add`, `T.Context`, `T.Chdir`, `T.Attr`, and
`T.Cleanup`, and pkg.go.dev/runtime/pprof for the goroutineleak profile, accessed 2026-09-26,
the fuzz and coverage behavior verified against go 1.27.0 locally, the two leg merge semantics
read against `go tool cover` and `go tool covdata`; pkg.go.dev/pgregory.net/rapid v1.3.0,
published 2026-03-30, go.uber.org/mock v0.6.0, published 2025-08-18, and the mockery, moq,
counterfeiter, and testify documentation, all accessed 2026-09-26 and deliberately not adopted.
Verified by the module's suite, 182 tests, 6 fuzz targets with their seeds riding plain `go
test`, 1 example, and 2 benchmarks under go vet, the plain gate, and the module-wide race
leg, with `make api-fuzz` green across all six targets and `make api-cover` green over the
standing compose stack.
