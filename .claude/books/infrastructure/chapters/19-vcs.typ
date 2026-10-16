#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= version control at scale

The last storage engine in the book is the one holding the book's own
source. Source control is a write-ahead log of changes, a
content-addressed blob store, and derived read structures built off
the log, three shapes this book has already built once each: the log
in #xref-to("infrastructure", "sqlite-wal"), the forward-only version
sequence in #xref-to("infrastructure", "migrations"). This chapter
builds them once more at the scale where git gives out, reads one
system end to end, Anthropic's Scion, and carries its data model in a
worked sample, an in-memory changeset store under
`samples/ch19` held to the same suite discipline as every other
engine chapter.

== git's object model, in brief

Git keeps four object kinds, every one content-addressed. A blob is
file bytes. A tree maps names to blob and tree digests, one whole
directory snapshot. A commit points at one tree plus parent ids.
Refs are the only mutable thing in the model, names pointing at
commits. A clone carries all four kinds for the entire history, and
that completeness is the design: diff, blame, log, and checkout all
compute offline because the whole past is local.

This corpus rides that model on every build. The ci lanes of
#xref-to("go", "shipit") and #xref-to("csharp-net", "shipit") start
each Actions job with a checkout, and at one job per push the
checkout is noise. The counts in the next section are what the same
checkout becomes when most of the writers are agents.

== the failure, measured

Anthropic's engineering post on Scion supplies the numbers, and every
one below is transcribed from its bytes. Merged changes grew from
around 2,500 per day in May 2026 to over 30,000 per day by September,
and the post calls the latent demand for merging code practically
infinite, so it expects no slowdown. Against that write rate sit four
more counts: the history of the main branch alone is almost 100 gb, a
compressed working copy is over 25 gb, ci performs on the order of 25
million code checkouts per day before counting developer
environments, agent sandboxes, and research jobs, and fetched naively
that is over 600 pb of git traffic per day.

#diagram([one day of ci checkouts against one repo, priced the way a git clone pays], length: 13pt, {
  cdraw.rect((0.0, 6.8), (7.2, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 7.85), [25 million checkouts], size: 6.5pt)
  cdraw.content((3.6, 7.2), [per day, ci alone], size: 6pt)

  cdraw.rect((0.0, 4.6), (7.2, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((3.6, 5.65), [almost 100 gb history], size: 6.5pt)
  cdraw.content((3.6, 5.0), [over 25 gb compressed copy], size: 6pt)

  cdraw.line((3.6, 4.6), (3.6, 3.5), stroke: luma(100), mark: (end: ">>"))

  cdraw.rect((0.0, 2.1), (7.2, 3.5), fill: luma(205), radius: 0.02)
  cdraw.content((3.6, 3.15), [over 600 pb per day], size: 6.5pt)
  cdraw.content((3.6, 2.5), [if fetched naively], size: 6pt)

  cdraw.content((15.0, 6.6), [the workarounds, all used], size: 6.5pt)
  cdraw.content((15.0, 5.8), [shallow clones], size: 6pt)
  cdraw.content((15.0, 5.0), [sparse checkouts], size: 6pt)
  cdraw.content((15.0, 4.2), [promisor remotes], size: 6pt)
  cdraw.content((15.0, 3.4), [mirrors, several hundred at peak], size: 6pt)
  cdraw.content((15.0, 2.6), [snapshot seeds in blob storage], size: 6pt)
  cdraw.content((15.0, 1.5), [each bought time, none held], size: 6pt)
})

The workarounds ran out together. The post reports using all of them,
shallow clones, sparse checkouts, promisor remotes, internal mirrors,
repository snapshots kept in blob storage, with several hundred
internal git mirrors at peak. Mirrors grew harder to operate as the
merge rate rose, seeds fell further from the tip of main between
refreshes, and history-dependent work like diff and blame kept needing
more care on partial clones.

The post's diagnosis is the one to keep. The company was running git
as a centralized system with one authoritative copy, while nearly all
of its clients were agents and jobs that are online by definition. The
properties that make git excellent for distributed offline work were
the same properties undermining scale, so the design question became:
what does source control look like when the client is always online?

== the changeset, a wal entry

