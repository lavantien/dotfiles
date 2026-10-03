#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= c sharp answers

The c sharp round rewards the same move as the go round, naming the
mechanism under the keyword. Every answer here floors to the
csharp-net manual: async owns the state machine, typesystem owns
boxing, memory and allocation own the heap, linq owns the deferred
plan, and the code side of these questions already runs gated in
this book's c sharp workspaces, chapters 2, 3, 5, and 6. These
four sections are the spoken layer over that floor: the answer to
say out loud, the follow-up to expect, and the concession to
volunteer first.

== async await machinery: state machines and context [DRILL]

Await does not wait. The compiler rewrites an async method into a
state machine: the locals become fields, each await is a suspension
point where the machine records its place, hands the unfinished
task back to the caller, and registers the rest of the method as a
continuation, #xref-to("csharp-net", "async"). The thread is
released at the suspension, which is the entire win, outstanding
work with no thread parked against it. What resumes, and where, is
the context question. By default the continuation is posted back
to the captured SynchronizationContext, the ui thread in a desktop
app, the request context in classic server code, and
ConfigureAwait(false) skips the capture and resumes on the thread
pool, which is why library code calls it everywhere and
application code at the top usually does not. Blocking against
suspending, said precisely: awaiting an incomplete task suspends
the machine and frees the thread, reading Result or calling Wait
on that same task parks a thread that does nothing. The classic
deadlock is sync over async on a context, the ui thread calls
Result, the continuation must post to the very context the Result
call is blocking, and neither side moves. Async void is the twin
trap, nothing can await it and its exceptions take down the
process, so it stays reserved for event handlers. The follow-up is
ValueTask, answered as the allocation-avoiding refinement for
paths that usually complete synchronously.

#callout("pitfall", "the deadlock is the context, not the task", [
  Result, Wait, and GetAwaiter().GetResult on an incomplete task
  burn a thread unconditionally, and where a SynchronizationContext
  exists they deadlock outright: the continuation is queued to the
  very context the blocking call holds. Await instead, all the way
  up, and let library code ConfigureAwait(false) its way out of the
  capture.
])

