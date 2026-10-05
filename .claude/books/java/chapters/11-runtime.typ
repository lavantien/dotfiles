#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= memory and runtime

Java removed the free call in 1995 and handed memory to a garbage
collector. This chapter is what that trade buys: the heap's layout,
the collectors that manage it, the object header shrink that landed
as a default in 27, the flight recorder that watches all of it live,
and the jit that makes the interpreter's bytecode fast. It ends with
the measurement discipline, because every number in this chapter is
either measured on this machine and dated, or documented, and the two
never blur.

== the heap and generations

Objects live on one shared heap, reached by tracing from the thread
stacks and the other gc roots. The collector's foundational bet is
the weak generational hypothesis: most objects die young. HotSpot
splits the heap accordingly. New objects allocate in eden, each
thread bumping a pointer through its own thread-local allocation
buffer, which is nearly free. A young collection evacuates the few
survivors into survivor spaces, and after surviving several cycles an
object is promoted to the old generation. Evacuation never touches
the dead majority, so young collections cost roughly the number of
live objects, not the number allocated. When the collector must move
objects that running threads can see, it stops the world at
safepoints, points where every thread sits at a known state.

G1, the default everywhere in 27, reshapes that heap into regions,
measured 4 MiB each on this machine. A region belongs to young, old,
or free, and the collector picks the regions with the most reclaimable
space first, which is the name. It compacts incrementally by
evacuating whole regions, and it works toward a pause goal,
`-XX:MaxGCPauseMillis=200` by default.

#diagram([the G1 heap: regions classified by role, evacuation moves survivors between them], length: 13pt, {
  cdraw.rect((0.3, 1.2), (3.4, 3.8), fill: luma(235), radius: 0.02)
  cdraw.content((1.85, 3.3), [eden], size: 6.5pt)
  cdraw.content((1.85, 2.4), [new objects], size: 6pt)
  cdraw.content((1.85, 1.6), [tlab bump alloc], size: 6pt)
  cdraw.rect((4.2, 1.2), (7.3, 3.8), fill: luma(228), radius: 0.02)
  cdraw.content((5.75, 3.3), [survivors], size: 6.5pt)
  cdraw.content((5.75, 2.4), [copied young], size: 6pt)
  cdraw.content((5.75, 1.6), [until tenured], size: 6pt)
  cdraw.rect((8.1, 1.2), (11.2, 3.8), fill: luma(222), radius: 0.02)
  cdraw.content((9.65, 3.3), [old], size: 6.5pt)
  cdraw.content((9.65, 2.4), [promoted and], size: 6pt)
  cdraw.content((9.65, 1.6), [long lived], size: 6pt)
  cdraw.rect((12.0, 1.2), (15.1, 3.8), fill: luma(240), radius: 0.02)
  cdraw.content((13.55, 3.3), [free], size: 6.5pt)
  cdraw.content((13.55, 2.4), [fresh regions], size: 6pt)
  cdraw.content((13.55, 1.6), [for any role], size: 6pt)
  cdraw.line((3.5, 2.5), (4.1, 2.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((7.4, 2.5), (8.0, 2.5), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((7.75, 0.7), [humongous objects take contiguous regions whole], size: 6pt)
  cdraw.content((7.75, -0.2), [measured region size on this machine: 4 MiB], size: 6pt)
})

== the collectors

G1 became the default for server configurations in 9 (jep 248), and
27 finished the job: jep 523 makes G1 the default in every
environment, the jvm no longer falls back to Serial on machines it
deems constrained, a single cpu or under 1792 mb of memory. The
sample reads the choice off the running vm, `UseG1GC` true with
origin `ERGONOMIC`, the vm picked it, no flag was passed.

The rest of the shelf: Serial and Parallel remain available when
passed explicitly, Parallel for throughput at the price of long full
pauses. CMS was deprecated in 9 and removed in 14 (jep 363).
Shenandoah, the Red Hat collector, evacuates concurrently with the
application and hunts sub-millisecond pauses on large heaps, its
generational mode arrived experimental in 24 (jep 404), became a
product feature in 25 (jep 521) with `-XX:ShenandoahGCMode=generational`,
and the flip of generational to the Shenandoah default is targeted
for 28 (jep 535). ZGC went generational in 21 (jep 439) with the
same young/old split under a concurrent collector.

== compact object headers

Every object carries a header: a mark word with identity hash, lock
state, and gc bits, plus a class pointer. The classic layout is 96
bits on 64-bit HotSpot with compressed class pointers, 12 bytes per
object before a single field is stored. Jep 450 previewed a 64-bit
header in 24, jep 519 made it a product feature behind
`-XX:+UseCompactObjectHeaders` in 25, and jep 534 flipped the
default in 27. The savings are per-object, so heaps full of small
objects shrink proportionally.

#listing("java/samples/src/Ch11/Heap.java", first: 21, last: 33, caption: [the running vm names its collector and header layout])

Measured 2026-10-04 on the pinned build: `UseCompactObjectHeaders`
reads true with origin `DEFAULT`, no flag was set, the 27 default at
work. The footprint follows:

#listing("java/samples/src/Ch11/Heap.java", first: 34, last: 58, caption: [two million plain objects, measured to the byte])

Three rounds agree: a plain object measures 8 bytes under the default
layout, the 64-bit header and nothing else. The identity hash read
after each measurement is load-bearing, without a later use the jit
dead-code-eliminates the whole allocation loop and the deltas read as
noise, a lesson this sample carries on purpose. Compressed oops
(measured on, origin `ERGONOMIC`) keep references at 4 bytes and the
sample's array arithmetic assumes them.

== finalization is dead

`finalize()` ran cleanup when the collector got around to it, which
is nowhere near a guarantee: no timing, no ordering, possibly never.
Jep 421 terminally deprecated it in 18, and the mechanism is on the
removal path. Resources with a lexical scope go through
try-with-resources, whose `close()` is guaranteed on the way out.
Resources outliving any one scope register with a `Cleaner` (since
9), accepting that the clean runs at gc's discretion. Nothing new
should ever override `finalize`.

== java flight recorder

JFR is the jvm's built-in, low-overhead event recorder, open sourced
with 11. It samples allocations, thread dumps, gc cycles, monitor
contention, and method profiles into chunked recordings, cheap
enough to leave running in production as a ring buffer so the data
around an incident survives the incident. The usual loop runs it from
outside: `jcmd <pid> JFR.start name=rec settings=profile duration=120s
filename=rec.jfr`, then `jfr print` or the JDK Mission Control gui
over the file. The same api works from inside:

#listing("java/samples/src/Ch11/Jfr.java", first: 15, last: 47, caption: [a recording started, fed allocation churn, and read back in-process])

Measured 2026-10-04: 153 events, 152 of them `ObjectAllocationSample`,
in a 137,269-byte file. With a destination set, `stop()` writes the
dump and the recording reads `CLOSED`, the state machine the checks
walk. `RecordingFile` streams the parsed events, the same records
Mission Control renders.

== the jit at a walk level

HotSpot starts every method in the interpreter, tier 0, counting. Hot
methods climb the tiers: 1 through 3 compile quickly on C1 with
increasing profiling, tier 4 hands the profile to C2 for the fully
optimized build. Tiered compilation has been the default since 8,
and it is why java warms up: the first seconds run interpreted and
lightly compiled, peak speed arrives after the profiles do. Compiled
code lives in the code cache, `ReservedCodeCacheSize` measured at
roughly 240 MiB on this machine's default flags, and deoptimization
drops a method back toward the interpreter whenever a speculative
assumption, an unstaken branch, an inlined monomorphic call, proves
wrong. This is deliberately a walk: the full compiler story belongs
to the vm literature, and nothing in day-to-day java needs it beyond
knowing why the p99 moves in the first five minutes.

== the measurement discipline

Every claim above splits into measured or documented, and the split
is stated. The measured side comes from three tools.

First, `jcmd`, the swiss knife: it talks to a running jvm by pid and
its command set is grouped by subsystem.

#listing("java/samples/src/Ch11/Tools.java", first: 28, last: 46, caption: [jcmd against the sample's own process])

Measured 2026-10-04, the same run: `GC.heap_info` reported
`garbage-first heap total reserved 8339456K, committed 12288K, used
2512K` with `region size 4M`, and `VM.flags` showed `+UseG1GC`.
Second, `jstat`, the sampled time series, `jstat -gc <pid> 1000`
prints one line per second of generation occupancy and collection
counts, the shape of a leak or a tuning change over time. Third, the
mx beans, which answer the same questions from inside the process
and are what application metrics should export: `MemoryMXBean`,
`CompilationMXBean`, `ClassLoadingMXBean`, and the diagnostic bean
the heap sample used to read flag values and origins.

#callout("verify", "measured or documented, never both", [
  A number in this book is either measured on the pinned build and
  dated, like the 8-byte object and the 4 MiB regions, or it comes
  from a cited jep or the javadoc, like the 200 ms default pause
  goal. Anything a workload actually depends on gets re-measured on
  the deployment machine before it drives a decision, because heap
  sizing, region granularity, and ergonomics all move with hardware
  and flags.
])

