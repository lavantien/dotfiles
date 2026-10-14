#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= capstone: an async runtime from scratch

The service part of this book runs on threads: chapter 19's kernel is a
bounded pool with one thread per connection, and it holds that shape
through chapter 31 because std gives no other road. This chapter builds
the other road. The crate `runcap` under `books/rust/capstone` is an
async runtime with zero dependencies: a work-stealing-free executor over
one task queue, a hashed timing wheel on its own thread, a fixed
`spawn_blocking` pool bridged over channels, a poll-loop reactor for
nonblocking tcp, and a fan-out server composed from all four, 1765
lines of source across 7 files and 36 tests, every one green under
`cargo test --locked` with `CARGO_NET_OFFLINE=true` on the pinned
1.99.0 build, dated 2026-10-13. The suite is 783 lines of tests in
five files plus a 66-line shared line-client harness, and the crate
carries no `unsafe` and no dependency, one package in `Cargo.lock`.
Chapter 14 built the parts by hand
in miniature, poll and waker and `block_on` as a loop. Everything here
is those parts grown to load-bearing size, and nothing else.

#diagram([the runtime in one picture: four driver threads around one task queue], length: 13pt, {
  cdraw.rect((0.3, 0.3), (21.7, 2.6), fill: luma(222), radius: 0.02)
  cdraw.content((11.0, 1.95), [the task queue: VecDeque of Arc<Task>], size: 6.5pt)
  cdraw.content((11.0, 1.05), [workers pop, poll, park on the condvar], size: 6pt)
  cdraw.content((3.0, 3.85), [wheel thread], size: 6.5pt)
  cdraw.content((3.0, 3.2), [1024 buckets, 1 ms], size: 6pt)
  cdraw.content((8.4, 3.85), [reactor thread], size: 6.5pt)
  cdraw.content((8.4, 3.2), [1 ms readiness poll], size: 6pt)
  cdraw.content((14.0, 3.85), [blocking pool], size: 6.5pt)
  cdraw.content((14.0, 3.2), [4 threads over a channel], size: 6pt)
  cdraw.content((19.2, 3.85), [workers], size: 6.5pt)
  cdraw.content((19.2, 3.2), [2 by default], size: 6pt)
  cdraw.line((3.0, 2.95), (3.0, 2.68), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((8.4, 2.95), (8.4, 2.68), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.0, 2.95), (14.0, 2.68), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((19.2, 2.95), (19.2, 2.68), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.0, 4.65), [every driver resolves into Waker::wake,, which means: push the task back on the queue], size: 6pt)
})

== the smallest executor

A task is a boxed future plus a pointer home. The `Wake` trait, stable
since 1.51, turns an `Arc<Task>` into a `Waker` whose wake is one
operation, push the task on the executor queue, and that single
equivalence is the whole scheduler:

#listing("rust/capstone/src/runtime.rs", first: 73, last: 101, caption: [the task: wake is a requeue, run is one poll under catch_unwind])

Three disciplines live in those 29 lines. The future sits behind a
`Mutex<Option<...>>` so a task parked in the queue and a task being
polled are the same object, and `None` marks completion so a stale wake
of a finished task is a no-op pop. The poll runs under
`catch_unwind`, so a panicking task dies alone, its slot cleared, its
siblings untouched, the worker keeps looping. And the waker is built
from the task's own `Arc`, so cloning it into a reactor slot is one
refcount, the property that makes wakers cheap enough to store
everywhere.

`block_on` is chapter 14's spin loop with the spin replaced by a condvar
park, the same `Arc` state and flag protocol the timer bridge used
there, and workers drain the queue with the same condvar discipline the
chapter 19 pool used for connections:

#listing("rust/capstone/src/runtime.rs", first: 374, last: 394, caption: [block_on: clear flag, poll, park until the waker fires, repeat])

`spawn` wraps the user future in a `JoinWrap` that forwards the output
into a shared slot and wakes whoever awaits the handle, and the handle
is a future itself, so `.await` on a `JoinHandle` parks the awaiting
task until the child finishes. Cancellation is the same drop as chapter
14 taught, now with a witness: if the task dies before completing, the
wrapper's `Drop` marks the state done with no result, and the awaiting
side panics with a message instead of hanging:

#listing("rust/capstone/src/runtime.rs", first: 136, last: 171, caption: [the join bridge: output forwarded on ready, cancellation surfaced on drop])

Measured on the pinned build, dated 2026-10-13: the 3-step self-waking
future from chapter 14's executor, regrown on `runcap`, completes in
exactly 4 polls, 3 pending that each self-wake plus 1 ready. Two tasks
over `Runtime::new(2)` meet a `Barrier(2)` and report exactly 2
distinct thread ids. A task that panics isolates cleanly: its siblings
sum to 16, its own handle panics on await, and the runtime still
serves new spawns afterwards. A handle awaited after its runtime
dropped panics with the cancel message rather than parking forever,
which is the post-shutdown contract tokio also chose: fail loud, never
hang.

