#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= memory and runtime

Chapter 3 established the value versus reference split. This chapter is
about what the runtime does with those two worlds: how the garbage
collector organizes the heap, and how the language hands you controlled
ways to step around allocation when a hot path needs it, spans,
`stackalloc`, `ref` passing, and `ref struct`. None of it requires
`unsafe`.

== the garbage collector

The GC is generational and compacting. New objects allocate in
generation 0, cheaply, by bumping a pointer in a reserved segment.
Collections happen most often in generation 0, because most objects die
young, survivors are promoted to generation 1 and then 2, and each
collection marks live objects, relocates them, and compacts the freed
space. Generation 2 collections are the expensive full collections.
Objects of 85,000 bytes or more allocate directly on the large object
heap, which by default is not compacted because copying that much is
its own cost problem. The suite watches a promotion happen:

#listing("csharp-net/samples/src/Ch10/Memory.cs", first: 56, last: 63, caption: [a fresh object, a forced collection, a promotion])

#flow(
  [the generational heap, survivors climb, big objects stay put],
  node((0, 1.2), [gen 0]),
  node((2.2, 1.2), [gen 1]),
  node((4.4, 1.2), [gen 2, full collections]),
  node((0.4, -1.2), [large object heap, 85000 bytes and up, not compacted]),
  edge((0, 1.2), (2.2, 1.2), "-|>", label: [survives]),
  edge((2.2, 1.2), (4.4, 1.2), "-|>", label: [survives again]),
  edge((0, 1.2), (0.4, -1.2), "-|>", bend: -30deg, label: [allocated directly]),
)

Two flavors exist. Workstation GC, the default, collects on the
triggering thread and suits client and high density workloads. Server
GC creates a heap and a dedicated high priority collector thread per
logical CPU for throughput. Background GC collects generation 2 on
dedicated threads while generation 0 and 1 collections happen as
needed, and it is on by default. All of this is configuration
(`System.GC.Server`, `ServerGarbageCollection` in the project file),
not code.

#callout("warning", "GC.Collect is a diagnostic", [
  Calling `GC.Collect()` in production code is almost always wrong, it
  forces blocking collections at times the collector did not choose and
  can measurably hurt throughput. It has one legitimate use, measuring
  the reachable heap while investigating a leak. The listing calls it
  for exactly that reason and says so in its comment.
])

What the GC cannot free is anything still referenced. The managed leak
is a rooted object nobody uses, a static cache that only grows, an
event handler never detached, which is the chapter 7 closure leak
wearing a different hat.

== spans

A span is a view over contiguous memory: an array, a string's chars, a
stack allocation, or native memory. Slicing updates a pointer and a
length, no copy happens, and writes through the span reach the
underlying storage:

#listing("csharp-net/samples/src/Ch10/Memory.cs", first: 8, last: 14, caption: [a slice of the middle, doubled through the view])

