#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= generics and macros

Generics in rust are erased by compilation, not by runtime. Every
concrete type argument becomes its own machine code copy, and the
alternative, `dyn Trait` from chapter 8, stays one copy behind a
vtable. This chapter measures that fork with a counter of
instantiations, then covers const generics since 1.51, phantom types,
and the two macro systems, `macro_rules!` in full and proc macros in
prose. The comparison with #xref-to("go", "generics") is instructive:
go erases at compile time with dictionaries and shared code, rust
duplicates, the trade is binary size and inlining against one body.

== monomorphization versus dynamic dispatch

One generic function, three integer types, one trait object path.
`type_name::<T>` since 1.38 names each instantiation, and function
pointer addresses prove the compiler emitted distinct code per type:

#listing("rust/samples/src/Ch09/Dispatch.rs", first: 37, last: 43, caption: [one static generic, one dynamic entry point])

#listing("rust/samples/src/Ch09/Dispatch.rs", first: 45, last: 70, caption: [the measurement: type names, three addresses, one dyn address])

The counter at the end of the sample walks the stamped names and
counts 3 distinct values for 3 types. The dyn path pays two words per
call site for the fat pointer, chapter 8's measurement, and one
indirect call per method, while the static path pays zero at runtime
and one machine code copy per type in the binary. Neither is free,
the cost just moves:

#diagram([where the dispatch cost lands], length: 13pt, {
  pane(0.3, 11.3, 7.2, [generics, monomorphized], [3 types in, 3 copies out], [call is direct], [binary grows])
  cdraw.line((11.6, 4.2), (12.4, 4.2), stroke: luma(100), mark: (end: ">>"))
  pane(12.7, 23.3, 7.2, [dyn, one copy], [vtable per type pair], [call is indirect], [binary flat])
  cdraw.content((11.8, 1.6), [measured: 3 distinct addresses, 1 dyn address], size: 6pt)
  cdraw.content((11.8, 0.5), [type_name counter reads 3 for 3 types], size: 6pt)
})

`impl Trait` in return position, since 1.26, is the same static
story with the type hidden: the function returns one concrete type
the caller cannot name, which is why `impl Iterator` cannot branch
into two different concrete iterators at runtime. Chapter 10 uses it
for adapter chains.

== bounds, where, and the turbofish

Bounds travel in three places. Inline after the parameter,
`<T: Squared>`, in a `where` clause below the signature, and as
`impl Trait` in argument or return position. The `where` form is
not style, it is the only one that scales, conditional bounds and
bounds on associated types read naturally there:

#snippet(
  "fn blend<N>(a: Vector<f32, N>, b: Vector<f32, N>) -> Vector<f32, N>\n"
  + "where\n"
  + "    N: std::ops::Mul<usize>,\n"
  + "    Vector<f32, N>: Clone,\n"
  + "{\n"
  + "    a\n"
  + "}\n"
  + "// the same signature inline would drown in one line,\n"
  + "// and bounds on whole generic types only fit in where\n",
  lang: "rust",
)

Multiple bounds stack with `+`, `T: Clone + Send`, and any number of
bounds can pile onto one parameter. When inference cannot pick the
type, the call site names it with the turbofish, `parse::<i64>()` or
`collect::<Vec<u32>>()`, the `::<T>` operator saying instantiate
here. Chapter 10 leans on it for `collect`, and the const generic
sample used `repeat::<u16, 3>` for the same reason, two parameters,
one inference hole.

Generic impls follow the same grammar: `impl<T: Copy, const N:
usize> Vector<T, N>` is a block parameterized over `T` and `N`,
covering every element type and length at once, while `impl<const
N: usize> Vector<i64, N>` covers one element type at every length.
The second form is how the sample gave the dot product to integer
vectors only.

== const generics since 1.51

Type parameters may be joined by constant parameters, `struct
Vector<T, const N: usize>`, stable since 1.51 in the minimal form:
integer, bool, and char constants. The length is part of the type,
so dimension errors are compile errors:

#listing("rust/samples/src/Ch09/ConstGenerics.rs", first: 13, last: 36, caption: [a fixed length vector, the length a const parameter])

The `dot` product takes another `Vector<i64, N>` with the same `N`.
Hand it a different length and the types simply do not unify, no
runtime check exists to fail. The sample measures the consequences:
each length is its own sized type, 12 bytes for `Vector<f32, 3>`,
and the type names stamp the length:

#listing("rust/samples/src/Ch09/ConstGenerics.rs", first: 38, last: 54, caption: [a per-length dot product, a const generic function, a const fn using the parameter])

#snippet(
  "let a: Vector<i64, 3> = Vector::filled(1);\n"
  + "let b: Vector<i64, 2> = Vector::filled(1);\n"
  + "a.dot(&b);\n"
  + "// error[E0308]: mismatched types, expected `Vector<i64, 3>`\n"
  + "// found `Vector<i64, 2>`\n",
  lang: "rust",
)

Before 1.51 the standard library shipped arrays at every power of
two length through macros, `HashMap`'s `K: Borrow<str>` world had no
part in it, and crate authors wrote type level integers with nested
structs. The const parameter collapsed all of that.

The stable slice is still minimal. Parameters accept only integers,
`bool`, and `char`, and complex const expressions in the type
position, generic `N + 1`, live on nightly. Two neighbors filled the
space around it: generic associated types, GATs, landed in 1.65 so a
trait can have a type constructor as an associated item, the shape
lending iterators need, and `type_name` from 1.38 lets a sample
print exactly which instantiation exists, the counter this chapter
opened with.

== phantom data and zero sized markers

A type parameter must be used or the compiler rejects the struct,
E0392, because an unused parameter says nothing checkable. The
escape is `PhantomData<T>`, a zero sized marker that declares how
the type relates to `T` without holding one. The standard use is
typestate, ids that can never be mixed:

#listing("rust/samples/src/Ch09/PhantomData.rs", first: 19, last: 35, caption: [a phantom keyed id type for two entity kinds])

`Id<User>` and `Id<Order>` are different types at zero memory cost,
measured: both are exactly 8 bytes, the size of the raw `u64`. The
marker also steers the auto traits, and the choice of marker matters:
`PhantomData<fn() -> T>` keeps the wrapper `Send` and `Sync` for any
`T` because fn pointers are, while `PhantomData<T>` would inherit
`T`'s own impls and `PhantomData<*mut T>` would poison both:

#listing("rust/samples/src/Ch09/PhantomData.rs", first: 37, last: 52, caption: [a function accepting only the user id, send and sync helpers, a second marker type])

The `is_send` and `is_sync` helpers compile only when the bound
holds, so a passing check is a proof. `PhantomPinned`, chapter 12's
subject, is the same trick aimed at `Unpin`.

== macro_rules: repetition and specifiers

`macro_rules!` matches token trees and rewrites them. A rule is
pattern followed by expansion, repetitions with `$(...),*` and
friends, and fragment specifiers that constrain what a metavariable
may match. One real macro from the samples does the rounds:

#listing("rust/samples/src/Ch09/Macros.rs", first: 13, last: 30, caption: [a struct generating macro, repetition over field name and type pairs])

The `$(,)?` tail allows an optional trailing comma. The expansion
emits one struct field per repetition and one `stringify!` per field
in the labels function, measured in the output. Specifiers used
here: `ident` for names, `ty` for types, `expr` for expressions,
`tt` for single token trees, `item` for whole items. The rest of the
family is `pat`, `path`, `literal`, `stmt`, `block`, `vis`,
`lifetime`, and `meta`, and since 1.53 `pat_param` exists because
`pat` itself is scheduled to change meaning across editions:

#listing("rust/samples/src/Ch09/Macros.rs", first: 32, last: 59, caption: [recursion over tokens, three specifiers in one rule, nested repetition])

