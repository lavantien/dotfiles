#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= back of the envelope, said aloud

Estimation rounds are won before any number appears: the interviewer
is listening for whether the candidate knows what to estimate, states
assumptions out loud, and lands inside a factor. This chapter drills
the spoken method, the number ladder every round expects, and five
timed boards, all of it arithmetic on textbook values, none of it a
measurement. The floors are real: the latency ladder belongs to the
patterns handbook, and the posture the estimates get checked against,
mean versus p99, was measured in the six service books, not guessed
at a whiteboard.

== the method [DRILL]

Four moves, in order, every time. First, restate the quantity being
estimated as a formula in words, users times requests per user per
day over seconds in a day, because the formula is the answer and the
number is only its evaluation. Second, name the per-unit size, the
bytes per row, the requests per second per pod, and say the
assumption out loud so the interviewer can correct it, a corrected
assumption is a free point, a silent one is a hidden fault. Third, do
the arithmetic aloud in powers of ten, rounding as you go, because
the listener is grading the arithmetic, not the product. Fourth,
sanity-band the result against something known, another system, a
published number, the same estimate cut a different way, and name the
band: within 2x is the claim, a tighter claim needs a measurement.

#diagram([the four moves, in order, every estimate], length: 13pt, {
  // a horizontal pipeline of the four moves with the sentence each one
  let stage(x0, name, line) = {
    cdraw.rect((x0, 5.6), (x0 + 5.1, 7.8), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 2.55, 7.2), [#name], size: 6.5pt)
    cdraw.content((x0 + 2.55, 6.3), [#line], size: 6pt)
  }
  stage(0.6, "restate", "the formula in words")
  stage(6.4, "per-unit size", "say the assumption")
  stage(12.2, "arithmetic", "aloud, in powers of ten")
  stage(18.0, "sanity band", "within 2x is the claim")
  for x in (5.7, 11.5, 17.3) {
    cdraw.line((x, 6.7), (x + 0.6, 6.7), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((11.9, 4.3), [a corrected assumption is a free point,#linebreak()a silent one is a hidden fault], size: 6pt)
  cdraw.content((11.9, 2.5), [within 2x is the claim, tighter needs a measurement], size: 6pt)
})

== the numbers every round expects [DRILL]

Powers of two first: 2^10 is a thousand, 2^20 a million, 2^30 a
billion, 2^40 a trillion, every ten powers of two buying three powers
of ten. The drift is the detail that lands: each step runs 2.4
percent heavy, compounding to about 10 percent at 2^40, so say
"roughly" once and stop apologizing. Time units in seconds: a day is
86,400, call it 10^5 when coarse, a year is about 3.15 x 10^7, which
is pi times ten to the seventh and the one mnemonic worth keeping, a
million seconds is 11.6 days, a billion is 32 years.

Then the latency ladder, restated exactly as the patterns handbook
pins it: a round trip within a datacenter is around 0.5 milliseconds,
across a continent around 30, and reading an nvme drive is around 100
microseconds. A protocol that adds 10 sequential cross-continent
round trips costs 300 milliseconds before any work happens,
#xref-to("patterns", "distributed"), whose source row pins norvig's
numbers and the berkeley interactive guide. The ladder earns its keep
as a budget: 0.5 milliseconds a hop says ten service hops inside one
datacenter cost 5 milliseconds, and one continental hop costs sixty
datacenter hops, which is why locality is a design decision and not a
tuning knob.

#diagram([the ladder as a budget: each tick costs the one before it many times over], length: 13pt, {
  // a log-scale strip of the pinned ladder with the 10x story between ticks
  let tick(x, v, label) = {
    cdraw.line((x, 4.4), (x, 7.6), stroke: luma(100))
    cdraw.content((x, 8.3), [#v], size: 6.5pt)
    cdraw.content((x, 3.4), [#label], size: 6pt)
  }
  cdraw.line((1.2, 6.0), (22.4, 6.0), stroke: luma(160))
  tick(3.0, "100us", "an nvme read")
  tick(8.2, "0.5ms", "a datacenter round trip")
  tick(13.6, "30ms", "across a continent")
  tick(19.4, "300ms", "ten continental hops")
  for (x, t) in ((5.5, "x5"), (10.8, "x60"), (16.4, "x10")) {
    cdraw.content((x, 6.9), [#t], size: 6pt)
  }
  cdraw.content((11.8, 1.7), [one continental hop costs sixty datacenter hops,#linebreak()locality is a design decision], size: 6pt)
})

== storage and memory, worked [DRILL]

The template board, said aloud. 100 million rows at one kilobyte
each is 10^8 times 10^3, which is 10^11 bytes, which is 100
gigabytes, decimal convention, stated, and kept for the rest of the
board. The index doubles it: a b-tree index over the key plus row
metadata runs to about half the payload, and the write amplification
of maintaining it is why the honest number is 2x, so 200 gigabytes
all in. Row versus page arithmetic: a 4 kilobyte page holds four of
these rows, so the table is roughly 25 million pages, and the number
to say is that scans read pages, not rows, so a query touching one
column of every row still pays the full 100 gigabytes unless an index
or a columnar store changes what a read means.

Sizing a cache from the hot set: the traffic rule of thumb is that
90 percent of requests touch 10 percent of keys, so the hot set is
10 million keys at a kilobyte, 10 gigabytes, plus per-entry overhead
that a redis-style store charges at roughly 2x the payload, call it
20 gigabytes. That number decides the architecture, a hot set that
fits one cache node is one node, one that does not is a cluster or a
tiered design, and the 90 percent hit ratio that keeps the database
seeing only the tail is the same sentence the 300k sketch of
#xref-to("repertoire", "design-answers") leans on.

#diagram([powers of two against powers of ten, with the drift named], length: 13pt, {
  // the four row matrix, binary column, decimal column, drift column
  cdraw.content((4.6, 8.9), [binary], size: 6.5pt)
  cdraw.content((11.4, 8.9), [say], size: 6.5pt)
  cdraw.content((18.2, 8.9), [drift], size: 6.5pt)
  let row(y, a, b, c) = {
    cdraw.rect((1.2, y), (8.0, y + 1.2), fill: luma(235), radius: 0.02)
    cdraw.content((4.6, y + 0.6), [#a], size: 6pt)
    cdraw.rect((8.4, y), (14.4, y + 1.2), fill: luma(245), radius: 0.02)
    cdraw.content((11.4, y + 0.6), [#b], size: 6pt)
    cdraw.content((18.2, y + 0.6), [#c], size: 6pt)
  }
  row(7.0, [2^10 = 1,024], [10^3], [2.4 percent])
  row(5.4, [2^20 = 1.05 x 10^6], [10^6], [4.9 percent])
  row(3.8, [2^30 = 1.07 x 10^9], [10^9], [7.4 percent])
  row(2.2, [2^40 = 1.10 x 10^12], [10^12], [10 percent])
  cdraw.content((11.8, 0.9), [every ten powers of two buy three powers of ten], size: 6pt)
})

== qps, fanout, headroom, worked [DRILL]

Split reads from writes before any other number, because every
capacity decision downstream depends on the ratio, and most systems
run 10 to 1 read heavy, some 100 to 1. Then say what the average
hides: mean and p99 are different systems, a 30 millisecond mean with
a 200 millisecond p99 is a service that is fast for most callers and
broken for a profitable few, and the p99 is the number capacity is
bought against. That posture is measured, not estimated, in this
corpus: the six service books each carry a load chapter that drives
real traffic through the service and reports the percentiles, one
representative being #xref-to("go", "load"), and the estimation
drill's job is to predict the order of those curves before they are
measured.

The 30k template, restated from the design chapter as the pattern to
reuse: 300k concurrent users at one request per user per ten seconds
is 30k requests per second, pods sized at 2k requests per second
make 15 pods by arithmetic, and the queue and the cache absorb what
the arithmetic cannot see. Fanout multiplies it: a write that must
reach 300k live connections is not one write, it is a fanout of
300k deliveries, and the write storm is a different system from the
write that produced it. Headroom, said as a rule: size for twice the
estimate, because the estimate is arithmetic on guesses, the spike is
real, and half a quiet cluster is cheap while one saturated cluster
is an outage. The rule buys the rolling deploy too, half the fleet
can be down for a release precisely when the estimate was doubled.

== five boards in ten minutes [DRILL]

Five timed boards, two minutes each, the arithmetic written the way
it should be said.

Videos served a day. Assume a billion users, one video each per day,
so 10^9 views over 86,400 seconds is about 12,000 views a second
average, peak two to three times that on a shared evening timezone.
Egress owns the design: 10^9 views at 30 megabytes is 30 petabytes a
day, no origin serves that, so the cdn is the system and the origin
is its fill tier, the arithmetic decides the architecture before any
box is drawn.

Cache or database for a lookup. The store answers a point lookup in
about a millisecond, memory answers in the microseconds, and at 30k
requests a second the store column is 30 concurrent in-flight
queries before any spike. The deciding number is the hit ratio: 90
percent hits cut store load tenfold, and the hot set arithmetic from
the storage board is what says whether that ratio is buyable, so the
answer is a hit-ratio question, never a preference.

Letters in the mail store. Assume 200 million letters a day,
metadata at a kilobyte, so 200 gigabytes a day, about 73 terabytes a
year, one ordinary database per year of metadata. A scanned image at
200 kilobytes is 40 terabytes a day, 14.6 petabytes a year, so
scanning everything is a policy decision the arithmetic exposes, not
a default a storage team drifts into.

One server or ten. A box carries about 2k requests a second, the
estimate says 12k, arithmetic buys 6 boxes, practice buys 10: the
extra four are headroom plus the ability to take half the fleet down
for a rolling deploy. One server stays right until it is a single
failure domain, a deploy outage, and a queue for every restart at
once, and the tenth box is cheaper than the incident that proves the
point.

Shard or replicate. Read heavy at 10 to 1 with 30k requests a second
means about 27k reads: replicas carrying 2k reads each make 14
replicas, and the one writer at 3k writes a second is still
comfortable, so replicate first, it is the cheaper rung and it buys
read scale without moving any data. Sharding is the answer when the
single writer saturates or the store outgrows one machine, it buys
write scale at the price of cross-shard queries and rebalancing, and
saying "replicate first, shard last" in that order is the answer the
round listens for.

floored to: every number in this chapter is arithmetic on textbook
values, none is a measurement. The latency ladder and its pinned
source, norvig's numbers and the berkeley interactive guide, belong
to #xref-to("patterns", "distributed"). The 300k arithmetic restated
as the qps template belongs to #xref-to("repertoire",
"design-answers"). The measured posture the estimates are checked
against, mean versus p99 under real load, lives in the six service
books' load chapters, #xref-to("go", "load") as one representative
of the lanes the service corpus closed.
