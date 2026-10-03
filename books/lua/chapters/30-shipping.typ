#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= shipping

The service exists as a directory of green tests until it also ships.
This chapter turns it into an artifact and a lane: the store story, the
wiring the ship marker owns, the secret source, the drain truth, an
image that builds its own interpreter because no registry carries
lua 5.5, one compose command, and a make gate that replays the
contract over the real listener.

== what shipping means here

Two facts decide this chapter's shape. First, no registry image carries
lua 5.5, so an honest image compiles the interpreter from the lua.org
tarball inside the build. Second, the wire is not lua's to own on any
platform: the winsock host owns the windows edge, and a plain vm has no
socket at all. The container answer is a posix twin of that host, the
same six net functions and the same `handle(fd)` contract ported to
berkeley sockets, and the discipline that keeps the port small is that
the seam, not either host, is the contract:

#listing("lua/service/docker/posix_host.c", first: 163, last: 181, caption: [the seam restated on posix, the same table the winsock host registers])

One divergence earns its comment at the send function: windows has no
sigpipe, a dead peer is just a send error, while linux raises a signal
that kills by default, and `MSG_NOSIGNAL` keeps the platforms alike.
The twin folds the windows host's two files into one because the
container needs no second lua state: serve mode is pid 1 with one
accept loop, and client mode runs one driver script with `connect` and
no listener, how the probe and the replay leg talk to a running stack
with no curl in the image.

#diagram([two hosts around one seam, the service module never learns which answered], length: 13pt, {
  cdraw.rect((0.6, 5.6), (9.8, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 8.0), [the winsock host], size: 6.5pt)
  cdraw.content((5.2, 6.9), [frozen, windows edge], size: 6pt)
  cdraw.content((5.2, 6.0), [closesocket unblocks accept], size: 6pt)
  cdraw.rect((14.2, 5.6), (23.4, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((18.8, 8.0), [the posix twin], size: 6.5pt)
  cdraw.content((18.8, 6.9), [linux face, MSG_NOSIGNAL], size: 6pt)
  cdraw.content((18.8, 6.0), [poll plus EINTR on term], size: 6pt)
  cdraw.rect((10.4, 2.2), (13.6, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((12.0, 4.0), [the seam], size: 6.5pt)
  cdraw.content((12.0, 2.5), [recv send close addr peer connect], size: 6pt)
  cdraw.line((12.0, 5.6), (12.0, 4.8), stroke: luma(100))
  cdraw.content((12.0, 0.9), [handle(fd) over an fd integer, same on both], size: 6pt)
})

== the oracle learns the report seams

The reports routes waited behind one honest gap: the handlers take
`report_create`, `report_load`, and `report_compute` injected, the jit
engine carried them, and the oracle that backs the service in this vm
did not. The store chapter's ruling settles it: the oracle is the
mirror the jit store must match row for row, so the seams belong on it
and every lane serves the same surface, events and delete cascade
included.

The series is the chapter's one derivation, the engine computes it in
one committed query with window functions and the oracle walks tables
to the same rows: presence collapses to one member per user per day,
the first day inside the window marks the newcomer, and delta carries
yesterday's count with today's as the lag default so the first day
reads zero. The window bound is the subtle part and the test pins it:
narrow the window to one day and both users count as newcomers there,
because first day is a property of the window, not of history, exactly
the bound the sql presence filter draws. Leaders rank with ties sharing
a rank and the user id breaking the order:

#listing("lua/service/users.lua", first: 438, last: 451, caption: [the series walk: days sorted once, then the counting loop the engine folds into one query])

#diagram([events to series, the window bounds every step], length: 13pt, {
  cdraw.rect((0.6, 4.4), (7.4, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 6.6), [presence, one set per day], size: 6.5pt)
  cdraw.content((4.0, 5.6), [#"2026-09-26: {ada, grace}"], size: 6pt)
  cdraw.line((7.6, 6.0), (8.4, 6.0), stroke: luma(100), mark: (end: ">>"))
  pane(8.6, 15.0, 7.6, [the walk], [days sorted once], [window bounds applied])
  cdraw.line((15.2, 6.0), (16.0, 6.0), stroke: luma(100), mark: (end: ">>"))
  pane(16.2, 23.4, 7.6, [one row per day], [active, newcomers], [delta, first day 0])
  cdraw.content((4.0, 4.3), [leaders: ties share rank, user id breaks], size: 6pt)
  cdraw.content((15.0, 4.3), [first day is a property of the window, not history], size: 6pt)
})

== the reports routes and vector 16

The wiring at the ship marker is four moves: the routes mount behind a
guard that demands an actor and stamps the idem scope, the policy rows
for both routes have sat in the authz table since that chapter froze
its audit, the readiness gate takes the kernel's `ready` seam, and the
secret line now reads through the shipping module. The guard answers an
anonymous caller with `unauthorized` before any store read, and the
actor's user id becomes the identity the handler keys its idempotency
claim on. The generic idem layer skips this one path by rule, because
the sanctioned 202 to 200 upgrade is the reports handler's own
decision and a generic replay would answer the stored 202 forever:

#listing("lua/service/main.lua", first: 392, last: 415, caption: [the ship splice: the gate, the reports pair over the oracle, the readiness seam])

Two facts are stated rather than hidden. The idem layer's clock is
milliseconds while the kernel's is whole seconds, so the root crosses
units at the construction, a bare seconds feed made every stored row
effectively immortal. And the wire lane's first run caught a real
defect here: the guard's anonymous branch returned its fail value as a
single value, the wrapper destructured two, took the truthy fail table
as success, and an anonymous submission reached a 202, invisible to
every in-process suite because the vectors compose the harness.

Vector 16 then lands as the scenario the suite was waiting for: the
bearer is the session the roles scenario minted at offset 49, asserted
byte for byte before the run, the setup op seeds through the oracle's
own `event_add`, and the contract's GET line reconciles with the
vector's bytes, this service computes on the first read so a GET
answers 200 or 404 and pending exists only on the replay before any
read has run.

#diagram([vector 16's three steps, the one sanctioned divergence in the middle], length: 13pt, {
  pane(0.6, 7.0, 7.8, [POST with key rep-01], [202 pending], [the location names the job])
  cdraw.line((7.2, 6.4), (7.6, 6.4), stroke: luma(100), mark: (end: ">>"))
  pane(7.8, 14.8, 7.8, [GET the report], [200, computes the series], [the row flips done])
  cdraw.line((15.0, 6.4), (15.4, 6.4), stroke: luma(100), mark: (end: ">>"))
  pane(15.6, 23.4, 7.8, [POST again, same key], [200, byte identical], [replaying a read])
})

