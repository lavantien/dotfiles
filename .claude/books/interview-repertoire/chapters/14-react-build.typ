#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= react build: a listing page, test driven

This is the book's flagship exercise: a listing page built against
a public api, test driven, then a virtual dom written from scratch
in plain javascript. The public api is jsonplaceholder, and the
suite runs offline against a verbatim capture of
`/posts?userId=1` taken 2026-09-10, with an `npm run live` script
that re-runs the same assertions against the network on demand.
The red-green beats below are the actual sequence the workspace
went through.

== beat one: red, the page does not exist [TDD]

The first commit is the test file alone: render `ListingPage` from
api data, one card per post, a count attribute, an error state, an
empty state, and a cache that hits the fixture url once. Run
against nothing, it fails to even import:

#snippet("node --test src/listing/*.test.js\nError [ERR_MODULE_NOT_FOUND]: Cannot find module '.../listing.js'", lang: "js")

#diagram([the honest red: the test file alone fixes the contract], length: 13pt, {
  // beat one as a timeline: the test lands, the run fails on import, the seam answers
  cdraw.line((2.5, 7.6), (2.5, 1.4), stroke: luma(100), mark: (end: ">"))
  for (y, title, sub) in (
    (7.2, "test file committed alone", "assertions fix the contract"),
    (4.6, "node --test", "cannot find module 'listing.js'"),
    (2.0, "api.js answers the import", "the fetch seam, beat two begins"),
  ) {
    cdraw.circle((2.5, y), radius: 0.1, fill: luma(60))
    cdraw.line((2.65, y), (8.4, y), stroke: luma(180))
    cdraw.content((14.0, y), [#title], size: 6.5pt)
    cdraw.content((14.0, y - 1.15), [#sub], size: 6pt)
  }
})

That is the honest red. The api contract the test fixes in place,
a fetch seam plus a one-slot cache, is the second file:

#listing("interview-repertoire/samples/ch12-react/src/listing/api.js", first: 5, last: 30, caption: [the injectable fetch, the deduping cache, failure eviction])

== beat two: green, three states as early returns [TDD]

The minimal component that passes is three early returns, error,
empty, content, and the content is a mapped card list:

#listing("interview-repertoire/samples/ch12-react/src/listing/listing.js", first: 7, last: 31, caption: [the page and the card, data in, markup out])

#diagram([green is three early returns and a mapped card list], length: 13pt, {
  // the render path: error, empty, content, each an early return to its own markup
  let box(x0, y, x1, t, fill: luma(235)) = {
    cdraw.rect((x0, y), (x1, y + 0.8), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, y + 0.4), [#t], size: 6.5pt)
  }
  box(1.2, 6.1, 4.2, "render", fill: luma(245))
  box(5.6, 6.1, 10.0, "error?")
  box(5.6, 3.7, 10.0, "empty?")
  box(5.6, 1.3, 10.0, "content", fill: luma(245))
  box(12.8, 6.1, 17.6, "error card", fill: luma(245))
  box(12.8, 3.7, 17.6, "empty card", fill: luma(245))
  box(12.8, 1.3, 17.6, "card list", fill: luma(245))
  cdraw.line((4.2, 6.5), (5.6, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.0, 6.5), (12.8, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.4, 6.95), [yes], size: 6pt)
  cdraw.line((7.8, 6.1), (7.8, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.6, 5.3), [no], size: 6pt)
  cdraw.line((10.0, 4.1), (12.8, 4.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.4, 4.55), [yes], size: 6pt)
  cdraw.line((7.8, 3.7), (7.8, 2.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.6, 2.9), [no], size: 6pt)
  cdraw.line((10.0, 1.7), (12.8, 1.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((20.4, 5.4), [early returns], size: 6pt)
  cdraw.content((20.4, 4.2), [nesting-free], size: 6pt)
  cdraw.content((9.0, 0.4), [same user twice: one flight], size: 6pt)
})

The loader contract the test encodes, data on success and `{error}`
on failure, is the shape a real data layer returns to a boundary.
All five tests pass on this file, including the one that matters
most for the interview story: two loads of the same user hit the
network once, which is the request cache of
#xref-to("repertoire", "react-state") earning its keep inside a
component test.

#callout("verify", "the fixtures are real", [
  The ten posts under `src/listing/fixtures/posts.json` are the
  live response from `https://jsonplaceholder.typicode.com/posts?userId=1`,
  fetched 2026-09-10, byte for byte. The live script runs the same
  render assertions against the endpoint, and it passed the day
  the fixture was captured. Offline suite, online proof, one file
  apart.
])

== beat three: the virtual dom from scratch [TDD]

The second half of the exercise drops react entirely. `h` builds
plain objects, `renderHost` mounts them on an in-memory host whose
shape mirrors what a real renderer targets, and `diff` walks old
against new producing patch ops:

#listing("interview-repertoire/samples/ch12-react/src/vdom/vdom.js", first: 5, last: 41, caption: [vnodes as data, function components expanding, keys living on the host node])

#diagram([h builds vnodes, diff emits ops, the host applies the change], length: 13pt, {
  // the pipeline: plain trees in, minimal op set out, keyed moves not rewrites
  let stage(x0, x1, t) = {
    cdraw.rect((x0, 5.2), (x1, 6.2), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 5.7), [#t], size: 6.5pt)
  }
  stage(1.2, 4.4, "h()")
  stage(5.6, 9.6, "diff")
  stage(10.8, 15.6, "ops")
  stage(16.8, 21.0, "apply")
  cdraw.line((4.4, 5.7), (5.6, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.6, 5.7), (10.8, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.6, 5.7), (16.8, 5.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((2.8, 4.6), [vnodes as data], size: 6pt)
  cdraw.content((7.7, 4.6), [old vs new], size: 6pt)
  cdraw.content((13.2, 4.6), [the patch ops], size: 6pt)
  cdraw.content((18.9, 4.6), [host mutations], size: 6pt)
  cdraw.content((13.2, 3.4), [setText, setProp], size: 6pt)
  cdraw.content((13.2, 2.2), [insert, remove, move], size: 6pt)
  cdraw.content((19.3, 3.4), [keys turn], size: 6pt)
  cdraw.content((19.3, 2.2), [into moves], size: 6pt)
})

#listing("interview-repertoire/samples/ch12-react/src/vdom/vdom.js", first: 43, last: 99, caption: [the diff: props, positional children, keyed children])

The tests are where the virtual dom claims become numbers: a text
change is exactly one patch, a prop change exactly one setProp,
and the node count before and after an insert or remove is
counted, text nodes included. The keyed reorder test is the one
that earned its keep, because the first implementation diffed
keyed children positionally, which rewrites content instead of
moving nodes, exactly the bug keys exist to prevent. The fixed
diffKeyed emits drop, append, move, then per-pair diffs at final
positions:

#listing("interview-repertoire/samples/ch12-react/src/vdom/vdom.js", first: 102, last: 124, caption: [keyed diff: drop vanished keys, append new ones, reorder, diff pairs at final indexes])

Say the summary out loud, because it is the answer to the original
question: a virtual dom is a diff engine over element trees, its
value is paying dom mutations only for real changes, and keys are
the identity hint that turns rewrites into moves.

sources: jsonplaceholder.typicode.com, fixture captured 2026-09-10.
Verified by `npm run verify` under node 26.3.0, 5 tests in
`src/listing`, 8 in `src/vdom`, plus the on-demand live script
which passed against the network the same day.
