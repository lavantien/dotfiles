#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= behavioral answers, from the register

The behavioral round is the one round the corpus answers outright.
Every story in this chapter is assembled from register rows, resume
lines, and the defense cookbook chapters that already drill them, and
the governing rule is the register's own: no invented employers, no
invented outcomes, no number the record cannot show. Where the record
is thin the card says what is checkable and stops, because the point
of a behavioral answer is surviving the depth probe that follows it,
and the depth probe here is a short one: open the register and show
me. The question bank closes the chapter, sixteen questions, every
one routed to a card, a script, or a chapter that already exists.

== star, but honest [DRILL]

STAR is situation, task, action, result, and the house version states
its discipline before its shape. The register's no-metrics row and
the analysis metrics chapter mean the R is a scoped claim tied to an
inspectable artifact, never an impact percentage. "The behavioral
requirements held, the harness surfaced the undocumented behavior",
"the client brought me back twice", "the archive shows the path, repo
9 stars, gist 0" are results, each one checkable today. "Improved
performance by 40 percent" is a number no engagement under NDA can
source, the metrics chapter bans it in writing, and the pivot to
rehearse is that chapter's own prepared line: I do not put numbers on
my resume I cannot prove in this room, so let me show you the ones I
can, #xref-to("analysis", "metrics").

Then the loop. Situation earns one sentence, the employer and the
constraint. Task earns one sentence, the scope owned, phrased in the
verbs the resume already carries, designed, built, migrated, wrote.
Action is the mechanism and gets the most air, because it is the only
state in the story nobody else can claim, and it is where the depth
probe lands. Result is the scoped claim plus the artifact behind it,
and the guard sits on the result state: a claim with no inspectable
artifact does not get softened, it gets routed back, tied to
something checkable or dropped. A story that ends on an uncheckable
number ends on the one thing this resume never carries.

