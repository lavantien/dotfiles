#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= testing and idioms

This book tests java without a build tool, without a framework for
most of it, and with one vendored jar where a framework is the right
answer. The reason is the corpus contract: every chapter's claims are
checked by code the reader can run with the pinned jdk and nothing
else, the same way the c and python books run their samples. This
chapter states the contract, builds the pieces a framework would
otherwise hand you, and closes the manual half of the book with the
idiom summary, what java 27 code looks like when none of the java 8
habits survive.

== the ok contract

Every runnable sample embeds the same helper. `ok(boolean, String)`
counts, prints `ok N name` per passing check, and on the first
failure prints `FAIL name (check N)` to stderr and exits 1. The
runner, `tools/run-java-samples.ps1`, compiles a chapter directory
under `-Xlint:all -Werror`, runs every main bearing class, and goes
red on a nonzero exit or a class that printed no ok lines. A green
run prints its check count and a dated measurement line, which is
where every number in this book's java prose comes from:

#listing("java/samples/src/Ch18/OkContract.java", first: 43, last: 57, caption: [the contract in use: count, assert the failure paths, run the table])

The shape is deliberate end to end testing. A sample drives real
files, real sockets, real subprocesses, the way chapters 14 through
17 did, because mocks over the jdk would test the mock. The contract
is also the honest budget: an assertion is a boolean and a name,
anything fancier needs a reason.

== asserts and tables by hand

The two framework conveniences worth building are exception
assertion and parameterization. `assertThrows` returns the caught
exception so the message can be checked, the failure mode a test
cares about:

#listing("java/samples/src/Ch18/OkContract.java", first: 21, last: 32, caption: [the junit shape without the framework, ten lines])

Parameterized tests are tables. A record per row, a list of rows, a
loop of `ok` calls with the row in the name, and a failing row is
legible in the output without a report file. The corpus makes one
exception for repeated values, inline test tables, and the rule
claws back anything that escapes the table:

#listing("java/samples/src/Ch18/OkContract.java", first: 34, last: 41, caption: [the function under test and its table shape])

== interleavings and contention

Java has no `-race` equivalent. The go book leans on a race detector,
#xref-to("go", "concurrency"), this book cannot, so correctness of
concurrent code rests on two disciplines. First, deterministic
interleavings: choreograph the threads with latches and barriers
until the order under test is the only possible order:

#listing("java/samples/src/Ch18/OkContract.java", first: 71, last: 102, caption: [a barrier forces the lost update window, then the atomic fix])

The `CyclicBarrier` demo is the honest version of a race: both
threads read, the barrier proves both reads happened before either
write, and two increments land as one. It is a data race by design,
isolated in two lines, with the joins providing the happens-before
edge that makes the final read sound. Second, contention loops, the
jcstress style from the openjdk's own concurrency torture tool:
exact answers under load, asserted, with the timing printed:

#listing("java/samples/src/Ch18/OkContract.java", first: 104, last: 133, caption: [4 threads x 250,000 increments, atomic and monitor, exactness asserted])

Measured on this machine, 2026-10-04: the atomic loop ran 24.5 ms
and the monitor loop 141.4 ms for the same million increments, both
exact. The number is machine specific, the exactness is not. The
service spine's chapter 31 suite builds its race story on these two
disciplines plus golden vectors, fixed input and output pairs that
pin the whole http pipeline end to end.

== the junit lane

For class shaped tests the book vendors one jar,
`junit-platform-console-standalone-6.1.3.jar` under `tools/junit/`,
the fat jar from maven central dated 2026-08-07. The 6.x console is
subcommand based, `execute`, `discover`, `engines`, and the lane this
chapter's sample drives is:

#listing("java/samples/src/Ch18/JUnitLane.java", first: 21, last: 37, caption: [the pinned jar path, and the honest branch while wave 2 owns vendoring])

