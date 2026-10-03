#import "../../theme/lib.typ": callout, diagram, cdraw
#import "../manifest.typ": cosbook
#import "../coverage/topics.typ": topics
#import "../coverage/sources.typ": sources

= appendices: topic matrix and sources

Twenty-seven topic chapters stand behind the matrix this chapter
computes, and the thirteen service chapters behind them stand behind
the lane instead: chapters 28 through 40 carry no topic rows, their
proof is the check count `make verify-capi` runs over the vehicle at
`books/c-os-cloud/api`, and the assert below pins that boundary so a
topic row cannot silently appear inside the service part. This chapter
adds no claim to any of them. It computes two views over what the book
left behind: the topic matrix at `coverage/topics.typ`, one
row per verified topic with its cost and its nearest standard or os
counterpart, and the pinned source list at `coverage/sources.typ`, one
row per canonical page a chapter actually consulted. Every number on
this page is computed by this page from those arrays, and the asserts
below fail the build when the matrix and the manifest disagree, so
the appendix cannot drift from the corpus it describes.

== topic coverage

#let ids = cosbook.chapters.map(c => c.id)
#let topic-chapters = cosbook.chapters.filter(c => c.num <= 27)
#let service-chapters = cosbook.chapters.filter(c => c.num >= 28 and c.id != "appendices")
#assert(topic-chapters.len() == 27 and service-chapters.len() == 13, message: "the matrix boundary moved, revisit this page")
#let unmapped = topics.filter(r => ids.find(i => i == r.chapter) == none)
#assert(unmapped.len() == 0, message: "topic rows mapping to no manifest chapter: " + unmapped.map(r => r.topic).join(", "))
#let in-service = topics.filter(r => service-chapters.find(c => c.id == r.chapter) != none)
#assert(in-service.len() == 0, message: "topic rows inside the service part: " + in-service.map(r => r.topic).join(", "))
#let content-chapters = topic-chapters
#let per-chapter = content-chapters.map(c => topics.filter(r => r.chapter == c.id).len())
#let na-rows = content-chapters.map(c => topics.filter(r => r.chapter == c.id and r.cost.starts-with("n/a")).len())
#let n-of(k) = per-chapter.enumerate().filter(p => p.at(1) == k).len()
#let max-c = calc.max(..per-chapter)
#let min-c = calc.min(..per-chapter)
#let busiest = per-chapter.position(n => n == max-c)
#let arcs = (per-chapter.slice(0, 10).sum(), per-chapter.slice(10, 18).sum(), per-chapter.slice(18, 21).sum(), per-chapter.slice(21, 27).sum())

The matrix holds #topics.len() topic rows across the 27 topic
chapters and none unmapped, and that zero is the assert above, not
prose: each row's chapter field is looked up against the manifest ids
and a row naming an id no chapter carries stops the build instead of
rendering a stray bar. The service zero is asserted the same way, a
row naming a service chapter id stops the build, because the service
part's proof is the lane's checks, not the matrix. The distribution
stays deliberately flat.
#n-of(4) chapters carry 4 rows, #n-of(5) carry 5, the sparsest is
chapter #content-chapters.at(per-chapter.position(n => n == min-c)).num
with #min-c, and the busiest is chapter
#content-chapters.at(busiest).num with #max-c, so no arc
owns the ledger. The four arcs the audit plan drew hold
#arcs.at(0) rows across the language and llvm chapters 1 through 10,
#arcs.at(1) across the machine chapters 11 through 18,
#arcs.at(2) across the systems deep dives of chapters 19 through 21,
and #arcs.at(3) across the cloud chapters 22 through 27.

The strip splits every bar by cost. Dark is the
#topics.filter(r => not r.cost.starts-with("n/a")).len() rows that
carry a measured or cited number, a probe count, a timing ratio, a
page quota. Light is the #na-rows.sum() semantics and documentation
rows, the honest boundary the book refuses to dress up as a
measurement. The machine arc is the darkest,
#{ arcs.at(1) - na-rows.slice(10, 18).sum() } of #arcs.at(1) rows
measured, because those chapters assert behavior in compiled checks.
The light mass sits at both ends: semantics rows in the language
chapters, documentation-verified rows in the cloud arc,
#na-rows.slice(21, 27).sum() of #arcs.at(3) there, where the contract
is a fetched page rather than a running binary.

