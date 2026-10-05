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
chapter from 19 on applied one technique to its own component, frozen
clocks, injected seams, channel choreography, barrier duels, and what
is left is the discipline the whole suite runs on: the inventory
matched to the tree, the one lane gate and its legs, junit without a
build tool on the stdlib-exclusive ruling, the seams that make time
and chance deterministic, and the adversarial history each wave
recorded, including this wave's own. The go book closed its spine the
same way over six fuzz targets and a strict recording double,
#xref-to("go", "suite"), and the java lane's honest inventory differs
in one row: it holds no standing property engine targets yet, and
says so instead of borrowing the claim.

== what the suite holds

The counts are taken from the tree, not from memory, and they are the
commit's counts. The module's junit suite holds 158 tests in 17 files
across 12 packages, and the docker lane holds 5 more outside the
plain scan path:

#diagram([the inventory by package, each row the tests that pin it], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [httpx 24], [kernel routes, json round trips])
  cell(17.1, 8.3, 10.0, [store 27], [engine, wal, snapshots])
  cell(5.9, 6.9, 10.0, [user 20], [validation, etags, the duel])
  cell(17.1, 6.9, 10.0, [authn 16], [jwt shapes, login budget])
  cell(5.9, 5.5, 10.0, [obs 17], [exposition, buckets, quantiles])
  cell(17.1, 5.5, 10.0, [cache 14], [ttl table, single flight])
  cell(5.9, 4.1, 10.0, [limit 10], [boundaries, the race, flood])
  cell(17.1, 4.1, 10.0, [authz 8], [policy table, last admin])
  cell(5.9, 2.7, 10.0, [middleware 9], [request id, recover, timing])
  cell(17.1, 2.7, 10.0, [load 6], [2 loops, warmup, the report])
  cell(5.9, 1.3, 10.0, [conc 5, root 2], [admission, the health probe])
  cell(17.1, 1.3, 10.0, [integration 5], [over the wire, docker gated])
  cdraw.content((11.5, 0.2), [158 in the plain lane, 5 behind the daemon gate], size: 6pt)
})

Beside the module suite stands the samples contract, the manual arc's
own gate: 58 runnable classes under `samples/src`, one public class
per file, each embedding the `ok` helper and printing its own dated
checks, 493 of them across chapters 1 through 18 plus chapter 25's
12 more. The two contracts answer different questions and share one
runner: a sample teaches a language fact and proves it on stdout, a
junit test pins a service behavior and fails loudly in a report, and
neither substitutes for the other.

== the one lane gate

Everything runs through `tools/verify-java.ps1`, and its legs are the
whole anatomy. The vendored junit console jar rehashes against its
sha before anything runs, so a corrupted vendor is a loud red naming
the re-vendor path, never a silent swap. The samples runner walks
every chapter directory and fails on any class that prints no check
or exits non-zero. The module lanes compile src then test under
`-Xlint:all -Werror` on the pinned jdk and run the console over both
class directories, the api module first, then the capstone module and
its web leg as those waves landed them. The docker lane is the one
leg that lives outside the gate, `make verify-javaapi-docker`, its
absent daemon a loud red, its compose stack brought up healthy and
torn down with volumes on every exit:

#snippet(
  "& $java -jar $jar execute --scan-classpath --fail-if-no-tests `\n"
  + "  --disable-ansi-colors --disable-banner `\n"
  + "  -cp \"$root/build/classes;$root/build/test-classes;$jar\"",
  lang: "ps1",
)

Three facts about that invocation earn their sentences. The scan
discovers tests by classpath, so the `*Tests` naming convention is
load bearing, a helper class named like a test would run and fail on
its missing fixtures. The `--fail-if-no-tests` flag turns an empty
scan into a red, so a mistyped package in a future leg can never pass
by testing nothing. And the semicolons are the windows classpath
separator, the reason the script resolves the pinned jdk's own
binaries and never the machine's.

== junit without a build tool

The spine's standing rule is stdlib-exclusive, no gradle, no maven,
no spring, and the test runtime is the same ruling carried to its
conclusion: one vendored console jar, `junit-platform-console-
standalone` 6.1.3, sha-gated in the vendor manifest, carrying jupiter
and its params. Nothing resolves from the network, nothing generates
sources, and the build is two `javac` invocations an agent can run
and re-run in seconds. The cost is stated plainly: no dependency
management means every third-party want becomes a vendoring decision,
and the spine made exactly one, the test console, because a language
needs a test runner the way a book needs a printer. The 6.x console
is subcommand based, `execute` then the selectors, which the older
documentation's bare flags would silently misrun.

== the deterministic seams

Every boundary the suite proves is injected, never waited for. The
clocks freeze, `Nanos` in the limit, load, and observability tests,
`StepClock` in the store and user tests, and a refill boundary or an
expiry is arithmetic on ticks under any scheduler interleaving. The
ids are suppliers, so a cursor's wire bytes are reproducible. The
hashers are functions, so pbkdf2's cost never runs inside a table
test. The limiter's keyer is a function, so one app serves many
independent budgets keyed on a header. The load harness's op is a
function, so the closed loop's latencies are exactly the fake's cost
and the open loop's schedule is stepped, not slept. That is what
makes the race tests meaningful: 10 concurrent requests against a
frozen burst of 5 answering exactly 5 and 429 is a contract, not a
timing observation.

