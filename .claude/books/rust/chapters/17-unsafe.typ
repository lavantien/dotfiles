#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= unsafe and ffi

`unsafe` is not a switch that disables checking, it is a list of five
operations the compiler cannot verify on its own, everything else
stays checked. The honest framing: unsafe rust exists because someone
must implement the safe abstractions, the standard library itself is
full of it, and the discipline is to keep it small, keep it behind a
safe interface, and write down the contract the unsafe block is
carrying. This chapter takes the five superpowers one by one, builds
`split_at_mut`'s trick by hand, handles uninitialized memory with
`MaybeUninit`, transmutes only under `repr(C)`, and measures what
actually links when calling into the c runtime on the msvc lane.

#diagram([unsafe is a narrow seam under a safe surface], length: 13pt, {
  cdraw.rect((0.3, 3.4), (11.3, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 5.85), [the safe api], size: 6.5pt)
  cdraw.content((5.8, 4.9), [push, pop, len, checked Err on full,], size: 6pt)
  cdraw.content((5.8, 3.95), [callers never write unsafe], size: 6pt)
  cdraw.rect((0.3, 0.3), (11.3, 3.0), fill: luma(222), radius: 0.02)
  cdraw.content((5.8, 2.45), [the unsafe seam], size: 6.5pt)
  cdraw.content((5.8, 1.5), [raw pointers, MaybeUninit, unsafe impl,, extern blocks, transmute], size: 6pt)
  cdraw.content((5.8, 0.55), [the contract is written down, invariants], size: 6pt)
  cdraw.line((5.8, 3.05), (5.8, 3.35), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((13.1, 5.9), [std works this way:,], size: 6pt)
  cdraw.content((13.1, 5.0), [Vec, Mutex, Box are,], size: 6pt)
  cdraw.content((13.1, 4.1), [safe wrappers over unsafe], size: 6pt)
  cdraw.content((13.1, 1.5), [edition 2024: unsafe ops,], size: 6pt)
  cdraw.content((13.1, 0.6), [need unsafe blocks inside,], size: 6pt)
  cdraw.content((13.1, -0.3), [unsafe fns too], size: 6pt)
})

== the five superpowers

The list, from the book's advanced features chapter: dereference raw
pointers, call unsafe functions or methods, implement unsafe traits,
access or mutate mutable statics, access union fields. Superpower 1
leads:

#listing("rust/samples/src/Ch17/RawPointers.rs", first: 13, last: 41, caption: [raw pointers from coercion and the raw address operator, null, deref])

`*const T` and `*mut T` are the types: they can be null, they can
alias, they can outlive what they point at, and copying them is safe,
only dereferencing is not. References coerce to raw pointers freely.
The `&raw const` and `&raw mut` operators, since 1.82, take an
address without creating even a momentary reference, the safe tool
for places like packed fields and static muts where a borrow would
already be a violation. Pointer arithmetic, the `as_ref` conversion,
and the copy primitives:

#listing("rust/samples/src/Ch17/RawPointers.rs", first: 43, last: 84, caption: [element-scaled arithmetic, Option-returning as_ref, copy_nonoverlapping, offset_from])

The remaining superpowers in one run. An `unsafe fn` marks its own
body safe by default in edition 2024, the unsafe operations inside
still need explicit blocks, the `unsafe_op_in_unsafe_fn` rule this
book compiles under with `-D warnings`. A union overlays its fields
on one memory, and reading a field reinterprets the bytes. An
`unsafe impl` asserts a marker trait the compiler cannot derive, here
`Send` for a struct holding a raw pointer, with the thread join
proving the claim was load-bearing. A `static mut` is the whole
program's shared memory, sound only under a discipline you state
yourself:

#listing("rust/samples/src/Ch17/UnsafePowers.rs", first: 17, last: 33, caption: [unsafe fn wrapping static mut, a union, and a Send assertion])

== split_at_mut, the trick in the standard library

`slice::split_at_mut` cannot be written with safe borrows: the
borrow checker sees two mutable borrows of the same slice. The real
implementation escapes to raw pointers and comes back, and the
round trip is sound because the halves are provably disjoint:

#listing("rust/samples/src/Ch17/UnsafePowers.rs", first: 35, last: 45, caption: [split_at_mut rebuilt, one raw pointer, two disjoint slices])

#listing("rust/samples/src/Ch17/UnsafePowers.rs", first: 47, last: 73, caption: [superpowers exercised, and both halves live and writable at once])

The contract carried by those four lines of unsafe: `mid <= len` is
asserted, `from_raw_parts_mut` gets a pointer plus a length that
stay in bounds, and the two regions do not overlap, so the two
`&mut` slices handed out can never alias. That is the entire content
of the safe abstraction every caller inherits.

== uninitialized memory and transmute

Reading uninitialized memory is instant undefined behavior, so safe
code cannot even name it: `MaybeUninit<T>` is the type that can hold
a `T` without there being one yet, same size, same alignment, no
tag, measured 8 and 8 for `u64`. The discipline is rigid: write
before any read, `assume_init` only over a full initialized `T`,
`assume_init_read` to move out. The array pattern below initializes
element by element and reinterprets the whole buffer in one step:

#listing("rust/samples/src/Ch17/MaybeUninit.rs", first: 27, last: 37, caption: [the MaybeUninit array pattern, element wise writes then one conversion])

`transmute` reinterprets bytes between types with the same size and
neither carrying invariants the other lacks. Under `repr(Rust)` it is
essentially always wrong: the compiler may reorder fields and change
padding at will, so two identical-looking structs have no guaranteed
shared layout, the nomicon's own example. `repr(C)` pins the layout,
and even then padding bytes are unspecified: measured 2026-10-13,
`Key { kind: u16, index: u32 }` and `Wire { index: u32, kind: u16 }`
transmute to `0x0000beef2bcf0007` and `0x000000070000beef`, the
same field values, different field order, and garbage `2bcf` sitting
in Key's padding. A byte comparison over transmuted structs is wrong
even when the layout is pinned, and under `-D warnings` a transmute
with a safe equivalent, like `u64` to `[u8; 8]` where `to_le_bytes`
exists, is rejected by the `unnecessary_transmutes` lint outright:

#listing("rust/samples/src/Ch17/MaybeUninit.rs", first: 39, last: 85, caption: [the write read pairing, the array fill, and the repr(C) transmute pair])

== calling into the c runtime, measured on msvc

Edition 2024 requires `unsafe extern` blocks, the mirror of the
superpower list: declaring foreign functions is claiming their
signatures are honest, and a `safe fn` inside the block re-narrows
the claim per function. The sample declares `strlen` and `qsort`
from the msvc c runtime and measures what actually happens: both
link and both run, the ucrt ships with the std on this toolchain.

#listing("rust/samples/src/Ch17/FfiLink.rs", first: 15, last: 37, caption: [unsafe extern declarations, a rust comparator callback, and an exported symbol])

Measured 2026-10-13: `strlen` over the c string literal `c"rust->ucrt"`
returned 10, `qsort` sorted 8 ints through the rust callback
`cmp_int`, and the ffi type sizes came out `usize` 8, `c_int` 4,
`c_char` 1. C string literals, since 1.77, produce a `&CStr` with
the terminating nul built in. One measured surprise worth keeping:
declaring `strlen` as `safe fn` trips the
`suspicious-runtime-symbol-definitions` lint under `-D warnings`,
the toolchain flags redefining a runtime symbol the standard library
itself resolves through its bundled shim, so the declaration stays
an `unsafe fn` called inside an unsafe block. Exporting goes the
other way: `#[unsafe(no_mangle)]` on an `extern "system"` fn makes a
symbol C can call, `system` being the stdcall-family abi on windows,
and the exported name is also an ordinary function inside rust.

#listing("rust/samples/src/Ch17/FfiLink.rs", first: 39, last: 73, caption: [the call, the sort, and the exported symbol with a fn pointer type])

== earning unsafe: a safe wrapper

