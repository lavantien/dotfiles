#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= the typed suite

Chapter 35 built the suite: `node:test`, `assert/strict`, hand-rolled
doubles, mock timers as the only clock, seeded prng loops as the
property checks, 317 tests over the js sources. This chapter runs the
same suite again with the import specifiers pointed at `src-ts/`, and
the claim under test is narrow and checkable: the typed vehicle behaves
identically because the same assertions pass against both trees. Where
the port needed a seam to speak, the seam is typed. Where it did not,
the test is the same text.

The wave built the mirror the way it built the vehicle, family by
family with the three verify legs green at every step. Each family's
mirrors landed as one unit, the js suite proving the spine untouched,
the ts suite proving the port faithful, the compiler proving the seams
coherent, and the next family started only when all three held. A
mirror that could not compile was never left in the shared tree, the
same parking discipline the js waves held for red tests, and the
ledger of those units is the commit chain this chapter's counts come
from.

== the same suite over the ts sources

Every one of the 63 js test files has a mirror under `test-ts/`, same
file name, same test names, same seeds, same counts. The differences
are exactly three. The imports name `.ts` modules, so the suite loads
the stripped sources through the same runner and the same glob shape
the js suite uses, `node --test` over a pattern that differs by its
directory and its extension. The
doubles grew the members the typed seams demand, `FakeRes` declares
itself an implementation of the kernel's `Res`, and one chapter's
private minimal recorder collapsed into the shared double because the
compiler refused the shortcut. And the fixtures type their deps
bundles, which reads as documentation and changes no runtime behavior.

The helpers came over with the same philosophy. `helpers.ts` is the
js `helpers.mjs` with one addition, the request double now carries an
empty async iterator because the `Req` seam names it and a router test
never reads a body, and `TestCtx` types the context at the recorder's
own richness so `res.json` reads without a cast, and one inert drift:
`makeCtx`'s id default moved from js `null` to the empty string,
unseen by every test that reads it. `ops-helpers.ts`
types the socket round trip and nothing else. The suite's discipline
carried over untouched: no test sleeps, every deadline and window runs
under `mock.timers` with `apis: ["setTimeout"]`, every opened server
closes in `after`, and the leak poll from the load chapter still asks
the process for its active resources and gets silence back.

The property loops came over byte for byte. The router's
static-beats-param invariant still drives seed `20261001`, the cursor
codec's closure still drives seed `0x53553138`, the store parity loop
still drives seed `0x12345678` against both stores, and the wire
writer's member-order loop still drives seed `0x53553137`. The seeds
are the cases, and a different answer from the ts tree would be a
different vehicle, which is the failure this suite exists to rule out.
Two tests have no js mirror, both in the probe file: one runs typed
syntax through the runner, one pins the stripping mode off the process
itself, so the ts suite counts 319 against the js 317, 6 describe
suites in each, zero sleeps in either.

The describe suites came over with their shapes intact because the
runner surface is the same surface. The limit layer's vector 06 replay
still mounts the wired stack under `describe` with a `before` that
builds the app once, the obs chapters still exercise the internal
listener and the finish-hook recorder in their own suites, the load
chapters still drive both loops, and the ship chapter still fires its
hand-rolled signal double at a real listening server. The mock timers
came with them, and the stripping runtime handles the double patching
the same way it handles any other library call, because the doubles
patch globals and the type syntax never survives to the call.

#listing("javascript/api/test-ts/kernel/router.test.ts", first: 24, last: 40, caption: [the same invariant, the same seed, the same loop, over the ts router])

