#import "../../theme/lib.typ": callout, diagram, cdraw
#import "../manifest.typ": jsbook
#import "../coverage/keywords.typ": matrix
#import "../coverage/stdlib.typ": stdlib-coverage
#import "../coverage/sources.typ": sources

= appendices: coverage and sources

The coverage matrices are this book's audit trail. The 4.0 edition
keeps the book split at the language's own seams, chapters 1 through
10 the runtime with no build step, heap and profiler included, 11
through 20 the type layer, 21 and 22 the framework layer where vite
enters, 23 the capstone that runs every face of the engine, 24 these
appendices, and the matrices follow that split: every word the
grammar admits mapped to the chapter that teaches it, every library
family placed on its edition shelf with this runtime's verdict, and
the pins that freeze the whole thing in time. The build enforces
honesty from the other side: every chapter listing reads a real file
that an npm project in this repo executes, and this chapter counts
those projects' suites exactly rather than estimating them.

== keyword coverage

#let unmapped = matrix.filter(r => r.chapter == "unmapped").len()

#let chapter-label(id) = {
  if id == "unmapped" { return [unmapped] }
  let found = jsbook.chapters.find(c => c.id == id)
  [ch #found.num]
}

The census was recounted against the live lexical grammar page on
2026-09-13 and the strata held: 35 words reserved outright, 4
reserved in strict mode and module code, 7 reserved for the future,
and the 29 typescript contextual words that parse as keywords only
inside type position, 75 in all. Every word maps to a chapter:
#unmapped unmapped. The grammar words concentrate in part one, 36 of
the 46 plus the contextual `of`, 37 words in all, because they are
the runtime's own vocabulary, and the type words all land in part
two.

The exceptions carry the interesting facts. Switching lives in
chapter 16, the exhaustive switch is the book's whole treatment of
`case` and `switch`, and part one contains no switch at all. The
`in` guard and the `is` and `asserts` predicates sit there for the
same reason. `void` never executes, it is the checker's return
contract, taught with the two tops and two bottoms of chapter 13.
`enum` is future reserved in javascript and real runtime code in
typescript, so it waits for the emit chapter. And four words never
run anywhere in this book: `while`, `do`, `with`, and `package` are
grammar facts only, part one iterates with `for..of` and generator
pulls, `with` is an error in module code, and `package` never
appears. `break` and `continue` each execute exactly once, inside
the loop tests, chapter 5's pull count and chapter 2's table walk.

#diagram([the 75 words, where each stratum lands], length: 13pt, {
  cdraw.content((5.0, 9.1), [words], size: 6.5pt, fill: luma(100))
  cdraw.content((16.4, 9.1), [taught where], size: 6.5pt, fill: luma(100))

  let row(y, w, t, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((5.0, y + 0.7), w, size: 6pt)
    cdraw.content((16.4, y + 0.7), t, size: 6pt)
  }
  row(7.4, [part one, 37], [the runtime words, ch 1-8], false)
  row(5.6, [lexical, 12], [ch 2, declarations, equality], true)
  row(3.8, [iteration, 8], [ch 5, loops, generators, `delete`], false)
  row(2.0, [objects, errors, 17], [ch 3, 4, 6, and 7], true)
  row(0.2, [type words, 38], [part two, ch 11-20], false)

  cdraw.line((11.4, 0.2), (11.4, 8.8), stroke: luma(220))
  cdraw.content((11.6, -0.8), [zero words unmapped, the build keeps it that way], size: 6.5pt)
})

#table(
  columns: (auto, auto, auto),
  inset: 4pt,
  table.header([*word*], [*kind*], [*taught in*]),
  ..matrix.map(r => ([#r.word], [#r.kind], chapter-label(r.chapter))).flatten(),
)

== stdlib coverage

Component families against edition shelves, with the status column
carrying this runtime's verdict row by row. ES2026 was approved
2026-06-30 as the seventeenth edition with seven features: this node
runs five, ships the json half, and lacks one outright, and the
matrix says which is which. Temporal runs the other direction, stage
4 and slated for the es2027 edition, yet fully present and unflagged
here, typed through the `esnext.temporal` fragment ahead of any
edition library.

#diagram([families against shelves, the status ledger], length: 13pt, {
  cdraw.content((5.4, 9.1), [family], size: 6.5pt, fill: luma(100))
  cdraw.content((16.6, 9.1), [status], size: 6.5pt, fill: luma(100))

  let row(y, f, s, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((5.4, y + 0.7), f, size: 6pt)
    cdraw.content((16.6, y + 0.7), s, size: 6pt)
  }
  row(7.4, [arrays, objects, keyed], [ch 5 and ch 8, taught in full], false)
  row(5.6, [es2026, five of seven], [covered, one absent, one half], true)
  row(3.8, [Temporal, es2027 slated], [runtime yes, fragment types it], false)
  row(2.0, [`Math.sumPrecise`], [absent, pinned by test], true)
  row(0.2, [the json half], [`rawJSON` yes, double from `parse`], false)

  cdraw.line((11.8, 0.2), (11.8, 8.8), stroke: luma(220))
  cdraw.content((11.6, -0.8), [the status column is the honesty ledger], size: 6.5pt)
})