#diagram([the distribution strip: one bar per topic chapter in manifest order, the number above a bar is its topic count, dark is a row with a measured or cited cost, light is an n/a row, and the service chapters past 27 are proven by the lane, not counted here], length: 13pt, {
  let pitch = 0.85
  let bw = 0.6
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
  cdraw.line((0.5, y0), (23.3, y0), stroke: 0.5pt + luma(180))
  let div(x) = cdraw.line((x, y0 - 0.08), (x, 7.0), stroke: 0.5pt + luma(200))
  div(0.5 + 10 * pitch - 0.14)
  div(0.5 + 18 * pitch - 0.14)
  div(0.5 + 21 * pitch - 0.14)
  cdraw.content((4.75, 1.72), [the language and llvm, #linebreak() chapters 1 to 10], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((12.4, 1.72), [the machine, #linebreak() chapters 11 to 18], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((17.1, 1.72), [deep dives, #linebreak() chapters 19 to 21], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((22.0, 1.72), [the cloud, #linebreak() chapters 22 to 27], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.9, 0.25), [the arcs hold #arcs.at(0), #arcs.at(1), #arcs.at(2), #arcs.at(3) rows left to right, the machine arc the darkest, the cloud arc the lightest], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((25.1, 5.2), [past the strip, chapters 28 to 40: #linebreak() the service part, thirteen chapters #linebreak() proven by the lane's checks over #linebreak() the vehicle, no topic rows by assert], wrap: text.with(size: 6pt, fill: luma(100)))
})

== pinned sources

#let family-of(url) = {
  if url.starts-with("https://learn.microsoft.com/") { "learn.microsoft.com" }
  else if url.starts-with("https://llvm.org/") or url.starts-with("https://clang.llvm.org/") { "llvm.org" }
  else if url.starts-with("https://docs.kernel.org/") { "docs.kernel.org" }
  else if url.starts-with("https://man7.org/") { "man7.org" }
  else if url.starts-with("https://docs.aws.amazon.com/") { "docs.aws.amazon.com" }
  else if url.starts-with("https://docs.cloud.google.com/") { "docs.cloud.google.com" }
  else if url.starts-with("https://developer.hashicorp.com/") { "developer.hashicorp.com" }
  else if url.starts-with("https://raw.githubusercontent.com/") { "raw.githubusercontent.com" }
  else { "the rest" }
}
#let families = ("learn.microsoft.com", "llvm.org", "docs.kernel.org", "man7.org", "docs.aws.amazon.com", "docs.cloud.google.com", "developer.hashicorp.com", "raw.githubusercontent.com", "the rest")
#let fam-counts = families.map(f => sources.filter(s => family-of(s.url) == f).len())
#let dates = sources.map(s => s.accessed).sorted().dedup()
#let date-counts = dates.map(d => sources.filter(s => s.accessed == d).len())
#let distinct-urls = sources.map(s => s.url).sorted().dedup().len()
#let url-counts = sources.map(s => s.url).fold((:), (acc, u) => {
  acc.insert(u, acc.at(u, default: 0) + 1)
  acc
})
#let most-visited = calc.max(..url-counts.values())
#assert(date-counts.sum() == sources.len(), message: "date census lost rows")
#assert(fam-counts.sum() == sources.len(), message: "family census lost rows")

