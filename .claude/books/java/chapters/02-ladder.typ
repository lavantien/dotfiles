#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= from java 8 to java 27

Every feature in this book carries the release that shipped it: "var
infers since 10", "records arrived final in 16", "virtual threads went
final in 21". This chapter is where those numbers come from. Twenty
releases run from the java 8 floor most production fleets still stand
on to the 27 this book pins, and the road divides cleanly into three
eras: java 8 alone, the module decade of 9 through 17, and the cadence
era of 18 through 27 where a release lands every march and september
and only some are lts.

#diagram([twenty releases, three eras, five of them lts with 29 pending], length: 13pt, {
  // one bar per era, width by release count, the lts years ringed
  let eras = (
    ([java 8 #linebreak() 2014], 3.6, luma(205)),
    ([9 to 17 #linebreak() 2017 to 2021], 8.2, luma(230)),
    ([18 to 27 #linebreak() 2022 to 2026], 9.8, luma(245)),
  )
  let x = 0.4
  for (label, w, fill) in eras {
    cdraw.rect((x, 3.2), (x + w, 4.8), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, 4.0), label, size: 6pt)
    x += w + 0.6
  }
  cdraw.line((0.4, 2.6), (22.0, 2.6), stroke: luma(100), mark: (end: ">>"))
  let mark(rel, x, lts) = {
    cdraw.line((x, 2.6), (x, 3.0), stroke: luma(100))
    cdraw.content((x, 1.9), rel, size: 6pt)
    if lts {
      cdraw.circle((x, 2.6), radius: 0.28, stroke: luma(60))
    }
  }
  mark([8], 2.2, true)
  mark([11], 8.7, true)
  mark([17], 12.4, true)
  mark([21], 15.4, true)
  mark([25], 18.7, true)
  mark([27], 21.6, false)
  cdraw.content((11.0, 0.4), [ringed: lts. 8 declared retroactively, 29 rings in september 2027], size: 6pt)
})

The chapter reads top down: the eras, one row per release, then the lts
story, the one withdrawal, the preview machinery, and a worked
migration that carries one domain from 2007 idioms to a form no
earlier release compiles.

== java 8, the floor

Java 8 (march 2014) rewrote the working style of the language in one
release: lambda expressions, method references, and the stream
pipeline over the collections, `Optional` as the explicit maybe, the
`java.time` date and time api that succeeded joda time, default methods
that let interfaces grow, and `CompletableFuture` for composable
async. Nothing before it matters to a reader starting today except as
history, and a great deal of the world still runs on it: the module
transition was expensive enough that 8 was declared lts after the
fact, and shops that skipped 9 through 17 built a decade of muscle
memory on 8 lambdas and 8 streams.

That floor is why this book starts its ladder there rather than at 1.0.
The 8 programmer already knows the lambda arrow and the stream
pipeline. Everything after is: better type inference (10), better data
carriers (16), closed hierarchies (17), pattern matching (16 through
21), and a concurrency model that finally matches the promise (19
through 21).

== the module decade, 9 through 17

Java 9 arrived 3.5 years after 8 with project jigsaw, the platform
module system that reorganized the jdk itself into modules, put every
class behind a named module with exports, and encapsulated the
internal sun APIs frameworks had reached into for years. It also
brought `jshell` and the collection factory methods, made G1 the
default collector, and replaced the version string scheme. The
adoption pain was real, so the era's story is the industry parking on
11 while the language work continued underneath: the Amber features
(`var`, switch expressions, text blocks, records, sealed types,
pattern matching) each previewed in an interim release and finalized
in time for an lts landing.

#table(
  columns: (auto, 1fr, 1fr, 1fr),
  inset: 4pt,
  table.header([*release*], [*language*], [*platform*], [*remembered for*]),
  [9, 2017-09],
  [module declarations, jigsaw syntax, the ten contextual keywords (`module`, `open`, `requires`, `transitive`, `exports`, `opens`, `to`, `uses`, `provides`, `with`)],
  [JPMS, jshell, collection factories, G1 default, compact strings],
  [the jdk restructured, internal apis closed],
  [10, 2018-03],
  [`var` for locals],
  [time-based versioning, parallel full GC in G1, root certificates],
  [first six month release, `var`],
  [11 lts, 2018-09],
  [`var` in lambda parameters],
  [HttpClient standard, single-file launch, Java EE and CORBA modules removed, TLS 1.3, Flight Recorder, ZGC experimental],
  [the lts the 9 skippers waited for],
  [12, 2019-03],
  [switch expressions preview],
  [Shenandoah experimental, microbenchmark suite, default CDS archives],
  [Amber's first preview],
  [13, 2019-09],
  [text blocks preview, switch second preview],
  [ZGC uncommits memory, legacy socket api reimplemented],
  [text blocks arrive],
  [14, 2020-03],
  [switch expressions final, records preview, instanceof patterns preview],
  [helpful NullPointerExceptions, CMS removed],
  [NPEs that name the variable],
  [15, 2020-09],
  [text blocks final, sealed classes preview],
  [ZGC and Shenandoah production, hidden classes, Nashorn removed],
  [the low pause collectors go production],
  [16, 2021-03],
  [records final, instanceof patterns final],
  [strong encapsulation by default, vector api incubator, development moves to github],
  [records day],
  [17 lts, 2021-09],
  [sealed classes final, switch patterns preview],
  [foreign function and memory incubator, macOS aarch64, security manager deprecated],
  [the lts that emptied java 8],
)

The era's grammar: a feature previews in one or two interim releases,
finalizes in the next lts or the one after, and the lts rows above are
where the industry actually met it.

== the cadence era, 18 through 27

After 17 the cadence settled into culture. Every release ships in
march or september, previews graduate on their own clock, and from 17
onward an lts lands every two years: 21 in 2023, 25 in 2025, 29
planned for september 2027. The language work
converged on pattern matching and data oriented programming while
Loom's concurrency went preview in 19, second preview in 20, final in
21. Panama's foreign function and memory api took longer, incubating
from 14 through 17, previewing from 19, final in 22.

#table(
  columns: (auto, 1fr, 1fr, 1fr),
  inset: 4pt,
  table.header([*release*], [*language*], [*platform*], [*remembered for*]),
  [18, 2022-03],
  [switch patterns second preview],
  [UTF-8 the default charset, simple web server, finalization deprecated],
  [the charset default flips],
  [19, 2022-09],
  [virtual threads preview, record patterns preview, switch patterns third preview],
  [structured concurrency incubator, RISC-V port],
  [Loom's debut],
  [20, 2023-03],
  [second previews: record patterns, switch patterns, virtual threads],
  [scoped values incubator, all seven JEPs preview or incubator],
  [the all preview release],
  [21 lts, 2023-09],
  [record patterns final, switch patterns final, string templates preview],
  [virtual threads final, sequenced collections, generational ZGC, key encapsulation api],
  [virtual threads for everyone],
  [22, 2024-03],
  [unnamed variables final, statements before `super()` preview],
  [foreign function and memory final, multi-file source launch, stream gatherers preview],
  [the underscore returns as a discard],
  [23, 2024-09],
  [markdown doc comments, module import declarations preview, implicit classes third preview],
  [ZGC generational by default, sun.misc.Unsafe memory access deprecated],
  [markdown javadoc, string templates withdrawn],
  [24, 2025-03],
  [primitive patterns second preview, flexible constructor bodies third preview],
  [stream gatherers final, class-file api final, compact object headers experimental, virtual threads stop pinning, security manager disabled, ML-KEM and ML-DSA],
  [synchronized virtual threads],
  [25 lts, 2025-09],
  [compact source files final, module imports final, flexible constructor bodies final, scoped values final],
  [compact object headers opt-in, AOT class caching and method profiles, generational Shenandoah],
  [the simple java lts],
  [26, 2026-03],
  [structured concurrency sixth preview, lazy constants second preview],
  [HTTP/3 in the client, prepare to make final mean final, applet api removed, AOT object caching with any GC],
  [HTTP/3, final hygiene],
  [27, 2026-09],
  [structured concurrency seventh preview, primitive patterns fifth preview, lazy constants third preview],
  [G1 the default in all environments, post-quantum TLS by default, compact object headers by default, JFR data redaction],
  [the footprint and crypto release, this book's pin],
)

Chapter 1 measured this build against the 27 row: the HttpClient
version enum reads `HTTP_1_1, HTTP_2, HTTP_3`, and
`java -XX:+PrintFlagsFinal -version` shows `UseCompactObjectHeaders =
true` as a default, the flag 24 introduced experimentally and 25 made
opt-in.

== the lts ladder

The lts badge is a vendor promise, not a language property: openjdk
ships every release, and the vendors choose which ones they will patch
for years. In practice the line is unambiguous. Java 8 was declared lts
retroactively when the module transition proved expensive, 11 was the
first planned one on the three year cadence, and from 17 onward oracle
has committed to a new lts every two years, so 21 and 25 followed at
two year intervals and 29 comes in september 2027.

#diagram([the lts ladder, years on the x axis, one rung per supported line], length: 13pt, {
  // one rung per lts, spaced by release year, 29 dashed as planned
  let rungs = (
    ([8, 2014 #linebreak() retroactive], 2014, true),
    ([11, 2018], 2018, true),
    ([17, 2021], 2021, true),
    ([21, 2023], 2023, true),
    ([25, 2025 #linebreak() current], 2025, true),
    ([29, 2027 #linebreak() planned], 2027, false),
  )
  let x-of = (year) => (year - 2014) * 1.55 + 1.2
  for (label, year, solid) in rungs {
    let x = x-of(year)
    cdraw.line((x, 1.2), (x, 4.4), stroke: if solid { luma(100) } else { (paint: luma(100), dash: "dashed") })
    cdraw.content((x, 5.1), label, size: 6pt)
  }
  cdraw.line((0.4, 1.2), (12.4, 1.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.0, 0.2), [the three year gap from 11 to 17, two year gaps since, #linebreak() this book rides the 27 feature release on top of the 25 lts line], size: 6pt)
})

This book rides a feature release, 27, rather than the current lts, 25.
The two differ by the table's last two rows, and chapter 1's pin makes
the choice safe: the samples prove on the exact ga build every claim
the chapters make. A team building this book's service part for
production deployment would run the same code on 25 with two rows of
preview features subtracted, nothing the service part uses.

== withdrawn: string templates

The cadence has one full withdrawal on its record. String templates,
the `STR."hello \{name}"` interpolation form, previewed in 21 as JEP
430 and re-previewed in 22 as JEP 459. The third preview, JEP 465, was
pulled before 23 shipped: the design's template processor model and
the `\{}` embedding did not sit right after two rounds of real use,
and the Amber group chose withdrawal over iteration. Java 23 contains
no string templates, and code that used the preview had to be
rewritten. Interpolation may return in another shape, no JEP carries
it today.

#callout("note", "what withdrawal teaches", [
  A preview feature is a live experiment on real codebases, and the
  contract runs both ways. Users accept churn, and in exchange the
  platform accepts the possibility of saying: this design was wrong,
  it is gone. String templates are the one time since the cadence
  began that the platform spent that option on a language feature.
])

== preview versus final

The ladder tables above say "preview" often enough that the word needs
precise meaning. A preview language feature compiles and runs only
with `--enable-preview` on both `javac` and `java`, and the class
files it produces are stamped for that exact release: 21's preview
class files do not run on 22, the code must recompile against each new
release. An incubator api is one step earlier, a module named
`jdk.incubator.something` that the classpath does not see until
`--add-modules` asks for it, and incubator apis may change shape
outright between releases. The foreign memory api lived that life for
eight releases before finalizing as `java.lang.foreign` in 22.

This book's marking follows the platform's: a feature is taught as
working code only when final, previews appear in prose and in the
tables with their preview release named, and the sample suite compiles
without `--enable-preview` entirely. The one nuance worth knowing:
"final" acquired teeth in 26, when JEP 500 began making final mean
final, closing the reflective writes to final fields that frameworks
had abused for years.

== the migration, worked

One domain, weather readings off three stations, carried from the
idioms a 2007 codebase would use to the 27 form, each step naming its
release. The sample asserts the whole way down that the forms agree.

The 2007 form hand rolls the function types guava shipped and the
loops everyone wrote, over a data carrier class with fields, a
constructor, getters, and no equals:

#listing("java/samples/src/Ch02/Migration.java", first: 17, last: 34, caption: [the pre-lambda world, a 10 line carrier plus one interface per arity])

#listing("java/samples/src/Ch02/Migration.java", first: 46, last: 72, caption: [anonymous classes at every use site, an explicit accumulator loop, an anonymous comparator])

Lambda expressions (8) delete the shim and the anonymous class
ceremony, and streams (8) move the loop into the pipeline. Then `var`
(10) stops restating the type the right hand side already states.
Records (16) collapse the carrier to a signature, with equals and
hashCode generated, and `Stream.toList` (16) finishes the pipeline.
Sealing (17) closes the hierarchy, which is what lets the pattern
switch (21) be exhaustive with no default arm. Text blocks (15) hold
the expected output. The virtual thread executor (21) replaces the
fixed pool the java 5 era would have sized by hand:

#listing("java/samples/src/Ch02/Migration.java", first: 74, last: 87, caption: [the 27 form, sealed plus records plus pattern switch, the whole pipeline])

#listing("java/samples/src/Ch02/Migration.java", first: 98, last: 120, caption: [text block expectations, equivalence, and one virtual thread per reading])

The equivalence check is the migration's contract: the 2007 form and
the 27 form render the same three lines, and rendering them again
spread over virtual threads still does. The 27 form is clearer because
the domain is visible in it, and the collapse from 13 lines of carrier
and shim to 6 lines of sealed hierarchy is the decade in one number.

== the ladder, asserted

The ladder chapter closes by running itself. `Ladder` opens with
`import module java.base` (25) and asserts one rung at a time, every
check naming its release, 19 checks green on the pinned build
2026-10-04:

#listing("java/samples/src/Ch02/Ladder.java", first: 48, last: 73, caption: [rungs 9 through 15, modules, factories, var, strip, HttpClient, switch expressions, text blocks])

#listing("java/samples/src/Ch02/Ladder.java", first: 74, last: 96, caption: [rungs 16 through 22, records, sealed, the 21 cluster, the underscore, java.lang.foreign])

#listing("java/samples/src/Ch02/Ladder.java", first: 97, last: 109, caption: [rungs 25 through 27, scoped values, flexible constructors, module imports, HTTP/3])

Two rungs are stated rather than asserted because they are launcher
and flag facts, not classpath facts: compact source files with the
instance main need `java file.java` not `javac`, which chapter 1
demonstrated on `greet.java`, and compact object headers are a VM flag
default, `UseCompactObjectHeaders = true`, measured on this build via
`-XX:+PrintFlagsFinal`. The 61 module boot layer and the 66 module jdk
counts in chapter 1 are this chapter's module rung, restated.

sources: openjdk.org per release project pages, jdk9 through jdk27,
feature lists and GA dates, all accessed 2026-10-04. oracle java se
support roadmap via search summary, the lts every two years intent
and the 29 in september 2027, accessed 2026-10-04. javaalmanac.io and
the withdrawn JEP 465 page, string templates previewed 21, re-previewed
22, withdrawn before 23, accessed 2026-10-04. Java in a nutshell 8th
edition, the brief history section (print pages 16 to 18) and the
beyond java 17 appendix (print pages 431 to 434), read from ref/java
via pdftotext, used for the era shape and rewritten here. The ladder
sample and migration sample verified live under
`pwsh tools/run-java-samples.ps1 -Chapter Ch02`, 22 checks, and the
`UseCompactObjectHeaders` and `HttpClient.Version` facts measured on
tools/jdk27/build/jdk-27, 2026-10-04.
