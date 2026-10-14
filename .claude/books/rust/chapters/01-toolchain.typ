#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= toolchain, cargo, and the rustup lane

Rust does not ship as one compiler binary. Rustup installs toolchains,
each toolchain carries the compiler plus a set of components, and Cargo
drives the compiler over a manifest. This book pins the stable msvc lane
at rustc 1.99.0 (b940084d7 2026-09-28), rustup 1.29.1 manages it, and
every sample in the corpus compiles as a single file under
`rustc --edition 2024 -D warnings`. The gates resolve the toolchain by
directory and assert the full version string before anything compiles,
so a wrong toolchain is a loud red, never a silent drift. Go makes the
opposite bet, one binary holding every subcommand, the trade the
#xref-to("go", "toolchain") chapter documents from its side.

== the rustup lane

A toolchain name is channel plus host triple: `stable-x86_64-pc-windows-msvc`.
Rustup keeps one directory per toolchain under `RUSTUP_HOME`, defaulting
to `~/.rustup`, and the `cargo` and `rustc` on PATH are proxies that
dispatch to the active toolchain. Three rules pick the active one, in
order: a directory override from `rustup override set`, a
`rust-toolchain.toml` file naming a channel, then the default channel.
Measured on this machine 2026-10-13: two toolchains installed, stable
as the default plus a nightly the gates exclude, and dropping a
`rust-toolchain.toml` containing `channel = "stable"` into a directory
makes `rustup show active-toolchain` report the file as the override
source.

#listing("rust/samples/src/Ch01/Toolchain.rs", first: 56, last: 81, caption: [the name grammar: edition to shipping version, triple fields, channel prefix, home override])

Each component installs once per toolchain, and this lane carries 8 of
them, measured with `rustup component list`: `cargo`, `clippy`,
`llvm-tools`, `rust-docs`, `rust-src`, `rust-std`, `rustc`, `rustfmt`.
The standard library is itself a component, `rust-std-<triple>`, one per
target, which is how cross compilation pays its entry fee later in this
chapter.

