#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= types and values

The value layer: twelve integer types and two floats with measured
ranges, inference that runs backwards from usage, one explicit cast
operator, the composite trio of tuples, arrays, and slices, the two
degenerate types `()` and `!`, and the two spelling of forever, `const`
and `static`. The reference's types section and expressions section are
the spine, the numbers come from the pinned 1.99.0 lane.

== the scalar inventory

Five unsigned widths, five signed, two floats, `bool`, `char`,
`usize`, and `isize`. The 128 bit integers joined the language in
1.26, everything else was there at 1.0. The machine dependent pair
follows the pointer: `usize::BITS` reads 64 on this host, and the
reference guarantees only at least 16:

#listing("rust/samples/src/Ch04/Scalars.rs", first: 16, last: 24, caption: [the signed ranges, measured against the reference table])

#listing("rust/samples/src/Ch04/Scalars.rs", first: 41, last: 58, caption: [the unsigned ranges and the pointer width pair on this host])

#callout("note", "code that assumes 64 bit pointers", [
  `usize::MAX` differs per platform and the reference warns that much
  of the ecosystem assumes 32 or 64 bit pointers, so 16 bit targets
  need opt in care. Everything this book measures is the pinned 64 bit
  msvc host, and the sizes on the pages here carry that caveat: 8 for
  a pointer, 16 for a fat pointer, 4 for a `char`, all measured, none
  portable law beyond the reference's minimums.
])

The floats are IEEE 754 binary32 and binary64, and the sample derives
their constants from the formulas instead of trusting decimal
spellings: epsilon is 2 to the -23 and -52, max is the largest
representable mantissa times the largest exponent:

#listing("rust/samples/src/Ch04/Scalars.rs", first: 61, last: 87, caption: [epsilon and max from first principles, NaN, and the 0.1 + 0.2 classic])

#diagram([the scalar inventory: widths, ranges, families], length: 13pt, {
  let cols = ((0.0, 5.0, [type]), (5.0, 11.5, [widths]), (11.5, 23.4, [range or value]))
  for (x0, x1, head) in cols {
    cdraw.rect((x0, 5.9), (x1, 6.8), fill: luma(205), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 6.35), head, size: 6.5pt)
  }
  let rows = (
    ([integers], [1 2 4 8 16 bytes], [i8 -128..127 through i128, since 1.26 for the 16 byte pair]),
    ([unsigned], [same widths], [u8 0..255 through u128]),
    ([usize], [pointer width], [64 bit here, at least 16 guaranteed]),
    ([floats], [4 and 8 bytes], [f32 f64, IEEE 754, NaN and infinities]),
    ([bool], [1 byte], [true false]),
    ([char], [4 bytes], [scalar values U+0000..U+10FFFF minus the surrogate gap]),
  )
  for (i, row) in rows.enumerate() {
    let y0 = 5.0 - i * 0.95
    cdraw.rect((0.0, y0 - 0.85), (5.0, y0), fill: luma(235), radius: 0.02)
    cdraw.content((2.5, y0 - 0.42), row.at(0), size: 6pt)
    cdraw.rect((5.0, y0 - 0.85), (11.5, y0), fill: luma(245), radius: 0.02)
    cdraw.content((8.25, y0 - 0.42), row.at(1), size: 6pt)
    cdraw.rect((11.5, y0 - 0.85), (23.4, y0), fill: luma(245), radius: 0.02)
    cdraw.content((17.45, y0 - 0.42), row.at(2), size: 6pt)
  }
})

== inference

Rust infers types at bindings and propagates them from every use
site. The defaults only apply where nothing else speaks: an unsuffixed
integer is `i32`, an unsuffixed float is `f64`. The sample measures
each site with `std::any::type_name`, since 1.38:

#listing("rust/samples/src/Ch04/Coercion.rs", first: 28, last: 56, caption: [six inference sites from defaults to turbofish])

The direction matters. `let x = 5;` starts from the literal, `let v:
Vec<u32> = (0..3).collect();` runs the annotation backwards through
the collect call, and `"12".parse::<u16>()` names the type at the
call. A binding whose type nothing can determine, like a genuinely
empty `collect` with no annotation, is a compile error, not a
fallback.

What inference never does is guess a semantics. It fills type
variables, it never inserts a conversion, widens a narrow integer, or
turns an `i32` into a `usize` to make an indexing expression work,
those are `as` casts by hand or trait methods by name. The split keeps
the reading rule simple, where the types come from is invisible, where
they change is always visible.