The whole chapter lands here: unsafe is earned when it buys a safe
interface nobody can misuse. `RawRing` is a ring buffer over a
`Box<[MaybeUninit<u64>]>` inside one `UnsafeCell`, with `unsafe
impl Send` and `Sync` asserting the claims, and every method safe.
The overflow check, the modulo arithmetic, and the init discipline
live in one place, callers get `push` returning `Result` and `pop`
returning `Option`:

#listing("rust/samples/src/Ch17/SafeWrapper.rs", first: 16, last: 73, caption: [the ring, UnsafeCell state, safe methods, the claims stated])

#listing("rust/samples/src/Ch17/SafeWrapper.rs", first: 75, last: 113, caption: [fill, overflow as Err, wrap, drain, then a sequential scoped handoff])

The honesty note the sample encodes: `unsafe impl Sync` here is
asserted for the sequential handoff, and the chapter's threaded part
runs the fill and the drain in non-overlapping scoped threads, joined
in order. Overlapping pushes through this ring would be a data race
the safe api cannot prevent, because the claim itself would be a
lie, a correct concurrent ring needs a lock from chapter 13 or
atomic head and tail indices from the same chapter. The line between
sound and unsound unsafe is exactly that: not how clever the pointer
code is, but whether the claimed invariant matches the discipline
the interface actually enforces.

#callout("verify", "when unsafe is earned", [
  The checklist this book applies: the unsafe block is small, the
  contract is written down, the safe wrapper is the only door, and
  the abstraction could not exist in safe code. Vec, Box, Mutex,
  and every atomic pass it. A wrapper whose claim can be falsified
  by two threads, like this ring under overlap, does not, and gets
  either a lock or an honest single-thread bound.
])

sources: the rust book unsafe rust chapter
(doc.rust-lang.org/stable/book/ch19-01-unsafe-rust.html), the
rustonomicon
(doc.rust-lang.org/stable/nomicon/index.html with repr-rust.html for
field reordering, exotic-sizes.html and checked-uninit.html for the
uninitialized discipline, and the SafeRust and aliasing pages for the
wrapper philosophy), the reference's unsafe blocks, implementation
and behavior sections
(doc.rust-lang.org/stable/reference/unsafe-behavior.html,
doc.rust-lang.org/stable/reference/items/statics.html for mutable
statics, doc.rust-lang.org/stable/reference/type-layout.html for
repr(C) and repr(Rust) layout rules), std::mem pages for transmute
and MaybeUninit
(doc.rust-lang.org/stable/std/mem/fn.transmute.html,
doc.rust-lang.org/stable/std/mem/union.MaybeUninit.html), std::ffi
for CStr and the c types
(doc.rust-lang.org/stable/std/ffi/index.html), and the edition guide
for unsafe extern blocks and unsafe attributes
(doc.rust-lang.org/stable/edition-guide/rust-2024/unsafe-attributes.html),
all read from the offline 1.99.0 html share under
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html
and accessed 2026-10-13. Version facts verified in
doc.rust-lang.org/stable/releases.md, accessed 2026-10-13: `&raw
const` and `&raw mut` in 1.82.0 (2024-10-17), c string literals in
1.77.0. Edition 2024 rules, unsafe op in unsafe fn, the unsafe
extern block requirement, and the two lint encounters
(suspicious-runtime-symbol-definitions on `safe fn strlen`,
unnecessary_transmutes on a convertible transmute) observed live
compiling the samples under `rustc --edition 2024 -D warnings`, dated
2026-10-13. All measurements (Frame union bytes 67, 66, 65 for
0x414243, size and align 8 for u64, Key bits 0x0000beef2bcf0007
against Wire 0x000000070000beef with padding garbage 2bcf, strlen
returning 10, qsort sorting 8 ints, ffi type sizes 8 4 1, the ring
drains [30, 40, 50] and a scoped handoff [1, 2, 3]) produced by
`rust/samples/src/Ch17` under `pwsh tools/run-rust-samples.ps1
-Chapter Ch17`, dated 2026-10-13 on the pinned rustc 1.99.0, 5 files
33 checks.
