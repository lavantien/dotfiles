#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the test suite

The service part ends with the service tested, and this chapter turns the suite around
and examines it as its own artifact. #xref-to("python", "testing") taught unittest's
anatomy on samples, the fixture protocol, the assert inventory, subTest, and the exit
code a programmatic run asserts, and every service chapter applied one technique to its
own component. What is left is the discipline the whole suite runs on: hand-rolled
doubles beside exactly one `mock.patch`, every deadline on an injected clock with
`Event` and join gates instead of sleeps, invariants held by seeded `random.Random`
loops because the stdlib ships no fuzz engine, a coverage lane over `trace` that stays
opt-in, and the ecosystem's pytest, hypothesis, and time-machine taught as dated facts
and declined on stated criteria. One rule governs everything: no third party is
adopted, and every library the ecosystem reaches for by habit is taught as a dated
fact instead.

== what the suite holds

The inventory first, stated from the tree, not memory: 313 tests in 22 modules under
`tests/`, the kernel and middleware suites, the users and authn families with their
route files, authz, the store's seven, the duel over it, conc, cache, limit, obs,
load, the platform pins, the vector spine, and the composition proof, the one file
that pulls `main.build_app` into the process and answers every route through the full
stack over a real sqlite file. The spine comes first because every family hangs from
it: the 16 frozen golden vectors, byte-copied from the go lane's contract testdata and
pinned by sha256, so drift in any lane's copy is a loud red in every lane. The
platform pins hold the ground under all of it, the interpreter is 3.14 and the
bundled sqlite is 3.50.4, measured facts, so a silent engine change fails a test
instead of surprising a chapter's numbers. Two boundaries shape the count: the docker
lane's wire replay sits in `integration/`, deliberately outside the discover glob, and
is #xref-to("python", "shipit")'s subject, and zero tests sleep and zero tests skip,
both greppable facts about the tree:

#listing("python/api/tests/test_contract_vectors.py", first: 37, last: 50, caption: [the spine: sixteen vectors, each failing under its own name when a byte drifts])

#diagram([the suite's layers, each against the one thing it proves], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [frozen vectors], [the wire contract, byte for byte])
  cell(17.1, 8.3, 10.0, [platform pins], [3.14, sqlite 3.50.4])
  cell(5.9, 6.9, 10.0, [family suites], [each module's grammar])
  cell(17.1, 6.9, 10.0, [injected seams], [clock, ids, hash, randomness])
  cell(5.9, 5.5, 10.0, [event gates], [concurrency, never timed])
  cell(17.1, 5.5, 10.0, [seeded loops], [nine invariants, committed seeds])
  cell(5.9, 4.1, 10.0, [the barrier canary], [the lost update, made deterministic])
  cell(17.1, 4.1, 10.0, [the census], [zero threads leaked per run])
  cdraw.content((11.5, 2.7), [each layer proves one kind of fact], size: 6pt)
  cdraw.content((11.5, 1.8), [no layer substitutes for another], size: 6pt)
})

== the unittest surface

The unit is `unittest.TestCase`, the loader collects one fresh instance per `test_`
method, and #xref-to("python", "testing") measured that interleaving, so this section
counts what the vehicle does with the surface. The assert inventory as used: 16
distinct methods plus `self.fail` across 730 call sites, `assertEqual` alone
two thirds of them, the context manager form of `assertRaises` extended with `as got`
into the caught error's own status and code, `assertAlmostEqual` with `delta=` where
float accumulation is the honest tolerance, the identity family `assertIs` and
`assertIsNone` for sentinel answers where `==` would accept a falsy stand-in, and
`self.fail` in the `else` branch of a `try` that should have raised. `subTest` carries
the parametric grids, 27 of them, a green grid counts once and a broken one names the
input that broke it. Fixtures pair 17 `setUp` with 13 `tearDown`, and `addCleanup`
appears 12 times where order is the contract: cleanups run LIFO and run even when
`setUp` fails partway through, which is why the kernel's socket fixture arms its three
teardown steps in reverse the moment the thread starts, not in a `finally` a later
line might never reach:

