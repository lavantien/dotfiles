#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= the test suite

The service spine ends with the service tested, and this chapter
turns the suite around and examines it as its own artifact. Every
chapter from 19 on applied one technique to its own component,
frozen clocks, injected seams, barrier duels, the ignored lane, and
what is left is the discipline the whole suite runs on: the
inventory matched to the tree, the one lane gate and its legs, the
two-lane contract this wave added, the seams that keep time and
chance deterministic, and the adversarial history each wave
recorded, including this wave's own. The go book closed its spine
over six fuzz targets and a strict recording double, #xref-to("go",
"suite"), the java book over a vendored junit console, #xref-to
("java", "suite"), and the rust lane's honest difference is the
smallest vendor count of the three: `cargo test` is the runner, the
toolchain brings it, and the crate contributes no dependency at all.

== the inventory

The counts are taken from the tree, not from memory, and they are
this commit's counts. The crate holds 162 tests in 13 integration
files, and 5 more live behind the docker gate:

#diagram([the inventory by file, each row the tests that pin it], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [httpx 33], [envelope, router, the pool, json])
  cell(17.1, 8.3, 10.0, [authn 16], [jwt shapes, refresh rotation])
  cell(5.9, 6.9, 10.0, [user 16], [vectors, etags, the cursor])
  cell(17.1, 6.9, 10.0, [conc 14], [admission, the idempotency flight])
  cell(5.9, 5.5, 10.0, [middleware 12], [request id, recover, timing])
  cell(17.1, 5.5, 10.0, [cache 12], [ttl table, single flight])
  cell(5.9, 4.1, 10.0, [obs 11], [exposition, buckets, the ring])
  cell(17.1, 4.1, 10.0, [authz 10], [policy table, last admin])
  cell(5.9, 2.7, 10.0, [store 10], [wal recovery, compaction])
  cell(17.1, 2.7, 10.0, [load 10], [2 loops, warmup, the report])
  cell(5.9, 1.3, 10.0, [limit 8], [boundaries, the frozen race])
  cell(17.1, 1.3, 10.0, [deploy 5, config 5], [the ship held to its files])
  cdraw.content((11.5, 0.2), [162 in the plain lane, 5 behind the daemon gate, plus 1 capture behind --ignored], size: 6pt)
})

Beside the crate suite stands the samples contract, the manual arc's
own gate: 85 sample files printing 902 dated checks across chapters
1 through 18, run by the same lane script as the multi-language
suites, 3 of them present and green this wave. The two contracts
answer different questions: a sample teaches a language fact and
proves it on stdout, an integration test pins a service behavior,
and neither substitutes for the other.

== the one lane gate

Everything runs through `tools/verify-rust.ps1`, and its legs are
the whole anatomy. The toolchain leg resolves the rustup-managed
stable msvc directory and asserts the exact `rustc 1.99.0
(b940084d7` prefix before anything compiles, so no machine default
toolchain can quietly satisfy a gate. The samples leg walks every
chapter directory and fails on any file that prints no check or
exits non-zero. The crate legs run fmt, clippy at `--all-targets
-D warnings`, and the tests, all under `CARGO_NET_OFFLINE=true` and
`--locked`, then the contract vectors hash against the go oracle
file by file, and finally the zero-dep leg reads the manifest for
any dependency section and the lock for exactly one package. The
docker lane is the one leg that lives outside the gate,
`make verify-rustapi-docker`, its absent daemon a loud red, never a
skip:

#snippet(
  "cargo clippy --all-targets --locked -- -D warnings\n"
  + "cargo test --locked\n"
  + "# then: the vectors hash against books/go/api/contract/testdata\n"
  + "# then: Cargo.lock holds exactly one package",
  lang: "sh",
)

The clippy invocation is the one that keeps the ignored file honest:
`--all-targets` compiles `docker_it.rs` like any other target, so
the docker-gated tests carry the same lint law as everything else,
ignored at run time, never exempt at compile time.

== the two-lane contract

The docker-gated suite is one file, `tests/docker_it.rs`, and every
test in it carries the same attribute:

#listing("rust/api/tests/docker_it.rs", first: 75, last: 76, caption: [the ignored-by-default law: the string names the one command that runs the test])

A plain `cargo test` compiles the file, lints it, and runs none of
it, measured: `0 passed; 5 ignored`. The lane target runs the same
file with `--ignored` against the compose stack the target itself
brings up, `RUSTAPI_URL` and `RUSTAPI_METRICS_URL` pointing at the
published ports, and the trap tears the stack down with volumes on
any exit. The five tests replay the contract over the real image:
health and routing with the 405 and its `allow`, register and login
with the one 401 shape that must not enumerate accounts, the notes
resource with its idempotent create, the etag duel over one
`If-Match` resolving to exactly one 200 and one 412, the exposition
scraped off the ops port with its content type and its one exact
path, and the actor budget drained to an honest 429 with
`retry-after` and both budget headers, spent under a registered
actor's own bucket so the drain can never starve the anonymous pool
the other four tests share.

