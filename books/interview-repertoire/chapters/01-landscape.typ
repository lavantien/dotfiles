#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= the 2026 interview landscape

The interview loop this book drills for changed shape between 2024 and 2026.
AI-assisted screening spread first, then the live rounds absorbed it: several
major employers now run AI-enabled coding rounds or comprehension-focused
experiments, and every serious loop assumes the candidate has an assistant
one keystroke away. What did not shrink is the live problem solving norm.
Medium difficulty data structure problems, solved with narration, still gate
the generalist software loop. On what the narration is worth, the pinned
data cuts both ways and this book takes the honest reading: a 100k interview
analysis by interviewing.io found code and problem solving scores dominate
pass decisions and communication is the smallest rubric factor, and the
same narration is how a problem solving score gets observed at all, which
is what a loop does now that unassisted code alone proves so much less.

Three consequences organize this book.

First, every answer ships code. A spoken answer that cannot survive
"show me" is a liability in a loop where the interviewer can ask for the
repo. The classic questions, from two sum through the event loop through a
rate limited REST service, are implemented here with their tests, in the
languages the questions get asked in: Go and C\# for the algorithm half,
plain JavaScript and a real React workspace for the frontend half, Go for
the systems half.

Second, system design weight rose as pure coding signal fell. The design
chapters treat scaling, gateways, queues, and the 300K concurrent user
sketch as first class drills with drawn topologies, not as trivia.

Third, the spoken layer is an artifact. Every implementable carries the
narration that goes with it: what to say while writing, what to concede
early, and what the follow-up trap is. The repertoire format is answer,
code, drill.

== how the chapters are labeled

Every chapter carries one of three labels on its sections.

- *TDD*, test driven. The section exists as code first: a failing test, the
  minimal implementation, the refactor. These live in the sample and
  capstone workspaces this book carries and run under `make verify`.
- *EWC*, explained with code. The section walks existing code line by line.
  The code runs under the same gate, the explanation is the deliverable.
- *DRILL*, spoken answer. No new code. The section is the answer to say out
  loud, the follow-ups to expect, and the floor chapter that backs it, in
  this book or in the handbooks it cross references.

#diagram([the three labels are a contract about where the evidence lives], length: 13pt, {
  // row label column plus one column per label, every cell one fact
  let cell(x, y, w, h, t, fill: luma(235), size: 6pt) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), [#t], size: size)
  }
  cell(0.0, 4.6, 3.6, 1.5, "", fill: luma(252))
  cell(3.6, 4.6, 6.8, 1.5, [tdd \ test driven], fill: luma(215))
  cell(10.4, 4.6, 6.8, 1.5, [ewc \ with code], fill: luma(215))
  cell(17.2, 4.6, 6.8, 1.5, [drill \ spoken], fill: luma(215))
  cell(0.0, 3.4, 3.6, 1.1, [evidence], fill: luma(252))
  cell(3.6, 3.4, 6.8, 1.1, [a failing test first])
  cell(10.4, 3.4, 6.8, 1.1, [gated code, walked])
  cell(17.2, 3.4, 6.8, 1.1, [a spoken answer])
  cell(0.0, 2.2, 3.6, 1.1, [the gate], fill: luma(252))
  cell(3.6, 2.2, 6.8, 1.1, [new code, red first])
  cell(10.4, 2.2, 6.8, 1.1, [pre-existing suite])
  cell(17.2, 2.2, 6.8, 1.1, [no new code])
  cell(0.0, 1.0, 3.6, 1.1, [deliverable], fill: luma(252))
  cell(3.6, 1.0, 6.8, 1.1, [the green suite])
  cell(10.4, 1.0, 6.8, 1.1, [the explanation])
  cell(17.2, 1.0, 6.8, 1.1, [script, follow-ups])
})

#callout("note", "the question inventory is audited, not claimed", [
  The appendices hold the full question to section index. Every question in
  the inventory this book was commissioned from maps to at least one
  labeled section, and the mapping is a table in
  #xref-to("repertoire", "appendices"), so a missing answer is a visible
  gap in a compiled document, not a quiet omission.
])

== what this book is not

