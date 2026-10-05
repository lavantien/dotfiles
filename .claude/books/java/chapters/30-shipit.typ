#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= ship it

The spine ends as a directory of tests unless it also ships. This
chapter turns the module into an artifact and a lane: the jlink recipe
that derives a custom runtime from the pinned jdk, the multi-stage
image that repeats the recipe on a pinned temurin 27 base, the compose
file that brings it up healthy on host ports 19380 and 19390, and the
make gate that replays the wire contract over that stack. Everything
leans on what the spine already built: the health route chapter 19
owns, the strong etags chapter 21 computes, the ops listener chapter
28 binds, the health probe class the load wave added. The go book
shipped the same service shape one idiom over, #xref-to("go",
"shipit"), and its chapter carries the platform envelopes, helm,
terraform, ci, as taught copies, which stay there: this chapter owns
the narrow band between a green module and a running container.

== what a java service ships as

A jar needs a java, and "install a jre" is a deployment dependency
the artifact can absorb. Chapter 15 built the machinery, jlink
assembles a runtime image from a module list, and the recipe here is
one script with the module list derived rather than hand-written:

#listing("java/api/deploy/jlink-image.ps1", first: 31, last: 46, caption: [jdeps answers what the module reads, jlink links exactly that plus the module itself])

The derived list is `java.base, java.net.http, jdk.httpserver,
jdk.jfr, javabook`: the kernel's server module, the load client's
http module, the observability event's recorder module, and the
module itself, nothing more. The derivation is the whole point, a new
`requires` in `module-info.java` rides the next build, while a
hand-written list silently ships a runtime that fails at startup with
a module not found. The recipe compiles fresh, links with stripped
debug and compressed modules, names one launcher after the module,
and states its own size, measured 32.8 MB of files on this machine
against the 370 MB of the pinned jdk 27 home it links from. The image
carries
`jfr.exe` because `jdk.jfr` brings its tool, and carries no `jcmd`,
which lives in `jdk.jcmd` and is not required, so a recording on the
shipped thing starts from outside the container, the operator's
machine, not from inside it.

== the image, two stages

The Dockerfile repeats the same recipe inside a pinned base, and the
runtime stage carries only the linked image:

#listing("java/api/Dockerfile", first: 1, last: 36, caption: [the whole image: temurin builder, jlink inside it, noble runtime, non-root])

Four decisions in the file earn their sentences. The builder is
`eclipse-temurin:27_35-jdk`, resolved 2026-10-05 at manifest digest
`sha256:2771efbbc159b89dc38b82ebe01312fd1b5f226071ff715ca9edd5411a389761`,
the temurin build 27+35 matching the repo's pinned jdk, so the image
links against the same bits the lane tests. The runtime is
`ubuntu:noble`, digest
`sha256:534baea6a22c03a63003dbc8dbe78fe34bc0d7e595d9a9dc9834884ff530eb55`,
because the temurin builder links against noble's glibc and a jlink
image is binaries, not a portable format, a bookworm base would be
smaller and wrong. The user is numeric, 65532, the same convention
the go lane's image set, so the platform and the image agree on who
runs the process without leaning on the base's user table. And `/data`
is created and
chowned in the builder then copied with its owner, because a named
volume inherits the image content's ownership on first mount and a
root-owned directory would deny the container user its store. The
built image measured 188 MB on this machine, 54.7 MB compressed, the
base's share included.

#diagram([two stages, two directories cross: the builder dies with the build, noble runs them], length: 13pt, {
  cdraw.rect((1.0, 6.2), (21.9, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.2), [eclipse-temurin:27_35-jdk builder], size: 6.5pt)
  cdraw.content((11.5, 7.3), [javac, jdeps, jlink, mkdir /data], size: 6pt)
  cdraw.content((11.5, 6.5), [the whole jdk, discarded at the end], size: 6pt)
  cdraw.line((11.5, 5.9), (11.5, 4.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 5.1), [two directories cross, /image and /data], size: 6pt)
  cdraw.rect((3.4, 1.2), (19.6, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 3.6), [ubuntu:noble runtime], size: 6.5pt)
  cdraw.content((11.5, 2.7), [the linked image, empty /data, user 65532], size: 6pt)
  cdraw.content((11.5, 1.8), [glibc matches, no jdk, no curl, no wget], size: 6pt)
})