== the secret source

Everything the tokens chapter signed rides one key, and the root's one
read of the environment moves into the shipping module where the
decision can fail loudly. The rules are three branches: a set secret is
the answer once it clears a floor, production without a secret is a
startup error, and the unset non-production case gets a named dev
constant that is a statement, not a secret. The floor exists because a
two-character key is configuration noise that happens to parse, and
the production branch exists because a service that boots on a default
key is a service nobody configured but everyone can talk to:

#listing("lua/service/ship.lua", first: 18, last: 39, caption: [the three branches: set and long enough, production refuses absence, dev otherwise])

A load-time error is the right shape: the host dies, the container
exits, the orchestrator restarts, an operator reads the message. The
reader seam is injected, the dev constant is public by construction,
and the secret appears nowhere else, the frozen vectors carry their
own pinned public key.

#diagram([one reader of the environment, three answers, one of them fatal], length: 13pt, {
  cdraw.content((12.0, 7.6), [secret_from, the root's one call], size: 6.5pt)
  cdraw.line((6.0, 6.4), (3.6, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((12.0, 6.6), (12.0, 5.2), stroke: luma(100))
  cdraw.line((18.0, 6.4), (20.4, 5.2), stroke: luma(100), mark: (end: ">>"))
  pane(1.0, 6.2, 4.8, [set], [under 16 bytes errors], [the answer otherwise])
  pane(9.2, 14.8, 4.8, [unset, production], [a startup error], [dies before serving])
  pane(17.6, 23.0, 4.8, [unset, not production], [the named dev constant], [public by construction])
})

== drain and readiness

The contract says readyz flips to 503 the moment drain starts, and the
single-threaded vm has an honest version of that sentence and no more.
The lua half is a gate, flipped once and latched because a drain that
un-flips lies to the balancer, and the boundary is plain: nothing on
the lua side can observe a signal to call it.

The container's drain lives in the twin, and the posix half has one
lesson the windows host never needed: windows documents that closing a
socket fails the accept blocked on it, linux makes no such promise, so
the twin polls and the term interrupts the poll, visible only because
the handler installs without `SA_RESTART`, which is why the code uses
`sigaction` and not `signal`, whose bsd semantics restart the poll and
hide the term. The drain falls out of the loop: the in-flight `handle`
runs to its last byte, the next poll reads the flag, and the exit is
zero, verified by stopping a healthy container:

#listing("lua/service/docker/posix_host.c", first: 227, last: 254, caption: [sigaction without restart, poll interrupted by term, the in-flight connection finishing])

#diagram([the drain a single thread can honestly give], length: 13pt, {
  cdraw.line((0.6, 3.4), (23.4, 3.4), stroke: luma(120))
  cdraw.rect((1.2, 4.4), (9.0, 5.6), fill: luma(160), radius: 0.02)
  cdraw.content((5.1, 5.0), [connection in flight], size: 6pt)
  cdraw.circle((7.0, 3.4), radius: 0.3, fill: luma(60))
  cdraw.content((7.0, 2.4), [term arrives, the flag sets], size: 6pt)
  cdraw.line((9.2, 5.0), (14.6, 5.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.9, 5.6), [handle runs to its last byte], size: 6pt)
  pane(14.8, 21.6, 6.6, [poll returns EINTR], [flag read, exit zero], [listener closed])
  cdraw.content((11.9, 1.4), [no 503 window: that needs a second thread, stated], size: 6pt)
})