#diagram([the star loop, the guard on result, a claim with no artifact routes back, not softer], length: 13pt, {
  // the four states clockwise, the guard after result passes scoped claims, rejects invented ones
  let state(x, y, t, sub) = {
    cdraw.rect((x, y), (x + 6.2, y + 1.6), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 3.1, y + 1.08), t, size: 6.5pt)
    cdraw.content((x + 3.1, y + 0.45), sub, size: 6pt)
  }
  state(0.4, 7.4, [situation], [one sentence, employer, constraint])
  state(8.4, 7.4, [task], [one sentence, the scope owned])
  state(16.4, 7.4, [action], [the mechanism, most of the air])
  state(16.4, 3.2, [result], [the scoped claim])
  cdraw.line((6.6, 8.2), (8.4, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.6, 8.2), (16.4, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.5, 7.4), (19.5, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.4, 4.0), (14.4, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.4, 3.2), (14.4, 4.8), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((11.4, 4.32), [the no-metrics guard], size: 6.5pt)
  cdraw.content((11.4, 3.68), [an artifact behind the claim?], size: 6pt)
  cdraw.line((8.4, 4.0), (5.6, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.4, 3.2), (5.6, 4.8), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((3.0, 4.32), [spoken result], size: 6.5pt)
  cdraw.content((3.0, 3.68), [the suite held, the demo runs], size: 6pt)
  cdraw.line((11.4, 4.8), (11.4, 6.15), (17.6, 6.15), (17.6, 7.4), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((14.2, 6.75), [no artifact: tie it to one or drop the number], size: 6pt, fill: luma(100))
  cdraw.rect((0.4, 0.7), (23.0, 2.1), fill: none, stroke: (paint: luma(150), dash: "dashed"), radius: 0.02)
  cdraw.content((11.7, 1.4), [impact percentages live outside the loop, no engagement under nda can source them], size: 6pt, fill: luma(120))
})

== the story cards [DRILL]

Ten cards, one paragraph each, three slots per card: the question it
answers, the register rows that back it, and the mechanism with its
scoped result. A card with no row behind it does not exist, and a
card whose row is thin says so out loud.

Card one, migration equivalence, answers "a project you owned end to
end". The row is `emp-dik-migration`, legacy Java and .NET services
moved to Go and NodeJS with behavioral equivalence as the contract.
The mechanism: capture the legacy service's outputs on recorded
requests as golden masters, the harness pattern walked line by line
in #xref-to("repertoire", "go-testing"), port, run both and diff,
decide every diff explicitly with the client, cut over with the old
service kept warm for rollback. The scoped result: the behavioral
requirements held, and the diffs the harness surfaced were mostly
undocumented behavior, which is what the capture step exists to
find, #xref-to("cookbook", "employment").

Card two, the southbound edge mesh, answers "a system you designed".
Rows `emp-dik-mesh` and `repo-mesh-stack`: agents collect at
construction sites, buffer locally through uplink loss, reconcile on
reconnect with idempotent writes, sites with no direct uplink relay
through peers, southbound the leg toward the devices, northbound
toward the cloud. The scoped result is a mechanism claim, a day of
outage costs latency, not data, and the demo stack behind it, edgex
compose, mosquitto, telegraf, influxdb, grafana, is public.

Card three, the orders pipeline, answers "a service you built end to
end". Rows `emp-ntq-orders` and `repo-order-stack`: gRPC endpoints
on Protobuf contracts over PostgreSQL, field numbers reserved, never
renumbered, never reused, order creation made retry-safe by
client-generated idempotency keys under a uniqueness constraint, the
state machine enforcing transitions in one place. The scoped result:
the order processing services ran for the quick-commerce app, and
the demo stack, gin, sqlc, postgres migrations, paseto auth, is
public.

Card four, iso-matched tests under a strict external spec, answers
"working to a spec you did not write". Rows `emp-fpt-header` and
`emp-fpt-avro`: one developer inside a large team on the E470 toll
program, five months, logic refactored out of private methods, unit
tests written to match the ISO standard the resume cites and the
Detailed Design Docs, Avro schemas evolving compatibly behind a
registry. The scoped result: the tests matched the external spec,
and the scope is conceded before it is attacked, to spec, five
months, not the vision system.

Card five, legacy exchange ownership, answers "a time you owned
something". Rows `emp-pal` and `repo-flower-stack`: whitelabel
exchange platforms where the money path was the whole game, decimal
columns never float, balances derived from journaled entries, a
wrong balance investigated by replaying the journal to find where
the divergence entered, audit logs not optional. The scoped result:
fixed and built on platforms where that discipline is the product,
with FlowerShop as the public artifact of the frontend side.

Card six, the coverage hole, answers "tell me about a failure", and
it is told as the honest one. Rows `repo-llm-coverage` and
`contrib-llm`: the 100 percent figure held on the pre-python_service
tree the line was written against, then the python service landed,
17 files, 2,328 code lines, no tests, and the headline outlived the
tree it measured. The mechanism of the catch: the measurement pass,
tokei for the size, an independent atomic-mode run for coverage. The
scoped result: 99.6 percent Go statements measured, the badge at
99.5, the 100 percent claim retired to historical in the register,
#xref-to("cookbook", "repo-llm").

Card seven, a decision to redo, answers "a time you were wrong".
Rows `contrib-swe` and `repo-swe-archive`: the library lived on a
gist with 100+ stars, and when the project was archived to GitHub in
January 2025 the gist was deleted. The mechanism: freeze a finished
thing rather than pretend it needs maintenance, right, and delete
the only starred copy while doing it, the mistake. The scoped
result, measured: repo 9 stars, gist 0, no other copy exists to
check, so the redo keeps the gist standing as a pointer. Stars were
the only proof the work had readers.

Card eight, the live gap as a built period, answers "what have you
been doing since December". Rows `gap-now`, `edu-degree`, and the
contribution rows: a planned period, the accredited BSc runs to
2027, and the output is inspectable, the tournament repo at 46,545
code lines held at 99.6 percent, the handbook corpus building under
its own make gates. The scoped result is the gaps chapter's own
line, the period was production, not absence, delivered in three
sentences and stopped, #xref-to("cookbook", "gaps").

Card nine, conflict, is taught as a shape, because the register
carries no recorded quarrel and the specifics sit under client NDAs.
The row is `emp-dik-craft`, the recurring disagreement of client
work, test discipline against delivery pressure, and the shape comes
from the stances chapter: steelman the other side, concede frames
freely, concede facts never, #xref-to("cookbook", "stances"). The
mechanism sentence: the argument ends as an artifact, a golden
master harness, an explicit middleware chain, not as a win. The
scoped result: engagements ended on schedule and the client
returned, three engagements across two modes. What is checkable is
the shape and the returning client, and the card stops there.

Card ten, the frontend accessibility line, answers "frontend work
you owned". The backing is the resume line itself, Angular, React,
and Svelte frontends with a11y and i11n for client projects, plus
the two chapters that teach the mechanisms,
#xref-to("repertoire", "css-answers") and
#xref-to("repertoire", "rendering-answers"). The register keeps no
dedicated frontend row, so the card says that: the mechanisms are
the chapters' to teach, the claim is the resume line, and the public
artifact of the frontend period is FlowerShop's Angular storefront,
`repo-flower-stack`.

#callout("note", "client confidential, once, calmly", [
  The standing rule for every thin card: say "client confidential"
  once, calmly, then pivot to what is public, the problem class, the
  tech decisions, the demo repo. A card that invents specifics to
  feel complete converts a scope limit into a credibility risk,
  #xref-to("cookbook", "employment") owns the rule.
])