It is not a problem archive. The inventory is the frequent sixty or so, the
questions that recur across loops, stacked into 158 index rows across the 40
practice chapters, each with working code where code is the honest answer and
a drilled script where talking is. Depth questions, the
ones that separate a practitioner from a memorizer, cross reference the
handbooks: the language manuals for books 3 through 7 floor the syntax
questions, #xref-to("dsa", "analysis") and its neighbors floor the
complexity claims, #xref-to("infrastructure", "jetstream") floors the
streaming answers, and the defense cookbook, book 14, owns the resume
itself. Part 3, chapters 23 through 31, is that promise kept in reverse:
the algorithm whiteboard staples gated under tdd in two go workspaces, and
seven spoken-answer chapters floored on the handbooks they name, the
distributed patterns, the c manual, mathematics, knowledge discovery, and
the python, lua, and c\# manuals, so the corpus's core concepts each carry
a drilled answer here without re-carrying their code. Part 4, chapters 32
through 40, is the loop completed: the web platform in css, rendering, and
security answers, estimation at the back of the envelope and four worked
design prompts, and the human round, behavioral and the observed screen,
take-homes and debugging, negotiation, and the java and rust transfer, so
every stage of a real loop from the first screen to the signed offer
carries a drilled answer here.

#flow([every depth question has an owner, the frequent sixty or so stay here],
  node((0, 0), [a depth question]),
  node((4.6, 1.65), [syntax floors#linebreak()books 3 to 7]),
  node((4.6, 0.55), [complexity claims#linebreak()the dsa volume]),
  node((4.6, -0.55), [streaming answers#linebreak()infrastructure]),
  node((4.6, -1.65), [the resume itself#linebreak()defense cookbook]),
  edge((0, 0), (4.6, 1.65), "-|>"),
  edge((0, 0), (4.6, 0.55), "-|>"),
  edge((0, 0), (4.6, -0.55), "-|>"),
  edge((0, 0), (4.6, -1.65), "-|>"),
)

== how to drill

One pass per chapter, aloud, same rule as the defense cookbook. Read the
section once, close it, speak the answer at an imaginary interviewer, open
the code and read it as you would narrate it live, then move on. The night
before, read only the appendices index and the DRILL sections. Everything
else is either internalized by then or it is not.

#diagram([the rehearsal loop, one pass per chapter, aloud], length: 13pt, {
  // five moves left to right, the whole pass fits in one sitting
  let box(x, t) = {
    cdraw.rect((x, 2.6), (x + 4.1, 4.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 2.05, 3.4), [#t], size: 6pt)
  }
  let xs = (0.5, 5.1, 9.7, 14.3, 18.9)
  box(xs.at(0), [read the \ section])
  box(xs.at(1), [close it])
  box(xs.at(2), [speak the \ answer])
  box(xs.at(3), [open and \ narrate])
  box(xs.at(4), [move on])
  for i in range(4) {
    cdraw.line((xs.at(i) + 4.1, 3.4), (xs.at(i + 1), 3.4), stroke: luma(100), mark: (end: ">"))
  }
  // the night before cuts the loop to two artifacts
  cdraw.line((0.5, 2.2), (23.0, 2.2), stroke: luma(220))
  cdraw.line((0.5, 2.2), (0.5, 2.4), stroke: luma(220))
  cdraw.line((23.0, 2.2), (23.0, 2.4), stroke: luma(220))
  cdraw.content((11.75, 1.55), [night before: drill sections and the appendices index only], size: 6.5pt)
})

== the 2026 facts, pinned

The meta claims above are not folklore. Meta piloted an AI-enabled coding
round in october 2025 that replaces one of the two onsite coding rounds,
sixty minutes with an assistant expected, per interviewing.io's walkthrough.
Google was reported in may 2026 to be piloting a comprehension round with
an AI assistant, rolling out through the second half of the year. Karat's
2026 trends report, published january 2026 from 400 engineering leaders,
has the numbers that frame the whole book: 71 percent say AI makes
technical skills harder to assess, take-homes and automated code tests
degrade fastest as signal, live technical interviews still run at 79
percent in the US, and 62 percent of organizations still ban AI in
interviews while estimating over half of candidates use it anyway. System
design weight rose as the coding signal fell, with 2026 guides reporting a
higher passing bar and AI infrastructure prompts inside design rounds.
Every URL and access date for these claims sits in the sources appendix of
#xref-to("repertoire", "appendices"), verified 2026-09-10.

#diagram([ai-assisted rounds, pinned: oct 2025 into 2026], length: 13pt, {
  // the axis is time, the karat numbers sit under their own tick
  cdraw.line((1.5, 3.2), (23.3, 3.2), stroke: luma(100), mark: (end: ">"))
  let tick(x, above, lines) = {
    cdraw.circle((x, 3.2), radius: 0.09, fill: luma(100))
    cdraw.content((x, 3.8), above, size: 6.5pt)
    for i in range(lines.len()) {
      cdraw.content((x, 2.55 - i * 1.05), lines.at(i), size: 6pt)
    }
  }
  tick(4.0, [oct 2025], ([meta's ai round],))
  tick(11.5, [jan 2026], ([karat trends, 400 leaders], [71: harder to assess], [62 ban, 79 still live]))
  tick(20.2, [may 2026], ([google comprehension], [round, h2 rollout]))
})