#diagram([one rustup lane: the name grammar on top, the directory it maps to, the components inside], length: 13pt, {
  cdraw.rect((6.2, 6.1), (16.6, 7.1), fill: luma(205), radius: 0.02)
  cdraw.content((11.4, 6.6), [stable - x86_64-pc-windows-msvc], size: 7pt)
  cdraw.content((11.4, 7.6), [channel + host triple], size: 6pt)
  cdraw.line((11.4, 6.1), (11.4, 5.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((2.4, 1.4), (20.4, 5.2), fill: luma(240), radius: 0.02)
  cdraw.content((11.4, 4.6), [\$RUSTUP\_HOME/toolchains/stable-x86_64-pc-windows-msvc/], size: 6.5pt)
  let slot(x, label) = {
    cdraw.rect((x, 2.2), (x + 4.2, 3.7), fill: luma(225), radius: 0.02)
    cdraw.content((x + 2.1, 3.15), label, size: 6pt)
  }
  slot(3.0, [rustc])
  slot(7.6, [cargo])
  slot(12.2, [clippy #linebreak() rustfmt])
  slot(16.0, [rust-docs #linebreak() rust-src])
  cdraw.content((11.4, 1.7), [headline components, 8 installed in all], size: 6pt)
})

#callout("note", "why the directory matters", [
  The gates prepend the toolchain's `bin` directory to PATH themselves
  instead of trusting whatever `rustc` resolves to, then assert the
  exact pinned prefix of the version line. A PATH pointing at the
  nightly, or at a system rustc from a package manager, is rejected
  before a single sample compiles.
])

== cargo's job and rustc's job

Cargo reads `Cargo.toml`, resolves the dependency graph, lowers build
profiles into rustc flags, and invokes rustc once per crate in that
graph. Rustc compiles exactly one crate root, the file it is given,
and knows nothing about manifests or versions or lockfiles. The split
is the whole configuration surface: dependency decisions live in the
manifest, language decisions live in rustc flags, and Cargo is the
translator between them.

The day to day command set is small. `cargo new` scaffolds the
manifest and the `src` tree, `cargo build` compiles into
`target/debug` or, with `--release`, into `target/release`, `cargo
run` builds and then executes, `cargo test` runs the unit tests and
then the doc tests as a second leg, and `cargo doc` renders html from
doc comments. The doc test leg deserves one measured fact: on this
lane a library crate with one fenced example in a doc comment reports
`running 0 tests` for the unit leg and `1 passed` for a doctest leg
that compiled the fence as its own binary with the crate's public
items in scope. A doc comment is a compiled artifact, not a comment.
Chapter 18 owns testing whole.

`cargo new hello` on this lane writes a manifest with
`edition = "2024"`, measured 2026-10-13 with cargo 1.99.0. New projects
get the newest stable edition. A manifest with no edition field
compiles as 2015, forever, because the edition is an opt in and its
default never moves under an existing project.

#listing("rust/samples/src/Ch01/CargoVsRustc.rs", first: 19, last: 57, caption: [a manifest reader: package fields, the dependency table, and the 2015 default when the edition field is absent])

The profiles are the other half of the translation. Cargo's book fixes
the defaults: `dev` runs at opt-level 0 with debug assertions on,
`release` at opt-level 3 with them off, and each profile owns one
output directory under `target`. The dev profile's directory is
`target/debug`, the name differs from the profile on purpose.

#listing("rust/samples/src/Ch01/CargoVsRustc.rs", first: 59, last: 92, caption: [the two profiles this book uses and their lowering into rustc codegen flags])

#diagram([cargo's translation: manifest and profile in, one rustc invocation per crate out], length: 13pt, {
  cdraw.line((0.6, 2.6), (22.6, 2.6), stroke: luma(100), mark: (end: ">>"))
  let stage(x, label, sub) = {
    cdraw.line((x, 2.6), (x, 3.0), stroke: luma(100))
    cdraw.content((x, 4.2), label, size: 6.5pt)
    cdraw.content((x, 3.4), sub, size: 6pt)
  }
  stage(3.0, [manifest], [edition and deps])
  stage(8.8, [cargo build], [resolves, lowers])
  stage(14.6, [rustc], [`--edition 2024`, `-C` flags])
  stage(20.6, [target/debug], [the dev profile's dir])
})

== rustc invoked directly

Rustc alone is the right tool for single-file programs with zero
dependencies, for learning the language without a build system in the
way, and for probing the compiler itself. All three describe this
book's samples lane: `tools/run-rust-samples.ps1` compiles each sample
with `rustc --edition 2024 -D warnings`, runs the binary, and fails on
any error or on a binary that prints no `ok` lines. The pinning law
that guards the lane:

#snippet(
  "$tcBin = Join-Path $rustupHome \"toolchains\stable-x86_64-pc-windows-msvc\bin\"\n"
  + "$env:PATH = \"$tcBin;$env:PATH\"\n"
  + "$versionLine = & $rustc --version | Select-Object -First 1\n"
  + "if (-not \"$versionLine\".StartsWith(\"rustc 1.99.0 (b940084d7\")) {\n"
  + "  throw \"verify-rust: expected rustc 1.99.0 (b940084d7...), found: $versionLine\"\n"
  + "}\n",
  lang: "text",
)

Rustc also answers questions about the machine. `--print cfg` dumps the
host's cfg values, `target_arch="x86_64"`, `target_env="msvc"`,
`target_os="windows"`, `target_vendor="pc"`, all measured on this lane.
`--print target-list` counted 331 targets on the same day. The version
line itself is a parseable contract:

#listing("rust/samples/src/Ch01/Toolchain.rs", first: 15, last: 54, caption: [the version string as a type: parse, pre-release precedence, numeric field order])

== the offline doc oracle

`rustup doc --book --path` prints
`~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html/book/index.html`
on this machine, measured 2026-10-13. The `rust-docs` component
installs that whole html tree: `book/`, `reference/`,
`rust-by-example/`, `edition-guide/`, `cargo/`, `std/`, the release
notes as `releases.md`, and the error index. This book grounds every
claim against that tree and cites it in the stable URL form,
`https://doc.rust-lang.org/stable/book/` and its siblings, with the
access date recorded in each chapter's sources paragraph.

The oracle cannot drift from the compiler because both arrive in one
toolchain: the docs describe 1.99.0, the compiler is 1.99.0, and
upgrading the toolchain upgrades both in the same atomic step. The
edition guide is the spine for chapter 2, `releases.md` is the spine
for the 1.0 through 1.99 timeline, and the reference settles grammar
questions the book chapters only summarize.

== clippy, rustfmt, and what each is for

Clippy 0.1.99 (b940084d7e 2026-09-28, the same commit as rustc,
measured) is the lint collection above rustc's own: idiom lints,
correctness lints, and pedantic groups, driven with `cargo clippy`
and repaired with `cargo clippy --fix`. Its history runs in both
directions, because rustc lints get uplifted from clippy when they
prove themselves, and `releases.md` records the receipts: 1.72 lifted
`clippy::cast_ref_to_mut` into `invalid_reference_casting`, 1.86
lifted `clippy::double_neg` into `double_negations`. Scoping came with
the edition system itself: since 1.31, tool lints let an attribute
like `#[allow(clippy::too_many_arguments)]` target a foreign tool's
lint by name without a compiler flag.

Rustfmt 1.10.0 is the formatter, driven with `cargo fmt`. Unlike go's
single non-negotiable format, rustfmt is configurable and editions
carry their own style editions, the 2024 edition adjusts raw identifier
sorting and version sorting among others, so a reformat belongs at the
end of an edition migration.

#callout("note", "the corpus split", [
  The samples lane never runs rustfmt or clippy: samples hold to rustc
  lints only, `-D warnings`, because a formatting pass would churn the
  pinned line ranges every chapter lists. The service part's crates run
  the full chain instead, `cargo fmt --check` and
  `cargo clippy --all-targets -- -D warnings`, under `make verify-rust`.
])