#diagram([suspension frees the thread, a blocked context waits on itself], length: 13pt, {
  // left: the machine suspends, the thread returns, the task completes and resumes; right: the deadlock ring
  cdraw.content((5.8, 11.0), [the state machine], size: 6.5pt)
  cdraw.rect((0.3, 9.5), (3.4, 10.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((1.85, 9.95), [caller], size: 6pt)
  cdraw.line((3.4, 9.95), (4.1, 9.95), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((4.1, 9.5), (7.4, 10.4), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((5.75, 9.95), [await: suspend], size: 6pt)
  cdraw.line((7.4, 9.95), (8.1, 9.95), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.1, 9.5), (11.3, 10.4), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((9.7, 9.95), [thread to pool], size: 6pt)
  cdraw.content((5.8, 8.6), [the rest of the method is a continuation], size: 6pt)
  cdraw.line((5.8, 9.0), (5.8, 7.9), stroke: (paint: luma(150), dash: "dashed"), mark: (end: ">"))
  cdraw.rect((3.3, 6.8), (8.3, 7.9), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((5.8, 7.35), [task completes, resume], size: 6pt)
  cdraw.content((5.8, 6.1), [posted to the context, or to the pool when the await is configured away], size: 6pt)
  cdraw.content((17.6, 11.0), [the deadlock ring], size: 6.5pt)
  cdraw.rect((13.0, 9.3), (22.2, 10.2), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.6, 9.75), [ui thread, blocked in Result], size: 6pt)
  cdraw.rect((13.0, 7.3), (22.2, 8.2), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((17.6, 7.75), [continuation queued to the context], size: 6pt)
  cdraw.line((14.8, 9.25), (14.8, 8.25), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.2, 8.72), [holds], size: 6pt)
  cdraw.line((20.4, 8.25), (20.4, 9.25), stroke: luma(100), mark: (end: ">"))
  cdraw.content((21.0, 8.72), [waits for], size: 6pt)
  cdraw.content((17.6, 6.1), [each side waits on the other, nothing moves], size: 6pt)
})

== linq as an embedded dsl [DRILL]

Linq is the functional core of c sharp worn as syntax. Query
syntax, from where select, is sugar the compiler translates into
exactly the method calls, Where OrderBy Select chained as
extension methods, one compiler output however it is spelled,
#xref-to("csharp-net", "linq"). Under the whole thing sit
iterators: a query expression builds a plan, nothing runs, and
each operator wraps its source in another enumerable that hands
out one element at a time on demand. That is deferred execution,
and it cuts both ways. The good edge is composition, filter and
project and group cheaply, materialize once at the end. The bad
edge is multiple enumeration: every enumeration re-runs the plan
against the current data, so a query enumerated twice over a list
that changed in between gives two different answers, and a query
over a store re-issues the work per pull. The operators that
return something other than IEnumerable, ToList, ToArray,
ToDictionary, First, Count, Any, Sum, execute immediately and
materialize, which is the lever: keep the query deferred while
composing, snapshot it once when the answer must be stable, and
never hand a live query to code that expects a snapshot. The
follow-up is the paradigm question, answered by owning it: this is
the same map filter reduce trio the paradigms chapter drills,
#xref-to("repertoire", "paradigms"), closure over a captured local
included, with the purity test being no stage writing into its
input.

#diagram([two spellings collapse into one chain, and every enumeration runs the plan again], length: 13pt, {
  // top: query syntax and method syntax meet in one extension-method chain; bottom: two pulls, two executions
  cdraw.rect((0.4, 9.4), (9.2, 10.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((4.8, 9.9), [query syntax], size: 6pt)
  cdraw.rect((12.6, 9.4), (21.4, 10.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.0, 9.9), [method syntax], size: 6pt)
  cdraw.line((4.8, 9.4), (9.2, 8.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.0, 9.4), (12.6, 8.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.4, 7.5), (15.4, 8.5), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((10.9, 8.0), [one extension method chain, a plan], size: 6pt)
  cdraw.content((10.9, 6.6), [nothing has run yet], size: 6pt)
  cdraw.line((8.6, 6.9), (6.4, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.4, 6.2), [first pull], size: 6pt)
  cdraw.line((13.2, 6.9), (15.4, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.4, 6.2), [second pull, data changed], size: 6pt)
  cdraw.content((10.9, 5.0), [each enumeration runs the plan again, two different answers], size: 6pt)
})

== value versus reference, boxing [DRILL]

A value type variable holds its data, a reference type variable
holds a reference to an object on the heap, and assignment is
where the difference surfaces: assigning a struct copies the whole
value so the copies diverge, assigning a class copies the
reference so both names watch one object mutate,
#xref-to("csharp-net", "typesystem"). Boxing is the seam between
the two worlds: casting a value type to object or to an interface
it implements allocates a box on the heap and copies the value in,
the box is separate storage so mutations after the copy never
reach it, and each box is an allocation the collector must later
track. It hides in plain sight, non generic collections,
interface-typed calls inside numeric loops, interpolation in older
shapes. Generics are the first cure and the reason they exist:
`List<int>` stores ints unboxed, and variance conversions are
reference conversions, so a sequence of int cannot be read as a
sequence of object without a wrapper, the compiler refusing the
free version precisely because it would box. The escape hatch
below that is the stack-only family: stackalloc reserves a buffer
on the stack, a span over it is a window onto that memory with no
heap allocation, and the cost is the discipline, a stack-only type
cannot be boxed, cannot be stored on the heap, cannot survive an
await, #xref-to("csharp-net", "memory"). When the question turns
to hot paths the answer is the ladder: keep values in generic
containers, span over stackalloc or pooled arrays for buffers,
#xref-to("csharp-net", "allocation"), and treat every object-typed
boundary as a box minted per call.

#diagram([assignment copies the value, an interface cast copies it into a heap box, spans stay off the heap], length: 13pt, {
  // three panels: the struct copy, the interface box, the span over a stackalloc buffer
  cdraw.content((5.8, 11.0), [value, assignment copies], size: 6.5pt)
  cdraw.rect((0.4, 9.4), (3.4, 10.3), fill: luma(230), stroke: luma(120), radius: 0.02)
  cdraw.content((1.9, 9.85), [a: 10], size: 6pt)
  cdraw.rect((8.2, 9.4), (11.2, 10.3), fill: luma(230), stroke: luma(120), radius: 0.02)
  cdraw.content((9.7, 9.85), [b: 10], size: 6pt)
  cdraw.line((3.4, 9.85), (8.2, 9.85), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.8, 10.6), [b = a], size: 6pt)
  cdraw.content((5.8, 8.6), [b.x = 5 leaves a alone], size: 6pt)
  cdraw.content((5.8, 7.2), [boxing, the interface cast], size: 6.5pt)
  cdraw.rect((0.4, 5.6), (3.4, 6.5), fill: luma(230), stroke: luma(120), radius: 0.02)
  cdraw.content((1.9, 6.05), [int 10], size: 6pt)
  cdraw.rect((8.2, 5.6), (11.2, 6.5), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((9.7, 6.05), [the box, heap], size: 6pt)
  cdraw.line((3.4, 6.05), (8.2, 6.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((5.8, 6.8), [copy in], size: 6pt)
  cdraw.content((5.8, 4.8), [mutating 10 after changes nothing], size: 6pt)
  cdraw.content((17.4, 7.2), [the span route], size: 6.5pt)
  cdraw.rect((13.0, 5.6), (16.2, 6.5), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((14.6, 6.05), [stackalloc buffer], size: 6pt)
  cdraw.line((16.2, 6.05), (17.6, 6.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.4, 6.05), [span, a window], size: 6pt)
  cdraw.content((17.4, 4.8), [no heap allocation, and it cannot cross an await], size: 6pt)
})

== the gc generations against go's [DRILL]

The dotnet collector is generational and compacting, the go
collector is concurrent and non compacting, and the honest answer
contrasts the designs rather than ranking them. Dotnet: new
objects allocate into generation 0 by bumping a pointer in a
reserved segment, collections fire most often there because most
objects die young, survivors are promoted to generation 1 and then
2, and each collection marks the live objects, relocates them, and
compacts the freed space, which is what keeps the allocation
pointer a bump and survivors local to each other,
#xref-to("csharp-net", "memory"). Objects of 85,000 bytes or more
allocate directly on the large object heap, not compacted by
default because copying that much is its own cost problem,
#xref-to("csharp-net", "allocation"). Go: concurrent tri-color
mark and sweep, non generational, non compacting, with
sub-millisecond stop-the-world pauses at both ends of the cycle
and pacing by GOGC and GOMEMLIMIT rather than by generations,
#xref-to("repertoire", "go-runtime"). What each buys, said out
loud: compaction buys locality and a permanent bump allocator but
pays pauses proportional to the surviving set it moves, and dotnet
hides those behind background collection of generation 2 plus the
workstation against server configurations; non compacting buys go
the tiny pause and a collector that runs beside the mutator, and
pays fragmentation, free memory no sweep ever makes contiguous
again, with escape analysis as the compiler's part, keeping what
it can on the stack so the heap never sees it. The follow-up is
always which is faster, refused as asked: the two collectors
optimize different costs, and the honest comparison names the
workload, allocation-heavy and short-lived against long-lived and
large.

#diagram([dotnet compacts survivors up the generations, go sweeps concurrently and moves nothing], length: 13pt, {
  // left: the gen ladder with the uncompacted large heap below; right: the concurrent cycle with stop-the-world marks at both ends
  cdraw.content((5.2, 12.4), [dotnet, generational and compacting], size: 6.5pt)
  cdraw.rect((0.4, 10.6), (3.2, 11.5), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((1.8, 11.05), [gen 0], size: 6pt)
  cdraw.line((3.2, 11.05), (3.8, 11.05), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((3.8, 10.6), (6.6, 11.5), fill: luma(230), stroke: luma(120), radius: 0.02)
  cdraw.content((5.2, 11.05), [gen 1], size: 6pt)
  cdraw.line((6.6, 11.05), (7.2, 11.05), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.2, 10.6), (10.0, 11.5), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((8.6, 11.05), [gen 2, full], size: 6pt)
  cdraw.content((5.2, 11.9), [survives, survives again], size: 6pt)
  cdraw.content((5.2, 9.9), [mark, relocate, compact], size: 6pt)
  cdraw.rect((0.4, 8.0), (10.0, 8.9), fill: luma(252), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((5.2, 8.45), [large object heap, 85000 bytes and up, not compacted], size: 6pt)
  cdraw.content((17.8, 12.4), [go, concurrent and non compacting], size: 6.5pt)
  cdraw.rect((13.4, 10.6), (22.2, 11.5), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.8, 11.05), [the mutator, running], size: 6pt)
  cdraw.rect((13.4, 8.9), (22.2, 9.8), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((17.8, 9.35), [tri-color mark, then sweep], size: 6pt)
  cdraw.content((17.8, 10.0), [concurrent, beside the mutator], size: 6pt)
  cdraw.rect((12.9, 8.9), (13.4, 11.5), fill: luma(140), stroke: luma(120), radius: 0.02)
  cdraw.rect((22.2, 8.9), (22.7, 11.5), fill: luma(140), stroke: luma(120), radius: 0.02)
  cdraw.content((17.8, 8.0), [stop-the-world at both ends, sub-millisecond], size: 6pt)
  cdraw.content((17.8, 6.9), [no generations, no compaction, pacing by GOGC and GOMEMLIMIT], size: 6pt)
})

floored to the csharp-net manual: #xref-to("csharp-net", "async")
for the state machine and the rules that keep async honest,
#xref-to("csharp-net", "linq") for the two spellings and the
deferred plan, #xref-to("csharp-net", "typesystem") for value
against reference and boxing, #xref-to("csharp-net", "memory") for
spans, stackalloc, and the generational heap,
#xref-to("csharp-net", "allocation") for the large object heap and
the pools, with go's side carried by
#xref-to("repertoire", "go-runtime").
