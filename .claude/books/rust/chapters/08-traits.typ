#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= traits and trait objects

A trait is a set of behaviors a type can adopt, half interface and
half mixin: required methods, optional default bodies, associated
types and constants, and a coherence rule that decides who may
implement what for whom. This chapter covers the whole surface,
defining, deriving, overloading, and then the two dispatch modes,
static generics against `dyn Trait`, with the vtable cost measured.
The `dyn` keyword itself landed in 1.27, supertrait upcasting in
1.86, both checked in `releases.md`.

== defining and implementing

A trait declares methods an implementer must provide and may provide
for them. `Summary` requires `headline`, supplies `preview` as a
default, and adds an associated function that needs a `Sized` bound
because it never sees a value:

#listing("rust/samples/src/Ch08/Defining.rs", first: 13, last: 24, caption: [required method, default method, sized-bounded associated function])

Two types implement it, one riding the default, one overriding:

#listing("rust/samples/src/Ch08/Defining.rs", first: 36, last: 50, caption: [the article impl inherits the default, the chirp impl overrides it])

The default body calls `self.headline()`, a method the implementer
has not written yet. That forward reference is the mixin half: every
impl gets `preview` for free, specialized only where it pays.

== bounds, supertraits, extension traits

`trait Long: Summary` makes `Summary` a supertrait: every `Long` type
is a `Summary` type, and `Long`'s default body freely calls the
supertrait method. The blanket impl below extends every existing
`Summary` in one stroke, which is the extension trait pattern
`Iterator` itself uses, new methods on old types with no changes to
the old code:

#listing("rust/samples/src/Ch08/Defining.rs", first: 52, last: 66, caption: [supertrait, blanket impl, two spellings of the same bound])

`fn announce<S: Summary>` and `fn announce_shorthand(item: &impl
Summary)` compile to the same thing, one static dispatch per concrete
type. The `+ ?Sized` in the blanket impl lets the extension reach
`dyn Summary` too, which is unsized.

== associated types and consts

Methods are the visible half of a trait. The other half is the
associated items a trait can demand: a `type` each impl picks once,
and a `const` each impl fixes at compile time. `Iterator` is the
famous case, one `type Item` instead of a type parameter, so
`Iterator<Item = u32>` reads as a constraint instead of an argument:

#listing("rust/samples/src/Ch08/Defining.rs", first: 68, last: 96, caption: [a channel trait with an associated type, a bound on it, and an associated const])

The `Message` type carries its own bound, `Debug`, which the caller
inherits for free, the sample formats it. The projection syntax
`<Queue as Channel>::Message` names the choice explicitly, and
`C::CAPACITY` reads the const through any bounded generic without a
value in hand. The rule of thumb for the choice: a generic parameter
says the caller picks per call, an associated type says the impl
picks once per type, which is why `Add` has `type Output` while
`HashMap<K, V>` takes parameters.

== coherence and the orphan rule

An impl is legal only if the trait or at least one of the types
belongs to the current crate, and no two impls may overlap. That is
the orphan rule, and it is why the ecosystem cannot deadlock: nobody
can `impl Display for Vec<ForeignType>` from outside both crates, so
no two dependencies can ever ship conflicting impls of the same
trait for the same type.

#snippet(
  "impl std::fmt::Display for Vec<crate::Cfg> { /* .. */ }\n"
  + "// error[E0117]: only traits defined in the current crate can be\n"
  + "// implemented for arbitrary types, both foreign\n",
  lang: "rust",
)

The escape hatches are the newtype pattern, wrap the foreign type in
a local tuple struct and impl on the wrapper, or a local trait that
delegates. Both are ordinary code, no compiler switch involved.

== dyn Trait and the vtable

`dyn Trait` erases the concrete type and keeps the method table. A
`&dyn Glyph` is a fat pointer, data pointer plus vtable pointer, two
words measured in the sample against a plain fn pointer's one:

#listing("rust/samples/src/Ch08/Objects.rs", first: 13, last: 30, caption: [a supertrait pair and two implementers])

#listing("rust/samples/src/Ch08/Objects.rs", first: 60, last: 87, caption: [heterogeneous dispatch, upcast, and the two word measurement])

#diagram([the fat pointer and its vtable], length: 13pt, {
  cdraw.rect((0.5, 5.6), (7.5, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((4.0, 6.3), [#"&dyn Glyph"], size: 6.5pt)
  cdraw.content((2.4, 5.9), [data ptr], size: 6pt)
  cdraw.content((5.6, 5.9), [vtable ptr], size: 6pt)
  cdraw.line((2.4, 5.5), (2.4, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.6, 5.5), (12.0, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.7, 3.2), (4.1, 4.3), fill: luma(250), radius: 0.02)
  cdraw.content((2.4, 3.75), [Dot value], size: 6pt)
  cdraw.rect((11.6, 0.6), (16.4, 4.3), fill: luma(245), radius: 0.02)
  cdraw.content((14.0, 3.9), [vtable for Dot], size: 6pt)
  cdraw.content((14.0, 3.1), [#"drop in place"], size: 6pt)
  cdraw.content((14.0, 2.3), [#"size, align"], size: 6pt)
  cdraw.content((14.0, 1.5), [#"fn name -> \"dot\""], size: 6pt)
  cdraw.content((14.0, 0.8), [#"fn draw -> \"dot 7\""], size: 6pt)
  cdraw.content((6.2, 2.0), [one table per (trait, type) pair], size: 6pt)
  cdraw.content((6.2, 1.0), [every call hops through it], size: 6pt)
})

Trait objects default to `+ 'static` in this position, `Box<dyn
Glyph>` means `Box<dyn Glyph + 'static>`. Not every trait is
dyn-compatible, the current term, object safe in older text. The
disqualifiers are the items a fixed per-type table cannot express:

#snippet(
  "trait Explain {\n"
  + "    fn explain<T: std::fmt::Debug>(&self, value: T);\n"
  + "    fn clone_of(&self) -> Self;\n"
  + "}\n"
  + "let x: Box<dyn Explain> = todo!();\n"
  + "// error[E0038]: the trait `Explain` is not dyn compatible,\n"
  + "// method `explain` has generic type parameters,\n"
  + "// method `clone_of` references the `Self` type in its return\n",
  lang: "rust",
)

A generic method would need one vtable slot per instantiation, which
no fixed table can hold, and returning `Self` by value would promise
the caller a value of a type the caller erased. The standard fixes
split the trait, keeping the object-safe core dyn-compatible and
moving the generic methods to a sibling trait, or add `where Self:
Sized` to the offending methods, the way `Summary::tag` did in the
first listing. Dynamic dispatch versus static is chapter 9's
measured comparison, here the mechanism is the point.

== derived traits

Nine traits can be derived with one attribute line: `Debug`, `Clone`,
`Copy`, `PartialEq`, `Eq`, `PartialOrd`, `Ord`, `Hash`, `Default`.
Each generates the obvious structural implementation:

#listing("rust/samples/src/Ch08/Derive.rs", first: 13, last: 34, caption: [the nine derivable traits across a struct and two enums])

The measurements pin the semantics. `Clone` deep copies, `Copy`
changes assignment from a move to a duplication, enum ordering
follows declaration order so sorting is free, and a set requires
`Eq` on top of `Hash`, the marker trait is not optional:

#listing("rust/samples/src/Ch08/Derive.rs", first: 42, last: 61, caption: [clone, default, and debug checked for exact output])

#listing("rust/samples/src/Ch08/Derive.rs", first: 66, last: 88, caption: [ordering by variant, sorting, enum default since 1.62, the eq plus hash requirement])

`PartialEq` versus `Eq` is a mathematical distinction: partial
equality allows incomparable values, which only `f64` and `f64`
adjacent types actually have through `NaN`. Every other type should
derive both. `#[default]` on an enum variant arrived in 1.62,
`Option<T>` gets `Default` as `None` without any attribute.

Derive is not magic and not exhaustive. The attribute writes the
structural version of each impl, field by field for structs, variant
by variant for enums, and it refuses the cases where no structural
answer exists: `Clone` requires every field be `Clone`, `Default`
requires every field have a `Default`, and a type holding a raw
pointer derives nothing useful for `PartialEq`. Hand impls remain
ordinary code when the semantics need to differ, a `PartialEq` that
compares two floats by epsilon, a `Display` that hides a field:

#snippet(
  "impl PartialEq for Session {\n"
  + "    fn eq(&self, other: &Self) -> bool {\n"
  + "        self.user == other.user\n"
  + "    }\n"
  + "}\n"
  + "// token deliberately excluded, two sessions are the same session\n"
  + "// when they belong to the same user, not when the token matches\n",
  lang: "rust",
)

== operator overloading

Every operator in rust is a trait method in `std::ops`. `+` is
`Add::add`, unary `-` is `Neg::neg`, `[]` is `Index::index`. The
right hand side type is a parameter, so scalar multiplication and
vector addition coexist:

#listing("rust/samples/src/Ch08/Operators.rs", first: 22, last: 56, caption: [add, mul with a foreign rhs, neg, and add_assign])

`Display` is not an operator trait but belongs in the same breath,
it is what `{}` binds to, while `{:?}` stays `Debug`:

#listing("rust/samples/src/Ch08/Operators.rs", first: 58, last: 73, caption: [display impl and an index impl that defines its own bounds])

The compile fails that follow are informative: `2.0 * a` does not
compile because `impl Mul<Vec2> for f64` lives in a foreign crate and
nobody wrote it, and `grid[9]` panics or not purely as the impl
decides, `Index` here wraps around. There is no operator
customization trap: arithmetic cannot overflow silently through
overloads because the operators still go through the same checks the
builtins use, and `==` requires `PartialEq`, it is never built in.

== Any and downcasting

`dyn Any` is the std escape hatch for reflection, a trait object
carrying a `TypeId`. Downcasting borrows, mutates, or consumes:

#listing("rust/samples/src/Ch08/AnyDown.rs", first: 21, last: 45, caption: [is, downcast_ref, and a local struct found by name])

#listing("rust/samples/src/Ch08/AnyDown.rs", first: 60, last: 80, caption: [downcast_mut, consuming downcast, and type id equality])

`Any` requires `'static`, a borrowed `&i32` cannot ride in a
`Box<dyn Any>` because its identity is not its own, so the pattern
trades exact typing for a closed set of expected types. `is`,
`downcast_ref`, and `downcast_mut` all landed in 1.3, the consuming
`Box::downcast` in 1.0.

#callout("verify", "measured, not asserted", [
  Every count in this chapter comes from `rust/samples/src/Ch08`,
  52 checks green under
  `pwsh -NoProfile -File tools/run-rust-samples.ps1 -Chapter Ch08`
  on rustc 1.99.0 edition 2024. The two-word fat pointer, the
  vtable dispatch, the deep clone, the variant ordering, and the
  associated type and const reads are printouts, not documentation
  claims.
])

sources: doc.rust-lang.org/stable/book ch10.02 traits, syntax and
semantics, reference/items/implementations.html for the orphan rule
and coherence, reference/items/associated-items.html for associated
types and consts, reference/types/trait-object.html for dyn trait
objects and dyn compatibility, book/appendix-03-derivable-traits.html
for the nine derivations, releases.md for 1.27 dyn, 1.62 enum
default, 1.86 upcasting, 1.3 any downcasts, all read from the
offline oracle at
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/rust/html,
accessed 2026-10-13, cross-checked against doc.rust-lang.org/stable
url forms.