== hosts: msvc and gnu

Windows has two tier 1 hosts and the triple's fourth field names the
difference. `x86_64-pc-windows-msvc` targets the MSVC ABI and links
with the Visual Studio toolchain, `x86_64-pc-windows-gnu` rides
MinGW-w64 and links with gcc, and `x86_64-pc-windows-gnullvm`, tier 2,
is the LLVM ABI row. One cfg value separates the first two,
`target_env="msvc"` against `target_env="gnu"`, and building the gnu
host from an msvc machine is a cross: the target's `rust-std` component
must be installed first through `rustup target add`. This book pins the
msvc host, the tier 1 default rustup chooses on this machine.

#listing("rust/samples/src/Ch01/Triples.rs", first: 20, last: 37, caption: [the triple grammar: three fields plus an optional abi, anything else rejected])

#listing("rust/samples/src/Ch01/Triples.rs", first: 39, last: 74, caption: [pointer widths, tier lookup, the cfg environment split, cross detection, component and toolchain naming])

== the edition field

The manifest's `edition` field is the whole edition system from
Cargo's side. It is per crate, it defaults to 2015 when absent, and it
never affects other crates in the same build: a 2015 crate and a 2024
crate link into one binary without ceremony, because every edition
compiles down to the same internal representation in the compiler.
What the field buys is the right to the incompatible changes each
rung introduced, new keywords, new capture rules, denied footguns,
and the ladder from 2015 to 2024 with its worked migrations is
chapter 2.

sources: doc.rust-lang.org/stable/edition-guide, editions index and
transitioning chapters, accessed 2026-10-13. doc.rust-lang.org/stable/cargo,
profiles reference and manifest reference, accessed 2026-10-13.
doc.rust-lang.org/stable/rustc, platform support tiers, accessed
2026-10-13. releases.md from the offline rust-docs component, 1.31,
1.72, and 1.86 sections, read 2026-10-13. Machine facts measured live on
the pinned lane 2026-10-13: rustc and cargo and rustfmt and clippy
version lines, rustup 1.29.1 show, toolchain list, component list,
rust-toolchain.toml override probe, cargo new manifest capture, cargo
build --edition rejection, rustup doc --book --path, rustc --print cfg,
rustc --print target-list count. Sample evidence: Ch01 4 files 50
checks green under `pwsh -NoProfile -File tools/run-rust-samples.ps1
-Chapter Ch01`, 2026-10-13.
