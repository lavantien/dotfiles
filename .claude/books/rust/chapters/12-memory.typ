#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= memory and smart pointers

There is no garbage collector and there is no manual free. Every
value has one owner from chapter 5, drops run deterministically when
ownership ends, and the smart pointer layer is the standard library
teaching the compiler new ownership shapes: `Box` for one heap owner,
`Rc` and `Arc` for counted shared owners, `Cell` and `RefCell` for
mutation that dodges the exclusive borrow rule under supervision.
This chapter measures layouts, clone counts, and drop counts for
each of them, and closes with `Pin`.

== layout: repr(C) against repr(Rust)

`repr(Rust)` is the default and promises nothing about field order.
`repr(C)` lays out fields in declaration order with c padding rules,
the only form safe to hand across an ffi boundary or a transmute.
The sample measures the same three fields both ways:

#listing("rust/samples/src/Ch12/Layout.rs", first: 14, last: 39, caption: [the same fields under both reprs, a transparent wrapper, tagged and plain enums])

#listing("rust/samples/src/Ch12/Layout.rs", first: 61, last: 90, caption: [sizes and offsets measured with addr_of, stable since 1.51])

`CPair` is 12 bytes with the u32 pinned at offset 4 by padding rules.
`RPair` measured 8 bytes with the u32 moved to offset 0 and both u8
packed after it: reordering saved 4 bytes. That 8 is a measurement,
not a promise, the nomicon is explicit that even two identical
struct definitions have no guaranteed matching layout across
compilations. The enum numbers: a `#[repr(u8)]` enum pins one byte
with chosen discriminants, a default repr enum sizes to tag plus
largest variant, 4 bytes for a u16 variant. Niche arithmetic, also
measured: `Option<&u8>` and `Option<Box<u8>>` stay 8 bytes because
null-like bit patterns mark none, `Option<NonZeroU32>` stays 4, but
`Option<f64>` is 16 on this build, the NaN niche is not used for
floats. `repr(transparent)` since 1.28, and since 1.42 on univariant
enums, guarantees a wrapper is exactly its single field.

#callout("pitfall", "never transmute repr(Rust)", [
  Transmuting between a `repr(Rust)` struct and anything else reads
  whatever order today's compiler happened to pick. The nomicon's
  rule: only `repr(C)` and `repr(transparent)` types have layout you
  may depend on. Cross-language structures and file formats declare
  `repr(C)`, always.
])

== Box: one heap owner

`Box<T>` moves its value to the heap and owns it. Deref makes it
read like a stack value, deref coercion hands out plain references,
and drop of the box drops the value, once, deterministically:

#listing("rust/samples/src/Ch12/BoxDrop.rs", first: 74, last: 107, caption: [deref, coercion, one drop, and the box riding inside a struct])

The drop counter runs exactly once per value and the struct move
never fires it, the box is just a field. `Box::leak` since 1.26
surrenders the drop entirely and returns `&'static mut`, the sample
mutates through it and the drop counter never moves again:

#listing("rust/samples/src/Ch12/BoxDrop.rs", first: 108, last: 139, caption: [leak, a hand written deref and deref mut, and into_pin])

`Deref` and `DerefMut` are traits anyone can implement, the `Wrapper`
block gets the same `*w` and `+=` sugar the box has, and the `&str`
to `&dyn Trait` coercions of chapter 8 ride the same mechanism.

== drop order

Drops follow two rules and both are measured. Locals drop in
reverse declaration order, the exact opposite of construction, and
struct fields drop in declaration order, one after another. The
sample logs every drop into a mutex guarded vec and reads the tape
back:

#listing("rust/samples/src/Ch12/BoxDrop.rs", first: 34, last: 59, caption: [a drop logger, a two field struct, and the measurement])

The recorded sequence is `inner`, `first`, `second`, `outer`. The
locals ran backwards, `_inner` was declared last so it dropped
first, `_outer` declared first dropped last, and inside the struct
the fields ran forward, `first` before `second`. The rules compose:
a struct holding boxes drops each box in field order, the box then
drops its heap value, and a `Vec<T>` drops its elements front to
back. Every number here is deterministic, no scheduler, no gc
timing, the order is a language rule.

