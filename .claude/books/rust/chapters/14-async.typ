#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= async: futures from first principles

Async rust is std-defined and runtime-less: the `Future` trait, the
waker machinery, and the `async` and `.await` syntax all ship in the
language and std since 1.36 and 1.39, and nothing in std schedules
them. Every executor is a library, and this chapter builds one from
scratch until the pieces are too plain to be mysterious: poll by hand,
a waker built over a raw vtable, `block_on` as a loop, `async fn`
shown to be a state machine by writing its twin, join and select
combinators with the same poll loop, and a timer whose wake comes from
a plain thread. Everything here feeds the capstone in chapter 32,
which grows this executor into the book's async runtime.

#diagram([async in one picture: syntax on top, the trait in the middle, an executor under it], length: 13pt, {
  cdraw.rect((0.3, 3.6), (11.3, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.05), [async fn and .await], size: 6.5pt)
  cdraw.content((5.8, 5.1), [syntax, since 1.39,], size: 6pt)
  cdraw.content((5.8, 4.1), [compiles to a state machine], size: 6pt)
  cdraw.rect((0.3, 0.3), (11.3, 3.2), fill: luma(222), radius: 0.02)
  cdraw.content((5.8, 2.65), [Future, Context, Waker], size: 6.5pt)
  cdraw.content((5.8, 1.7), [poll returns Ready or Pending,, since 1.36], size: 6pt)
  cdraw.content((5.8, 0.75), [waker says who to repoll], size: 6pt)
  cdraw.rect((0.3, -3.0), (11.3, -0.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, -1.15), [the executor], size: 6.5pt)
  cdraw.content((5.8, -2.1), [a library, std ships none, built below], size: 6pt)
  cdraw.line((5.8, 3.3), (5.8, 3.55), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((5.8, 0.05), (5.8, 0.25), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((13.1, 5.1), [inert until polled,, zero cost], size: 6pt)
  cdraw.content((13.1, 1.7), [Pin threads the state,], size: 6pt)
  cdraw.content((13.1, 0.8), [chapter 12 owns it], size: 6pt)
  cdraw.content((13.1, -1.6), [tokio is one of these,], size: 6pt)
  cdraw.content((13.1, -2.5), [the last section maps it], size: 6pt)
})

== the Future trait and poll

The whole contract is one method:

#snippet("fn poll(self: Pin<&mut Self>, cx: &mut Context<'_>) -> Poll<Self::Output>;", lang: "rust")

`Poll` is `Ready(T)` or `Pending`, and `Pending` carries a promise:
the future arranged for its waker to be called when poll is worth
retrying, or it accepts never being polled again. Futures are inert,
polling is a plain function call, and a future that is never polled
does no work at all, the sample's first check constructs a countdown
and observes zero polls.

#listing("rust/samples/src/Ch14/FuturePoll.rs", first: 28, last: 53, caption: [two hand written futures, one always ready, one counting down])

Driving it by hand is a `loop` over `Pin::new(&mut fut).poll(&mut cx)`.
`Pin::new` works here because `CountDown` holds only plain fields and
is therefore `Unpin`: the pin exists for state machines that borrow
into themselves, chapter 12 owns `Pin` and `Unpin`, this chapter only
needs the two working moves, `Pin::new` for `Unpin` types and `pin!`
for compiler futures. Measured 2026-10-13: 3 pending polls then a ready, 4
polls total.

#listing("rust/samples/src/Ch14/FuturePoll.rs", first: 61, last: 95, caption: [hand polling, inertness, and the poll counts])

== wakers and a tiny executor

A waker is a cloneable handle that means "poll this task again". The
safe route is the `Wake` trait, stable since 1.51: implement `wake` on
an `Arc<T>` and `Waker::from` builds the handle. The sample's
`NoopWaker` is the smallest one possible.

The raw route shows what `Wake` hides: a `RawWaker` is a data pointer
plus a `RawWakerVTable` of four function pointers for clone, wake,
wake by ref, and drop. Edition 2024 hardened this exact code: an
`unsafe fn` body no longer grants its own permissions, the pointer
dereference needs its own `unsafe` block, the `unsafe_op_in_unsafe_fn`
lint is a hard error in this edition and the sample shows the wrapped
shape.

