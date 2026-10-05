#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= concurrency control

Chapter 10 built the thread ladder and measured the thread itself.
This chapter owns the question underneath a running service: what
limits anything. The kernel's executor is
`newVirtualThreadPerTaskExecutor`, one virtual thread per request, no
queue, no cap, no rejection, and that is correct for the thread but
silent about every other resource. A flood of requests is a flood of
threads, each holding heap, an open exchange, and a turn at whatever
the handler touches, and unlimited concurrency is just unbounded
memory with extra steps. The service answer is three layers built
over this chapter and the two after it: admission control in
`javabook.conc`, the bounded state tables of `javabook.cache`, and
the fairness budget of `javabook.limit`. The go book walked the same
territory from the lost update up, #xref-to("go", "conc"), and its
singleflight and admission material lands here in java's shapes,
with the lost update itself closing the chapter as the promise
chapter 21 made and this one keeps.

== thread-per-request removes a cap that was doing work

A platform-thread pool of 200 was a crude load shedder by accident:
request 201 waited in the pool's queue and timed out there. Virtual
threads deleted the pool, deleted the queue, and deleted the
rejection handler with it, so the service must rebuild all three on
purpose. The jep 444 wording is the design center and worth quoting
exactly: virtual threads "are cheap and plentiful, and thus should
never be pooled", and code that needs to cap concurrent access to a
limited resource should use "constructs specifically designed for
that purpose, such as semaphores". That sentence is this chapter's
whole architecture: not a pool, a semaphore at the door.

What the flood actually costs is not thread creation, and the next
section measures that honestly, it is the resources the threads hold
while parked or running: heap for the stack chunks, file descriptors
and buffers for each open exchange, and turns at the carriers while
a handler computes. Backpressure is the name for refusing work
before those costs pile up, and its two knobs are how much may run
at once and how long the rest may wait.

== one hundred thousand threads, measured

#listing("java/samples/src/Ch25/Scale.java", first: 19, last: 32, caption: [100,000 virtual threads spawned, started, and joined, timed])

Measured 2026-10-05 on this machine, 20 reported cores, the pinned
build 27+35-2325: 100,000 virtual threads spawned, started, and
joined in 111 ms, 1.12 microseconds per thread, and all 100,000 were
simultaneously alive at a latch, each parked on the heap, the 20
carriers free for other work. The platform comparison in the same
sample creates, starts, and joins 2,000 platform threads one at a
time, 85.11 microseconds per thread, a ratio of 76 platform-thread
costs per virtual-thread cost, before touching the 1 mb default
stack reservation that makes stacking 100,000 of them a memory
planning question rather than a rounding error. The lesson is not
that virtual threads are fast, it is where the bottleneck moved:
creation is noise, so anything that limits a virtual-thread service
limits the resources the threads hold, never the threads
themselves.

#diagram([the cap moved: pools capped threads, the service must cap what threads hold], length: 13pt, {
  pane(0.3, 10.3, 7.8, [the pool era], [200 platform threads], [request 201 queues])
  cdraw.line((5.3, 5.5), (5.3, 4.5), stroke: luma(100), mark: (end: ">>"))
  pane(0.3, 10.3, 4.2, [the virtual era], [threads unbounded], [cap the holdings, not the threads])
  cdraw.line((10.5, 6.0), (11.3, 6.0), stroke: luma(100), mark: (end: ">>"))
  pane(11.5, 22.5, 7.8, [what a flood costs], [heap, descriptors, buffers,], [carrier turns while computing])
  cdraw.content((11.5, 2.4), [jep 444: never pool them, use a semaphore], size: 6pt)
})

== executor sizing, the question that came back

Virtual threads answered sizing for blocking work by deleting it,
and cpu-bound work puts the question right back. A carrier runs one
mounted virtual thread at a time, a thread that computes for a
second holds its carrier for a second, and enough of them starve
every blocked-and-unmountable thread behind them. So the hybrid is
the standing rule: virtual threads where the work waits, a fixed
platform pool sized to the core count where the work computes, and
the two meet when a request's virtual thread submits its compute to
the sized pool. The pinned build's own `ThreadPoolExecutor` is that
pool, and its constructor is where bounded queues and rejection
policies live:

#listing("java/samples/src/Ch25/Bounded.java", first: 67, last: 82, caption: [one measured run: core count threads, a 4-slot queue, a rejection handler])

The four shipped handlers are four sentences. `AbortPolicy` throws
`RejectedExecutionException`, loud refusal. `CallerRunsPolicy` runs
the overflow on the submitting thread, backpressure that slows the
producer to the consumer's pace. `DiscardPolicy` drops the task
silently, and `DiscardOldestPolicy` drops the queued head to make
room for the new. Measured 2026-10-05, 20 cores, 100 tasks of 25 ms
submitted flat out: abort completed 24 and refused 76, caller-runs
completed all 100 with the main thread running 12 of them itself,
and the virtual-thread executor ran the same 100 sleeps in 38 ms
with no sizing knobs at all, because sleeps block and blocking
unmounts. For request work the silent discards are disqualified on
their face, a dropped request is an unexplained timeout to its
client, so the choice is refuse loudly or push back, and the
admission layer below is the refuse-loudly answer at the http door.

