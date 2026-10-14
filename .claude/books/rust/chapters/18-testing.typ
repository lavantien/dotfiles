#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= testing and idioms

Rust ships its test harness in the toolchain: `#[test]` fns compiled
under `cargo test`, a builtin runner with filters and parallelism,
and assert macros that print diffs. This chapter covers the attribute
set and its exact semantics, the doc test fence format, the bench
discipline this corpus uses since criterion is a dependency and the
book has none, and closes with the idiom roundup, the conventions
every chapter of this book has been following. The corpus's own
runner contract sits underneath: samples print `ok N name` lines and
`tools/run-rust-samples.ps1` counts them, red on any failure or a
file with zero checks, chapter 16 showed the layout, this chapter
shows the semantics.

== the attributes and their meanings

`#[test]` marks a test function, `#[should_panic]` inverts pass and
failure, `expected = "..."` narrows it to panics whose message
contains the text, `#[ignore = "reason"]` skips unless explicitly
requested with `--ignored`, and since 1.28 a test can return
`Result<(), E: Debug>` so `?` replaces unwrap chains. All of it
compiles inert under the corpus runner, plain `rustc` without
`--test`, the attribute-marked fns simply have no symbols, measured
by this file compiling and running:

#listing("rust/samples/src/Ch18/TestAttributes.rs", first: 15, last: 38, caption: [all four attribute forms plus the result shape])

`#[should_panic]` semantics are worth seeing once from the inside
rather than trusting the label. The harness catches the unwind and
checks the message, `catch_unwind` has been stable since 1.9, and the
sample rebuilds the rule by hand, including the two failure cases
the harness rejects: a panic whose text misses the expectation, and
no panic at all:

#listing("rust/samples/src/Ch18/TestAttributes.rs", first: 43, last: 58, caption: [should_panic rebuilt, catch_unwind, payload downcast, substring match])

#listing("rust/samples/src/Ch18/TestAttributes.rs", first: 60, last: 111, caption: [the semantics run live, both failure modes proven to fail])

The assert macros are the vocabulary inside every test: `assert!`
for a condition, `assert_eq!` and `assert_ne!` for values, each
taking format arguments so the failure message carries the actual
values, named arguments included. `panic!` payloads differ by form,
a literal rides as `&str`, formatting allocates a `String`, and the
sample's downcast proves which is which.

#snippet("let v = vec![3, 1, 2];\nv.sort_unstable();\nassert_eq!(v, vec![1, 2, 3], \"sorted, got {v:?}\");\nassert!(v.len() == 3, \"length {n}, expected 3\", n = v.len());\nassert_ne!(v.first(), Some(&3));", lang: "rust")

== doc tests

Doc comments are executable documentation: a fenced rust block
inside `///` is extracted by `rustdoc --test`, compiled as its own
program with the item in scope, and run, `no_run` and `ignore`
annotate fences that should not execute. The doc test lives in the
crate's documentation and breaks the build when the example rots,
which is the point, the corpus api crate's public functions in
chapter 19 carry their fences the same way:

#listing("rust/samples/src/Ch18/DocTests.rs", first: 15, last: 45, caption: [two documented functions, each with its executable fence])

Under the per-file runner the fences are prose, so the sample's
contract is that every assert inside every fence has a matching ok
line in `main`, the same expectations executed for real:

#listing("rust/samples/src/Ch18/DocTests.rs", first: 48, last: 73, caption: [the fence expectations as live checks])

== hand-rolled benches

Criterion is the ecosystem standard and a dependency, so this book
benches with `Instant`, `std::hint::black_box` to keep the optimizer
honest, since 1.66, checksums so no round can be elided, and medians
over a fixed five samples so one scheduler hiccup cannot lead. The
measured pair is the classic complexity gap, linear against binary
search over a 4096-element sorted array, all misses so the linear
scan pays full price every round:

#listing("rust/samples/src/Ch18/Benches.rs", first: 16, last: 46, caption: [the two implementations, the timed harness, black_box, median])

#listing("rust/samples/src/Ch18/Benches.rs", first: 48, last: 101, caption: [agreement asserted first, then timing printed, never asserted])

