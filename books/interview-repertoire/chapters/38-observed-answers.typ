#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= the observed round, take-homes, debugging

The observed round is problem solving with someone watching, and the
2026 loop made the watching the point: unassisted code proves less
than it did, so the graded channel is what you say while you work.
This chapter drills that channel in order, the five minutes before
the first line, the narration while writing, the recovery from the
blank, the rules for the assistant one keystroke away, the timed
mocks this book already contains, the take-home posture, and the
debugging round with its proof rule. The pinned numbers come from
the landscape chapter, the delivery mechanics from the cookbook.

== the first five minutes [DRILL]

Four moves, in order, before any code. Restate the problem in your
own words and get a yes, "here is what I understand, the input is
this, the output is that, is that right", because the yes converts
the next twenty minutes from possibly-solving-the-wrong-problem
into solving. Name the input shape and the constraints, sizes,
ranges, sorted or not, duplicates allowed, what the empty input
returns, the questions the code cannot answer later. Name the
solution shape before writing: brute force first with its
complexity stated, then the improvement with its mechanism and its
complexity, the two-shape sentence, the naive double loop is
quadratic, the hash map buys linear time for linear space. Agree on
the definition of done, working code, which edge cases, tested how,
so the finish line exists before the pen moves. The five minutes
are not overhead, they are the cheapest minutes of the round, and
an interviewer who watches them sees a process rather than a race.

#diagram([the five minute clock, restate and yes, inputs and constraints, both shapes, done], length: 13pt, {
  // one proportional bar across five minutes, four zones, the budget written under each
  let zones = (
    (0.6, 4.4, [restate, get the yes], [0 to 1 min], luma(245)),
    (5.0, 4.4, [inputs, constraints], [1 to 2 min], luma(235)),
    (9.4, 8.8, [brute force, then better,#linebreak() complexities stated], [2 to 4 min], luma(225)),
    (18.2, 4.4, [definition of done], [4 to 5 min], luma(215)),
  )
  for (x, w, top, tick, f) in zones {
    cdraw.rect((x, 4.9), (x + w, 6.3), fill: f, stroke: luma(120), radius: 0.0)
    cdraw.content((x + w / 2, 7.5), top, size: 6pt)
    cdraw.content((x + w / 2, 4.1), tick, size: 6pt, fill: luma(100))
  }
  cdraw.content((2.8, 8.8), [the yes is the gate], size: 6pt, fill: luma(100))
  cdraw.content((14.0, 8.8), [two shapes, both complexities], size: 6pt, fill: luma(100))
  cdraw.content((11.8, 2.6), [the cheapest five minutes of the round, a process on display, not a race], size: 6pt, fill: luma(100))
})

== narration while writing [DRILL]

Narrate decisions, not keystrokes. The channel carries why this and
not that, the tradeoff at the turn, the reason the map is a map.
Every skip is flagged aloud, "I will pretend this helper exists and
test it after", so the observer can price the skip instead of
discovering it. Uncertainty is annotated in the same breath as the
line it touches, "this is n log n from the sort, the inner scan is
still naive, I will come back to it", because a stated doubt is a
plan and an unstated one is a hole.

The evidence for spending the air this way is pinned in the
landscape chapter: the interviewing.io 100k analysis found code and
problem solving scores dominate pass decisions and communication is
the smallest rubric factor, and the same narration is how a problem
solving score gets observed at all,
#xref-to("repertoire", "landscape"). Both facts hold at once. The
rubric pays least for talking and the score it pays for cannot be
seen without it, so the narration is not performance, it is the
observable half of the work, which is exactly what a loop grades
now that unassisted code alone proves so much less.

