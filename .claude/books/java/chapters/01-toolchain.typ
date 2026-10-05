#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= toolchain and the jdk

Java arrives as one download, the jdk, and everything this book does
runs on the six programs its `bin` directory puts on the path: `javac`,
`java`, `jshell`, `jar`, `jlink`, and `jdeps`. There is no second
package manager, no project file format, no build daemon. The book pins
oracle jdk 27, the ga build `27+35-2325` released 2026-09-15, and every
sample lives under `books/java/samples/src` in the default package,
one public class per file, compiled and run by that jdk alone.

27 is a feature release, not an lts one. The current lts is 25 (ga
2025-09-16), 21 before it, and oracle intends future lts releases every
two years, so 29 lands september 2027. Chapter 2 walks the whole ladder
from java 8 to here. This chapter owns the toolchain that the ladder's
top rung hands you.

== the pin

The machine this repo builds on has jdk 26.0.2 installed, so the book
does not trust the machine. `tools/build-jdk27.sh` fetches the oracle
archive zip, gates it on a sha256, and unpacks it into
`tools/jdk27/build/jdk-27`:

#snippet(
  "url=\"https://download.oracle.com/java/27/archive/jdk-27_windows-x64_bin.zip\"\n"
  + "sha=c75756490b95f44db07a21d4491b712399107d50fc041c2ecf0a6848662bfbd7\n"
  + "unzip -q -o jdk-27.zip -d tools/jdk27/build\n",
  lang: "sh",
)

A fresh clone is red until that script runs, by design and loudly: the
sample runner prints the missing path and the command that builds it
rather than silently falling back to whatever `java` happens to resolve
to. Pinned bytes or no build is the repo's law for vendored tooling,
the same stance #xref-to("go", "toolchain") takes when it refuses to
compile samples against anything but the module's declared version.

