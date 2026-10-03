#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= cpu scheduling algorithms

Chapter 15 ended on a division of labor: the program owns the predicate
and the lock, the scheduler owns the order. This chapter opens the
scheduler's side. Seven policies run the same four jobs through the same
harness, every turnaround, response, and wait triple below was computed
by hand from a unit-by-unit trace before it became a `CHECK`, and one
sample drives real Windows threads to show the one scheduling knob the
kernel actually sells. The policy zoo is not folklore here: each
algorithm's numbers on the fixed set are frozen in its source, the gate
recomputes them on every run, and the closing table lines all ten rows
up side by side.

The seven simulators are pure user-space arithmetic, one translation
unit each over one shared header. Nothing in them calls the operating
system, which is the point: a scheduler policy is a function from
(arrival, burst) histories to a dispatch order, and a function that
calls the kernel cannot be checked deterministically. The kernel enters
twice, both times labeled: `setpriority.c` proves `SetThreadPriority`'s
contract on live threads, and the linux facts are quoted from canonical
pages, cited and never executed, the treatment chapter 11 gave `fork`.

== the model and the metrics

One job is five numbers and three fields of simulator state:

#listing("c-os-cloud/samples/src/Ch17/sched.h", first: 13, last: 34, caption: [the job record and the fixed four-job set every algorithm drives])

The fixed set is the whole chapter's universe: A arrives at 0 wanting 7
units, B at 2 wanting 4 at the highest priority, C at 4 wanting 1 at the
lowest, D at 5 wanting 4. Total work is 16 units, so on a cpu that never
idles every algorithm finishes at 16, and every difference between the
rows of the closing table is a difference in ordering, not in total
work. The `nice` field only feeds the weighted fair scheduler; its sign
convention, lower value more cpu, is the unix one: POSIX defines the
nice value as "a non-negative number" where "a more positive value
shall result in less favorable scheduling" and "Only a process with
appropriate privileges can lower the nice value", linux runs the same
direction over -20 to 19, setpriority(2)'s range with -20 the highest,
and the last section runs the arithmetic on it. The three metrics are
pure functions of the record:

#listing("c-os-cloud/samples/src/Ch17/sched.h", first: 46, last: 56, caption: [turnaround, response, wait: finish, first, arrival, burst combined])

Turnaround is `finish - arrival`, the job's whole lifetime from
submission to completion. Response is `first - arrival`, submission to
first cpu touch, the metric an interactive system feels. Wait is
turnaround minus burst, the time the job existed without running. Each
simulator also records its dispatch order as one letter per unit, the
string `AAAAAAABBBBCDDDD` and its rivals, and the header counts context
switches off that string, adjacent differing letters, so every algorithm
is metered the same way.

