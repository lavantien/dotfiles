#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= offers and negotiation

The offer conversation is the one round most candidates rehearse least,
and it rewards the same discipline as every other round: know what is
being asked, answer from a record, price the exchange honestly. This
chapter drills the offer as information, the anchor as a bias with a
counter, the timeline as a repeated game, and the scripts, word for
word, with no invented numbers anywhere: the record this book defends
carries no metrics by policy, and the negotiation module keeps that
discipline, every number in a script is a script variable, your
number, their number, the walk-away.

== reading an offer [DRILL]

Read the offer as a grid, not a number. Base is the only component
everything else compounds on: the bonus is a percentage of it, the
next negotiation prices off it, relocation and level both key on it,
so a base concession is never a single-year concession. Bonus is the
discretionary discount: ask for the realized range for the level, the
target is a forecast and the payout history is the fact. Equity
demands the illiquidity honesty: options at a strike are a bet priced
by a vesting clock, a preference stack, and a tax event, and the four
questions to ask are strike, preference, vesting schedule, and the
last round's price. Value equity at zero for the rent-paying
decision, let it be upside, and never trade base for equity at face
value, that trade prices a lottery ticket at par.

Benefits are read by price, not by count: insurance with a real
coverage number costs the company real money, a gym discount costs
almost nothing, and the grid cell is what the benefit costs them, not
how it photographs. Scope is the quietest cell and the most
expensive: what the offer buys, the team, the on-call rotation, the
manager, the systems owned, because scope sets the record you bring
to the next negotiation. Team signal is the last cell: how they
negotiated is how they manage, a rushed deadline on a sloppy
agreement is data about the working environment, and the offer is
the only period where the company negotiates with you while trying
to impress you.

