#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

#let dbox(x, w, y, t) = {
  cdraw.rect((x, y), (x + w, y + 1.1), fill: luma(235), radius: 0.02)
  cdraw.content((x + w / 2, y + 0.55), [#t], size: 6pt)
}

= the test suite

Twelve chapters landed a service one family at a time, every family
tested. This last chapter walks back through the suite and asks what
those tests are made of: the census, the one assert surface, the seam
behind every double, the frozen vectors as the spine, the sanitizer
legs, the fuzz lane behind its flag, and the boundary the composition
ran into. Three rules were fixed
before the first check ran and never bent: one CHECK macro and no
framework, function-pointer seams and no mock generator, byte-frozen
vectors where drift means the code is wrong. The gate prints the
inventory on every run: 1130 checks from 727 sites in 16 translation
units, zero skipped, zero sleeps.

== what the suite holds

The census first. The suite is one executable with one main,
`test_wiring.c`, and 15 family suites behind it, each exporting
`capi_test_<family>` over the api root and dispatched in registration
order. The prefix pins the scaffold before any family runs, the
toolchain, the engine, the vectors, and this chapter's own two census
checks:

#listing("c-os-cloud/api/tests/test_wiring.c", first: 75, last: 89, caption: [the scaffold prefix, toolchain, engine, vectors, and the census, each its own named check])

#diagram([the census: one main, 15 family suites, and the prefix that pins the scaffold], length: 13pt, {
  cdraw.rect((2.0, 6.6), (21.0, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 7.7), [the prefix, 9 checks], size: 6.5pt)
  cdraw.content((11.5, 7.05), [c23, clang 23, the engine 3.53.4, 16 vectors, the census], size: 6pt)
  cdraw.rect((2.0, 3.8), (21.0, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 5.75), [the 15 family suites, dispatched in registration order], size: 6pt)
  cdraw.content((11.5, 5.1), [kernel middleware limit obs load users authn], size: 6pt)
  cdraw.content((11.5, 4.55), [authz store store rep reports conc cache ship comp], size: 6pt)
  pane(2.0, 11.2, 3.2, [zero skipped], [no filter, no annotation], [a check runs or does not exist])
  pane(11.8, 21.0, 3.2, [zero sleeps], [gates are event handles], [the clock never ticks on its own])
})

The 727 sites, counted as every CHECK and TRES_CHECK call site in the
sixteen test translation units with the macro definitions themselves
subtracted, produce 1130 ok lines because the sites ride loops, one
vector replay a handful of checks multiplied across sixteen files. Each
family keeps its own counter, prints its own lines, and returns nonzero
on its first failure, and the gate sums the ok lines and fails on any
FAIL line or nonzero exit. Every clock in the suite is arithmetic on an
injected counter pinned to the contract's t0, 2026-10-01T05:00:00Z,
stepping by each vector's own second offsets.

== the CHECK convention

The assert surface is one macro, the book's own from chapter 1, and the
suite is what it grew into. A check is a condition and a name. On
success the counter increments and one line prints, the word ok, the
number, the name. On failure the FAIL line prints with the check number
and the family returns 1 on the spot:

#listing("c-os-cloud/api/tests/test_wiring.c", first: 39, last: 48, caption: [the one macro, a name, a counter, and the nonzero exit that stops the family])

#diagram([one check's two paths, and what the gate does with each], length: 13pt, {
  cdraw.content((11.5, 8.2), [the condition], size: 6.5pt)
  dbox(2.6, 5.6, 6.4, [true])
  dbox(14.8, 5.6, 6.4, [false])
  dbox(0.6, 6.4, 5.6, [ok line, counter +1])
  dbox(14.2, 6.8, 5.6, [FAIL line, return 1])
  cdraw.line((10.2, 8.0), (5.4, 7.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.8, 8.0), (17.6, 7.6), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 5.4), [the family returns 1, the run is red, the rest wait for the fix], size: 6pt)
})

