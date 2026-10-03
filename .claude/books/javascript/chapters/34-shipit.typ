#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= ship it

The module ends as a directory of tests unless it also ships. This
chapter turns the service into an artifact and a lane: an image built
from one stage, one compose command that brings it up healthy, and a
make gate that replays the contract over that stack. Everything leans
on machinery the earlier chapters built: the health and ready routes
chapter 23 owns, the strong ETags chapter 29 computes, the drain
state chapter 33 wires, the metrics exposition chapter 32 binds. The
platform envelopes around a shipped service, the ci workflow, the
helm chart, and the terraform slice, are taught in full in
#xref-to("go", "shipit") and mirrored in #xref-to("csharp-net",
"shipit"), and this third lane keeps one executing lane per vehicle
instead of re-deriving them. What this chapter owns is the node truth
of each layer: what the image is when there is nothing to compile,
what the probe runs when the runtime is the only executable.

== the image

One stage, because node has no build to stage. The go lane's chapter
crossed from a builder into `scratch` with one static file, legal
because its store engine was pure go, and the `c#` lane needed the
aspnet base because its sqlite bundle is a native library the runtime
must carry. This service's store is `node:sqlite`, a module compiled
into the runtime itself, and its dependency list is empty, so the
smallest correct image is the runtime alone. A builder stage would
carry a compiler the image never runs, and the image states that
trade instead of paying it. The whole image is 24 lines and the
service adds about 4 MB over its base:

#listing("javascript/api/Dockerfile", first: 1, last: 24, caption: [the whole image: one stage, the runtime, the no-op install proof, both source trees, user 1000])

Four decisions earn a second look. The manifests copy precedes the
source copy so the install layer caches independently of code edits,
the same layer economy the other lanes pay for, except that here the
install is deliberately a proof: `npm ci --omit=dev` over the
committed lockfile resolves zero packages, and the step exists so the
day a dependency sneaks into the manifest the build fails loudly at
the layer that introduced it. The source copy takes both trees, `src`
and `src-ts`, because the typed lane of chapter 37 runs the same
image with the entrypoint pointed at the typed entry, node stripping
the `.ts` sources at run, so no second image exists to maintain. The
`/data` directory is created with
an owner because a named volume inherits the image content's
ownership on first mount, and a volume mounting onto a root-owned
directory would deny the container user its database. The user is
numeric, `1000:1000`, the uid and gid the node image ships as `node`,
read off the pulled image rather than assumed from docs. And only
8080 is declared, because the metrics listener on 6090 is the
observability chapter's internal surface, published by the lane that
asserts against it and by nothing else.

The tag is exact, `node:26.3.0-slim`, verified against the registry
on the day the chapter was written, and it matches the machine the
book builds under at the major and the minor. The slim variant is
glibc, the same libc family the local suite runs on, at a fraction of
the full image, and alpine's musl would make the shipped platform a
different platform than the tested one to save megabytes this service
does not care about.

The healthcheck has the shape problem both earlier lanes met: the
slim image carries no curl and no wget, both verified absent from the
pulled image, so nothing exists to probe with except the one
executable that does exist, the runtime itself. `src/ship/probe.mjs`
reads `GOAPI_ADDR`, rewrites the host to loopback because a bind
address of `0.0.0.0` names the side that listens and is not a host
anyone can dial, and asks its own `/readyz`. Ready is 200 and only
200, a draining 503 means do not route traffic here, and a refused
dial is a failed probe. The probe mirrors the go lane's `-health`
flag and the `c#` lane's `--ready-probe` with the one difference that
node's global `fetch` makes the probe a module of ten lines rather
than a flag on the entrypoint.

The `GOAPI_` names carry over from the go and `c#` lanes
deliberately. The contract pins the `goapi_` metric series and the
token issuer, so one parameter family and one frozen contract serve
all three lanes, each with its own compose file, the ruling the `c#`
lane's chapter states and this lane inherits rather than re-argues.
The vehicle reads five names, `GOAPI_ADDR`, `GOAPI_METRICS_ADDR`,
`GOAPI_DB`, `GOAPI_JWT_SECRET`, and `GOAPI_VERSION`, and nothing
else.

