#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= resilience

Everything before this chapter assumed failure is an event. In a
distributed system failure is weather: timeouts, retries, and
degradation are steady-state design, not exception handling. The
four tools in this chapter, retry with backoff, the circuit breaker,
rate limiting, and the bulkhead, are the standard equipment, and the
chapter's specific discipline is making all of them testable
through injected clocks and sleeps, no test waits a real second.
Every tree runs its timing through a clock it hands in: C advances
a vclock struct, java advances a vclock long whose sleeps record
themselves, C\# reads a `TimeProvider` and takes the sleep as a
delegate, javascript queues timers on a fake clock whose advance
fires them after pumping the microtask queue, python records sleeps
on a fake clock and drives the bulkhead through a timer heap under
asyncio, lua scripts a scheduler over a time table. The dry runs
below assert exact admit, drip, and open-half states, never wall
timing.

== retry with exponential backoff and full jitter

Retrying immediately in a tight loop is a denial of service attack
on your own dependency, and retrying in synchronized lockstep is
one on its recovery. The standard answer is exponential caps plus
full jitter, sleep uniform in `[0, cap)` with the cap doubling per
attempt, with the sleep and the draw both injected so the schedule
is an observation, not a wait.

The dry run: all seven lanes pin the same schedules.

- 4 attempts succeeding on the 3rd, jitter pinned to the cap:
  sleeps `[10ms, 20ms]`
- 3 attempts, zero jitter, all failing: 2 sleeps, the error names
  exhaustion and the last cause
- realized full jitter, corpus LCG seed 42 over caps `[10, 20, 40,
  80]`: draws `[5, 4, 16, 50]` ms, sum 75
- the frozen go test pins the first two walks plus a draw-under-cap
  property, the realized vector is pinned by the 6 new trees

#listing("patterns-concurrency-distributed/samples-c/src/Ch15/retry.c", first: 47, last: 86, caption: [C, the attempt is a function pointer, the outcome struct carries exhaustion and cause])

#listing("patterns-concurrency-distributed/samples/ch15/resilience.go", first: 15, last: 52, caption: [Go, caps double, jitter draws under the cap, sleep injected])

#listing("patterns-concurrency-distributed/samples-java/src/Ch15/Retry.java", first: 65, last: 100, caption: [Java, caps double, jitter an injected cap-to-delay operator, the vclock records each sleep, an Out carries exhaustion and cause])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch15/Retry.cs", first: 14, last: 36, caption: [C\#, caps from base ticks, exhaustion throws with the last error inside])

#listing("patterns-concurrency-distributed/samples-js/src/ch15-retry.mjs", first: 52, last: 77, caption: [JavaScript, do is async, the injected sleep queues on the fake clock])

#listing("patterns-concurrency-distributed/samples-py/src/Ch15/retry.py", first: 22, last: 60, caption: [Python, the LCG beside the clock, the exhausted error is a string naming both])

#listing("patterns-concurrency-distributed/samples-lua/ch15_retry.lua", first: 8, last: 48, caption: [Lua, the LCG wraps mod 2^64 natively, failure rides pcall])

Sleeps happen between attempts, never after the last, and the
exhausted error names both facts in every lane: go joins
`ErrRetriesExhausted` with the last real error so `errors.Is` finds
either, C fills an outcome struct with the exhausted flag and the
cause pointer, java the same shape, an `Out` with the flag and the
cause beside a message naming both, C\# throws
`RetriesExhaustedException` carrying the last error as its
`InnerException`, javascript and python build the exhaustion
message around the carried cause, lua concatenates it into the
returned message string. The jitter source is the other split: go
draws from `rand/v2`, the 6 new lanes draw from chapter 11's corpus
LCG so the realized schedule is a pinned vector, and the AWS blend
is the same shape in all seven, herds spread across the band
instead of stampeding in lockstep.

Retries are only correct for idempotent operations, which is not a
formality: retrying a payment creation is how double charges
happen. Chapter 13's idempotency keys are the companion tool, the
key makes the operation safe to retry, this pattern supplies the
patience.