== admission control

The semaphore the jep names, as a filter. At most `permits` requests
are inside the stack at once, an arriving request beyond the cap
waits up to `maxWaitNanos`, and one that waited out its budget is
refused with the 503 overload envelope and a `Retry-After`:

#listing("java/api/src/javabook/conc/Admit.java", first: 61, last: 83, caption: [tryAcquire with a budget, refuse with the overload envelope, release in the finally])

Three decisions carry the weight. The wait is the bounded queue:
`tryAcquire` with a timeout parks the request's own virtual thread,
a parked virtual thread costs its few hundred bytes, so the queue is
as long as the clients make it and exactly as patient as the budget.
The refusal is the rejection policy, and it is the overload code
chapter 19 reserved for exactly this, mapped through the kernel's
one envelope writer. And the release lives in a `finally`, because
the one leak that matters in an admission layer is the permit that
never comes back: the tests pin it against a handler that returns, a
handler that throws past the adapted route, and a flood of 50
requests against 4 permits where every request answers, 200 or 503,
none lost. The interrupt lane answers overload too, restores the
flag, and leaves the semaphore untouched.

The answer is written, never thrown, the same fact chapter 22's
authn coded against: the kernel's `ApiError` adapter wraps the route
handler at the bottom of the chain, so a filter exception would
climb past it unanswered and drop the connection. The leak test is
the one worth reading whole, because an admission layer that leaks
permits turns every error into a capacity cut:

#listing("java/api/test/javabook/conc/AdmitTests.java", first: 122, last: 132, caption: [the throw climbs past the adapted handler, the exchange dies, and the finally still releases])

== where the pair sits in the stack

The rate layer of chapter 27 lands next to this one, and the wiring
order between them is contract. The cheap decision runs first: a
rate check is a map lookup and an arithmetic take, so a flooding
client collects 429s without ever being granted a queue wait, and
admission's budget is spent only on traffic that already passed the
fairness gate. Both sit inside the access log and timing, so a shed
request is logged as the 503 or 429 the client saw, the chapter 20
order rule applied to two more layers:

#listing("java/api/src/javabook/Main.java", first: 66, last: 75, caption: [the load-shedding pair in the stack, rate outside admission, both inside the log])

The permit count in the wiring is `max(64, 8 per core)`, a blocking
handler holds its permit across io so the number wants headroom over
the core count, and the wait budget is 500 ms, about half a round
trip of client patience. Both are constructor arguments, not
constants burned into the class, because the right numbers are a
deployment fact.

== pinning, one paragraph

Chapter 10 measured it and this chapter only inherits the
conclusion: `synchronized` no longer pins, jep 491 since 24, the
1,000 sleeper probe ran 64 ms against a 2,000 ms pinning floor, so
the monitors in this book's store and limiter are safe under virtual
threads. What still pins on 27 is native frames on the stack,
blocking inside class initialization, and jni or foreign calls that
block in native code, which is why the store chapter's file channel
work and this chapter's semaphore wait are the shapes to keep: both
unmount.

== structured task scope, waiting to land

Handler-level fan-out, one request racing two backend calls and
cancelling the loser, is the shape the jdk has been previewing since
21 and still previews in 27, jep 533, the seventh preview:

#snippet("try (var scope = StructuredTaskScope.open()) {\n  var left = scope.fork(() -> fetchLeft());\n  var right = scope.fork(() -> fetchRight());\n  scope.join();\n  // one scope, one lifetime: both subtasks are done or cancelled here\n}", lang: "java")

It compiles only under `--enable-preview`, so it lives here as a
snippet and never rides the samples runner, the wave's standing
rule. The pairing to watch is scoped values, chapter 10's other
final feature: a scope's forked children are exactly the threads
that inherit its bindings, which is why the two apis grew up
together and why the fan-out above is also the context-propagation
story a service needs.

== compare-and-swap, the promise chapter 21 made

Chapter 21 parked the user's version member as the substrate for
optimistic concurrency, and this is the mechanism and the route that
spend it. The lost update is the oldest race in the book: two
readers fetch version 3, both write back, and one overwrite
silently wins. The lock-free answer is compare-and-swap,
`AtomicReference`'s one instruction: set the value to the candidate
only if it is still the expected one, and let the loser re-read and
retry.

#snippet("var box = new java.util.concurrent.atomic.AtomicReference<Long>(3L);\n\n// thread A and thread B both hold the version 3 they read\nboolean aWon = box.compareAndSet(3L, 4L);  // true\nboolean bWon = box.compareAndSet(3L, 5L);  // false: the world moved\n\n// bWon is false, so B re-reads, merges onto 4, and tries again\n// losing is detected, never guessed at", lang: "java")