Scion's unit of work is the changeset, an entry in a write-ahead log.
It carries what a git commit carries except the tree pointer: a list
of the files that changed relative to its first parent, plus
content-addressed pointers to the compressed file contents in blob
storage. Changesets are created server-side and are available
everywhere instantly, and accepting one touches nothing global, no
packfile to build, no lock, no cross-server coordination, no ref to
move. The post's footnote is candid about the first-parent choice:
in a trunk-based monorepo people only ask about history and blame on
the main line, so recording changes against the first parent gives up
nothing anyone misses.

#diagram([what a commit points at, git on the left, scion on the right], length: 13pt, {
  cdraw.content((5.2, 8.9), [git], size: 6.5pt)
  cdraw.content((16.8, 8.9), [scion], size: 6.5pt)
  cdraw.line((0.6, 8.3), (10.0, 8.3), stroke: luma(220))
  cdraw.line((11.0, 8.3), (21.5, 8.3), stroke: luma(220))

  cdraw.rect((2.2, 6.9), (8.2, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 7.4), [a commit], size: 6.5pt)

  cdraw.line((5.2, 6.9), (5.2, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((1.2, 4.7), (9.2, 5.9), fill: luma(205), radius: 0.02)
  cdraw.content((5.2, 5.45), [one tree], size: 6pt)
  cdraw.content((5.2, 4.95), [every file and dir, by name], size: 6pt)

  cdraw.line((5.2, 4.7), (5.2, 3.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((2.2, 2.5), (8.2, 3.7), fill: luma(235), radius: 0.02)
  cdraw.content((5.2, 3.1), [blobs], size: 6pt)

  cdraw.rect((12.8, 6.9), (20.8, 7.9), fill: luma(235), radius: 0.02)
  cdraw.content((16.8, 7.4), [a changeset], size: 6.5pt)

  cdraw.line((16.8, 6.9), (16.8, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((11.8, 4.7), (21.8, 5.9), fill: luma(205), radius: 0.02)
  cdraw.content((16.8, 5.45), [the changed paths only], size: 6pt)
  cdraw.content((16.8, 4.95), [measured against the first parent], size: 6pt)

  cdraw.line((16.8, 4.7), (16.8, 3.7), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((13.8, 2.5), (19.8, 3.7), fill: luma(235), radius: 0.02)
  cdraw.content((16.8, 3.25), [blob digests], size: 6pt)
  cdraw.content((16.8, 2.8), [content-addressed], size: 6pt)

  cdraw.content((5.2, 1.5), [one snapshot per commit], size: 6pt)
  cdraw.content((16.8, 1.5), [one delta per commit, a wal entry], size: 6pt)
})

The sample store is that data model made small, one mutex in place of
spanner, a map in place of blob storage:

#listing("infrastructure/samples/ch19/store.go", first: 33, last: 69, caption: [change, changeset, and put: sha256 over the bytes, stored once, defensive copy in and out])

`Put` is the whole addressing scheme. The digest is the sha256 of the
content, identical content stores once, and the bytes are copied on
the way in and on the way out. Immutability is what every cache tier
later in this chapter lives on, in the post's words: "a piece of data
never changes once it's stored, and any server can cache it without
checking with the others."

#listing("infrastructure/samples/ch19/store.go", first: 83, last: 104, caption: [commit: validate the parent, sort by path, reject duplicates and unstored digests, append with a sequential id])

`Commit` validates, canonicalizes, appends. The parent must exist, the
changes come out sorted by path, a duplicate path is a rejection,
every digest must already be stored, and ids run sequentially from 1,
the same gapless forward-only discipline the migration runner enforces
in #xref-to("infrastructure", "migrations"). The append is the wal
property verbatim: the cost of a commit scales with the size of the
change, never with the size of the repository. No tree is materialized
anywhere, not on commit, not on read.

== refs as compare and swap

Refs are the one mutable thing in git and the one piece of global
state in Scion, which is why the post discourages them: global state
that every server has to agree on is a looming scaling problem, so the
development lifecycle keeps to the main ref and release branches.
Creating and fetching changesets never involves a ref, so moving one
is a compare-and-swap on a single spanner row, off the hot path
entirely.

#listing("infrastructure/samples/ch19/store.go", first: 116, last: 131, caption: [update ref: absent plus expect null creates, a mismatch reports the observed value])

An absent ref combined with `expect == NullID` creates it, anything
else compares. A mismatch returns a `*RefConflict` carrying the
observed `Have`, and that field is the entire retry protocol: the
caller re-attempts the swap with the reported value instead of
guessing. The race test pins the contract:

#listing("infrastructure/samples/ch19/refs_test.go", first: 139, last: 186, caption: [8 racers, one cas expectation, exactly one winner, every loser told the winner's value])

Eight goroutines race one expectation, exactly one wins, 7 read
conflicts, and every conflict reports the winner's value, which is
what lets a loser retry without a re-read. The mutex stands in for the
spanner row, and the guarantee is the same one a single-row cas gives
at fleet size.

#callout("pitfall", "retry with the reported value, never the cached one", [
  A retry that reuses its own stale expectation conflicts again, so a
  loop that never adopts the conflict's `Have` spins forever. The
  sample's `TestCASRetryWithReportedHave` pins exactly this path:
  second call with the old expectation fails, third call with
  `conflict.Have` lands. The conflict type exists to carry that field,
  an error string without `Have` forces every caller back to a read
  that can race again.
])

== derived data, blame and path history

A changeset records only what changed, so on its own it cannot answer
who last touched a path or which changesets touched it. Scion derives
those answers from the log: dedicated structures for file blame and
path history, and skip lists over the commit graph. Each type of
derived data is defined recursively, its value at a changeset computed
from its values at that changeset's parents, each type computed
eagerly or deferred as needed, and none of it visible to clients, so
the internals can be reoptimized without touching a single client.
Copy detection and path-based file search joined later as new derived
types, and the post reports adding new types this way more than once
as the system grew.

The sample derives the same three answers from the same recursion:

#listing("infrastructure/samples/ch19/query.go", first: 3, last: 30, caption: [chain walks first parents to the root, snapshot replays oldest to newest, each change overwriting its path])

`chain` walks first parents to the root, and `Snapshot` replays that
chain from the oldest entry forward, each change overwriting its
path's digest. The resulting map is the working copy: the state a
checkout would materialize, computed from the log, stored nowhere.

#listing("infrastructure/samples/ch19/query.go", first: 32, last: 63, caption: [path history names every changeset that touched a path, newest first, blame assigns each path its last writer])

`PathHistory` walks newest first and names every changeset that
touched a path. `Blame` assigns each path the id of its last writer.
Every expected value in the suite is counted by hand from the fixture,
the oracle discipline of #xref-to("infrastructure", "testing"):

#listing("infrastructure/samples/ch19/query_test.go", first: 138, last: 157, caption: [the blame oracle: 3 snapshots over a 4 changeset chain, each map derived from the fixture by eye])

#callout("note", "path granularity, on purpose", [
  The sample's blame works at path granularity with whole-file
  digests, so every line of a path blames to that path's last writer.
  Line-level blame needs the blob diffed against its parent, and that
  is exactly the work Scion pushes into derived data beside the log
  rather than into the changeset itself. The sample also keeps the
  recursion and drops the increment: every query walks the whole
  chain, where Scion's derived structures are maintained per
  changeset. The recursion is the design, the index is the
  optimization, and the chapter's sample stops at the design.
])

== three tiers, one rpc shape

Moving file contents is the data-intensive half, and Scion's answer is
a cache hierarchy in front of the storage of record. The scn client
talks over a socket to scion-daemon, one per node, which stores
objects for the whole node, since jobs on one node reuse most of the
same objects, and starts from a periodically refreshed snapshot. The
daemon talks only to the tree and blob cache servers in its region,
scion-cache, which stream objects straight from memory in the disk
format the daemon consumes, so a cache spends no time computing a
client's missing objects and none on delta compression. A cache
missing an object asks the authoritative scion-servers, which read
from spanner or cloud storage as needed. All three tiers answer
identical rpcs, so the client never needs to know the cache topology,
and the tiering is strictly enforced anyway to isolate failure
domains: a failing regional cache must never be able to overwhelm the
authoritative servers and take the whole system down.

#diagram([the tier ladder, one rpc shape at every hop, misses go up exactly one tier], length: 13pt, {
  cdraw.rect((1.0, 7.0), (9.0, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 7.75), [scn client], size: 6.5pt)
  cdraw.content((5.0, 7.3), [socket, asks for trees and blobs], size: 6pt)

  cdraw.line((5.0, 7.0), (5.0, 6.0), stroke: luma(100), mark: (end: ">>"))

  cdraw.rect((1.0, 5.0), (9.0, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 5.75), [scion-daemon, one per node], size: 6.5pt)
  cdraw.content((5.0, 5.3), [node-wide objects, refreshed snapshot], size: 6pt)

  cdraw.line((5.0, 5.0), (5.0, 4.0), stroke: luma(100), mark: (end: ">>"))

  cdraw.rect((1.0, 3.0), (9.0, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 3.75), [scion-cache, one per region], size: 6.5pt)
  cdraw.content((5.0, 3.3), [streams from memory, disk format], size: 6pt)

  cdraw.line((5.0, 3.0), (5.0, 2.0), stroke: luma(100), mark: (end: ">>"))

  cdraw.rect((1.0, 1.0), (9.0, 2.0), fill: luma(205), radius: 0.02)
  cdraw.content((5.0, 1.75), [scion-server, authoritative], size: 6.5pt)
  cdraw.content((5.0, 1.3), [spanner and cloud storage], size: 6pt)

  cdraw.content((16.0, 5.6), [identical rpcs at all three], size: 6pt)
  cdraw.content((16.0, 4.8), [a miss asks one tier up only], size: 6pt)
  cdraw.content((16.0, 4.0), [over 99 percent hits per tier], size: 6pt)
  cdraw.content((16.0, 3.2), [no long-lived state], size: 6pt)
  cdraw.content((16.0, 2.4), [no packfiles anywhere], size: 6pt)
})