== timers, the wheel, and select ordering

Chapter 14's timer was one thread per sleep. The capstone wheel serves
every timer from one thread: entries hash into 1024 buckets by
deadline millisecond, the ticker advances a tick cursor and fires the
bucket whose millisecond has arrived, and the thread sleeps on a
condvar until exactly the earliest pending deadline, so an empty wheel
costs nothing and a far deadline parks rather than spins:

#listing("rust/capstone/src/timer.rs", first: 52, last: 104, caption: [the wheel: hash by deadline ms, advance fires due buckets, earliest drives the sleep])

`Sleep::poll` is the chapter 14 double-check pattern under one lock:
due means ready, otherwise the entry is inserted or its waker
refreshed, and a missing entry means the ticker already fired it, so a
wakeup is never lost while a value sits queued. Dropping the future
removes the entry, and cancellation of a timer is again just a drop:

#listing("rust/capstone/src/timer.rs", first: 212, last: 246, caption: [sleep: due check first, insert or refresh under the wheel lock, drop removes])

Measured 2026-10-13, debug build on windows: a 2 ms sleep delivered in
9.5406 ms and a 2 ms entry with a 10 s entry parked delivered in
13.3590 ms, the honest lateness of a 1 ms wheel under a 15 ms os timer
granularity, and the floor is the only asserted property, delivery
never precedes the deadline. Twenty-six sleeps spanning 1250 ms, more
than one full 1024 ms revolution, fire in exact deadline order with
zero entries left. Five entries at one deadline all fire. A sleep
dropped after one manual poll leaves `pending() == 0`.

Ordering against a second future is the biased race, chapter 14's
`Select2` at two arms, now the runtime's own combinator. It polls the
left arm first, always, which makes ties reproducible and gives
shutdown its shape: a reader racing `read` against `stop` still drains
bytes that arrived before the signal, because readiness on the left
wins the tie:

#listing("rust/capstone/src/runtime.rs", first: 210, last: 223, caption: [the biased race: left arm polled first, first ready wins, the loser is dropped])

== the blocking pool and the io bridge

Std file and socket calls block, a worker must never block, so the
runtime owns a fixed pool of 4 threads fed by one `mpsc` channel, the
bridge chapter 14 built for one timer generalized to any closure. The
worker loop is the whole pool: try the channel, park on the condvar
when empty, drain what is queued before exiting at shutdown, so a
dropping pool finishes its accepted work:

#listing("rust/capstone/src/blocking.rs", first: 78, last: 103, caption: [the pool worker: try_recv under the lock, condvar park, drain before exit])

`spawn_blocking` returns a future over the same slot-and-waker seam the
join bridge uses, with one addition: a panicking job stores its payload
and the awaiting side `resume_unwind`s it, so panics cross the thread
boundary as panics. Measured 2026-10-13: three jobs on a 3-worker pool
meet a `Barrier(3)` and report exactly 3 distinct thread ids, the fixed
pool proven by construction, five jobs on a 1-worker pool run in fifo
order 0 through 4, and a write-then-read of a temp file rides the pool
end to end. Connects take this road too, because std exposes no
nonblocking connect: `AsyncTcpStream::connect` parks the connect on
the pool, then registers the arrived socket with the reactor. The
honest statement is the chapter 19 one restated: what std cannot do
asynchronously, the runtime does on a thread you are not waiting on.

== the reactor and the concurrent server

Std has no readiness API on windows, no epoll, no kqueue, so the
reactor is a level-triggered poll loop: every 1 ms tick it accepts on
registered listeners, peeks registered streams whose readers parked,
and drains outbound queues with nonblocking writes. Readiness is
`peek`, one syscall, `WouldBlock` means not yet, anything else wakes
the parked reader:

#listing("rust/capstone/src/net.rs", first: 126, last: 174, caption: [the reactor tick: accept, probe with peek, pump writes, wake outside the lock])

Two laws in that loop cost real debugging, both dated 2026-10-13. Map
values are never dropped under the reactor lock: an entry's stored
waker can hold the last reference to a task whose future owns a socket
handle, and that handle's `Drop` re-enters the reactor lock, a
self-deadlock that hung the first server test until the maps were
cleared by taking them out and dropping after the unlock. And every
removal wakes its parked futures, so a read parked on a closed entry
observes `NotConnected` instead of sleeping forever.

Reads and writes are futures over the registry, not over sockets. A
`Read` parks by storing the task waker in the entry, a `WriteAll`
commits its bytes to the connection's own outbound queue and completes
when the reactor has drained it, which is exactly the per-connection
outbound queue the fan-out server needs, broadcasts enqueue without
awaiting and shutdown flushes what is queued:

#listing("rust/capstone/src/net.rs", first: 425, last: 460, caption: [read: one nonblocking syscall under the lock, park by storing the waker])

The write side is the same seam turned around: a `ConnWriter` is a
cheap clone of the reactor handle plus the connection id, so the server
can hold one per connection without moving the socket, and its whole
surface is five methods over the registry. `enqueue` appends bytes to
the entry's queue and pokes the reactor, `write_all` is a future that
finishes when the reactor has drained what it enqueued, and `close`
unregisters the entry and wakes whatever was parked on it, the same
wake-after-unlock law the loop obeys:

#listing("rust/capstone/src/net.rs", first: 469, last: 504, caption: [the writer handle: enqueue and poke, await the drain, close wakes the parked])

The server composes every module. Each connection runs a reader task
that races `read` against the stop signal, splits complete lines, and
broadcasts each line to every registered connection. The socket itself
lives in the connection map, not in the task, so a stopped reader
leaves its outbound queue alive for the drain:

#listing("rust/capstone/src/server.rs", first: 144, last: 174, caption: [the reader task: biased race against stop, lines broadcast to the map])

Shutdown is the contract the api lane established in chapter 19,
restated for futures: stop intake first, then wait until every reader
has finished and every queue has drained, bounded by a grace deadline,
then close. The stop signal itself is a waker list, not a slot, one
entry per parked task with `will_wake` dedupe, because the first
version held a single `Option<Waker>` and only the last reader to park
ever woke, measured as one reader of three breaking while the drain
waited on the other two:

#listing("rust/capstone/src/server.rs", first: 252, last: 281, caption: [graceful shutdown: stop, drain readers and queues under the grace, then close])

The demo binary drives the whole stack over its own loopback: 4 client
tasks on the runtime connect, publish 3 lines each, and read all 12
broadcasts, then the server drains. Measured 2026-10-14, 10 runs of 10
green at 0.020 to 0.033 s each: 4 connections, 12 messages, 192 bytes
in, 768 bytes out, drained true, 48 lines delivered. The first version
of that demo hung one run in two, and the fault was not in the runtime
but in the protocol around it, which is the last lesson the capstone
teaches. The barrier that fixed it is four lines of the demo itself:

#listing("rust/capstone/src/main.rs", first: 45, last: 53, caption: [the join barrier: no client writes until the server has accepted all four])

#callout("pitfall", "broadcast reaches accepted connections only, measured", [
  The demo's first version hung at 10 of 12 lines, and the byte ledger
  showed why: two broadcast waves fired in the window after the fourth
  client's connect returned and before the accept task registered that
  connection in the map. The client could write the instant its
  connect completed, the server could only broadcast to connections it
  had accepted, and the lines in between reached the other three and
  not the fourth. The fix is the join barrier every real chat protocol
  carries: the demo waits for `stats().connections == 4` before any
  client writes, exactly the `wait_for_connections` helper the test
  suite already used. A tcp accept is not a join, it is a race you
  must barrier yourself.
])

== what tokio adds

Tokio is this chapter's runtime scaled, and the corpus rule applies:
the library is explained by the std primitives it composes. Chapter 14
built the primitives sidebar, this section only maps.

#snippet(
  "let rt = tokio::runtime::Runtime::new().unwrap();\n"
  + "rt.block_on(async {\n"
  + "    let listener = tokio::net::TcpListener::bind(addr).await?;\n"
  + "    loop {\n"
  + "        let (sock, _) = listener.accept().await?;\n"
  + "        tokio::spawn(handle_conn(sock));\n"
  + "    }\n"
  + "});\n", lang: "rust")

The scheduler is the task queue plus workers, widened with stealing:
tokio's runtime docs, read 2026-10-14, state it executes futures on a
thread pool using a work-stealing strategy, that stealing moves half
of the tasks in one local queue to another, and that a worker thread
starts per cpu core by default. `runcap` has one global queue and no
stealing, which is the simpler correct shape and the reason its
`Runtime::new(2)` is a parameter instead of a cpu count.

The timer is the wheel with levels. Tokio's time driver source, read
2026-10-14, describes six wheels of 64 slots each, level 0 slots of
one millisecond, each level covering the whole wheel below it, entries
cascading down as time advances, one millisecond resolution with
sub-millisecond durations rounded up, the design of Varghese and
Lauck's hashed and hierarchical timing wheels. `runcap` is one level
of 1024 slots at the same 1 ms resolution, which fires correctly at
any distance, measured past one full revolution, and simply scans
more buckets when deadlines spread.

