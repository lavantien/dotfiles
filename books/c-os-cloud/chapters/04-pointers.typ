#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= pointers, arrays, and memory

Every object in C is three things at once: storage that occupies bytes,
a value held in those bytes, and an address where the storage starts. A
pointer is itself an object whose value is such an address. This chapter
pins that split with checks, follows the array through its decay into a
pointer, reads restrict as a promise the caller makes to the compiler,
measures alignment through `alignof` and `_Alignas` up to the allocation
calls windows actually ships, and closes with compound literals and
designated initializers, the two initializer forms that keep aggregate
data readable. Every number below comes from a check that ran or a probe
on this machine, dated 2026-09-12.

== pointers, arrays, decay

The sample opens by separating the array from the pointer that points
into it. `sizeof a` is `5 * sizeof(int)` because `sizeof` sees the object,
the whole storage, not a pointer to it. The pointer `p` is a different
object: its own address differs from the address it holds, and its size
is one pointer's worth, 8 bytes on this target where chapter 1 asserted
8-byte pointers, against 20 bytes of array. Four checks, one contrast:

#listing("c-os-cloud/samples/src/Ch04/pointers.c", first: 46, last: 76, caption: [object against pointer, decay, and arithmetic as index math])

Decay is the rule that an array expression becomes a pointer to its
first element nearly everywhere. `a == &a[0]` holds after decay, and
`(void *)&a == (void *)&a[0]` holds too: taking the array's address and
taking the first element's address produce the same address value.
`sizeof` is the exception the sample exercises where decay does not
happen, which is why `sizeof a` still measures all 20 bytes while every
other use of `a` hands a pointer to whoever asks. The call inside the
third check hands one across the function boundary:

#listing("c-os-cloud/samples/src/Ch04/pointers.c", first: 20, last: 27, caption: [the callee receives a pointer, so sizeof sees a pointer])

The parameter is declared `int *p`, and `sizeof(p)` inside equals
`sizeof(int *)`. An array declared as a parameter would decay at the call
anyway, and the gate refuses `sizeof` on an `[]`-declared parameter
outright under -Wsizeof-array-argument, so the pointer spelling is the
honest one. Arithmetic then reduces to index math: `a + 2` is the
address of `a[2]`, `*(a + 2)` is `a[2]`, the difference `&a[3] - &a[1]`
counts elements, and the byte distance between the same two addresses
is `2 * sizeof(int)` once the pointers are cast to `char *`. Byte math
goes through `char *` because the standard defines no arithmetic on
`void *`: clang accepts `vp + 1` as a silent GNU extension even under the
gate's -Werror, and only `-pedantic -Werror` rejects it with
-Wgnu-pointer-arith (probed 2026-09-12), so the discipline is a habit
the gate does not enforce. The loop at the end walks from `a` to the
one-past-the-end address `a + 5`: forming, comparing, and adding to
that address is defined, dereferencing it never happens.

The second half widens the same rules. Any object pointer converts to
`void *` and back without loss, which is the round trip malloc's `void *`
return relies on. A two dimensional array nests: `sizeof m` is six
ints, `sizeof m[0]` is three, `m` decays to a pointer that steps one
row at a time, so `*(*(m + 1) + 2)` is `m[1][2]`, and the last element
of row 0 sits immediately before the first element of row 1. A string
literal used as an array initializer builds a modifiable 3-byte copy of
"hi" including the terminating zero, while a pointer to a literal is
just an address:

#listing("c-os-cloud/samples/src/Ch04/pointers.c", first: 78, last: 97, caption: [void round trip, row-wise decay of a 2d array, literal copy versus literal pointer])