#diagram([narration is the observable channel, decisions, skips, doubts, carried on the air], length: 13pt, {
  // three inputs into the channel, silent typing crossed out below
  let src(y, t) = {
    cdraw.rect((0.6, y), (7.4, y + 1.2), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((4.0, y + 0.6), t, size: 6pt)
  }
  src(7.6, [decisions, why this not that])
  src(6.0, [skips, flagged aloud])
  src(4.4, [doubts, annotated in place])
  cdraw.line((7.4, 8.2), (9.6, 7.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.4, 6.6), (9.6, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.4, 5.0), (9.6, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((9.6, 5.3), (16.6, 8.0), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((13.1, 7.4), [the narration channel], size: 6.5pt)
  cdraw.content((13.1, 6.35), [smallest rubric factor], size: 6pt)
  cdraw.content((13.1, 5.75), [the only way solving is seen], size: 6pt)
  cdraw.rect((17.4, 5.3), (22.8, 8.0), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((20.1, 7.4), [the score], size: 6.5pt)
  cdraw.content((20.1, 6.35), [problem solving], size: 6pt)
  cdraw.content((20.1, 5.75), [observed or absent], size: 6pt)
  cdraw.line((16.6, 6.65), (17.4, 6.65), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.6, 3.0), (16.6, 4.2), fill: none, stroke: (paint: luma(150), dash: "dashed"), radius: 0.02)
  cdraw.content((8.6, 3.6), [silent typing carries nothing, the observer cannot price what was never said], size: 6pt, fill: luma(120))
})

== blanking recovery [DRILL]

The blank is a state, not a verdict, and it has a loop. Name it
aloud, "I have lost the thread, let me restate what I have", which
converts the silence into a move the observer can follow. Shrink to
a smaller problem, solve for one element, for the empty input, for
n equal to 2, because the small case re-derives the invariant the
blank lost. Write the naive version and label it, the labeled naive
is a plan with a complexity attached, the unlabeled one reads as
the ceiling. Annotate the uncertainty and keep moving, write the
line you believe in, mark the doubt, continue, a wrong line marked
beats a blank page every round. The loop exits when the thread is
back, and running it twice in one round costs less than hiding the
blank once, the hidden blank is the only unrecoverable version.

#diagram([the blank has a loop, name it, shrink it, label the naive, annotate, move], length: 13pt, {
  // five states in a cycle, the exit arrow out of the last
  let st(x, y, t, sub) = {
    cdraw.rect((x, y), (x + 5.4, y + 1.5), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 2.7, y + 1.0), t, size: 6.5pt)
    cdraw.content((x + 2.7, y + 0.42), sub, size: 6pt)
  }
  st(0.5, 7.6, [the blank], [lost the thread])
  st(8.4, 7.6, [name it aloud], [a move the room follows])
  st(16.2, 7.6, [shrink], [one element, n = 2, empty])
  st(16.2, 3.4, [naive, labeled], [a plan, not a ceiling])
  st(8.4, 3.4, [annotate, move], [the doubt marked, the pen moving])
  cdraw.line((5.9, 8.35), (8.4, 8.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.8, 8.35), (16.2, 8.35), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.9, 7.6), (18.9, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.2, 4.15), (13.8, 4.15), stroke: luma(100), mark: (end: ">"))
  cdraw.line((8.4, 4.15), (5.6, 4.15), (5.6, 5.4), (3.2, 5.4), (3.2, 7.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.6, 5.75), [still blank: run it again, aloud], size: 6pt, fill: luma(100))
  cdraw.rect((0.5, 0.9), (10.6, 2.3), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((5.55, 1.95), [the exit], size: 6.5pt)
  cdraw.content((5.55, 1.35), [the thread is back, resume the round], size: 6pt)
  cdraw.line((11.1, 3.4), (11.1, 1.6), (10.6, 1.6), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((16.9, 1.6), [the hidden blank is the only unrecoverable one], size: 6pt, fill: luma(100))
})

== ai-assist norms [DRILL]

The numbers first, pinned in the landscape chapter from Karat's
2026 trends report, 400 engineering leaders: 62 percent of
organizations still ban AI in interviews while estimating over
half of candidates use one anyway, live technical interviews still
run at 79 percent in the US, 71 percent say AI makes technical
skills harder to assess, and take-homes and automated code tests
degrade fastest as signal, #xref-to("repertoire", "landscape").
Three norms follow. Disclosure first: state what you intend to use
before you use it, the rule is theirs to give and asking for it is
free, 62 percent of the rooms ban it. Scope, named: autocomplete
and syntax recall against generation and solution shape are
different concessions, and saying which one you are making is the
difference between use and smuggling. Concede cleanly: if the
round bans the assistant, closing it is the whole answer, no
negotiation, and the honest posture underneath all three is that
the loop already assumes the assistant exists, which is why the
graded channel is the narration and the follow-ups rather than the
keystrokes.

#callout("pitfall", "the undisclosed assist", [
  The one unrecoverable move in this round is the assist the
  interviewer can see but you have not named, the paste that lands
  too fast, the API call the connection log shows. Disclosure costs
  a sentence, the undisclosed assist costs the trust every later
  answer rides on, the repeated-game price, #xref-to("cookbook",
  "games") states it.
])

