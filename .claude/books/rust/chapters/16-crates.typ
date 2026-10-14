#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= crates, modules, and workspaces

A package is a cargo directory with a manifest. A crate is one
compilation unit, a library or a binary. A module is a namespace
inside a crate. Cargo's job is the first two, the compiler's job is
the third, and most confusion is just those three words being used
interchangeably. This chapter walks the module system as one file, the
visibility ladder item by item, the manifest of this book's own crate
shape field by field, and the cargo test organization the corpus
runner mirrors. The book's law sits over all of it: the api crate is
one bin plus lib crate with zero dependencies, everything it needs is
std, and that crate arrives in chapter 19.

== modules and paths

`mod` declares a namespace, inline or in its own file. Every item has
a path from the crate root, spelled `crate::` for absolute,
`self::` for the current module, `super::` for the parent. The
sample runs one module tree through all three spellings and asserts
they agree:

#listing("rust/samples/src/Ch16/Modules.rs", first: 13, last: 59, caption: [one module tree carrying the whole visibility ladder])

The ladder, rung by rung. `pub` is visible everywhere the crate is.
`pub(crate)` is visible inside this compilation unit only, the right
default for internals a binary crate never exports anywhere anyway.
`pub(super)` is visible in the parent module, used when a child hands
its parent a hook and nobody else. Plain private is visible in the
defining module and its descendants, which is why `frame_checksum`
runs inside `tcp` but not from `network`. Fields ride the same ladder:
`Session` has a public `peer` and a private `id` behind a getter,
construction through `Session::open` so the invariant survives.

#listing("rust/samples/src/Ch16/Modules.rs", first: 61, last: 91, caption: [absolute, use imported, and self relative paths agreeing, and the ladder probed])

Two compile errors this sample deliberately walks around, worth
seeing in their reject form. A private item from outside its module:

#snippet("network::tcp::frame_checksum(\"host\")\n// error[E0603]: function `frame_checksum` is private", lang: "rust")

And `pub(super)` from above the super in question, `tcp::status` is
visible to `network` but not to the crate root:

#snippet("network::tcp::status()\n// error[E0603]: function `status` is private\n// the pub(super) on tcp::status stops at network", lang: "rust")

Modules nest anywhere, including inside a function body, and `super`
always means exactly one level up:

#listing("rust/samples/src/Ch16/Modules.rs", first: 93, last: 111, caption: [a sibling call through super, inside a block scoped module])

The file-per-module layout is the same tree on disk: `mod tcp` inside
`network` becomes `network/mod.rs` with `pub mod tcp` plus
`network/tcp.rs`, or `network.rs` beside a `network/` directory, both
shapes are legal and the 2018 edition removed the need for `extern
crate` and the `mod` declarations for `src/lib.rs` and `src/main.rs`
themselves. The api crate uses the directory form for its sections,
router, store, and the rest, one file per module.

== use and re-exports

`use` brings a path in once so call sites stop spelling it, `as`
renames on the way, `pub use` re-exports so a facade module becomes
the public face over deep internals. The sample builds the pattern
the api crate's `Server` type will use in chapter 19:

#listing("rust/samples/src/Ch16/UseReexport.rs", first: 17, last: 49, caption: [impl module, then a facade re-exporting it under two spellings])

#listing("rust/samples/src/Ch16/UseReexport.rs", first: 51, last: 89, caption: [deep path, facade path, renamed re-export, use with as, types too])

The rule that makes facades work: `pub use` does not copy code, it
publishes a path. `facade::line` and `format_impl::line` are the same
item, one function, one symbol, and a glob `use facade::*` pulls the
whole published surface. Std items rename identically, the sample
binds `BTreeMap as OrderedMap` and uses it.

== the manifest, field by field

The crate this book ships is one package with one lib and one bin,
and its manifest is small enough to walk completely:

#snippet("[package]\nname = \"rust\"\nversion = \"1.0.0\"\nedition = \"2024\"\n\n[lib]\nname = \"rust\"\npath = \"src/lib.rs\"\n\n[[bin]]\nname = \"rust-api\"\npath = \"src/main.rs\"\n\n[dependencies]\n\n[dev-dependencies]", lang: "toml")

Field by field. `name` is the crate name other code imports, kebab
or snake, hyphens become underscores on use. `version` is semver,
the caret range cargo derives from it is why lockfiles matter.
`edition` picks the dialect, 2024 for this book, chapter 2 owns the
ladder. `[lib]` names the library target, `[[bin]]` an array table
because a package may hold several binaries, each with its own name
and entry file. `[dependencies]` is empty here and stays empty, the
zero-dependency law, which also means no supply chain, no version
drift, and no audit surface beyond the toolchain pin. A `[dev-dependencies]`
section would carry test-only crates, this book has none.

Workspaces, in prose: a root manifest with `[workspace] members =
[\"api\", \"tools\"]` shares one `Cargo.lock`, one `target/`, and one
dependency graph across member crates, so two crates in the repo
cannot disagree on a version. This book has one crate, so the
workspace question never arises, but the corpus's repo is exactly
that shape if a second crate ever lands.

Features, in prose: `[features]` declares named cfg switches, the
`default` list, and dependencies can be optional behind a feature.
The api crate declares none: every feature is a compile-time
fork of the code under test, and a zero-dependency service has
nothing to switch.

== cargo test organization

Three kinds of tests live in three places. Unit tests sit next to the
code in `src/`, inside `#[cfg(test)] mod tests` with `use super::*`,
compiled only under `cargo test`. Integration tests live in `tests/`,
each file its own crate linking the library as a user would. Doc
tests live in fenced rust blocks inside doc comments, extracted and
run by `rustdoc --test`. The shape:

#listing("rust/samples/src/Ch16/TestOrg.rs", first: 15, last: 40, caption: [the #[cfg(test)] module shape, exactly as src unit tests are written])

The corpus runner compiles each sample with plain `rustc --edition
2024 -D warnings`, no `--test`, so the module is compiled out and
the checks are ok lines instead. The sample proves the gate live:
`cfg!(test)` is false, and the `#[test]` fns have no symbols at all
under a plain compile, measured 2026-10-13 by this file compiling
and running. Chapter 18 owns the full testing treatment, this
section fixes the layout only.

#listing("rust/samples/src/Ch16/TestOrg.rs", first: 42, last: 56, caption: [the same expectations as ok lines, and the cfg gate probed])

#callout("note", "the ok line contract", [
  Every sample in this book prints `ok N name` per passing check and
  exits nonzero on the first failure, which is what
  `tools/run-rust-samples.ps1` counts. The discipline predates cargo
  here: one file, one binary, zero setup, the same contract as the
  java and c sample runners in this corpus. The api crate's own
  suite in chapter 31 runs under `cargo test` with real #[test] fns,
  both shapes coexist because the layout above is identical in both.
])

sources: the rust book packages and modules chapter
(doc.rust-lang.org/stable/book/ch07-00-managing-growing-projects-with-packages-crates-and-modules.html
through ch07-05-separating-modules-into-different-files.html), the
rust reference items on modules and visibility
(doc.rust-lang.org/stable/reference/items/modules.html), and the
cargo book manifest reference and tests organization pages
(doc.rust-lang.org/stable/cargo/reference/manifest.html,
doc.rust-lang.org/stable/cargo/guide/tests.html), all read from the
offline 1.99.0 html share under
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html
and accessed 2026-10-13. The edition 2018 path and extern crate
changes verified against
doc.rust-lang.org/stable/edition-guide/rust-2018/module-system/index.html,
same share, accessed 2026-10-13. The #[cfg(test)] compiled out under
plain rustc, the private and pub(super) rejection messages, and the
example.org checksum of 1122 measured live compiling and running
`rust/samples/src/Ch16` under `pwsh tools/run-rust-samples.ps1
-Chapter Ch16`, dated 2026-10-13 on the pinned rustc 1.99.0, 3 files
18 checks.
