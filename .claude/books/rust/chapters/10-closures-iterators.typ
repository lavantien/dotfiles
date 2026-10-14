#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= closures and iterators

A closure is a function that captures its environment, and the three
closure traits are three capture contracts stacked: `Fn` reads, `FnMut`
reads and writes, `FnOnce` may consume. An iterator is the consumer
side of the same design, one `next` method at a time, adapters
wrapping adapters until a driver pulls. Nothing in the middle runs.
This chapter measures both claims with counters.

== the three kinds

Every closure the compiler assigns the weakest kind its body permits.
A capture free closure is `Fn`, a closure that mutates its captures is
`FnMut`, one that moves a capture out of itself is `FnOnce`, and the
hierarchy runs `Fn` into `FnMut` into `FnOnce`, so any bound accepts
weaker closures:

#listing("rust/samples/src/Ch10/Kinds.rs", first: 13, last: 27, caption: [three takers and a closure returning factory])

#listing("rust/samples/src/Ch10/Kinds.rs", first: 29, last: 61, caption: [each kind demonstrated, and the hierarchy in action])

The `tally` closure mutates `count` on every call and the captured
state persists across calls, 10 then 15 then 16. `consume` moves
`owned` out, so it can only answer once. `make_adder` returns
`impl Fn(i32) -> i32`, the return position opaque type from chapter 9,
and the returned closure must be reusable, so it has to be `Fn`. A
closure type is a real anonymous struct generated per closure site,
capturing exactly what the body reads, which is why closures
implement `Copy` and `Clone` when all captures do, stable since 1.26
and measured in the next section.

== capture modes, measured

The sample counts borrows with a `Cell` counter and drops with a
static, and the numbers pin the rules down:

#listing("rust/samples/src/Ch10/Capture.rs", first: 16, last: 41, caption: [a pair with a read counter and a loud drop counter])

#listing("rust/samples/src/Ch10/Capture.rs", first: 42, last: 71, caption: [borrow counts, then edition 2021 disjoint capture])

Creating a closure performs no work, the read counter sits at zero
until the first call. Two calls cost four reads, one per method per
call. The disjoint capture block is the edition 2021 change, RFC 2229:
`|| p.left` captures only the `left` field, so `p.right` stays
mutable while the closure is alive, where edition 2018 captured the
whole struct and forbade it. And because `both` captures only shared
references, it is `Copy`, the drop of the binding is a no-op, which
the compiler itself insists on:

#listing("rust/samples/src/Ch10/Capture.rs", first: 72, last: 111, caption: [drop counts for shared and owned captures, and a move closure carrying a reference])

A shared capture leaves the value alive at scope end, one drop. A
`move` closure owns it, the drop lands inside the call. `move` is a
demand, not a kind: moving a `Copy` reference in still leaves the
closure `Fn`, as `owned_reader` shows, carrying a borrowed counter to
four reads across two calls.

#callout("note", "when move is needed", [
  `move` matters at function boundaries: a closure returned from a
  function, or sent to a thread in chapter 13, must own its captures
  because the borrows end when the enclosing scope does. Chapter 5
  covered the move semantics underneath, this is the same rule at the
  closure boundary.
])

== adapters and laziness

An adapter wraps an iterator and returns a new iterator, and none of
them evaluates anything. The sample proves it with a `next` counter:

#listing("rust/samples/src/Ch10/Laziness.rs", first: 14, last: 34, caption: [an iterator that counts every next call])

#listing("rust/samples/src/Ch10/Laziness.rs", first: 36, last: 53, caption: [chain built, zero nexts, collect, two nexts])

The chain reads zero after construction, two after `collect`. `take`
pulled two passing items and stopped, so the underlying `Counting`
was never drained, and `filter` never buffered anything, each pull
walks until one item passes. The `for` loop measurement shows the
same control from the caller side, `break` after two pulls leaves the
iterator mid-stream, and `sum` pays one extra `next` for the closing
`None`:

#diagram([an adapter chain, pulled from the right], length: 13pt, {
  let stage(x, name, first, second) = {
    cdraw.rect((x - 1.75, 0.2), (x + 1.75, 2.2), fill: luma(235), radius: 0.02)
    cdraw.content((x, 1.78), name, size: 6.5pt)
    cdraw.content((x, 1.15), first, size: 5pt)
    cdraw.content((x, 0.62), second, size: 5pt)
  }
  let pull(x) = cdraw.line((x, 1.2), (x + 0.65, 1.2), stroke: luma(100), mark: (end: ">"))
  stage(2.4, [driver], [collect, sum, for], [])
  pull(4.25)
  stage(6.7, [take 2], [counts its yields], [])
  pull(8.55)
  stage(11.0, [filter], [skips non matches,], [never buffers])
  pull(12.85)
  stage(15.3, [map], [one out per in], [])
  pull(17.15)
  stage(19.6, [counting], [next, increments,], [then yields])
})

Building the chain right to left costs nothing, every arrow is a
`next` call that only happens when the driver pulls. The same
structure is why iterators compose in `impl Trait` returns, each
adapter is a concrete type the compiler names for you.

== writing an iterator

Everything above composes because the contract is one method. Any
type with a `next` returning `Option<Item>` is an iterator, and
inherits the entire adapter surface, dozens of methods, for free.
The laziness sample's `Counting` is the whole story in ten lines:

#listing("rust/samples/src/Ch10/Laziness.rs", first: 14, last: 31, caption: [the entire iterator contract: one next method])