== coercion sites and the as table

Two roads change types. Implicit coercions happen only at fixed sites
where the target type is already known, `let` with annotation,
function arguments, return positions, and a handful more, and they
cover a short list, weakening `&mut` to `&`, unzing arrays into
slices, and a few pointer forms. Everything else needs the explicit
`as` cast:

#listing("rust/samples/src/Ch04/Coercion.rs", first: 58, last: 76, caption: [coercion sites need no keyword, the annotation drives them])

The `as` table is closed. Integers and floats swap freely, `bool` and
`char` go to integers, `u8` goes to `char`, enum types go to their
integer representation, a preview of chapter 7, and pointers cast
among compatible forms. Nothing else crosses without a method. The
numeric semantics are exact: same width is a bit reinterpretation,
narrowing truncates, signed widening sign extends, unsigned widening
zero extends:

#listing("rust/samples/src/Ch04/Coercion.rs", first: 83, last: 122, caption: [truncation, extension, and the two directions of char casting, measured])

#callout("pitfall", "float to int saturates, since 1.45", [
  Before 1.45 the float to int cast produced whatever the cpu felt
  like for out of range values. Now `300.0f32 as u8` is 255, negative
  infinity is `i32::MIN`, and `NaN` is 0. Truncation toward zero still
  applies to in range values, `3.9` becomes 3.
])

#diagram([two roads: coercion sites and the closed as table], length: 13pt, {
  cdraw.rect((0.3, 2.6), (10.6, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.45, 4.9), [implicit coercion], size: 6.5pt)
  cdraw.content((5.45, 4.0), [only at fixed sites], size: 6pt)
  cdraw.content((5.45, 3.1), [`&mut` to `&`, array to slice], size: 6pt)
  cdraw.line((10.6, 4.0), (11.6, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.6, 2.6), (23.2, 5.4), fill: luma(225), radius: 0.02)
  cdraw.content((17.4, 4.9), [explicit `as`], size: 6.5pt)
  cdraw.content((17.4, 4.0), [numeric casts, bool and char to int], size: 6pt)
  cdraw.content((17.4, 3.1), [`u8` to `char` the only door back], size: 6pt)
  cdraw.content((11.8, 1.4), [everything else, `String` to `&str` style questions, belongs to methods and traits, not casts], size: 6.5pt)
})

== tuples, arrays, slices

Tuples are structural, heterogeneous, and named by position. Arrays
carry their length in the type, `[i32; 3]` and `[i32; 4]` are
unrelated types, and indexing is bounds checked everywhere in safe
code. Slices are views, `[T]` is unsized and lives behind a fat
pointer of data address plus length:

#listing("rust/samples/src/Ch04/Composites.rs", first: 35, last: 63, caption: [tuple forms, the trailing comma rule, unit, and array facts])

#listing("rust/samples/src/Ch04/Composites.rs", first: 66, last: 104, caption: [bounds checks, the slice family, and the 16 byte fat pointer])

The bounds check is a runtime guarantee, not a debug aid: the sample
catches the panic and reads its exact message, `index out of bounds:
the len is 3 but the index is 7`.

== unit and never

`()` is the tuple with no fields, one value, zero size, and the
result type of statements that produce nothing, including assignment
expressions. `!` is the type with no values, the return type of
diverging functions, and it coerces into any other type, which is why
`panic!` and `unreachable!()` sit inside expressions of any type:

#listing("rust/samples/src/Ch04/Composites.rs", first: 21, last: 31, caption: [a diverging function and a branch that leans on the coercion])

#listing("rust/samples/src/Ch04/Composites.rs", first: 123, last: 139, caption: [! coerces through if and match arms, reaching it panics])

== const and static

A `const` is a name for a value, inlined at each use, with no fixed
address promised. A `static` is a name for one allocation with a fixed
address, initialized at compile time, never dropped at program end,
and required to be `Sync` unless declared `mut`. Constants prefer
`const fn` initializers, stable since 1.31:

#listing("rust/samples/src/Ch04/ConstStatic.rs", first: 15, last: 31, caption: [the declarations side by side])

#listing("rust/samples/src/Ch04/ConstStatic.rs", first: 33, last: 60, caption: [const inlining, the fixed static address, interior mutability, static mut place access])

Edition 2024 hardened the last sharp edge: taking a reference to a
`static mut` is now denied by default, because aliasing a mutable
global through references violates the mutability xor aliasing rule
the borrow checker enforces everywhere else. Place operations, the
direct read and write, remain legal inside `unsafe`, and the raw
pointer operators `&raw const` and `&raw mut` are the sanctioned
route since 1.82:

#snippet(
  "static mut LEVELS: u32 = 0;\n"
  + "unsafe {\n"
  + "    LEVELS += 1;            // fine, a place operation\n"
  + "    let r = &LEVELS;        // error: creating a shared reference to mutable static\n"
  + "}\n",
  lang: "rust",
)

The safe replacements are the ones chapter 13 will build on, an
immutable `static` over `AtomicU64` or a `Mutex`.

== integer overflow

Debug builds panic on arithmetic overflow, release builds wrap in two's
complement, and `-C overflow-checks` overrides the mode. The sample
suite runs on the debug lane, `rustc --edition 2024 -D warnings` with
no optimization flag, so every panic below is measured:

#listing("rust/samples/src/Ch04/Overflow.rs", first: 26, last: 58, caption: [four panics with their exact payloads, and the literal exception])

#callout("verify", "which build the runner uses", [
  The sample lane compiles without `-O`, so `cfg!(debug_assertions)`
  is true and the checks on this page are the debug behavior. The
  release behavior was probed separately with `rustc -O` on the same
  toolchain, 2026-10-13: `250u8 + 250u8` wrapped to 244 with no panic.
])

The division corner is its own rule: `i8::MIN / -1` panics even in
release, the reference calls the legacy behavior out explicitly, and
`i8::MIN % -1` is 0 rather than a panic. Shifts overflow when the
right side reaches the type's width. When wrapping is the intent, the
four method families say it at the call site, `checked_` since 1.0,
`saturating_` since 1.0, `wrapping_` since 1.0 with the shift variants
in 1.2, and `overflowing_` in 1.7:

#listing("rust/samples/src/Ch04/Overflow.rs", first: 60, last: 126, caption: [the four families over add, sub, div, and shift, every branch measured])

#diagram([overflow policy: build mode picks the default, the families opt out explicitly], length: 13pt, {
  cdraw.rect((0.3, 3.6), (11.0, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((5.65, 5.05), [plain operators], size: 6.5pt)
  cdraw.content((5.65, 4.35), [debug: panic], size: 6pt)
  cdraw.content((5.65, 3.95), [release: wrap], size: 6pt)
  cdraw.line((11.0, 4.6), (12.0, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 2.0), (23.4, 5.6), fill: luma(245), radius: 0.02)
  cdraw.content((17.7, 5.05), [the method families], size: 6.5pt)
  let fams = (
    [`checked_`], [`Option`, None on overflow],
    [`saturating_`], [clamp at the bound],
    [`wrapping_`], [two's complement wrap],
    [`overflowing_`], [wrapped value plus a bool],
  )
  for i in range(4) {
    let y = 4.5 - i * 0.62
    cdraw.content((13.0, y), fams.at(i * 2), size: 6pt)
    cdraw.content((16.2, y), fams.at(i * 2 + 1), size: 6pt)
  }
  cdraw.content((11.8, 1.0), [always panicking regardless of mode: i8::MIN / -1, shift by the width], size: 6.5pt)
})

== type aliases

`type Celsius = f64;` creates a synonym, nothing more. The alias is
transparent to the type checker, the sample proves it with
`type_name`, and distinct identities are chapter 7's `struct` and
`enum` job. The one distinction that survives aliasing is in error
messages, which print the alias name where it was written:

#listing("rust/samples/src/Ch04/Coercion.rs", first: 23, last: 25, caption: [aliases for a scalar, a tuple, and an array])

#listing("rust/samples/src/Ch04/Coercion.rs", first: 134, last: 150, caption: [the alias reads back as the underlying type, measured])

sources: the rust reference, types, numeric types, char, tuple, array,
slice, and never type pages plus type coercion, type cast expressions,
constant items, and static items,
doc.rust-lang.org/stable/reference/types.html and the per type pages,
accessed 2026-10-13 against the pinned 1.99.0 offline rust-docs set.
overflow semantics from the reference's operator expressions page, the
saturating float cast change from releases.md 1.45, the edition 2024
static mut rule from the edition guide's static-mut-references page,
all read 2026-10-13. claims verified by the Ch04 sample suite, 115
checks under `tools/run-rust-samples.ps1 -Chapter Ch04` on
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc, plus two probes
run 2026-10-13: `rustc -O` on the wrapped addition for the release
claim, and the edition 2024 compile fail on `&LEVELS` whose error text
is quoted in this chapter.