The escape hatches sit on the same axis. `std::mem::drop(value)`
ends a value early, explicit and immediate, the tool for releasing
a lock or a file before the scope ends. `ManuallyDrop<T>` since
1.20 wraps a field so its drop never runs, for the rare ffi handoff
where the other side takes ownership. `Box::leak` is the same idea
at the pointer level. All three are moves of responsibility, not
deletions, the value's memory is released only when its owner's
owner finally drops.

== Rc: counted clones on one thread

`Rc` adds a reference count beside the value. Cloning copies the
pointer and bumps the count, dropping decrements it, and only the
final drop runs the value drop:

#listing("rust/samples/src/Ch12/RcClones.rs", first: 24, last: 55, caption: [strong counts through three owners, a weak handle, one survivor])

`Rc::downgrade` since 1.4 mints a `Weak` that points without owning,
`upgrade` returns `Option<Rc>` because the value may already be gone,
and `Rc::get_mut` refuses while any weak handle exists. The drop
counter proves the whole story: zero drops while three owners shrink
to one, exactly one drop at the end, and the weak handle outliving
the value still reports `None` from upgrade without dangling.

== Arc: the same count across threads

`Arc` is `Rc` with an atomic counter. The sample hands clones to
four threads and counts drops globally:

#listing("rust/samples/src/Ch12/ArcThreads.rs", first: 26, last: 69, caption: [four threads cloning, joining, one drop at the very end, eight clones counted])

Each thread saw at least the original plus its own clone, after the
joins the count returned to 1, and the final drop ran the value drop
exactly once across all threads. `Rc` cannot do this, its counter is
not atomic and the type is neither `Send` nor `Sync`:

#snippet(
  "let rc = std::rc::Rc::new(1u8);\n"
  + "std::thread::spawn(move || println!(\"{}\", *rc));\n"
  + "// error[E0277]: `Rc<u8>` cannot be sent between threads safely\n",
  lang: "rust",
)

== Cell and RefCell: the borrow rule at runtime

Interior mutability moves an exclusivity check from compile time to
runtime. `Cell<T>` swaps whole values through `&self`, `get`, `set`,
`replace` since 1.17, `take`, and only works for `Copy` types.
`RefCell<T>` hands out borrow guards, `Ref` and `RefMut`, and
panics on a violated rule:

#listing("rust/samples/src/Ch12/CellRefCell.rs", first: 16, last: 34, caption: [a counter type mutating both interior slots through a shared receiver])

#listing("rust/samples/src/Ch12/CellRefCell.rs", first: 36, last: 73, caption: [cell set replace take, from_mut since 1.37, try_borrow_mut, and the guard drop])

The `Counter::record` method takes `&self` and mutates a `Cell` and a
`RefCell` behind it, which is the entire point: shared receivers with
interior state. `try_borrow_mut` reports the conflict as an `Err`
instead of panicking, and the caught panic proves the second
`borrow_mut` really aborts. The rule did not disappear, it moved:
a wrong borrow is now a runtime failure instead of a compile error.
`Cell::from_mut` since 1.37 reborrows a `&mut T` as a `&Cell<T>`,
bridging the two worlds.

#diagram([where the exclusivity check runs], length: 13pt, {
  pane(0.3, 11.3, 7.0, [plain borrows], [checked at compile], [violation: red build], [zero runtime cost])
  cdraw.line((11.6, 4.2), (12.4, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(12.7, 23.3, 7.0, [refcell], [checked at runtime], [violation: panic], [guards carry flags])
  cdraw.content((11.8, 1.6), [cell: checked never, copy in copy out], size: 6pt)
  cdraw.content((11.8, 0.5), [same guarantees, different timing, measured below], size: 6pt)
})

== Weak and cycle breaking

Strong `Rc` links make cycles, and no drop in a cycle ever fires.
The sample builds a two node cycle, drops both handles, and the drop
counter reads zero, a leak proven, then rebuilds the same graph with
`Weak` links and everything drops:

#listing("rust/samples/src/Ch12/WeakCycle.rs", first: 17, last: 37, caption: [the strong node type that leaks, the weak link type that does not])

#listing("rust/samples/src/Ch12/WeakCycle.rs", first: 39, last: 51, caption: [the capped strong walk, returning where it stopped])

#listing("rust/samples/src/Ch12/WeakCycle.rs", first: 53, last: 77, caption: [the cycle: two strong owners each, cap hit, zero drops])

#listing("rust/samples/src/Ch12/WeakCycle.rs", first: 78, last: 124, caption: [weak links upgrade on demand, both nodes drop, and new_cyclic since 1.60])

`Rc::new_cyclic` since 1.60 hands the constructor a `Weak` to the
value being built, the clean way to make a self reference, and the
measured drop count shows it still drops: weak references observe,
they do not own. The parent-child idiom falls out, parents hold
strong `Rc` to children, children hold `Weak` back to parents.

== Pin in one section

`Pin` wraps a pointer and forbids moving the value behind it. It
exists for async: a future that awaits across a suspension may hold
pointers into its own stack frame, so moving it after polling would
dangle those pointers. `Pin` since 1.33 with `PhantomPinned`, the
marker from chapter 9 that opts a type out of `Unpin`, and
`Box::into_pin` since 1.63:

#listing("rust/samples/src/Ch12/BoxDrop.rs", first: 128, last: 139, caption: [into_pin, and a pinned unpin value still mutating through get_mut])

The contract is small: for `T: Unpin`, everything, `Pin` is a
no-op wrapper and `get_mut` is safe, the sample mutates through it.
Only a `!Unpin` type, one carrying `PhantomPinned`, actually locks
the address, and then `get_mut` stops compiling. Chapter 14 builds
futures on exactly this, here the type is the whole story.

== the no-gc contrast

The throughline of the chapter: nothing traces, nothing defers, no
write barrier exists. A `Box` drops when its owner drops, an `Rc`
drops when the count reaches zero, a cycle leaks unless you break it
with `Weak` yourself, and every one of those statements was printed
by a drop counter in these samples, 63 checks green. The cost model
is the mirror of a tracing collector: deterministic drops and no
pause times, paid for with the ownership discipline of chapter 5 and
the occasional `Rc<RefCell<T>>` when a graph refuses to be a tree.

That last combination deserves its own sentence because it is the
idiomatic graph in practice. `Rc<RefCell<T>>` gives shared ownership
and shared mutation, each `Rc` clone can reach the `RefCell` and
borrow it mutably, exactly what a shared cache or an observer list
needs, and the `WeakCycle` sample ran it as the node type. The
price is doubled vigilance: the borrow rule now fails at runtime,
chapter 12's own `CellRefCell` measurement, and a cycle of strong
`Rc` links leaks, so observers must hang off `Weak`. When either
price is too high the answer is not more cell types, it is a redesign
towards ownership, a single owner with indices instead of pointers,
which is where the service chapters land.

`MaybeUninit` since 1.36 and the allocator api are the escape
hatches further down, chapter 17 walks them.

sources: doc.rust-lang.org/nomicon repr-rust.html for field ordering
and the transmute rule, reference/destructors.html for drop order,
reference/type-layout.html for size, align,
and the enum layouts, doc.rust-lang.org/stable/book ch15 smart
pointers for box, rc, refcell, and weak, std docs for rc, sync,
cell, and pin pages with their since badges, releases.md for 1.4
downgrade and upgrade, 1.17 cell replace, 1.20 manuallydrop, 1.26
box leak, 1.28 repr transparent, 1.33 pin and phantompinned, 1.36
maybeuninit, 1.37 from_mut, 1.42 transparent enums, 1.51 addr_of,
1.60 new_cyclic, 1.63 into_pin, all read from the offline oracle at
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html,
accessed 2026-10-13, cross-checked against doc.rust-lang.org/stable
url forms. Every count asserted by `rust/samples/src/Ch12`, 63
checks green under `pwsh -NoProfile -File tools/run-rust-samples.ps1
-Ch12` on rustc 1.99.0 edition 2024, measured 2026-10-13.