`next` advances and reports. `None` means finished forever, the
caller is allowed to stop calling, and returning `Some` after a
`None` is a contract violation the adapters cannot defend against,
so honest iterators keep their own end state, the `remaining == 0`
branch above. The measurement harness, the static counter and the
`nexts` reader, is exactly how this chapter's laziness claims were
pinned.

Two optional traits refine the contract. `DoubleEndedIterator` adds
`next_back`, letting `rev` and `rfind` work, a vec iterator has it,
a stream does not. `ExactSizeIterator` promises `len` is exact,
which unlocks index math in adapters. Both are plain traits, a type
implements them when it honestly can, and the adapters degrade
gracefully when it cannot.

Returning an iterator from a function has two spellings. `impl
Iterator<Item = u32>` returns one unnamed concrete type, zero cost,
but every path in the body must agree on that type. `Box<dyn
Iterator<Item = u32>>` boxes the trait object of chapter 8, one
indirect call per item, but the body may return different concrete
iterators per branch:

#snippet(
  "fn numbers(flag: bool) -> Box<dyn Iterator<Item = i32>> {\n"
  + "    if flag {\n"
  + "        Box::new(0..3)\n"
  + "    } else {\n"
  + "        Box::new(vec![7, 8].into_iter())\n"
  + "    }\n"
  + "}\n"
  + "// two different concrete types, one signature, dyn is the only way\n",
  lang: "rust",
)

== collect and the turbofish

`collect` drives the chain into any container that implements
`FromIterator`, and the target type is inferred from the binding, or
named inline with the turbofish `::<T>`:

#listing("rust/samples/src/Ch10/Collect.rs", first: 15, last: 42, caption: [vec, string, set, and map collection with inference and turbofish])

#listing("rust/samples/src/Ch10/Collect.rs", first: 43, last: 67, caption: [sum, product, fold, partition, chain, and a str iterator])

`String` implements `FromIterator<char>`, maps and sets collect from
zips and mapped pairs, `partition` splits one pass into two vecs, and
string iterators ride the same machinery. The folding family, `sum`,
`product`, `fold`, are also drivers, they just return a scalar instead
of a container.

== iter, iter_mut, into_iter

Three entry methods cover the three borrow modes from chapter 5 and
6. `iter` lends `&T`, `iter_mut` lends `&mut T`, `into_iter` moves
the `T` out:

#listing("rust/samples/src/Ch10/IterKinds.rs", first: 17, last: 43, caption: [borrow, mutate in place, then move out])

Arrays grew `IntoIterator` by value in 1.53, so `[5, 6, 7].into_iter()`
yields `i32` items, while the array itself remains usable because
arrays are `Copy` and the iteration copies elementwise. The `for`
loop itself desugars to `into_iter`, so `for x in &v` borrows and
`for x in v` consumes. `by_ref` lets one iterator be consumed in
pieces:

#listing("rust/samples/src/Ch10/IterKinds.rs", first: 44, last: 68, caption: [by_ref prefix consumption, then find, position, count])

== iterator invalidation

The one mistake the borrow checker catches for you, mutating the
collection while iterating it:

#snippet(
  "let mut v = vec![1, 2, 3];\n"
  + "for x in &v {\n"
  + "    v.push(*x);\n"
  + "}\n"
  + "// error[E0502]: cannot borrow `v` as mutable because it is also\n"
  + "// borrowed as immutable, the iterator holds `&v` across the loop\n",
  lang: "rust",
)

The iterator owns a borrow of the whole vec, `push` needs `&mut`, and
the two cannot overlap. The escape is collecting first,
`let taken: Vec<_> = v.iter().copied().collect();`, then mutating,
or `iter_mut` when the mutation is in place. Languages with iterators
over live references solve this at runtime with invalidation checks
and crashes, rust solved it at the type level.

Closures slot into the same picture as values. A closure type is an
anonymous struct, so it can sit in a struct field, travel through a
vec, or arrive as a function argument with its captures along:

#snippet(
  "struct Pipeline {\n"
  + "    transform: Box<dyn Fn(u32) -> u32>,\n"
  + "}\n"
  + "let bias = 100;\n"
  + "let p = Pipeline { transform: Box::new(move |x| x + bias) };\n"
  + "// the closure owns its copy of bias, the struct owns the closure,\n"
  + "// dyn because the field must accept any closure with this shape\n",
  lang: "rust",
)

The `move` matters here: without it the closure borrows `bias`, and
the borrow cannot outlive the function that built the struct. This
is the callback shape the service chapters build on, a stored
closure with captured configuration, and it is why `Box<dyn Fn>` is
the standard spelling for stored callbacks rather than generics,
the field needs one type, not one type per closure.

sources: doc.rust-lang.org/stable/book ch13.01 closures and the three
fn traits, ch13.02 processing iterators, reference/types/closure.html
for capture precision including wildcard and disjoint field capture,
book ch04.05 or the slices chapter for iter versus into_iter context,
releases.md for 1.26 copy closures, 1.53 array into_iterator, and the
edition 2021 capture changes, all read from the offline oracle at
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html,
accessed 2026-10-13, cross-checked against doc.rust-lang.org/stable
url forms. Every count in this chapter is asserted by
`rust/samples/src/Ch10`, 51 checks green under
`pwsh -NoProfile -File tools/run-rust-samples.ps1 -Chapter Ch10` on
rustc 1.99.0 edition 2024, measured 2026-10-13.
