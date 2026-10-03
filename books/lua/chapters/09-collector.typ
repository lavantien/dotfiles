#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw, xref-to
#import "@preview/fletcher:0.5.8": node, edge

= inside the collector

Chapter 8 set the collector's knobs and measured what they return. This
chapter opens the machine: what an incremental cycle actually does
between two allocations, how the tricolor walk decides what dies, what
the pause and step multipliers mean arithmetically, what separates a
minor collection from a major one, and what the allocator hook below it
all looks like. Stock lua offers no gc internals api, so everything here
is observed from lua through the only instruments it ships:
`collectgarbage("count")` as the oscilloscope, the boolean return of
`"step"` as the cycle flag, and weak tables as the verdict on what
survived. Every number in this chapter was measured on this machine
against `tools/lua55/build/bin/lua.exe`, lua 5.5.1, on 2026-09-13.

== the count as an oscilloscope

`collectgarbage("count")` reports kilobytes with a fraction, and the
manual promises that the value times 1024 is the exact byte count in
use. That precision is what makes it a usable probe: two full collects
in a row differ by 0.000 KB on this build, so the floor after a collect
is a stable baseline, and the delta over any allocation burst is the
true retained cost of what the burst built:

#listing("lua/samples/ch09_collector.lua", first: 5, last: 19, caption: [the two probes: kilobytes now, and bytes per boxed table])
#listing("lua/samples/ch09_collector.lua", first: 30, last: 40, caption: [the floor returns to itself after the garbage dies])

#diagram([count as an oscilloscope, the floor, the ramp, the drop], length: 13pt, {
  // the floor line and the allocation ramp
  cdraw.line((0.8, 8.0), (20.8, 8.0), stroke: luma(100))
  cdraw.content((2.6, 8.55), [the floor, one full collect], size: 6pt)
  cdraw.line((2.0, 8.0), (2.0, 10.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.6, 10.0), [allocation burst, #linebreak() count climbs], size: 6pt)
  // the ramp
  cdraw.line((2.0, 8.2), (12.5, 11.6), stroke: luma(60))
  cdraw.content((8.4, 11.3), [50k tables, measured +3553 KB], size: 6pt)
  // the drop
  cdraw.line((12.5, 11.6), (13.4, 8.05), stroke: luma(60), mark: (end: ">"))
  cdraw.content((16.6, 10.9), [drop the references, one collect], size: 6pt)
  // the rules
  cdraw.content((11.0, 6.4), [count \* 1024 is exact bytes, the fraction is real], size: 6.5pt)
  cdraw.content((11.0, 5.2), [two collects in a row differ by 0.000 KB here], size: 6.5pt)
  cdraw.content((11.0, 4.0), [the delta over a burst is the retained cost], size: 6.5pt)
  cdraw.content((11.0, 2.8), [steps never sink below the floor: only garbage frees], size: 6.5pt)
})

The stop and restart pair completes the instrument panel: `"stop"`
freezes the automatic collector but explicit calls still work, which is
how a benchmark can hold the heap still while it runs.

#listing("lua/samples/ch09_collector.lua", first: 87, last: 103, caption: [stop freezes the automatic collector, explicit calls still run])

== incremental anatomy

In incremental mode a mark-and-sweep cycle is sliced into steps
interleaved with the program's own execution. `collectgarbage("step")`
returns true when a call finished a cycle. The measurement that shapes
everything else in this section: garbage can outlive the cycle that
should have freed it. A table allocated while a cycle is mid-flight is
marked black as reachable, because at that moment it is, and the sweep
at the end of that cycle lets it go. The freed bytes arrive one whole
cycle later:

#listing("lua/samples/ch09_collector.lua", first: 59, last: 85, caption: [the drop needs the cycle after it, two cycle ends asserted])