#table(
  columns: (1.6fr, auto, 1.4fr),
  inset: 4pt,
  table.header([*component family*], [*chapter*], [*status*]),
  ..stdlib-coverage.map(r => ([#r.component], chapter-label(r.chapter), [#r.status])).flatten(),
)

== pinned sources

Every chapter ends with its own sources line naming the official
sections consulted while writing it. The book level pins carry three
dates: the 1.0 fetches of 2026-09-08, the 2.0 re-probe of
2026-09-13, when the toolchain was measured again and the new
material, the edition approval, the temporal proposal status, and
the release notes, was fetched, and the 4.0 fetches of 2026-09-21
for the framework layer, react 19.3.0, svelte 5.57.1, vite 8.3.0,
and the import maps specification. The four projects' suites,
counted at this edition and not estimated: `javascript/samples`,
part one, 133 tests in 11 suites with no build step,
`javascript/tssamples`, part two, 105 tests in 10 chapter suites,
checked and emitted by `tsc` before node runs them,
`javascript/fwsamples`, part three, 53 tests, 37 for the react
chapter and 16 for the svelte chapter, unit tests over the `tsc`
emit and smokes over five vite builds, and `javascript/capstone`,
63 tests in 10 suites, 28 plain against the `.mjs` layer, 21 web
against the microfrontend, and 14 typed through the facade.
Together 354 tests, and the repo's `make verify-ts` runs all four
projects plus the repertoire suite.

#diagram([the pins as one dated discipline], length: 13pt, {
  cdraw.content((11.6, 7.6), [the pin discipline], size: 6.5pt, fill: luma(100))
  cdraw.content((6.0, 5.4), [2026-09-08, the 1.0 fetches], size: 6.5pt)
  cdraw.content((16.6, 5.4), [2026-09-13, the 2.0 re-probe], size: 6.5pt)
  cdraw.line((0.8, 4.6), (22.2, 4.6), stroke: luma(100), mark: (end: ">"))
  for x in (6.0, 16.6) { cdraw.line((x, 4.4), (x, 4.8), stroke: luma(100)) }
  cdraw.content((6.0, 3.6), [`typescript` 7.0.2, #linebreak() `node` 26.3.0], size: 6pt)
  cdraw.content((16.6, 3.6), [drift recorded in the table, #linebreak() never a silent rewrite], size: 6pt)
  cdraw.content((11.6, 1.6), [the table doubles as the documentation changelog], size: 6.5pt)
})

#table(
  columns: (1.6fr, 2.2fr, auto),
  inset: 4pt,
  table.header([*topic*], [*url*], [*accessed*]),
  ..sources.map(s => ([#s.topic], [#s.url], [#s.accessed])).flatten(),
)

#callout("note", "version drift rule", [
  The 1.0 pins were fetched 2026-09-08 against typescript 7.0.2 on
  windows with node 26.3.0, and the 2.0 edition re-probed the same
  toolchain on 2026-09-13, node v26.3.0 with V8 14.6.202.34-node.20
  and npm 12.0.2. The projects pin `typescript` at `^7.0.2` with
  `es2025` targets plus two fragments, `esnext.array` and
  `esnext.temporal`. The drift worth naming: `tsc` 7.0.2 knows no
  es2026 at all, `--target es2026` and `--lib es2026` both answer
  TS6046 and the list it prints ends at `es2025` then `esnext`, so
  the runtime is ahead of its checker's edition vocabulary and the
  fragments are the bridge. Re-verified 2026-09-30 under the corpus
  version currency law, which rides the newest installable build of
  every vendor, nightlies excepted: 7.0.2 is still the newest
  typescript on the npm dist-tags, 7.1 exists only as nightly dev
  builds with the es2026 target and lib committed for its beta, and
  both TS6046 answers reproduced verbatim on that date, so the pin
  stands and moves the day a newer installable build ships. Temporal
  is stage 4, slated for the
  es2027 edition, shipped unflagged in node 26.3.0, and absent from
  `@types/node` 26, so without the fragment a file using it fails
  TS2503. Decorators are still stage 3, the default in 7.0.2 with no
  flag. On this runtime `Math.sumPrecise` is `undefined` and
  `JSON.parse` takes two arguments, so `JSON.rawJSON` pins digits on
  the way out while parsing the same text returns the double. The
  4.0 framework wave re-probed its layer 2026-09-21, react 19.3.0,
  svelte 5.57.1, the svelte vite plugin 7.3.0, and vite 8.3.0,
  all measured on the projects' installed trees, and the browser
  facts are node-measured, no browser ran in the suite. If an
  upstream page changes, the delta gets recorded here rather than
  silently rewriting chapters, so this table is also the book's
  changelog for documentation movement.
])
