#import "../../theme/lib.typ": callout, xref-to, diagram, cdraw

= the transfer answer: java and rust shops

Every shop interview eventually asks it: our stack is java, or rust,
and your record is go and c. The wrong answer apologizes for the
record, the right one runs a method: name the nearest language you
already own, map mechanisms instead of syntax, scope the ramp by
artifacts, and floor every mapping on work this corpus actually
contains. This chapter works both languages, java from the
employment record, rust from the c manual's metal, with the honest
concession up front where a record does not exist.

== the transfer method [DRILL]

First move, name the nearest corpus language, because transfer is
not symmetric and the bridge is specific: java's nearest is c-sharp,
both run on a vm with a runtime gc, both carry generics, a big
standard library, and an embedded query dsl, and the c-sharp answers
chapter already owns most of that ground. Rust's nearest is c, both
put memory layout and lifetimes in the programmer's hands, and the
c manual already teaches the exact bug class rust was built to
retire.

What transfers is mechanisms, never syntax: the memory model, who
frees and when, the concurrency model, threads, green threads, or
event loops, the error channel, exceptions, values, or result types,
the io shape, blocking, async, or reactors, and the debugging
instincts, where profiling attaches and where locks deadlock. A
mechanism understood once is portable, a syntax memorized is worth
one language. What does not transfer is everything mechanical: the
idioms, the toolchain muscle memory, the ecosystem names, the
library lore, and the honest sentence is that the non-transferring
layer is weeks of comfort, not years of understanding.

The ramp is scoped by artifacts, not by weeks: read one service end
to end, then fix small bugs in it, then land one small feature
behind its tests, then take one design review, and each artifact is
checkable by the team the way every claim in this corpus is
checkable by a reader. Saying the ramp as artifacts is the same
discipline as the resume: no invented metrics, a named deliverable
instead of a promise.

