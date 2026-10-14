#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= from edition 2015 to edition 2024

Every feature in this book carries the version or edition that shipped
it: "async/await arrived stable in 1.39", "edition 2021 changed array
IntoIterator". This chapter is where those numbers come from. Editions
are Rust's mechanism for incompatible change without breaking the
ecosystem. There are four of them so far, and this chapter walks all
four as worked migrations, 2015 to 2018, 2018 to 2021, 2021 to 2024,
then closes with the compiler timeline the rungs hang from. Java walks
its own version ladder the same way in #xref-to("java", "ladder").

== what an edition is

Rust 1.0 landed in may 2015 with a promise, stability without
stagnation: once a feature ships on stable, every later compiler keeps
compiling it. But some changes are incompatible by nature. A new
keyword breaks every variable already named with it, and a closure
that captures less than before can change when destructors run. The
edition system is the escape valve: incompatible changes pile up
behind an opt in, and a crate states which rule set it compiles under
through one manifest field.

The constraint that shapes every edition decision is that editions
never split the ecosystem. A 2015 crate links against a 2024 crate
without ceremony, because the choice is private to each crate and all
editions compile down to the same internal representation in the
compiler. The changes an edition may carry are correspondingly shallow
in machine terms, a keyword here, a capture rule there, a denied lint,
even when they rewrite how every file in a project reads.

#diagram([four rungs in ten years, each ships in the release that stabilized it], length: 13pt, {
  let rungs = (
    ([2015 #linebreak() 1.0, 2015], 2015),
    ([2018 #linebreak() 1.31, 2018], 2018),
    ([2021 #linebreak() 1.56, 2021], 2021),
    ([2024 #linebreak() 1.85, 2025], 2025),
  )
  let x-of = (year) => (year - 2015) * 1.9 + 1.6
  cdraw.line((0.6, 1.4), (22.2, 1.4), stroke: luma(100), mark: (end: ">>"))
  for (label, year) in rungs {
    let x = x-of(year)
    cdraw.line((x, 1.4), (x, 3.6), stroke: luma(100))
    cdraw.circle((x, 1.4), radius: 0.3, stroke: luma(60))
    cdraw.content((x, 4.3), label, size: 6pt)
  }
  cdraw.content((11.0, 0.3), [rung spacing is true to shipping years, the next edition is on no calendar], size: 6pt)
})

Migration between rungs is tooling, not archaeology: the `cargo fix`
subcommand, run with `--edition`, applies the migration lints for the
next edition and rewrites the code. The whole hop is five commands:

#diagram([the edition hop as cargo runs it, five commands from warning free to reformatted], length: 13pt, {
  cdraw.line((0.6, 2.6), (22.6, 2.6), stroke: luma(100), mark: (end: ">>"))
  let stage(x, label, sub) = {
    cdraw.line((x, 2.6), (x, 3.0), stroke: luma(100))
    cdraw.content((x, 4.2), label, size: 6.5pt)
    cdraw.content((x, 3.4), sub, size: 6pt)
  }
  stage(2.6, [cargo update], [dependencies current])
  stage(7.2, [cargo fix], [`--edition` flag])
  stage(11.8, [bump the field], [`edition = "2024"`])
  stage(16.4, [cargo test], [both compile])
  stage(21.0, [cargo fmt], [style edition])
})

After the hop the code compiles under both editions, which is why a
large dependency graph migrates crate by crate with nothing waiting on
anything else.

== 2015 to 2018: keywords and paths

Edition 2018 shipped in 1.31 (2018-12-06) under RFC 2052, the RFC that
also proposed the edition system, and it front-loaded two language
cleanups the first three years had earned.

`dyn` became a strict keyword. Bare trait object syntax,
`Box<Trait>`, was ambiguous with generic syntax and read badly beside
`impl Trait`, so trait objects gained their own marker:

#snippet(
  "// 2015\nlet sink: Box<Write> = Box::new(Vec::new());\n\n"
  + "// 2018\nlet sink: Box<dyn Write> = Box::new(Vec::new());\n",
  lang: "rust",
)

The `dyn Trait` syntax arrived in 1.27 (2018-06-21), usable in every
edition, and 2018 made it the required spelling while reserving
`async` and `await` as strict keywords in 2018 crates, ahead of
async/await stabilizing in 1.39 (2019-11-07), and `try` for a feature
that has still not shipped.

The module system got the bigger rework. `extern crate` disappeared
from ordinary code, paths in `use` declarations started working the
same as paths everywhere else, `crate::` names the current crate's
root from anywhere, and a module's submodules stopped needing the
special name `mod.rs`:

#snippet(
  "// 2015\nextern crate serde;\nuse serde::Serialize;\n\n"
  + "// 2018\nuse serde::Serialize;\n",
  lang: "rust",
)

#snippet(
  "2015                          2018\n"
  + "src/                          src/\n"
  + "+- lib.rs                     +- lib.rs\n"
  + "+- foo/                       +- foo.rs\n"
  + "   +- mod.rs                  +- foo/\n"
  + "   +- bar.rs                     +- bar.rs\n",
  lang: "text",
)

A dependency now enters through `Cargo.toml` alone, and the compiler
resolves its name in every module. Renamed crates moved from
`extern crate futures as f` to `use futures as f`, per module.

== 2018 to 2021: arrays, closures, panics

Edition 2021 shipped in 1.56 (2021-10-21) and its three visible
changes all removed traps rather than adding features.

Arrays became iterable by value. Until 1.53 only `&[T; N]` and
`&mut [T; N]` implemented `IntoIterator`, so `for e in [1, 2, 3]`
failed to compile. The trait implementation landed in 1.53 (2021-06-17)
in every edition, with one hack: method call syntax,
`array.into_iter()`, kept resolving to `(&array).into_iter()` in 2015
and 2018 crates, because too much code depended on the borrow. Edition
2021 removed the hack, and the method call finally yields owned values:

#snippet(
  "// 2018: x is &u8, the call secretly borrows\n"
  + "for x in array.into_iter() {}\n\n"
  + "// 2021: x is u8, the call consumes\n"
  + "for x in array.into_iter() {}\n",
  lang: "rust",
)