The update scope turns that instruction into a route family:
`PATCH /api/users/\{id\}` carrying `If-Match`, answered by the 412
precondition code on the stale version and the version bump on the
win. The stack answers in three layers, fast fail, invariant,
atomicity. Fast fail is the handler: the If-Match is required, a
missing header answers 412 before any decode work runs, the choice
the go book made for the same route over the 428 the rfc merely
suggests, and the header is checked against the current etag before
the body is read:

#listing("java/api/src/javabook/user/Users.java", first: 90, last: 125, caption: [existence, then the precondition, then the decode: the stale request never burns a parse])

The invariant is the version member, and the comparison runs the
rfc's If-Match rules, which differ from the If-None-Match two
sections below it in exactly one word: the comparison is strong. A
star matches any current representation, a list matches when the
etag appears in it, and a weak `W/` form never matches, where the
304 lane counts it. A sender may split the list across repeated
header lines, and the read combines them into one list before it
compares, the comma join the rfc's field-value grammar allows. The
star's truth is evaluated where the precondition is, at the read,
so a writer landing between that read and the swap still meets the
swap's own 412 and a retry succeeds, the precondition is a gate,
not a reservation:

#listing("java/api/src/javabook/user/Users.java", first: 127, last: 144, caption: [ifMatch: strong comparison, star and list carry, weak never matches])

And the atomicity is the store's, the only layer that is. The port
grew one method, `update` gated on the version the caller read, and
the file implementation rides the whole compare-and-swap inside one
engine write transaction: the version check, the email claim swap,
and the record write commit or discard together, because chapter
24's full lock across a transaction makes the check atomic with the
write it gates:

#listing("java/api/src/javabook/store/FileStore.java", first: 60, last: 89, caption: [the CAS in one write transaction: check, swap the claim, bump, commit, or discard whole])

The proof is the duel, two PATCHers carrying the same valid etag,
released together by one barrier. Both may pass the handler's
check, only the swap decides, and every run answers exactly one 200
and one 412 with version 2 standing after:

#listing("java/api/test/javabook/user/UserResourceTests.java", first: 358, last: 392, caption: [the duel: one barrier releases both writers, the store's CAS crowns one])

Around the duel sit the contract's edges, each its own test: the
missing and the stale and the weak and the list-without-the-etag
refused, the star and the carrying list accepted, the bump serving
a fresh etag that feeds the chapter 21 conditional read, the email
claim following the patch in both directions with the freed address
registrable again, json null members decoding as the leave-alone
form while every member null still leaves nothing to update, the
patch validation lanes including the empty object and a display
name ceiling counted in characters rather than utf-16 units, and
the unknown id answering 404 before any precondition work. The
store side pins the same swap at its own level, the stale version
refused, the claim swap atomic, the bumped record surviving a
reopen with its hash intact, and the guarded wiring pinning the
policy row the route rides, anonymous 401, stranger 403, owner and
admin 200.

The chapter's own tests are five over a real socket: three permits
serving three concurrent slow requests, the fourth refused after its
budget with the envelope and the header, the permit returned on
completion and on a handler throw, and the 50-request flood against
4 permits losing none. Twenty-nine tests land across the three
packages of this wave, 14 in the cache chapter and 10 in the rate
chapter, and the update scope adds 12 more over the user and store
packages, green three consecutive runs with the module lane green
beside them.

sources: jep 444 at openjdk.org/jeps/444, the pooling prohibition and
the semaphore guidance quoted from its text, accessed 2026-10-05. Jep
491 and the pinning measurement are chapter 10's, re-verified there
2026-10-04 against openjdk.org/jeps/491. Jep 533, structured
concurrency seventh preview in 27, verified 2026-10-05 at
openjdk.org/jeps/533. Rfc 9110 section 13.1.1, the If-Match strong
comparison mandate, the star rule, and the lost-update framing,
read from the full text at rfc-editor.org, accessed 2026-10-05.
The rejection policy semantics read from the
pinned build's own `ThreadPoolExecutor` sources,
`tools/jdk27/build/jdk-27/lib/src.zip`, oracle jdk 27 ga build
27+35-2325, accessed 2026-10-05. `Semaphore.tryAcquire` timeout
semantics and `AtomicReference.compareAndSet` from the same src.zip.
Measurements (100,000 virtual threads in 111 ms at 1.12 microseconds
per thread, 2,000 platform threads at 85.11 microseconds each, ratio
76.1, 100,000 simultaneously alive, abort 24 completed 76 refused,
caller-runs 100 completed with 12 on the caller, the same 100 sleeps
in 38 ms on the virtual executor, 20 reported cores) produced by
`java/samples/src/Ch25` under
`pwsh tools/run-java-samples.ps1 -Chapter Ch25`, dated 2026-10-05.
Verified live 2026-10-05 by the `javabook.conc` tests under the
vendored junit 6.1.3 lane, 5 tests green, 29 across this wave's
three packages, and the update scope verified by the `javabook.user`
and `javabook.store` tests, 47 green three consecutive runs, 133
across the module, the duel answering one 200 and one 412 every
run.
