#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= ownership and moves

Every value has exactly one owner, the stack frame, the struct field,
or the heap box that holds it. Assignment either copies the bytes, for
the types marked `Copy`, or moves the owner's title to the new name and
ends the old one. When the owner dies the value drops, and the drop is
deterministic and ordered. That triple, one owner, move or copy,
deterministic drop, is the whole model, and everything chapters 6 and
12 build on it. C gives you the same graph of allocations with no
rules about who frees, #xref-to("c-os-cloud", "pointers") is the
contrast case, and the garbage collected corner of this corpus,
#xref-to("go", "allocation"), never needs the question answered.

== the ownership graph

Ownership is a tree. Each value has one incoming edge from its owner,
a stack slot, a field, an element slot, or the interior of a `Box`,
and the tree is what gets dropped, leaves first in field order, roots
last in reverse declaration order. Two owners for one heap buffer is
the bug the whole model exists to prevent, the double free:

#diagram([the ownership graph: one tree, moves re-root it, borrows are non owning edges], length: 13pt, {
  cdraw.rect((0.3, 4.6), (5.3, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((2.8, 5.4), [stack frame #linebreak() `let s = String::from("hi")`], size: 6pt)
  cdraw.rect((1.0, 2.2), (4.6, 3.4), fill: luma(225), radius: 0.02)
  cdraw.content((2.8, 2.8), [String header #linebreak() ptr len cap], size: 6pt)
  cdraw.line((2.8, 4.6), (2.8, 3.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.6, 2.2), (15.4, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((12.0, 2.8), [heap #linebreak() h i _ _ _ _], size: 6pt)
  cdraw.line((4.6, 2.8), (8.6, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((12.0, 1.4), [the header owns the buffer, one edge, one owner], size: 6pt)
  cdraw.rect((17.6, 4.6), (23.4, 6.2), fill: luma(245), radius: 0.02)
  cdraw.content((20.5, 5.7), [after `let t = s;`], size: 6pt)
  cdraw.content((20.5, 5.0), [`s`: dead, `t`: the owner], size: 6pt)
  cdraw.line((17.6, 5.4), (5.3, 5.4), stroke: luma(140), mark: (end: ">"))
  cdraw.content((11.4, 5.6), [the move retitles the same graph, no bytes copied on the heap], size: 6pt)
})

A move is a change of title, not a traversal. The heap buffer stays
put, the header on the stack may be copied, and the source name loses
the right to touch anything.

== the double free, prevented

The reason moves exist is the double free. If `let s2 = s1;` copied a
`String` naively, both names would own one heap buffer, and both
drops would free it. C walks this exact cliff in every manual
allocator call, #xref-to("c-os-cloud", "heap") is the corpus chapter
on that side. Rust's answer is to make assignment cheap and the
source dead, and using the source afterwards is the compile error:

#snippet(
  "fn main() {\n"
  + "    let s1 = String::from(\"hello\");\n"
  + "    let s2 = s1;\n"
  + "    println!(\"{s1}, {s2}\");\n"
  + "}\n",
  lang: "rust",
)

The compiler answers with `error[E0382]: borrow of moved value: s1`,
and the full diagnostic is worth reading once, it teaches the model:

#snippet(
  "error[E0382]: borrow of moved value: `s1`\n"
  + "  | let s1 = String::from(\"hello\");\n"
  + "  |     -- move occurs because `s1` has type `String`,\n"
  + "  |        which does not implement the `Copy` trait\n"
  + "  | let s2 = s1;\n"
  + "  |     -- value moved here\n"
  + "  | println!(\"{s1}, {s2}\");\n"
  + "  |        ^^ value borrowed here after move\n"
  + "help: consider cloning the value if the performance cost is\n"
  + "      acceptable: `let s2 = s1.clone();`\n",
  lang: "text",
)

Three annotations, one per line of the story: the type is not `Copy`
so this is a move, the value moved at the assignment, and the borrow
came after. The suggested clone is one of the two exits, the other is
chapter 6's reference, and the error code families map onto the two,
E0382 for using a moved owner, E0502 and friends for overreaching
borrows.

== moves in practice

Passing by value moves into the callee, returning moves back out, and
a moved out name can be re-bound fresh. `mem::take` and `mem::replace`
are the sanctioned surgeries when a moved out hole must be filled
immediately, take leaves the `Default` value behind since 1.40:

#listing("rust/samples/src/Ch05/Moves.rs", first: 13, last: 37, caption: [move in, move out, and the return path back to the caller])

#listing("rust/samples/src/Ch05/Moves.rs", first: 39, last: 67, caption: [take, replace, re-binding, and the partial move that empties one field])

The partial move is worth a pause: moving `pair.0` out of a tuple
leaves the tuple half alive, `pair.1` stays usable, and the tuple as a
whole cannot be moved or dropped by name afterwards, only its
remaining fields.

== copy types and the Copy boundary

`Copy` is a promise that duplication is memcpy, nothing more, and the
compiler polices the boundary. A type is `Copy` when all its fields
are `Copy` and it has no `Drop` implementation, and the built-ins that
qualify are the scalars, shared references, function items and
pointers, tuples and arrays of `Copy`, and closures that capture only
`Copy` values, that last one since 1.26:

#listing("rust/samples/src/Ch05/CopyTypes.rs", first: 29, last: 78, caption: [struct, tuple, array, reference, function pointer, and Copy closure copies, all measured])

The mirror side fails loudly. A struct holding a `String` cannot
derive `Copy`, the error is `E0204`, this field does not implement
`Copy`. Implementing `Copy` on a type with a destructor is `E0184`,
`Copy` not allowed on types with destructors, and the reason is the
model itself: if assignment copied silently, the destructor would run
twice on the same resource:

#snippet(
  "#[derive(Clone, Copy)]\n"
  + "struct T {\n"
  + "    f: String,\n"
  + "}\n",
  lang: "rust",
)

`Clone` is the explicit deep copy for everything that cannot be
`Copy`. When a type implements both, `Copy` is the fast path
assignment uses and `clone()` stays available for spelling it out.
The sample proves a `String` clone is independent, mutating the clone
leaves the original untouched:

#listing("rust/samples/src/Ch05/CopyTypes.rs", first: 81, last: 97, caption: [Clone as the explicit deep copy, independence measured])

#callout("note", "copy changes semantics, not layout", [
  A `Copy` struct still occupies its bytes, the sample measures
  `size_of::<Point>()` at 8. What changes is what assignment means,
  duplicate the bytes and keep both names alive, versus retitle and
  kill the source name.
])

== drop order, demonstrated

Drop is deterministic. Locals drop in reverse declaration order,
struct fields drop in declaration order after the struct's own `Drop`
body ran, tuple fields in order, array elements first to last, and
assignment drops the value it overwrites on the spot. The sample logs
every drop into a mutex and asserts the exact 17 element sequence:

#listing("rust/samples/src/Ch05/DropOrder.rs", first: 17, last: 39, caption: [the probe types, two structs, one with a Drop body and one without])

#listing("rust/samples/src/Ch05/DropOrder.rs", first: 41, last: 72, caption: [the scene and the mid scene snapshot, only three drops ran before scope end])

#listing("rust/samples/src/Ch05/DropOrder.rs", first: 75, last: 123, caption: [the full sequence asserted, plus the six orderings stated as separate checks])

#diagram([drop order rules as one picture], length: 13pt, {
  let rules = (
    ([locals], [reverse declaration order], [`c`, `b`, `a`]),
    ([struct fields], [declaration order], [`head`, `foot`]),
    ([with Drop], [own body first, fields after], [`frame`, `head`, `foot`]),
    ([array], [first to last], [`e0`, `e1`, `e2`]),
    ([tuple], [in order], [`t0`, `t1`]),
    ([assignment], [old value on the spot], [`old` drops at the =]),
  )
  for (i, row) in rules.enumerate() {
    let y = 5.2 - i * 1.05
    cdraw.rect((0.3, y - 0.5), (4.6, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((2.45, y), row.at(0), size: 6pt)
    cdraw.content((10.0, y), row.at(1), size: 6.5pt)
    cdraw.content((18.6, y), row.at(2), size: 6pt)
  }
})

`drop(x)` from the prelude is the explicit form, and `mem::forget`
exists at the other extreme, it leaks on purpose. What no safe code
can do is observe a value after its drop or drop it twice.

This is RAII with teeth, resource acquisition is initialization, the
C++ discipline, but enforced instead of encouraged. The type owns the
resource, the scope owns the type, and the brace on the way out is
the destructor call. Locks, file handles, and buffers all ride the
same rails in the standard library, which is why this chapter's rules
matter more than any single API, they are the discipline every
wrapper in chapter 12 and chapter 13 depends on.

== ownership at function boundaries

The parameter and return types of a function publish its ownership
contract. By value means the callee owns and destroys, `&T` means it
reads, `&mut T` means it writes, and returning an owned value hands
the title back. Reading a signature is therefore reading the memory
story, no comments required:

#snippet(
  "fn owned(name: String) -> String        // takes title, gives title back\n"
  + "fn shared(text: &str) -> usize         // reads, returns a plain value\n"
  + "fn exclusive(list: &mut Vec<u8>)       // writes in place\n"
  + "fn made() -> Box<u32>                  // allocates and hands over\n",
  lang: "text",
)

The sample's `round_trip` and `take_ownership` are the two ends of
that table, and `mem::take` is the bridge, move the value out through
a `&mut`, leave a usable default behind, keep both sides happy.

== Box, the first heap allocation

`Box<T>` is the owned pointer, one allocation, one owner, and the
first unsized-aware type this book meets. It is one machine pointer
wide, moving it moves the pointer while the heap payload stays at the
same address, which the sample measures directly:

#listing("rust/samples/src/Ch05/BoxAlloc.rs", first: 15, last: 47, caption: [heap versus stack addresses, and the address stability across a move])

#listing("rust/samples/src/Ch05/BoxAlloc.rs", first: 49, last: 78, caption: [nested boxes, the boxed slice fat pointer, and leak since 1.26])

`Box::leak` surrenders the destructor and returns a reference that
outlives everything, the escape hatch that turns owned data into
`'static` data, chapter 6 picks that thread up. Chapter 12 owns the
rest of the smart pointer family, `Rc`, `Arc`, and the rest.

== closures capture ownership

A closure body uses outer variables, and the capture is itself an
ownership decision. A plain closure borrows what it can, a `move`
closure takes title to everything it mentions, and a closure that
consumes its capture can only run once, which is the `FnOnce` bound
the sample threads through a generic function. Chapter 10 owns the
full closure story, the `Fn` `FnMut` `FnOnce` ladder and the trait
mechanics, this is the ownership preview:

#listing("rust/samples/src/Ch05/ClosureMoves.rs", first: 17, last: 45, caption: [borrow by default, move on request, FnOnce when consumed])

#listing("rust/samples/src/Ch05/ClosureMoves.rs", first: 46, last: 60, caption: [Copy captures make Copy closures since 1.26, and a Vec travels whole])

The capture mode decides which of the three closure traits a closure
satisfies, and the traits are a ladder. A closure that only reads its
captures can run any number of times, `Fn`. One that writes through
them needs them by mutable reference, `FnMut`, still callable
repeatedly as long as it owns the call slot. One that consumes a
capture, moving it out of the closure environment, runs exactly once,
`FnOnce`, and the sample's `consume_once` demands exactly that bound.
The compiler picks the least demanding fit from how the body treats
each capture, and the `move` keyword only changes where the captures
live, never the fit:

#diagram([capture mode decides the trait, the ladder from FnOnce up to Fn], length: 13pt, {
  cdraw.rect((0.4, 3.4), (7.4, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 5.05), [`FnOnce`], size: 6.5pt)
  cdraw.content((3.9, 4.35), [consumes a capture], size: 6pt)
  cdraw.content((3.9, 3.9), [runs once], size: 6pt)
  cdraw.line((7.4, 4.5), (8.4, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.4, 3.4), (15.4, 5.6), fill: luma(242), radius: 0.02)
  cdraw.content((11.9, 5.05), [`FnMut`], size: 6.5pt)
  cdraw.content((11.9, 4.35), [writes through captures], size: 6pt)
  cdraw.content((11.9, 3.9), [repeats under a lock], size: 6pt)
  cdraw.line((15.4, 4.5), (16.4, 4.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((16.4, 3.4), (23.4, 5.6), fill: luma(248), radius: 0.02)
  cdraw.content((19.9, 5.05), [`Fn`], size: 6.5pt)
  cdraw.content((19.9, 4.35), [reads only], size: 6pt)
  cdraw.content((19.9, 3.9), [copies freely], size: 6pt)
  cdraw.content((11.9, 2.2), [every closure satisfies everything below its fit, callers take the narrowest bound they need], size: 6pt)
})

sources: the rust book's ownership chapter,
doc.rust-lang.org/stable/book/ch04-01-what-is-ownership.html, the
reference's destructors page for every drop order rule, special types
and traits for the Copy boundary, constant and static items, accessed
2026-10-13 against the pinned 1.99.0 offline rust-docs set. the E0382,
E0204, and E0184 texts quoted here were produced by rustc probes run
2026-10-13 on the pinned toolchain, and closures implementing Copy
since 1.26 is from the release log in the same offline set. claims
verified by the Ch05 sample suite, 52 checks under
`tools/run-rust-samples.ps1 -Chapter Ch05`.
