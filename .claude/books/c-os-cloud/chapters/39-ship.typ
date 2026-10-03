#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= ship it

Twelve chapters built a service one family at a time, and every one of
them ended wired, tested, and parked. This chapter is the parked
part's opposite: `main.c` is the whole composition on one screen, the
config story names the two values the process refuses to guess, the
resource families wire their three calls in the order the guard
demands, the internal listener lands the second bind chapter 37
promised, and a real process runs the whole stack over the wire on
the lane's pinned port pair and stops on ctrl+c with the drain's own
exit code. Composition is where the families meet for the first time,
where every integration defect lives, and the chapter's discipline is
the live run: the claims are a captured transcript, not a prediction.

== the composition root

Go's `main.go` wires a service behind a framework's `ListenAndServe`,
and the c lane has no framework, so the composition root is 63 lines
of plain c23 that the chapters grew one call at a time. The shape is a
fixed prefix and suffix with the families between them, and the
comment at the top of the file is the contract: config first, kernel
seams second, each family's wiring in the order the middleware
chapter fixed, the public listener last, so a family can never wire
itself after the server starts serving, because `capi_run_tcp` does
not return until the server stops. Every call that can fail is
checked and exits 1 with the failing step's name on stderr, because a
half-wired service is worse than one that dies loudly:

#listing("c-os-cloud/api/src/main.c", first: 11, last: 24, caption: [the root's opening: config, seams, kernel, the first families, each refusal its own line])

#diagram([the root as one ordered stack, the listener pinned at the bottom], length: 13pt, {
  let row(y, title, sub, fill) = {
    cdraw.rect((2.0, y), (21.0, y + 1.35), fill: fill, radius: 0.02)
    cdraw.content((11.5, y + 0.82), [#title], size: 6pt)
    cdraw.content((11.5, y + 0.22), [#sub], size: 6pt)
  }
  row(7.2, [the config story], [db path, secret, fail closed], luma(235))
  row(5.7, [kernel seams + middleware + ops setups], [clock, ids, ten layers, each checked], luma(230))
  row(4.2, [users, authn, authz last], [the guard audits every row], luma(225))
  row(2.7, [internal listener, ctrl handler], [the run surface], luma(220))
  cdraw.rect((2.0, -0.3), (21.0, 0.75), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 0.2), [capi_run_tcp, last, serves until it stops], size: 6pt)
})

== the config story

Two values decide everything the families cannot derive: where the
database file lives and what the jwt secret is. The lane's answer is
argv plus the environment, no config library, the vehicle's standing
bias. The database path has a precedence a reader can recite, argv
first, `CAPI_DB` second, `capi.db` in the working directory last. The
secret has exactly one source: a secret passed as an argument lands in
a process listing the whole machine can read, so the argument is not
an option, `CAPI_JWT_SECRET` or nothing, and nothing is a refusal,
not a default, because a service signing tokens with an empty key is
a running vulnerability. The bounds are the code's own: under 16
bytes is too thin for an hs256 key, over 63 cannot fit the service
struct's secret field, and both refuse with the bound in the message:

#listing("c-os-cloud/api/src/ship.c", first: 47, last: 68, caption: [the secret's one source and three refusals, the bounds stated in the messages])

#diagram([the precedence for the db, the single source for the secret], length: 13pt, {
  pane(0.4, 6.4, 6.2, [the db path: argv[1]], [else CAPI_DB], [else capi.db])
  cdraw.content((17.6, 7.9), [the secret], size: 6.5pt)
  pane(13.4, 21.8, 6.7, [CAPI_JWT_SECRET], [16 to 63 bytes, no default], [never an argument, a listing reads argv])
  pane(13.4, 21.8, 3.6, [empty refuses], [under 16 refuses], [over 63 refuses])
})

The environment reads go through `GetEnvironmentVariableA`, kernel32's
own window onto the environment block, the same dodge the kernel uses
for `CAPI_ADDR`: the ucrt's `getenv` declaration is deprecated and the
vehicle calls the platform's direct surface. The addresses belong to
their listeners: `CAPI_ADDR` is the kernel's variable with its
`:8080` default, the internal listener reads `CAPI_METRICS_ADDR` with
a loopback `:19390` default, two names a deployment sets, not flags a
library parses anywhere.

