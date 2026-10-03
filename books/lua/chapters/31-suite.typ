#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= the test suite

The service part ends the way the language chapters began, with the
project runner: `samples/run.lua` pcalled a `{name, fn}` list per
chapter in chapter 1, and the service suite is that same runner grown
to 21 entries. This chapter turns the suite around as its own
artifact: the 2 shapes a test takes here, the 51-line runner and
59-line assert library that carry everything, the swap that moved the frozen
vector replay onto the composition root's real chain and caught 3
production defects doing it, the deterministic replay suites that
stand in for the property libraries the other lanes import, and the
dated facts about `busted` and `luaunit` this vehicle declines.

== what the suite holds

The census, stated once here and nowhere else in the chapter. The
plain lane runs 188 checks green: 136 of them live in the array part
of 15 family modules, each module carrying its own test list beside
the code it tests, and 52 of them live in 6 scenario files under
`service/tests/` that compose several families into one story. The jit
lane adds 18 checks over the ffi store family, a lane boundary and
never a skip, and the host lane drives 162 wire checks through the
compiled winsock seam. All 16 frozen vectors are pinned: 01 through 14
and 16 replay byte for byte through the scenario suite, and 15, the
metrics exposition, is pinned by the observability module's own list.
The runner's table is the census in executable form:

#listing("lua/service/run.lua", first: 7, last: 29, caption: [the chapters table: 15 family modules, 6 scenario files, the store suite's absence stated in the comment above])

#diagram([three lanes, each proving a different thing about the same tree], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [plain lane, 188], [logic in the 5.5 vm])
  cell(17.1, 8.3, 10.0, [jit lane, 18], [the ffi store family])
  cell(5.9, 6.9, 10.0, [host lane, 162], [the c seam over sockets])
  cell(17.1, 6.9, 10.0, [16 vectors], [the wire contract, byte for byte])
  cell(5.9, 5.5, 10.0, [136 family arrays], [units beside their modules])
  cell(17.1, 5.5, 10.0, [52 scenario checks], [families composed into stories])
  cdraw.content((11.5, 2.9), [one tree, three gates, the store suite a lane boundary], size: 6pt)
})

== the runner

The runner is 20 lines and no framework. Each entry in the chapters
table is required, its array part is walked with `ipairs`, and every
test function runs under `pcall`: a pass contributes one to the
module's count, a raise is caught, named to standard error as module,
test name, and message, and counted as a failure instead of killing
the run. The per-module line is the same shape chapter 1 printed.
The exit code is the whole contract with the make lane: zero failures
exits 0, any failure exits nonzero and `verify-lua` stops:

#listing("lua/service/run.lua", first: 33, last: 51, caption: [the loop: pcall per test, failures named, the exit code the only output verify reads])