#diagram([the hermetic chain, from oracle archive to make verify-java], length: 13pt, {
  // left to right: fetch, gate, unpack, override, run
  let stages = (
    ([oracle archive #linebreak() jdk-27_windows-x64_bin.zip], [curl]),
    ([sha256 gate #linebreak() c7575...fbd7], [exact match or stop]),
    ([tools/jdk27/build/jdk-27 #linebreak() gitignored], [unzip]),
    ([JAVA_HOME override #linebreak() machine jdk 26.0.2 never runs], [pwsh runner]),
    ([make verify-java #linebreak() compile, run, count], []),
  )
  for (i, st) in stages.enumerate() {
    let x = i * 4.7
    cdraw.rect((x, 2.6), (x + 4.1, 4.6), fill: luma(235), radius: 0.02)
    cdraw.content((x + 2.05, 4.15), st.at(0), size: 5.6pt)
    if st.at(1) != [] {
      cdraw.content((x + 2.05, 3.0), st.at(1), size: 6pt)
    }
    if i < stages.len() - 1 {
      cdraw.line((x + 4.1, 3.6), (x + 4.7, 3.6), stroke: luma(100), mark: (end: ">"))
    }
  }
})

The sample that states the pin's identity is 33 lines and answers every
version question a chapter might raise. Its checks ran green before this
paragraph was written:

#listing("java/samples/src/Ch01/Version.java", first: 15, last: 33, caption: [the pinned jdk describes itself, eight machine checked facts])

`java.version` is `27` exactly, `java.vm.version` carries the build
`27+35-2325`, the vm is hotspot, the runtime is oracle se, and
`Runtime.version().feature()` reads 27, the same call the ladder chapter
asserts on. The last two checks spawn work on a virtual thread executor
and read the thread's id and `isVirtual`, which pins the concurrency
story of chapter 10 to measured facts on day one.

== the whole toolchain

Six programs, and all six answer `--version` with 27 on this build,
measured 2026-10-04:

#table(
  columns: (auto, 1fr, auto),
  inset: 4pt,
  table.header([*program*], [*role*], [*first seen*]),
  [`javac`], [compiles source to class files, the book's every build], [1.0],
  [`java`], [runs class files, and since 11 launches `.java` source directly], [1.0],
  [`jshell`], [read eval print loop, one expression at a time], [9],
  [`jar`], [packages class files and resources into the archive format], [1.0],
  [`jlink`], [assembles modules into a trimmed runtime image], [9],
  [`jdeps`], [reads class dependencies, the input jlink works from], [8],
)

#callout("note", "no gradle, no maven, no dependencies", [
  This book compiles everything with `javac` and runs everything with
  `java`, and no sample links a library outside the jdk. Two reasons.
  The platform under a build tool is still the platform: the class file
  model, the module path, and the launcher are what those tools wrap, so
  the book teaches the layer that survives fashion. And the service
  part of chapters 19 through 31 genuinely needs nothing more, the jdk
  ships an http server, a json tokenizer, a websocket client, and the
  cryptography the service part uses. When chapter 18 needs a test framework,
  it vendors one jar behind a sha256 and nothing else.
])

The module-aware half of that table earns its keep in chapter 15, but
two measured facts belong here. The full jdk lists 66 modules, and an
ordinary classpath program resolves 61 of them into its boot layer.
`java.se`, the aggregate module covering the whole specification, is
not among the resolved: aggregation is opt in, `jshell --add-modules`
or a jlink image asks for it explicitly, and jlink in 27 refuses to
guess, it errors on a missing `--add-modules` rather than defaulting
the image to `java.se`.

== run without ceremony

Since java 11 the launcher compiles for you. `java Hello.java` reads
the source, compiles in memory, and runs, no `javac` step and no class
file left behind. Java 22 widened it to multi file programs, JEP 458:
the launcher follows source imports from the entry file and compiles
the graph. The book's runner still uses `javac` explicitly, because
the `-Xlint:all -Werror` discipline below is a compile time contract,
but for a single file nothing beats it:

#snippet(
  "$ java HttpV.java\n"
  + "[HTTP_1_1, HTTP_2, HTTP_3]\n",
  lang: "sh",
)

Java 25 removed the last of the boilerplate, JEP 512's compact source
files. A source file may declare no class at all, the launcher wraps
the statements in an implicit one, `main` becomes an instance method
with whatever parameter list it wants, and a simple `IO` class handles
console output. The pinned build runs this verbatim, measured
2026-10-04:

#snippet(
  "void main() {\n"
  + "  IO.println(\"implicit class, instance main, jdk \" + Runtime.version().feature());\n"
  + "}\n",
  lang: "java",
)

The file can be named anything, `greet.java` lower case and mismatched
is fine, because a compact source file is not declaring a public type
the launcher has to find by name. This is the shape of every quick
probe in this book: the chapter states a claim, a compact source file
or a jshell session checks it, and the claim carries the date. The
`Version` sample above stays in the classical shape, one public class
matching its filename, because the sample suite compiles whole
directories with `javac` and that contract wants declared types.

jshell is the other probe surface, an instantaneous check for a
one line question:

#snippet(
  "$ jshell\n"
  + "|  Welcome to JShell -- Version 27\n"
  + "jshell> java.util.List.of(1, 2, 3).reversed()\n"
  + "$1 ==> [3, 2, 1]\n",
  lang: "sh",
)

One measured wrinkle from this build: jshell's default execution runs
through a remote agent and resolves everything this book needs, but
`--execution local` failed to load nested enum classes like
`HttpClient$Version` with a `ClassNotFoundException`. The flag looks
like a performance win and is not one. The default agent is the mode the
probes in this book ran under.

== the compile discipline

Every sample in the book compiles under
`javac -Xlint:all -Werror`. The first flag turns every lint on,
raw types, unchecked calls, serialization, reflection on internals.
The second turns warnings into errors, so the suite never ships with
a yellow compile. Measured on this build 2026-10-04, a four line class
using a raw `List` produces three warnings, and with `-Werror`:

#snippet(
  "error: warnings found and -Werror specified\n"
  + "1 error\n"
  + "3 warnings\n",
  lang: "text",
)

Exit code 1, no class file. The same source without `-Werror` compiles
clean with three warnings scrolling past, which is exactly the failure
mode the flag exists to prevent: warning fatigue normalizes the noise
until the real one is missed. Chapters justify the rare suppression
inline with a scoped `@SuppressWarnings` and a comment, never a file
wide silence.

== the runner

`tools/run-java-samples.ps1` is the whole harness. It resolves the
pinned jdk, exports `JAVA_HOME` over it, walks every `ChNN` directory
under `books/java/samples/src`, compiles each directory as one unit
under the lint discipline, runs every class with a `main`, and counts
`ok N name` lines:

#listing("java/samples/src/Ch01/Version.java", first: 4, last: 13, caption: [the ok helper, the corpus contract every sample embeds])

A check that fails prints `FAIL` to stderr and exits 1, which the
runner turns red. A class that prints no `ok` lines is equally red:
silence is not success. The count is the book's unit of verification,
the same contract the c and python sample runners use, so
`Ch01/Version 8 checks` and `Ch02/Ladder 19 checks` are comparable
statements. `pwsh tools/run-java-samples.ps1 -Chapter ChNN` scopes a
run to one chapter while iterating, and `make verify-java` runs the
whole lane inside `make verify`.

== the tests, vendored once

The sample suite proves the platform claims. The test chapter, 18,
needs a real framework, and its discipline belongs here because it is
a toolchain decision: the book vendors
`junit-platform-console-standalone 6.1.3`, one jar, sha256
`e62b96ac475dbcde8599ea905d088f65d90778f86e259b856a49fa5c4ea256ec`,
behind the same gate the jdk zip sits behind. The standalone jar is
subcommand shaped, 6.x dropped the bare flag style of the 1.x era:

#snippet(
  "java -jar junit-platform-console-standalone-6.1.3.jar \\\n"
  + "  execute --select-class books.java.suite.Ch18Tests\n"
  + "exit 0: green, 1: failing tests, 2: the run never happened\n",
  lang: "sh",
)

Test classes take the `*Tests` suffix so `--select-class` never points
at a helper, and the exit codes are the whole ci contract: 0 green,
1 red, 2 for a discovery or usage failure that produced no verdict at
all. Chapter 18 builds the suite. Nothing before it needs the jar.

== the checks that gate every commit

A chapter is prose over evidence, and the repo gates the evidence.
Every listing in this book is a live slice of a real sample file, read
at compile time, so the pdf cannot drift from the code it quotes:
`check-listings` hashes each pinned line range into `pins.lock.json`
and fails when a source edit moves a slice. `check-headings` fails a
chapter with two level 1 titles, `check-figures` rasterizes every
figure page and fails ink in the guard band, and the harmony floor
holds the book to the corpus word count. All of it rides in one
target:

#flow(
  [the commit gate: pinned jdk, lint discipline, ok counts, listing pins, heading and figure checks, one pipeline into make verify],
  node((0, 0), [javac]),
  edge((0, 0), (1.6, 0), "-|>"),
  node((1.6, 0), [ok counts]),
  edge((1.6, 0), (3.2, 0), "-|>"),
  node((3.2, 0), [pins]),
  edge((3.2, 0), (4.8, 0), "-|>"),
  node((4.8, 0), [headings]),
  edge((4.8, 0), (6.4, 0), "-|>"),
  node((6.4, 0), [verify-java]),
)