Every chapter ends with its own sources line and this section is all
of them rolled up: #sources.len() rows over #distinct-urls distinct
urls, a page two chapters consulted keeps two rows and rfc 9110 alone
carries five consults, one per service chapter that leaned on it. The
rows carry #dates.len() access dates,
one per verification pass: #dates.enumerate().map(p => "#date-counts.at(p.at(0)) rows on #p.at(1)").join(", "),
the 2026-09-12 pass that verified the book, the 2026-09-13 pass
the allocator wave added, the 2026-09-14 rows the capstone's sqlite
pages pinned, and the 2026-09-27 pass the service part rolled up at
its closeout. The host
census is computed the same way, and its counts are rows per family,
not fetches. Microsoft learn carries #fam-counts.at(0) rows, the win32 and
ucrt reference the compiled chapters call by name.
developer.hashicorp.com carries #fam-counts.at(6), the terraform
language and cli pages. The console guides split
#fam-counts.at(4) on docs.aws.amazon.com against
#fam-counts.at(5) on docs.cloud.google.com. The
#fam-counts.at(7) rows on `raw.githubusercontent.com` are provider
resource pages read at the pinned tags, `hashicorp/terraform-provider-aws`
v6.64.0 and `hashicorp/terraform-provider-google` v8.2.0, the recorded
workaround for a registry whose pages render nothing to a fetch. The
llvm family counts #fam-counts.at(1) across llvm.org and
clang.llvm.org, man7.org #fam-counts.at(3), docs.kernel.org
#fam-counts.at(2). The remaining #fam-counts.at(8) rows hold the c23
drafts at open-std.org, cppreference, the posix pages at
pubs.opengroup.org, the nist cloud definition, one intel prefetching
page, the github release indexes that date the pins, the
openpolicyagent docs, the allocator homes at jemalloc.net and the two
github.io pages, the marketing hosts: pricing serves from
aws.amazon.com, and one vpc pricing page serves from cloud.google.com,
the cited form because its redirect runs the reverse direction, and
the service part's tail: the rfc editor pages and the doi row behind
little's proof, the fips 180-4 page at csrc.nist.gov, the w3c trace
context recommendation, prometheus.io's exposition and histogram
pages, the singleflight source, the Unity and CMock release pages,
and sqlite.org, whose c3ref family the store chapter and the capstone
both consult.

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
  cdraw.content((16.9, 1.51), [provider resource pages at, #linebreak() the pinned tags, the registry, #linebreak() shells return no version string], wrap: text.with(size: 6pt, fill: luma(100)), anchor: "west")
})

Cloud documentation moved under this book six times while it was
verified, and each move is a register row rather than a silent
repair. Row cos-013: the terraform pages relocated, the releases and
settings urls 404 with the block references now under
`/language/block/`, and the provider registry's js shells return no
version string, so version truth routes through the github release
lists. Row cos-014: cloud.google.com urls 301 permanently to
docs.cloud.google.com, so the rows record the form actually fetched,
and the aws well-architected root renders nothing to a fetch, so its
pillars came from the marketing page and the dated framework welcome.
Row cos-015: three plan-era cloud run urls died, the traffic content
lives at rollouts-rollbacks-traffic-migration, and
`google_project_iam_member` lost its standalone page to the umbrella
page that documents all four iam resource flavors. Row cos-016: the
values references moved to `/language/block/variable` and
`/language/block/output`, locals and the mocks page moved with them,
and the old workspace-name sentence vanished from every page that
carried it, leaving the cli page's url-path-segment rule as the
surviving constraint. Row cos-017: three provider deprecations reshaped
the chapter 25 sample before it was written, the split security group
rules, the iam role policy split, the s3 bucket split. Row cos-018: the
aws budgets page answers only at budgets-managing-costs.html, the
-ing spelling, while the wrong form serves a title-only shell, three
more plan urls died, one compute pricing url 301s in the reverse
direction back to cloud.google.com, and loadability itself proved
fetcher-dependent, title-only under one fetcher and full under
another.

#callout("note", "version drift rule", [
  The pins this book froze: clang 23.1.1 on `x86_64-pc-windows-msvc`
  with `-std=c23` for every compiled sample, terraform 1.16.2
  (published 2026-09-09), hashicorp/aws 6.64.0 (2026-09-09), and
  hashicorp/google 8.2.0 (2026-09-08), all Latest at access
  2026-09-12. The compiler pin then drifted on this machine to
  23.1.2, announced 2026-09-22, and every gate stayed green under
  both because the pinned asserts ask for the c23 standard version
  and the major 23, not a patch number, the drift rule applied to
  the toolchain itself, with one exception the rule caught: chapter
  8's ir expectation carried a literal patch number in the emitted
  ident metadata, went red on the first verify under 23.1.2, and
  now pins the ident at the major. Cloud pages will move again: urls relocate, js shells
  replace documents, sentences vanish, redirects run both directions.
  Cite what you fetched, record what moved, and treat the version
  pins and access dates as the only durable facts. The
  #sources.len() rows behind the timeline are that record: when a
  future fetch disagrees with a row here, the row is what this book
  claimed and the date is when it was true.
])

sources: `coverage/topics.typ` and `coverage/sources.typ`, the two
arrays this page computes every number from, and
docs/audit/c-os-cloud.md, the drift register this chapter generalizes.
All #sources.len() source rows accessed #dates.join(" and "). Documentation-verified only: no terraform
binary in this corpus, nothing initialized, planned, or applied, and
this chapter ships no samples, its checks are the arithmetic above.