#diagram([caps double per attempt, every sleep drawn under its cap so herds spread], length: 13pt, {
  // y(height) maps a cap in ms to canvas units, x columns per retry sleep
  let cap-y = (ms) => 1.0 + ms / 80 * 5.0
  let cols = ((3.2, [try 2], 10), (8.4, [try 3], 20), (13.6, [try 4], 40), (18.8, [try 5], 80))
  for (x, label, cap) in cols {
    cdraw.rect((x - 1.5, 1.0), (x + 1.5, cap-y(cap)), fill: luma(235), radius: 0.02)
    cdraw.line((x - 1.5, cap-y(cap)), (x + 1.5, cap-y(cap)), stroke: (paint: luma(100), dash: "dashed"))
    cdraw.content((x, cap-y(cap) + 0.45), [cap #(cap)ms], size: 6pt)
    // three jittered draws inside [0, cap), scattered across the band
    let draws = ((-0.85, 0.3), (0.0, 0.6), (0.85, 0.85))
    for (dx, f) in draws {
      cdraw.circle((x + dx, 1.0 + f * (cap-y(cap) - 1.0)), radius: 0.11, fill: luma(30))
    }
    cdraw.content((x, 0.45), label, size: 6pt)
  }
  cdraw.line((1.4, 1.0), (21.8, 1.0), stroke: luma(100))
  cdraw.content((11.5, -0.85), [sleep uniform in \[0, cap): retried callers land anywhere in the band, never in lockstep], size: 6pt)
})

== the circuit breaker

A breaker is a state machine that stops hammering a dependency that
is down, so its recovery is not suffocated by its callers:

#flow(
  [breaker states],
  node((0, 0), [closed, traffic flows]),
  node((2.2, 0), [open, reject fast]),
  node((4.4, 0), [half-open, one probe]),
  edge((0, 0), (2.2, 0), "->", label: [consecutive failures >= threshold]),
  edge((2.2, 0), (4.4, 0), "->", label: [reset delay elapsed]),
  edge((4.4, 0), (0, 0), "->", bend: 30deg, label: [probe succeeds]),
  edge((4.4, 0), (2.2, 0), "->", bend: -20deg, label: [probe fails]),
)

The dry run: threshold 3, reset delay 5 seconds, the whole walk on
the injected clock.

- 2 failures stay closed, a success resets the streak, the 3rd
  consecutive failure opens
- open rejects fast and the dependency's call count does not move,
  +2s stays open, the full +5s admits exactly one probe, a second
  concurrent probe is rejected, java pinning the whole lifecycle's
  dependency count at exactly 8
- a failed probe reopens with a fresh delay counted from the
  failure, a successful probe closes
- the go lane's frozen walk advances 2s then 4s more, admitting its
  probe at 6s cumulative, both walks verified against the same
  implementation

#listing("patterns-concurrency-distributed/samples-c/src/Ch15/breaker.c", first: 56, last: 98, caption: [C, allow claims the probe slot, report settles it, the clock is a long the test owns])

#listing("patterns-concurrency-distributed/samples/ch15/resilience.go", first: 56, last: 104, caption: [Go, the breaker fields and constructor, allow admits one half-open probe, the clock injected])

#listing("patterns-concurrency-distributed/samples/ch15/resilience.go", first: 106, last: 129, caption: [Go, report settles the probe, a failure reopens with a fresh delay, a success closes])

#listing("patterns-concurrency-distributed/samples-java/src/Ch15/Breaker.java", first: 51, last: 92, caption: [Java, the probing flag claims the single half-open slot, report settles it, a failed probe restamps the open time])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch15/Breaker.cs", first: 46, last: 73, caption: [C\#, Allow throws when open and claims the single probe slot, Report mirrors go's settle])

#listing("patterns-concurrency-distributed/samples-js/src/ch15-breaker.mjs", first: 22, last: 68, caption: [JavaScript, the now function is injected, open admission compares against it])