#listing("rust/samples/src/Ch14/BlockOn.rs", first: 18, last: 54, caption: [a raw waker over an AtomicBool flag, and block_on as a poll loop])

The invariant the `unsafe` carries, stated plainly: the vtable's data
pointer is `Arc::as_ptr` of the flag, `block_on` owns that `Arc` for
its whole body, so the waker outlives every poll it is handed to and
the pointer is never dangling. The executor loop is then six lines:
clear the flag, poll, spin until the flag is set, repeat. A future
that self-wakes, like the sample's `Steps`, walks the flag protocol
without any thread at all, and `block_on` drives `async` blocks to a
value with no runtime in sight.

#listing("rust/samples/src/Ch14/BlockOn.rs", first: 87, last: 104, caption: [block_on running a self waking future, an async block, a ready one])

== async fn is a state machine

`async fn` and `async` blocks are syntax for a type that implements
`Future`, an enum with one variant per suspension point, `.await` is
the boundary between variants, and the compiler writes the `poll` that
steps the enum. The proof is parity: write the machine by hand, run
both against the same dependency, and compare.

#listing("rust/samples/src/Ch14/JoinFutures.rs", first: 25, last: 71, caption: [the dependency future, the manual enum machine, and its async fn twin])

Both shapes are driven against the same `Delayed` dependency that
instruments its own polls. Measured 2026-10-13: identical output 21
and identical 2 pending polls each, the machine is the desugaring.

#listing("rust/samples/src/Ch14/JoinFutures.rs", first: 116, last: 148, caption: [the parity run, manual machine against compiler machine])

One asymmetry the compiler enforces and the sample hits: the generated
future is `!Unpin`, even when it holds only plain values, so `Pin::new`
is rejected and `pin!` (since 1.68) pins it on the stack. That is the
entire reason `Pin` leaks into async code at all: an `async fn` that
holds a borrow across an await becomes self-referential when parked in
its enum, and moving it would break the borrow.

== join, by hand

`join` is polling children and keeping the ready ones until all are
in. The combinator below takes two `Unpin` children and their outputs,
which keeps pin projection out of the picture, the honest scope here:
a general join over pinned children needs structural pin projection,
and that machinery belongs to chapter 12 and the pin-project pattern,
not to an async primer.

#listing("rust/samples/src/Ch14/JoinFutures.rs", first: 73, last: 113, caption: [Join2, poll both, stash the ready one, complete on the slowest])

Measured 2026-10-13: children with 1 and 3 pending polls finish in 4
rounds, the first ready value waits in the `Option` for the last one,
which is exactly what `futures::join` and `tokio::join!` do with
arbitrary arity.

== timers through a thread and channel bridge

Nothing in std parks a future on a clock, and that is the point: a
timer is a thread, a channel, and a waker slot, composed from the
pieces this chapter already built. The thread sleeps, sends the
delivery instant, then wakes whoever registered. The poll is the
double-check pattern done right: try the channel, and only if empty
take the lock, try again under the lock, and only then store the waker
and return pending. The second try closes the race where the thread
fired between the first try and the store, so a wakeup is never lost
while a value sits queued.

#listing("rust/samples/src/Ch14/TimerBridge.rs", first: 56, last: 99, caption: [the timer bridge, channel for the value, waker slot for the latency])

Measured 2026-10-13 under the chapter executor: a 25 ms timer
delivered at 25.4958 ms, a 10 ms plus 20 ms pair joined by hand
spanned 20.7017 ms. No assert rides on those numbers beyond the
semantic floor: delivery is never earlier than the requested
duration, which is `thread::sleep`'s own documented guarantee.

== select and cancellation

`select` is polling children until the first ready wins and dropping
the rest. The biased version polls arms in written order, which makes
its behavior reproducible and makes it the right teaching shape: the
sample asserts which arm wins in three schedules, including the tie.

#listing("rust/samples/src/Ch14/SelectFutures.rs", first: 51, last: 73, caption: [Select2, biased, first ready wins])