#diagram([the 2026 numbers pinned, 62 ban, 79 still live, half use one anyway], length: 13pt, {
  // three number boxes over the three norms, the fourth number set apart
  let num(x, n, t) = {
    cdraw.rect((x, 6.4), (x + 6.9, 8.6), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 3.45, 7.95), n, size: 6.5pt)
    cdraw.content((x + 3.45, 7.1), t, size: 6pt)
  }
  num(0.5, [62 percent], [still ban it])
  num(8.4, [79 percent], [still run live, in the us])
  num(16.3, [over half], [estimated using one])
  cdraw.content((11.8, 9.3), [karat 2026, 400 leaders: 71 percent say ai makes skills harder to assess], size: 6pt, fill: luma(100))
  let norm(x, t) = {
    cdraw.rect((x, 3.6), (x + 6.9, 5.6), fill: luma(215), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 3.45, 4.6), t, size: 6.5pt)
  }
  norm(0.5, [disclose first])
  norm(8.4, [name the scope])
  norm(16.3, [concede a ban cleanly])
  cdraw.line((3.95, 6.4), (3.95, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.85, 6.4), (11.85, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((19.75, 6.4), (19.75, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.75, 2.5), [the room already assumes the assistant, the narration is what gets graded], size: 6pt, fill: luma(100))
})

== timed mocks from this book [DRILL]

The mock deck is already written, it is this book, and no external
question set is needed. The 25-minute set: any section of the two
classics chapters or the algorithm patterns chapter, #xref-to(
"repertoire", "classics1"), #xref-to("repertoire", "classics2"),
#xref-to("repertoire", "algopatterns"), one problem, spoken start
to finish. The 40-minute set: the four design prompts of the
design prompts chapter, #xref-to("repertoire", "design-prompts"),
topology drawn aloud, the tradeoffs owed out loud. The
15-minute set: the emitter or the promise subset from the
javascript from scratch chapter, #xref-to("repertoire",
"js-fromscratch"), mechanism over polish. The debugging set:
delete a line from any go sample in this book and hand it over,
reproduce, isolate, fix, prove, the section below owns the loop.

The scoring rubric is the book's own three labels, asked as
questions: does the code run, the TDD question. Is the mechanism
named, the EWC question. Are the follow-ups caught, the DRILL
question. Two of three is a fail, and the rubric needs no external
judge because the labels already define what finished means in this
corpus. Partner protocol: the partner holds the chapter file, fires
the DRILL traps written in it, and scores only the three labels,
one line each, no coaching mid-mock, the feedback lands after the
clock.

#diagram([the mock deck map, four lanes, one rubric, the partner holds the file], length: 13pt, {
  // four lanes left, the rubric column right, the partner note below
  let lane(y, t, sub) = {
    cdraw.rect((0.5, y), (14.8, y + 1.5), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((2.0, y + 0.98), t, size: 6.5pt)
    cdraw.content((7.6, y + 0.42), sub, size: 6pt)
  }
  lane(7.7, [25 minutes], [classics1, classics2, algopatterns sections])
  lane(6.0, [40 minutes], [the four design prompts, ch 36, drawn aloud])
  lane(4.3, [15 minutes], [the js emitter or the promise subset, ch 9])
  lane(2.6, [debugging], [a deleted line from any go sample in this book])
  cdraw.rect((16.2, 2.6), (22.9, 9.2), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((19.55, 8.6), [the rubric], size: 6.5pt)
  cdraw.content((19.55, 7.2), [does the code run], size: 6pt)
  cdraw.content((19.55, 5.8), [is the mechanism named], size: 6pt)
  cdraw.content((19.55, 4.4), [are the follow-ups caught], size: 6pt)
  cdraw.content((19.55, 3.2), [2 of 3 is a fail], size: 6pt, fill: luma(120))
  cdraw.content((11.5, 1.3), [the partner holds the chapter file, fires its drills, scores three lines after the clock], size: 6pt, fill: luma(100))
})

== take-home discipline [DRILL]

