#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= error handling

Rust has exactly two failure channels. A panic aborts the current
task through unwinding, for bugs and broken invariants. A `Result`
value reports an expected failure through the type system, for
everything a caller might want to handle. This chapter covers both,
the `?` operator that chains results, hand rolled error types, and
the unwinding machinery itself, `catch_unwind` since 1.9 and the
abort profile switch. `Option` and `Result` were introduced in
chapter 7 as enums, here they get their full treatment.

== panic versus result

The rule of thumb is simple: panic when the caller cannot possibly
do anything sensible, return a `Result` when they can. The sample
implements the same division twice, one panicking, one reporting:

#listing("rust/samples/src/Ch11/PanicVsResult.rs", first: 16, last: 31, caption: [the same failure as a panic and as a value])

#listing("rust/samples/src/Ch11/PanicVsResult.rs", first: 33, last: 57, caption: [unwinding measured: a flag that never gets set, and a payload read])

`catch_unwind` turns the panic into a `Result` whose error side is
the payload, and the `reached` flag proves the statement after the
panic point never ran, unwinding really unwound. The `Err` from
`safe_div` is just a value, catching it costs nothing, no thread
dies, no stack unwinds. The combinators, `map`, `map_err`,
`unwrap_or`, adapt each side without a match:

#listing("rust/samples/src/Ch11/PanicVsResult.rs", first: 58, last: 69, caption: [map_err, unwrap_or, and map on the two sides])

The library version of the rule is stricter than the application
version. A library panics only on contract violations its caller
cannot express: the wrong kind of value in a type that promised
otherwise, an index the caller already checked. Anything arriving
from outside, files, sockets, user input, env vars, comes back as a
`Result`, because the caller of a library is the one who knows
whether the failure is fatal. The standard library follows this
line exactly, `Vec::index` panics on out of range because the
caller's own logic chose the index, while `HashMap::get` returns
`Option` because absence is an ordinary outcome. A panic in library
code is a bug report with your crate's name on it.

There is also the explicit middle form, `#[should_panic]` territory
in chapter 18 aside: the `assert!` family is how invariants are
declared, and each assert is a panic site with a message. `debug_assert!`
compiles away in release, so performance-critical checks can stay
in the test and debug builds. None of this is exception machinery,
an assert is a branch plus a panic call, and the branch is visible
in the codegen.

== the question mark operator

`?` is early return for results, since 1.13. On `Ok` it unwraps and
continues, on `Err` it converts through `From` and returns. It works
on `Option` the same way with `None`:

#listing("rust/samples/src/Ch11/Question.rs", first: 16, last: 35, caption: [two parses through one signature, collect short circuiting, option, boxed errors])

`parse_all` collects into `Result<Vec<i64>, ParseIntError>`, the
`FromIterator` impl for `Result` stops at the first error, an
iterator level `?` for free. `boxed_total` returns
`Result<i64, Box<dyn Error>>` and uses `?` on a `ParseIntError`
directly, the `From` conversion wraps it into the box. `main` itself
can return a `Result`, since 1.26, printing the error through
`Debug` and exiting nonzero when it lands:

#listing("rust/samples/src/Ch11/Question.rs", first: 37, last: 74, caption: [main returning result, the termination impl])

