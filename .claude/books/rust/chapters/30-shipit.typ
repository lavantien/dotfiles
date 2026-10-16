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
chapter turns the crate into an artifact and a lane: `deploy.rs`,
the ship facts held as data so tests can hold the files to them, the
multi-stage image with a digest-pinned builder and a non-root
runtime, the compose file that brings it up healthy on host ports
19580 and 19590, the `--health` flag the healthcheck drives, and the
make gate that replays the wire contract over that stack in the next
chapter. Everything leans on what the spine already built: the health
route chapter 19 owns, the ops listener chapter 28 binds, the load
client chapter 29 probes with. The go book shipped the same service
shape and carried the platform envelopes, helm, terraform, ci, as
taught copies, #xref-to("go", "shipit"), and the java book derived a
jlink runtime from the pinned jdk, #xref-to("java", "shipit"): a
rust service ships one statically honest binary and no runtime to
derive, which makes this the narrowest ship chapter of the three.

== the ship as data

Digests, dates, uid, ports, and build flags live once, in a module,
not in a comment a file can outlive:

#listing("rust/api/src/deploy.rs", first: 1, last: 12, caption: [the ship: both image refs at their manifest digests with resolved dates, the uid, the paths, the build flags])

#listing("rust/api/src/deploy.rs", first: 27, last: 39, caption: [the whole story as one value, the single place a chapter or a test reads it from])

The builder is `rust:1.99` resolved 2026-10-14 at manifest digest
`sha256:81015672...edc90`, and the pin is stronger than it looks:
the manifest list fixes the exact builder image whose `rustc`
reports 1.99.0 `(b940084d7 2026-09-28)`, the same build the lane's
every gate asserts, so the image compiles with the bits the tests
ran on or not at all. The runtime is `debian:trixie-slim`, resolved
the same day at `sha256:a29215f6...f11f`, and trixie is not a
preference: `rust:1.99` was measured to ride debian 13 trixie,
`/etc/os-release` read inside the pulled image on 2026-10-14, so
the binary links against trixie's glibc and a bookworm-slim runtime,
one debian older, would be smaller and unable to load it. A pin is
only a pin if it is checked:

#listing("rust/api/src/deploy.rs", first: 41, last: 53, caption: [a reference earns its pin: name, sha256, 64 lowercase hex, five negative vectors in the test])

The deploy tests hold the tree to these values: the `Dockerfile`'s
two `FROM` lines parse, through `from_ref`, to exactly the two
constants, the compose file maps the lane's ports and probes with
the flag, and the `.dockerignore` keeps the build cache out of the
context, so the story cannot drift from the ship.

== the image, two stages

#listing("rust/api/Dockerfile", first: 1, last: 15, caption: [the whole image: pinned builder, offline locked release build, trixie runtime, non-root, both ports])

Four decisions in the file earn their sentences. The build is
offline and locked, `CARGO_NET_OFFLINE=true` and `--locked`, the
zero-dep law carried into the image: the lock holds exactly one
package, nothing vendors, nothing resolves from the network, and a
`--locked` build that drifts from the lock fails loudly instead of
quietly updating it. The runtime copies one file, the release
binary, measured 2026-10-15 at a 1.22 MB layer on this machine,
against a 119 MB image whose remainder is the trixie base, so the
shipped thing is one executable and a libc. The user is numeric, 65532, the
same convention both siblings set, so the platform and the image
agree on who runs the process without leaning on the base's user
table. And `/data` is created and chowned in the builder then copied
with its owner, because a named volume inherits the image content's
ownership on first mount and a root-owned directory would deny the
container user its wal store.