#diagram([two lanes, one file: plain cargo never runs it, the lane target runs nothing else], length: 13pt, {
  pane(0.4, 10.6, 7.6, [the plain lane], [cargo test --locked], [162 green, 5 ignored])
  cdraw.line((10.8, 6.0), (11.4, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.8, 4.6), (11.4, 4.6), stroke: luma(100), mark: (end: ">>"))
  pane(11.6, 22.8, 7.6, [the docker lane], [make verify-rustapi-docker], [compose up, --ignored, down -v])
  cdraw.content((11.5, 3.2), [one file, both lanes, no skipped tests and no silent skips], size: 6pt)
})

== the deterministic seams

Every boundary the suite proves is injected, never waited for. The
clocks freeze or tick on arithmetic: frozen millis drive the token
bucket's boundary table, a mutex-held micros counter advances 100
per read so the observability layer measures exactly 100 micros per
request, and the load loops run whole schedules under fake sleepers
that record their waits into a vector. The ids are injected
functions, so the vector tests pin byte-identical cursor and etag
responses. The hashers are injected, so pbkdf2's cost never runs
inside a table test. The fire seam is a function, so the open loop's
schedule is stepped, not slept. The wall clock appears in exactly
one test, the client against a real listener, and that test asserts
counts and statuses only, never a duration, because a latency
asserted against a wall clock proves nothing on a loaded machine.

The one sleep in the tree sits behind `--ignored`: the capture
lane's readiness poll waits up to 10 seconds for the real binary's
first healthz, an availability wait with a deadline, and it is the
scenario itself, a measurement tool booting a measurement subject,
not a boundary proof.

== the adversarial history

Each wave ran its own attackers before landing, and the record is
the suite's scar tissue. The earlier waves' catches are their
chapters' own: the frozen race admitting exactly the burst, the
single flight measured at 6390 double fills before the fix in the
java lane's telling, the wal truncate-at-stop law, the substring
pins surviving clang drift. This wave's development half caught its
own bugs as they surfaced, and the list is short because the tests
came with the code: the nearest-rank rank computed with both an
add-999 ceiling and a `div_ceil`, a double ceiling that landed one
rank too far and failed the boundary table before any run went
green; the golden table's column literals, wrong by one space until
the first render; the ring's push borrowing its own cursor while
mutating it; the elapsed window miscounted by one clock read. The
expensive one arrived from outside the suite: the compose
healthcheck pronounced a healthy service dead, because inside the
container `localhost` resolves v6 first and the load client dialed
only the first address, a defect no in-process test could see
because the test loopback resolves one family. The fix landed in
the client's resolver loop, chapter 29 states it, and the lane that
caught it is the same lane that now proves it green on every run.

#callout("note", "what the rounds are for", [
  The rounds are recorded because an unfixed finding that survives into the book is a lie with a publication date, and a fixed one that names its test is a suite that grew. The healthcheck catch is the wave's own proof of the two-lane contract: the plain lane was green while the ship was broken, and only the docker lane could say so.
])

== what the suite does not hold

The inventory's gaps are stated as plainly as its contents. No
property or fuzz targets ride this lane, the go spine's 6 fuzz
engines have no siblings here or in java, so the arithmetic
surfaces the lane does hold, the json codec, the bucket refill, the
rank, the ring's overwrite, are pinned by boundary vectors and
adversarial rounds rather than by a mutation engine. No coverage
percentage is printed anywhere in the book, the figure moves with
every edit and a pinned number would be a lie with a date on it.
The capture lane is one test behind `--ignored` and its outputs
live in committed, dated files rather than in assertions, because a
measurement's artifact is a document, not a gate. And the capstone
crate's own suite is chapter 32's subject, walked there beside the
code it pins.

== what the suite proves

The closer maps each layer to the fact it establishes. The httpx
tests prove the envelope and the router's exactness, the user tests
the vectors and the strong etags, the authn tests the one 401 shape
and the refresh rotation, the authz tests the deny default and the
last admin, the store tests the wal's recovery and compaction, the
conc tests the admission cap and the idempotent replay, the cache
tests the ttl plane and the single flight, the limit tests the
honest 429, the obs tests the exposition and the exact rank, the
load tests the harness itself, the deploy tests hold the image and
the compose file to the ship's own constants, and the docker lane
proves all of it again over a real image on real ports with a real
clock. That surface is contract, not preference, and the spine's
last word is the same as its first: a green lane means the
behaviors hold, and every number in this chapter was counted from
the tree on 2026-10-14.

sources: the lane anatomy read from tools/verify-rust.ps1,
tools/run-rust-samples.ps1, and the Makefile's
verify-rustapi-docker target as they stand at this commit, the
target quoted in chapter 30 from its 01cca1f8 commit. The inventory
counted from the tree with `cargo test --locked` per target under
`CARGO_NET_OFFLINE=true` on the pinned 1.99.0 build, 2026-10-14:
162 plain-lane tests green, 5 docker-gated green under
`make verify-rustapi-docker` with the compose teardown observed
firing, and the samples leg reporting 85 files at 902 checks with
all 3 multi-language suites present. The two-lane contract verified
live the same day: a plain `cargo test --locked --test docker_it`
run printing `0 passed; 5 ignored`, then the lane target running
the same 5 green against the stack it built.