A handful of sleeps stand in the tree, and each is a wait on a fact
or the scenario itself rather than a proof of a boundary: one poll
loop awaits a log line under a deadline, and the choreography sleeps
hold a single-flight window open, or let one request arrive inside
another's admission wait, the kernel stop test's in-flight request
being a handler that takes 300 ms on purpose. A boundary proven by
sleeping proves nothing on a loaded machine, and no boundary in this
suite is.

The freshest seam tests are the adversarial round's own regressions,
and one earns its place as the exemplar, the histogram's first-touch
race, closed by eager cells and pinned by assertions on the rendered
sums:

#listing("java/api/test/javabook/obs/MetricsTests.java", first: 137, last: 164, caption: [the regression the blind round forced: 8 simultaneous first observations, all 8 counted in the bucket and the total])

== the adversarial history

Each wave ran its own attackers before landing, and the record is the
suite's scar tissue. Wave one, the kernel through the user resource,
closed 9 code and 20 prose findings. The store wave closed 17, the
wal's length overflow and append-failure poisoning among them, and
documented 2 latent items in prose rather than pretending them fixed,
the values-shared view rule and the non-ApiError escape at the
envelope boundary. The concurrency, cache, and limit wave closed 18,
the falsifiable single-flight among them, 6390 double fills measured
before the fix and 0 after, then the update scope's own round closed
6 more, the json null member rules and the repeated If-Match lines.
This wave's record has two halves. The development half caught its
own bugs as they surfaced, an unordered map reaching the report
unsorted, a racy counter in a fake, an open loop whose cold connection
pool met the listen backlog before the server did, each closed with
the test that pinned it. The blind half, 2 independent attackers on
the chapters, the code, and the ship lane, returned 19 confirmed
findings, and every one is closed in the tree: the histogram's
check-then-act bucket cell, the nearest-rank ceil an ulp too far at 2
measured vectors, the open loop's warmup failure settling its await
one arrival early, the untimed client that hung against a silent
server, the rate argument that accepted NaN, the ops path that
accepted percent-encoded spellings, the unsent exchange and the
measured window nothing pinned, the prose that claimed a shell-less
runtime on top of ubuntu, and the counts and ranges this chapter
re-verified.

#callout("note", "what the rounds are for", [
  The two-attacker round is the mutation-testing minimum this lane currently meets by hand: every surviving finding names a hole in the suite, and each fix lands with the test that would have caught it, so the next round starts from a harder suite. The rounds are recorded because an unfixed finding that survives into the book is a lie with a publication date.
])

== what the suite does not hold

The inventory's gaps are stated as plainly as its contents. No
standing property or fuzz targets ride the java lane, the go spine's
6 fuzz engines have no siblings here, so the arithmetic surfaces the
lane does hold, the json codec, the bucket refill, the rank, are
pinned by boundary vectors and adversarial rounds rather than by a
mutation engine, and a corpus-level fuzz minimum is carried by the
lanes that built those engines. No coverage percentage is printed
anywhere in the book, the figure moves with every edit and a pinned
number would be a lie with a date on it. And the capstone module's
own suite, the chat hub and the mini apps, is chapter 32's subject,
walked there beside the code it pins.

== what the suite proves

The closer maps each layer to the fact it establishes. The kernel and
json tests prove the envelope and the codec, the user and authn tests
the validation and the one 401 shape, the store tests the wal's
recovery and compaction, the concurrency tests the admission cap, the
cache tests the single flight, the limit tests the honest 429, the
observability tests the exposition and the exact rank, the load tests
the harness itself, the samples hold the language facts, and the
docker lane proves all of it again over a real image on a real port
with a real clock. That surface is contract, not preference, and the
spine's last word is the same as its first: a green lane means the
behaviors hold, and every number in this chapter was counted from the
tree on the day it was written.

sources: the junit console launcher's 6.1.3 cli, the `execute`
subcommand, `--scan-classpath`, and `--fail-if-no-tests`, verified
against the vendored jar at
tools/junit/vendor/junit-platform-console-standalone-6.1.3.jar, whose
sha256 e62b96ac475dbcde8599ea905d088f65d90778f86e259b856a49fa5c4ea256ec
matches the vendor manifest, accessed 2026-10-05. The lane anatomy
read from tools/verify-java.ps1 and tools/run-java-samples.ps1 as
they stand at this commit. The wave histories quoted from the ledger
at .claude/plans/briefs/java-TASKS.md and from this wave's own
commit messages. Verified live 2026-10-05 on
tools/jdk27/build/jdk-27, build 27+35-2325: the module suite 158
green 3 consecutive runs, the integration suite 5 green 2 consecutive
runs under `make verify-javaapi-docker`, and the samples runner
reporting 58 files and 493 checks, all counted again for this
chapter the same day.
