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

The module ends as a directory of tests unless it also ships. This
chapter turns the service into an artifact and a lane: an image built
from one stage with no install step at all, one compose command that
brings it up healthy, and a make gate that replays the frozen
contract over that stack. Everything leans on machinery the earlier
chapters built: the kernel routes chapter 27 owns, the pbkdf2 cost
chapter 30 pins, the bucket chapter 35 refills, the exposition
chapter 36 binds, the admission gate and drain chapter 37 wires. The
platform envelopes around a shipped service, the ci workflow, the
helm chart, and the terraform slice, are taught in full in
#xref-to("go", "shipit") and mirrored in #xref-to("csharp-net",
"shipit") and #xref-to("javascript", "shipit"), and the corpus keeps
one executing lane per vehicle instead of re-deriving them. What this
chapter owns is the python truth of each layer: what the image is
when the interpreter is the whole platform and nothing installs, and
what the probe runs when the only executable in the image is the
runtime the service is made of.

== the image

One stage, because python has nothing to stage. The go lane's
chapter crossed from a builder into `scratch` with one static file,
legal because its store engine was pure go. The `c#` lane needed the
aspnet base because its sqlite bundle is a native library the runtime
must carry. The js lane's image is the runtime alone, and its install
step exists as a proof: `npm ci` over the committed lockfile resolves
zero packages, so the day a dependency sneaks into the manifest the
build fails loudly. This vehicle's dependency list is empty because
the platform and the dependency are the same object: cpython ships
with `sqlite3`, `json`, and `http.server` compiled in, and the
vehicle imports nothing outside that. There is no install step to
make a no-op of. The source is the dependency, `COPY` is the only
content step, and the image states that plainly:

#listing("python/api/Dockerfile", first: 1, last: 28, caption: [the whole image: one stage, the runtime, no install layer at all, the user the lane creates, the source])

The tag is the exact version the book builds under: the machine's
pinned interpreter is cpython 3.14.7, the same interpreter the plain
gate runs under, and `python:3.14.7-slim` was verified present against
the registry's tags api the day this chapter shipped, with the
image's own `python -V` answering 3.14.7. The `slim` variant is
debian trixie minus the common packages, and two absentees matter
later: neither `curl` nor `wget` is in it.

The user is this lane's own, and that is a python fact the other
lanes did not have. Node's image ships as uid 1000 already, so the js
lane only names the number. The python image ships as root, `id`
answers uid 0, so the lane creates the user itself: `useradd --uid
1000 pyapi`, no home, no login shell, just an identity to own files
with. `/data` is created and chowned at build time because a named
volume inherits the image content's ownership on first mount, and a
volume over a root-owned directory would deny the container user its
database, the ruling the js lane made carried across.

Three environment lines earn their place. `PYTHONUNBUFFERED` keeps
the json access log streaming to `docker logs`, one line per request
the moment it is written, verified by reading the lane's own log off
the composed stack. `PYTHONDONTWRITEBYTECODE` states a fact the file
permissions already enforce: the source tree ships root-owned and
read-only under `/app`, the runtime user cannot write a `__pycache__`
into it, and the source is the shipped artifact. `PYTHONUTF8` puts
the process in the same mode the plain gate runs under with `-X
utf8`. The whole service adds 388,740 bytes over its base, measured
off `docker image inspect`, under half a megabyte and every byte of
it source.

The lane caught its own bug on the first build, and the catch is the
argument for the lane. `COPY main.py pyapi ./` flattened the package:
a directory source copies its contents, not itself, so the modules
landed loose in `/app` and the container exited 1 naming
`ModuleNotFoundError: No module named 'pyapi'`. Loud at boot, before
any request, because the entrypoint runs the composition and the
composition imports the package. The fix names the directory, `COPY
pyapi pyapi`, the same shape as the js lane's `COPY src src`:

#diagram([one stage, four layers, and the empty slot where the others install], length: 13pt, {
  let layer(x, w, y, title, sub) = {
    cdraw.rect((x, y), (x + w, y + 2.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 1.4), [#title], size: 6.5pt)
    cdraw.content((x + w / 2, y + 0.55), sub, size: 6pt)
  }
  layer(4.0, 16.0, 6.2, [trixie slim + cpython 3.14.7], [sqlite3, json, http.server compiled in])
  layer(4.0, 16.0, 4.0, [the user + /data], [uid 1000 created here, root is not shipped])
  layer(4.0, 16.0, 1.8, [the source, 388,740 bytes], [COPY is the only content step])
  cdraw.content((12.0, 3.0), [go put a static binary here, c sharp an sdk publish, js a zero-resolve npm ci], size: 6pt)
  cdraw.content((12.0, 0.9), [python puts nothing: no pip layer exists anywhere in the image], size: 6pt)
})

== compose, one command

The compose file is one service and its volume, and the contract it
enforces is the return value of a single command. `docker compose up
-d --build --wait` builds the image, creates the container, starts
it, and blocks until the healthcheck passes, so a green up means the
image built, the store applied its migrations against a fresh volume,
and the listener answers probes. `down -v` removes the volume in the
same breath, so every lane run starts from migration zero, which is
what keeps the suite behind it deterministic:

#listing("python/api/compose.yml", first: 14, last: 44, caption: [the whole system: both listeners, the volume, the stdlib probe, the widened grace, host ports off 8080])

The healthcheck has no `curl` to call, and that is the python shape
of the probe. The slim image carries neither `curl` nor `wget`, both
probed absent, so the runtime probes its own `healthz` on loopback
with `urllib.request`, the same stdlib the server is made of, and the
assertion is 200 and only 200. The kernel's route answers from the
route table the composition registered, so a passing probe also
proves the composition ran to its last line.

The environment block carries exactly what construction demands, and
one honesty belongs here rather than in a footnote. The secret is
read at wiring with an empty default, `os.environ.get("GOAPI_JWT_SECRET",
"")`, and this chapter ran the image without the name to see what
happens: the service starts, `healthz` answers 200, register answers
201, and login mints a real bearer signed with the empty key. The js
lane's entry fails closed, refusing to start without the secret, and
that refusal is the right owner for it, so this vehicle's entry
carries it too: `main()` exits 2 before the listener binds when the
name is unset, `build_app` keeps the empty default so tests wire
families explicitly, and the composition suite pins both directions.
The compose file always supplies one, and the platform envelopes in
the go lane exist partly to replace it. The measured difference this
chapter opened with is history now, kept here because the probe that
found it is the same probe that closed it.

Both listeners bind every interface inside the container because both
defaults bind loopback, and a published port cannot reach a loopback
bind. The metrics listener reads its own name, chapter 36's
`GOAPI_DEBUG_ADDR` with its `:9091` default, and the kernel's
`GOAPI_ADDR` carries the api listener. The grace is widened to 40
seconds for a reason the load chapter earned: the entry runs the
drain on `SIGTERM` with a 30-second budget, the orchestrator's
default kill lands 10 seconds after the term, and an unwidened grace
would truncate the drain before it could report its exit code.

The host side of both mappings sits on 19280 and 19290, and the
sibling lanes own the rest of the table: go holds 8080 and 6060, c
sharp 18080 and 16090, js 19080 and 19090 with its typed lane on
19180 and 19190. A lane is the only thing under its ports, because
two lanes racing for one port on one shared machine is a flake
factory neither lane can debug from its own logs.

#diagram([what a green up proves, in order], length: 13pt, {
  let step(x, w, top, sub) = {
    cdraw.rect((x, 4.6), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.4), sub, size: 6pt)
  }
  step(0.8, 4.4, [build], [COPY runs, nothing installs])
  step(6.2, 4.4, [create + start], [env read at wiring])
  step(11.6, 4.4, [migrations], [user_version records, in process])
  step(17.0, 4.4, [probe passes], [--wait returns 0])
  cdraw.line((5.3, 5.8), (6.1, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.7, 5.8), (11.5, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((16.1, 5.8), (16.9, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.5), [the probe is stdlib urllib on loopback healthz], size: 6pt)
  cdraw.content((11.5, 2.6), [down -v wipes the volume, next run starts at migration zero], size: 6pt)
  cdraw.content((11.5, 1.7), [no manual schema step anywhere, ever], size: 6pt)
})

== the docker lane as a gate