#diagram([the model on one job: B's record, and B's three metrics marked on the fcfs timeline], length: 13pt, {
  let field(y, t) = {
    cdraw.rect((0.4, y), (5.6, y + 0.9), fill: luma(235), radius: 0.02)
    cdraw.content((3.0, y + 0.45), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((3.0, 8.9), [struct job, B's values], wrap: text.with(size: 6.5pt, weight: 700))
  field(7.6, [name 'B'])
  field(6.5, [arrival 2, burst 4])
  field(5.3, [priority 1, nice -1])
  field(4.1, [first 7, finish 11])
  // the fcfs timeline 0..16, B's block shaded
  let x0 = 8.2
  let sc = 0.8
  for t in range(16) {
    let ch = if t < 7 { "A" } else if t < 11 { "B" } else if t < 12 { "C" } else { "D" }
    let f = if ch == "B" { luma(160) } else { luma(235) }
    cdraw.rect((x0 + t * sc, 3.2), (x0 + (t + 1) * sc, 4.1), fill: f, radius: 0.02)
    cdraw.content((x0 + (t + 0.5) * sc, 3.65), ch, wrap: text.with(size: 5.5pt))
  }
  cdraw.content((x0 + 8 * 0.8 + 3.0, 4.5), [fcfs order, B runs 7 to 11], wrap: text.with(size: 6pt))
  // ticks at 0, 2, 7, 11, 16
  for (t, lab) in ((0, "0"), (2, "2"), (7, "7"), (11, "11"), (16, "16")) {
    cdraw.line((x0 + t * sc, 3.2), (x0 + t * sc, 2.95), stroke: luma(100))
    cdraw.content((x0 + t * sc, 2.6), lab, wrap: text.with(size: 6pt))
  }
  // response 2..7, turnaround 2..11
  cdraw.line((x0 + 2 * sc, 2.0), (x0 + 7 * sc, 2.0), stroke: luma(100), mark: (start: "|", end: "|"))
  cdraw.content((x0 + 4.5 * sc, 2.25), [response = first - arrival = 5], wrap: text.with(size: 6pt))
  cdraw.line((x0 + 2 * sc, 1.2), (x0 + 11 * sc, 1.2), stroke: luma(100), mark: (start: "|", end: "|"))
  cdraw.content((x0 + 6.5 * sc, 1.45), [turnaround = finish - arrival = 9], wrap: text.with(size: 6pt))
  cdraw.content((x0 + 6.5 * sc, 0.3), [wait = turnaround - burst = 5, the same stretch twice queued], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "the hand traces were wrong twice before they were right", [
  The first version of this chapter's constants held a round-robin
  trace that gave job A 9 units of cpu for a 7-unit burst, and a
  priority trace that re-ran units A had already spent. Both were
  hand-derived, both looked plausible, and both disagreed with the
  simulators. Recounting from the order strings proved the sims right
  both times: hand arithmetic that reuses a job's already-run prefix is
  exactly the mistake the `CHECK` count exists to catch. Every pair in
  every sample below survived that recount.
])

== fcfs, sjf, srtf

First come first served is the null policy: the table is sorted by
arrival, so walking it in order and running each burst to completion is
the whole algorithm.

#listing("c-os-cloud/samples/src/Ch17/fcfs.c", first: 25, last: 37, caption: [fcfs: arrival order, each burst runs to completion])

A runs 0-7, B 7-11, C 11-12, D 12-16. The convoy effect is visible in
one number: C has a 1-unit burst and waits 7 units for it, because it
had the bad luck to arrive behind A's 7. Averages over the four jobs:
turnaround 8.75, response 4.75, wait 4.75, with 3 switches. Shortest
job first fixes exactly that, at a price:

#listing("c-os-cloud/samples/src/Ch17/sjf.c", first: 47, last: 71, caption: [sjf: at each completion the shortest arrived burst runs next])

At time 7 the ready set is B (burst 4), C (burst 1), D (burst 4). C
runs 7-8, then the B and D tie at burst 4 resolves to the earlier
arrival, B 8-12, D 12-16. Turnaround sum 32 beats fcfs's 35, response
16 beats 19. The price is clairvoyance: the scheduler must know each
burst before running it, which real systems do not. The sample then
settles the optimality question the honest way, by exhausting all 24
orders of the four jobs:

#listing("c-os-cloud/samples/src/Ch17/sjf.c", first: 92, last: 113, caption: [sjf optimality by exhaustion: idle-allowed best 31, never-idle best 32])

Two facts fall out. Among non-preemptive orders that never idle while
work exists, which on this set are the orders starting with A, no order
beats sjf's 32, and exactly two tie. But the global best over all 24 orders is 31, uniquely B, C,
D, A: that schedule idles from 0 to 2 on purpose, declines to start the
long job that is sitting there, and waits for the short one. sjf is
optimal among busy schedules, not among all schedules; a clairvoyant
scheduler that sleeps in waits less on average. Shortest remaining time
first is sjf with preemption, and preemption is one changed compare:

#listing("c-os-cloud/samples/src/Ch17/srtf.c", first: 28, last: 49, caption: [srtf: every unit the least remaining runs, arrivals preempt by arithmetic])

No preemption code exists. The unit loop simply re-picks, and when B
arrives at 2 with 4 units against A's remaining 5, the compare switches
sides by itself. The chain: A 0-2, B preempts at 2, C's arrival at 4
(remaining 1 under B's 2) preempts again, B drains 5-7, D outranks A's
5 remaining with 4 at 7, and A's tail lands last, 11-16. Response
collapses from sjf's 16 to 2, B, C, and D each touch the cpu the
moment they arrive or within 2 units, while A's turnaround balloons to
16, the whole makespan: srtf buys response with the long job's tail.

#diagram([the three batch policies as dispatch orders over the same 16 units], length: 13pt, {
  let fill = ("A": luma(232), "B": luma(210), "C": luma(186), "D": luma(162))
  let row(y, label, order) = {
    cdraw.content((-1.1, y + 0.42), label, wrap: text.with(size: 6pt))
    for (i, ch) in order.clusters().enumerate() {
      cdraw.rect((i * 0.82, y), ((i + 1) * 0.82, y + 0.84), fill: fill.at(ch), radius: 0.02)
      cdraw.content((i * 0.82 + 0.41, y + 0.42), ch, wrap: text.with(size: 6pt))
    }
  }
  for t in (0, 4, 8, 12, 16) {
    cdraw.line((t * 0.82, 0.7), (t * 0.82, 7.3), stroke: luma(220))
    cdraw.content((t * 0.82, 0.3), str(t), wrap: text.with(size: 6pt))
  }
  row(6.2, "fcfs", "AAAAAAABBBBCDDDD")
  row(4.6, "sjf", "AAAAAAACBBBBDDDD")
  row(3.0, "srtf", "AABBCBBDDDDAAAAA")
  cdraw.content((6.6, 1.5), [darker cells ran later into the timeline: C's single unit sits at 11 under fcfs, at 7 under sjf, at 4 under srtf], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== round robin, priority with aging

Round robin replaces the burst with a quantum: the fifo head runs at
most `quantum` units, then requeues. One convention decides every trace
this section reports, and it sits in three lines:

#listing("c-os-cloud/samples/src/Ch17/rr.c", first: 32, last: 47, caption: [the rr fifo: arrivals enter before a preempted job requeues at the same instant])

At each tick boundary, jobs arriving at that instant join the fifo
first, and only then does a job whose quantum just expired requeue
behind them. At time 4, C's arrival enters before B's requeue, so the
dispatch order from there is A, C, B. A quantum expiring exactly on an
arrival puts the newcomer ahead: the alternative convention changes
traces, and pinning one is the price of exact numbers. With quantum 2
the trace runs A 0-2, B 2-4, A 4-6, C 6-7, B 7-9, D 9-11, A 11-13, D
13-15, A 15-16: turnaround sum 36, response sum 6, 8 switches. The
quantum is a dial, and the sample turns it:

#listing("c-os-cloud/samples/src/Ch17/rr.c", first: 75, last: 94, caption: [the quantum cost model: q=1, 2, 4 on the same set, verdicts checked])

At q=1 the response sum is 3 but the cpu changes hands 14 times; at
q=4 response rises to 13 and switches fall to 4; turnaround drifts from
38 down to 34 as the quantum grows toward batch behavior. Every switch
is pipeline state thrown away, which is why the dial has no right
setting, only a workload-dependent one. Windows states its own setting
in its model: the Scheduling Priorities page says "The system treats
all threads with the same priority as equal. The system assigns time
slices in a round-robin fashion to all threads with the highest
priority", and the SetThreadPriority page repeats the mechanism,
"Threads are scheduled in a round-robin fashion at each priority
level, and only when there are no executable threads at a higher level
does scheduling of threads at a lower level take place." Round robin at
32 priority levels is the real os's within-level rule, not just a
teaching toy.

Priority scheduling replaces the fifo with a ranking. This chapter's
policy is preemptive: every unit, the arrived unfinished job with the
smallest effective priority runs, ties keeping the earlier arrival. On
the fixed set, B (priority 1) preempts A at 2 and finishes at 6, A
resumes 6-11, D runs 11-15, C's single unit lands 15-16: turnaround sum
37, response sum 17. C's response of 11 is worse than fcfs's 7, the
price of D and A outranking it. The real cost of strict priority is
elsewhere and the second scenario measures it: one 20-unit job L at
priority 3 arrives at 1, and a stream of ten 2-unit jobs at priority 1
arrives every 2 units from 2 on. Under strict priority L first touches
the cpu at 22 and finishes at 42, waiting 21 units. Aging deletes the
starvation with arithmetic:

#listing("c-os-cloud/samples/src/Ch17/prio.c", first: 32, last: 41, caption: [aging: one priority step per two units waited, floored at 1])

#listing("c-os-cloud/samples/src/Ch17/prio.c", first: 87, last: 109, caption: [the starvation set and both verdicts: L waits 21 under strict priority, runs at 5 under aging])

At time 5, L has waited 4 units, 4/2 = 2 steps, static 3 drops to an
effective 1 that ties the stream, and the arrival tie-break hands L the
cpu. L runs 5-25 and the stream finishes behind it at 42. One division
moved 17 units of wait, and the aging rule is the whole difference
between the two printed verdicts. Windows pushes on the same wound
from the other side: the SetThreadPriority page says of background
mode, "If there are threads executing at high priority, a thread in
background processing mode may not be scheduled promptly, but it will
never be starved", and of the dynamic layer, "the system dynamically
boosts a thread's base priority level when events occur that are
important to the thread."

The knob itself is real, small, and checkable. Its page fixes the
model: the priority value "together with the priority class of the
thread's process, determines the thread's base priority level", and
"All threads initially start at `THREAD_PRIORITY_NORMAL`". For a
`NORMAL_PRIORITY_CLASS` process the base table runs 1, 6, 7, 8, 9, 10,
15 across idle, lowest, below normal, normal, above normal, highest,
time critical: the middle band is class value plus offset, the ends
pinned at 1 and 15.

#listing("c-os-cloud/samples/src/Ch17/setpriority.c", first: 60, last: 77, caption: [the knob contract on live threads: set, read back, background begin, refuse, end])

Every claim in that listing is a documented behavior, not an
observation: the normal start, the readback of 2 and -15, and the
documented failure mode of background mode, "The function fails if the
thread is already in background processing mode", which is why the
second `SetThreadPriority` call is checked for failure, not success.
The contention experiment then shows the knob working:

#listing("c-os-cloud/samples/src/Ch17/setpriority.c", first: 79, last: 96, caption: [two workers, one pinned core, two priorities: equal work under forced contention])

Priority is only visible under contention, so both workers are pinned
to cpu 0 by `SetThreadAffinityMask` and released together. Both
compute the identical checksum over 100 million iterations. Probed on
this machine 2026-09-12: the above-normal worker did its work
in 41.5 ms and was done at +41.6 ms; the below-normal worker did
equivalent work in 42.9 ms and was done at +84.6 ms. The higher
priority effectively owned the core until it finished, the page's
promise in action: "If a higher-priority thread becomes available to
run, the system ceases to execute the lower-priority thread (without
allowing it to finish using its time slice)". Those wall-clock numbers
are probes, printed and never checked, because shares of a cpu belong
to the scheduler, not to the program.

#callout("warning", "the top of the band bites", [
  The SetThreadPriority page draws the line in one sentence: "A thread
  with a base priority level above 11 interferes with the normal
  operation of the operating system." The samples above never leave
  the documented relative band, highest at 10 for a normal-class
  process, and `REALTIME_PRIORITY_CLASS` appears here only as the table
  row that disables dynamic boosts.
])

#diagram([the quantum dial: same set, same order discipline, three quanta], length: 13pt, {
  let fill = ("A": luma(232), "B": luma(210), "C": luma(186), "D": luma(162))
  let row(y, label, order, note) = {
    cdraw.content((-1.6, y + 0.42), label, wrap: text.with(size: 6pt))
    for (i, ch) in order.clusters().enumerate() {
      cdraw.rect((i * 0.82, y), ((i + 1) * 0.82, y + 0.84), fill: fill.at(ch), radius: 0.02)
      cdraw.content((i * 0.82 + 0.41, y + 0.42), ch, wrap: text.with(size: 6pt))
    }
    cdraw.content((14.6, y + 0.42), note, wrap: text.with(size: 6pt, fill: luma(100)))
  }
  for t in (0, 4, 8, 12, 16) {
    cdraw.line((t * 0.82, 0.7), (t * 0.82, 7.3), stroke: luma(220))
    cdraw.content((t * 0.82, 0.3), str(t), wrap: text.with(size: 6pt))
  }
  row(6.2, "q=1", "AABABCADBADBADAD", "14 switches")
  row(4.6, "q=2", "AABBAACBBDDAADDA", "8 switches")
  row(3.0, "q=4", "AAAABBBBCAAADDDD", "4 switches")
  cdraw.content((6.6, 1.4), [response sums 3, 6, 13: the finer the slice, the sooner a newcomer touches the cpu, the more hands change], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== multilevel feedback queues

The policies so far each know one thing: fcfs knows arrival, sjf knows
burst, priority knows a rank. A multilevel feedback queue knows
nothing up front and learns from the job's own behavior. This chapter
fixes the ruleset: three queues with quanta 2, 4, and run to
completion; arrivals always enter the top queue; an arrival above the
running job's level preempts it, the preempted job keeping its level at
that level's tail; a job that spends its whole quantum is demoted one
level; and every `promote` time units everything returns to the top.

#listing("c-os-cloud/samples/src/Ch17/mlfq.c", first: 71, last: 88, caption: [arrivals enter the top queue, a higher queue preempts, the highest nonempty head dispatches])

#listing("c-os-cloud/samples/src/Ch17/mlfq.c", first: 100, last: 109, caption: [finish or demote: a spent quantum costs one level, the bottom queue keeps])

On the fixed set the trace is A 0-2 demoted, B 2-4 demoted, C 4-5 done
from the top queue, D 5-7 demoted, then the middle queue drains A
7-11 (demoted again), B 11-13, D 13-15, and A's last unit runs from
the bottom, 15-16. The learning is visible: A, the 7-unit job, sinks
twice; C, the 1-unit job, rides the top queue to a finish at its
arrival instant. Response sum is 0, every job first touched at
arrival, something no policy above bought at this turnaround price
(sum 38). The promotion reset exists for the job that learns wrong:

#listing("c-os-cloud/samples/src/Ch17/mlfq.c", first: 37, last: 54, caption: [the promotion reset: every job returns to the top queue in level then fifo order])

Scenario 2 runs A (16 units, arrives alone) against B (3 units,
arrives at 3) with promotion every 15. B's arrival preempts A from the
top queue at 3; A falls to the middle at 2, to the bottom by 9; the
promotion at 15 pulls it back to the top mid-run, and one demotion and
one middle-quantum later it finishes at 19. The sample checks the
bookkeeping: exactly one promotion fired, A spent exactly 5 units at
the bottom, B finished at 10.

#listing("c-os-cloud/samples/src/Ch17/mlfq.c", first: 134, last: 148, caption: [scenario 2 verdicts: one promotion at t=15 pulls A off the bottom queue])

The linux ancestry of this shape is documented on both ends. sched(7)
states the succession: "Since Linux 2.6.23, the default scheduler is
CFS, the "Completely Fair Scheduler". The CFS scheduler replaced the
earlier "O(1)" scheduler", and names the older one's property, "the
newly introduced O(1) scheduler ensures that the time needed to
schedule is fixed and deterministic irrespective of the number of
active tasks." The CFS design notes describe that predecessor without
fondness: CFS "has no "array switch" artifacts (by which both the
previous vanilla scheduler and RSDL/SD are affected)", "has no notion
of "timeslices" in the way the previous scheduler had, and has no
heuristics whatsoever", and its real-time side "uses 100 runqueues
(for all 100 RT priority levels, instead of 140 in the previous
scheduler)". A priority array per level, the "array switch" the
notes name as an artifact, and interactivity heuristics: of these the
notes say CFS "is not prone to any of the 'attacks' that exist today
against the heuristics of the stock scheduler". That predecessor is
the multilevel feedback design this section simulated, fifo queues and
a promote timer in place of heuristics, and the two things the notes
hold against it, the array switch and the heuristics, are exactly the
two parts this chapter's fixed ruleset replaced with explicit
mechanics.

#diagram([the mlfq state machine: three queues, demotion on a spent quantum, the promotion reset], length: 13pt, {
  let qbox(y, t) = {
    cdraw.rect((5.0, y), (15.0, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((10.0, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((1.8, 8.35), [arrival], wrap: text.with(size: 6.5pt))
  cdraw.line((1.8, 8.0), (5.0, 8.0), stroke: luma(100), mark: (end: ">"))
  qbox(7.5, [q0: quantum 2, round robin])
  qbox(5.4, [q1: quantum 4, round robin])
  qbox(3.3, [q2: run to completion])
  // demotion diagonals on the right, labels beside each arrow tip
  cdraw.line((15.4, 7.5), (17.2, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.8, 6.7), [quantum spent], wrap: text.with(size: 6pt))
  cdraw.line((15.4, 5.4), (17.2, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.8, 4.6), [quantum spent], wrap: text.with(size: 6pt))
  cdraw.line((10.0, 7.5), (10.0, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.8, 6.95), [demote], wrap: text.with(size: 6pt))
  cdraw.line((10.0, 5.4), (10.0, 4.3), stroke: luma(100), mark: (end: ">"))
  // the cpu takes the head of the highest nonempty queue
  cdraw.rect((21.6, 7.8), (24.6, 8.8), fill: luma(205), radius: 0.02)
  cdraw.content((23.1, 8.3), [cpu], wrap: text.with(size: 6pt))
  cdraw.line((15.0, 8.3), (21.6, 8.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.7, 7.8), [head of the highest #linebreak() nonempty queue], wrap: text.with(size: 6pt))
  // the promotion reset sweeps far right, up, and back into q0's top
  cdraw.line((15.0, 3.8), (26.2, 3.8), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((26.2, 3.8), (26.2, 9.6), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((26.2, 9.6), (7.5, 9.6), stroke: (paint: luma(100), dash: "dashed"))
  cdraw.line((7.5, 9.6), (7.5, 8.5), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((15.5, 9.95), [promotion reset, every promote units, level resets to 0], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((1.6, 4.85), [a higher-queue arrival preempts; #linebreak() the preempted job keeps its level], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((2.2, 1.9), [the rules this chapter fixes: quanta 2, 4, and run to completion, promote period a parameter], wrap: text.with(size: 6.5pt))
})

== cfs and eevdf

The completely fair scheduler inverts the whole chapter. Every policy
above ranks jobs and runs the winner; CFS imagines hardware with no
winner at all. Its design notes open with the model: "CFS basically
models an "ideal, precise multi-tasking CPU" on real hardware", a cpu
that "can run each task at precise equal speed, in parallel, each at
`1/nr_running` speed". Real hardware runs one task at a time, so the
model needs a bookkeeping number: "The virtual runtime of a task
specifies when its next timeslice would start execution on the ideal
multi-tasking CPU described above", and the picking rule is one
sentence, the notes say CFS "always tries to run the task with the
smallest `p->se.vruntime` value (i.e., the task which executed least so
far)". On an rbtree keyed by vruntime, the balanced search tree the dsa
book covers in its trees chapters, that sentence becomes "CFS picks
the "leftmost" task from this tree and sticks to it."

#listing("c-os-cloud/samples/src/Ch17/cfs.c", first: 28, last: 32, caption: [one nice step is factor 1.25, scaled to integers 6400, 5120, 4096])

The 1.25 is cited arithmetic, sched(7) on nice: "each unit of
difference in the nice values of two processes results in a factor of
1.25 in the degree to which the scheduler favors the higher priority
process", and the sample's weights are that rule scaled to stay exact
in integers, 5120 times 1.25 is 6400, divided is 4096.

#listing("c-os-cloud/samples/src/Ch17/cfs.c", first: 69, last: 81, caption: [the cfs pick: minimum vruntime runs, its vruntime advances by 100 times 5120 over weight])

With equal weights vruntime is received cpu and the picker degenerates
into the fair twin of q=1 round robin, but with a sharper property:
response sum 0 on the fixed set, every job first touched at arrival,
at turnaround sum 35, where q=1 rr paid 38. With weights, B at nice -1
advances vruntime 80 per unit against D's 100 at nice 0, so B's 4-unit
burst finishes at 11 while the equal-burst D waits until 13: the 1.25
factor is a real share, not a hint. The sample also tracks the worst
vruntime spread among started competitors and checks it stays inside
one maximum weighted slice, 125: measured 120, which happens at time 3
when A sits at 200 and B at 80, the weight ratio visible as a gap. The
kernel handles the other spike, a newcomer arriving at vruntime 0
against established jobs, with placement: the notes describe
`rq->cfs.min_vruntime` as "a monotonic increasing value tracking the
smallest vruntime among all tasks in the runqueue", used "to place
newly activated entities on the left side of the tree"; the simulator
instead excludes not-yet-started jobs from the spread and says so in
its source.

EEVDF, the scheduler that replaced CFS, keeps the ledger and adds a
deadline. The kernel page states the succession: "The Linux kernel
began transitioning to EEVDF in version 6.6 (as a new option in 2024),
moving away from the earlier Completely Fair Scheduler (CFS) in favor
of a version of EEVDF proposed by Peter Zijlstra in 2023", and the
fairness goal is unchanged, "Similarly to CFS, EEVDF aims to
distribute CPU time equally among all runnable tasks with the same
priority." The new mechanics are the lag and the virtual deadline: the
scheduler "assigns a virtual run time to each task, creating a "lag"
value that can be used to determine whether a task has received its
fair share of CPU time. In this way, a task with a positive lag is
owed CPU time, while a negative lag means the task has exceeded its
portion", then "EEVDF picks tasks with lag greater or equal to zero
and calculates a virtual deadline (VD) for each, selecting the task
with the earliest VD to execute next." The sample checks that
arithmetic exactly, no run queue needed:

#listing("c-os-cloud/samples/src/Ch17/cfs.c", first: 102, last: 118, caption: [eevdf arithmetic: exact fair shares, lag signs, eligibility, the virtual deadline comparison])

Two jobs at weights 6400 and 4096 over a 41-unit window have fair
shares of exactly 25 and 16, and with one slice traded across that
split the lags are -1 and +1: the negative job exceeded its portion,
the positive one is owed cpu, and only the owed one is eligible. The
deadline half is why fairness moved from vruntime to deadlines: the
page notes "this allows latency-sensitive tasks with shorter time
slices to be prioritized, which helps with their responsiveness", and
"tasks can preempt others if their VD is earlier, and tasks can
request specific time slices using the new `sched_setattr()` system
call". Under pure vruntime a task cannot ask for latency; under
deadlines a shorter requested slice means an earlier deadline, and the
sample's last two checks pin that comparison, 200 against 400 for
slices 2 and 4. The page also records the anti-gaming half of the
design: "when a task sleeps, it remains on the run queue but marked
for "deferred dequeue," allowing its lag to decay", so a task cannot
sleep off a negative lag.

#listing("c-os-cloud/samples/src/Ch17/cfs.c", first: 120, last: 133, caption: [weighted verdicts: the heavier equal-burst job finishes first, spread bounded])

#diagram([vruntime trajectories of the weighted run: three lines converging inside one weighted slice], length: 13pt, {
  let sc = 0.62 // one tick wide
  let ysc = 0.0075 // one vr unit tall
  let base = 1.2
  let traj(vals, col, lab) = {
    let pts = ((0, 0),)
    for t in range(1, 17) { pts.push((t * sc, base + vals.at(t - 1) * ysc)) }
    cdraw.line(..pts, stroke: col + 0.8pt)
    cdraw.content((16 * sc + 0.3, base + vals.at(15) * ysc), lab, wrap: text.with(size: 6pt), anchor: "west")
  }
  let a = (100, 200, 200, 200, 200, 200, 200, 300, 300, 300, 400, 400, 500, 600, 700, 700)
  let b = (0, 80, 160, 160, 160, 160, 240, 240, 240, 320, 320, 320, 320, 320, 320, 320)
  let d = (0, 0, 0, 0, 100, 200, 200, 200, 300, 300, 300, 400, 400, 400, 400, 400)
  for t in (0, 4, 8, 12, 16) {
    cdraw.line((t * sc, base - 0.3), (t * sc, base + 700 * ysc + 0.3), stroke: luma(220))
    cdraw.content((t * sc, base - 0.8), str(t), wrap: text.with(size: 6pt))
  }
  cdraw.line((0, base - 0.3), (16 * sc, base - 0.3), stroke: luma(100))
  traj(a, luma(60), [A, nice 0])
  traj(b, luma(130), [B, nice -1, heavier])
  traj(d, luma(190), [D, nice 0])
  cdraw.content((4.9, 7.6), [spread peaks at t=3: A 200, B 80, gap 120], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((4.9, 7.0), [bounded by one weighted slice, 125], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((4.9, -0.9), [vruntime after each tick, the weighted fixed set; C's single unit omitted], wrap: text.with(size: 6.5pt))
})

Ten rows, one fixed set, every number a checked sum divided by four:

#table(
  columns: (1.5fr, auto, auto, auto),
  inset: 5pt,
  stroke: 0.5pt + luma(200),
  table.header(
    text(size: 8pt, weight: 700)[policy],
    text(size: 8pt, weight: 700)[avg turnaround],
    text(size: 8pt, weight: 700)[avg response],
    text(size: 8pt, weight: 700)[switches],
  ),
  ..(
    ("fcfs", "8.75", "4.75", "3"),
    ("sjf, never idle", "8.00", "4.00", "3"),
    ("srtf", "7.00", "0.50", "5"),
    ("rr q=1", "9.50", "0.75", "14"),
    ("rr q=2", "9.00", "1.50", "8"),
    ("rr q=4", "8.50", "3.25", "4"),
    ("priority, strict", "9.25", "4.25", "4"),
    ("mlfq, quanta 2-4-run", "9.50", "0.00", "7"),
    ("cfs, equal weight", "8.75", "0.00", "10"),
    ("cfs, weighted", "8.50", "0.00", "10"),
  ).flatten().map(v => text(size: 8pt)[#v]),
)

The clairvoyant optimum among non-preemptive orders that never idle is
8.00 and srtf beats it at 7.00, the dividend preemption pays on this
arrival pattern. The
two rows with 0.00 response, mlfq and cfs, both dispatch every job at
its arrival instant, and they pay for it in switches and turnaround.
The idle-allowed optimum of 7.75 from the sjf exhaustion is absent
from the table on purpose: no online policy in this chapter achieves
it, because reaching it requires refusing to run the only runnable
job.

sources: learn.microsoft.com, SetThreadPriority and the Scheduling
Priorities conceptual page, accessed 2026-09-12; docs.kernel.org,
CFS Scheduler design notes and the EEVDF Scheduler page, accessed
2026-09-12; man7.org sched(7) and setpriority(2), accessed 2026-09-12;
pubs.opengroup.org Issue 8 nice(3), accessed 2026-09-12. The knob
round trips, the background begin-refuse-end pair, the readback of 2
and -15, and the pinned-core probe (above normal done at +41.6 ms,
below normal at +84.6 ms) probed on this machine the same day. Sample
behavior verified by `make verify-c`, 83 checks in chapter 17 of the
samples suite.