A `.dockerignore` earns its place here where the go module's did
not: a node vehicle grows `node_modules` from local runs, and riding
it into the build context would both bloat the upload and undermine
the install proof. The excluded set is the local installs and every
tree that is not service source.

#diagram([one stage, nothing to cross: the runtime is the toolchain is the app], length: 13pt, {
  cdraw.rect((1.0, 6.2), (21.9, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.2), [#"node:26.3.0-slim"], size: 6.5pt)
  cdraw.content((11.5, 7.3), [manifests, npm ci proof, then src], size: 6pt)
  cdraw.content((11.5, 6.5), [the runtime that compiles nothing runs the service], size: 6pt)
  cdraw.line((11.5, 5.9), (11.5, 4.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 5.1), [no boundary to cross, the layer stack is the only stack], size: 6pt)
  cdraw.rect((3.4, 1.2), (19.6, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 3.6), [the shipped image], size: 6.5pt)
  cdraw.content((11.5, 2.7), [src, an empty node_modules, /data owned by 1000], size: 6pt)
  cdraw.content((11.5, 1.8), [no compiler, no shell utilities, 4 MB over the base], size: 6pt)
})

== compose one command

The compose file is one service and its volume, and the contract it
enforces is the return value of a single command. `docker compose up
-d --build --wait` builds the image, creates the container, starts
it, and blocks until the healthcheck passes, so a green up means the
image built, the migrations ran against a fresh volume, and the
listener answers probes. `down -v` removes the volume in the same
breath, so every lane run starts from migration zero, which is what
keeps the suite behind it deterministic:

#listing("javascript/api/compose.yml", first: 14, last: 36, caption: [the whole system: both listeners, the volume, the probe, host ports off 8080])

The environment block carries exactly what construction demands. The
secret must be present or the process refuses to start, loudly, a
behavior the chapter verified by running the image without it and
reading the crash: the error names `GOAPI_JWT_SECRET`, the
orchestrator restarts, an operator reads the log. A missing secret is
a crash, never a running service signing tokens with an empty key.
The value in the file is a development constant, and the platform
envelopes in the earlier lanes exist partly to replace it. Both
listeners bind every interface inside the container because the
kernel's listen default in this vehicle is loopback, so the compose
file states the bind side explicitly rather than inheriting a default
chosen for tests.

The host side of both mappings sits on 19080 and 19090. The
container ports keep the family shape, 8080 for the api and 6090 for
the metrics listener, but the host ports move off 8080, where shared
dev machines carry loopback shadows, and off the `c#` lane's 18080
and 16090, because two lanes must never race for one port on one
machine. A lane is the only thing under its ports.

The environment is read exactly once, at the process boundary.
`src/ship/config.mjs` is the vehicle's one reader of ambient
environment, every family takes its configuration as injected
dependencies, and the entrypoint passes those injections to the
composition the same way the tests do. One more fact of the entry is
stated plainly rather than hidden: the users port rides one store
handle the entry opens, and the composition opens a second handle to
the same file for idempotency keys and analytics, two handles the
store chapter's wal mode lets coexist. The single-store ruling names
the day the composition constructs both from one open, and until that
day the entry is the honest description of what runs.

#diagram([what a green up proves, in order], length: 13pt, {
  let step(x, w, top, sub) = {
    cdraw.rect((x, 4.6), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.4), sub, size: 6pt)
  }
  step(0.8, 4.4, [build], [image builds, install proof runs])
  step(6.2, 4.4, [create + start], [env read once, volume mounted])
  step(11.6, 4.4, [migrations], [version records apply])
  step(17.0, 4.4, [probe passes], [--wait returns 0])
  cdraw.line((5.3, 5.8), (6.1, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.7, 5.8), (11.5, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.1, 5.8), (16.9, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.5), [any step failing leaves up non-zero], size: 6pt)
  cdraw.content((11.5, 2.6), [down -v wipes the volume, next run starts at zero], size: 6pt)
  cdraw.content((11.5, 1.7), [no manual schema step anywhere, ever], size: 6pt)
})