#flow(
  [one incremental cycle, sliced],
  node((0, 0), [pause: waiting for the heap #linebreak() to hit pause% of the last total]),
  node((0, 1.7), [propagate: gray worklist drained #linebreak() in small steps]),
  node((0, 3.4), [atomic: the world stops, #linebreak() barriers resolve]),
  node((0, 5.1), [sweep: dead objects freed, #linebreak() count drops]),
  node((3.0, 1.7), [allocation during the cycle #linebreak() marks new objects black]),
  node((3.0, 5.1), [black garbage from mid-cycle #linebreak() waits for the next cycle]),
  edge((0, 0), (0, 1.7), "-|>"),
  edge((0, 1.7), (0, 3.4), "-|>"),
  edge((0, 3.4), (0, 5.1), "-|>"),
  edge((3.0, 1.7), (3.0, 5.1), "-|>", bend: -30deg),
)

How much work one step does is set by the step size knob, not by the
step's argument. Measured on this machine, 2026-09-13: a fresh process
clearing a 13 MB dropped heap at the 9600 KB default step size needed 4
steps and 2 cycle ends (`bench.lua trace`); the same heap and step size
inside the full sample suite, after eight chapters of allocation
history, needed 409 steps and 2 cycle ends. The step count is a
function of collector state, not a constant. An explicit 200 MB budget
argument to `"step"` changed the count by nothing measurable in either
state.

== the tricolor walk

The marking phase is a tricolor walk over the object graph. Roots are
grayed, a worklist drains: each gray object's children are grayed if
still white, then the object turns black. Cycles are irrelevant to
reachability, which is the whole point of tracing versus refcounting.
The walk runs in pure lua on a toy graph, one rooted cycle and one
unreachable island, and the real collector is then asked to agree
through weak values:

#listing("lua/samples/ch09_collector.lua", first: 205, last: 232, caption: [the walk in pure lua, cycles and all])
#listing("lua/samples/ch09_collector.lua", first: 234, last: 250, caption: [the real collector agrees, the island dies])

#diagram([three colors over the toy graph, one walk], length: 13pt, {
  // the color legend
  cdraw.rect((0.8, 10.2), (3.6, 11.4), fill: luma(245), radius: 0.02)
  cdraw.content((2.2, 10.8), [white], size: 6pt)
  cdraw.rect((4.0, 10.2), (6.8, 11.4), fill: luma(205), radius: 0.02)
  cdraw.content((5.4, 10.8), [gray, on the list], size: 6pt)
  cdraw.rect((7.2, 10.2), (10.0, 11.4), fill: luma(120), radius: 0.02)
  cdraw.content((8.6, 10.8), [black, survives], size: 6pt)
  // the reachable cycle
  cdraw.circle((5.0, 9.2), radius: 0.75, fill: luma(205))
  cdraw.content((5.0, 9.0), [a], size: 6pt)
  cdraw.circle((8.2, 9.2), radius: 0.75, fill: luma(120))
  cdraw.content((8.2, 9.0), [b], size: 6pt)
  cdraw.circle((6.6, 6.9), radius: 0.75, fill: luma(120))
  cdraw.content((6.6, 6.7), [c], size: 6pt)
  cdraw.circle((2.4, 6.9), radius: 0.75, fill: luma(120))
  cdraw.content((2.4, 6.7), [d], size: 6pt)
  cdraw.line((5.7, 9.2), (7.4, 9.2), stroke: luma(60), mark: (end: ">"))
  cdraw.line((7.9, 8.6), (6.9, 7.5), stroke: luma(60), mark: (end: ">"))
  cdraw.line((6.0, 7.1), (3.1, 7.0), stroke: luma(60), mark: (end: ">"))
  cdraw.line((3.4, 7.5), (4.4, 8.7), stroke: luma(60), mark: (end: ">"))
  // the island
  cdraw.circle((15.0, 8.1), radius: 0.75, fill: luma(245))
  cdraw.content((15.0, 7.9), [x], size: 6pt)
  cdraw.circle((18.2, 8.1), radius: 0.75, fill: luma(245))
  cdraw.content((18.2, 7.9), [y], size: 6pt)
  cdraw.line((15.7, 8.1), (17.4, 8.1), stroke: luma(60), mark: (end: ">"))
  cdraw.line((17.4, 7.7), (15.7, 7.7), stroke: luma(60), mark: (end: ">"))
  // the verdicts
  cdraw.content((11.0, 5.2), [the cycle from the root marks black, sweep keeps it], size: 6.5pt)
  cdraw.content((11.0, 4.0), [the island stays white, sweep frees it], size: 6.5pt)
  cdraw.content((11.0, 2.8), [reachability, not refcounts: cycles cannot leak], size: 6.5pt)
})

== the pause and step multipliers

Chapter 8 read and wrote the six knobs. The arithmetic behind the
incremental three, measured as this build's defaults on 2026-09-13:
pause 250, stepmul 200, stepsize 9600. Pause of n means a new cycle
starts when live bytes hit n% of the total after the previous
collection, so the default waits for a 2.5x heap (the manual's 200
example is the double). Step size n means roughly n bytes allocated
between automatic steps. Step multiplier n means n% units of work per
word allocated, and 0 is the special stop-the-world value. The values
are stored compressed: setting 333 reads back 325, 256 reads back 250,
and the documented 100000 ceiling reads back 99200:

#listing("lua/samples/ch09_collector.lua", first: 167, last: 177, caption: [compression: the stored value is not the written one])

Pause maxed out is the cleanest behavioral demonstration of the
arithmetic: with pause at 100000 the collector waits for a 1000x heap,
so a garbage burst grows the count monotonically, 22.5 MB over a 24 KB
floor measured in a fresh probe, a 943x ratio, with no reclaim until
the knob comes home:

#listing("lua/samples/ch09_collector.lua", first: 179, last: 203, caption: [a 1000x pause defers the cycle, the heap only grows])

#diagram([the pause threshold against the heap], length: 13pt, {
  // the heap line
  cdraw.line((0.8, 3.2), (20.8, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.4, 2.5), [bytes in use], size: 6pt)
  // the 2.5x default threshold
  cdraw.line((6.6, 3.2), (6.6, 9.4), stroke: luma(140))
  cdraw.content((6.6, 10.0), [pause 250: cycle starts #linebreak() at 2.5x the last total], size: 6pt)
  // the 1000x threshold
  cdraw.line((17.6, 3.2), (17.6, 9.4), stroke: luma(140))
  cdraw.content((17.4, 10.0), [pause 100000: the wait #linebreak() for a 1000x heap], size: 6pt)
  // the measured burst
  cdraw.line((1.6, 3.4), (17.2, 8.0), stroke: luma(60))
  cdraw.content((10.0, 7.3), [one garbage burst, 22.5 MB, monotonic], size: 6pt)
  // the other two knobs
  cdraw.content((11.0, 6.0), [step size 9600: bytes between automatic steps], size: 6.5pt)
  cdraw.content((11.0, 4.8), [stepmul 200: work per word, 0 is stop the world], size: 6.5pt)
  cdraw.content((11.0, 1.6), [restore the knob, one collect, back at the floor], size: 6.5pt)
})

== generational anatomy

5.5 defaults to generational mode, and its majors run incrementally.
Minor collections traverse only objects born since the last one, which
makes two facts observable from lua. Fresh young garbage dies to a
single minor step. But a table that is alive across a minor, referenced
at the moment the minor runs, is tenured into the old generation, and
old garbage is invisible to minors: a 3.5 MB tenured cohort survived
301 consecutive minor steps at byte-for-byte the same count and was
freed only by the explicit major that `"collect"` runs:

#listing("lua/samples/ch09_collector.lua", first: 105, last: 118, caption: [a fresh young cohort dies to one minor])
#listing("lua/samples/ch09_collector.lua", first: 120, last: 139, caption: [tenured garbage is minor-proof, the major frees it])

#diagram([two generations, promotion, and the three multipliers], length: 13pt, {
  // young generation
  cdraw.rect((0.8, 5.6), (9.6, 9.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 9.1), [the young generation], size: 6pt)
  cdraw.content((5.2, 8.0), [born since the last minor], size: 6pt)
  cdraw.content((5.2, 6.8), [a minor traverses only this], size: 6pt)
  cdraw.content((5.2, 5.9), [dead young objects die cheaply], size: 6pt)
  // old generation
  cdraw.rect((11.6, 5.6), (20.4, 9.6), fill: luma(205), radius: 0.02)
  cdraw.content((16.0, 9.1), [the old generation], size: 6pt)
  cdraw.content((16.0, 8.0), [survivors of a minor, tenured], size: 6pt)
  cdraw.content((16.0, 6.8), [only a major traverses it], size: 6pt)
  cdraw.content((16.0, 5.9), [majors run incrementally in 5.5], size: 6pt)
  // the promotion arrow
  cdraw.line((9.8, 7.6), (11.4, 7.6), stroke: luma(60), mark: (end: ">"))
  cdraw.content((10.6, 8.2), [alive #linebreak() across one #linebreak() minor], size: 6pt)
  // the multipliers
  cdraw.content((5.0, 4.2), [minormul 20: minor at +20% of the post-major total], size: 6.5pt)
  cdraw.content((14.4, 3.0), [minormajor 68: old-byte growth schedules the major], size: 6.5pt)
  cdraw.content((11.0, 1.8), [majorminor 50: the shift back once a major pays], size: 6.5pt)
})

A young object held alive through its cohort's death is the promotion
proof from the other side: it survives forty minor steps and a full
major with its payload intact while everything allocated beside it is
gone. The three generational defaults measured on this build are
minormul 20, minormajor 68, majorminor 50, and the same state
dependence seen in incremental mode applies: in a fresh process the
minor steps alone reclaimed a 3.5 MB young cohort, inside the full
suite the tenured cohort needed the major. The suite pins both
directions honestly, one per design.

== the allocator hook, from lua

Every byte the collector manages arrives through one function pointer,
the `lua_Alloc` hook a host passes to `lua_newstate`:
`f(ud, ptr, osize, nsize)`. The contract is realloc-shaped but not
realloc: `ud` is an opaque pointer the host chose, `ptr` is the block
being created, grown, shrunk, or freed, `osize` its old size, `nsize`
the requested one. When `nsize` is zero the hook frees and returns
null. When `ptr` is null the hook creates, and `osize` then carries a
type tag, `LUA_TSTRING`, `LUA_TTABLE`, and so on, for exactly the
calls that create a new collectable object. The manual's own
`luaL_alloc` is the whole thing in eight lines over `free` and
`realloc`.

Chapter 14 and chapter 18 build hosts, but none swaps the allocator,
so the hook is not demonstrated live from this book: the honest
instrument is the count-delta census, which measures the same traffic
the hook would see, allocations that grew the heap and the collect
that returned it:

#listing("lua/samples/ch09_collector.lua", first: 265, last: 276, caption: [the census: what the hook would have counted, measured by delta])

#diagram([one block's life through the hook], length: 13pt, {
  // four call shapes as a timeline
  cdraw.line((1.0, 6.0), (20.6, 6.0), stroke: luma(100), mark: (end: ">"))
  let call(x, l1, l2) = {
    cdraw.rect((x - 1.8, 6.6), (x + 1.8, 8.8), fill: luma(235), radius: 0.02)
    cdraw.content((x, 8.2), l1, size: 6pt)
    cdraw.content((x, 7.2), l2, size: 6pt)
    cdraw.line((x, 6.6), (x, 6.0), stroke: luma(120))
  }
  call(4.2, [create], [ptr null, #linebreak() osize is a type])
  call(9.4, [grow], [realloc, #linebreak() osize the old size])
  call(14.6, [shrink], [same shape, #linebreak() nsize smaller])
  call(19.6, [free], [nsize zero, #linebreak() return null])
  // the honest boundary
  cdraw.content((11.0, 5.0), [ud rides every call, chosen by lua_newstate], size: 6.5pt)
  cdraw.content((11.0, 3.8), [null return means failure, and only failure], size: 6.5pt)
  cdraw.content((11.0, 2.6), [no host swaps the allocator: the census stands in, chapter 14's boundary], size: 6.5pt)
})

== weak tables and finalizers, in one breath

The endgame machinery stays where chapter 8 measured it. Weak entries
clear when the last strong reference elsewhere dies, `__mode` picking
keys, values, or both, `__gc` marks only when present at setmetatable
time, finalizers run in reverse marking order, and a finalizer that
stores its object somewhere reachable resurrects it. One recap test
holds the whole story in miniature:

#listing("lua/samples/ch09_collector.lua", first: 252, last: 263, caption: [the held value survives, the dropped one clears])

#flow(
  [a weak entry's life],
  node((0, 0), [a weak table holds a value]),
  node((0, 1.7), [the last strong reference #linebreak() elsewhere dies]),
  node((0, 3.4), [the collector claims the object]),
  node((0, 5.1), [the entry drops at the next cycle]),
  node((3.0, 1.7), [one strong reference survives, #linebreak() the entry holds]),
  edge((0, 0), (0, 1.7), "-|>"),
  edge((0, 1.7), (0, 3.4), "-|>"),
  edge((0, 3.4), (0, 5.1), "-|>"),
  edge((0, 1.7), (3.0, 1.7), "-|>", label: [never]),
)

== the particle kernel, boxed

The corpus-wide particle kernel lands here in its densest lua form: n
particles, eight float64 fields each, boxed as tables `t[1..8]`, a
seeded `xorshift64`-star generator, and a pure arithmetic step with no
allocation after init, `pos += vel*dt + 0.5*a*dt^2` under an analytic
spring-and-field force, sixteen steps to a run:

#listing("lua/samples/kernel.lua", first: 18, last: 41, caption: [the seeded generator and the boxed layout])
#listing("lua/samples/kernel.lua", first: 44, last: 63, caption: [the arithmetic step, allocation free])

#diagram([one particle, boxed against dense], length: 13pt, {
  // the boxed form: header plus eight tagged slots
  cdraw.rect((1.0, 6.2), (12.6, 9.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.8, 8.9), [boxed: one table per particle], size: 6pt)
  cdraw.rect((1.6, 6.6), (3.6, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((2.6, 7.4), [header], size: 6pt)
  let slot(x, label) = {
    cdraw.rect((x, 6.6), (x + 1.1, 8.2), fill: luma(245), radius: 0.02)
    cdraw.content((x + 0.55, 7.4), label, size: 6pt)
  }
  slot(4.0, [x]); slot(5.2, [y]); slot(6.4, [z]); slot(7.6, [vx])
  slot(8.8, [vy]); slot(10.0, [vz]); slot(11.2, [m])
  cdraw.content((12.0, 7.4), [q], size: 6pt)
  // the dense form
  cdraw.rect((14.2, 6.2), (20.6, 9.4), fill: luma(205), radius: 0.02)
  cdraw.content((17.4, 8.9), [dense: 8 doubles], size: 6pt)
  cdraw.content((17.4, 7.4), [64 contiguous bytes, #linebreak() the ffi form], size: 6pt)
  // the budget
  cdraw.content((11.0, 5.0), [measured: 133.4 bytes per boxed particle at 1m, 139.1 at 10m], size: 6.5pt)
  cdraw.content((11.0, 3.8), [payload is 64 bytes: boxing pays 2.1x, header and tagged slots], size: 6.5pt)
  cdraw.content((11.0, 2.6), [100m boxed is 13.9 gb by this arithmetic, not run on this machine], size: 6.5pt)
})

Measured on this machine, 2026-09-13, `samples/bench.lua scale`, a
lua-5.5-only opt-in script the gates never run: at 1m particles init
took 0.545 s and grew the heap 130310 KB, 133.4 bytes per particle,
and sixteen steps took 1.825 s of `os.clock` cpu, 114.1 ns per
particle per step, with the heap exactly flat across the loop, +0 KB,
because the step allocates nothing and the collector has nothing to
do. At 10m: init 6.169 s, 1358394 KB, 139.1 bytes per particle, the
same sixteen steps 23.678 s, 148.0 ns per particle per step, slowest
single step 1.577 s. Both runs return to the 31 KB floor after one
collect. The 100m scale is infeasible by design in the boxed form:
the same arithmetic prices it at 13.9 gb against the 14.4 gb of free
memory measured on this machine, and that is the chapter's conclusion
working as intended, the representation is the budget. The ffi path in
the capstone carries 100m in 6.4 gb of cdata.

The suite keeps a 10k-particle smoke with both checksums pinned, fast
enough for every gate run, and the seed is printed by every bench run:

#listing("lua/samples/ch09_collector.lua", first: 278, last: 286, caption: [the smoke: 10k particles, both checksums pinned])
#listing("lua/samples/bench.lua", first: 12, last: 36, caption: [the opt-in scale run every number above came from])

sources: lua.org manual 5.5 sections 2.5.1 through 2.5.4, 4.6
(lua_Alloc, lua_gc, lua_newstate), 6.2 (collectgarbage), accessed
2026-09-13. All measurements from lua 5.5.1 built at tools/lua55, run
on this machine, 18 tests green through `make verify-lua`.
