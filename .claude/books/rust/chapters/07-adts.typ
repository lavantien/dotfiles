#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= structs, enums, and patterns

Chapter 5 gave moves and borrows, chapter 6 gave the lifetimes that
scope them. This chapter builds the data shapes those rules govern:
products (structs) and sums (enums), then the pattern language that
decomposes both. The pattern half is where rust earns the ml family
comparison, a match that proves its own coverage, and the arc runs
from fixed slice patterns in 1.26 through let-else in 1.65 to let
chains in 1.88, each step attributed inline. Chapter 2 walked the
edition ladder, the 2024 edition is where let chains live.

== structs: named, tuple, unit

Three spellings cover every product type. The named struct is the
default, the tuple struct wraps one position, the unit struct carries
no data at all:

#listing("rust/samples/src/Ch07/Adts.rs", first: 13, last: 32, caption: [the three struct spellings and a sum type beside them])

Methods hang off `impl` blocks and chapter 5's move rules apply
unchanged: `norm2` borrows `&self`, `apply` takes `self` by value and
consumes it. Field init shorthand, `x, y` instead of `x: x`, and the
update syntax `..p` keep construction short:

#listing("rust/samples/src/Ch07/Adts.rs", first: 34, last: 52, caption: [an associated constructor, a borrowed method, an exhaustive area])

The runner measures the shapes. A unit struct is zero sized, a tuple
struct destructures like a tuple, and struct update moves only the
fields it copies from `p`, so `p` is partially moved afterwards:

#listing("rust/samples/src/Ch07/Adts.rs", first: 64, last: 74, caption: [method call, update syntax, positional destructure, zero sized marker])

== the newtype pattern

A tuple struct with exactly one field is a newtype, and it is the
cheapest abstraction in the language. `Celsius(f64)` costs nothing at
runtime, chapter 12 measures this class of wrapper at exactly the
inner size, yet it is a distinct type to the compiler: a bare `f64`
will not bind where a `Celsius` is expected, and no implicit
conversion exists in either direction. The pattern carries three
duties at once, unit clarity, capability tracking, and orphan rule
relief from chapter 8, wrapping a foreign type in a local newtype
makes it yours to implement traits on.

#snippet(
  "struct Celsius(f64);\n"
  + "struct Fahrenheit(f64);\n"
  + "fn boil(t: Celsius) -> bool { t.0 >= 100.0 }\n"
  + "let f = Fahrenheit(212.0);\n"
  + "boil(f);\n"
  + "// error[E0308]: mismatched types, expected `Celsius`, found `Fahrenheit`\n"
  + "// the two f64 wrappers never mix, the field is public but the type gates\n",
  lang: "rust",
)

Access is positional, `.0`, and construction is a function call,
`Celsius(21.5)` is the tuple constructor applied to a value. The
sample destructures it the same way, `let Celsius(t) = ...`, an
irrefutable pattern because every value of the type matches.

== enums as sum types

An enum lists alternatives, each variant is either a unit, a tuple, or
a record. `Shape` uses all three spellings in one declaration. The
compiler assigns each variant a discriminant, and the sample proves
the discriminants differ. Sizing follows: a three variant dataless
enum is one byte, and `Option<&u8>` reuses pointer bits for the none
case so it costs nothing over a bare reference:

#listing("rust/samples/src/Ch07/Adts.rs", first: 93, last: 103, caption: [the niche at work, measured on this build])

That niche reuse is a compiler optimization, not a language promise,
but it is why `Option<&T>` replaced nullable pointers with no size
penalty. The tag for an inline `u64` payload is forced up to a full
word by alignment, the same padding arithmetic any c programmer
knows, measured at 16 bytes.

== match and exhaustiveness

A match arm is a pattern, optionally a guard, then a body. The
compiler checks that the arms cover every value of the scrutinee
type, so adding a variant to `Event` breaks every match over it until
each new case is handled:

#listing("rust/samples/src/Ch07/Match.rs", first: 13, last: 33, caption: [guards, or patterns, ranges, and one binding per arm])

Constants can appear in patterns, `HOT` above, and literals inside
variants too. Guard clauses run after the pattern matches, so
`Event::Click(5, 9)` fails the `x == y` guard and falls to the next
arm. The wildcard `_` closes any match, and integer ranges can
partition a whole `u8` without one since 1.33:

#snippet(
  "error[E0004]: non-exhaustive patterns: `Event::Scroll(_)` not covered\n"
  + "  --> src/main.rs\n"
  + "   = help: ensure that all possible cases are being handled\n",
  lang: "text",
)

Delete one arm and that is the error, verbatim, naming the uncovered
variant. This is the same contract as #xref-to("java", "patterns")
sealed hierarchies: closed sums plus a compiler that walks them.

Any value can be the scrutinee, not just enums. Tuples match
positionally, literals and ranges match numbers and chars, and a
named binding without a subpattern is itself a pattern, the
irrefutable one that always succeeds:

#snippet(
  "let pair = (2, \"two\");\n"
  + "match pair {\n"
  + "    (0, _) => (),\n"
  + "    (n, word) if n == word.len() => (),\n"
  + "    whole => (),\n"
  + "}\n"
  + "// tuple arms try top to bottom, the first fit wins,\n"
  + "// and `whole` binds whatever reaches it, never failing\n",
  lang: "rust",
)

Arm order is the search order. The compiler only checks
exhaustiveness, it does not reorder, so a specific arm placed under
a general one is dead and the general one wins every time. The
dominance rules go further for literals: two identical literal arms
are an outright error, unreachable pattern, while two overlapping
guarded arms are legal and the earlier guard gets first refusal,
the guarded-then-unguarded pairing the sample relies on for
`Event::Scroll`.

== guards, bindings, and at

The `@` sign binds a name to the whole value a subpattern matched,
which is how one arm tests a range and still reads the number:

#listing("rust/samples/src/Ch07/Match.rs", first: 36, last: 51, caption: [at with a range on one arm, plain binding on the next])

`n @ 1..=3` tests the range and binds `n` to the same `i32`. Since
1.53 or patterns nest inside subpatterns, `Event::Key('a' | 'b')`, and
since 1.42 `matches!` wraps a pattern test in a boolean, with the
guarded form used in the sample. `assert_matches!` landed much later,
in 1.96, the current year's stable. Bindings may also be typed:
`ref`, `ref mut`, and `mut` inside patterns still work, but match
ergonomics below made them mostly unnecessary.