== the docker lane as a gate

The lane is one make target, and its shape mirrors the two-gate rule
#xref-to("infrastructure", "compose") owns: the plain module gate
never needs a docker daemon, and the docker lane never runs silently,
a missing daemon a loud red with the instruction to start it, never a
skip. The integration suite lives under `integration/` with its own
script entry, outside the `test/**` glob `npm run verify` runs, the
faithful mirror of go's build tag and the `c#` lane's project outside
the solution:

#snippet(
  "verify-jsapi-docker:\n"
  + "\t@docker info >/dev/null 2>&1 || { \\\n"
  + "\t\techo \"docker daemon not reachable.\" >&2; exit 1; }\n"
  + "\t@cd books/javascript/api && docker compose down -v >/dev/null 2>&1 || true && \\\n"
  + "\t\ttrap 'docker compose down -v' EXIT && \\\n"
  + "\t\tdocker compose up -d --build --wait && \\\n"
  + "\t\tJSAPI_URL=http://127.0.0.1:19080 \\\n"
  + "\t\tJSAPI_METRICS_URL=http://127.0.0.1:19090 \\\n"
  + "\t\tnpm run test:integration; rc=$$?; exit $$rc",
  lang: "makefile",
)

Two environment families live in this lane and never mix. The
`GOAPI_` names are the vehicle's configuration surface, the same keys
in the compose file, read once by the entry. The `JSAPI_URL` and
`JSAPI_METRICS_URL` names are the lane's own probe coordinates, read
by the integration suite and set by the make target, never by the
service. The split guards a failure mode the `c#` lane named:
renaming one family without the other makes the lane silently probe
its defaults, a green suite pointed at nothing, so the two lists
change together or not at all. The suite also refuses a target that
carries a path, because `new URL(path, base)` would silently drop a
prefix and the suite would stay green while probing the wrong
namespace.

Six tests cover the contract's scenarios: both probes and the two
routing envelopes, including the ruling that a 405 carries the
`not_found` code plus an `Allow` header, the register replay and
login walk with its cookie attribute line and its identical 401
bytes, the etag duel with its one 200 and one 412, the rate drain to
a 429, the reports idempotent pair with the sanctioned 202-to-200
upgrade, and the metrics exposition off the internal listener. The
ETag rule is the sharpest, a strong ETag is the sha256 of the exact
response body, so the suite recomputes the hash over the wire bytes
and compares:

#listing("javascript/api/integration/lane.test.mjs", first: 67, last: 80, caption: [the etag check recomputed over live bytes, not frozen ones])

The rate drain is where the lane tells a node truth the in-process
suites cannot. The issue-tier scrypt the authn chapter pins costs
about 0.4 seconds per verify on this machine, measured, and the
bucket refills one token per second, so a counted drain of exactly
five draws races the refill and flakes. The suite draws until the 429
is a fact, bounded at twelve draws, and asserts the denial's
`Retry-After` of at least one second and a remaining count of zero.
The clock under test is real, refill is part of the behavior under
it, and the assertion names the fact rather than the interleaving.

The lane earned its keep before it ever booted a container. Two hand
probes against the composed app over a real socket found failures no
family's own suite had walked, because no in-process test registers
through the users family and then logs in through the authn family
over the composition: the login first read a second, empty user
store the composition had accidentally allowed each family to
default, and after that fix the login answered 400 because the
limiter's email key had consumed the request body that the handler
then tried to read a second time from a spent stream. Both were
one-line composition fixes, and both were the argument for this
chapter: the composed service over a real socket is a different test
object than any family's stack, and the contract only holds when the
composition holds.