The build context carries `src/` alone because a `.dockerignore`
trims the rest, and the rest matters here more than it did for the go
lane: `build/` can hold a whole linked runtime image from the recipe
above, 33 MB of context the builder would upload only to ignore, and
the captures, tests, and integration suite ride none of it into the
image. The go chapter chose no ignore file and stated the trade, this
one chooses the file because its build directory is not merely
sources.

== compose, one command

The compose file is one service and its volume, and the contract it
enforces is the return value of a single command. `docker compose up
-d --build --wait` builds the image, creates the container, starts it,
and blocks until the healthcheck passes, so a green up means the image
linked, the wal engine opened its directory, and both listeners
answer. `down -v` removes the volume in the same breath, so every lane
run starts from store zero:

#listing("java/api/compose.yml", first: 22, last: 43, caption: [the whole system: the env the wiring reads, both ports published, the probe the image runs])

The healthcheck is the load wave's `Health` class, the runtime's own
`java` running the module's probe against the app's own port. The
image carries no curl and no wget, and installing either would grow
the runtime for a diagnostic the module already knows how to run,
which is the same trade the go lane made when it gave its binary a
`-health` flag. The cadence is 5 seconds, measured against a probe
that boots a jvm in about 0.9 s inside the container: a 2 second
cadence would burn a third of a core just asking. The environment
block carries exactly
what construction demands: the secret present so authn signs with a
known key, the data directory on the volume, both ports pinned to the
lane's 19380 and 19390, and the shared budget raised to 100 so the
replay behind the healthcheck is not the limiter's subject, the same
knob the load chapter named, its default untouched. The migration
discipline of the store chapter holds unchanged, `docker compose up
-d` is the only command that touches the data, because the wal engine
applies its own log at startup.

== the docker lane as a gate

The lane is one make target, and its shape is the infrastructure
book's two-gate rule, #xref-to("infrastructure", "compose") owns the
compose depth and #xref-to("infrastructure", "containers") the pid 1
and signal story. The plain module lane never needs a daemon, and the
docker lane never runs silently, a missing daemon is a loud red with
the instruction to start it, never a skip:

#snippet(
  "verify-javaapi-docker:\n"
  + "\t@docker info >/dev/null 2>&1 || { echo \"docker daemon not reachable.\" >&2; exit 1; }\n"
  + "\t@cd books/java/api && docker compose down -v >/dev/null 2>&1 || true && \\\n"
  + "\t\ttrap 'docker compose down -v' EXIT && \\\n"
  + "\t\tdocker compose up -d --build --wait && \\\n"
  + "\t\t<compile src and integration under the pinned jdk, then the junit console\n"
  + "\t\t over --select-package javabook.it with JBAPI_URL and JBAPI_METRICS_URL set>",
  lang: "makefile",
)

The suite lives outside the plain junit scan path, `integration/`
instead of `test/`, so `--scan-classpath` in the ordinary lane never
sees it and only the docker target compiles and runs it. Its tests
replay the contract over the real listener with a real clock and real
uuids, the statuses, the header relations, and the byte-identical
guarantees that must survive all three. The etag check is the sharpest
one, recomputed over the wire bytes:

#listing("java/api/integration/javabook/it/IntegrationTests.java", first: 113, last: 121, caption: [the strong etag rule recomputed over live bytes, not frozen ones])

Five tests cover the scenarios the contract names. Health and routing
pins both probes and the two routing envelopes, including the 405
carrying the not_found code plus an Allow header. Register and login
walks the 201 with Location and the sha256 etag, the 409 the same
email answers, which is this contract's replay answer where the go
contract's idempotency key replayed the stored snapshot, the login
pair with the two 401 shapes that must not differ enough to enumerate
accounts, and the owner's read with its etag. The patch duel releases
2 concurrent patches on one If-Match and demands exactly one 200 and
one 412, then a 304 off the fresh etag and a stale 412:

#listing("java/api/integration/javabook/it/IntegrationTests.java", first: 209, last: 231, caption: [the duel over the wire: one latch, 2 virtual-thread patchers, the collector concurrent])

The remaining 2 are the exposition, read off the ops port the wired
service binds it to, both series present with the route label the
pattern table produces, and the budget drain, ordered last because it
spends the shared per-address budget down to zero on purpose, the
429's envelope and its Retry-After asserted at the status the limiter
really wrote.

#diagram([the gate: preflight, compose, replay, teardown, no skips], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.5), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.6), sub, size: 6pt)
  }
  box(0.8, 3.8, [preflight], [docker info or loud red])
  box(5.2, 4.2, [compose up], [build, wait for health])
  box(9.9, 4.2, [the replay], [5 tests on 19380, 19390])
  box(14.6, 3.8, [trap fires], [down -v on any exit])
  cdraw.line((4.7, 6.0), (5.1, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.5, 6.0), (9.8, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.2, 6.0), (14.5, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.6), [the plain junit scan never sees integration/], size: 6pt)
  cdraw.content((11.5, 2.7), [the lane target sits outside make verify on purpose], size: 6pt)
})

== the shipped checklist

The ship lane ends where it started, with the property each spine
chapter contributed, every row a behavior the lane or the module gate
observes and names where it is proven:

#diagram([the readiness table: twelve chapters, twelve properties, all proven], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [19 kernel: one envelope], [on every failure, over the wire])
  cell(17.1, 8.3, 10.0, [20 middleware: recover], [a panic never escapes])
  cell(5.9, 6.9, 10.0, [21 users: strong etags], [plus keyset pagination])
  cell(17.1, 6.9, 10.0, [22 authn: hmac jwt], [one 401 shape, pbkdf2 seam])
  cell(5.9, 5.5, 10.0, [23 authz: deny default], [owner checks, last admin])
  cell(17.1, 5.5, 10.0, [24 store: wal engine], [recovery, compaction])
  cell(5.9, 4.1, 10.0, [25 conc: admission], [the 503 at the cap])
  cell(17.1, 4.1, 10.0, [26 cache: single flight], [one fill under a stampede])
  cell(5.9, 2.7, 10.0, [27 limit: token bucket], [429 with Retry-After])
  cell(17.1, 2.7, 10.0, [28 obs: two series], [ops port, the jfr event])
  cell(5.9, 1.3, 10.0, [29 load: the ladder], [captures, honest p99])
  cell(17.1, 1.3, 10.0, [30 ship: the lane], [image, compose, replay])
})

The chapter also declares what it does not teach again. Docker's
storage model, the container runtime, and networking are the
infrastructure book's chapters, the compose internals and the
one-click philosophy are #xref-to("infrastructure", "compose"), and
the migration discipline the wal log rides is the store chapter's own.
The cloud side stays with the go book's ship chapter, whose helm chart
and terraform slice are the same service's platform envelopes taught
line by line, and a java copy of them would be the same files wearing
a new name. What this chapter owns is the band between a green module
and a running service, and the band is small enough to read in a
sitting and boring enough to trust.

sources: docker docs on multi-stage builds and `docker compose up
--wait` semantics, at docs.docker.com, accessed 2026-10-05. The
eclipse-temurin and ubuntu tag listings and digests read from
hub.docker.com's registry api on 2026-10-05, recorded in the
Dockerfile's header comment. The jlink and jdeps tool pages at
docs.oracle.com/en/java/javase/27, same access date, run against
tools/jdk27/build/jdk-27, build 27+35-2325. Verified live 2026-10-05:
the jlink recipe run end to end on this machine (32.8 MB of files,
the boot, the probe, and the exposition all checked against the linked
image before the Dockerfile repeated it), and `make
verify-javaapi-docker` green 3 consecutive runs, the compose stack
healthy on 19380 and 19390, 5 integration tests green each run, the
down -v trap observed firing on both the passing and a deliberately
broken early exit.