#diagram([a span is a reference and a length into storage, no copy], length: 13pt, {
  // the array at top, the span view below pointing into its middle
  cdraw.content((2.1, 6.6), [`int[] xs`], size: 6pt)
  for i in range(5) {
    let f = if i >= 2 { luma(205) } else { luma(235) }
    cdraw.rect((1.0 + i * 2.2, 4.8), (3.2 + i * 2.2, 6.0), fill: f, radius: 0.02)
    cdraw.content((2.1 + i * 2.2, 5.4), [#i], size: 6pt)
  }
  cdraw.rect((1.0, 1.2), (12.4, 3.2), fill: luma(230), radius: 0.02)
  cdraw.content((6.7, 2.2), [`Span<int> slice = xs.AsSpan(2, 3)`, #linebreak() a reference and a length, no copy], size: 6pt)
  cdraw.line((5.4, 3.2), (5.4, 4.7), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.7, 0.3), [the elements never move, the view does], size: 6.5pt)
  cdraw.rect((13.4, 4.6), (23.6, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((18.5, 5.5), [writes reach the array: #linebreak() `xs[3]` doubles in place], size: 6pt)
  cdraw.rect((13.4, 2.2), (23.6, 4.0), fill: luma(235), radius: 0.02)
  cdraw.content((18.5, 3.1), [`ReadOnlySpan<char>`: the same #linebreak() view, reads only, no substrings], size: 6pt)
})

`ReadOnlySpan<T>` is the immutable form, and it is the standard answer
to substring churn. Parsing a header with `Substring` allocates a new
string for the digits. Parsing it with a span reads the same characters
in place:

#listing("csharp-net/samples/src/Ch10/Memory.cs", first: 16, last: 22, caption: [slice, trim, parse, zero allocations])

`Span<T>` is a `ref struct`, and the compiler polices its lifetime: it
cannot be boxed, cannot be a field of a class or a normal struct,
cannot cross an `await` or `yield` boundary, and cannot escape the
method whose stack it points into. When a buffer must live on the heap
or cross an async boundary, `Memory<T>` is the wrapper without those
restrictions, and you take the span for the synchronous work inside.

#snippet(
  "Span<int> M()\n"
  + "{\n"
  + "    Span<int> numbers = stackalloc int[3];\n"
  + "    return numbers; // error CS8352: cannot escape the method\n"
  + "}\n",
  lang: "cs",
)

== stackalloc

`stackalloc` reserves memory on the stack frame, which costs nothing at
collection time because the frame just goes away. Inside a `ref struct`
safe context it combines with spans into the standard scratch buffer
pattern, small buffers on the stack, big ones on the heap, one type for
both:

#listing("csharp-net/samples/src/Ch10/Memory.cs", first: 24, last: 35, caption: [the ternary scratch buffer, stack under the limit])

#diagram([stackalloc, stack under the limit, heap above, one span either way], length: 13pt, {
  // the ternary test at top, the two storage paths below, one type beneath both
  cdraw.rect((8.0, 4.6), (14.6, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.3, 5.2), [`xs.Length <= 1024?`], size: 6pt)
  cdraw.line((8.6, 4.6), (3.8, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.2, 4.4), [yes], size: 6pt)
  cdraw.line((14.0, 4.6), (18.8, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.0, 4.4), [no], size: 6pt)
  cdraw.rect((0.2, 1.6), (7.4, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((3.8, 2.6), [`stackalloc int[n]`, #linebreak() the frame dies with it], size: 6pt)
  cdraw.rect((15.2, 1.6), (22.4, 3.6), fill: luma(230), radius: 0.02)
  cdraw.content((18.8, 2.6), [`new int[n]`, #linebreak() gc tracked memory], size: 6pt)
  cdraw.line((3.8, 1.6), (9.2, 1.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.8, 1.6), (14.4, 1.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.8, -0.4), (15.8, 1.4), fill: luma(205), radius: 0.02)
  cdraw.content((11.8, 0.5), [one `Span<int>`, #linebreak() same code both ways], size: 6pt)
  cdraw.content((19.8, -0.1), [the limit is #linebreak() yours to pick], size: 6.5pt)
})

The limit is a judgement call you own, stack space is finite and
environment dependent. Stack allocated memory is uninitialized, so
write before you read, and never put `stackalloc` inside a loop, hoist
the buffer out and reuse it.

== passing by reference

`ref`, `out`, `in`, and `ref readonly` parameters pass a reference to
the caller's storage instead of a copy. `ref` requires the caller to
initialize, `out` makes the callee assign, `in` is a read only
reference that avoids copying large structs. Combined with `readonly
struct`, which guarantees no member can mutate, `in` parameters are
free of defensive copy surprises:

#listing("csharp-net/samples/src/Ch10/Memory.cs", first: 3, last: 4, caption: [a readonly struct with no mutable state to defend])

#listing("csharp-net/samples/src/Ch10/Memory.cs", first: 48, last: 49, caption: [in takes the big struct without copying it])

#diagram([the by-reference modifiers, who initializes and who writes], length: 13pt, {
  // the modifier on the left, its rule and its job to the right
  let rows = (
    ([`ref`], [caller initializes], [both sides read and write]),
    ([`out`], [callee must assign], [results without a tuple]),
    ([`in`], [read only], [big structs, no copies]),
    ([`ref` return], [returns storage], [the caller writes the original]),
  )
  for (i, row) in rows.enumerate() {
    let y = 5.4 - i * 1.3
    cdraw.rect((0.4, y - 0.5), (3.8, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((2.1, y), row.at(0), size: 6pt)
    cdraw.line((3.8, y), (5.0, y), stroke: luma(100), mark: (end: ">"))
    cdraw.content((8.6, y), row.at(1), size: 6.5pt)
    cdraw.content((16.6, y), row.at(2), size: 6.5pt)
  }
  cdraw.content((10.0, 0.0), [`in` plus `readonly struct` is the pair that kills defensive copies], size: 6.5pt)
})

References can also flow back out. A `ref` return hands the caller a
reference to storage the method can see, an array element, a field of a
class. Ref locals rebind with `ref =` and write through to the original:

#listing("csharp-net/samples/src/Ch10/Memory.cs", first: 37, last: 46, caption: [ref return and ref local rebinding])

The test writes `100` through the returned reference and asserts the
array changed. The compiler enforces the safety here: a reference to a
local cannot leave its method, and ref safe contexts are checked at
compile time, so a dangling reference is a compile error, not a crash.

== overflow

Integer overflow wraps silently by default. `checked` and `unchecked`
make the choice per expression or per block, with `checked` throwing
`OverflowException` instead:

#listing("csharp-net/samples/src/Ch10/Memory.cs", first: 51, last: 54, caption: [the same addition, two overflow policies])

#diagram([overflow policy, unchecked wraps silently, checked throws], length: 13pt, {
  // one expression at top, its two policies below
  cdraw.rect((5.8, 4.4), (12.6, 5.6), fill: luma(235), radius: 0.02)
  cdraw.content((9.2, 5.0), [`int.MaxValue + 1`], size: 6pt)
  cdraw.line((6.8, 4.4), (4.3, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.6, 4.4), (14.1, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 1.2), (8.4, 3.2), fill: luma(230), radius: 0.02)
  cdraw.content((4.3, 2.2), [`unchecked`, the default: #linebreak() wraps to `-2147483648`], size: 6pt)
  cdraw.rect((9.8, 1.2), (18.4, 3.2), fill: luma(205), radius: 0.02)
  cdraw.content((14.1, 2.2), [`checked`: #linebreak() throws `OverflowException`], size: 6pt)
  cdraw.content((11.0, 0.0), [the choice is per expression or per block, unchecked is the default], size: 6.5pt)
})

== unsafe in outline

`unsafe` enables pointer types, pointer arithmetic, and `fixed`, which
pins a managed object so the GC cannot move it while native code holds
its address. `sizeof` measures unmanaged types at compile time. This
book treats the pointer surface as interop territory, reached for when
calling native libraries or parsing wire formats byte by byte, and
always behind a safe managed facade. The modern interop path uses
source generated marshalling rather than hand written `fixed` blocks,
covered in chapter 13.

#diagram([fixed pins the object while native code holds its address], length: 13pt, {
  // the fixed statement pins the object inside the heap, the address elbow
  // leaves the heap for native code, the ghost shows where the gc is blocked
  cdraw.rect((0.2, 4.8), (7.6, 6.0), fill: luma(230), radius: 0.02)
  cdraw.content((3.9, 5.4), [`fixed (byte* p = ...)`], size: 6pt)
  cdraw.line((3.2, 4.8), (3.0, 3.2), stroke: luma(100))
  cdraw.content((1.4, 4.35), [pins], size: 6pt)
  cdraw.rect((0.2, 0.6), (10.6, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((2.8, 1.0), [managed heap], size: 6pt)
  cdraw.rect((1.0, 1.7), (4.6, 3.2), fill: luma(205), radius: 0.02)
  cdraw.content((2.8, 2.45), [the object], size: 6pt)
  cdraw.rect((5.8, 0.8), (9.8, 2.4), stroke: (paint: luma(170), dash: "dashed"), radius: 0.02)
  cdraw.content((7.8, 1.6), [where the gc #linebreak() moves it], size: 6pt)
  cdraw.line((4.6, 2.0), (5.8, 2.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.8, 3.2), (3.8, 3.9), stroke: luma(100))
  cdraw.line((3.8, 3.9), (15.0, 3.9), stroke: luma(100))
  cdraw.line((15.0, 3.9), (15.0, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.4, 4.1), [`p`, the raw address], size: 6pt)
  cdraw.rect((12.6, 4.6), (20.2, 6.4), fill: luma(230), radius: 0.02)
  cdraw.content((16.4, 5.5), [native code holds #linebreak() the address `p`], size: 6pt)
  cdraw.content((20.8, 1.6), [`sizeof(T)`, #linebreak() compile time], size: 6.5pt)
})

== the memory safety preview

C\# 15 opens a multi release effort to redefine what `unsafe` means.
The original model ties the `unsafe` context to the existence of
pointers. The updated model ties it to the operations that touch memory
the runtime does not manage, so holding, passing, and returning a
pointer becomes safe code while reading through it stays unsafe. The
first slice ships in this SDK and every claim below was probed on
11.0.100-rc.1, none of it is blog inheritance. With `LangVersion` set
to `preview`: declaring a pointer type, address-of `&`, the `fixed`
statement, a `stackalloc` expression converted to a pointer, and
`sizeof` on an unmanaged type all compile in safe code. Dereference
`*p`, member access `p->m`, element access `p[i]`, and function pointer
invocation still require an `unsafe` context, the probe measured error
CS9360 on a bare `*pointer` in safe code. The preview lives in its own
project because a preview language version must not leak into the main
samples assembly:

#listing("csharp-net/samples/src/CsharpBook.Preview/CsharpBook.Preview.csproj", caption: [the isolated preview project, preview language plus the runtime async toggle])

The relaxations in one slice of the real sample:

#listing("csharp-net/samples/src/CsharpBook.Preview/MemorySafety.cs", first: 10, last: 35, caption: [pointer existence, address-of, fixed, sizeof, stackalloc to pointer, all in safe code])

#diagram([the boundary moved, pointer existence is safe, access is not], length: 13pt, {
  // the operations at top, safe side left, unsafe side right
  let ops = (
    ([`int* p = &x`], true),
    ([`fixed (int* f = a)`], true),
    ([`stackalloc` to pointer], true),
    ([`sizeof(T)`], true),
    ([`*p`, `p->m`, `p[i]`], false),
    ([function pointer call], false),
  )
  for (i, (op, safe)) in ops.enumerate() {
    let y = 5.6 - i * 1.15
    cdraw.rect((0.2, y - 0.5), (9.0, y + 0.5), fill: luma(235), radius: 0.02)
    cdraw.content((4.6, y), op, size: 6pt)
    cdraw.line((9.0, y), (10.2, y), stroke: luma(100), mark: (end: ">"))
    let (x1, fill, label) = if safe { (17.4, luma(205), [safe code]) } else { (19.2, luma(180), [unsafe only]) }
    cdraw.rect((10.4, y - 0.5), (x1, y + 0.5), fill: fill, radius: 0.02)
    cdraw.content(((10.4 + x1) / 2, y), label, size: 6pt)
  }
  cdraw.content((10.2, -1.1), [the existence of a pointer stopped being the risk, the access is the risk], size: 6.5pt)
})

Two more pieces of the preview round it out. The `unsafe(expr)`
expression form scopes an unsafe context to a single expression, which
matters where an `unsafe` block cannot appear syntactically: the probe
compiled it in a field initializer and in a `catch` filter. Both usages
still gate on `AllowUnsafeBlocks`, the probe measured error CS0227 with
it off, while the pure pointer relaxations above compile even with it
off. And the `safe` contextual keyword is recognized as a modifier on
`extern` members and explicit layout struct fields, where the compiler
cannot classify safety itself. The bigger half of the model, caller
unsafe obligations and the assembly opt in, is not enforced at RC1:
marking a member `unsafe` currently has no effect on its callers:

#listing("csharp-net/samples/src/CsharpBook.Preview/MemorySafety.cs", first: 37, last: 57, caption: [the unsafe expression form, in a return and in a field initializer])

== what .NET 10 and 11 changed

The JIT got more aggressive about escaping the heap. Small arrays of
value types and of reference types that provably do not outlive their
method are stack allocated, and escape analysis covers local struct
fields and delegates. The practical effect: code written in the plain
allocation style above gets faster without changing shape, which is
the runtime trend to expect, measure, and let happen rather than
pre-optimizing around.

#diagram([escape analysis, provably local allocations move to the frame], length: 13pt, {
  // the same source shape at top, its two destinations below
  cdraw.rect((5.2, 4.6), (14.8, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((10.0, 5.5), [a local array that provably #linebreak() never escapes its method], size: 6pt)
  cdraw.line((6.4, 4.6), (3.7, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.6, 4.6), (16.3, 3.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.2, 0.4), (7.2, 3.8), fill: luma(230), radius: 0.02)
  cdraw.content((3.7, 2.1), [earlier runtimes: #linebreak() a heap allocation, #linebreak() delegates allocate too], size: 6pt)
  cdraw.rect((12.8, 0.4), (19.8, 3.8), fill: luma(205), radius: 0.02)
  cdraw.content((16.3, 2.1), [.net 10: the stack frame, #linebreak() delegates stop allocating], size: 6pt)
  cdraw.content((11.8, -0.7), [same source shape, the jit moves it under you: measure, do not pre-optimize], size: 6.5pt)
})

.NET 11 adds two more runtime moves worth naming. Runtime Async shifts
async suspension from compiler generated state machines into the
runtime itself. A project opts in with `<Features>runtime-async=on</Features>`,
which no longer needs the preview feature switch on `net11.0`, and the
runtime libraries ship compiled with it on. The cheap part is
demonstrable and demonstrated: the preview project carries the toggle
and its plain `await` code compiles and runs under it on this SDK. The
interesting part, cleaner live stack traces and lower allocation
overhead, stays a release note claim here, this suite does not measure
it. Chapter 9 covers the await model the feature runs underneath. The
JIT side continues the story above: bounds check elimination for the
`i + cns < len` shape and index from end access, and bounds checks
dropped after an empty span guard. Those are release note claims too,
the pattern to apply is the one this chapter keeps repeating, write
the plain shape and let the JIT close the gap.

#listing("csharp-net/samples/src/CsharpBook.Preview/MemorySafety.cs", first: 59, last: 65, caption: [the runtime async toggle demo, plain await shape under runtime-async=on])

sources: learn.microsoft.com, fundamentals of garbage collection,
workstation and server gc, background gc, the large object heap,
memory and span types, span t and readonlyspan t api pages, method
parameters, stackalloc expression, performance with ref safety, and
what's new in the .net 10 runtime pages, accessed 2026-09-08, what's
new in c\# 15 memory safety, unsafe code two models and preview pages,
the safe keyword page, and what's new in the .net 11 runtime page,
accessed 2026-09-13. Sample behavior verified by `make verify-csharp`,
14 tests.