#callout("verify", "the claim discipline for this book", [
  Every chapter ends with a sources line naming the pages it was
  written against and the date each was fetched. Behavior claims carry
  a measurement: which sample check or which jshell probe answered the
  question on the pinned build. When something could not be verified,
  the chapter says so instead of guessing.
])

sources: openjdk.org jdk 27 project page, ga 2026-09-15 and the jep
list, accessed 2026-10-04. oracle java se support roadmap, lts cadence
and the 29 in september 2027 note, accessed 2026-10-04. Toolchain
behavior verified live on `tools/jdk27/build/jdk-27` measured
2026-10-04: the Version sample's 8 checks under
`pwsh tools/run-java-samples.ps1 -Chapter Ch01`, `javac java jshell
jar jlink jdeps --version` all printing 27, `java greet.java` running
the compact source form above, `java HttpV.java` printing the
HttpClient version enum, `java -XX:+PrintFlagsFinal -version` for the
flag table, the raw type class failing under `-Werror`, jshell
resolving `List.of(1, 2, 3).reversed()` under the default execution
and failing `HttpClient$Version` under `--execution local`,
`java --list-modules` counting 66, and the classpath boot layer
counting 61. The junit console jar's subcommand shape and exit codes
are the wave's measured facts, recorded 2026-10-04 for chapter 18.