#diagram([what one question mark expands to], length: 13pt, {
  pane(0.3, 11.3, 7.0, [call site], [#"let x = f()?;"], [the operator reads], [as one match])
  cdraw.line((11.6, 4.2), (12.4, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(12.7, 23.3, 7.0, [the expansion], [#"Ok(v) => v"], [#"Err(e) => return"], [#"  Err(From::from(e))"], )
  cdraw.content((11.8, 1.4), [since 1.13, from converts for free], size: 6pt)
})

== combinators and the conversion traits

Between `?` and `match` sits the combinator layer, one method per
way a branch might continue. `map` and `map_err` transform one side,
`and_then` chains a fallible closure onto an ok, `or_else` supplies
an alternative error path, `unwrap_or` and `unwrap_or_else` collapse
to a value, and `ok_or` promotes an `Option` into a `Result`:

#snippet(
  "let port = parse_port(raw).or_else(|_| fallback_port());\n"
  + "let path = env::var_os(\"HOME\").ok_or(HomeMissing);\n"
  + "let n: i64 = text.trim().parse().unwrap_or_else(|e| {\n"
  + "    log::warn!(\"bad number {e}, using zero\");\n"
  + "    0\n"
  + "});\n"
  + "// each combinator returns the same enum it consumed, so they stack\n",
  lang: "rust",
)

`unwrap` and `expect` are the panic side of the api: both extract or
panic, `expect` stamps the message with your string and the file and
line of the call. The rule from the first section still applies,
they are for invariants you can prove, not for input you cannot.

The conversion traits complete the bridge. `From` is total, `u8`
into `u16` always succeeds and `Into` rides it, `TryFrom` since 1.34
is the fallible twin that returns `Result`, and `TryInto` is its
consumed mirror. Numeric narrowing is the canonical case,
`u8::try_from(300u32)` is an `Err`, where the `as` cast would have
silently wrapped:

#listing("rust/samples/src/Ch11/Question.rs", first: 76, last: 90, caption: [try_from rejecting a lossy narrowing, try_into on the value])

Every fallible conversion in std that can lose data returns a
`Result`, never a panic and never a silent wrap, `str::parse`,
`i64::try_from`, `Vec::try_reserve`. The `Try` trait that
generalizes `?` beyond `Result` is still nightly, the operator
works on `Option` and `Result` on stable.

== a custom error enum

Library grade error handling is one enum per fallible area, a hand
written `Display`, an `Error` impl exposing `source` since 1.30, and
`From` impls so `?` converts into it. The trait itself is 1.0:

#listing("rust/samples/src/Ch11/CustomError.rs", first: 17, last: 49, caption: [the enum, display, error with source, and a from impl])

Two loader flavors use it. `setting` maps errors explicitly with
`map_err`, `translated` leans on `?` plus the `From` impl, and both
compile against the same signature. The source chain is the payoff,
a caller walking `source()` gets the parse error underneath the
config error without knowing its type:

#listing("rust/samples/src/Ch11/CustomError.rs", first: 51, last: 70, caption: [explicit map_err against question mark conversion])

#listing("rust/samples/src/Ch11/CustomError.rs", first: 92, last: 116, caption: [walking the source chain, and a boxed trait object printing through display])

The ecosystem's error crates automate exactly this shape, `thiserror`
derives `Display` and `From` from attributes, `anyhow` replaces the
enum with a boxed trait object plus context. Both are sugar over what
the sample wrote by hand, no magic underneath.

The `Error` trait itself is deliberately small. `description` is
deprecated since the `Display` impl made it redundant, `cause` is
the pre-1.30 spelling of `source`, and `provide`, the
request-response hook for downcasting payloads without `Any`, is
nightly. What remains is `source` plus the blanket machinery:
`Box<dyn Error>` is `Any` underneath, so a boxed error downcasts
back to the concrete enum, the round trip a library boundary
preserves for callers that need the variant:

#listing("rust/samples/src/Ch11/CustomError.rs", first: 105, last: 121, caption: [the box, the source walk, and the downcast back to the enum])

Choosing where each shape lives follows from ownership. Inside a
module, the enum, every variant is a case the code can branch on.
Across a library boundary, the trait object in the signature, the
caller can print, chain, or downcast but cannot exhaustively match.
Across a process boundary, the serialized error, text with a code,
because the trait object dies with the process. The service chapters
of this book run all three layers.

== catch_unwind and the panic machinery

`catch_unwind`, stable since 1.9 under that name, runs a closure and
catches any panic that escapes it, returning the payload as
`Box<dyn Any + Send>`:

#listing("rust/samples/src/Ch11/CatchUnwind.rs", first: 16, last: 45, caption: [payload downcasting to str and string, and a counting hook])

The payload rule measured here: a literal message downcasts to
`&str`, a message formatted from runtime values downcasts to
`String`, and since the constant folding landed, a message whose
format arguments are all compile time constants downcasts to `&str`
again because the message is rendered at compile time. The hook
mechanism, `set_hook` and `take_hook`, observes every panic before
it unwinds, which is how test frameworks and loggers capture
messages:

#listing("rust/samples/src/Ch11/CatchUnwind.rs", first: 56, last: 83, caption: [resume_unwind preserving the payload, and assert_unwind_safe around a mutable capture])

`resume_unwind` rethrows the original payload without counting as a
new panic, the tool for a catch-log-rethrow chain. `AssertUnwindSafe`
is the honesty marker: types with interior mutability are not
logically consistent across a unwind boundary, the cell may be half
updated, and the wrapper is you telling the compiler you accept
that. `panic=abort` is a cargo profile setting, not code:

#snippet(
  "[profile.release]\n"
  + "panic = \"abort\"\n"
  + "# unwinding machinery removed, smaller and faster binaries,\n"
  + "# catch_unwind can no longer catch, the process dies at the panic\n",
  lang: "toml",
)

Under `abort`, every panic ends the process immediately, `?` and
`Result` are unaffected, they never unwind. Foreign exceptions, c++
crossing an ffi boundary, abort rather than unwind, so
`catch_unwind` is not a general exception catcher. Chapter 17 covers
that boundary.

A panic prints three things by default, the message, the file and
line of the panic site, and the note pointing at `RUST_BACKTRACE`.
Setting `RUST_BACKTRACE=1` in the environment adds the stack, which
is the difference between guessing and knowing when a panic escapes
in a test run. The default hook prints all of it, and the hook
itself receives `PanicHookInfo`, the type renamed from `PanicInfo`
in 1.81 when the std hook argument split from the no_std panic
handler's. The message text is a debug aid, not an api, code that
needs to react to a panic reacts to the payload through
`catch_unwind` and downcasting, the way both samples did.

The unwinding path itself costs nothing until it fires. The
generated code for a fallible call is a branch on the discriminant,
the same branch a c error code would take, and the unwinding tables
are dead weight only when the panic never happens. That is the
whole justification for the two channel design: expected failures
ride the cheap channel, the enum, and the expensive machinery stays
reserved for the bugs.

#callout("verify", "every claim measured", [
  The unwound flag, the payload types, the hook count, the source
  chain length, the combinator behaviors, the try_from rejection,
  and the boxed error downcast are printed by
  `rust/samples/src/Ch11`, 41 checks green under
  `pwsh -NoProfile -File tools/run-rust-samples.ps1 -Chapter Ch11`
  on rustc 1.99.0 edition 2024, measured 2026-10-13.
])

sources: doc.rust-lang.org/stable/book ch9 error handling for panic
versus result and the question mark, std::error::Error trait page for
source since 1.30 and the trait since 1.0, std::panic module docs for
catch_unwind, resume_unwind, set_hook, take_hook, and the payload
types, convert module docs for from, try_from, and try_into,
releases.md for 1.9 catch_unwind, 1.13 the question mark, 1.26 main
returning result, 1.30 error source, 1.34 try_from and try_into, all
read from the offline oracle at
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html,
accessed 2026-10-13, cross-checked against doc.rust-lang.org/stable
url forms.