The `count!` macro recurses: one rule matches empty for the base
case, the other peels a `tt` and adds 1. `grid!` nests two
repetitions, the outer over rows, the inner over cells. Macros in
type position have worked since 1.13, so `Vec<count!()>` style uses
are legal, if unwise.

== hygiene

Each macro expansion lives in its own syntactic context. A `let`
written inside a macro body cannot collide with a variable of the
same name at the call site, because the two identifiers are
different symbols to the compiler even though they spell the same:

#listing("rust/samples/src/Ch09/Macros.rs", first: 48, last: 53, caption: [a macro local named shadowed])

#listing("rust/samples/src/Ch09/Macros.rs", first: 92, last: 100, caption: [the caller's shadowed survives the expansion untouched])

The flip side is that a macro cannot accidentally reach into caller
scope either: identifiers it invents stay private to the expansion.
The escape hatch is passing names in, `$name:ident`, the way `bump!`
takes `answer`. Item-level definitions are exempt, the `struct
Reading` from `record!` is visible afterwards, which is exactly why
the macro could write a type the rest of the file uses.

Two more rules finish the picture. `$crate` names the crate that
defined the macro, so an exported macro can call `::$crate::helper`
and resolve correctly from any caller, the reason std macros work
from every module. And fragment specifiers have a follow set: after
`$e:expr` the compiler permits only certain tokens, `=>`, `,`, `;`,
before it can decide where the expression ends, which is why
`$e + 1` is a compile error in a rule, the `+` is not in `expr`'s
follow set. The reference table lists them per specifier, and the
practical takeaway is to end each metavariable with a clear
separator rather than splice it into an expression.

== proc macros in brief

`macro_rules!` rewrites token trees on syntactic shape alone. Proc
macros are rust functions that receive a `TokenStream` and return
one, compiled as a separate crate and run by the compiler. Four
kinds exist: function-like (`sqlx::query!`), attribute
(`#[tokio::main]`), derive (`#[derive(Serialize)]`), and since the
derive kind stabilized in 1.15 as macros 1.1 it is the everyday one.
No proc macro runs in this book's samples, the runner compiles
single files with plain rustc, but what a derive generates is worth
naming once. For chapter 8's `Config`:

#snippet(
  "#[derive(Debug)]\n"
  + "struct Config { name: String, retries: u32 }\n"
  + "// expands to the equivalent of:\n"
  + "impl std::fmt::Debug for Config {\n"
  + "    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {\n"
  + "        f.debug_struct(\"Config\")\n"
  + "            .field(\"name\", &self.name)\n"
  + "            .field(\"retries\", &self.retries)\n"
  + "            .finish()\n"
  + "    }\n"
  + "}\n",
  lang: "rust",
)

That is why `format!("{:?}", base)` printed
`Config { name: "gate", retries: 3 }` in chapter 8: the derive wrote
a method per field, calling the same builder the hand impl would.

#callout("verify", "the counter is the chapter", [
  The instantiation count, the distinct code addresses, the zero
  byte markers, and the 12 byte vector all come from
  `rust/samples/src/Ch09`, 38 checks green under
  `pwsh -NoProfile -File tools/run-rust-samples.ps1 -Chapter Ch09`
  on rustc 1.99.0 edition 2024, measured 2026-10-13.
])

sources: doc.rust-lang.org/stable/book ch10.01 generic data types
for monomorphization, reference/items/generics.html for type
parameters, const parameters, bounds, and where clauses, book ch19
macros and the macro_rules reference chapter
macros-by-example.html, reference/macros.html for fragment
specifiers, follow sets, and hygiene, releases.md for 1.13 macros in
type position, 1.15 custom derive, 1.26 impl trait, 1.38 type_name,
1.51 const generics and addr_of, 1.53 pat_param, 1.65 gats, all read
from the offline oracle at
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html,
accessed 2026-10-13, cross-checked against doc.rust-lang.org/stable
url forms.