#diagram([the gate: one lane, one trap, no skips], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.5), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.6), sub, size: 6pt)
  }
  box(0.8, 3.8, [preflight], [docker info or loud red])
  box(5.2, 4.2, [compose up], [build, wait for health])
  box(9.9, 4.2, [lane tests], [six replays on 19080])
  box(14.6, 3.8, [trap fires], [down -v on any exit])
  cdraw.line((4.7, 6.0), (5.1, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.5, 6.0), (9.8, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.2, 6.0), (14.5, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.6), [plain npm run verify never sees these files], size: 6pt)
  cdraw.content((11.5, 2.7), [its own script entry, integration/lane.test.mjs], size: 6pt)
  cdraw.content((11.5, 1.8), [the only executing lane in this chapter], size: 6pt)
})

== the shipped checklist

The lane ends where it started, with the property each chapter
contributed, and the ship family added one artifact of its own, the
process entry. The entry is the composition's last consumer: it reads
the environment once, fails closed on the secret, opens and migrates
the store, hands the composition its injected dependencies, and boots
through the ship family's own wiring, so the file holds no listening
of its own:

#listing("javascript/api/src/ship/main.mjs", first: 11, last: 32, caption: [the process entry: env once, fail closed, injection, boot])

The boot the entry calls owns the ordered shutdown. A `SIGTERM`,
which is what a container stop sends, runs the load family's drain
over the real server, readiness flips first so balancers stop routing
while in-flight requests finish, and the exit code reports what the
drain earned: zero when it drained, one when the grace deadline
passed and the hard kill had to run, with `closeAllConnections`
executed only after that deadline, the load chapter's rule carried to
the process edge, reported rather than pretended.

#diagram([the readiness table: twelve chapters, twelve properties, all proven], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [23 kernel: one envelope], [on every failure, over the wire])
  cell(17.1, 8.3, 10.0, [24 middleware: the stack], [ids, log, deadline, recover])
  cell(5.9, 6.9, 10.0, [25 users: validation], [plus keyset pagination])
  cell(17.1, 6.9, 10.0, [26 authn: scrypt sessions], [rotating refresh, no enumeration])
  cell(5.9, 5.5, 10.0, [27 authz: rbac], [owner checks, audited routes])
  cell(17.1, 5.5, 10.0, [28 store: migrations], [transactions, wal isolation])
  cell(5.9, 4.1, 10.0, [29 conc: the duel], [etag plus idempotent replay])
  cell(17.1, 4.1, 10.0, [30 cache: lru with ttl], [and the stampede guard])
  cell(5.9, 2.7, 10.0, [31 limit: token bucket], [429 with Retry-After])
  cell(17.1, 2.7, 10.0, [32 obs: the exposition], [on the internal listener])
  cell(5.9, 1.3, 10.0, [33 load: drain], [admission and no leaks])
  cell(17.1, 1.3, 10.0, [34 ship: the lane], [proving all of the above])
})

The chapter declares what it does not carry. The ci workflow, the
helm chart, and the terraform slice are the go lane's teaching and
the `c#` lane's mirror, and the corpus keeps one executing lane per
vehicle. The parameter family is what transfers: the earlier lanes'
envelopes configure this image by the same `GOAPI_` names, with the
image reference and the host ports as the only edits. Docker's
storage model, the container runtime, and compose internals belong to
#xref-to("infrastructure", "containers") and
#xref-to("infrastructure", "compose"). What this chapter owns is the
narrow band between a green module and a running service, and the
suite chapter that follows hardens the whole set.

sources: the node image tag verified against the registry at
hub.docker.com/v2/repositories/library/node/tags, `26.3.0-slim`
present, accessed 2026-09-26, and the image facts read off the pulled
image the same day, user `node` at uid and gid 1000, `curl` and
`wget` absent, `node -v` answering 26.3.0. Docker docs on build cache
ordering, healthchecks, and `docker compose up --wait` semantics at
docs.docker.com, and node docs on process signal events,
`import.meta.main`, the global fetch, and the test runner under
nodejs.org/docs/latest/api, both accessed 2026-09-26. The scrypt
figure is this machine's own measurement at the chapter's pinned
parameters. Verified by `docker compose build`, a run of the image
failing closed without the secret and naming the missing name, the
unit suite at 317 green, and the compose lane end to end under `make
verify-jsapi-docker`.
