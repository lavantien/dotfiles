#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= the test suite

The service part ends with the service tested, and this chapter turns the suite around and
examines it as its own artifact. What is left is the discipline the whole suite runs on:
`node:test` with `assert/strict` as the only framework, doubles that are arguments instead
of loader patches, every deadline owned by a fake clock, invariants held by seeded loops
because node ships no fuzz engine, and a coverage lane that stays opt-in. The standing
rule governs here too: no third party adopted, every habitual package taught as a dated
fact instead.

== what the suite holds

The inventory first, because the chapter builds on all of it. The suite holds 60 test files
across the family directories plus this chapter's own `test/suite`, 317 test
functions and 6 describe suites at this landing, and all sixteen frozen vectors are pinned
by a single file whose job is the spine: each vector's bytes hashed with sha256, drift in
either direction failing the run. Around the vectors sit the techniques each chapter
contributed, the router precedence, parity, and bound loops, the limiter's 429 replayed at
the vector's frozen instant, the load lane's orphan check. Zero tests sleep, every test that opens
a server closes it in `after()` or a `finally`:

#listing("javascript/api/test/contract.test.mjs", first: 8, last: 24, caption: [the sixteen vectors, sha256 pinned: the spine every family test hangs from])

#diagram([the suite's layers, each against the one thing it proves], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [frozen vectors], [the wire contract, byte for byte])
  cell(17.1, 8.3, 10.0, [table tests], [the named cases, one block each])
  cell(5.9, 6.9, 10.0, [injected seams], [clock, ids, hash, timers])
  cell(17.1, 6.9, 10.0, [fake clocks], [every ttl, rate, expiry])
  cell(5.9, 5.5, 10.0, [seeded loops], [nine invariants, committed seeds])
  cell(17.1, 5.5, 10.0, [strict fakes], [calls that must not happen])
  cell(5.9, 4.1, 10.0, [parity and teardown], [two stores, one port, zero orphans])
  cdraw.content((11.5, 2.7), [each layer proves one kind of fact, none substitutes for another], size: 6pt)
})

== the surface

`node:test` is the vehicle's only test framework and the whole surface fits in one import.
The unit is `test()`, the grouping form is `describe()` with `it()` inside: 6 describe
suites carry the 17 layered tests that mount a real kernel, and the other 300 ride bare
`test()` calls. Subtests exist on the surface as `t.test()` and the vehicle does not use
them, `describe` and `it` nest identically in the runner's report and keep the arrange and
assert phases in separate scopes. The assertion half is `assert/strict`, and the strict is
load-bearing: plain `node:assert` runs legacy mode where `equal` is `==` and
`assert.equal(1, "1")` passes, while the strict import rebinds `equal` to `strictEqual`
and `deepEqual` to `deepStrictEqual`. Each identity gets one job: `assert.equal` compares wire
bytes as strings, strict identity on strings being content equality and the vectors
content, and `assert.deepEqual` compares parsed shapes like the router's params, where
prototype and type must match too:

#listing("javascript/api/test/obs/layer.test.mjs", first: 9, last: 23, caption: [a describe suite over the real kernel, the handle closed in the same block])