#diagram([two stages, two directories cross: the builder dies with the build, trixie runs them], length: 13pt, {
  cdraw.rect((1.0, 6.2), (21.9, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.2), [rust:1.99 builder, digest-pinned], size: 6.5pt)
  cdraw.content((11.5, 7.3), [cargo build --locked --release --bin rustapi], size: 6pt)
  cdraw.content((11.5, 6.5), [the whole toolchain, discarded at the end], size: 6pt)
  cdraw.line((11.5, 5.9), (11.5, 4.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 5.1), [two directories cross, /rustapi and /data], size: 6pt)
  cdraw.rect((3.4, 1.2), (19.6, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 3.6), [debian:trixie-slim runtime], size: 6.5pt)
  cdraw.content((11.5, 2.7), [one binary, empty /data, user 65532], size: 6pt)
  cdraw.content((11.5, 1.8), [glibc matches, no shell, no curl, no toolchain], size: 6pt)
})

A `.dockerignore` trims the context to what the image reads, and the
rust tree needs it more than most: `target/` can hold gigabytes of
build cache the builder would upload only to ignore, and the tests,
the contract vectors, and the captures ride none of it into the
image.

== the binary as its own doctor

The image carries no shell, no curl, no wget, and installing a
diagnostic would grow the runtime for a question the binary can ask
itself. The `--health` flag answers it before any wiring runs,
probing the configured url's healthz with chapter 29's client and
exiting 0 on a 200, 1 on anything else:

#listing("rust/api/src/main.rs", first: 41, last: 48, caption: [the self-check: one client call before any bind, the exit code the healthcheck reads])

The probe earned its resolver lesson in this lane's own compose
wait: the first stack came up serving and stayed unhealthy, because
inside the container `localhost` resolves v6 first, the listener
holds v4, and a client dialing only the first answer pronounced a
healthy service dead. The fix landed in the client, chapter 29's
try-every-address loop, not in the compose file, and the same probe
then went healthy against the same image.

== compose, one command

The compose file is one service and its volume, and the contract it
enforces is the return value of a single command. `docker compose up
-d --build --wait` builds the image, creates the container, starts
it, and blocks until the healthcheck passes, so a green up means
the image built offline, the wal engine opened its volume, and both
listeners answer:

#listing("rust/api/compose.yml", first: 9, last: 29, caption: [the whole system: the env the wiring reads by name, both ports published, the volume, the probe])

The environment block carries exactly what construction demands:
both listeners bound wide for the container, both urls pointed at
localhost for the probe, the secret present so authn signs with a
known key, and the data directory on the named volume. `down -v`
removes the volume in the same breath, so every lane run starts from
store zero, the wal engine applying its log from nothing. Measured
2026-10-14, this machine: the stack went healthy on the wait, the
api answered `{"status":"ok","version":"0.1.0"}` on 19580, and the
first scrape of 19590 counted 6 requests on `/healthz`, every one of
them the probe's own fires, one registry counting its own doctor.

== the docker lane as a gate

The lane is one make target, committed before this wave's suite
landed, and its shape is the infrastructure book's two-gate rule,
#xref-to("infrastructure", "compose") owns the compose depth and
#xref-to("infrastructure", "containers") the pid 1 and signal story.
The plain crate lane never needs a daemon, and the docker lane never
runs silently, a missing daemon is a loud red with the instruction
to start it, never a skip:

#snippet(
  "verify-rustapi-docker:\n"
  + "\t@docker info >/dev/null 2>&1 || { \\\n"
  + "\t\techo \"docker daemon not reachable.\" >&2; \\\n"
  + "\t\techo \"start Docker Desktop (or the engine), then rerun: make verify-rustapi-docker\" >&2; \\\n"
  + "\t\texit 1; \\\n"
  + "\t}\n"
  + "\t@cd books/rust/api && docker compose down -v >/dev/null 2>&1 || true && \\\n"
  + "\t\ttrap 'docker compose down -v' EXIT && \\\n"
  + "\t\tdocker compose up -d --build --wait && \\\n"
  + "\t\tPATH=\"$$HOME/.rustup/toolchains/stable-x86_64-pc-windows-msvc/bin:$$PATH\" \\\n"
  + "\t\tCARGO_NET_OFFLINE=true \\\n"
  + "\t\tRUSTAPI_URL=http://127.0.0.1:19580 \\\n"
  + "\t\tRUSTAPI_METRICS_URL=http://127.0.0.1:19590 \\\n"
  + "\t\tcargo test --locked --test docker_it -- --ignored; rc=$$?; exit $$rc",
  lang: "makefile",
)

