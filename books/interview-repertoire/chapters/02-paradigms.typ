#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= paradigms: oop, fp, mvc, mvvm, ecs

The paradigm question is a vocabulary check that turns into a depth
probe. The safe answer names the four oop pillars and moves on. The
answer that scores walks the same ground in two languages with
different mechanisms for it, then names the architecture patterns
as variations of where state lives. This chapter drills both halves,
and every file it walks runs under `make verify` in the Go and C\#
workspaces of this chapter.

== oop in go: methods without classes [EWC]

Go has no classes, yet answers every oop question. The four pillars
are encapsulation, abstraction, inheritance, and polymorphism: this
section answers encapsulation and polymorphism without the
keywords, the C\# section adds real inheritance with its override,
and abstraction is the interface story in both. Encapsulation is
a lowercase name, construction is a plain function, and
polymorphism is a method set satisfied implicitly:

#listing("interview-repertoire/samples/ch02-go/oop.go", first: 5, last: 30, caption: [the interface, the unexported struct, the constructor function, the pointer receiver])

#diagram([structural satisfaction: the method sets match, the type never says so], length: 13pt, {
  // left: the interface is only a method set; right: the struct that happens to carry it
  cdraw.rect((0.5, 4.6), (6.5, 6.8), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((3.5, 6.05), [stock], size: 6.5pt)
  cdraw.content((3.5, 4.95), [a method set], size: 6pt)
  cdraw.rect((13.0, 4.6), (21.5, 6.8), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((17.25, 6.05), [inventory], size: 6.5pt)
  cdraw.content((17.25, 4.95), [methods on \*inventory], size: 6pt)
  // the dashed edge is the whole polymorphism story
  cdraw.line((13.0, 5.7), (6.5, 5.7), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((9.75, 6.3), [method sets], size: 6pt)
  cdraw.content((9.75, 5.15), [match, implicit], size: 6pt)
  // embedding below: methods gained wholesale, no override, no call back up
  cdraw.rect((13.0, 1.2), (21.5, 3.7), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((17.25, 3.25), [auditlog], size: 6.5pt)
  cdraw.rect((13.7, 1.6), (20.8, 2.5), fill: luma(230), radius: 0.02)
  cdraw.content((17.25, 2.05), [embedded inventory], size: 6pt)
  cdraw.content((6.5, 2.9), [embedding composes,], size: 6pt)
  cdraw.content((6.5, 1.8), [gains both wholesale,], size: 6pt)
  cdraw.content((6.5, 0.7), [no override, no call up], size: 6pt)
  cdraw.line((10.4, 2.05), (13.0, 2.05), stroke: luma(160), mark: (end: ">"))
})

The two facts interviewers listen for live in the receivers and the
embedding. A pointer receiver means `Count` reads the same struct
`Add` mutates, and a value receiver would not. Embedding is
composition, not inheritance: `auditLog` gains `Count` and `Add`
without redeclaring them, but there is no override, no virtual
dispatch, and no way for the embedded type to call back up:

#listing("interview-repertoire/samples/ch02-go/oop.go", first: 32, last: 55, caption: [embedding gains methods wholesale, the outer type adds its own])

The test suite pins the semantics: the embedded method stays
reachable as `audit.inventory.Count`, and `TotalCount` accepts both
concrete types through the interface without either one declaring
it. When the follow-up comes, the honest concession is that Go
trades subclass polymorphism for interface polymorphism on purpose,
and the template method shape an override enables does not
translate.

== oop in c\#: the keyword version [EWC]

C\# has the keywords the Go answer describes. The same inventory
becomes a class hierarchy with real inheritance, a `virtual` method
overridden through `base.Add`, and an interface satisfied by
declaration rather than implicitly:

#listing("interview-repertoire/samples/ch02-cs/src/Oop.cs", first: 3, last: 31, caption: [inheritance with a real override calling into the base implementation])

#diagram([nominal satisfaction: the header says it, the override calls base], length: 13pt, {
  // same inventory as the go figure, spelled with keywords instead of structure
  cdraw.rect((0.5, 4.6), (6.5, 6.8), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((3.5, 6.05), [istock], size: 6.5pt)
  cdraw.content((3.5, 4.95), [add, count], size: 6pt)
  cdraw.rect((13.0, 4.6), (21.5, 6.8), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((17.25, 6.05), [class item : istock], size: 6.5pt)
  cdraw.content((16.5, 4.95), [virtual add], size: 6pt)
  // the declaration itself is the satisfaction
  cdraw.line((12.9, 5.7), (6.5, 5.7), mark: (end: ">"))
  cdraw.content((9.75, 6.3), [declared in], size: 6pt)
  cdraw.content((9.75, 5.15), [the header], size: 6pt)
  // the subclass overrides through base, the arrow is the inheritance
  cdraw.rect((13.0, 2.2), (21.5, 4.4), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((17.25, 3.85), [class bulkitem : item], size: 6.5pt)
  cdraw.content((17.25, 2.75), [override add, base first], size: 6pt)
  cdraw.line((17.25, 4.4), (17.25, 4.6), stroke: luma(100), mark: (end: ">"))
  // the fp-leaning half: records plus match replace virtual dispatch
  cdraw.rect((0.5, 0.7), (9.0, 2.8), fill: luma(252), stroke: luma(190), radius: 0.05)
  cdraw.content((4.75, 2.25), [record plus match], size: 6.5pt)
  cdraw.content((4.75, 1.15), [shape, not virtual], size: 6pt)
})

The one-line contrast worth saying out loud: in Go, satisfaction is
structural, the type never names the interface it implements. In
C\#, satisfaction is nominal, and the compiler message when a type
forgets the interface is the first thing the tests in this workspace
caught.

The C\# answer also carries the fp-leaning half of the language:
records are immutable data with structural equality, and pattern
matching over a closed hierarchy replaces adding a virtual method
per behavior:

#listing("interview-repertoire/samples/ch02-cs/src/Oop.cs", first: 54, last: 77, caption: [a record, a closed discount hierarchy, and the match that replaces a virtual method])

== fp: pure functions, closures, composition [EWC]

Functional programming in an interview is three claims: pure
functions are easier to reason about, closures capture state
without a class, and higher order functions compose. Both
workspaces implement the same trio.

#listing("interview-repertoire/samples/ch02-go/fp.go", first: 3, last: 30, caption: [map, filter, reduce over generics, pure by construction])

#diagram([pure stages never mutate, a closure is a function plus its own cell], length: 13pt, {
  // top: the pipeline, every stage a fresh slice
  let stage(x, t, sub) = {
    cdraw.rect((x, 4.6), (x + 4.4, 6.3), fill: luma(235), stroke: luma(120), radius: 0.05)
    cdraw.content((x + 2.2, 5.85), [#t], size: 6.5pt)
    cdraw.content((x + 2.2, 5.15), [#sub], size: 6pt)
  }
  stage(0.5, "xs", "the input")
  stage(6.2, "map f", "new slice")
  stage(11.9, "filter p", "new slice")
  stage(17.6, "reduce g", "one value")
  cdraw.line((4.95, 5.45), (6.15, 5.45), mark: (end: ">"))
  cdraw.line((10.65, 5.45), (11.85, 5.45), mark: (end: ">"))
  cdraw.line((16.35, 5.45), (17.55, 5.45), mark: (end: ">"))
  cdraw.content((11.75, 3.9), [no stage writes into its input, the tests assert it], size: 6pt)
  // bottom: one factory call, one captured cell per returned function
  cdraw.rect((0.5, 1.4), (4.9, 2.6), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((2.7, 2.0), [ticker()], size: 6.5pt)
  cdraw.rect((9.0, 1.4), (14.0, 2.6), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((11.5, 2.0), [counter a, n = 1], size: 6pt)
  cdraw.rect((17.0, 1.4), (22.0, 2.6), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((19.5, 2.0), [counter b, n = 1], size: 6pt)
  cdraw.line((4.9, 2.25), (9.0, 2.25), mark: (end: ">"))
  cdraw.line((4.9, 1.75), (17.0, 1.75), mark: (end: ">"))
  cdraw.content((13.0, 0.7), [two counters, two captured cells, no class], size: 6pt)
})

#listing("interview-repertoire/samples/ch02-go/fp.go", first: 32, last: 47, caption: [a closure holding state, and compose returning a function from two functions])

The closure test is the one that lands: two counters from the same
factory stay independent, because each call of `Ticker` creates its
own `n`. The C\# side is the same trio with LINQ spelling, `Where`
`Select` `Aggregate`, plus the identical closure over a captured
local. The trap to concede early: `Filter` in the Go workspace
allocates a new slice and never mutates its input, and the test
proves it. A candidate whose filter writes into the argument has
answered the purity question wrong while saying the right words.

== mvc, mvvm, and ecs: where state lives [DRILL]

The three architecture patterns are the same question at three
altitudes. Say it that way and the follow-ups answer themselves.

MVC, model view controller, is a server pattern: the model owns
state and rules, the view renders it, the controller translates
requests into model calls and picks a view. State lives in the
model, mutation flows through the controller, and every mainstream
web framework, ASP.NET included, is a variation on it.

MVVM, model view viewmodel, is the client descendant: the viewmodel
exposes observable state and commands, the view binds to it
declaratively, and the binding layer replaces the controller's
hand-written glue. It is the pattern behind WPF and behind the
signal-based state of #xref-to("repertoire", "js-fromscratch"),
where the framework re-renders on state change instead of the
developer pushing updates.

ECS, entity component system, inverts all of it: state leaves
objects entirely. Entities are ids, components are plain data rows,
systems are functions over all rows matching a shape. There is no
inheritance and no per-object behavior, which is what makes the
cache-friendly iteration of #xref-to("game-systems", "ecstheory")
and its implementation chapter possible.

#diagram([one question at three altitudes: where state lives], length: 13pt, {
  // three stacks side by side, the state box shaded in each
  let col(x, head, top, mid, bot, state) = {
    let f(box) = if box == state { luma(205) } else { luma(235) }
    cdraw.content((x + 3.5, 5.75), head, size: 6.5pt)
    cdraw.rect((x, 4.1), (x + 7.0, 5.0), fill: f("top"), radius: 0.02)
    cdraw.content((x + 3.5, 4.55), top, size: 6pt)
    cdraw.rect((x, 2.8), (x + 7.0, 3.7), fill: f("mid"), radius: 0.02)
    cdraw.content((x + 3.5, 3.25), mid, size: 6pt)
    cdraw.rect((x, 1.5), (x + 7.0, 2.4), fill: f("bot"), radius: 0.02)
    cdraw.content((x + 3.5, 1.95), bot, size: 6pt)
    cdraw.line((x + 3.5, 4.1), (x + 3.5, 3.7), stroke: luma(100), mark: (end: ">"))
    cdraw.line((x + 3.5, 2.8), (x + 3.5, 2.4), stroke: luma(100), mark: (end: ">"))
  }
  col(0.5, "mvc, server", [view], [controller], [model, state + rules], "bot")
  col(8.5, "mvvm, client", [view], [bindings], [viewmodel], "bot")
  col(16.5, "ecs, batches", [systems, funcs], [components, rows], [entities, ids], "mid")
  cdraw.content((12.0, 0.6), [state in the model, bound to views, or out of objects entirely], size: 6.5pt)
})

Follow-ups to expect: which pattern for a CRUD dashboard, answer
MVC, because the framework gives it to you. Which for a live
editor, answer MVVM or signals, because observable state beats
manual dom sync. Which for thousands of moving objects, answer ECS,
because per-object method calls lose to batch iteration.

sources: none cited online; both workspaces verified by `go test`
and `dotnet test` through `make verify`, 7 Go tests and 12 C\#
tests, chapter id `ch02-go` and `ch02-cs`.