#diagram([one entry's path through the runner], length: 13pt, {
  let step(x0, w, top, sub) = {
    cdraw.rect((x0, 5.4), (x0 + w, 7.4), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 6.8), top, size: 6.5pt)
    cdraw.content((x0 + w / 2, 5.9), sub, size: 6pt)
  }
  step(0.5, 4.4, [require], [the module loads])
  step(5.8, 4.6, [#"ipairs(mod)"], [the array part walks])
  step(11.3, 4.6, [#"pcall(t.fn)"], [a raise is caught, never fatal])
  step(16.8, 4.6, [the verdict], [counted, failures named to stderr])
  cdraw.line((5.1, 6.4), (5.7, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.6, 6.4), (11.2, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.1, 6.4), (16.7, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((19.1, 5.3), (19.1, 4.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((19.1, 4.2), [exit 0 or 1], size: 6pt)
})

== the t lib

The assert library is 5 functions shaped like `samples/lib.lua`, and 2
of them do all the work. `eq` tries lua equality first, so numbers,
strings, and booleans compare for free, and falls to a structural
walk for tables that counts members in both directions, so a missing
member and an extra member are both differences. The failure message
raises at level 2, which points the error at the caller's line rather
than inside the library. `throws` wraps `pcall` and requires the
message substring, `near` carries the float slack the clock
arithmetic sometimes needs, and `show` renders both sides sorted:

#listing("lua/service/lib.lua", first: 19, last: 36, caption: [deep equality counting members both ways, eq raising at level 2])

#diagram([each assert and the fact it establishes], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [#"T.eq"], [equal, or structurally equal])
  cell(17.1, 8.3, 10.0, [#"T.ok"], [truthy, message on failure])
  cell(5.9, 6.9, 10.0, [#"T.throws"], [raised, message contains])
  cell(17.1, 6.9, 10.0, [#"T.near"], [floats, with stated slack])
  cell(5.9, 5.5, 10.0, [#"T.show"], [sorted, one-line rendering])
  cell(17.1, 5.5, 10.0, [level 2], [the failure names the caller])
  cdraw.content((11.5, 3.9), [no mocking, no patching, no lifecycle], size: 6pt)
})

== the two test shapes

A test here takes 1 of 2 shapes, and the split is deliberate. The
family module carries its own tests in the array part of the table it
returns, the mixed-table idiom the json chapter ratified: the array
part is the test list the runner walks, the hash part is the module's
api, one table serving both, and a module test lives 1 require away
from the code it pins. The 6 files under `service/tests/` exist
because their subjects are not units: the vector scenarios compose
the store, the identity layer, the limiter, and the idem guard into
one chain, the ops walkthrough mirrors the root's splice order, and
the swap and replay suites drive the root itself. Both shapes splice
into the same chapters table, so the runner never learns which shape
an entry is:

#listing("lua/service/main.lua", first: 492, last: 508, caption: [the family shape: one entry of the kernel module's own list, beside the code it pins])

#diagram([the two shapes, one runner], length: 13pt, {
  cdraw.rect((0.6, 5.4), (10.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.6, 7.4), [the family module], size: 6.5pt)
  cdraw.content((5.6, 6.4), [array part: the {name, fn} list], size: 6pt)
  cdraw.content((5.6, 5.8), [hash part: the module's api], size: 6pt)
  cdraw.rect((12.4, 5.4), (22.4, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.4, 7.4), [the tests/ file], size: 6.5pt)
  cdraw.content((17.4, 6.4), [cross-family scenarios], size: 6pt)
  cdraw.content((17.4, 5.8), [vectors, ops, swap, replay], size: 6pt)
  cdraw.line((5.6, 5.2), (11.3, 4.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((17.4, 5.2), (11.7, 4.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((6.3, 2.2), (16.3, 4.2), fill: luma(222), radius: 0.02)
  cdraw.content((11.3, 3.6), [the chapters table], size: 6pt)
  cdraw.content((11.3, 2.8), [one pcall loop, one exit code], size: 6pt)
})

== the harness swap

The scenario suite began on a fixture that hand-rolled the whole
chain over a bare router, and the fixture's own comment invited the
swap: when the composition root grew a builder over injected seams,
the fixture could retire and the vectors would drive the production
wiring. `main.build(cfg)` is that builder, and the swap is 1 file.
The harness still owns the frozen vectors' queues, the constant clock
the byte pins assume, the ids and bytes in pop order, the test
iterations tier, and the collected sink, but the stack those seams
feed is now the root's own. The one ruled divergence rides the rules
seam, login only, because the frozen register vectors answer without
rate headers and the bytes outrank the prose for replay.

The swap caught 3 production defects the fixture had been hiding, all
3 fixed in the builder's landing commit. The idem store was built on
the bare seconds clock against a milliseconds ttl, making the 24 hour
expiry effectively immortal, and the fixture had crossed units all
along, which is why every byte stayed green while the root was wrong.
Nothing in the real chain fed `req.decoded`, so the login rule's
email keying collapsed every caller into 1 shared bucket in
production, invisible because the fixture decoded by hand. And the
idem guard's key-reuse refusal returned a raw fail value no layer
above it renders, so the contract's 422 reached the wire as a 500
with the connection closed, confirmed by probe before the fix. A 4th
finding closed as a deletion: the root minted a cache object nothing
consumed, its ttl on the bare seconds clock besides, and the honest
fix was removing it, a reads cache over an in-memory table being
theater the go lane's sqlite boundary earns. Every scenario byte held
through the swap, 13 of 13: the fixture agreed with the root because
the vectors said so, not because the 2 stacks were the same code:

#listing("lua/service/tests/harness.lua", first: 29, last: 51, caption: [the swap: the queues and seams feed main.build, the stack is the root's own])

#diagram([before and after the swap, the bytes the judge], length: 13pt, {
  cdraw.rect((0.4, 4.6), (10.2, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.3, 7.8), [before: the hand-rolled fixture], size: 6.5pt)
  cdraw.content((5.3, 6.9), [identity, decode, limit, idem], size: 6pt)
  cdraw.content((5.3, 6.1), [over a bare router], size: 6pt)
  cdraw.content((5.3, 5.2), [agreed with the vectors, hid the root], size: 6pt)
  cdraw.line((10.4, 6.5), (11.8, 6.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.1, 7.1), [the swap], size: 6pt)
  cdraw.rect((12.0, 4.6), (22.6, 8.4), fill: luma(222), radius: 0.02)
  cdraw.content((17.3, 7.8), [after: main.build's real chain], size: 6.5pt)
  cdraw.content((17.3, 6.9), [id, log, metrics, decode, bucket], size: 6pt)
  cdraw.content((17.3, 6.1), [deadline, recover, identity, guard, router], size: 6pt)
  cdraw.content((17.3, 5.2), [same queues, same bytes, one stack], size: 6pt)
  cdraw.content((11.5, 2.7), [3 defects found and fixed, the bytes the judge], size: 6pt)
  cdraw.content((11.5, 1.9), [the immortal ttl, the unfed decode, the 422 that answered 500], size: 6pt)
  cdraw.content((11.5, 1.1), [13 of 13 vectors byte-identical through the root], size: 6pt)
})

== the four fresh states

The vectors are scenarios, not 1 story, and the suite says so with
fresh state per group. Vector 08 revokes a session family, and
vectors 09 through 12 act with the very session that revocation
kills, so the read, patch, and list scenarios cannot follow the reuse
attack in one continuous state. Four fixtures cover the 4 stories,
each with its own queues, the ids a scenario will mint in the order
the requests will mint them and the bytes the wire will consume. One
ordering rule worth stating: the auth routes draw the dummy verify's
salt at wiring time, before any request runs, so the first queue
entry is always the dummy's, and scenario a's four 16 byte draws are
the dummy, then 3 registration salts:

#listing("lua/service/tests/vectors_test.lua", first: 72, last: 85, caption: [scenario a's build: the queues carry the vector's own ids and bytes in pop order])

#diagram([four scenarios, four fresh states, what each holds], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [a: the happy walk], [01 to 03, 13, the reads])
  cell(17.1, 8.3, 10.0, [b: the login limits], [04, 05, and the 429 of 06])
  cell(5.9, 6.9, 10.0, [c: the reuse attack], [07's rotation, 08's two 401s])
  cell(17.1, 6.9, 10.0, [d: roles and reports], [14's last admin, 16's pair])
  cell(5.9, 5.5, 10.0, [own id queue], [pop order pinned by the bytes])
  cell(17.1, 5.5, 10.0, [own byte queue], [dummy first, then the wire's])
  cdraw.content((11.5, 3.9), [08 revokes the family 09 to 12 acts with], size: 6pt)
  cdraw.content((11.5, 2.9), [fresh fixture per group, loud queue exhaustion], size: 6pt)
})

== replay invariants over seeded streams

The go lane holds its invariants with fuzz targets whose seeds ride
the plain gate, and this lane's analog is deterministic replay over a
committed seed, because the lua vm has no native fuzzing and the
contract rules the platform's own mechanism. The generator is a
hand-rolled xorshift64 rather than `math.random`, because the manual
declares `math.random`'s algorithm implementation defined, and a seed
whose every bit the book can print is the honest version of
reproducible. The first stream drives the cache as a state machine,
600 ops over 6 names at capacity 4, each op's move picked by the low
2 bits of the op word and its name by the bits above them. The
invariants are named and checked after every op: the bound holds, a
hit always answers the last write, a deleted name is gone, and
expiry is a cliff, everything written before a tick misses after it.
The hit invariant is one directional on purpose, because a bound
cache may legally miss what eviction removed, and the claim worth
testing is that it never answers a wrong value. The second stream
holds the bucket arithmetic the same way, 400 draws at random gaps,
the level inside its bounds, a denial free, an allow exactly 1, the
reported remaining floored. No test sleeps, every clock is
arithmetic, and no assertion depends on map order:

#listing("lua/service/tests/replay_test.lua", first: 45, last: 69, caption: [the op dispatch: four moves, an invariant under each, the bound after every op])

#diagram([seed to stream to model, the invariant under every step], length: 13pt, {
  let step(x0, w, top, sub) = {
    cdraw.rect((x0, 5.6), (x0 + w, 7.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + w / 2, 7.0), top, size: 6.5pt)
    cdraw.content((x0 + w / 2, 6.1), sub, size: 6pt)
  }
  step(0.4, 4.2, [the seed], [committed, xorshift64])
  step(5.6, 4.6, [the op word], [low 2 bits pick the move])
  step(11.2, 4.6, [the dispatch], [set, get, delete, tick])
  step(16.8, 4.6, [the model], [a plain table, in lockstep])
  cdraw.line((4.7, 6.6), (5.5, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.3, 6.6), (11.1, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((15.9, 6.6), (16.7, 6.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 4.4), [under every op: the bound holds, a hit answers the last write], size: 6pt)
  cdraw.content((11.5, 3.6), [a miss is legal, a wrong value is a failure], size: 6pt)
  cdraw.content((11.5, 2.8), [the bucket stream holds its arithmetic the same way], size: 6pt)
})

== busted and luaunit as dated meta

The ecosystem's 2 test frameworks both shipped lua 5.5 support in
2026, and both are declined on the standing rule. `busted` 2.3.0,
published 2026-01-07 under lunarmodules, brings describe blocks,
before_each hooks, spies and mocks, and a command line runner.
`luaunit` 3.5, published 2026-03-26, brings an assert family over the
xunit shape with xml output. The adoption criteria are stated so the
refusal is a decision: a framework earns its keep when the suite is
large enough that uniform describe structure beats reading a flat
list, when the mocking machinery replaces doubles this tree would
otherwise build, and when ci integration consumes the framework's
report format. This suite meets none of them. The runner is 20 lines
the book has already taught, the doubles are hand-rolled and strict,
and the make lane reads an exit code, so a dependency would add a
rockspec, a pin, and a second thing to learn, and remove nothing the
suite lacks. The strict double is the concrete core of that answer:
the store double in the reports module mirrors the real row shape
field for field, every call lands in a log a test reads to prove what
did not run, and a second create for a live id is an error rather
than a silent overwrite, the strictness generated mocks sell:

#listing("lua/service/reports.lua", first: 122, last: 146, caption: [the strict store double: the log proves what did not run, the second create errors])

#diagram([the frameworks as dated facts, the axes that would change the answer], length: 13pt, {
  let col(x, name) = cdraw.content((x, 8.4), name, size: 6.5pt)
  let row(y, what, mine, busted, luaunit) = {
    cdraw.content((3.4, y), what, size: 6pt)
    cdraw.content((9.0, y), mine, size: 6pt)
    cdraw.content((15.0, y), busted, size: 6pt)
    cdraw.content((20.6, y), luaunit, size: 6pt)
  }
  col(3.4, [the axis])
  col(9.0, [this suite])
  col(15.0, [#"busted 2.3.0"])
  col(20.6, [#"luaunit 3.5"])
  row(7.2, [structure], [a flat list], [describe blocks], [xunit classes])
  row(5.8, [doubles], [hand-rolled, strict], [spies and mocks], [none shipped])
  row(4.4, [ci reads], [the exit code], [junit and taps], [xml output])
  row(3.0, [dependency cost], [zero], [a rockspec and a pin], [a rockspec and a pin])
  cdraw.content((11.5, 1.4), [both added lua 5.5 support in 2026, neither adopted], size: 6pt)
})

sources: lua.org manual 5.5 sections 6.2 (basic functions, the pcall,
error, and assert the runner and lib are built on), 6.3 (coroutine
manipulation, the resume and status the deadline layer runs under),
6.7 (table manipulation, the remove and concat of the queues), 6.8
(mathematical functions, floor and min in the bucket arithmetic), and
6.10 (operating system facilities, os.exit and the root's os.time
edge), all accessed 2026-09-28. `busted` 2.3.0 verified against
github.com/lunarmodules/busted/releases and luarocks.org, `luaunit`
3.5 verified against luaunit.readthedocs.io, both accessed 2026-09-28
and deliberately not adopted, criteria stated above. The structural
mirror is the go lane's suite chapter,
`books/go/chapters/30-suite.typ`. Verified by the service lanes under
the pinned toolchain: 188 plain checks, 18 jit checks over the ffi
store family, 162 wire checks through the host seam, all 16 frozen
vectors byte-exact through the composition root's real chain.