#listing("patterns-concurrency-distributed/samples-py/src/Ch15/breaker.py", first: 28, last: 68, caption: [Python, allow raises CircuitOpen, report reopens or closes on the probe outcome])

#listing("patterns-concurrency-distributed/samples-lua/ch15_breaker.lua", first: 26, last: 68, caption: [Lua, allow returns false with a message, the walk is scripted instants])

Every transition in that walk is an assertion, and none of them
took real time. The state itself is a string in go and lua, an enum
in C and java, and the machine's edge conditions are identical: the
delay comparison is `>=`, the half-open slot is claimed before the
call, and a failed probe stamps a fresh `openedAt`. The threading
row is quiet here, a mutex in go and C\# around fields that the
scripted walks in C, java, javascript, python, and lua touch one
step at a time.

The design decision a breaker forces: failure threshold and reset
delay are SLA statements. A threshold of 3 with a 5 second delay
says "3 failures in a row is a dependency outage, I will check back
every 5 seconds", and tuning those numbers to the dependency's
reality is the engineering.

== rate limiting with a token bucket

The token bucket holds `burst` tokens and refills at `rate` per
second, allowing short bursts over the average rate, which is what
makes it the default limiter shape. The refill is lazy, computed
from elapsed time on each take, which is the property that keeps
the limiter correct through idle periods with zero background
cost, no ticker anywhere in any of the 7 trees.

The dry run: rate 10 per second, burst 4, the clock advanced by
hand.

- takes 1 through 4 succeed, the 5th is refused
- +100ms refills exactly 1 token, another 100ms one more, a long
  idle caps at burst
- WaitTake from empty at rate 2 per second: exactly one 500ms wait
- the go lane's frozen test runs the same walk at burst 3, both
  verified against the same implementation

#listing("patterns-concurrency-distributed/samples-c/src/Ch15/bucket.c", first: 35, last: 74, caption: [C, lazy refill on read in doubles, the wait derives from the deficit])

#listing("patterns-concurrency-distributed/samples/ch15/resilience.go", first: 141, last: 195, caption: [Go, lazy refill on read, burst cap, wait-take computes the deficit delay])

#listing("patterns-concurrency-distributed/samples-java/src/Ch15/Bucket.java", first: 29, last: 77, caption: [Java, lazy refill in doubles capped at burst, waitTake computes the deficit delay and pushes the clock through it])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch15/Bucket.cs", first: 25, last: 70, caption: [C\#, refill from TimeProvider elapsed, WaitTake sleeps the computed wait through the delegate])

#listing("patterns-concurrency-distributed/samples-js/src/ch15-bucket.mjs", first: 6, last: 51, caption: [JavaScript, elapsed seconds feed the refill, Math.min caps at burst])

#listing("patterns-concurrency-distributed/samples-py/src/Ch15/bucket.py", first: 23, last: 52, caption: [Python, the clock object advances, the sleep callback advances it further])

#listing("patterns-concurrency-distributed/samples-lua/ch15_bucket.lua", first: 10, last: 52, caption: [Lua, floats appear exactly where the arithmetic needs them, elapsed seconds times rate])

The arithmetic is float in all seven lanes and lands on the same
numbers because it is the same expression, elapsed seconds times
rate, capped at burst, with the wait derived as deficit over rate.
`WaitTake` loops: refill, draw if a full token is there, otherwise
sleep exactly the deficit delay and come back. The injected sleep
is what turns the blocking path into part of the walk, the fake
clock advances inside the sleep so the next refill sees the time
the caller just waited.