The reactor is the poll loop replaced by the os: tokio's net driver
subscribes sockets to epoll on linux, kqueue on macos, iocp on
windows, and wakes exactly the task whose readiness arrived. `runcap`
polls every tick because std exposes none of those, trading 1 ms of
latency and a quiet tick of cpu for zero unsafe and zero ffi, the
same trade chapter 19's accept loop made at 2 ms.

`spawn_blocking` is the pool, `JoinHandle` is the join bridge with
`abort` added on top of the same drop, `select!` is the biased race
with a fairness twist chapter 14 verified: random branch order by
default, `biased;` polls top to bottom, the exact order `Race` bakes
in. Graceful shutdown in tokio compositions, task cancellation plus a
drain, is the server's stop signal plus queue drain, and the demo's
join barrier is the property no runtime gives you for free: admission
and notification must be ordered by the protocol, not by the
scheduler.

== what the capstone proves

Chapter 1 pinned the toolchain that builds all of this and asserts
its own version. Chapters 4 through 7 gave the value model the
executor stands on: `Poll` is an enum, `Option` in a `Mutex` is the
task slot, the `Arc` clones that make wakers cheap are ownership and
moves doing scheduler work. Chapter 8's traits are the contract,
`Future` and `Wake` both, one vtable each. Chapter 10's closures are
the pool's jobs. Chapter 11's error model is why `WouldBlock` is a
kind, not a failure, the single decision that makes readiness polling
composable. Chapter 12's `Pin` is why `pin!` and `Box::pin` appear
exactly three times in the crate and nowhere else. Chapter 13's
mutexes, condvars, atomics, and barriers are every synchronization
primitive the runtime uses, and no other kind appears.

Chapter 14 is the direct ancestor: poll by hand, the waker, block_on
the loop, join and select, the timer bridge. The capstone is that
chapter with the miniatures promoted to modules, and its tests are
the chapter's observations promoted to assertions, the 4-poll
countdown and the biased tie among them. Chapter 18's discipline
governs the suite: fixed thread counts, joins before asserts, no
timing assertions beyond the never-early floor, and 36 tests that
attack the runtime from outside through its real interfaces.

The service part contributed its laws. Chapter 19's kernel taught the
socket front door, nonblocking mode set on everything registered, eof
as a quiet close, and the windows inheritance trap the reactor's
register path still guards against. Its bounded pool and 50 ms worker
waits are the condvar discipline the executor and the blocking pool
both reuse, and its drain, flip readiness, refuse work, wait for busy
within a grace, is the shutdown contract the fan-out server restates
over queues. Chapters 20 through 31 built the service above a thread
pool and never needed async to be correct, which is the capstone's
closing claim: async rust is not a better way to serve, it is a
cheaper way to park, one heap enum instead of a megabyte of stack per
waiting connection, and now the whole mechanism is code you have read
at 1.99.0, line by line, with the threads showing.

sources: the rust standard library surface read from the offline
1.99.0 html share under
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html,
accessed 2026-10-13 and 2026-10-14: std::task for the Wake trait and
Waker (doc.rust-lang.org/stable/std/task/trait.Wake.html),
std::sync for Condvar including wait_timeout and for the mpsc module
(doc.rust-lang.org/stable/std/sync/index.html), std::thread
(doc.rust-lang.org/stable/std/thread/index.html), and std::net for
TcpStream including peek, set_nonblocking, and shutdown, and
TcpListener accept
(doc.rust-lang.org/stable/std/net/struct.TcpStream.html). The tokio
mapping verified live 2026-10-14: the runtime module page for the
thread pool, the half-queue steal, and the per-core worker default
(docs.rs/tokio/latest/tokio/runtime/index.html), the select macro
page for random-first order and biased top to bottom
(docs.rs/tokio/latest/tokio/macro.select.html), and the time driver
source for the six-wheel, 64-slot, 1 ms leveled wheel after Varghese
and Lauck's hashed and hierarchical timing wheels
(github.com/tokio-rs/tokio/blob/master/tokio/src/runtime/time/mod.rs).
All measurements produced by `cargo test --locked` and
`cargo run --locked --bin runcap-demo` under `CARGO_NET_OFFLINE=true`
on the pinned rustc 1.99.0 (b940084d7), dated 2026-10-13 and
2026-10-14: 36 tests, 8 runtime, 8 timer, 7 blocking, 7 net, 6
server, the 4-poll countdown, 2 ms sleep at 9.5406 ms and 13.3590 ms
with a far entry parked, 26 sleeps ordered across one 1024 ms
revolution, the 3-thread barrier pool, the 1 MiB enqueue at
1048576 bytes queued, the demo's 10 of 10 runs at 0.020 to 0.033 s
with 12 messages, 192 bytes in, 768 bytes out, drained true, and the
three debugging findings, the drop-cascade deadlock, the single-waker
stop slot, and the 10-of-12 acceptance gap, each observed live in the
test and demo logs before its fix.