== the wiring order and its failure modes

Three calls sat declared and unwired since the resource families
landed, and the order they land in is load-bearing. `capi_wire_users`
goes first because everything downstream reads from it: the dll load
asserts the 3.53.4 version pin, the pool opens four slots with slot 0
held for the roles and idem statements, the migrations apply under
their `user_version` pragma, the statements build once per slot.
`capi_wire_authn` goes second with the config's secret, arming the
signer and resetting the session table. `capi_wire_authz` goes last,
strictly last, because the guard walks the router's real
route table against the policy table and refuses on any route without
a policy row, and a guard that runs before a family registers audits a
table that is not finished:

#listing("c-os-cloud/api/src/main.c", first: 40, last: 54, caption: [users, then the secret, then the guard, each failure its own exit])

#diagram([each setup with its own refusal, walked in start order], length: 13pt, {
  let step(x, title, refuse) = {
    cdraw.rect((x, 4.6), (x + 5.4, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + 2.7, 6.3), [#title], size: 6.5pt)
    cdraw.content((x + 2.7, 5.35), [#refuse], size: 6pt)
    cdraw.line((x + 5.5, 5.8), (x + 6.3, 5.8), stroke: luma(100), mark: (end: ">>"))
  }
  step(0.4, [users], [dll, pool, migrate, stmts])
  step(6.6, [authn], [the secret is armed])
  step(12.8, [authz last], [missing policy rows counted])
  cdraw.rect((19.0, 4.6), (23.6, 7.0), fill: luma(205), radius: 0.02)
  cdraw.content((21.3, 5.8), [serve or exit 1], size: 6pt)
})

A policy row that names a route not yet mounted only warns, because a
forward-looking row is not a hole, while a route without a row refuses
the whole startup. The asymmetry is the guard's stance: deny by
default is proven before the process serves one request, not hoped
for at request time.

== the internal listener

Chapter 37 split the surfaces and the split lands as a second bind.
The same one route table serves both listeners, so the public
listener on 19380 answers `/metrics` too, and the internal listener's
loopback bind on `CAPI_METRICS_ADDR`, default `:19390`, gives
operations a scrape address of its own. Keeping `/metrics` off the
public listener entirely would need a per-listener route filter, a
kernel seam this lane chose not to add, and that stated cost is the
one-table ruling's trade: one router, one dispatch, the boundary is
the bind address an operator controls. The loop is one thread, one
connection at a time, one context per scrape from the heap, scrapes
rare, the steady request path allocation-free:

#listing("c-os-cloud/api/src/ship.c", first: 100, last: 123, caption: [the internal loop: accept, check the stop flag, one context per scrape through the kernel's serve path])

#diagram([two binds, one route table, the boundary is the bind], length: 13pt, {
  pane(0.4, 10.6, 6.8, [public listener], [CAPI_ADDR, wildcard ok], [the whole table, /metrics too])
  pane(13.4, 23.6, 6.8, [internal listener], [CAPI_METRICS_ADDR, loopback], [the whole table, ops scrapes here])
  cdraw.line((5.5, 3.6), (5.5, 2.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((18.5, 3.6), (18.5, 2.9), stroke: luma(100), mark: (end: ">>"))
  pane(8.2, 15.8, 2.9, [one route table], [one dispatch], [no per-listener filter])
})

Stopping the loop is its own platform lesson. A blocking `accept` on
windows is not documented to wake when another thread closes the
socket, so the stop path sets a flag and connects to its own listener
once: the accept returns, the thread sees the flag on the wake
connection and exits. The test binds `127.0.0.1:0`, scrapes the
ephemeral port, and proves the bind is gone by the refused connect.

== the live run

The lane pins a port pair like its siblings, 19380 for the service
and 19390 for metrics, and the transcript is a committed capture of a
real process on a fresh database. The banner names both listeners,
the probes answer, and the scrape on the internal port renders the
exposition chapter 37 froze:

#listing("c-os-cloud/api/captures/2026-09-27-ch39-walkthrough.txt", first: 5, last: 22, caption: [the run's opening: two env names, the banner, the health probe])

#diagram([the run's arc, one transcript behind every claim], length: 13pt, {
  let stage(x, w, title, sub) = {
    cdraw.rect((x, 4.6), (x + w, 7.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, 6.3), [#title], size: 6.5pt)
    cdraw.content((x + w / 2, 5.35), [#sub], size: 6pt)
  }
  stage(0.4, 4.6, [start], [config, wiring, banner])
  stage(5.8, 4.6, [probe], [healthz, readyz 200])
  stage(11.2, 4.6, [walk the contract], [register through logout])
  stage(16.6, 4.6, [scrape], [19390, the exposition])
  stage(21.6, 2.0, [stop], [drain])
  cdraw.line((5.1, 5.8), (5.7, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((10.5, 5.8), (11.1, 5.8), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((15.9, 5.8), (16.5, 5.8), stroke: luma(100), mark: (end: ">>"))
  pane(0.4, 23.6, 2.2, [the port pair], [19380 service, 19390 metrics], [siblings pin 19280, 19290])
})

The capture is dated and toolchain-labeled under the chapter 20
measurement discipline: committed data, never re-run by the verify
chain, because a transcript that runs on every build is a flaky test
wearing a lab coat.

== end to end over the wire

The walkthrough exercises the contract the vectors froze, with a real
clock, real uuids, and the full ten-layer stack in the path. Ada
registers and the answer carries the three rate headers, the
`Location`, and the strong `ETag`, the shape vector 01 pins. The same
key over the same bytes replays the stored snapshot, byte identical,
no second row, the idempotency chapter's guarantee over a real
socket:

#listing("c-os-cloud/api/captures/2026-09-27-ch39-walkthrough.txt", first: 35, last: 50, caption: [the register over the wire, the rate headers and the strong etag on a real 201])

#diagram([the request ladder, each rung a contract chapter's guarantee], length: 13pt, {
  let rung(y, label, right) = {
    cdraw.rect((0.6, y), (11.4, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((6.0, y + 0.5), [#label], size: 6pt)
    cdraw.content((12.0, y + 0.5), [#right], size: 6pt)
  }
  rung(7.6, [register, then the replay], [201 + headers, byte-identical again])
  rung(6.3, [login, list, get, patch], [cookie, bearer, keyset, 412 on stale])
  rung(5.0, [the reports pair], [202 pending, read flips done, replay 200])
  rung(3.7, [the concurrent burst], [4, 3, 2, 1, 0, then the 429])
})

The login hands back the session cookie and the bearer token, the list
walks the keyset cursor with the bearer naming the caller, the patch
on `If-Match` lands and returns version 2, and the same etag replayed
against the changed row answers the 412, the conditional-write story
riding the store's compare-and-swap. The reports pair rides the same
bearer: the create answers 202 pending with the `Location` and
demands the `Idempotency-Key`, its absence is the 422, the first
read computes the series and flips the row done, the replay answers
200 with the read's exact bytes. The wrong-password ladder is a
concurrent burst, 6 logins inside one second, because a sequential
ladder refills faster than pbkdf2 spends, and the remaining column
reads 4, 3, 2, 1, 0 across the five allowed draws before the sixth
answers the 429 with `Retry-After`, the contract's five drawn once
each. That column is also this chapter's argument: the walkthrough's
first capture caught the login route drawing twice, once through the
layer's rule and once inside the handler, invisible to every family's
isolated harness because each replayed vector 06 alone, and the
ruling that followed gives the layer every draw, one drawer like the
one failure writer. The logout consumes the cookie, and the scrape
closes the loop with every route counted and histogrammed.

== shutdown over the drain

A service that only dies has no shutdown story, and windows gives a
console process exactly one hook for the polite version: the console
control handler. The handler runs the drain chapter's order as three
lines. Readiness flips first, `srv.draining` is the flag `readyz`
reads, so the probe answers the overload envelope from the first line
on and any load balancer watching stops routing here. The drain joins
second, over the gate the load family wired. The exit code is third,
0 drained, 1 grace expired with work inside:

#listing("c-os-cloud/api/src/ship.c", first: 305, last: 336, caption: [the stop order as one function, and the console handler that exits with its code])

#diagram([readiness, join, exit code, in that order, once], length: 13pt, {
  let hit(x, label) = {
    cdraw.circle((x, 4.6), radius: 0.28, fill: luma(160))
    cdraw.content((x, 5.5), [#label], size: 6pt)
  }
  cdraw.line((0.6, 4.6), (23.4, 4.6), stroke: luma(120))
  hit(2.0, [ctrl+c arrives])
  hit(7.0, [draining = 1])
  hit(12.0, [readyz answers 503])
  hit(17.0, [drain joins the gate])
  hit(21.6, [exit 0 or 1, the transcript's last line])
})

The honest statement about today's surface: the gate is wired, the
serve path draws an admission slot around every request, and the
drain joins those holders for real, so the wait ships with the
order. The join's scope is the stack and not the wire: a slot
releases when the answer exists, before the serve loop writes it, so
the exit can still cut a response mid-send where the go lane's
Shutdown waits for the connection to go idle, a boundary the ship
source's own comment states so prose and code cannot drift apart. The
accept loop owns the listener's
life, so the handler's exit is the process's exit. The transcript
closes with the handler's own lines and the exit code the wait
returned, and getting the signal there took two platform facts: a
group-0 signal did not reach the service while its group id belonged
to a parent on another console, and a group created with
`CREATE_NEW_PROCESS_GROUP` has plain ctrl+c disabled by rule, so the
capture harness spawns the service as its own group and sends
ctrl+break, which the handler treats identically. The tests pin the
order with a composed in-flight request and a 40 millisecond grace,
the deadline doing its job.

== the shipped checklist

The service part ends the way the go book's ship chapter ends, with
every family's property named next to the place it is proven. Each row
is a behavior the lane observes, and the lane that observes them all
is the one this chapter built:

#diagram([twelve chapters, twelve properties, all proven by the lane], length: 13pt, {
  let cell(x, y, w, l1, l2) = {
    cdraw.rect((x - w / 2, y - 0.55), (x + w / 2, y + 0.55), fill: luma(235), radius: 0.02)
    cdraw.content((x, y + 0.18), [#l1], size: 6pt)
    cdraw.content((x, y - 0.28), [#l2], size: 6pt)
  }
  cell(5.9, 8.3, 10.0, [28 kernel: one envelope], [11 codes, one writer])
  cell(17.1, 8.3, 10.0, [29 middleware: ten layers], [id, log, metrics, admission, limit, deadline, precond, idem, cache, guard])
  cell(5.9, 6.9, 10.0, [30 users: validation], [plus the keyset cursor])
  cell(17.1, 6.9, 10.0, [31 authn: pbkdf2 proofs], [hs256 and the session table])
  cell(5.9, 5.5, 10.0, [32 authz: the policy walk], [owner or admin, audited rows])
  cell(17.1, 5.5, 10.0, [33 store: wal and cas], [versioned migrations])
  cell(5.9, 4.1, 10.0, [34 conc: the duel], [etag plus idempotent replay])
  cell(17.1, 4.1, 10.0, [35 cache: lru with ttl], [and the stampede guard])
  cell(5.9, 2.7, 10.0, [36 limit: token bucket], [429 with Retry-After])
  cell(17.1, 2.7, 10.0, [37 obs: one writer], [traceparent, the exposition])
  cell(5.9, 1.3, 10.0, [38 load: gate and drain], [p99 both honest ways])
  cell(17.1, 1.3, 10.0, [39 ship: the lane], [the transcript proving all of it])
})

#listing("c-os-cloud/api/src/main.c", first: 55, last: 63, caption: [the run surface: the internal listener, the handler, the listener that serves])

The suite chapter that follows hardens the set. What this chapter
owns is the band between a green build and a running service: the
config that refuses to guess, the order that refuses to serve
half-wired, the second bind, and the transcript that keeps the
contract honest over a real socket.

sources: learn.microsoft.com's console pages for SetConsoleCtrlHandler
and GenerateConsoleCtrlEvent with its process group semantics, the
processthreadsapi pages for CreateProcessW's CREATE_NEW_PROCESS_GROUP
flag with its ctrl+c rule for created groups and for ExitProcess, and
the winsock2 pages for bind, listen, accept, and closesocket, all
accessed 2026-09-27, the w3c and prometheus references inherited from
chapters 37 and 38, and the sqlite.org C API pages chapter 33 pins.
Verified by the ship family's 42 checks in the lane's runner under
the pinned clang 23, the walkthrough captured from a real process on
ports 19380 and 19390, the lane's gate green with the family
included, plus clang-format over every file touched.