#listing("python/api/tests/test_kernel.py", first: 365, last: 374, caption: [the listener fixture: three cleanups armed at birth, LIFO at death])

#diagram([the surface against what the vehicle uses it for], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(4.6, 8.3, 8.0, [TestCase], [the unit, fresh per method])
  cell(13.4, 8.3, 8.0, [16 asserts], [730 sites, equal is two thirds])
  cell(4.6, 6.9, 8.0, [subTest], [27 grids, failures named])
  cell(13.4, 6.9, 8.0, [setUp, tearDown], [16 and 13, paired fixtures])
  cell(4.6, 5.0, 8.0, [addCleanup], [LIFO, survives a failed setUp])
  cell(13.4, 5.0, 8.0, [discover, exit 1], [the only interface make sees])
  cdraw.content((9.0, 3.2), [discover -s tests -t . under the pinned venv], size: 6pt)
  cdraw.content((9.0, 2.1), [the same flags the integration lane sits outside], size: 6pt)
})

== doubles and unittest.mock

The doubles are hand-rolled and live beside the tests they serve. `make_request` and
`envelope_of` build and read the kernel's plain shapes, `recorded` and `terminal`
stamp an ordered box for chain tests, and `CapturedLog` wires the production
`JsonLogHandler` over a `StringIO`, so a test reads whole structured lines back
through the real formatter rather than a fake that would only test itself. The strict
shape is `ScriptedClient` in the load tests: one planned pair per request index, every
call recorded, an unplanned index an immediate failure. `unittest.mock` appears at
exactly one site in the whole suite, `mock.patch.dict` over `os.environ` for the
`GOAPI_DB` name in the store's wire test, the one dependency python code reads from
process ambient instead of an argument, and `patch.dict` is the honest tool there
because it swaps a mapping's contents and restores them on exit, no attribute spec to
keep honest. The composition test needs the same seam and spells it by hand, setting
the variable and restoring it in an `addCleanup`, which is the pair worth seeing side
by side: one ambient dependency, two restorations, no mocks anywhere else.
`MagicMock` and `patch.object`, the ecosystem's reflex, are unused for a
structural reason: every seam this service defines is an injected argument,
`users.Family(now=, new_id=, hash_password=)`, `Limiter(now=)`, and
`access_log(logger, clock=)`, so a double is a value the test builds whole, never a
loader patch, and the
spec discipline `Mock(spec=...)` sells against attribute typos is the interpreter's
own `AttributeError` when the double is a real class, because `FakeClock` is its own
spec:

#listing("python/api/tests/test_middleware.py", first: 26, last: 52, caption: [the hand-rolled half: a recorder, a terminal, and the production log handler over a buffer])