Cancellation is the same drop. Completing a select consumes the
future and drops the losing arm, and because a future is just a state
enum, dropping it deletes the work: the sample's losing arm counts its
own polls, was polled once, on the single round where the winner was
still pending, and is never polled again after the drop. That is
async cancellation, the property the capstone's request timeouts rely
on.

#listing("rust/samples/src/Ch14/SelectFutures.rs", first: 94, last: 121, caption: [which arm wins, and the losing arm's polls stopping at the drop])

== what tokio adds

Tokio is one executor of the shape just built, scaled up, and every
piece of it decomposes into this chapter's primitives. The mapping,
per the corpus rule that libraries are explained by what they compose:

The reactor is the waker slot at scale. The timer bridge stored one
`Option<Waker>` behind a mutex, tokio's runtime bundles an io driver
and a timer whose job is the same registration: os readiness events,
epoll style, plus timer wheels, all resolved into `Waker::wake` calls.
`Timer::after` above is a one-shot wheel of size one.

The multithreaded scheduler is `block_on` widened from one spin loop
to a pool. Tokio's multi-thread scheduler executes tasks on a thread
pool with work stealing: idle workers steal half of another worker's
local queue, where this chapter's executor runs exactly one task on
the calling thread.

`spawn` lifts a future onto that pool, requiring `Send` futures, where
`block_on` runs one future inline. `tokio::join!` is the `Join2` above
at arbitrary arity, `JoinSet` adds cancellation of the group.

`tokio::select!` is the biased `Select2` with a fairness twist the
tokio documents state exactly: by default it randomly picks a branch
to check first, and `biased;` mode polls the futures in written order
top to bottom, exactly the behavior this chapter's combinator bakes
in. Random order protects a loop where one arm is always ready,
biased order costs no rng and gives determinism.

Timeouts are select against a timer, the capstone composes exactly
this: a request future raced against `Timer::after`, first ready
wins, the loser drops, and the drop cancels it. Chapter 32 grows
this chapter's executor into that runtime, io bridges included, with
std only and zero dependencies.

#callout("note", "why not just threads", [
  An os thread idles at megabytes of reserved stack and parks in the
  kernel, a parked future is a heap enum the size of its state. The
  chapter 13 stack handles hundreds of threads comfortably, async
  exists for the tens of thousands of concurrent sockets the api lane
  in chapter 19 serves. The two compose freely: timers here are
  threads, and `spawn_blocking` in tokio is a thread pool for the
  blocking work futures must never do inline.
])

sources: the async book
(doc.rust-lang.org/stable/book/ch17-00-async-await.html plus its
futures, concurrency, streams, and traits sections through
ch17-06-futures-tasks-threads.html), std::future::Future
(doc.rust-lang.org/stable/std/future/trait.Future.html), the
std::task module pages for Poll, Context, Waker, RawWaker,
RawWakerVTable, and the Wake trait
(doc.rust-lang.org/stable/std/task/index.html and
doc.rust-lang.org/stable/std/task/trait.Wake.html), std::pin
including the pin! macro
(doc.rust-lang.org/stable/std/pin/macro.pin.html), all read from the
offline 1.99.0 html share under
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html
and accessed 2026-10-13. Version facts verified in
doc.rust-lang.org/stable/releases.md, accessed 2026-10-13: Future in
1.36.0 (2019-07-04), async and await syntax in 1.39.0, the Wake trait
in 1.51.0, the pin! macro in 1.68.0 (2023-03-09). The
unsafe-op-in-unsafe-fn hard error observed live compiling the sample
under `rustc --edition 2024 -D warnings`, dated 2026-10-13. The tokio
mapping quotes verified against docs.rs/tokio/latest/tokio/macro.select.html
and docs.rs/tokio/latest/tokio/runtime/index.html, accessed 2026-10-13:
random-first select with biased top to bottom mode, work stealing of
half a worker's local queue, the bundled io driver and timer. All
measurements (4 polls 3 pending countdown, join rounds 4 for 1 and 3 pending polls
pending polls, 25 ms timer delivered at 25.4958 ms, pair span 20.7017 ms,
losing arm polled once then cancelled) produced by
`rust/samples/src/Ch14` under `pwsh tools/run-rust-samples.ps1
-Chapter Ch14`, dated 2026-10-13 on the pinned rustc 1.99.0.