Exit codes carry the verdict: 0 for green, 1 when any test or
container failed, 2 when nothing was discovered under
`--fail-if-no-tests`, 3 for invalid input. Test classes follow the
`*Tests` naming convention, junit 5 style, so discovery finds
`OkTests` and skips helpers. Inside, the api is the jupiter one:
`assertEquals`, `assertThrows` from `org.junit.jupiter.api`, and
`@ParameterizedTest` with `@CsvSource` from the bundled
jupiter-params, the framework version of the table loop above.

#callout("note", "vendoring status, stated", [
  The jar lands in wave 2 of this book's build, so the sample's
  jar-free branch is what runs today: it prints the pinned
  coordinates and the exact command line it will run, and it never
  fakes a green line. When the jar appears, the same class compiles
  the `OkTests` source, runs `execute`, asserts the 5 successful
  count, asserts zero module warnings on 27, and asserts the exit 2
  no-tests path. The `assertThrows` and csv assertions in this
  chapter's hand-built lane already run green today.
])

== java 27 idioms, the wrap-up

Eighteen chapters in, the manual's working style is fixed. The java
8 habits and their replacements, in the order this book met them:

#diagram([java 8 habit on the left, java 27 idiom on the right], length: 13pt, {
  let rows = (
    ("anonymous inner class", "lambda, method reference, 8"),
    ("final buffered reader dance", "try-with-resources, effectively final since 9"),
    ("iterator loops", "streams and sequenced collections, 8 and 21"),
    ("null checks and instanceof casts", "pattern matching, 16 and 21"),
    ("hand written data classes", "records, 16"),
    ("if else chains on enums", "switch expressions, 14, sealed, 17"),
    ("escaped string concatenation", "text blocks, 15"),
    ("HttpURLConnection", "HttpClient, 11, HTTP/3 in 26"),
    ("thread pools for blocking io", "virtual threads, 21"),
    ("classpath as the only model", "modules where they pay, 9, imports 25"),
  )
  for (i, r) in rows.enumerate() {
    let y = 20 - i * 2.1
    cdraw.rect((0.5, y - 0.7), (8.6, y + 0.7), fill: luma(238), radius: 0.02)
    cdraw.rect((9.4, y - 0.7), (22.6, y + 0.7), fill: luma(228), radius: 0.02)
    cdraw.content((4.5, y), [#r.at(0)], size: 6pt)
    cdraw.content((16.0, y), [#r.at(1)], size: 6pt)
  }
  cdraw.content((4.5, 21.1), [the habit], size: 6.5pt)
  cdraw.content((16.0, 21.1), [the idiom], size: 6.5pt)
})

The two-line version of the whole manual: name what a thing is with
a record or a sealed hierarchy, move data with streams or channels,
block freely on a virtual thread, and let the compiler's warnings be
errors. The service spine that starts in chapter 19 holds this line
for thirteen chapters, and the suite in chapter 31 tests it with the
contract from this one.

#snippet("class Greeter {\n  private final String name;\n  Greeter(String name) { this.name = name; }\n  String greet() { return \"hello \" + name; }\n  // plus equals, hashCode, toString, getters\n}\n// versus, since 16:\nrecord Greeter(String name) {\n  String greet() { return \"hello \" + name; }\n}\n", lang: "java")

sources: repo1.maven.org/maven2/org/junit/platform/junit-platform-console-standalone
(the 6.1.3 version listed, dated 2026-08-07) and docs.junit.org/6.1.3
user guide, console launcher page (the execute subcommand, the option
set, the 0, 1, 2, 3 exit codes), both accessed 2026-10-04,
github.com/openjdk/jcstress for the concurrency torture tool the
contention style borrows, and book 3 of this corpus, chapter 6, for
the go race detector contrast. Behavior verified live on
`tools/jdk27/build/jdk-27` by the Ch18 samples under `pwsh
tools/run-java-samples.ps1 -Chapter Ch18`: 13 checks, OkContract 12
and JUnitLane 1, covering the assertThrows contract, the parameter
table, the barrier forced lost update, the atomic and monitor
exactness with timings, the latch choreography order, and the pinned
junit coordinates with the honest vendoring branch, all dated
2026-10-04.