#diagram([each card is a chain, register rows into a mechanism and a scoped result, answering one question], length: 13pt, {
  // left: the rows, middle: the card's three slots, right: the question it answers
  let chip(y, t) = {
    cdraw.rect((0.4, y), (6.6, y + 1.1), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((3.5, y + 0.55), t, size: 6pt)
  }
  chip(7.8, [emp-dik-migration, defensible])
  chip(5.9, [repo-llm-coverage, defensible])
  chip(4.0, [gap-now, framing])
  cdraw.content((3.5, 2.7), [47 rows, one register], size: 6pt, fill: luma(100))
  cdraw.line((6.6, 8.35), (8.6, 7.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.6, 6.45), (8.6, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.6, 4.55), (8.6, 5.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.6, 3.6), (16.4, 8.9), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((12.5, 8.35), [the story card], size: 6.5pt)
  cdraw.content((12.5, 7.2), [the mechanism sentence], size: 6pt)
  cdraw.content((12.5, 6.1), [the scoped result], size: 6pt)
  cdraw.content((12.5, 5.0), [the register rows, named], size: 6pt)
  cdraw.content((12.5, 3.95), [thin row: say so, stop], size: 6pt, fill: luma(120))
  cdraw.line((16.4, 6.25), (18.4, 6.25), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.4, 5.1), (23.0, 7.4), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((20.7, 6.85), [one question], size: 6.5pt)
  cdraw.content((20.7, 5.9), [a failure, a design,#linebreak() a wrong call], size: 6pt)
  cdraw.content((11.5, 2.2), [a card with no row behind it does not exist], size: 6pt, fill: luma(100))
})

== tell me about yourself [DRILL]

The ninety-second arc is assembled, not improvised, and its parts
are the register's: the identity line, the tags, the four-employer
arc, and the gap as a built period with inspectable output. Spoken:

I am Raeliosol, and the header carries no title by design.
Eight years since the first job, four employers, C, Go, Java, C\#,
JavaScript, Python,
and Lua API work, SQLite and DuckDB where a database server would
be overkill, distributed systems where the wire matters, and test
driven development as the default rather than the tag. The arc: a
first job fixing money paths on whitelabel exchange platforms, five
months inside a large team on the E470 toll system writing tests
against an ISO spec, then three engagements at Dikshatek across
five years, client APIs, a Java and .NET to Go migration proven by
behavioral equivalence, and a southbound edge mesh I designed for
construction sites, with ten months at NTQ between the Dikshatek
runs building the order processing services, which is also where a
previous client rehired me. Since December 2025 I have been on a
planned build period: the BSc runs to 2027, the tournament repo
holds 46,545 code lines at 99.6 percent Go coverage, and the
handbook corpus behind this resume builds under its own make gates.
I am returning deliberately, and this conversation is the start of
that.

Every clause routes somewhere: the identity and tags to the header
rows, the arc to `emp-pal` through `emp-dik-header`, the rehire to
`gap-2022`, the build period to `gap-now` and `edu-degree`, the
numbers to `repo-llm-sloc` and `repo-llm-coverage`. Ninety seconds
is the budget because the tenth second past it buys nothing, the
silence rule owns the close, #xref-to("cookbook", "communication").

#diagram([the ninety second arc, identity and tags, the employer arc, the build period, the return], length: 13pt, {
  // one proportional bar, 90 seconds across, segment widths carry the budget
  let segs = (
    (0.6, 4.1, [identity, tags], [0 to 15s], luma(245)),
    (4.7, 9.8, [the employer arc,#linebreak() pal to dik via fpt and ntq], [15 to 55s], luma(225)),
    (14.5, 4.9, [the build period,#linebreak() degree plus corpus], [55 to 75s], luma(235)),
    (19.4, 3.8, [the return], [75 to 90s], luma(205)),
  )
  for (x, w, top, tick, f) in segs {
    cdraw.rect((x, 4.9), (x + w, 6.3), fill: f, stroke: luma(120), radius: 0.0)
    cdraw.content((x + w / 2, 7.4), top, size: 6pt)
    cdraw.content((x + w / 2, 4.1), tick, size: 6pt, fill: luma(100))
  }
  cdraw.content((3.5, 8.7), [one register row per clause], size: 6pt, fill: luma(100))
  cdraw.content((17.0, 8.7), [46.5k lines, 99.6, the gates run], size: 6pt, fill: luma(100))
  cdraw.content((11.8, 2.6), [the tenth second past ninety buys nothing, answer, stop], size: 6pt, fill: luma(100))
})

== conflict, failure, ownership [DRILL]

Three full scripts, the cards with the most follow-up surface, each
with its three traps rehearsed: what would the other person say,
what did you lose, what changed afterwards.

Conflict, spoken: the honest opening is that the register carries no
recorded quarrel and the specifics sit under client NDAs, so here is
the shape and the nearest true material. The recurring disagreement
of client work is test discipline against delivery pressure, the row
is tests, handlers, middlewares, business logic. The shape: steelman
the other side first, the deadline is the contract and unverified
code is a liability shipped to the client, concede the frame freely,
yes, not everything deserves a test, hold the fact, the merge and
cutover paths do. Then make it mechanical instead of personal: on
the migrations the argument ended as a golden-master harness, the
pattern walked line by line in chapter 16 of this book, on the API
work as an explicit middleware chain, logging, recovery, auth,
handler, testable end to end. Traps: the other person would say the
deadline was the job and my discipline was a cost, and they would be
partly right. What I lost was my own time, not the client's
calendar, the engagements ended on schedule. What changed: I stopped
arguing discipline in the abstract and started demonstrating it, the
harness is the argument.

Failure, spoken: the failure is mine and it is measured. The resume
line said 100 percent coverage, true against the tree it was written
for. Then the python service landed, 17 files, 2,328 code lines, no
tests, and the headline number outlived the tree it measured. My own
measurement pass caught it: 46,545 code lines of 62,058 total, 99.6
percent Go statements in an independent atomic-mode run, the badge
reading 99.5. The failure was not the gap, untested code happens, it
was letting a claim drift without re-measuring, on the one repo
whose whole point was the discipline. Traps: the other person would
say the badge was decoration and nobody would have checked, granted,
which is why the check has to be mine. What I lost is the 100
percent claim, permanently, it is retired to historical in the
register. What changed: every number I speak now arrives with its
measurement and its command.

Ownership, spoken: the first job. Whitelabel exchange platforms,
C\#, Java, Spring, MySQL, AWS, where I fixed more than I designed,
which is what a first job is for. What I owned was the money path:
decimal columns, never float, balances derived from journaled
entries, so a client reporting a wrong balance was not a mystery but
a reconstruction job, replay the journal, find where the divergence
entered, and audit logs were not optional in that domain. Traps: the
other person, the platform's original architects, would say the
journal was their design and my work was maintenance, and they would
be right, the ownership was of fixes and incidents, not the
platform. What I lost, nothing dramatic is on the record, the honest
cost is the domain knowledge stayed under NDA, and the public
residue of that period is FlowerShop. What changed: the shape stayed
with me, append-only records, derived state, replay as repair, the
same skeleton the outbox carries in the patterns handbook.

#diagram([three scripts, three traps each, the trap answers rehearsed with the script, not after it], length: 13pt, {
  // rows: the three scripts, columns: the three follow-up traps
  cdraw.content((1.9, 9.5), [the script], size: 6.5pt, fill: luma(100))
  cdraw.content((6.95, 9.5), [the other person says], size: 6pt, fill: luma(100))
  cdraw.content((13.55, 9.5), [what you lost], size: 6pt, fill: luma(100))
  cdraw.content((19.9, 9.5), [what changed], size: 6pt, fill: luma(100))
  let rows = (
    (7.4, [conflict], [the deadline was the job], [my time, not their calendar], [mechanisms, not arguments]),
    (5.0, [failure], [the badge was decoration], [the 100 percent claim, retired], [numbers arrive with commands]),
    (2.6, [ownership], [the journal was theirs], [the domain stayed under nda], [the shape stayed with me]),
  )
  for (y, name, a, b, c) in rows {
    cdraw.rect((0.4, y), (3.4, y + 1.6), fill: luma(215), stroke: luma(120), radius: 0.02)
    cdraw.content((1.9, y + 0.8), name, size: 6.5pt)
    cdraw.rect((3.7, y), (10.2, y + 1.6), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((6.95, y + 0.8), a, size: 6pt)
    cdraw.rect((10.5, y), (16.6, y + 1.6), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((13.55, y + 0.8), b, size: 6pt)
    cdraw.rect((16.9, y), (22.9, y + 1.6), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((19.9, y + 0.8), c, size: 6pt)
  }
  cdraw.content((11.65, 1.3), [the trap columns are where the honest story lives, the script alone is theater], size: 6pt, fill: luma(100))
})

== why leaving, why us, weakness [DRILL]

Why leaving has a strongest version and the register holds it: the
NTQ engagement ran its course in October 2022, and Dikshatek, where
I had already contracted in 2020 and 2021, brought me back in
December for a two-year run, `gap-2022`, rehired by a previous
client. Every exit in the register is an engagement ending, the 2025
one ended as planned into the deliberate build period, and the
sentence to speak is the gaps chapter's: the pattern to read is that
previous clients rehired me, twice. No exit in the record is a
walkout, and none needs a softer telling.

Why us is the preparation question inverted. The playbook's closer
asks the team one question that uses the preparation, what does the
team's test discipline look like, and where does it hurt,
#xref-to("cookbook", "playbook"). Why-us runs the same discipline in
the other direction: one true, specific fact about them, drawn from
the preparation, tied to one row of the record, the mechanism I
would bring stated as the bridge. Two slots, both checkable, and the
generic praise sentence fills neither.

Weakness and why-should-we-not-hire-you are the endgame pair, reused
in interview voice. The weakness: distribution over promotion, I
build things that are testable and documented, including for
myself, and underinvest in making noise about them, eight stars on
46.5 thousand code lines is the trait rendered as a number. The
not-hire: if you need a specialist, one stack at scale, one domain
for years, I am the wrong shape, I am broad by design, four
languages and the systems underneath them, and the depth is proven
where it counts, the handbooks and the repos. Both cards are
prepared because the questions arrive, and the games chapter prices
the volunteered weakness as a commitment device that retires the
attack, #xref-to("cookbook", "games"), which is the one place
volunteering pays.

#diagram([three cards, one slot each from the record, prepared before the question lands], length: 13pt, {
  // the endgame cards pattern, each card two lines, the second line is the checkable half
  let cards = (
    (0.5, [why leaving], [an engagement ended], [a previous client rehired me]),
    (8.2, [why us], [one fact about them], [one row of the record]),
    (15.9, [weakness], [distribution over promotion], [8 stars on 46.5k lines]),
  )
  for (x, title, l1, l2) in cards {
    cdraw.rect((x, 4.4), (x + 7.1, 7.4), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 3.55, 6.9), title, size: 6.5pt)
    cdraw.content((x + 3.55, 5.8), l1, size: 6pt)
    cdraw.content((x + 3.55, 4.8), l2, size: 6pt)
  }
  cdraw.content((11.75, 3.1), [the second line is the half that survives checking], size: 6pt, fill: luma(100))
})

== the drill and the traps [DRILL]

The question bank, sixteen questions, each with its route. The
openers: tell me about yourself, the arc above. Walk me through the
resume, the timeline drill, eight years, four employers, one of them
bringing me back twice, every transition measured in weeks,
#xref-to("cookbook", "gaps"). The motivation four: why leaving, the
returning client. Why us, the two-slot preparation. Weakness and
why should we not hire you, the endgame pair. The story six:
conflict with a teammate, the shape card. Conflict with a
stakeholder, the provider material, third-party sandboxes drift
from production, the resolution was pinning contracts with tests
and treating sandbox pass as necessary, not sufficient. Failure,
the coverage card. Proudest work, the mesh, the resume's one
designed-and-built row. Ownership, the exchange card. A time you
were wrong, the deleted gist. Where in five years, the degree runs
to 2027 and the return is deliberate, and nothing more is invented
past that. Why no
titles on the resume, contractor and outsourcing titles varied per
engagement and carried no standard meaning, so the bullets do the
signaling and seniority is answered with scope, `no-titles`,
#xref-to("cookbook", "policy"). The gap question, card eight, three
sentences maximum. Salary expectation in an early screen, one
sentence, a range anchored in your own record, and the full
treatment is the negotiation chapter's,
#xref-to("repertoire", "negotiation-answers").

The traps, four. The anchor first: the interviewer names a number
or a frame before you do, and the defense is the fallacies
chapter's row, restate the number from your own record before
negotiating inside theirs, with the communication chapter's cheaper
half, frame first and there is nothing to restate against,
#xref-to("cookbook", "fallacies"). The silence after an answer: a
move, not a vacancy, whoever fills it pays in truth or status, so
answer, stop, and let the pause belong to the person who created
it, #xref-to("cookbook", "communication"). Loaded and presupposition
questions: both answers convict, so split the presupposition and
answer the true half, the counter table's own row. And the
unprompted weakness: the cookbook's rule is that every sentence
past the question is a fresh claim under new risk, the prepared
weakness exists for the question, not for the air, and conceding
scope under attack is the opposite of opening unforced.

#diagram([the sixteen questions as chips, every one routing to a card, a script, or a chapter], length: 13pt, {
  // four by four chips, question above, route below in the lighter ink
  let chip(x, y, q, r) = {
    cdraw.rect((x, y), (x + 5.5, y + 1.5), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 2.75, y + 1.02), q, size: 6pt)
    cdraw.content((x + 2.75, y + 0.44), r, size: 6pt, fill: luma(120))
  }
  let xs = (0.5, 6.3, 12.1, 17.9)
  let ys = (7.6, 5.9, 4.2, 2.5)
  chip(xs.at(0), ys.at(0), [yourself], [the arc, sec 3])
  chip(xs.at(1), ys.at(0), [the resume], [the timeline drill])
  chip(xs.at(2), ys.at(0), [why leaving], [gap-2022, rehired])
  chip(xs.at(3), ys.at(0), [why us], [two slots, checked])
  chip(xs.at(0), ys.at(1), [weakness], [the endgame pair])
  chip(xs.at(1), ys.at(1), [why not hire], [the specialist shape])
  chip(xs.at(2), ys.at(1), [a teammate], [the shape, card 9])
  chip(xs.at(3), ys.at(1), [a stakeholder], [sandbox contracts])
  chip(xs.at(0), ys.at(2), [failure], [card 6, measured])
  chip(xs.at(1), ys.at(2), [proudest], [the mesh, card 2])
  chip(xs.at(2), ys.at(2), [ownership], [the exchange, card 5])
  chip(xs.at(3), ys.at(2), [wrong once], [the gist, card 7])
  chip(xs.at(0), ys.at(3), [five years], [degree, the return])
  chip(xs.at(1), ys.at(3), [no titles], [scope, not words])
  chip(xs.at(2), ys.at(3), [the gap], [card 8, 3 sentences])
  chip(xs.at(3), ys.at(3), [salary], [one sentence, ch 39])
  cdraw.content((11.75, 1.5), [no chip is improvised, each names its owner before the room asks], size: 6pt, fill: luma(100))
})

floored to the register and the books that defend it: the stories
are the register's, none is invented, none carries a number the
register cannot show, #xref-to("cookbook", "employment") for the
per-employer material, #xref-to("cookbook", "gaps") for the timeline
and the gap cards, #xref-to("cookbook", "playbook") for the rules
under pressure and the endgame pair, #xref-to("cookbook", "stances")
for the concession rule the conflict card runs,
#xref-to("cookbook", "communication") for silence, framing, and the
stop, with #xref-to("analysis", "employment") and
#xref-to("analysis", "contributions") holding the rows behind the
cards and #xref-to("analysis", "metrics") owning the no-metrics
discipline the result state carries.