First failure stops the family, and the trade is stated plainly: a
framework that continues past a failure reports everything wrong in one
run, this convention reports the first and stops, and the family's
remaining checks stay unproven until the fix lands, because a family
that failed has already failed and the next run is one command. The
strictness lives elsewhere: a double that sees an unexpected call fails
the check, and the gate treats zero ok lines as red, so a suite that
silently does nothing cannot pass. The shared harness carries one
variant, TRES_CHECK, the same macro over a counter passed by pointer:
two spellings, one convention.

== seams as the double mechanism

Where a test needs a double, the mechanism is the seam, and every seam
is a function pointer plus a context. The clock, the id source, and the
random source hang off the server struct, the log line is a sink the
middleware writes, and the connection io is a recv and send pair the
serve loop never names winsock through. The header states the rule
where it declares the clock: tests inject fakes stepped by hand, the
wiring installs the real ones. The kernel's io doubles are the shape of
all of them:

#listing("c-os-cloud/api/tests/test_kernel.c", first: 77, last: 95, caption: [the io doubles, scripted chunks in, one captured buffer out, a full buffer refuses])

#diagram([every seam, its double, and what it holds fixed], length: 13pt, {
  let col(x, name) = cdraw.content((x, 8.4), [#name], size: 6.5pt)
  let row(y, what, fake, fixed) = {
    cdraw.content((3.4, y), [#what], size: 6pt)
    cdraw.content((9.6, y), [#fake], size: 6pt)
    cdraw.content((17.4, y), [#fixed], size: 6pt)
  }
  col(3.4, [the seam])
  col(9.6, [its double])
  col(17.4, [what stays fixed])
  row(7.2, [clock], [a variable], [wire dates, expiries])
  row(5.8, [ids, rand], [queues of uuids, bytes], [the material the oracle froze])
  row(4.4, [recv, send], [chunks in, one buffer], [framing, exact bytes])
  row(3.0, [log sink], [one buffer], [the access and crash lines])
  row(1.6, [the fills], [a park on an event], [the singleflight window])
  cdraw.content((11.5, 0.2), [strict where they record: an unscripted call fails the check], size: 6pt)
})

Scripted chunks in, one captured buffer out, and the send double that
would overflow refuses rather than truncating. The c ecosystem reaches
for a pair by habit, Unity for assertions and CMock for generated
mocks, both at v2.7.0 from the same collective at access. Neither is
adopted, and the criteria are written down so the refusal is a
decision: a generator earns its keep against wide churning interfaces,
call-order contracts many consumers assert, and teams large enough that
uniformity beats reading twenty lines of fake. This vehicle's seams are
already function pointers and the hand fakes are shorter than the
adoption argument.

== the vectors as the spine

The spine is the 16 contract vectors, byte-frozen json files shared
with the sibling lanes, and the suite's relationship to them is
asymmetric: the go lane's copies are the oracle, the verify lane hashes
both sets file by file and names any difference, and drift means this
tree is wrong. Every resource family replays its slice, and the ship
family runs the whole set through the composed stack, through one
shared harness that builds the request with the one codec, dispatches
through the real router over the real store, and asserts the status,
every named header, and the body byte for byte through the canonical
renderer.

The harness earned one scar the reports chapter paid for. The kernel's
scanner caps a document at 96 nodes, right for wire bodies, and one
vector response carrying a then chain, vector 16 nests two, rode past
that budget and refused to parse whole. The fix is slicing under one
rule, that no second parser exists: a depth-one member walk, string
aware and brace matched, cuts the text into its pieces, and each piece
goes through the one codec on its own:

#listing("c-os-cloud/api/tests/tresource.h", first: 258, last: 276, caption: [the sliced docs, the war story in the declaration comment, each piece parsed on its own])

#diagram([one vector file, sliced into pieces, each through the one codec], length: 13pt, {
  cdraw.rect((0.6, 6.2), (23.4, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((12.0, 6.9), [one vector file], size: 6.5pt)
  dbox(0.9, 4.4, 4.6, [when_offset])
  dbox(5.7, 4.4, 4.6, [request])
  dbox(10.5, 7.0, 4.6, [response: status, headers, body])
  dbox(17.9, 5.2, 4.6, [then chain, as text])
  cdraw.line((8.0, 4.55), (8.0, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((13.9, 4.55), (13.9, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((5.0, 2.6), (18.0, 3.8), fill: luma(222), radius: 0.02)
  cdraw.content((11.5, 3.2), [each piece through the one codec on its own], size: 6pt)
  cdraw.content((12.0, 1.4), [a whole-file parse rides past the 96-node wire budget], size: 6pt)
  cdraw.content((12.0, 0.5), [sliced pieces never do, and no second parser exists], size: 6pt)
})

Frozen bytes mean the code is wrong. That is the whole enforcement, a
hash on the set and a byte compare on the answer, and the ruling runs
the other way too: when the oracle re-freezes a vector, every lane
changes together or every lane is red.

== the crash guard and the asan leg

Two legs harden the suite past assertions. The first is the crash
guard, structured exception handling turned into a contract answer. The
guard wraps the handler stack in a try and except pair, and the filter
makes one distinction: a stack overflow passes the exception on,
because the guard would run on the broken stack and the process dies
honestly, and everything else executes the handler:

#listing("c-os-cloud/api/src/middleware.c", first: 128, last: 152, caption: [the recover, every fault below this frame becomes the 500 envelope])

#diagram([the fault ladder, the filter's one fork, and the two legs under the suite], length: 13pt, {
  dbox(8.7, 5.6, 7.2, [a handler faults])
  dbox(3.0, 8.0, 4.6, [stack overflow])
  dbox(12.6, 8.0, 4.6, [anything else])
  dbox(3.0, 8.0, 3.0, [passes on, dies honestly])
  dbox(12.6, 8.0, 3.0, [the 500 envelope, detail to the log])
  cdraw.line((11.5, 7.1), (7.0, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((11.5, 7.1), (16.6, 5.8), stroke: luma(100), mark: (end: ">>"))
  pane(0.6, 10.0, 2.2, [the test's way in], [RaiseException, a software fault], [no sanitizer sees it])
  pane(12.6, 23.4, 2.2, [the second leg], [the same exe under asan], [rerun in the verify chain])
  cdraw.content((11.5, 0.6), [the access log outside the guard records the 500 the client saw], size: 6pt)
})

The fault becomes the contract's 500 internal envelope, the detail goes
to the log sink with the request id and never the response, and the
answer is best effort by nature, because the fault left whatever state
it left. Testing recovery without crashing: the test raises the access
violation status as a software exception through `RaiseException`, no
sanitizer sees a fault, and the assertions read
the 500 and the crash log line. The second leg is asan, the verify
chain rebuilding the whole test executable under `-fsanitize=address`
and running it again. The standing machine fact rides here: ubsan does
not run on this box, so the sanitizer leg is asan only, and its clean
run over the full suite is the strongest thing this toolchain says
about the suite's memory.

== fuzzing the parser

Property work rides libFuzzer behind a flag, never inside the verify
chain, because a search is not a gate. The target is the parser
translation unit compiled under `-fsanitize=fuzzer` by the opt-in
`make api-fuzz-c`: arbitrary bytes in, the invariants out, a violation
a trap:

#listing("c-os-cloud/api/fuzz/fuzz_parse.c", first: 15, last: 27, caption: [arbitrary bytes in, the parser's invariants out, a trap is a finding])

#diagram([the fuzz lane, seeded, bounded, and committed to only on failure], length: 13pt, {
  let stage(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), [#top], size: 6.5pt)
    cdraw.content((x + w / 2, 5.4), [#sub], size: 6pt)
  }
  stage(0.8, 4.6, [the seeds], [3 committed wire files])
  stage(6.0, 4.6, [the bounded run], [fixed seed, 2000 runs])
  stage(11.2, 4.6, [the invariants], [consumed, budget, terminator])
  stage(16.4, 4.6, [the verdict], [a trap is a finding])
  cdraw.line((5.5, 5.9), (5.9, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.7, 5.9), (11.1, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((15.9, 5.9), (16.3, 5.9), stroke: luma(100), mark: (end: ">>"))
  pane(0.8, 11.2, 3.4, [the policy], [a corpus file commits only], [beside a failure it reproduces])
  pane(12.4, 23.2, 3.4, [the generated tail], [hash named, no extension], [stays uncommitted, out of the census])
})

The invariants are the parser's contract: a complete request never
claims bytes it does not have, never overruns the body budget, and
always lands its terminator. The seed corpus is three committed wire
files doubling as regression inputs, the kernel tests carrying the same
bytes inline and asserting the exact parse.
The corpus policy is the lane's standing rule and the census check
enforces its edge: a corpus file is committed only beside a failure it
reproduces, while the bounded run writes its coverage gains beside the
seeds as extensionless hash-named entries that never enter the count or
the tree. The gate script's one linking trap: the sanitizer runtimes
must resolve from llvm's own resource directory, because the msvc
toolset ships its own clang_rt copies and lld searching the library
paths in order links the broken ones.

== what the suite proves

The closer maps each layer to the fact it establishes, the grid below.
The cross-lane claim is checkable in the tree: five books carry the 16
vectors byte-identical today, go as the oracle with c, csharp,
javascript, and python as mirrors, one rolling hash over the set, and
the program's later lanes join the same spine when they land, lua,
typescript, and java on the same vectors and the same hash.

The honest boundary is the one the composition chapter paid to learn,
and the suite is what could not see it. Three defects lived green under
family tests. The authorization hole: a dead
policy walk let any authenticated actor read, patch, or delete any user
row and grant roles up to self-admin, while every family's vectors
replayed byte-exact, because the vectors exercised the routes through
the families' own resolvers and the hole sat in the walk between them.
The login double draw: each family harness replays the login vector
byte-exact because each draws the bucket alone, and the composed
service drew twice, the middleware once and the handler once, so the
live burst refilled at half the contract's rate. The unlocked limit
table: a data race, family tests run one thread while the composed
service draws from every worker thread, and two concurrent misses on
one key could claim two slots. The fixes are in the tree and the lesson
is institutionalized, the login vectors now replay through the composed
one-layer stack, the fixture's `limit_layer` flag composing the limit
middleware over dispatch, so the family test draws the way the service
draws:

#listing("c-os-cloud/api/tests/test_authn.c", first: 422, last: 431, caption: [the login pair replays through the composed limit layer, the double-draw lesson as a fixture flag])

#diagram([the layer to proof map, and the band only composition sees], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), [#l1], size: 6pt)
    cdraw.content((x, y - 0.28), [#l2], size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [vectors: contract], [byte for byte, every family slice])
  cell(17.1, 8.3, 10.0, [seams: determinism], [same inputs, same bytes])
  cell(5.9, 6.9, 10.0, [handles: concurrency], [windows closed, zero sleeps])
  cell(17.1, 6.9, 10.0, [guard: recovery], [a fault becomes the 500])
  cell(5.9, 5.5, 10.0, [asan: memory], [the full suite, instrumented])
  cell(17.1, 5.5, 10.0, [transcript: composition], [the whole stack, real socket])
  cdraw.rect((2.0, 1.6), (21.0, 3.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 2.7), [what only composition sees], size: 6.5pt)
  cdraw.content((11.5, 2.1), [the authz walk between families, the double draw, the table race], size: 6pt)
})

Per-family testing proves each family against its slice of the
contract. What it cannot see is the space between families, where two
correct implementations of one rule meet, and that space is what the
ship chapter's transcript is for: a committed capture of a real process
on the pinned port pair, never re-run by verify. The suite is 1130
checks, zero skipped, zero sleeps, one fixed clock, sixteen frozen
files, and one transcript, and the boundary is stated plainly: the
tests prove what they can reach, the composition proves the rest.

sources: learn.microsoft.com's structured exception handling pages for
try-except, RaiseException, and the filter constants, and its
FindFirstFileA page for the census pattern matching, accessed
2026-09-27, llvm.org's libFuzzer documentation for the corpus semantics
and bounded runs and the clang sanitizer page for the address runtime's
placement, accessed 2026-09-27, github.com/ThrowTheSwitch's Unity and
CMock release pages, both at v2.7.0 at access, dated and deliberately
not adopted. Verified by the lane's runner at 1130 checks under the
pinned clang 23, the asan leg clean, and make api-fuzz-c's bounded run
clean over the committed seed corpus.