#listing("rust/samples/src/Ch02/Arrays2021.rs", first: 21, last: 60, caption: [the 2021 behaviors asserted: by-value for and into_iter, the fully qualified form, iter's borrow, zip consuming an array])

The `array_into_iter` lint warns on every call that changes meaning,
on all editions since 1.41, so warning-free 2018 code was already
2021-ready.

Closures started capturing disjoint fields, RFC 2229. In 2018 and
before, a closure mentioning `a.x` captures all of `a`, which blocks
moves of sibling fields and drags non-Send fields into threads. From
2021 the closure captures `a.x` and nothing else:

#snippet(
  "// 2018: error, the closure wants all of a\ndrop(a.x);\n"
  + "let c = || println!(\"{}\", a.y);\n\n"
  + "// 2021: compiles, the closure captures a.y only\ndrop(a.x);\n"
  + "let c = || println!(\"{}\", a.y);\n",
  lang: "rust",
)

Capturing less can change drop order and which auto traits a closure
implements, the two behaviors the sample measures directly:

#listing("rust/samples/src/Ch02/DisjointCapture.rs", first: 47, last: 86, caption: [drop event logs prove the capture granularity, the dummy let cargo fix inserts forces the whole capture, a Clone field makes a Clone closure])

`panic!` became consistent with `format!`. The 2018 macro only applied
formatting when handed more than one argument, so `panic!("{}", 1)`
formatted its message to `1` while a single argument bypassed
formatting entirely: `panic!(a)` panicked with the raw payload, and
`panic!(123)` produced the famously unhelpful `Box<Any>` message.
Edition 2021 made the first argument always a format string, killed
the arbitrary-payload form, and moved non-string panics to
`std::panic::panic_any`:

#snippet(
  "// 2018\npanic!(\"{}\");\npanic!(a);\n\n"
  + "// 2021\npanic!(\"{{}}\");\npanic!(\"{}\", a);\nstd::panic::panic_any(a);\n",
  lang: "rust",
)

#callout("note", "why the consistency could not wait", [
  The 2021 panic rules landed one release before captured format
  arguments, `{ident}` inside any format string, arrived in 1.58
  (2022-01-13). Without the fix, `panic!("failed at {stage}")` would
  have printed the literal braces while `println!` interpolated, the
  exact confusion the edition change erased.
])

== 2021 to 2024: capture rules and unsafe hygiene

Edition 2024 shipped in 1.85 (2025-02-20) under RFC 3501, and its
changes share one theme, making the compiler honest about what code
already depended on by accident.

`gen` became a reserved keyword, clearing room for gen blocks, a
future iterator-building feature, before the next edition needs it.
Identifiers named `gen` become `r#gen` through raw identifiers, the
same escape hatch `r#async` used in the 2018 hop. The `try` keyword
from 2018 is still waiting in the same reserved state.

Return-position `impl Trait` changed what it captures. In 2021 and
earlier, an RPIT captured a lifetime parameter only when it appeared
syntactically in the opaque type's bounds, which forced the `Captures`
trick and the outlives trick onto serious codebases. Rust 1.82
(2024-10-17) stabilized `use<..>` precise capturing in all editions,
and edition 2024 flipped the default: an RPIT without a `use<..>`
bound now captures every in-scope lifetime, matching what RPITIT and
`async fn` already did in every edition:

#snippet(
  "// the outlives trick, before\nfn f<'a, T: 'a>(x: &'a (), y: T) -> impl Sized + 'a { (x, y) }\n\n"
  + "// precise capturing, since 1.82 in all editions\nfn f<'a, T>(x: &'a (), y: T) -> impl Sized + use<'a, T> { (x, y) }\n\n"
  + "// 2024, the capture is implicit\nfn f<'a, T>(x: &'a (), y: T) -> impl Sized { (x, y) }\n",
  lang: "rust",
)

#listing("rust/samples/src/Ch02/RpitCapture2024.rs", first: 15, last: 51, caption: [use<> beside the Captures trick, an impl method capturing its outer generic, Debug as the only window into an opaque])

Attributes with soundness requirements became `unsafe` syntax.
`no_mangle`, `export_name`, and `link_section` reach into the global
symbol namespace, where a collision can break linking with nothing but
safe code in sight. Since 1.82 any attribute could opt into the
`unsafe(...)` spelling, and 2024 requires it:

#snippet(
  "// 2021\n#[no_mangle]\npub fn example() {}\n\n"
  + "// 2024\n#[unsafe(no_mangle)]\npub fn example() {}\n",
  lang: "rust",
)

References to `static mut` are denied. The `static_mut_refs` lint,
warn-by-default before, is deny in 2024, because forming even an
unused reference to a mutable static violates the aliasing rules
instantly and proving it sound requires reasoning about the whole
program. The replacement is the raw borrow operators, `&raw const` and
`&raw mut`, stabilized in 1.82:

#snippet(
  "// 2021\nunsafe { let r = &X; }\n\n"
  + "// 2024\nunsafe { let p = &raw const X; }\n",
  lang: "rust",
)

#listing("rust/samples/src/Ch02/Unsafe2024.rs", first: 13, last: 53, caption: [the 2024-clean forms asserted: raw borrows on a static mut, the unsafe extern block, `r#gen`, the atomics replacement])

== the migration, measured

The chapter's claims about cargo hold on the pinned lane, measured
2026-10-13 with cargo 1.99.0: `cargo fix --edition` and
`cargo fix --edition-idioms` exist, while `cargo build --edition` and
`cargo run --edition` do not, the flag is rejected with an unexpected
argument error. The edition lives in the manifest and in rustc, not in
build subcommands. `cargo fix --edition` works by applying the
`rust-2024-compatibility` lint group, the same lints the ladder
sample names: `keyword_idents_2024` for `gen`, `impl_trait_overcaptures`
for RPIT capture, `unsafe_attr_outside_unsafe` for the attributes,
`static_mut_refs` for the references. Each hop in the ladder has its
equivalent group, `keyword_idents_2018` for the first hop,
`rust_2021_incompatible_closure_captures` among others for the second.