The lane is one make target, and its shape mirrors the two-gate rule
#xref-to("infrastructure", "compose") owns: the plain module gate
never needs a docker daemon, and the docker lane never runs silently,
a missing daemon a loud red with the instruction to start it, never a
skip. The integration suite lives under `integration/`, outside the
`tests/` directory the plain gate discovers with `unittest discover
-s tests`, so the daemon-free gate never even imports it, the faithful
mirror of go's build tag and the `c#` lane's project outside the
solution:

#snippet(
  "verify-pyapi-docker:\n"
  + "\t@docker info >/dev/null 2>&1 || { \\\n"
  + "\t\techo \"docker daemon not reachable.\" >&2; \\\n"
  + "\t\techo \"start Docker Desktop (or the engine), then rerun: make verify-pyapi-docker\" >&2; \\\n"
  + "\t\texit 1; \\\n"
  + "\t}\n"
  + "\t@cd books/python/api && docker compose down -v >/dev/null 2>&1 || true && \\\n"
  + "\t\ttrap 'docker compose down -v' EXIT && \\\n"
  + "\t\tdocker compose up -d --build --wait && \\\n"
  + "\t\tPYAPI_URL=http://127.0.0.1:19280 \\\n"
  + "\t\tPYAPI_METRICS_URL=http://127.0.0.1:19290 \\\n"
  + "\t\tpython -m unittest discover -s integration; rc=$$?; exit $$rc",
  lang: "makefile",
)

Two environment families live in this lane and never mix. The
`GOAPI_` names are the vehicle's configuration surface, the same keys
the compose file sets, read once at wiring. The `PYAPI_URL` and
`PYAPI_METRICS_URL` names are the lane's own probe coordinates, read
by the integration suite and set by the make target, never by the
service. The split guards a failure mode the `c#` lane named:
renaming one family without the other makes the lane silently probe
its defaults, a green suite pointed at nothing. The suite also
refuses a target that carries a path, because the probe routes are
root-relative and a prefix would be silently dropped, and the suite
would stay green while probing the wrong namespace.

Five tests cover the contract's scenarios: both probes and the two
routing envelopes, including the ruling that a 405 carries the
`not_found` code plus an `Allow` header; the register with its
`Location` and strong ETag, and the replay answered 409 on the email
conflict; the login pair with its cookie attribute line, its bearer
token, and the identical 401 bytes for a wrong password and an
unknown account; the bucket drained to a 429 with `Retry-After` and a
remaining count of zero; and the metrics exposition answered on the
internal listener. The ETag rule is the sharpest, a strong ETag is
the sha256 of the exact response body, so the suite recomputes the
hash over the wire bytes and compares:

#listing("python/api/integration/test_lane.py", first: 86, last: 94, caption: [the etag check recomputed over live bytes, not frozen ones])

The drain is where the lane tells a python truth the in-process
suites cannot. A wrong-password login costs about 27 milliseconds
over the wire, read off the lane's own access log, the pbkdf2 verify
chapter 30 pins running inside the 401, while the bucket refills one
token per second, so a counted drain of exactly five draws races the
refill and flakes. The suite draws until the 429 is a fact, bounded
at twelve draws, and asserts the denial's shape rather than the
interleaving. The clock under test is real, refill is part of the
behavior under it.