#diagram([four double shapes against the job each does], length: 13pt, {
  let col(x, name) = cdraw.content((x, 8.4), name, size: 6.5pt)
  let row(y, what, a, b) = {
    cdraw.content((3.4, y), what, size: 6pt)
    cdraw.content((10.6, y), a, size: 6pt)
    cdraw.content((18.0, y), b, size: 6pt)
  }
  col(3.4, [the job])
  col(10.6, [the vehicle's answer])
  col(18.0, [the ecosystem's habit])
  row(7.2, [counting, recording], [a box, a calls list], [#"MagicMock, call_count"])
  row(5.8, [the ambient seam], [#"patch.dict(os.environ)"], [#"monkeypatch, pytest-mock"])
  row(4.4, [spec discipline], [real classes, own spec], [#"Mock(spec=...)"])
  row(3.0, [strictness], [the scripted fake], [expectation apis])
})

== clocks, events, zero sleeps

The rule is absolute and greppable: no test anywhere sleeps, the string `.sleep(`
appears nowhere under `tests/`, and the word itself lives only in docstrings, the
limiter's own stating the rule in one line, "a rate limiter tested against time.sleep
is tested against a scheduler", and in the load harness's injected `sleep_until`
seam, which its test replaces with a recorder that answers instantly. Every deadline
runs on an injected
clock: `FakeClock` moves by arithmetic, `SteppedClock` steps by whole ticks, and the
middleware tests drive the access log's duration from an iterator of two planned
reads, so 0.25 is a stated fact about the seam, not a measurement of the scheduler.
Concurrency is gated, never timed. The deadline expiry test parks the handler on a
`gate` `Event`, the layer answers 503 and drops the late response, and
`produced.wait(5)` then proves the abandoned handler finished anyway, a fence with a
bound, loud if the fact never happens. The drain test gates on the drainer's
`flipped` `Event`, polls fresh dials until the listener refuses, which is real socket
state, and joins with a bound. The expired grace is `wait_for` at a zero timeout, one
predicate look, no waiting at all. The conc runner asserts the second caller is alive
while it is parked on the first caller's handoff event, in that file's words "a fact
about blocking, not a timing probe", and the `Barrier` rendezvous in the pool, duel,
and canary tests makes both writers hold the same stale read before either writes:

#listing("python/api/tests/test_middleware.py", first: 200, last: 214, caption: [the expiry: gated on an event, the late answer dropped, the handler proven finished])

#diagram([the three gates, none of them a clock], length: 13pt, {
  let gate(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.4), sub, size: 6pt)
  }
  gate(0.8, 6.4, [the Event], [a flip waited on, bounded])
  gate(7.9, 6.4, [the join], [a thread gone, bounded])
  gate(15.0, 6.4, [the Barrier], [both hold the stale read])
  cdraw.line((7.3, 5.9), (7.8, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.4, 5.9), (14.9, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.8, 2.6), (21.4, 4.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.1, 3.3), [the injected clock: FakeClock.advance, SteppedClock, two planned reads], size: 6pt)
  cdraw.content((11.5, 1.4), [zero sleep calls, the word lives in docstrings and one seam's name], size: 6pt)
})

== properties as seeded loops

The go lane has a fuzz engine and ships seeds that ride the plain gate, node has
neither, and python is in node's camp: the stdlib has no mutation search, no corpus
directory, no coverage-guided anything. The vehicle's answer is the seeded loop. A
property is a sentence that must hold for every input, `random.Random` with a
committed seed generates the inputs, the invariant is named in the file beside the
seed, and a failure replays exactly, because the seed is the case. The suite holds
nine loops: route order irrelevance on seed 2026, the bucket spend bound on 20261001,
the authz verdict grid on 3131, the cache capacity bound on 5501 and the hand-rolled
versus fused parity on 5502, etag determinism on 3301 and the conditional round trip
on 3302, the sql keyset walk against a sorted walk on 4402, and the cursor walk that
covers the table exactly once over shuffled insertions on 2925. The bucket loop is
the cleanest demonstration, its invariant is its arithmetic, the draws allowed can
never exceed capacity plus refill, held over 200 rounds of 500 draws with the clock
advanced by random fractions, and the honest boundary is stated with it: a seeded
loop is a fixed stream, not a search, which is why the seeds are committed like the
vector bytes, the replay is the contract:

#listing("python/api/tests/test_limit.py", first: 93, last: 104, caption: [the spend bound as a property: allowed never exceeds capacity plus refill, seed committed])

#diagram([seed to stream to invariant to verdict, the python answer to fuzzing], length: 13pt, {
  let stage(x0, w, top, sub) = {
    cdraw.rect((x0, 5.4), (x0 + w, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.8), top, size: 6.5pt)
    cdraw.content((x0 + w / 2, 5.9), sub, size: 6pt)
  }
  stage(0.6, 4.6, [the seed], [committed in the file])
  stage(6.0, 4.6, [the stream], [#"random.Random(seed)"])
  stage(11.4, 4.6, [the invariant], [named in a docstring])
  stage(16.8, 4.6, [the verdict], [fails loudly, replays exactly])
  cdraw.line((5.3, 6.4), (5.9, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.7, 6.4), (11.3, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.1, 6.4), (16.7, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.2), [nine loops, nine seeds, each invariant a sentence in the file], size: 6pt)
})

== dated and declined

The ecosystem's testing stack is dated here, named, and declined, and the criteria
are stated so the choice reads as a decision rather than a habit. pytest, at 9.1.1 on
PyPI the day of this writing, offers fixtures, `parametrize`, assert rewriting
through a bytecode hook, and a plugin graph. hypothesis, at 6.168.1, offers
composable strategies, shrinking that walks a failure down to its minimal form, and a
database of failures. time-machine, at 3.5.1, patches `time.time` and `datetime.now`
at the C level so a global clock becomes fake-able. Each fails the vehicle's adoption
criteria on its own ground: pytest's runner would add a dependency to a gate whose
whole design is that the interpreter alone runs it, and the surface it sells is
already in use, `TestCase` is the fixture, `subTest` the parametrize, and the named
assert methods already report their operands, which is all assert rewriting would
improve. hypothesis earns its keep against generator complexity a hand-rolled loop
cannot express, and these shapes are flat, `randbytes` over a length, `randrange`
over a dozen keys, `choice` over four actor kinds. time-machine exists for code that
reads a global clock, and this vehicle's modules take `now` as an injected callable,
so the fake clock is an argument and there is nothing global to patch. The same
accounting covers the framework lane: fastapi's `TestClient` story belongs to
#xref-to("python", "fastapi") and is declined there on the same rule. The verdict
grid below is the loop hypothesis would own, 200 seeded actor picks against every
policy, admin passes everywhere, anonymous passes only the open set, no code outside
the 401/403 pair, and an admin denial fails the test by name:

#listing("python/api/tests/test_authz.py", first: 152, last: 177, caption: [the verdict grid: seeded actor populations against every policy, seed 3131])

#diagram([the declined column against what each would have owned], length: 13pt, {
  let col(x, name) = cdraw.content((x, 8.4), name, size: 6.5pt)
  let row(y, what, a, b) = {
    cdraw.content((3.8, y), what, size: 6pt)
    cdraw.content((11.0, y), a, size: 6pt)
    cdraw.content((18.4, y), b, size: 6pt)
  }
  col(3.8, [the axis])
  col(11.0, [what it offers])
  col(18.4, [why the vehicle declines])
  row(7.2, [pytest 9.1.1], [fixtures, parametrize], [the surface is already in use])
  row(5.8, [hypothesis 6.168.1], [strategies, shrinking], [flat shapes, the seed replays])
  row(4.4, [time-machine 3.5.1], [the c-level clock patch], [#"now is an argument"])
  row(3.0, [dependency cost], [one module, or three], [zero, the interpreter runs the gate])
})

== coverage, opt in

Coverage answers what the suite executes, and the honest lane is opt-in exactly like
the go and `c#` lanes, never inside `make verify`, because a percentage measures the
machine and the tree, not the code. The mechanism is the stdlib `trace` module and
one invocation: the lane runs `unittest discover` itself under `--module`, counting
executed lines while the suite passes, and `trace`'s runctx arms `threading.settrace`
beside `sys.settrace`, read from the module's own source, so worker threads the suite
spawns count too. `'$prefix'` is `trace`'s spelling for the stdlib directory, the one
ignore that scopes the report to the vehicle tree, `--file` accumulates counts under
`.cover/` with one `.cover` file per module, and `--summary` prints the table once.
Two boundaries keep it honest, both probed on the pinned 3.14.7. The composition test
pulls `build_app` into the process, but the serving loop, the SIGTERM-to-drain chain,
and the exit code run only as a real process in the docker lane, so the report covers
the suite's own execution and the entrypoint's runtime half stays on the wire. And
`trace`'s own main swallows the traced program's `SystemExit`, a red
suite would still exit 0, so the lane requires the run's verdict line instead of the
exit code, coverage of a red run is not a report. No percentage appears in this book:
the number moves with every edit, and a pinned number would be a lie with a date on
it:

#listing("python/api/cover.sh", first: 13, last: 29, caption: [the lane: venv resolved, suite traced, the verdict line required])

#diagram([the gate against the opt-in lane], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.4), sub, size: 6pt)
  }
  box(0.8, 5.2, [the gate], [discover, compileall, ruff])
  box(7.0, 5.6, [the lane], [#"trace --count --summary"])
  box(14.0, 5.2, [the report], [one table, never pinned])
  cdraw.line((6.1, 5.9), (6.9, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.7, 5.9), (13.9, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.6), [make pyapi-cover, opt-in like api-cover and csapi-cover], size: 6pt)
  cdraw.content((11.5, 2.7), [worker threads count, threading.settrace rides runctx], size: 6pt)
  cdraw.content((11.5, 1.8), [main.py and the docker replay stay outside the report], size: 6pt)
})

== what the suite proves

The closer maps each layer to the fact it establishes, the service part's readiness
table one chapter later. The vectors prove the wire contract byte for byte across
every lane, the platform pins prove the interpreter and the bundled engine, the
family suites prove each module's grammar, the injected seams prove determinism, ids
and hashes and clocks supplied by the test, the event gates prove the concurrency
windows close without one millisecond of waiting, the seeded loops prove nine
invariants under their committed streams, and the census proves the harness leaks no
thread per run. The canary is python's honest answer to a missing tool: cpython ships
no race detector, so the suite forces the interleave with a barrier and turns the
lost update into a deterministic fact, the unsynchronized twin answers 1 and the
locked twin answers 2, which proves the hazard the lock exists for rather than the
detector go's lane runs. The suite's last proof is its own exit: the process ends,
daemon threads cannot hide inside it, the census already named anything left, and
`make` reads 0 or 1, the one number the whole chain exists to produce. Zero sleeps,
zero skips, contract minimums, not preferences:

#listing("python/api/tests/test_load.py", first: 213, last: 217, caption: [the census: the thread list before and after, the difference must be empty])

#diagram([the layer to property to where proven grid, closing the part], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [vectors: contract], [16 digests, every lane])
  cell(17.1, 8.3, 10.0, [platform: pinned], [3.14, sqlite 3.50.4])
  cell(5.9, 6.9, 10.0, [seams: determinism], [clock, ids, hash, random])
  cell(17.1, 6.9, 10.0, [gates: windows closed], [Event, join, Barrier])
  cell(5.9, 5.5, 10.0, [loops: invariants], [nine seeds, nine sentences])
  cell(17.1, 5.5, 10.0, [canary: the hazard], [1 without the lock, 2 with])
  cell(5.9, 4.1, 10.0, [census: zero leaked], [threading.enumerate diff])
  cell(17.1, 4.1, 10.0, [exit: 0 or 1], [the number make reads])
  cdraw.content((11.5, 2.7), [zero sleeps, zero skips, every lane carries this surface], size: 6pt)
  cdraw.content((11.5, 1.8), [contract minimums, not preferences], size: 6pt)
})

sources: docs.python.org, the 3.14 library pages for unittest (TestCase loading,
subTest, the assert methods, and discover), unittest.mock (patch.dict and the spec
argument), and trace (the command line, the `'$prefix'` spelling, and the runctx
hooks), accessed
2026-09-27, the trace facts verified against the pinned cpython 3.14.7 locally: the
lane run over the whole suite, the worker-thread hook read from the module source,
and the swallowed SystemExit probed with a deliberately red run. pypi.org/project for
pytest at 9.1.1, hypothesis at 6.168.1, and time-machine at 3.5.1, accessed
2026-09-27, deliberately not adopted. Verified by the vehicle's suite, 313 tests
under `make verify-pyapi` with zero sleeps and zero skips, and by `make pyapi-cover`
green over the same tree.