Two migrations have no automatic fix: the `static mut` rewrite, where
the tooling refuses to guess between atomics, locks, and raw pointers,
and the APIT cases of overcapture, where a type parameter must gain a
name before a `use<..>` bound can mention it.

== the 1.0 to 1.99 timeline

#table(
  columns: (auto, auto, 1fr, 1fr),
  inset: 4pt,
  table.header([*version*], [*date*], [*language*], [*remembered for*]),
  [1.0], [2015-05-15], [the baseline edition, ownership and borrowing as shipped], [stability without stagnation],
  [1.27], [2018-06-21], [`dyn Trait` trait object syntax], [the marker before it was required],
  [1.31], [2018-12-06], [edition 2018, tool lints, `const fn`, lifetime elision in impl headers], [the edition system's debut],
  [1.39], [2019-11-07], [`async fn`, `.await`], [async/await for everyone],
  [1.53], [2021-06-17], [`IntoIterator` for arrays in all editions, or patterns], [the by-value fix with a hack around it],
  [1.56], [2021-10-21], [edition 2021, `binding @ pattern` may bind], [arrays, closures, panic],
  [1.58], [2022-01-13], [captured format arguments `{ident}`], [format strings name their arguments],
  [1.75], [2023-12-28], [`async fn` and return-position `impl Trait` in traits], [traits speak async],
  [1.82], [2024-10-17], [`use<..>` bounds, `&raw const` and `&raw mut`, unsafe attribute opt-in, unsafe extern blocks], [the 2024 groundwork],
  [1.85], [2025-02-20], [edition 2024, async closures], [the fourth rung],
  [1.99], [2026-10-01], [C-variadic definitions stable, `#[my_macro] mod foo;`], [the lane this book pins],
)

The version line the samples parse carries the build stamp
2026-09-28 while the release notes date the release 2026-10-01, a
commit-date versus release-date distinction the ladder sample's data
keeps straight by citing the notes for dates and the version line for
the pin.

#listing("rust/samples/src/Ch02/EditionLadder.rs", first: 15, last: 52, caption: [the ladder as data: version, year, reserved keywords, and the migration lint each hop rides])

#listing("rust/samples/src/Ch02/EditionLadder.rs", first: 54, last: 91, caption: [the timeline table, rung and feature lookups, and the panic catcher that measures the 2021 macro])

The closing sample runs the ladder itself: 15 checks across the rungs,
keyword reservations, lint names, the dyn trait object, captured
format arguments, and five panic behaviors under `catch_unwind`, green
on the pinned build 2026-10-13.

sources: doc.rust-lang.org/stable/edition-guide, editions index,
transitioning chapter, and the 2018, 2021, 2024 chapter pages for
keywords, paths, arrays, closures, panic, gen, RPIT capture, unsafe
attributes, and static mut references, all accessed 2026-10-13 against
the offline rust-docs copy. releases.md from the offline component,
sections 1.0, 1.31, 1.39, 1.53, 1.56, 1.58, 1.75, 1.82, 1.85, 1.99,
read 2026-10-13, plus the edition guide's dyn page, which redirects
to the 1.27 blog post dated 2018-06-21. doc.rust-lang.org/stable/rustc lint
listing, allowed and warn by default groups, accessed 2026-10-13, for
the six lint names. Cargo behavior measured live 2026-10-13:
`cargo fix --help` shows `--edition` and `--edition-idioms`,
`cargo build --edition 2024` and `cargo run --edition 2024` are
rejected. Sample evidence: Ch02 5 files 38 checks green under
`pwsh -NoProfile -File tools/run-rust-samples.ps1 -Chapter Ch02`,
2026-10-13.