== the image

Two stages, and the boundary carries one binary and one tree. The
builder is debian slim plus a compiler toolchain, it fetches the lua
tarball by pinned version and checksum so a moved upstream is a loud
build failure, and it builds the interpreter with the release's own
`make linux` target, proving the artifact in place: the whole plain
lane runs green in the builder on the interpreter the image ships. The edge links that build's static `liblua.a` in one gcc
line, so the runtime needs no lua at all, only the binary and libc:

#listing("lua/service/Dockerfile", first: 15, last: 35, caption: [the pin, the build, the self-proof, the static link])

The checksum is the pin that matters, the same 5.5.1 the book's
`tools/lua55` builds locally, and `make linux` needs no readline, that
is the separate flavor. The runtime is slim debian under uid 1000 and
the tree copies whole, the context trade the go lane states rather
than paying a dockerignore that drifts.

#diagram([two stages, one binary and one tree cross], length: 13pt, {
  cdraw.rect((1.0, 6.0), (22.0, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.5, 8.3), [builder, debian slim plus gcc], size: 6.5pt)
  cdraw.content((11.5, 6.9), [sha256-checked tarball, make linux, run.lua green], size: 6pt)
  cdraw.line((11.5, 5.7), (11.5, 4.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 5.1), [the binary, the tree, nothing else], size: 6pt)
  cdraw.rect((3.4, 1.2), (19.6, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 3.6), [runtime, debian slim], size: 6.5pt)
  cdraw.content((11.5, 2.7), [one static binary plus the lua files], size: 6pt)
  cdraw.content((11.5, 1.8), [uid 1000, no lua interpreter, no curl], size: 6pt)
})

== compose one command

The compose file is one service and its replay sibling, and the
contract it enforces is the return value of a single command.
`docker compose up -d --build --wait` builds, starts, and blocks until
the healthcheck passes, so a green up means the interpreter compiled,
the lane proved itself in the builder, the edge bound its listener,
and the probe answered. The probe is the image probing itself: no curl
exists in the runtime, so the healthcheck runs the same binary in
client mode against its own loopback, one flag apart from the server.
The published port is the reserved 19490 fronting the container's
19480, keeping a running stack off the local winsock lane's port, and
the ops listener is declined: this kernel owns one listener, metrics
already ride the main mux:

#listing("lua/service/compose.yml", first: 13, last: 30, caption: [the probe timing anchor, one service, the self-probe, the reserved port fronting it])

No volume exists, and the absence is the statement: the oracle is this
vm's memory, a restart starts from zero, durability is the jit engine's
file store. The file also lacks a stop grace period, because this drain
concludes with the in-flight connection.