The protocol change that makes the hierarchy cheap is the negotiation
shape. Git's fetch negotiates haves: the client announces what it
holds, the server computes a packfile against that, one
multi-gigabyte response that cannot resume. Scion's scn client
negotiates wants: starting from a root tree, the client checks its
local store for missing trees and requests them recursively, then
repeats for blobs. Every request names one immutable object, so any
cache at any tier can answer it, and the fetch resumes wherever it
stopped because there is no single response to lose. Sparse checkouts
fall out of the same shape, the client just does not ask for trees
outside its scope, and virtualized checkouts materialize files on
demand through the same mechanism.

The working copy itself is optional. A ci job that needs the diff
between a commit and its merge base asks the server for it, and write
workloads can function entirely through the api, the post's example
being automated bisect and revert pipelines that would be impractical
if each needed its own repository copy. Permissions live at directory
level inside the one monorepo, and the review tooling expresses
semantic constraints on approvals, separating comment-only changes
from sensitive logical ones, so human reviewers spend attention where
it matters.

The workflow conclusion is the sharpest break in the post. A merge
queue serializes merges behind a global repository lock, and at agent
scale that lock is the bottleneck: hundreds or thousands of changes
can merge while tests are still running. Anthropic could not
replicate that lock at its merge rate, so it invests in post-merge
and pre-deploy automated testing instead, accepts that concurrent
changes conflict, and reports that Claude fixes those conflicts
faster than humans can even identify them. The per-push ci gates of
#xref-to("go", "shipit") are the human-scale form of the same
question, and the post's answer at fleet scale is to test after the
merge and gate the deploy.