sources: jep 523 (openjdk.org/jeps/523, G1 default in all
environments, the 1792 mb and single cpu Serial fallback, JEP 522
throughput work), jep 534 compact headers default 27 with the 96 to
64 bit reduction and the 450 (24 preview) and 519 (25 opt-in)
lineage, jep 248 G1 server default 9, jep 363 CMS removed 14, jep
404 generational Shenandoah experimental 24, jep 521 product 25,
jep 535 generational default targeted 28, jep 439 generational ZGC
21, jep 421 finalization deprecation 18, all accessed 2026-10-04.
Tiered compilation default since 8 verified against Oracle's
compilation optimization documentation,
docs.oracle.com/en/java/javase/11/jrockit-hotspot/compilation-optimization.html,
accessed 2026-10-04. The 8-to-17 arcs (mark and sweep, evacuation,
survivor spaces, the HotSpot heap, G1 region model, parallel
concurrent serial distinctions, finalization's failure modes, jcmd
and jstat usage, JFR workflow) ground on Java in a Nutshell 8th
edition chapter 6 pages 237 to 248 and chapter 13 pages 407 to 429.
Measurements (collector ergonomics and header origins via
HotSpotDiagnosticMXBean, 8 bytes per plain object over 3 rounds,
153 JFR events with 152 allocation samples in 137,269 bytes, G1
region size 4M, reserved heap 8339456K, code cache ~240 MiB, loaded
class count) produced by `java/samples/src/Ch11` under
`pwsh tools/run-java-samples.ps1 -Chapter Ch11` and the VM.flags
probe, dated 2026-10-04 on tools/jdk27/build/jdk-27.