#diagram([what a green up proves, in order], length: 13pt, {
  let step(x, w, top, sub) = {
    cdraw.rect((x, 4.6), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), [#top], size: 6.5pt)
    cdraw.content((x + w / 2, 5.4), [#sub], size: 6pt)
  }
  step(0.8, 4.4, [build], [tarball checked, lane green])
  step(6.2, 4.4, [start], [uid 1000, one listener])
  step(11.6, 4.4, [probe passes], [the binary asks itself])
  step(17.0, 4.4, [--wait returns], [the stack is a fact])
  cdraw.line((5.3, 5.8), (6.1, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.7, 5.8), (11.5, 5.8), stroke: luma(100))
  cdraw.line((16.1, 5.8), (16.9, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.5, 3.2), [down -v wipes everything, the next run starts at zero], size: 6pt)
})

== the docker lane as a gate

The lane is one make target with the sibling lanes' shape: a daemon
preflight that fails loudly instead of skipping, teardown under a trap
on every path, and the replay leg as the gated step. One lesson cost a
stale image and sits in the build line: `up --build` never builds a
service whose profile is inactive, so the lane builds with the profile
named, and the replay container runs one-shot over the compose network
with its exit code as the verdict:

#snippet(
  "verify-lua-docker:\n"
  + "\t@docker info >/dev/null 2>&1 || { echo \"docker daemon not reachable.\" >&2; exit 1; }\n"
  + "\t@cd books/lua/service && docker compose down -v >/dev/null 2>&1 || true && \\\n"
  + "\t\ttrap 'docker compose down -v' EXIT && \\\n"
  + "\t\tdocker compose --profile lane build && \\\n"
  + "\t\tdocker compose up -d --wait && \\\n"
  + "\t\tdocker compose --profile lane run --rm replay; rc=$$?; exit $$rc",
  lang: "makefile",
)

The nine scenarios replay the contract's guarantees at the layer the
frozen bytes cannot reach over a wire: the register replay byte
identical, the two 401 shapes differing only in their request id, the
etag pair, the stale patch guard, the last admin chain, the
exposition, and the reports pair's upgrade. The rate limit scenario is the most honest platform
statement: every credential-shaped login miss pays the issue-tier
pbkdf2 before its 401, measured around twenty seconds per answer over
this wire, and six of those cannot fit the bucket's one-token refill
second, the flattened cost being the feature that stops account
enumeration. The lane trips the same bucket with the decode-refusal
shape the bind ladder rejects before any verify runs, the sixth read
the 429 with its retry-after, where the frozen vector pins the same
arithmetic at zero cost. The suite chapter owns the test shapes and
the swap, the conc chapter the idem semantics, the load chapter the
offered-load harness and the p99.

#diagram([the lane: preflight, build with the profile, up, replay, teardown on every path], length: 13pt, {
  let box(x, w, top, sub) = {
    cdraw.rect((x, 4.8), (x + w, 7.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.5), [#top], size: 6.5pt)
    cdraw.content((x + w / 2, 5.6), [#sub], size: 6pt)
  }
  box(0.6, 3.6, [preflight], [no daemon is a red])
  box(4.8, 4.4, [profile build], [up skips profiles])
  box(9.8, 3.6, [up --wait], [healthy means probed])
  box(14.2, 3.8, [replay], [nine scenarios])
  box(18.6, 3.6, [trap], [down -v, always])
  cdraw.content((11.5, 3.4), [it caught the anonymous 202 the suites missed], size: 6pt)
})

sources: the lua 5.5 manual section 6.9, operating system facilities,
for `os.getenv`, and the lua.org ftp page plus the 5.5 readme for the
`linux` target and `liblua.a`, at lua.org, accessed 2026-09-28.
Docker's documentation for multi-stage builds, `up --wait`,
healthchecks, profiles, and build, at docs.docker.com, accessed
2026-09-28. The linux man-pages via man7.org for `signal(2)` and
`sigaction(2)` on `SA_RESTART`, `poll(2)` on `EINTR`, and `send(2)` on
`MSG_NOSIGNAL`, accessed 2026-09-28. Verified by the service plain
lane at 188 checks on the landed tree, the host lane at 162 and the
jit lane at 18 both green, and the docker lane end to end under
`make verify-lua-docker`, nine wire scenarios, the trap teardown
observed, the stopped container's zero exit read from its state.