Take-homes degrade fastest as signal, the Karat row says so, so the
strategy is over-transparency. The scope contract comes before any
code: what is in, what is out, what done grades, asked and answered
before building, because the unasked scope question is how a
weekend becomes two. The method is the beats of the react build
chapter, #xref-to("repertoire", "react-build"), the template this
corpus already drills: the test file alone first, the honest red,
the minimal green, then the extension, commit order carrying the
story. The readme tells the grader how to run it, prerequisites,
the one command, the one test command, and what was cut and why,
written for a stranger. And the handoff is one command, the
corpus's own make verify posture, the same gate every sample in
this book runs under: the grader's first action is the readme,
the second is the command, and anything that needs a live
explanation inside the repo has already failed.

#diagram([the take-home ladder, contract, red, green, readme, one command], length: 13pt, {
  // five rungs left to right, the grader's two actions annotated below
  let rung(x, t, sub) = {
    cdraw.rect((x, 5.0), (x + 4.2, 7.0), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 2.1, 6.35), t, size: 6.5pt)
    cdraw.content((x + 2.1, 5.6), sub, size: 6pt)
  }
  let xs = (0.5, 5.2, 9.9, 14.6, 19.3)
  rung(xs.at(0), [the contract], [in, out, done])
  rung(xs.at(1), [red first], [the test file alone])
  rung(xs.at(2), [minimal green], [then extend])
  rung(xs.at(3), [the readme], [for a stranger])
  rung(xs.at(4), [one command], [the verify posture])
  for i in range(4) {
    cdraw.line((xs.at(i) + 4.2, 6.0), (xs.at(i + 1), 6.0), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((5.0, 3.4), [the grader reads the readme], size: 6pt, fill: luma(100))
  cdraw.content((17.8, 3.4), [then runs the one command], size: 6pt, fill: luma(100))
  cdraw.content((11.75, 1.9), [a take-home that needs its author present is a failed take-home], size: 6pt, fill: luma(100))
})

== the debugging round [DRILL]

Four moves, and the last one is the rule. Reproduce: the bug that
cannot be reproduced cannot be proved fixed, so the smallest input
that shows it comes first, printed, deterministic where possible.
Isolate: bisect the path, and the signals have an order, the metric
names the symptom, the trace names the hop, the log explains the
line, #xref-to("patterns", "observability") owns all three, and the
test layers name the seam, store, service, handler, notifier, each
with its own suite, #xref-to("repertoire", "go-testing"). Fix: the
smallest change that removes the cause, not the symptom, and if the
fix is not small, the isolation was not done. Prove: the failing
test comes first, written against the reproduction, red, then the
fix, then the same test green and the suite green, because a fix
without a prior red test is a story, and the debugging round grades
the proof, not the anecdote.

#diagram([reproduce, isolate, fix, prove, the failing test arrives before the fix], length: 13pt, {
  // the pipeline with one guard under prove
  let stage(x, t, sub) = {
    cdraw.rect((x, 5.4), (x + 5.0, 7.4), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((x + 2.5, 6.75), t, size: 6.5pt)
    cdraw.content((x + 2.5, 6.0), sub, size: 6pt)
  }
  let xs = (0.5, 6.3, 12.1, 17.9)
  stage(xs.at(0), [reproduce], [smallest failing input])
  stage(xs.at(1), [isolate], [the signals, the seam])
  stage(xs.at(2), [fix], [the cause, smallest change])
  stage(xs.at(3), [prove], [test red, then green])
  for i in range(3) {
    cdraw.line((xs.at(i) + 5.0, 6.4), (xs.at(i + 1), 6.4), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.rect((0.5, 2.6), (23.2, 4.2), fill: none, stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((11.85, 3.75), [the guard: no failing test, no proof], size: 6.5pt, fill: luma(100))
  cdraw.content((11.85, 3.05), [the red test exists before the fix lands, otherwise the fix is an anecdote], size: 6pt)
  cdraw.line((20.7, 5.4), (20.7, 4.2), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.content((11.75, 1.5), [a fix without a prior red is a story, the round grades the proof], size: 6pt, fill: luma(100))
})

floored to the pinned and the drilled: #xref-to("repertoire",
"landscape") for the round facts this chapter leans on, the 100k
analysis reading and the Karat numbers with their dates,
#xref-to("cookbook", "communication") for the delivery mechanics,
the stop, the frame, the silence, #xref-to("cookbook", "playbook")
for the hostile follow-ups these answers must survive, and the
debugging round's two floors, #xref-to("repertoire", "go-testing")
for the test layers that name the seam and
#xref-to("patterns", "observability") for the signals that say
where to look first.