#diagram([token level over time: burst drain, lazy refill on read, cap at burst], length: 13pt, {
  // x: time in seconds, y: tokens, burst 4, rate 2/s
  let px = (t) => 1.6 + t * 2.6
  let py = (v) => 0.9 + v * 1.1
  // burst cap line
  cdraw.line((px(0), py(4)), (px(8), py(4)), stroke: (paint: luma(180), dash: "dashed"))
  cdraw.content((px(8) + 0.1, py(4)), [burst], size: 6pt)
  // burst of four takes drains the bucket
  let pts = ((0, 4), (0.18, 3), (0.36, 3), (0.54, 2), (0.72, 2), (0.9, 1), (1.08, 1), (1.26, 0))
  // then lazy refill climbs at rate, one take knocks it down, cap holds
  pts += ((2.0, 0), (4.0, 4), (4.18, 3), (5.0, 4), (6.5, 4), (6.68, 3), (7.6, 4))
  for i in range(pts.len() - 1) {
    let (t0, v0) = pts.at(i)
    let (t1, v1) = pts.at(i + 1)
    cdraw.line((px(t0), py(v0)), (px(t1), py(v1)), stroke: luma(100))
  }
  cdraw.line((px(0), 0.9), (px(8), 0.9), stroke: luma(100))
  cdraw.content((0.2, py(4)), [4], size: 6pt)
  cdraw.content((0.2, py(0)), [0], size: 6pt)
  cdraw.content((px(1.8), 0.2), [four takes drain the burst], size: 6pt)
  cdraw.content((12.0, -1.0), [refill accrues on each read, no ticker, wait-take waits out the exact deficit], size: 6pt)
})

== bulkhead and fallback

A bulkhead caps concurrency to a dependency so saturation there
cannot consume every worker here. The shape is chapter 6's counting
semaphore with a deadline: entry either finds a slot or expires
into a full error, `Leave` frees one, and the expiry timer runs on
the chapter's injected clock, so a full bulkhead fails in zero real
time.

The dry run: capacity 2, the wait a virtual 20ms.

- entries 1 and 2 take the slots, the third expires into the full
  error with the clock at 20ms, `Leave` frees a slot and the next
  entry succeeds without burning any time
- a slot freed mid-wait admits the waiter early, pinned in the
  java, javascript, python, and lua lanes
- fallback: a broken dependency answers with the degraded string, a
  healthy one passes the primary through

#listing("patterns-concurrency-distributed/samples-c/src/Ch15/bulkhead.c", first: 31, last: 79, caption: [C, a counter and a clock burn, the guarded service only runs on a taken slot])

#listing("patterns-concurrency-distributed/samples/ch15/resilience.go", first: 199, last: 222, caption: [Go, buffered channel as a counting semaphore, timer-bounded entry])

#listing("patterns-concurrency-distributed/samples-java/src/Ch15/Bulkhead.java", first: 40, last: 84, caption: [Java, a count and a waiter deque, the expiry burns the clock, leave hands the slot to an unexpired parked waiter])

#listing("patterns-concurrency-distributed/samples-cs/src/Ch15/Bulkhead.cs", first: 11, last: 42, caption: [C\#, SemaphoreSlim counts the slots, Task.Delay on the TimeProvider expires the wait])

#listing("patterns-concurrency-distributed/samples-js/src/ch15-bulkhead.mjs", first: 7, last: 55, caption: [JavaScript, the wait races slot against timer, a woken waiter re-checks the count])

#listing("patterns-concurrency-distributed/samples-py/src/Ch15/bulkhead.py", first: 58, last: 107, caption: [Python, an Event race through the timer heap, fallback wraps the pair])

#listing("patterns-concurrency-distributed/samples-lua/ch15_bulkhead.lua", first: 57, last: 94, caption: [Lua, one virtual sleep then a re-check, fallback degrades on error])

The slot counter is the easy half, a buffered channel in go, a
`SemaphoreSlim` in C\#, a plain count in the scripted lanes. The
wait is the interesting half: go races the channel send against a
timer through `select`, C\# awaits `Task.Delay` on the injected
provider, javascript races a slot promise against the fake clock's
sleep promise and re-checks the count after the wake so a stolen
slot cannot overfill the hold, python races an `asyncio.Event`
against the timer heap, lua sleeps once virtually and re-checks, C
runs single-threaded and just burns the clock, and java scripts the
rescue without threads at all, a parked waiter deque where `leave`
hands the slot straight to a waiter whose deadline has not passed,
the admit pinned at the release instant. Fallback completes
the set as the smallest tool in the chapter, a degraded answer when
the real one fails, stale cache over error page, and its test is 2
lines because the pattern is 2 lines.