The lane earned its keep twice during this chapter's own landing.
The first was the flatten, the image layer's `COPY` catching a bug no
in-process suite could see because no in-process suite imports from
an image's `/app`. The second came while the store family was still
mid-landing: the lane went red on a login that answered 500, and the
container's own log named `SessionStore.create() takes 1 positional
argument but 2 were given`, a signature drift between the authn
routes and a store edit that no family's own suite had walked,
because no family's suite registers through one family and logs in
through another over the composition. Both were the same argument:
the composed service over a real socket is a different test object
than any family's stack, and the contract only holds when the
composition holds.

#diagram([the gate: one lane, one trap, no skips], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.5), top, size: 6.5pt)
    cdraw.content((x + w / 2, 5.6), sub, size: 6pt)
  }
  box(0.8, 3.8, [preflight], [docker info or loud red])
  box(5.2, 4.2, [compose up], [build, wait for health])
  box(9.9, 4.2, [lane tests], [five replays on 19280])
  box(14.6, 3.8, [trap fires], [down -v on any exit])
  cdraw.line((4.7, 6.0), (5.1, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((9.5, 6.0), (9.8, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.2, 6.0), (14.5, 6.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.6), [plain verify-pyapi never sees these files], size: 6pt)
  cdraw.content((11.5, 2.7), [GOAPI_ configures the service, PYAPI_ aims the suite], size: 6pt)
  cdraw.content((11.5, 1.8), [the second gate, never in make verify], size: 6pt)
})

== the shipped checklist

The lane ends where the family began, with the property each chapter
contributed, and the composition root is the document that carries
them all: the stack reads trace, metrics, request id, access log,
limit, deadline, recover, then identity installs the actor and the
admission gate rides innermost, so a refusal at the cap still carries
the request id and lands in the access log like every other answer.
The process entry below the composition owns the two listeners and
the ordered shutdown: `SIGTERM`, which is what a container stop
sends, raises into the join, the drain runs over the real server
with readiness flipped first so the probe stops passing while
in-flight requests finish, the metrics listener closes after the
drain, and the exit code reports what the drain earned, the load
chapter's rule carried to the process edge:

#listing("python/api/main.py", first: 134, last: 172, caption: [the process entry: the secret refusal, both listeners, the term raise, the drain with its reported exit code])

#diagram([the readiness table: twelve chapters, twelve properties, all proven], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), l1, size: 6pt)
    cdraw.content((x, y - 0.28), l2, size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [27 kernel: one envelope], [on every failure, over the wire])
  cell(17.1, 8.3, 10.0, [28 middleware: the stack], [ids, log, deadline, recover])
  cell(5.9, 6.9, 10.0, [29 users: validation], [plus keyset pagination])
  cell(17.1, 6.9, 10.0, [30 authn: pbkdf2 sessions], [rotating refresh, no enumeration])
  cell(5.9, 5.5, 10.0, [31 authz: the registrar], [a route without a row refuses to wire])
  cell(17.1, 5.5, 10.0, [32 store: migrations], [transactions, wal isolation])
  cell(5.9, 4.1, 10.0, [33 conc: the duel], [etag plus idempotent replay])
  cell(17.1, 4.1, 10.0, [34 cache: lru with ttl], [and the collapse loader])
  cell(5.9, 2.7, 10.0, [35 limit: token bucket], [429 with Retry-After])
  cell(17.1, 2.7, 10.0, [36 obs: the exposition], [on the internal listener])
  cell(5.9, 1.3, 10.0, [37 load: the drain], [admission, exit code reported])
  cell(17.1, 1.3, 10.0, [38 ship: the lane], [proving all of the above])
})

The parameter family is what transfers. `GOAPI_ADDR`,
`GOAPI_VERSION`, `GOAPI_DB`, and `GOAPI_JWT_SECRET` are the same
names in every lane's compose file, and `GOAPI_DEBUG_ADDR` is this
book's own name for the metrics listener, the same role go's 6060 and
js's 6090 play: the image reference and the host ports are the only
edits between one lane's file and another's. The chapter declares
what it does not carry: the ci workflow, the helm chart, and the
terraform slice are the go lane's teaching and the `c#` mirror, and
the corpus keeps one executing lane per vehicle. Docker's storage
model, the container runtime, and compose internals belong to
#xref-to("infrastructure", "containers") and
#xref-to("infrastructure", "compose"). What this chapter owns is the
narrow band between a green module and a running service, and the
suite chapter that follows hardens the whole set.

sources: the base image tag verified against the registry at
hub.docker.com/v2/repositories/library/python/tags, `3.14.7-slim`
present, accessed 2026-09-27, and the image facts read off the
pulled image the same day, `python -V` answering 3.14.7, `id`
answering uid 0 so the user is the lane's own, `curl` and `wget`
both absent, the service measured at 388,740 bytes over the base by
`docker image inspect`. Docker docs on copy semantics, healthchecks,
`stop_grace_period`, and `docker compose up --wait` semantics at
docs.docker.com, accessed 2026-09-27. The wrong-password figure is
this lane's own access log over the composed stack. Verified by
`make verify-pyapi` with its 313 daemon-free tests, `make
verify-pyapi-docker` end to end with its five scenarios, and a run
of the image without the secret whose behavior this chapter states.