Measured 2026-10-13 on the pinned build: linear median 40145844 ns
per round against binary 432326 ns, a 92.9x ratio, five samples each
with the spread printed. The discipline in the asserts is the
chapter's rule: correctness claims are asserted, timing claims are
printed with their samples and dated, never asserted, a faster or
slower machine changes the numbers and no build should go red over
a clock.

== clippy and rustfmt governance

The book's rules, matching the corpus tooling: rustfmt formats the
crates, never the samples, whose alignment and layout are part of
the listings, and clippy lints the crates. Samples compile under
`rustc --edition 2024 -D warnings`, which is where this book met
real clippy-class lints already: `unnecessary_transmutes` rejecting
a transmute with a safe equivalent, and
`suspicious-runtime-symbol-definitions` flagging a redeclared
runtime symbol, both in chapter 17. The full clippy suite runs over
the api crate when it lands in wave 2, under the same law, lints on
what ships, never on what teaches.

== the idiom roundup

The conventions this book has followed in every chapter, in one
place, each one checked live:

#listing("rust/samples/src/Ch18/Idioms.rs", first: 15, last: 92, caption: [builder types, derived traits, the error chain with From and source])

Iterator chains over index loops: `(1..=100).map(i * i).sum()` in
place of a mutable accumulator, the loop's value asserted equal, and
the whole corpus pipeline style, chapter 10's adapters especially,
is this rule at scale. Builders over constructors with many
arguments, consuming `self` so each method is a statement.
`#[derive]` for `Debug`, `PartialEq`, `Clone`, `Default` whenever
the derived meaning is the meaning. Errors as enums implementing
`Display` and `Error`, conversion through `From` so `?` crosses
levels, `source()` chaining so one print tells the whole story,
measured as the chain string in the sample's output. `matches!` for
pattern assertions. Newtypes when a bare primitive would let
arguments swap silently, the `StatusCode(u16)` shape the http
kernel uses.

#listing("rust/samples/src/Ch18/Idioms.rs", first: 94, last: 159, caption: [chain equality, builder equality, the error chain printed end to end])

The prose rules that have no assert: no `unwrap` outside tests and
samples, `expect` with a message when a sample must fail loudly,
`pub(crate)` as the default visibility, zero dependencies, edition
2024 everywhere, and unsafe only behind a safe wrapper with its
contract written down, chapter 17's law.

#callout("note", "the corpus runner in one line", [
  `pwsh tools/run-rust-samples.ps1 -Chapter ChNN` compiles every
  `.rs` under the chapter with `rustc --edition 2024 -D warnings`,
  runs it, fails red on any nonzero exit or any `FAIL:` line, and
  requires at least one `ok N name` line per file. This chapter's 4
  samples and 24 checks, and all 29 files and 230 checks across
  chapters 13 through 18, ride that contract.
])

sources: the rust book testing chapter
(doc.rust-lang.org/stable/book/ch11-00-testing.html through
ch11-03-test-organization.html), std::panic::catch_unwind
(doc.rust-lang.org/stable/std/panic/fn.catch_unwind.html, stable
since 1.9.0), std::hint::black_box
(doc.rust-lang.org/stable/std/hint/fn.black_box.html, stable since
1.66.0), the rustdoc documentation on doc tests and code block
attributes (doc.rust-lang.org/stable/rustdoc/write-documentation/documentation-tests.html),
and the reference on testing attributes
(doc.rust-lang.org/stable/reference/attributes/testing.html), all
read from the offline 1.99.0 html share under
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html
and accessed 2026-10-13. Version facts verified in
doc.rust-lang.org/stable/releases.md, accessed 2026-10-13: test
functions returning Result in 1.28.0 (2018-08-02), black_box in
1.66.0 (2022-12-15). The runner contract quoted from
tools/run-rust-samples.ps1 in this repo, read 2026-10-13. All
measurements (5 attribute fns inert under plain rustc, both
should_panic failure modes rejected, literal versus formatted panic
payloads, linear 40145844 ns against binary 432326 ns medians at
92.9x over five samples, the error chain string end to end) produced
by `rust/samples/src/Ch18` under `pwsh tools/run-rust-samples.ps1
-Chapter Ch18`, dated 2026-10-13 on the pinned rustc 1.99.0, 4 files
24 checks.