#flow(
  [a full bulkhead fails fast, the fallback answers degraded],
  node((0, 0), [TryEnter]),
  node((2.4, 1.1), [slot free,#linebreak()work in flight]),
  node((2.4, -1.1), [slots full,#linebreak()wait on the timer]),
  node((4.8, 1.1), [Leave frees the slot]),
  node((4.8, -1.1), [ErrFull]),
  node((7.2, -1.1), [Fallback:#linebreak()degraded answer]),
  edge((0, 0), (2.4, 1.1), "-|>"),
  edge((0, 0), (2.4, -1.1), "-|>"),
  edge((2.4, 1.1), (4.8, 1.1), "-|>", label: [done]),
  edge((2.4, -1.1), (4.8, -1.1), "-|>", label: [timer fires]),
  edge((4.8, -1.1), (7.2, -1.1), "-|>"),
)

#callout("pitfall", "retry storms compose", [
  Every layer adding retries multiplies the load multiplier: 3
  retries at the client times 3 at the proxy times 3 at the service
  is up to 27 attempts per user action, aimed at whatever is already
  struggling. The discipline: one layer owns aggressive retries,
  the others fail fast and let the breaker decide. Timeout budgets
  keep the same rule, the sum of nested timeouts must shrink, never
  grow, toward the leaf.
])

#flow(
  [retries multiply down the stack, one layer owns aggression],
  node((0, 0), [one user action]),
  node((1.9, 0), [client retries x3]),
  node((3.8, 0), [proxy retries x3]),
  node((5.7, 0), [service retries x3]),
  node((3.8, -1.5), [up to 3 x 3 x 3 = 27 attempts]),
  edge((0, 0), (1.9, 0), "-|>"),
  edge((1.9, 0), (3.8, 0), "-|>"),
  edge((3.8, 0), (5.7, 0), "-|>"),
  edge((5.7, 0), (3.8, -1.5), "-|>", bend: 20deg, label: [at the leaf]),
)

== across the seven languages

The build sizes count non-comment source lines, the go column the
chapter's one frozen file:

#table(
  columns: (auto, auto, 1.2fr, 2.9fr),
  inset: 4pt,
  table.header([*language*], [*build SLOC*], [*dependency*], [*boundary note*]),
  [c], [459], [libc],
  [single-threaded, timers through a virtual clock, the bulkhead just burns it],
  [go], [188], [stdlib],
  [channel semaphore raced by select, rand.Int64N the jitter, timer-bounded entry],
  [java], [462], [jdk 27 stdlib],
  [every timer through a hand-in vclock, the bulkhead rescue scripted without threads],
  [c\#], [232], [bcl],
  [SemaphoreSlim counts the slots, Task.Delay expires on the injected TimeProvider],
  [javascript], [207], [node stdlib],
  [slot promise raced against the fake clock's sleep, a woken waiter re-checks],
  [python], [389], [stdlib only],
  [asyncio.Event raced against the timer heap, heapq drives every deadline],
  [lua], [458], [lib.lua harness],
  [one virtual sleep then a re-check, fallback degrades on the error return],
)

sources: AWS Architecture Blog, "Exponential Backoff and Jitter",
for full jitter against synchronized retries, Nygard, "Release
It!", for circuit breakers and bulkheads, go.dev/pkg/time for the
timer semantics used by the bulkhead wait, accessed 2026-09-08.
Verified by the seven chapter legs: 4 Ch15 C programs with 90
embedded checks, `go test` at 8 tests in `patternsbook/ch15`, the
java runner's 90 checks across 4 programs in `samples-java/src/Ch15`,
9 xunit facts, node's 9 cases in `test/ch15.test.mjs`, 4 python
modules with 60 embedded checks, and the lua runner's 17 ch15 rows.