#diagram([the runner surface against what the vehicle uses it for], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(4.6, 8.3, 8.0, [#"test()"], [the unit, 300 of them])
  cell(13.4, 8.3, 8.0, [#"describe + it"], [6 suites, 17 layered tests])
  cell(4.6, 6.9, 8.0, [#"t.test()"], [on the surface, unused])
  cell(13.4, 6.9, 8.0, [#"t.after()"], [teardown, every open handle])
  cell(4.6, 5.0, 8.0, [#"assert.equal"], [wire bytes, content identity])
  cell(13.4, 5.0, 8.0, [#"assert.deepEqual"], [parsed shapes, strict])
  cdraw.content((9.0, 3.2), [legacy node:assert and its == coercion: never imported], size: 6pt)
})

== doubles without a framework

The doubles story is two platform tools and one hand-rolled shape. `mock.fn()` builds a
counting function, and the suite counts with it everywhere: handler calls in the
concurrency guard, fills in the cache layer, log lines in the middleware tests, each
asserted through `handler.mock.callCount()`. `mock.method()` intercepts one method
of a real object in place, and the vehicle never reaches for it, because every seam the
service defines is an injected argument rather than a method on a shared object, so a
seam's double is a plain object the test builds whole. The hand-rolled shape is the
strict fake, the one thing neither platform tool gives by default, a double where any
call at all fails the test, and the concurrency chapter's `refusingKeys` is eight lines
proving a negative, that the keyed runner never consults storage on the paths it does
not govern:

#listing("javascript/api/test/conc/guard.test.mjs", first: 19, last: 26, caption: [the strict fake: any call is unexpected, the guard proven clean-handed])

The ecosystem's habit is the reverse of this choice, `jest.fn()` and vitest's `vi.fn()`,
`testdouble`, `sinon` with its spies and sandbox restore. All are taught as names and
adopted as nothing, on the maintenance rule: a mock library in the graph is a dependency
whose deprecation becomes your migration, while these seams are small enough that a
readable object literal costs less than the tooling it replaces, and the strictness
those libraries sell is the eight lines above for unexpected calls and a `mock.fn` plus
an `assert.equal(callCount(), n)` for expected ones:

#diagram([four double shapes against the job each does], length: 13pt, {
  let col(x, name) = cdraw.content((x, 8.4), name, size: 6.5pt)
  let row(y, what, a, b) = {
    cdraw.content((3.4, y), what, size: 6pt)
    cdraw.content((10.6, y), a, size: 6pt)
    cdraw.content((18.0, y), b, size: 6pt)
  }
  col(3.4, [the job])
  col(10.6, [the vehicle's answer])
  col(18.0, [the ecosystem's answer])
  row(7.2, [counting], [#"mock.fn + callCount()"], [#"jest.fn, vi.fn"])
  row(5.8, [refusal], [a throwing object], [expectation APIs])
  row(4.4, [interception], [an injected argument], [#"mock.method, sinon"])
  row(3.0, [dependency cost], [zero], [one module, or a framework])
})

== the fake clock owns every deadline

Every clock-dependent test runs on `mock.timers`, and the discipline has three parts.
Enable names the apis to replace, `enable({ apis: ["setTimeout"] })` fakes `setTimeout`
in the global context and in `node:timers` and `node:timers/promises` alike, while a bare
`enable({ now })` takes the broader default and fakes `Date` too. Tick is the only clock:
the idempotency key's 24 hour window is driven to its boundary from below and above, the
cache ttl by a 1000ms tick, the limiter's frozen 429 at the vector's own instant, and no
test anywhere sleeps. Reset restores the real clock, explicitly in a `finally` or
`after()`, or implicitly because `t.mock.timers` restores itself when the test ends. The
idempotency test is the whole discipline in eleven lines, a match at `ttl - 1` and a
miss one tick later:

#listing("javascript/api/test/store/idem.test.mjs", first: 43, last: 53, caption: [the 24 hour window ticked to its boundary: match below it, miss past it])

Three platform traps are already probed on the pinned 26.3.0 and each has its fix in the
tree. The first is the captured reference: a module whose default clock is the `Date.now`
function value, `now = Date.now`, freezes the real clock into its closure before any test
enables the mock and ticks move nothing, so the vehicle's rule is a thunk, `now = () =>
Date.now()`, resolving `Date` at every call and seeing whatever clock is installed, a rule the
limiter states in its own comment. The
second is the default scope: a bare `enable()` replaces `setImmediate` too, so an
un-ticked immediate poll would hang forever, and the fixes are both in the tree, the
deadline tests narrow the apis list to `setTimeout` so their `setImmediate` settle steps
stay real, and the load lane's tests under the full default use latches, promises the
code under test releases, never polls. The third is the import: `mock` rides the named
export of `node:test` itself, imported alongside `test` in the whole-clock tests:

#diagram([one ttl under the fake clock, ticked across its boundary], length: 13pt, {
  cdraw.line((1.0, 4.4), (22.0, 4.4), stroke: luma(140))
  cdraw.content((1.4, 3.9), [#"enable({ now: t0 })"], size: 6pt)
  cdraw.content((21.8, 3.9), [time], size: 6pt)
  cdraw.line((6.0, 4.4), (6.0, 7.2), stroke: luma(100))
  cdraw.content((6.0, 7.6), [#"save()"], size: 6pt)
  cdraw.line((14.0, 4.4), (14.0, 7.2), stroke: luma(100))
  cdraw.content((14.0, 7.6), [#"tick(ttl - 1)"], size: 6pt)
  cdraw.line((19.0, 4.4), (19.0, 7.2), stroke: luma(100))
  cdraw.content((19.0, 7.6), [#"tick(1)"], size: 6pt)
  cdraw.content((10.0, 5.8), [#"lookup: match"], size: 6pt)
  cdraw.content((21.0, 5.8), [#"lookup: miss"], size: 6pt)
})

== properties as seeded loops

Go has a fuzz engine, and node does not: `node:test` ships no mutation search, no corpus
directory, no coverage guided anything. The node answer in this vehicle is the seeded loop:
a property is a sentence that must hold for every input, a small prng with a committed
seed generates the inputs, the invariant is named in the file beside the seed, and a
failure replays exactly because the seed is the case. The book's stated prng is splitmix32, and
the suite holds nine loops: router precedence on an
LCG with seed 20261001, cursor compose on seed `0x2a17c0ffee`, the keyset round-trip,
store parity, and cache bound loops on seed `0x12345678`, bucket arithmetic on seed
`0x4c494d49`, metrics monotonicity on seed `0x4f425339`, and this chapter's two additions
in `test/suite`. The cursor closedness loop earned its prose the hard way, its own seed
found a true fact about the codec: a flipped base64 character decoded to a carriage
return between two json members, `JSON.parse` tolerates it as whitespace, and the parsed
key was valid while its re-encoding differed from the corrupted string. So the invariant
is stated in its honest two-leg form, byte identity pinned on issued bytes only, and the
corruption leg pins what matters to the walk, that any single-character corruption either
refuses or yields a well-formed key that itself round-trips, never a silently empty
position that would truncate page two:

#listing("javascript/api/test/suite/cursor-closed.test.mjs", first: 74, last: 91, caption: [round-trip over random sort keys, the identity leg on issued bytes])

#diagram([seed to stream to invariant to verdict, the node answer to fuzzing], length: 13pt, {
  let stage(x0, w, top, sub) = {
    cdraw.rect((x0, 5.4), (x0 + w, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.8), top, size: 6.5pt)
    cdraw.content((x0 + w / 2, 5.9), sub, size: 6pt)
  }
  stage(0.6, 4.6, [the seed], [committed in the file])
  stage(6.0, 4.6, [the stream], [#"splitmix32 or an lcg"])
  stage(11.4, 4.6, [the invariant], [named in a comment])
  stage(16.8, 4.6, [the verdict], [fails loudly, replays exactly])
  cdraw.line((5.3, 6.4), (5.9, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.7, 6.4), (11.3, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.1, 6.4), (16.7, 6.4), stroke: luma(100), mark: (end: ">>"))
})

== dated and declined

Node has a module mocking story and it is dated prose, not adopted surface. The
documentation marks `--experimental-test-module-mocks` at stability 1.0, early
development, added in v22.3.0 and v20.18.0, and it gates `mock.module()`, which swaps a
specifier's resolved module for a fake for the remainder of the run. Verified on the
pinned 26.3.0 with a probe: without the flag the `mock` object exposes no `module`
member at all, with the flag it is a function. The design reason for declining it is
stronger than the flag: module interception works by patching the loader, mocks a
specifier for every importer at once, fights ESM's evaluated-once semantics, and couples
a test to module identity rather than behavior. The vehicle's seams are constructor and
function injection instead, the deadline middleware takes a `timers` object, the limiter
a clock thunk, the store a `now`, so faking a dependency means handing the subject a
different argument, never touching the module graph. The deadline tests show the style in
one file, the seam test injecting a `timers` object built from two `mock.fn` doubles and
asserting the cleared handle without any clock at all:

#listing("javascript/api/test/middleware/deadline.test.mjs", first: 25, last: 38, caption: [the seam as the module-mock alternative: a timers object handed in, two mock.fn doubles inside])

The property library the ecosystem reaches for is `fast-check`, at version 4.10.2 on the
registry the day of this writing. It offers structured generators, shrinking that walks
a failing case down to its minimal form, and frequency-weighted unions, and the vehicle
deliberately fails its adoption criteria: the module graph is zero dependencies by
standing rule and `npm ci` over the committed lockfile is a no-op, the shapes this
service generates are flat enough that a ten line splitmix32 loop already states them,
and reproducibility rides the committed seed rather than a shrinker's output. The same
accounting covers the frameworks the kernel chapter declined, `express` at 5.2.1 and
`fastify` at 5.12.5 on the registry the same day, both would own the router, the
middleware chain, and the error envelope, the three things this part exists to build by
hand. The criteria are stated so the choice reads as a decision: a third party earns its
keep against generator complexity a hand-rolled loop cannot express, or a framework
feature the kernel would otherwise get wrong at the wire, and neither holds here:

#listing("javascript/api/test/suite/envelope-order.test.mjs", first: 92, last: 109, caption: [the hand-rolled generator loop: shuffled construction, byte-identical wire answers])

#diagram([the declined column against what each would have owned], length: 13pt, {
  let col(x, name) = cdraw.content((x, 8.4), name, size: 6.5pt)
  let row(y, what, a, b) = {
    cdraw.content((4.2, y), what, size: 6pt)
    cdraw.content((11.8, y), a, size: 6pt)
    cdraw.content((18.8, y), b, size: 6pt)
  }
  col(4.2, [the axis])
  col(11.8, [#"mock.module, fast-check 4.10.2"])
  col(18.8, [express 5.2.1, fastify 5.12.5])
  row(7.2, [what it offers], [loader swaps, generators], [router, chain, envelope])
  row(5.8, [stability], [#"a flag, stability 1.0"], [mature, and unnecessary])
  row(4.4, [the vehicle's answer], [a seam, a seed, a loop], [100 lines the book teaches])
  row(3.0, [dependency cost], [a module in the graph], [a framework owns the wire])
})

== coverage, opt-in

Node ships a native coverage lane and the flag story is verified on the pinned 26.3.0
rather than recalled: `node --test --experimental-test-coverage` prints a per-file table
of line, branch, and function percentages plus the uncovered line ranges, and the flag
still carries its experimental name in the v26 documentation, added in v19.7.0 and usable
with `--test` since v20.1.0. Around it 26 ships a threshold family,
`--test-coverage-lines`, `--test-coverage-branches`, and `--test-coverage-functions` turn
a low percentage into a failure, and `--test-coverage-include` and `--test-coverage-exclude`
scope the report. The lane is opt-in and stays out of the gate: `npm run verify` is the
plain runner and the coverage command is typed when wanted, never wired into a script, on
the ruling the go lane already made, a percentage measures the tree and the day, and a
pinned number would be a lie with a date on it. No percentage appears in this book, the
report's one job is the gap scan before a chapter lands, the branches the new tests never
reached:

#listing("javascript/api/package.json", first: 9, last: 13, caption: [the gate: one script, the plain runner, coverage never wired in])

#diagram([the gate against the opt-in lane], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.4), sub, size: 6pt)
  }
  box(0.8, 5.2, [the gate], [#"npm run verify, plain runner"])
  box(7.0, 5.6, [the opt-in lane], [#"--experimental-test-coverage"])
  box(14.0, 5.2, [the thresholds], [lines, branches, functions])
  cdraw.line((6.1, 5.9), (6.9, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.7, 5.9), (13.9, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.6), [still experimental-named in the v26 docs, verified on 26.3.0], size: 6pt)
})

== what the suite proves

The closer maps each layer to the fact it establishes. The vectors prove the wire contract
byte for byte, the table tests the named cases, the injected seams determinism, ids and
hashes and clocks supplied by the test, the fake clocks every ttl, rate, and expiry
boundary without one millisecond of wall time, the seeded loops nine invariants under
their committed streams, the strict fakes that calls which must not happen do not, and
the parity loop the deepest one, that the sqlite adapter and the frozen in-memory store
answer identically through the port because the port is the oracle and disagreement names
the diverging op. Two honest boundaries close the account. Node has no race detector, and
the go lane's child process canary has no equivalent here, the single threaded event loop is the mitigation the
concurrency chapter argued, and the load lane's orphan check polls `process.getActiveResourcesInfo()` after a run so
a leaked socket or timer fails the suite instead of haunting the next one. And node has
no fuzz engine, so the loops are fixed streams, not searches, which is why their seeds
are committed like vector bytes, the replay is the contract:

#listing("javascript/api/test/store/users-port.test.mjs", first: 193, last: 210, caption: [the parity loop: two stores, one port, the port the oracle])

#diagram([the layer to property to where proven grid, closing the part], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [vectors: contract], [kernel, users, authn, conc, limit, obs])
  cell(17.1, 8.3, 10.0, [loops: invariants], [nine seeds, nine sentences])
  cell(5.9, 6.9, 10.0, [clocks: boundaries], [ttl, rate, expiry, deadline])
  cell(17.1, 6.9, 10.0, [seams: determinism], [ids, hashes, timers, clock])
  cell(5.9, 5.5, 10.0, [fakes and parity], [refusals held, one port, same answers])
  cell(17.1, 5.5, 10.0, [teardown and limits], [zero orphans, no detector, no fuzzer])
  cdraw.content((11.5, 3.6), [every lane of the program carries this surface], size: 6pt)
  cdraw.content((11.5, 2.7), [contract minimums, not preferences], size: 6pt)
})

sources: nodejs.org/docs/latest-v26.x/api/test.html for `test`, `describe`, `it`,
subtests, `mock.fn`, `mock.method`, and `mock.timers` including the `apis` option,
nodejs.org/docs/latest-v26.x/api/assert.html for strict mode and the legacy `==` warning,
and nodejs.org/docs/latest-v26.x/api/cli.html for `--experimental-test-coverage`, its
threshold family, and `--experimental-test-module-mocks` at stability 1.0, all accessed
2026-09-26. The flag and mock surfaces verified against the pinned node 26.3.0 locally:
the coverage table run over a family test file, `mock.module` absent without the flag
and present under it, a bare `mock.timers.enable()` probed to take `setImmediate` and
`Date`. The registry reads: fast-check at 4.10.2, express at 5.2.1, fastify at 5.12.5,
accessed 2026-09-26, deliberately not adopted. Verified by the suite, 317 tests and 6
describe suites under `npm run verify`, zero sleeps, every handle closed.
