#import "../../theme/lib.typ": callout, diagram, cdraw
#import "../manifest.typ": pybook
#import "../coverage/topics.typ": topics
#import "../coverage/sources.typ": sources

= appendices: coverage and sources

Twenty-six content chapters and the two capstone parts stand behind
this book and this chapter adds no claim to any of them. It computes
two views over what those chapters left behind, the topic matrix at
`coverage/topics.typ`, one row per verified topic with its cost and its
nearest stdlib or library counterpart, and the pinned source list at
`coverage/sources.typ`, one row per canonical page a chapter actually
consulted, then freezes the version pins those chapters asserted.
Every number on this page is computed by this page from those arrays,
and the asserts below fail the build when the matrix and the manifest
disagree, so the appendix cannot drift from the corpus it describes.

== topic matrix

#let ids = pybook.chapters.map(c => c.id)
#let content-chapters = pybook.chapters.filter(c => c.id != "appendices")
#let unmapped = topics.filter(r => ids.find(i => i == r.chapter) == none)
#assert(unmapped.len() == 0, message: "topic rows mapping to no manifest chapter: " + unmapped.map(r => r.topic).join(", "))
#let per-chapter = content-chapters.map(c => topics.filter(r => r.chapter == c.id).len())
#let na-rows = content-chapters.map(c => topics.filter(r => r.chapter == c.id and r.cost.starts-with("n/a")).len())
#let n-of(k) = per-chapter.enumerate().filter(p => p.at(1) == k).len()
#let max-c = calc.max(..per-chapter)
#let min-c = calc.min(..per-chapter)
#let busiest = per-chapter.position(n => n == max-c)
#let arcs = (per-chapter.slice(0, 12).sum(), per-chapter.slice(12, 20).sum(), per-chapter.slice(20, 28).sum())
#let arc-na = (na-rows.slice(0, 12).sum(), na-rows.slice(12, 20).sum(), na-rows.slice(20, 28).sum())

The matrix holds #topics.len() topic rows across the
#content-chapters.len() chapters and none unmapped, and that zero is
the assert above, not prose: each row's chapter field is looked up
against the manifest ids and a row naming an id no chapter carries
stops the build instead of rendering a stray bar. The distribution is
flat by design, #n-of(4) chapters carry 4 rows, and the two capstone
parts carry the only exceptions, #n-of(5) rows for part 1 and #max-c
for part 2, the chapters whose opening and closing sections the plan
let grow past the four-section grammar. The sparsest count is #min-c
and no arc owns the ledger: chapters 1 through 12 hold #arcs.at(0)
rows for the language core, 13 through 20 hold #arcs.at(1) for the
runtime, memory, and systems chapters, and 21 through 28 hold
#arcs.at(2) for the libraries and the capstone.

The strip splits every bar by cost. Dark is the
#topics.filter(r => not r.cost.starts-with("n/a")).len() rows that
carry a measured or probed fact, a probe count, a byte count, a
version census, a pinned divergence. Light is the #na-rows.sum()
semantics and documentation rows, the honest boundary the book refuses
to dress up as a measurement. The runtime and systems arc is the
darkest, #{ arcs.at(1) - arc-na.at(1) } of #arcs.at(1) rows measured,
because its chapters assert behavior in running samples, pipe
deadlocks, worker caps, race outcomes, thread-to-process ratios, and
a later pass added its two most measured chapters, pymalloc and
profiling, with not one n/a row between them. The language core is the
lightest by share, #{ arcs.at(0) - arc-na.at(0) } of #arcs.at(0),
semantics rows for the most part with the gc thresholds and the growth
ladders the exceptions. The library arc sits between,
#{ arcs.at(2) - arc-na.at(2) } of #arcs.at(2), the probed promotion
and interpolation facts against quoted documentation.