#diagram([name the bridge, map the mechanisms, ramp by artifacts], length: 13pt, {
  // a decision flow: nearest language, mechanism map, artifact ramp
  cdraw.rect((0.8, 7.0), (6.6, 8.6), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((3.7, 8.05), [name the bridge], size: 6.5pt)
  cdraw.content((3.7, 7.2), [c-sharp for java,#linebreak()c for rust], size: 6pt)
  cdraw.line((6.6, 7.8), (8.4, 7.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.4, 6.8), (15.6, 8.8), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((12.0, 8.25), [map the mechanisms], size: 6.5pt)
  cdraw.content((12.0, 7.55), [memory, concurrency, errors, io], size: 6pt)
  cdraw.content((12.0, 6.85), [syntax never], size: 6pt)
  cdraw.line((15.6, 7.8), (17.4, 7.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((17.4, 6.2), (23.0, 9.4), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((20.2, 8.75), [the artifact ramp], size: 6.5pt)
  cdraw.content((20.2, 8.0), [read one service,], size: 6pt)
  cdraw.content((20.2, 7.25), [fix bugs, land a feature,], size: 6pt)
  cdraw.content((20.2, 6.5), [then a design review], size: 6pt)
  cdraw.content((12.0, 4.2), [a mechanism understood once is portable,#linebreak()a syntax memorized is worth one language], size: 6pt)
  cdraw.content((12.0, 2.3), [no invented ramp numbers, named deliverables only], size: 6pt)
})

== java, from the record [DRILL]

The record first, because the answer opens there: the FPT stint is
Spring Boot with Avro over PostgreSQL and Kafka on GCP behind
ISO-matched tests, the PALTech work is whitelabel exchange platforms
whose FlowerShop artifact is spring boot JPA on MySQL with an Angular
storefront, and the Dikshatek migration moved legacy Java and .NET
services to Go and NodeJS under behavioral equivalence, which is the
transfer question answered in the harder direction, reading java
well enough to reproduce its behavior in another runtime. That is
the sentence to lead with, then the four mappings.

The gc mapping: the jvm's collectors are generational, betting the
weak generational hypothesis that most objects die young, so a
copying nursery collects short-lived objects cheaply and survivors
graduate to an old generation, with g1 the region-based modern
shape. Go's collector is the opposite bet, one heap, concurrent
tri-color mark and sweep, non-generational, paying sub-millisecond
stops instead of a generational layout,
#xref-to("repertoire", "go-runtime"). The interview sentence: both
trade throughput against pause, the jvm bets on death rates, go
bets on cheap concurrent marking.

The concurrency mapping: java 21 shipped virtual threads, jep 444,
runtime-scheduled onto carrier threads the way goroutines schedule
onto os threads, with one honest caveat the jep itself pins: a
virtual thread inside a `synchronized` block or a native call pins
its carrier, and the scheduler does not compensate by expanding
parallelism, so hot paths migrate to `ReentrantLock`. Go's scheduler
grew up with handoff as the design: a goroutine blocking in a
syscall drops its processor to another thread instead of pinning
it, #xref-to("repertoire", "go-runtime"). Say both and the follow-up
writes itself, the pinning trap is the jep's own text.

The query dsl mapping: java streams are the same embedded language
as linq, deferred until a terminal operation, chained methods over
a sequence, the same traps, re-enumerating an expensive pipeline and
smuggling side effects into a lambda, and the whole answer including
the floor transfers from #xref-to("repertoire", "csharp-answers").
The error mapping: checked exceptions put the failure surface in the
signature, which is a cousin of result types, and the honest stance
is two-sided, they encode what callers must face, and they are also
why so much java wraps them into runtime exceptions and loses the
encoding, the same trade go resolved by returning error values,
#xref-to("repertoire", "go-runtime"). And spring's container is not
magic to unlearn, it is constructor injection with the wiring moved
into a runtime container, the dependency injection
#xref-to("repertoire", "go-testing") already drills, so the transfer
is learning where the wiring lives, not what wiring is.

== rust, from the metal [DRILL]

The concession first, out loud, because a scope concession retires
the attack before it arrives: the register carries no rust
employment, nothing in the record claims it, and what follows is the
mapping, not a resume line. Rust's nearest corpus language is c, and
the c manual is the honest floor: ownership is the compile-time
answer to the exact bug class the manual teaches, use-after-free,
double free, the dangling pointer, #xref-to("c-os-cloud", "heap")
and #xref-to("c-os-cloud", "allocators") for the manual's own
treatment of who frees.

The ownership rules are three, and the rust book states them
plainly: each value has an owner, one owner at a time, the value is
dropped when the owner leaves scope. The consequence is move
semantics, `let s2 = s1` invalidates `s1`, because two owners would
free twice, and passing to a function moves or copies exactly like
assignment. Borrowing is the second half: a reference reads without
owning, many shared borrows or one mutable borrow, never both, and
the checker enforcing that is the type system, compile time, zero
runtime cost. Option and result replace two silences at once, null
and the unchecked throw, and the whole shape, the two carriers and
the railway they compose into, is already built in c in this corpus,
#xref-to("math", "railway").

No gc is a design consequence, not a feature bullet: making freeing
a static fact is what removes the runtime collector, and the price
is that lifetimes become part of function signatures, the borrow
checker part of the build. Go chose the other payment, a concurrent
collector and the freedom to hand aliases around,
#xref-to("repertoire", "go-runtime"). The honest answer to "would
you write rust" is scoped: yes at a security boundary, in wasm, on
embedded, anywhere the c manual's bug class is the incident report
and the pause budget is microseconds, and no for the service shape,
an api over a store, which this corpus shipped six times over in
six runtimes, #xref-to("cookbook", "tags"), none of whose
requirements price rust's compile-time rent.

#diagram([four ways to answer who frees this memory], length: 13pt, {
  // a matrix: manual memory, ownership, go gc, jvm heap
  cdraw.content((12.0, 9.6), [who frees], size: 6.5pt)
  let col(x0, name, who, fail, price) = {
    cdraw.rect((x0, 2.4), (x0 + 5.4, 9.0), fill: luma(240), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 2.7, 8.3), [#name], size: 6.5pt)
    cdraw.content((x0 + 2.7, 7.0), [#who], size: 6pt)
    cdraw.content((x0 + 2.7, 5.4), [#fail], size: 6pt)
    cdraw.content((x0 + 2.7, 3.6), [#price], size: 6pt)
  }
  col(0.6, [c, manual], [you free it, by hand], [dangling pointer,#linebreak()double free], [the discipline is#linebreak()the whole job])
  col(6.5, [rust, ownership], [the compiler frees it,#linebreak()statically], [borrow error,#linebreak()at compile time], [lifetimes in#linebreak()signatures])
  col(12.4, [go, runtime gc], [the runtime frees it,#linebreak()concurrently], [none, paid as#linebreak()sub-ms pauses], [pause budget plus#linebreak()the runtime])
  col(18.3, [jvm, generational], [the runtime frees it,#linebreak()by generation], [leaks through#linebreak()live references], [heap size plus#linebreak()tuning])
  cdraw.content((12.0, 1.3), [ownership is the compile-time answer to the bug class the c manual teaches], size: 6pt)
})

== the traps [DRILL]

Four traps, one honest line each. "Green threads" as if java invented
them in 21: java carried a green-threads experiment decades ago,
dropped it for native threads, and virtual threads in 21 are the
return with a real scheduler and the pinning caveat above, so the
answer that lands names jep 444 and its two pinning cases instead of
the folklore name. "Final means immutable": final locks the
reference, not the object, the instance behind a final field is
still mutable, and the confusion is the same one the value versus
reference drill retires for readonly in c-sharp,
#xref-to("repertoire", "csharp-answers"). "The borrow checker slows
it down at runtime": no, the checks are type system facts settled at
compile time, which is the entire design point, the runtime pays
nothing for the borrow it already proved. "Rust for everything":
no, gc is fine for the service shape, the six-lane corpus is the
existence proof, and rust prices in where the boundary is security
or the pause budget, not where the work is an api over a store,
saying when not rust is part of the transfer answer, the same
concession discipline the whole book drills.

floored to: no employment facts were invented, the record rows are
quoted from the claim register, FPT's spring boot with Avro,
PostgreSQL, Kafka, ISO-matched tests, PALTech's whitelabel exchange
platforms and the spring boot JPA FlowerShop, Dikshatek's legacy
Java and .NET to Go and NodeJS migration under behavioral
equivalence, and the rust concession is the register's own silence.
The mechanisms floor on #xref-to("repertoire", "go-runtime") for
the gc and scheduler contrasts, #xref-to("repertoire",
"csharp-answers") for the linq and value-against-reference bridges,
#xref-to("math", "railway") for option and result,
#xref-to("c-os-cloud", "heap") and #xref-to("c-os-cloud",
"allocators") for the manual memory rust answers, and
#xref-to("cookbook", "tags") for the six-lane service corpus the
when-not-rust trap leans on. The two online pins, jep 444 for
virtual threads and the rust book's ownership chapter, carry their
urls and access dates in the book's source table.