== the migration, measured

The results, every count from the post's bytes. The Scion
infrastructure footprint is 200x smaller than the git mirroring
infrastructure it replaced, in cpu and memory terms. Every tier holds
a cache hit rate over 99 percent with no long-lived state. Ci and
research jobs check out code two orders of magnitude faster, in the
post's own phrasing "in seconds rather than minutes", and the bytes
never print a literal 100x for checkouts, so neither does this
chapter. Ci alone realized a 25 percent cpu capacity win. Neither
clients nor caches perform repository maintenance, there are no
packfiles, so there is nothing to gc.

The build is itself a data point about agent-scale engineering. 7
people built Scion, the Antique code review tool, and half a dozen
related systems, and fully migrated the monorepo off git in 5 months,
while the volume of code merged per day grew 10x under them. Asked to
rewrite the earlier handwritten git-to-Scion ingestion pipeline, an
internal model snapshot produced a version on the first try that
consumed 20x less memory and ran 4x faster while preserving the
ingestion-ordering invariants. The post is equally plain about the
division of labor: agents wrote the code, and the engineers supplied
the design-level judgment, very often the judgment to tell Claude no
when it over-engineered in response to hypothetical concerns from
adversarial review.

== piper, sapling, and what oss can adopt

Google hit the same wall a decade earlier and published the answer.
Potvin and Levenberg's cacm article, 59(7), july 2016, describes
Piper: one repository of roughly 1 billion files with a history of
roughly 35 million commits, 86 tb uncompressed, shared by more than
25,000 developers who commit 16,000 changes on a typical workday
while automated systems commit another 24,000. No commercial or open
source version-control system could hold that scale in one
repository, so Piper runs on standard Google infrastructure,
originally bigtable, now spanner, distributed over 10 data centers
and kept consistent with paxos. Developers work in CitC, cloud
storage under a fuse file system, where an average workspace holds
fewer than 10 files against a seamless view of the whole codebase,
and over 80 percent of Piper users work that way. Trunk-based
development, one main line, review before commit: Scion holds every
one of these positions, and the post names Piper and Sapling as the
prior art it built on.