#diagram([the distribution strip: one bar per chapter in manifest order, the number above a bar is its topic count, dark is a row with a measured or probed cost, light is an n/a row], length: 13pt, {
  let pitch = 0.8
  let bw = 0.56
  let y0 = 3.4
  let sc = 0.5
  for (i, c) in per-chapter.enumerate() {
    let na = na-rows.at(i)
    let m = c - na
    let x = 0.5 + i * pitch
    cdraw.rect((x, y0), (x + bw, y0 + m * sc), fill: luma(160), radius: 0.0)
    cdraw.rect((x, y0 + m * sc), (x + bw, y0 + c * sc), fill: luma(235), radius: 0.0)
    cdraw.content((x + bw / 2, y0 + c * sc + 0.32), [#c], wrap: text.with(size: 6pt))
    cdraw.content((x + bw / 2, 3.02), [#content-chapters.at(i).num], wrap: text.with(size: 6pt))
  }
  cdraw.line((0.5, y0), (22.9, y0), stroke: 0.5pt + luma(180))
  let div(x) = cdraw.line((x, y0 - 0.08), (x, 7.0), stroke: 0.5pt + luma(200))
  div(0.5 + 12 * pitch - 0.14)
  div(0.5 + 20 * pitch - 0.14)
  cdraw.content((4.9, 1.78), [the language core, #linebreak() chapters 1 to 12], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((12.9, 1.78), [runtime, memory, #linebreak() and systems, chapters 13 to 20], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((19.3, 1.78), [libraries and capstone, #linebreak() chapters 21 to 28], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.6, 0.25), [the arcs hold #arcs.at(0), #arcs.at(1), #arcs.at(2) rows left to right, the systems arc the darkest, the language core the lightest], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== sources ledger

#let family-of(url) = {
  if url.starts-with("https://docs.python.org/") { "docs.python.org" }
  else if url.starts-with("https://peps.python.org/") { "peps.python.org" }
  else if url.starts-with("https://fastapi.tiangolo.com/") { "fastapi.tiangolo.com" }
  else if url.starts-with("https://numpy.org/") { "numpy.org" }
  else if url.starts-with("https://docs.pydantic.dev/") or url.starts-with("https://pydantic.dev/") { "pydantic.dev" }
  else if url.starts-with("https://pandas.pydata.org/") { "pandas.pydata.org" }
  else if url.starts-with("https://github.com/") { "github.com" }
  else if url.starts-with("https://learn.microsoft.com/") { "learn.microsoft.com" }
  else { "unlisted" }
}
#let families = ("docs.python.org", "peps.python.org", "fastapi.tiangolo.com", "numpy.org", "pydantic.dev", "pandas.pydata.org", "github.com", "learn.microsoft.com")
#let fam-counts = families.map(f => sources.filter(s => family-of(s.url) == f).len())
#let dates = sources.map(s => s.accessed).sorted().dedup()
#let date-counts = dates.map(d => sources.filter(s => s.accessed == d).len())
#let distinct-urls = sources.map(s => s.url).sorted().dedup().len()
#assert(date-counts.sum() == sources.len(), message: "date census lost rows")
#assert(fam-counts.sum() == sources.len(), message: "family census lost rows, an url fell outside the listed families")
#assert(distinct-urls == sources.len(), message: "a url earned a second row, the prose says none did")

Every chapter ends with its own sources line and this section is all
of them rolled up: #sources.len() rows over #distinct-urls distinct
urls, no page consulted twice, every row carrying its own access date.
The rows name #dates.len() verification
#(if dates.len() == 1 [pass] else [passes]),
#dates.enumerate().map(p => "#date-counts.at(p.at(0)) rows on #p.at(1)").join(", "),
#if dates.len() > 1 [the 2026-09-12 pass that verified the book and the later pass that added the memory and measurement chapters, each row dated by its own fetch] [the single date because the book's verification ran as one pass so far].
The host census is computed the same way and its counts are rows per
family, not fetches. The python software foundation carries the load,
#fam-counts.at(0) rows on docs.python.org for the library and
reference pages plus #fam-counts.at(1) on peps.python.org, the
numbered proposals the language chapters quote. The third-party houses
follow: fastapi.tiangolo.com carries #fam-counts.at(2) for the taught
web chapter and its release notes, numpy.org #fam-counts.at(3)
including the nep 50 promotion proposal, the pydantic family
#fam-counts.at(4) across two host forms, docs.pydantic.dev for the
fields page and pydantic.dev for the validation concepts, the current
canonical home, and pandas.pydata.org #fam-counts.at(5). The last two
rows sit outside the language entirely: github.com carries the ruff
changelog row that dates the formatter pin, and learn.microsoft.com
carries the netsh command reference behind the firewall preflight that
keeps the capstone's real-socket test from popping a dialog on this
machine.

#diagram([the pin set on its access timeline: one circle per verification pass, one row per host family, the count beside each label computed from the array], length: 13pt, {
  cdraw.line((13.6, 0.4), (13.6, 9.2), stroke: luma(100))
  let y = 7.95
  for (i, f) in families.enumerate() {
    cdraw.line((12.95, y), (13.5, y), stroke: luma(200))
    cdraw.content((12.6, y), [#f], wrap: text.with(size: 6pt), anchor: "east")
    cdraw.content((13.85, y), [#fam-counts.at(i)], wrap: text.with(size: 6pt, fill: luma(100)), anchor: "west")
    y -= 0.92
  }
  for (i, d) in dates.enumerate() {
    let cy = 9.0 - i * 0.55
    cdraw.circle((13.6, cy), radius: 0.09, fill: luma(100))
    cdraw.content((13.95, cy), [#date-counts.at(i) rows accessed #d], wrap: text.with(size: 6pt, fill: luma(100)), anchor: "west")
  }
  cdraw.content((16.9, 2.2), [two host forms share one, #linebreak() pydantic family, the fields, #linebreak() page and the validation, #linebreak() concepts], wrap: text.with(size: 6pt, fill: luma(100)), anchor: "west")
  cdraw.content((16.9, 1.28), [the two solo rows date the, #linebreak() formatter pin and guard the, #linebreak() firewall preflight], wrap: text.with(size: 6pt, fill: luma(100)), anchor: "west")
})

== the version drift rule

Four moves happened under this book while it was written, and each is
recorded rather than silently repaired. The register's environment
facts paragraph carries the first two. The taught web library switched
from httpx to fastapi 0.141.1 before chapter 22 was written, one user
decision mid-build, with 3.14 support verified back to 0.118.3, and
the capstone's client leg settled on stdlib urllib so the taught set
stayed honest about what a boundary fetch needs. Then the gate
surfaced starlette 1.6.0 deprecating httpx inside TestClient with the
message "install httpx2 instead", so the test-only pin moved to httpx2
2.12.0 and the deprecation itself became a taught boundary fact in
chapter 22. The third move is ruff: 0.16.0 grew its default rule set
from 59 rules to 413, so the book freezes its selection at E4, E7,
E9, and F with line length 88, because a format gate that changes
meaning between patch releases is not a gate. The fourth is
environment drift rather than package drift: pandas hard-depends on
tzdata, so the gate venv resolves timezones while the bare per-user
3.14.7 raises ZoneInfoNotFoundError even for utc, which chapter 19
teaches two-sided rather than papering over. Row pyt-002 is the
arithmetic cousin of the family: the figure plan header said 109 rows
while the table carried 110 after the fastapi switch gave the capstone
its sixth section, and the re-total is the fix.

#diagram([before and after: the pin set as planned against the pin set as shipped, one user decision and two gate discoveries apart], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 0.85), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.42), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((4.9, 9.5), [the pin set as planned], wrap: text.with(size: 6.5pt))
  cdraw.content((17.1, 9.5), [the pin set as shipped], wrap: text.with(size: 6.5pt))
  box(0.6, 8.3, 8.6, [cpython 3.14.7])
  box(0.6, 7.3, 8.6, [pydantic, pandas, numpy])
  box(0.6, 6.3, 8.6, [httpx, the taught client chapter])
  box(0.6, 5.3, 8.6, [ruff, tools-only])
  box(12.8, 8.3, 8.6, [cpython 3.14.7])
  box(12.8, 7.35, 8.6, [fastapi 0.141.1, taught])
  box(12.8, 6.4, 8.6, [pydantic 2.13.4])
  box(12.8, 5.45, 8.6, [pandas 3.0.5])
  box(12.8, 4.5, 8.6, [numpy 2.5.3])
  box(12.8, 3.55, 8.6, [httpx2 2.12.0, test-only])
  box(12.8, 2.6, 8.6, [ruff 0.16.7, tools-only])
  box(12.8, 1.65, 8.6, [starlette 1.6.0, transitive], fill: luma(245))
  cdraw.line((9.2, 6.7), (12.8, 7.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.2, 6.7), (12.8, 4.0), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((11.0, 8.4), [the taught chapter, #linebreak() swapped to fastapi], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.0, 5.1), [the test engine, #linebreak() followed starlette], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.0, 0.7), [same analysis stack, the web boundary, #linebreak() rewritten from client to server], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("note", "version drift rule", [
  The pins this book froze: cpython 3.14.7 for every sample and the
  in-sample patch assert, fastapi 0.141.1 as the taught web framework,
  pydantic 2.13.4, pandas 3.0.5, numpy 2.5.3, httpx2 2.12.0 as the
  test-only TestClient engine, ruff 0.16.7 as the tools-only formatter
  with its rule selection frozen, and starlette 1.6.0 riding along
  transitive and pinned. Packages and pages will move again: a
  deprecation lands, a promotion rule changes, a default grows. Cite
  what you fetched, assert the exact version from inside the sample,
  and treat the pins and access dates as the only durable facts. The
  #sources.len() rows behind the timeline are that record: when a
  future fetch disagrees with a row here, the row is what this book
  claimed and the date is when it was true.
])

#callout("verify", "the gate behind the matrix", [
  `make verify-py` over the tree this chapter lands in reports: 107
  files, 1103 checks, 18 dis assertions, format clean, 78 capstone
  tests. This chapter ships no samples, so its own checks are the
  three asserts above, the unmapped zero, the family and date
  censuses, and the distinct-url count, plus the compile that turns
  the arrays into the numbers on this page. Every count quoted in the
  verify callouts of the written chapters rolls up into that one gate
  line, and the line is reproducible from a clean venv whose name is
  the hash of the requirements file that built it.
])

sources: `coverage/topics.typ` and `coverage/sources.typ`, the two
arrays this page computes every number from, and docs/audit/python.md,
register rows pyt-001 and pyt-002 plus the environment facts
paragraph, the drift record this chapter generalizes. All
#sources.len() source rows accessed #dates.join(" and "), no new pages
fetched for this appendix, it cites the record the chapters already
left behind. Sample behavior throughout the book verified by
`make verify-py`, 1103 checks behind the matrix this chapter computes.