#diagram([one suite, two trees, one gate], length: 13pt, {
  let box(x0, y, w, title, l1, fill) = {
    cdraw.rect((x0, y), (x0 + w, y + 1.6), fill: fill, radius: 0.02)
    cdraw.content((x0 + w / 2, y + 1.05), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, y + 0.35), [#l1], size: 6pt)
  }
  box(0.3, 5.4, 7.2, [vectors and seeds], [#"16 files, 4 committed seeds"], luma(235))
  cdraw.line((7.7, 5.6), (8.1, 6.4), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((7.7, 5.6), (8.1, 4.8), stroke: luma(100), mark: (end: ">>"))
  box(8.3, 6.2, 6.8, [js suite], [#"317 tests over src/"], luma(225))
  box(8.3, 3.4, 6.8, [ts suite], [#"319 tests over src-ts/"], luma(225))
  cdraw.line((15.3, 6.9), (16.1, 6.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((15.3, 4.2), (16.1, 4.2), stroke: luma(100), mark: (end: ">>"))
  box(16.3, 5.4, 6.0, [verify], [#"then tsc --noEmit"], luma(245))
  cdraw.content((11.3, 2.4), [the runner strips types itself, no compiler step in the loop], size: 6pt)
  cdraw.content((11.3, 1.4), [a green mirror is the port's behavior-identity proof], size: 6pt)
})

== what strictness catches

The port met, in the compiler, the classes of error the js tree can
only meet at runtime, and a few of them are worth naming because they
are the classes this book's js chapters guarded by hand.

The unknown catch. In js, `catch (err)` is whatever was thrown, and
`err?.stack` reads it optimistically. The typed `catch` hands over
`unknown`, so the recover layer's log line narrows with
`instanceof Error` before it reads the stack, and the js spine's line
and the ts line produce the same bytes while only one of them had to
say what it knows. The index read. `noUncheckedIndexedAccess` made
every params read a possible miss, which is true, a handler can be
mounted under a different pattern than the one it was written for, and
the presence rules the js handlers already ran are now the only thing
standing between the read and the answer, stated instead of assumed.
The optional member. `exactOptionalPropertyTypes` refused every
hand-built deps bundle that passed an explicit `undefined` down, and
the fix was to declare the optionals honestly, which is why the deps
interfaces read `| undefined` throughout.

The composition felt that one twice. `createKernel` receives the
spread of the whole deps bundle, and the first draft of its options
type took plain optional members, so the composition's
`{ ...d, ready }` failed to compile the moment any member held an
explicit `undefined`. The honest fix was not a cast, it was typing the
optionals as `X | undefined` and letting the spread tell the truth
about what a caller may pass. The same flag caught the wire limit's
key seam, where a default whose declared type accidentally read as
returning `undefined` was refused until the parentheses said what the
rule meant.

The tests also sharpened the seams, which runs the usual direction
backwards. The keyed runner's body argument started as a buffer
because the register wrapper reads bytes, and the guard's own tests
hand it strings, so the seam widened to `string | Buffer`, both naming
the same sha256, and the declaration now admits what the callers
actually do. The session store's `alive` started on the full record
and narrowed to the two members the time policy reads, because the js
test feeds it a partial and the partial is the honest input. A seam
that only compiles against the fixture you imagined is a seam the
suite has not met, and the port met every seam the js suite already
owned.

The doubles were the quietest win. A hand-rolled response that forgot
`write` or `on` compiled fine in js and failed the moment a layer
touched the member. Under the `Res` seam the double declares itself an
implementation and the compiler lists the missing members at authoring
time. And the ambient surface pays the same rent in reverse: a test
that reached for an api nobody declared, an unprobed `mock.module`, a
convenience off `process` nobody measured, fails to compile until
someone writes the declaration down and owns it.

#listing("javascript/api/src-ts/middleware/adapter.ts", first: 15, last: 28, caption: [the unknown catch narrowed by instance, the stack read only where it exists])

#diagram([the same mistakes, met at two different times], length: 13pt, {
  pane(0.3, 10.6, 7.2, [js: met at runtime], [a red test answers], [the fix after the run])
  cdraw.line((10.8, 4.8), (11.6, 4.8), stroke: luma(100), mark: (end: ">>"))
  pane(11.8, 22.3, 7.2, [ts: met at authoring], [a red squiggle answers], [the fix before the run])
  cdraw.content((5.4, 2.1), [the suite still catches it, later], size: 6pt)
  cdraw.content((17.0, 2.1), [the compiler catches it, sooner], size: 6pt)
  cdraw.content((11.3, 1.0), [both trees run the same assertions, only the meeting time moved], size: 6pt)
})

== what the vectors still own

The types never fork the contract. The 16 frozen files stay the spine
of both suites, sha256 pinned, and the pin test itself came over
unchanged: the mirror reads the same `contract/testdata` directory,
hashes the same bytes, and fails on the same drift. Wire member order,
status mapping, the timing flatten's identical 401 bytes, the etag
over exact body bytes, the replay snapshot, the metrics exposition,
all of it is behavior, and behavior belongs to the vectors and the
suite, not to the annotations.

The vector-driven chapters read the same in both trees for that
reason. Register still answers vector 01 byte for byte, the frozen
Set-Cookie line still lands with its attributes in order, the login
429 still replays its exact request id, and the report pair still
walks its 202, done, upgraded 200 chain. No type participated in any
of those answers, and none could: a type can promise that a writer
exists, only the frozen bytes can promise what it writes. The port
kept every runtime check for exactly this reason, the strict decode
ladders, the uuid test, the presence rules, so that the ts handler and
the js handler run the same code path with the same branches taken.

The wire claim is machine checked too, over the real socket. The ship
chapter's image carries both trees, and a compose override points the
entrypoint at the typed entry, so `make verify-jsapi-ts-docker` boots
the same image as a typed service on host ports 19180 and 19190 and
replays the same six wire tests against it, the same probes, the same
register and login walk, the same etag duel and report pair and
metrics exposition. Node strips the `.ts` sources inside the
container exactly as it does in the suite, no compiler rode into the
image, and a green lane is the same contract served through the
typed composition.

The js spine is untouched by ruling, and the ruling is enforced by the
chain rather than by promise. Every commit of this wave ran the js
suite first, so an edit that reached into `src/` or `test/` would have
turned the first leg red before anything else ran, and no commit in
the ledger carries such an edit. The two trees stay in lockstep the
same way they got there, a change lands in the spine, the js suite
proves it, the mirror follows it, and the ts suite plus the compiler
prove the mirror. A change that lands only in the typed tree is a
fork, and the shared vectors are the tripwire that fires on it.

That division is the wave's conclusion. The typed layer bought
guarantees about the seams, the wiring inside one process, and paid
for them with declarations the js spine never needed to write. The
vectors kept everything the process says to the outside world, and
they gate both languages alike, so the ts tree can never drift from
the contract without failing a test the js tree already ran. Two
notations, one service, 636 tests saying so on every commit.

What a reader carries out of the pair of chapters is the working
method rather than a new service. Start from the spine that already
runs, the js sources or the plain sources of any lane, and let the
typed tree grow beside it one family at a time with both suites green
between steps. Name the seams first, the context, the writer, the
port, the outcome unions, because those are the places where the
compiler can hold an agreement the prose otherwise enforces. Keep the
runtime checks that own the boundary, the decode ladders and the
shape tests, and let the frozen files arbitrate everything the process
says outward. When the method is followed the second notation costs
declarations and buys certainty, and the day it stops being followed
the compiler says so first.

#listing("javascript/api/test-ts/contract.test.ts", first: 48, last: 58, caption: [the pin test, mirrored unchanged: the same 16 hashes gate both trees])

#diagram([what gates what], length: 13pt, {
  let box(x0, y, w, title, l1, fill) = {
    cdraw.rect((x0, y), (x0 + w, y + 1.6), fill: fill, radius: 0.02)
    cdraw.content((x0 + w / 2, y + 1.05), [#title], size: 6pt)
    cdraw.content((x0 + w / 2, y + 0.35), [#l1], size: 6pt)
  }
  box(0.3, 5.2, 7.0, [the compiler gates], [#"the seams inside one process"], luma(235))
  box(15.0, 5.2, 7.0, [the vectors gate], [#"everything the wire says"], luma(235))
  cdraw.line((3.8, 5.1), (3.8, 4.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.5, 5.1), (18.5, 4.3), stroke: luma(100), mark: (end: ">>"))
  box(4.5, 2.6, 13.5, [16 frozen files], [#"byte-for-byte, sha256 pinned, both languages"], luma(225))
  cdraw.line((11.3, 2.5), (11.3, 1.7), stroke: luma(100), mark: (end: ">>"))
  box(4.5, 0.0, 13.5, [636 tests per commit], [#"317 js and 319 ts, one verify chain"], luma(245))
  pane(0.3, 8.0, 2.2, [the split], [types: seams], [vectors: wire])
})

sources: nodejs.org/api/test.md for the runner surface the mirrors
ride and nodejs.org/api/typescript.html for the stripping mode, both
accessed 2026-09-27, typescriptlang.org for the 7.0.2 compiler's
strict behavior on unknown catches and optional members, accessed
2026-09-27. The mechanism facts are the committed probe on node 26.3.0,
`process.features.typescript` with the value `strip`, 2026-09-27.
Verified by the live chain: the js suite at 317, the ts suite at 319,
and `tsc --noEmit` clean in `npm run verify`, plus the six wire tests
green over the typed composition under `make verify-jsapi-ts-docker`.
