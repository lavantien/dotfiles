#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= borrowing and lifetimes

Ownership is too expensive to use for every read, so Rust has a second
access path: the reference, written `&T` for shared access and `&mut
T` for exclusive access. The borrow checker enforces one rule pair,
many shared borrows or one exclusive borrow, and lifetimes are the type
system spelling of the question "does the referent outlive the
reference". Together they replace use after free, iterator
invalidation, and data races at their common root, aliasing plus
mutation, #xref-to("c-os-cloud", "machine") is the corpus chapter on
what those bugs cost in a language with no rules.

== shared and exclusive borrows

`&T` promises the target will not change through this path, so any
number of them may coexist. `&mut T` promises this is the only live
path, so exactly one may exist, and it excludes even reads. The
sample runs both sides of each rule:

#listing("rust/samples/src/Ch06/Borrows.rs", first: 17, last: 34, caption: [shared borrows in a crowd, then the owner mutating again after their last use])

#listing("rust/samples/src/Ch06/Borrows.rs", first: 36, last: 57, caption: [one exclusive borrow at a time, sequenced reborrowing, and borrows in function calls])

The exclusivity is about overlap, not count. Two exclusive borrows
that never overlap in time are fine, and the borrow ends at its last
use, not at the end of the lexical scope, which is the next section's
subject.

#diagram([the borrow rules as one matrix], length: 13pt, {
  let cols = ((0.0, 8.2, [while it lives]), (8.2, 16.4, [add another `&`]), (16.4, 23.4, [add a `&mut`]))
  for (x0, x1, head) in cols {
    cdraw.rect((x0, 5.9), (x1, 6.8), fill: luma(205), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 6.35), head, size: 6.5pt)
  }
  let rows = (
    ([shared `&`], [yes, any number], [no, E0502]),
    ([exclusive `&mut`], [no, E0502], [no, E0499]),
  )
  for (i, row) in rows.enumerate() {
    let y0 = 4.9 - i * 1.35
    cdraw.rect((0.0, y0 - 1.1), (8.2, y0), fill: luma(235), radius: 0.02)
    cdraw.content((4.1, y0 - 0.55), row.at(0), size: 6.5pt)
    cdraw.rect((8.2, y0 - 1.1), (16.4, y0), fill: luma(245), radius: 0.02)
    cdraw.content((12.3, y0 - 0.55), row.at(1), size: 6.5pt)
    cdraw.rect((16.4, y0 - 1.1), (23.4, y0), fill: luma(225), radius: 0.02)
    cdraw.content((19.9, y0 - 0.55), row.at(2), size: 6.5pt)
  }
  cdraw.content((11.7, 1.2), [the reference must also stay valid, that half is lifetimes], size: 6.5pt)
})

== the borrow checker, non lexical

The original borrow checker tied a borrow to its lexical scope, the
enclosing block, and rejected code whose borrows clearly died mid
block. The 2018 edition shipped with the fix, the non lexical
lifetime borrow checker that ends each borrow at its last use, so
1.31 is the version that made this compile. The 2015 edition received
the same checker in 1.36, and the old checker was fully retired
after 1.40. Every pattern in the sample would have failed the lexical
checker:

#listing("rust/samples/src/Ch06/Nll.rs", first: 15, last: 33, caption: [the two classic survivors: a borrow that dies before a push, and a block scoped borrow])

#listing("rust/samples/src/Ch06/Nll.rs", first: 35, last: 66, caption: [loop borrows, if let arms, match arms, the shapes that trip newcomers])

#callout("note", "what still fails", [
  A borrow held across the mutation still fails, NLL moved the end of
  the borrow to the last use, it did not remove the exclusivity rule.
  Keeping the borrowed value alive past the push, storing it or
  printing it after, is E0502 and lands in the error section below.
])

== lifetime parameters

A reference type is incomplete without the answer to "outlives what".
The `'a` in `&'a str` names that answer, and it becomes a generic
parameter whenever a function or struct ties references together.
Structs holding references must declare the tie, the parameter bounds
how long the struct may live:

#listing("rust/samples/src/Ch06/StructRefs.rs", first: 13, last: 38, caption: [a struct of borrowed data, its methods, and the longest function with its tie])

The parameter on `longest<'a>` states a constraint, not a fact: the
caller must find one region that covers both inputs and the result.
The sample shows the short side of that bargain, inside a block where
both inputs are alive the result is fine, after the block only the
longer lived input remains:

#listing("rust/samples/src/Ch06/StructRefs.rs", first: 40, last: 77, caption: [call sites satisfying the tie, and the boundary the compiler draws])

== elision, the three rules

Writing `'a` on every signature would be noise, so the compiler infers
elided lifetimes with three rules, applied in order. Rule one, each
elided lifetime in the inputs becomes its own fresh parameter. Rule
two, if there is exactly one lifetime in the inputs, every elided
output lifetime takes it. Rule three, in methods, a receiver of `&self`
or `&mut self` lends its lifetime to every elided output. When the
rules cannot decide, the signature is rejected with E0106:

#listing("rust/samples/src/Ch06/Elision.rs", first: 13, last: 39, caption: [the four signatures, one input, placeholder, two inputs no output, and the self rule])

#snippet(
  "fn longest(s1: &str, s2: &str) -> &str {\n"
  + "    if s1.len() > s2.len() { s1 } else { s2 }\n"
  + "}\n",
  lang: "rust",
)

`error[E0106]: missing lifetime specifier`, and the help text names
the ambiguity exactly, the signature does not say whether the return
is borrowed from `s1` or `s2`. Two inputs, one output, no rule
applies, the tie must be written by hand. The `'_'` placeholder,
stable since 1.26, says "elide here" inside paths where bare elision
is not allowed, and `impl Reader for BufReader<'_>` in impl headers
arrived with the 2018 edition in 1.31:

#listing("rust/samples/src/Ch06/Elision.rs", first: 41, last: 77, caption: [the elided signatures running, fn pointers and trait objects elide the same way])

== static

`'static` is the lifetime of the whole program, the longest region
there is. String literals have it, their bytes sit in the read only
data of the binary. Because a longer lifetime coerces to any shorter
one, a `&'static str` flows anywhere a `&'a str` is wanted, the
subtyping rule the reference states as `&'static str` being a subtype
of `&'a str`:

#listing("rust/samples/src/Ch06/StaticLife.rs", first: 13, last: 27, caption: [literal and static sources of 'static, the coercion target, the bound])

#listing("rust/samples/src/Ch06/StaticLife.rs", first: 29, last: 73, caption: [what qualifies for 'static, what does not, and the leak door since 1.26])

The distinction to keep straight: `'static` on a reference means the
referent lives forever, `'static` in a bound like `T: 'static` means
`T` contains no borrowing shorter than forever, owned data qualifies.
Run time data is not `'static` until `Box::leak` surrenders its
destructor, which trades a drop for a forever reference and should be
a deliberate, rare act.

#callout("pitfall", "lifetime syntax does not change how long anything lives", [
  Writing `'a` in `fn longest<'a>(x: &'a str, y: &'a str) -> &'a str`
  creates no region and shortens no value. The annotations only
  describe the relationships the checker must verify, the actual
  regions come from the call site, where the compiler picks the
  shortest region that satisfies every tie. When a lifetime error
  appears, the fix is in the data flow, move the value earlier, return
  the owned copy, shrink the struct's life, never in the annotations
  themselves.
])

A function returning a borrowed value with no inputs to borrow from
fails before lifetimes even enter the picture, E0106 with a help note
that offers the two real fixes, return owned data or borrow from a
parameter:

#snippet(
  "fn dangle() -> &String {\n"
  + "    let s = String::from(\"hello\");\n"
  + "    &s\n"
  + "}\n",
  lang: "rust",
)

The `&String` return names no source, and even with `'static` spelled
out the body could not produce one, the local `s` dies at the closing
brace. Chapter 12's smart pointers are the toolbox when neither plain
ownership nor plain borrowing fits.

== the error vocabulary

Three error codes cover most borrow checker encounters. E0502 is the
mutability clash, E0499 is the double exclusive, E0597 is the value
that died while borrowed. Each snippet below was compiled on the
pinned toolchain and the quoted line is verbatim rustc output:

#snippet(
  "let mut v = vec![1, 2, 3];\n"
  + "let first = &v[0];\n"
  + "v.push(4);\n"
  + "println!(\"first is {first}\");\n",
  lang: "rust",
)

`error[E0502]: cannot borrow v as mutable because it is also borrowed
as immutable`, with the three annotations: immutable borrow occurs
here, mutable borrow occurs here, immutable borrow later used here.
The last annotation is the load bearing one, deleting the later use
makes the program compile, which is the NLL fix in miniature.

#snippet(
  "let mut i = 0;\n"
  + "let x = &mut i;\n"
  + "let y = &mut i;\n"
  + "*x += 1;\n"
  + "*y += 1;\n",
  lang: "rust",
)

`error[E0499]: cannot borrow i as mutable more than once at a time`,
first mutable borrow, second mutable borrow, first borrow later used.
Again the later use is what makes the overlap real, dropping the last
line lets the second borrow start after the first one ended.

#snippet(
  "let r;\n"
  + "{\n"
  + "    let x = 5;\n"
  + "    r = &x;\n"
  + "}\n"
  + "println!(\"r: {r}\");\n",
  lang: "rust",
)

`error[E0597]: x does not live long enough`, borrowed value does not
live long enough, `x` dropped here while still borrowed, borrow later
used here. This is the dangling reference the compiler refuses to
build.

Reading these diagnostics is a skill worth practicing, the format is
stable across all three: each annotation names a moment, borrow
occurs, borrow later used, value dropped, and the conflict is the span
between two of those moments. Fixing the code means shrinking one
span, moving the last use earlier, or lengthening a life, declaring
the owner outside the block. Slices participate in the same system, a
`&[T]` borrows whatever storage it views, which is why pushing to a
`Vec` through a live slice reference is the same E0502 as the vector
case above, and why the iterator invalidation class of bugs in other
languages does not compile here at all.

#diagram([the borrow graph of the E0597 case, the borrow outlives its referent], length: 13pt, {
  cdraw.rect((0.3, 4.0), (11.0, 5.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.65, 5.35), [outer block timeline], size: 6.5pt)
  cdraw.content((5.65, 4.6), [`r` declared, then used at the println], size: 6pt)
  cdraw.rect((3.0, 1.6), (9.5, 3.1), fill: luma(225), radius: 0.02)
  cdraw.content((6.25, 2.35), [inner block: #linebreak() `x` born, `r = &x`, `x` drops], size: 6pt)
  cdraw.line((6.25, 3.1), (6.25, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.2, 3.55), [the borrow], size: 6pt)
  cdraw.line((2.0, 4.0), (2.0, 1.5), stroke: rgb("#8B0000"))
  cdraw.line((1.7, 1.5), (2.3, 1.5), stroke: rgb("#8B0000"))
  cdraw.line((1.7, 4.0), (2.3, 4.0), stroke: rgb("#8B0000"))
  cdraw.content((1.1, 2.75), [needs], size: 6pt)
  cdraw.content((13.0, 2.9), [the reference wants to reach the println], size: 6pt)
  cdraw.content((13.0, 2.0), [but `x` ended at the brace, E0597], size: 6pt)
})

sources: the rust book's references and borrowing chapter,
doc.rust-lang.org/stable/book/ch04-02-references-and-borrowing.html,
the reference's lifetime elision page and subtyping page, the error
codes index for E0502, E0499, E0597, and E0106, all accessed
2026-10-13 against the pinned 1.99.0 offline rust-docs set. the NLL
history is from the release log in that set, releases.md: the 2018
edition at 1.31, non lexical lifetimes on the 2015 edition at 1.36,
the old borrow checker's exit at 1.39 to 1.40, read 2026-10-13. the
quoted error texts were produced by rustc probes run 2026-10-13 on
~/.rustup/toolchains/stable-x86_64-pc-windows-msvc. claims verified
by the Ch06 sample suite, 39 checks under
`tools/run-rust-samples.ps1 -Chapter Ch06`.