#diagram([the object, the pointer object, and what decay hands over], length: 13pt, {
  // the array object: five ints with byte offsets
  for i in range(5) {
    cdraw.rect((1.0 + i * 2.2, 5.4), (1.0 + (i + 1) * 2.2, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((2.1 + i * 2.2, 5.95), [#((10, 20, 30, 40, 50).at(i))], wrap: text.with(size: 7pt))
    cdraw.content((2.1 + i * 2.2, 5.0), [a#i: +#(i * 4)], wrap: text.with(size: 6pt))
  }
  cdraw.content((6.5, 4.35), [the object: 20 bytes, int is 4], wrap: text.with(size: 6pt))
  cdraw.content((6.5, 3.7), [one contiguous block], wrap: text.with(size: 6pt))

  // the pointer object, elsewhere, holding the array's address
  cdraw.rect((14.5, 6.55), (23.8, 8.0), fill: luma(215), radius: 0.02)
  cdraw.content((19.15, 7.7), [p, one pointer object], wrap: text.with(size: 6pt))
  cdraw.content((19.15, 7.05), [value \&a\[0\], 8 bytes], wrap: text.with(size: 6pt))
  cdraw.content((19.1, 6.15), [own address \&p elsewhere], wrap: text.with(size: 6pt, fill: luma(120)))
  cdraw.line((15.4, 6.55), (2.1, 6.55), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.7, 6.95), [p holds the array's start], wrap: text.with(size: 6pt))

  // the three-way split as a legend band
  let legend(x, l1, l2) = {
    cdraw.rect((x, 1.75), (x + 7.2, 3.2), fill: luma(245), radius: 0.02)
    cdraw.content((x + 3.6, 2.85), l1, wrap: text.with(size: 6pt))
    cdraw.content((x + 3.6, 2.1), l2, wrap: text.with(size: 6pt))
  }
  legend(0.8, [object: the storage], [what sizeof measures])
  legend(8.7, [value: 10 20 30 40 50], [what reads return])
  legend(16.6, [address: the start], [what pointers hold])
  cdraw.content((12.2, 1.35), [decay: a becomes \&a\[0\] almost everywhere,], wrap: text.with(size: 6.5pt))
  cdraw.content((12.2, 0.7), [checked exceptions: sizeof, unary \&], wrap: text.with(size: 6.5pt))
})

== restrict and aliasing promises

Two functions in the sample differ by one qualifier. `scale` promises
nothing: its `dst` and `src` may alias, so calling it with the same
buffer on both sides is defined, each element read before it is
written. `scale_restricted` adds `restrict` to both parameters, a
promise from the caller that for the entire execution of the call,
every access to the objects `dst` reaches goes through `dst`, and
every access to the objects `src` reaches goes through `src`:

#listing("c-os-cloud/samples/src/Ch04/pointers.c", first: 29, last: 44, caption: [two loops, one contract apart])

The promise buys the optimizer freedom: it may cache loads, reorder,
and vectorize without proving the two streams disjoint, because the
caller has sworn they are. This chapter claims the contract, not a
speedup, and leaves the ir evidence for chapter 5, where the noalias
metadata this qualifier produces is read directly. Clang's own c status
page states the caveat: restrict support is fully conforming, but llvm
applies its optimization semantics for function parameters, not for
local variables or data members. Both uses in this sample are
parameters.

main then exercises exactly the calls each contract allows. The plain
call scales `vals` in place, 1 2 3 4 becoming 10 20 30 40. The
restricted twin runs only on disjoint buffers and produces the same
values. `scale_restricted(vals, vals, 10, 4)` would be the same call
shape with a broken promise, undefined behavior, and this book does not
execute undefined behavior to show it. The library carries the same
split in its prototypes: `memmove(text + 2, text, 5)` shifts "abcdefg"
into "ababcde" because, per the microsoft docs, memmove ensures the
original source bytes in the overlapping region are copied before being
overwritten, while the memcpy page states that if the source and
destination regions overlap, the behavior of memcpy is undefined, use
memmove instead:

#listing("c-os-cloud/samples/src/Ch04/pointers.c", first: 99, last: 121, caption: [the legal call for each contract, and the library's own split])

#callout("verify", "the broken promise is never executed", [
  The one interesting call this chapter does not make is
  `scale_restricted(vals, vals, 10, 4)`. The promise is false for that
  call, the standard says undefined behavior, and running it would
  prove nothing about any other compiler or day. Chapter 5 takes the
  same discipline further: the noalias metadata the promise produces
  in llvm ir, read as evidence, never executed as a bug.
])

#diagram([one call shape, two contracts, and where each is legal], length: 13pt, {
  // left panel: no promise, one buffer, two roles
  cdraw.rect((0.5, 4.7), (11.6, 8.1), stroke: luma(180), radius: 0.02)
  cdraw.content((6.0, 7.75), [scale: no promise], wrap: text.with(size: 6pt))
  for i in range(4) {
    cdraw.rect((1.3 + i * 2.4, 5.4), (1.3 + (i + 1) * 2.4, 6.5), fill: luma(235), radius: 0.02)
    cdraw.content((2.5 + i * 2.4, 5.95), [#((10, 20, 30, 40).at(i))], wrap: text.with(size: 7pt))
  }
  cdraw.rect((1.3, 6.55), (10.9, 7.15), stroke: (paint: luma(120), dash: "dashed"), radius: 0.02)
  cdraw.content((6.1, 6.85), [dst and src, one object: vals], wrap: text.with(size: 6pt))
  cdraw.content((6.0, 5.0), [in place: read then write], wrap: text.with(size: 6pt))

  // right panel: the promise, two objects
  cdraw.rect((13.0, 4.7), (24.1, 8.1), stroke: luma(180), radius: 0.02)
  cdraw.content((18.5, 7.75), [scale_restricted: disjoint only], wrap: text.with(size: 6pt))
  for i in range(4) {
    cdraw.rect((13.8 + i * 2.4, 6.1), (13.8 + (i + 1) * 2.4, 7.0), fill: luma(215), radius: 0.02)
    cdraw.content((15.0 + i * 2.4, 6.55), [#((10, 20, 30, 40).at(i))], wrap: text.with(size: 7pt))
    cdraw.rect((13.8 + i * 2.4, 5.0), (13.8 + (i + 1) * 2.4, 5.9), fill: luma(235), radius: 0.02)
    cdraw.content((15.0 + i * 2.4, 5.45), [#((1, 2, 3, 4).at(i))], wrap: text.with(size: 7pt))
  }

  // the library's split, and the line never crossed
  cdraw.content((12.2, 3.6), [the library split: memmove defined on overlap, memcpy not], wrap: text.with(size: 6pt))
  cdraw.content((12.2, 2.8), [restrict is that same promise spelled in a parameter list], wrap: text.with(size: 6pt))
  cdraw.content((12.2, 2.0), [the aliased restrict call is undefined, never executed], wrap: text.with(size: 6pt))
})

== alignment and aligned allocation

Alignment is a promise about the low bits of an address: an object with
alignment 8 starts at an address divisible by 8. `alignof` measures it,
and the probed fundamentals on this target are char 1, int 4, double 8.
A struct takes the strictest alignment among its members and pads to
make every member sit correctly: `struct mixed` with a char, a double,
and a char has alignment 8, the double lands at offset 8 behind seven
pad bytes, and the size rounds up to 24 so the next object in an array
of them is aligned too:

#listing("c-os-cloud/samples/src/Ch04/align.c", first: 21, last: 34, caption: [one padded struct, one over-aligned struct, one static placement])

`_Alignas(32)` on a member lifts the whole struct: alignof(struct over)
is 32 and the size rounds to 32 around 16 bytes of payload. The linker
honors the lift for static storage and the compiler honors it on the
stack, both checked by taking addresses modulo 32. Plain malloc stops
at the fundamental alignment: the microsoft docs state malloc returns
storage suitably aligned for any object whose alignment requirement is
at most the fundamental alignment, which for visual c++ is the
alignment of a double, 8 bytes, and 16 bytes in code that targets
64-bit platforms. The check asserts the returned pointer is a multiple
of 16. Thirty-two was never malloc's to promise:

#listing("c-os-cloud/samples/src/Ch04/align.c", first: 36, last: 58, caption: [probed alignments, the padding arithmetic, and where malloc stops])

Above that line is the windows truth. `_aligned_malloc(size,
alignment)` from `<malloc.h>` takes an alignment the docs require to be
an integer power of 2 and returns a pointer that is a multiple of it,
NULL on failure. Its memory returns to the heap only through
`_aligned_free`: the docs' own words for using free instead are that it
"doesn't reclaim the aligned memory correctly and can lead to
hard-to-diagnose bugs". The sample allocates a struct over at 32,
writes through both ends of the block, frees it with `_aligned_free`,
then asks for 64 to show the request scales with the power of two. The
same docs mark malloc and `_aligned_malloc` with `__declspec(noalias)`
and `__declspec(restrict)`, promising the fresh block is not aliased: the
allocator's return and the restrict qualifier are two spellings of one
aliasing discipline.

#listing("c-os-cloud/samples/src/Ch04/align.c", first: 60, last: 74, caption: [the aligned allocation pair at 32 and 64, freed by `_aligned_free`])

#callout("pitfall", "aligned_alloc is not in ucrt", [
  The standard library has owned `aligned_alloc` since c11. The
  microsoft runtime does not ship it: a one-line call fails at compile
  time under the gate with an implicit-declaration error (probed
  2026-09-12, and gcc 15.2 mingw with -std=c23 rejects it identically
  on this machine). cppreference states the reason: the function is
  not supported in the microsoft c runtime because its implementation
  of free is unable to handle aligned allocations of any kind, and
  `_aligned_malloc` freed by `_aligned_free` is provided instead. A
  defect report against c11, dr460, turned bad-argument calls from
  undefined behavior into a null pointer return, and the c23 wording
  asks only for an alignment the implementation supports. None of
  that changes what this crt links.
])

#diagram([padding inside struct mixed, the 32 byte lift, and the two allocators' promises], length: 13pt, {
  // struct mixed: 24 bytes with padding shaded
  for i in range(24) {
    let f = if i == 0 or i == 16 { luma(225) }
      else if i <= 7 or i >= 17 { luma(245) }
      else { luma(215) }
    cdraw.rect((2.0 + i * 0.55, 6.0), (2.55 + i * 0.55, 7.0), fill: f, radius: 0.02)
  }
  cdraw.content((2.3, 7.4), [tag], wrap: text.with(size: 6pt))
  cdraw.content((5.2, 7.4), [value at 8], wrap: text.with(size: 6pt))
  cdraw.content((8.8, 7.4), [flag], wrap: text.with(size: 6pt))
  for t in ((2.0, [0]), (6.4, [8]), (10.8, [16]), (15.2, [24])) {
    cdraw.content((t.at(0), 5.65), t.at(1), wrap: text.with(size: 6pt, fill: luma(120)))
  }
  cdraw.content((20.2, 6.7), [mixed: alignof 8, sizeof 24], wrap: text.with(size: 6pt))
  cdraw.content((20.2, 6.05), [shaded cells are padding], wrap: text.with(size: 6pt))

  // struct over: 32-aligned, 16 payload bytes
  for i in range(32) {
    let f = if i < 16 { luma(215) } else { luma(245) }
    cdraw.rect((2.0 + i * 0.55, 3.5), (2.55 + i * 0.55, 4.5), fill: f, radius: 0.02)
  }
  cdraw.content((10.0, 3.0), [over: \_Alignas(32), 16 payload], wrap: text.with(size: 6pt))
  cdraw.content((10.0, 2.35), [size rounds to 32], wrap: text.with(size: 6pt))
  cdraw.content((3.6, 4.85), [address 0 mod 32], wrap: text.with(size: 6pt, fill: luma(120)))

  // the two allocators
  cdraw.rect((1.0, 0.05), (11.6, 1.95), fill: luma(245), radius: 0.02)
  cdraw.content((6.3, 1.5), [malloc: fundamental alignment], wrap: text.with(size: 6pt))
  cdraw.content((6.3, 0.9), [16 bytes on x64 per the docs], wrap: text.with(size: 6pt))
  cdraw.rect((12.6, 0.05), (23.2, 1.95), fill: luma(225), radius: 0.02)
  cdraw.content((17.9, 1.6), [\_aligned\_malloc(size, 32):], wrap: text.with(size: 6pt))
  cdraw.content((17.9, 1.0), [a multiple of 32], wrap: text.with(size: 6pt))
  cdraw.content((17.9, 0.4), [freed by \_aligned\_free], wrap: text.with(size: 6pt))
})

== compound literals and designated initializers

Designated initializers name what they initialize. `struct point p =
{.z = 3, .x = 1}` sets two fields out of order and leaves `y` zero.
`.min.x` and `.max.y` descend through nested members. `[4] = 9` and
`[1] = 5` punch holes in an array and the gaps read as zero. `[2].y`
and `[0].x` combine both kinds on an array of structs. The zeroing is
part of the form, checked for a struct, for a nested member, and for
array gaps:

#listing("c-os-cloud/samples/src/Ch04/compound.c", first: 52, last: 70, caption: [field, nested, array, and combined designators, gaps zero])

Against the memberwise habit: three assignments reach the same three
values, and the check compares the two objects field by field. The
initializer form still wins in practice, because the assignment
sequence leaves any forgotten member uninitialized while the
initializer form zeroes it:

#listing("c-os-cloud/samples/src/Ch04/compound.c", first: 72, last: 79, caption: [designated initializer against memberwise assignment, equal values])

A compound literal is an unnamed object written as a value:
`(struct point){.x = 20, .y = 3, .z = 4}` creates the object in place
and passes it by value to `sum3`, whose return proves the fields
arrived. The literal is an lvalue, so its address can be taken.
Lifetime is the load-bearing fact: at block scope the literal lives
for the current execution of the enclosing block, so the sample
captures `trio` at the top of a block, runs an unrelated call, then
reads the literal again at the bottom, and a loop body re-enters its
block each iteration with the literal re-initialized, `i` and `i * 10`
arriving fresh every pass. The standard deals in three storage
durations: automatic, tied to the enclosing block's execution, static,
tied to the whole program run, and allocated, claimed from `malloc`
and returned by `free`. At file scope the rule changes: a compound
literal evaluated outside a function has static storage duration, the
rule cppreference records under c23 6.5.2.5, which is why the `trip`
pointer initialized at lines 17-18 of the sample is readable at any
point in main, and the closing check reads it:

#listing("c-os-cloud/samples/src/Ch04/compound.c", first: 81, last: 105, caption: [by value, by address, block lifetime, per-iteration re-initialization])

The struct-of-arrays idiom is where the two forms meet. `struct cols`
holds one array per field, the initializer fills column by column, and
the row-wise walk over the same storage totals 124 both ways, one by
loop and one by the column-summing `total`. The whole table also
travels by value as a single compound literal argument. C23 grew
storage-class specifiers inside compound literals, `(static int[]){...}`;
clang's c status page marks that proposal unimplemented, so this
chapter keeps the classic spelling:

#listing("c-os-cloud/samples/src/Ch04/compound.c", first: 107, last: 127, caption: [column-wise initialization read back row-wise, a by-value table, the file scope literal])

#diagram([two spellings of one initialization, and the two lifetimes of a compound literal], length: 13pt, {
  // left: memberwise versus designated
  cdraw.rect((0.6, 5.6), (11.4, 7.6), fill: luma(248), radius: 0.02)
  cdraw.content((6.0, 7.25), [memberwise, three statements], wrap: text.with(size: 6pt))
  cdraw.content((6.0, 6.6), [mw.x = 4; mw.y = 5; mw.z = 6], wrap: text.with(size: 6pt))
  cdraw.content((6.0, 5.95), [forgotten members stay unset], wrap: text.with(size: 6pt))
  cdraw.rect((0.6, 3.2), (11.4, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 4.85), [designated, one initializer], wrap: text.with(size: 6pt))
  cdraw.content((6.0, 4.2), [d = \{.x = 4, .y = 5, .z = 6\}], wrap: text.with(size: 6pt))
  cdraw.content((6.0, 3.55), [unmentioned fields are zeroed], wrap: text.with(size: 6pt))
  cdraw.content((6.0, 2.6), [equal values, checked field by field], wrap: text.with(size: 6pt, fill: luma(120)))

  // right: lifetimes as bands over the program timeline
  cdraw.rect((12.4, 6.25), (23.8, 7.55), fill: luma(215), radius: 0.02)
  cdraw.content((18.1, 7.15), [file scope: static storage], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 6.5), [spans the whole program], wrap: text.with(size: 6pt))
  cdraw.rect((13.4, 4.45), (22.8, 5.75), fill: luma(235), radius: 0.02)
  cdraw.content((18.1, 5.35), [block scope literal:], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 4.7), [entry to closing brace], wrap: text.with(size: 6pt))
  cdraw.content((14.2, 4.1), [captured at top], wrap: text.with(size: 6pt, fill: luma(120)))
  cdraw.content((22.0, 4.1), [read at bottom], wrap: text.with(size: 6pt, fill: luma(120)))
  cdraw.line((12.4, 2.5), (23.8, 2.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.1, 2.15), [program time], wrap: text.with(size: 6pt, fill: luma(120)))
  for i in range(3) {
    cdraw.rect((13.4 + i * 3.2, 3.0), (15.4 + i * 3.2, 3.8), fill: luma(245), radius: 0.02)
    cdraw.content((14.4 + i * 3.2, 3.4), [iter #i], wrap: text.with(size: 6pt))
  }
  cdraw.content((18.1, 1.5), [each iteration re-enters the block], wrap: text.with(size: 6pt))
  cdraw.content((18.1, 0.85), [and the literal re-initializes], wrap: text.with(size: 6pt))
})

sources: learn.microsoft.com malloc, `_aligned_malloc`, `_aligned_free`,
memcpy, and memmove pages (fundamental alignment 8, 16 on 64-bit; power
of two alignment; the `_aligned_free` pairing; the memcpy overlap
prohibition), clang.llvm.org c language status page (c23 partial,
restrict conforming for parameters, compound literal storage class
specifiers unimplemented), cppreference compound literal and
`aligned_alloc` pages (storage duration rule, c23 6.5.2.5, the ucrt
absence and its stated reason), all accessed 2026-09-12; alignment
values, the `aligned_alloc` and void pointer arithmetic compile probes,
and header behavior probed on this machine the same day. Sample
behavior verified by `make verify-c`, 47 checks in chapter 4 of the
samples suite.