#diagram([the offer grid: six cells, one reading per cell], length: 13pt, {
  // a two by three matrix, one cell per reading
  let cell(x0, y0, name, line) = {
    cdraw.rect((x0, y0), (x0 + 7.2, y0 + 2.5), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 3.6, y0 + 1.85), [#name], size: 6.5pt)
    cdraw.content((x0 + 3.6, y0 + 0.8), [#line], size: 6pt)
  }
  cell(1.2, 6.2, "base", "everything compounds on it")
  cell(9.0, 6.2, "bonus", "ask for the realized range")
  cell(16.8, 6.2, "equity", "strike, stack, vest, price")
  cell(1.2, 3.0, "benefits", "price them, not count them")
  cell(9.0, 3.0, "scope", "sets the next record")
  cell(16.8, 3.0, "team signal", "how they negotiate is how they manage")
  cdraw.content((12.5, 1.3), [an offer is information about how a company prices people], size: 6pt)
})

== anchoring from the record [DRILL]

The anchoring material is already owned: the first number spoken
frames every number after it, the bias is theirs most of the time,
and the counter is to restate the number from your own record before
negotiating inside theirs, because measurement is the anchor you
control, #xref-to("cookbook", "fallacies"). The cheaper half of the
same move is to frame first: your definition and your criterion on
the table before their number arrives, a frame stated first reads as
ground, the identical frame stated second reads as resistance,
#xref-to("cookbook", "communication"). In the offer conversation the
frame is the criterion: pay against the record, the checkable
artifacts, not self-reported impact.

Here the no-metrics policy stops being a defense problem and becomes
an asset: a record with no invented impact numbers has nothing to
walk back and nothing to discount, every claim resolves to something
openable, #xref-to("cookbook", "policy"). The negotiation use is
direct: their number anchors on levels and surveys, yours anchors on
checkable work, and when the two disagree the honest ask is that the
record win in both directions, the same sentence the cookbook drills
for the interview room. A number backed by an artifact cannot be
argued away, only declined, and declining is a decision you can see.

== competing timelines [DRILL]

The exploding offer is manufactured urgency, the marker is "decide
today, the window closes tonight", and the counter is architectural:
open channels, written trails, agreements restated, the deadline
asked for in writing, #xref-to("cookbook", "deception"). A real
deadline survives being written down, a manufactured one often
softens the moment it is restated in an email, and the restatement
costs nothing to request.

Honest sequencing is the move that keeps the repeated game intact:
tell each process its true state, in process elsewhere, one offer in
hand, your process is the one I want to finish, and never invent a
competing offer. A fabricated offer is inflation, and the interview
is move one of a repeated game where every later move gets repriced:
the panel talks to the next panel, the industry is a village, and a
word caught discounting follows you into the renegotiation,
#xref-to("cookbook", "games"). The acceleration ask is the honest
instrument: tell the second company that company A's deadline is
real, name the date, ask to accelerate, accept no for an answer,
because a declined acceleration is information, it prices your
process at their real speed. Commitment is reputation repricing in
both directions: accepting and reneging is the defection the village
prices forever, and a stated deadline held to, even at a cost, is a
commitment device, the payoff matrix changed before the argument
started.

#diagram([two processes, one honest acceleration window, no invented third], length: 13pt, {
  // two horizontal tracks, the acceleration ask bridging them
  cdraw.line((1.5, 7.6), (22.0, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.2, 8.3), [company a, offer in hand], size: 6.5pt)
  for (x, t) in ((6.0, "offer"), (12.0, "deadline")) {
    cdraw.circle((x, 7.6), radius: 0.16, fill: luma(60))
    cdraw.content((x, 6.8), [#t], size: 6pt)
  }
  cdraw.line((1.5, 3.6), (22.0, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.2, 4.3), [company b, in process], size: 6.5pt)
  for (x, t) in ((9.0, "onsite"), (18.0, "decision")) {
    cdraw.circle((x, 3.6), radius: 0.16, fill: luma(60))
    cdraw.content((x, 2.8), [#t], size: 6pt)
  }
  cdraw.line((12.0, 7.2), (9.6, 4.1), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((11.6, 5.8), [the acceleration ask,#linebreak()named date, no as an answer], size: 6pt)
  cdraw.content((12.0, 1.4), [never a fabricated third track: the village reprices inflation], size: 6pt)
})

== the scripts [DRILL]

Five scripts, drilled word for word, every number a variable.

The early-screen range answer, for when the recruiter asks
expectations before anyone has met you: "for this scope in this
market I am looking in a range, my number to anchor it is your
number for the level, and I will weigh it against my record." Give a
range if pressed, never a single number, the range's top is the ask
and its floor is the walk-away plus margin, and say the basis, a
range with no basis invites theirs.

The offer call: gratitude, then silence, and never acceptance on the
call. "Thank you, I am glad this came together, I want to read the
whole package in writing, when do you need my answer by", then stop.
Silence after an answer is a move, whoever fills it pays in
concessions, and the pause belongs to the person who created it,
#xref-to("cookbook", "communication"). Accepting on the call throws
away every lever at the one moment they are all live, and a verbal
offer is memory, a written offer is an offer.

The counter: one number, anchored to scope and the record, delivered
once. "Everything in the package works as written except the base,
the scope as described sits above the number, here is the number
that closes it today, and if the number cannot move I want to talk
about what else can." One ask prices clean, two asks dilute each
other and read as appetite, and the counter that concedes everything
else up front is the commitment device that makes the single ask
believable.

Accept: short, warm, same-day, and the agreed terms restated in
writing the same day, agreements restated in the room is the whole
architectural move. Decline: short, warm, the door open, one true
sentence of reason if a reason is owed, no counteroffer theater and
no silence, because the declined company is still in the repeated
game, panels forward names and remember them. Status asks are priced
in patience, spend them rarely: ask once, with a date attached, and
take the no. Concessions split by what they spend, concede scope
freely, it retires attacks before they arrive, concede truth never,
truth once conceded cannot be rebought, #xref-to("cookbook",
"communication"). Repair works mid-negotiation too: a number
misspoken is corrected before they check it, a self-caught error is
a process working, an externally caught one is a story about you.

#diagram([the offer call as a game tree: accept now is the one dead leaf], length: 13pt, {
  // a tree: offer lands, accept-now leaf, the read-counter line, leaves
  cdraw.rect((0.6, 7.4), (5.0, 8.8), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((2.8, 8.1), [the offer lands], size: 6.5pt)
  cdraw.line((5.0, 8.5), (7.6, 9.4), stroke: luma(100))
  cdraw.line((5.0, 8.1), (7.6, 6.6), stroke: luma(100))
  cdraw.rect((7.6, 9.0), (12.2, 9.9), fill: luma(248), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((9.9, 9.45), [accept on the call, all levers gone], size: 6pt)
  cdraw.rect((7.6, 6.1), (12.2, 7.1), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((9.9, 6.6), [gratitude, silence, in writing], size: 6pt)
  cdraw.line((12.2, 6.6), (14.2, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.2, 6.1), (18.2, 7.1), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((16.2, 6.6), [in band?], size: 6.5pt)
  cdraw.line((18.2, 6.9), (19.8, 7.9), stroke: luma(100))
  cdraw.line((18.2, 6.3), (19.8, 5.2), stroke: luma(100))
  cdraw.rect((19.8, 7.6), (23.2, 8.5), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((21.5, 8.05), [accept, same-day restatement], size: 6pt)
  cdraw.rect((19.8, 5.8), (23.2, 6.7), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((21.5, 6.25), [one counter, one number], size: 6pt)
  cdraw.line((21.5, 5.8), (21.5, 5.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((21.5, 4.4), [met, weighed, or the walk-away], size: 6pt)
  cdraw.content((11.5, 2.6), [every leaf after the read keeps a lever,#linebreak()the dead leaf is the only one that cannot be priced], size: 6pt)
})

== closing the loop after a no [DRILL]

The post-rejection note goes out same day, two sentences: thanks, one
specific thing the process taught you, the door open, and a request
that the note be kept with the file. No paragraph of rebuttal, no
case for reconsideration unless they ask, the note is a move in the
repeated game, not an appeal of the verdict, and the specific detail
is what makes it a person's note rather than a template.

The register discipline carries over: keep the pipeline the way the
corpus keeps its claims, dates, states, what was asked and what was
offered, in the private copy, so the next negotiation anchors on a
record instead of memory, the same method the repo evidence chapter
drills, #xref-to("cookbook", "repomethod"). Memory flatters and
drifts, a written table does not, and the walk-away from last cycle
is the floor of this cycle's range.

Re-approach timing is priced by change, not by calendar: go back when
something checkable is different, a shipped artifact, a new chapter
of work, a role that matches the specific reason given at the no,
and reference that reason in the first line. A re-approach with
nothing new reads as a rerun, a re-approach with a new artifact reads
as growth, and the difference is the whole sentence.

floored to: no numbers were invented for this chapter, every script
carries script variables, and the negotiation theory is not new
here. Anchoring as a bias and its counter belong to
#xref-to("cookbook", "fallacies"), framing first, silence, question
control, and the two concessions belong to
#xref-to("cookbook", "communication"), the repeated game, repricing,
and commitment devices belong to #xref-to("cookbook", "games"),
manufactured urgency and the architectural counter belong to
#xref-to("cookbook", "deception"), the no-metrics posture as an
asset belongs to #xref-to("cookbook", "policy"), and the register
discipline belongs to #xref-to("cookbook", "repomethod").