#diagram([one arm, four moving parts], length: 13pt, {
  pane(0.3, 11.3, 7.0, [pattern], [#"Scroll(n @ 4..)"], [range subpattern], [at binding])
  cdraw.line((11.6, 4.2), (12.4, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(12.7, 23.3, 7.0, [guard then body], [#"if n % 2 == 0"], [runs only after], [the pattern matched])
  cdraw.content((11.8, 1.6), [guards may not make a match exhaustive], size: 6pt)
  cdraw.content((11.8, 0.5), [a wildcard arm still closes it], size: 6pt)
})

== if let, while let, let-else

Refutable patterns get three lighter forms. `if let` runs a block on
one pattern, `while let` loops until the pattern fails, and let-else,
since 1.65, binds on success and forces the else block to diverge:

#listing("rust/samples/src/Ch07/IfLet.rs", first: 13, last: 18, caption: [let-else since 1.65, the else must diverge])

The else block must `return`, `break`, `continue`, or panic, the
checker rejects any path that falls through. That single rule is the
whole feature: after the let-else, the binding is live and every
later line knows the pattern held. `while let` pairs naturally with
`Vec::pop`:

#listing("rust/samples/src/Ch07/IfLet.rs", first: 52, last: 57, caption: [while let over a stack, none ends the loop])

Edition 2024 in 1.88 stabilized let chains, `if let` and boolean
conditions mixed freely in one `if`, with any number of `let`
conditions. Since 1.33 `if let` also accepts or patterns:

#listing("rust/samples/src/Ch07/IfLet.rs", first: 29, last: 37, caption: [an else-if-let chain, each branch with its own let chain])

#listing("rust/samples/src/Ch07/IfLet.rs", first: 70, last: 79, caption: [three let conditions and two booleans in one if, edition 2024])

#listing("rust/samples/src/Ch07/IfLet.rs", first: 80, last: 88, caption: [or patterns folding two tuple shapes in one if let since 1.33])

#callout("note", "the ladder", [
  Fixed entry slice patterns 1.26, match ergonomics 1.26, `|` in if
  let and while let 1.33, exhaustive integer patterns 1.33, subslice
  patterns and `matches!` 1.42, or patterns in subpatterns 1.53,
  let-else 1.65, let chains 1.88 in edition 2024 only, `assert_matches!`
  1.96. Every number checked against the offline `releases.md`.
])

== match ergonomics

Since 1.26 patterns apply dereferences automatically. Matching a
`&Expr` against `Expr::Lit(v)` binds `v` as `&i64`, no explicit
`&` in the pattern, and the same holds through any depth of
references and through `&mut`:

#listing("rust/samples/src/Ch07/Ergonomics.rs", first: 19, last: 32, caption: [a reference scrutinee and a double reference, both matched by value patterns])

The mechanism is the default binding mode, which starts in move mode
and switches to ref when the scrutinee is a reference. Edition 2024
tightened the edges: once the binding mode is not move, writing
`mut`, `ref`, or `ref mut` on a binding is an error, and `&` or
`&mut` patterns are only allowed in the fully explicit prefix of a
pattern. Old code that mixed both styles had to pick one.
Slice patterns complete the picture, fixed entries since 1.26 and
rest patterns with `..` since 1.42:

#listing("rust/samples/src/Ch07/Ergonomics.rs", first: 34, last: 47, caption: [empty, single, both ends pinned, and a three element prefix])

`edges` is total over slices with no wildcard arm, the three shapes
cover `[]`, `[x]`, and everything longer. A `Vec` coerces to a slice
for the match, deref coercion from chapter 6 doing the work.

== Option and Result

`Option<T>` is the enum with `None` and `Some(T)`, `Result<T, E>` the
enum with `Ok(T)` and `Err(E)`. Both are ordinary enums, every
pattern tool in this chapter applies to them, and the niche sizing
measured above is `Option`'s. Their full treatment, `?`, conversions,
and the error trait, is chapter 11's subject. Here they close the
loop: absence is a value, not a null pointer, and the type system
forces every read to pick a branch for it.

Because they are ordinary enums, the lighter forms all apply too.
`if let Some(x) = lookup()` is the everyday read, let-else turns
absence into an early return, and the sample's `to_ounces` is the
canonical shape. What patterns cannot do is invent a default, that
job belongs to the combinators, and they are just methods returning
the same enums:

#snippet(
  "let port = env::var(\"PORT\").ok().map(|s| s.parse::<u16>().ok()).flatten();\n"
  + "let port: Option<u16> = maybe_parse.and_then(|s| s.parse().ok());\n"
  + "let port = port.or(Some(8080));\n"
  + "// map, and_then, or, unwrap_or, ok_or: every one returns\n"
  + "// an option or result, so the chain never leaves the enum world\n",
  lang: "rust",
)

`and_then` is `map` for fallible closures, `or` substitutes an
alternative absence, `ok_or` converts `Option` into `Result` by
supplying the error. They compose because each returns the same
container it consumed, the same design the iterator adapters of
chapter 10 follow. The rule of thumb that falls out: match when the
branches need different logic, chain combinators when the branches
are transform or default.

`Vec<T>`, `HashMap<K, V>`, and friends are products of the same
story told in chapters 6 and 15, their accessors return `Option`
precisely so that absence stays on the type level. A `None` from
`HashMap::get` carries no error information, it is pure absence,
which is why lookup methods that can fail for a reason return
`Result` instead.

sources: doc.rust-lang.org/stable/book ch05 structs and ch06 enums
and match, reference/patterns.html for default binding modes, range
patterns, and the irrefutable and refutable pattern classes,
reference/statements.html for the let-else divergence rule,
edition-guide rust-2024 match ergonomics chapter for the binding
mode error rule, releases.md for every version number above, all
read from the offline oracle at
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html
and cross-checked against doc.rust-lang.org/stable url forms,
accessed 2026-10-13. Every behavioral claim is asserted by
`rust/samples/src/Ch07`, 57 checks green under
`pwsh -NoProfile -File tools/run-rust-samples.ps1 -Chapter Ch07` on
rustc 1.99.0 edition 2024, measured 2026-10-13.