Meta's Sapling, open sourced 2022-11-15 by Goode and Bolin, attacked
the client first: 10 years of work that started as an extension to
Mercurial, now serving an internal repository with tens of millions
of files, tens of millions of commits, and tens of millions of
branches. Two of its ideas reappear in Scion nearly whole. Lazy
history, a clone downloads almost none of it, because three-quarters
of the 5.5 gb Linux kernel repo is history, with the segmented
changelog shipping the shape of the commit graph in a few megabytes,
ancestry queries in o(number-of-merges) time, and file log and blame
in o(log n) instead of o(n). And the working copy, virtual or sparse:
a virtual file system that materializes files on first access, plus
org-committed sparse profiles so thousands of engineers share one
shifting subset of the repo without configuring it themselves. That
first release open sourced the client only, the server and the
virtual file system stayed internal.

The post closes with what transfers today. Scion is no git
replacement for general use, it only pays off at truly enormous
monorepos with tens of thousands of engineers or swarms of agents,
and adopting it means migrating review, search, and ci along with the
vcs, which is why Anthropic shared the design instead of shipping a
product. Inside git the ideas still apply: a git server does not have
to work the way a git client does, server architectures exist that
scale much better, forges can expose the full source-control query
surface as server-side rpcs, perhaps standardized across forges,
negotiation can become want-shaped, and the sparse and shallow
features can be made to compose. The post expects this class of
problems to become commonplace within 6 to 12 months. The checkout at
the top of every Actions job is where it arrives first.

#callout("verify", "the store is pinned by its suite", [
  The sample carries 31 test functions across 4 files, 7 in
  store_test.go, 8 in changeset_test.go, 8 in refs_test.go, 8 in
  query_test.go, green under `go vet` and `go test -race` run
  2026-10-15. The counts are measured from the live tree, and the
  suite keeps this book's oracle discipline: every expected digest,
  snapshot, path history, and blame value is derived from the fixture
  by hand, never harvested from output.
])

sources: Anthropic engineering, "Redesigning source control at
Anthropic", published 2026-10-13,
https://www.anthropic.com/engineering/redesigning-source-control,
accessed 2026-10-15. Potvin and Levenberg, "Why Google Stores Billions
of Lines of Code in a Single Repository", cacm 59(7), july 2016,
https://cacm.acm.org/practice/why-google-stores-billions-of-lines-of-code-in-a-single-repository/,
accessed 2026-10-15. Goode and Bolin, "Sapling: Source control that's
user-friendly and scalable", published 2022-11-15,
https://engineering.fb.com/2022/11/15/open-source/sapling-source-control-scalable/,
accessed 2026-10-15. All three cached verbatim under `ref/scion/`
with sha256 receipts in its README. Absent from the bytes and
therefore from this chapter: any literal checkout multiplier beyond
"two orders of magnitude", any scion fleet size, and any per-tier
cache cost, the post gives none.