The suite it runs lives in `tests/docker_it.rs`, every test carrying
`#[ignore = "docker lane only: make verify-rustapi-docker"]`, so a
plain `cargo test` skips the file and the target runs it with
`--ignored` against the live stack, then the trap tears the stack
down with volumes on any exit. Chapter 31 walks the tests themselves
and states the two-lane contract in full.

#diagram([the gate: preflight, compose, replay, teardown, no skips], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.5), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.6), sub, size: 6pt)
  }
  box(0.8, 3.8, [preflight], [docker info or loud red])
  box(5.2, 4.2, [compose up], [build, wait for health])
  box(9.9, 4.2, [the replay], [docker_it --ignored])
  box(14.6, 3.8, [trap fires], [down -v on any exit])
  cdraw.line((4.7, 6.0), (5.1, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.5, 6.0), (9.8, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.2, 6.0), (14.5, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.6), [plain cargo test never runs docker_it], size: 6pt)
  cdraw.content((11.5, 2.7), [the lane target sits outside make verify on purpose], size: 6pt)
})

== the shipped checklist

The ship lane ends where it started, with the property each spine
chapter contributed, every row a behavior the lane or the module
gate observes:

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
  cell(5.9, 4.1, 10.0, [25 conc: admission], [the idempotency flight])
  cell(17.1, 4.1, 10.0, [26 cache: ttl plane], [invalidation on the write])
  cell(5.9, 2.7, 10.0, [27 limit: token bucket], [429 with Retry-After])
  cell(17.1, 2.7, 10.0, [28 obs: two series], [ops port, the ring])
  cell(5.9, 1.3, 10.0, [29 load: the ladder], [captures, honest p99])
  cell(17.1, 1.3, 10.0, [30 ship: the lane], [image, compose, replay])
})

The chapter also declares what it does not teach again. Docker's
storage model, the container runtime, and networking are the
infrastructure book's chapters, and the cloud side stays with the go
book's ship chapter, whose helm chart and terraform slice are the
same service's platform envelopes taught line by line. What this
chapter owns is the band between a green crate and a running
service: 59 lines of ship data, a 15-line image, a 29-line compose
file, and an 8-line probe.

sources: docker docs on multi-stage builds and `docker compose up
--wait` semantics, at docs.docker.com, accessed 2026-10-14. The
manifest digests resolved from the docker hub registry with
`docker buildx imagetools inspect` on 2026-10-14 and recorded in
`deploy.rs` with their dates, the builder `rust:1.99` at
`sha256:81015672d6939b0265f09adf96d5de125482bb1330106076956b0518e74edc90`
and the runtime `debian:trixie-slim` at
`sha256:a29215f6a35e51e22adffa17f89e9d2ef06214e64a2bad10d765c46aea49f11f`.
The builder's base measured by reading `/etc/os-release` inside the
pulled image, debian gnu/linux 13 trixie, and its `rustc --version`
matching 1.99.0 `(b940084d7 2026-09-28)`, both 2026-10-14. The
image and binary sizes from `docker images` and `docker history`
the same day, re-measured 2026-10-15 through the lane with the
numbers unchanged, 1.22 MB layer against a 119 MB image. Verified
live 2026-10-14: `docker compose up -d
--build --wait` healthy on this machine, both ports scraped from
the host, the healthcheck's own probes counted on the ops port, and
`docker compose down -v` clean. The make target quoted from the
Makefile as committed at 01cca1f8.
