#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the typing system

Python's type annotations began life as a runtime eagerly evaluated
dictionary, grew a string-quote escape hatch for forward references, and
in 3.14 became lazy by default. That history matters because the new
behavior changes what `__annotations__` means and adds a new module,
`annotationlib`, as the sanctioned way to read annotations. This chapter
walks annotations at runtime first, then the PEP 695 generic syntax,
then the toolbox of unions, `Literal`, `TypedDict`, and `Never`, and
closes on `Protocol`, structural typing. One boundary up front: the
annotations themselves never enforce anything at runtime. Enforcement
belongs to static checkers and to libraries like the one
#xref-to("python", "pydantic") covers, and this chapter states that
limit rather than blurring it.
Every claim below is one of the 56 checks in the four samples, run
under cpython 3.14.7 with `-X utf8`.

== annotations at runtime

Before 3.14, `def later(x: Undefined)` raised `NameError` at definition
time unless `Undefined` already existed, and the escape hatch was a
quoted string, `"Missing"`, which then had to be evaluated by hand. PEP
649 changed the default: the compiler now emits an `__annotate__`
function per annotated object and calls it only when annotations are
accessed. PEP 749 added the public reading API, `annotationlib`, with
three formats that name the whole design:

#listing("python/samples/src/Ch08/annotate.py", first: 22, last: 30, caption: [an unquoted forward reference, a quoted one, and a self referential class])

The `Node` body at lines 25-27 is the headline demo: `nxt: Node | None`
names the class currently being defined, unquoted, and it works because
nothing evaluates until `Node` exists. The three formats read the same
objects three ways:

#listing("python/samples/src/Ch08/annotate.py", first: 33, last: 50, caption: [value raises at access, string gives source text, forwardref gives proxies])

VALUE is the format `__annotations__` uses, so it raises `NameError`
exactly when the name is still missing, line 34, the old failure moved
from definition time to access time. STRING returns the source text,
`"Undefined"` and `"None"`, and cannot fail. FORWARDREF is the
diagnostic middle: real values where they resolve, `ForwardRef` proxy
objects where they do not, and line 48 pins the boundary inside one
dict, the unquoted name became a proxy, the quoted one stayed a
string. Access order is the other half of the story:

#listing("python/samples/src/Ch08/annotate.py", first: 53, last: 73, caption: [define the names late, then read values, strings, or evaluated strings])

Once `Undefined` and `Missing` exist, lines 61-65 read real values,
with the quoted annotation still a string, and `eval_str=True` at 66-69
evaluates even those. `__annotations__` at 70-73 is the VALUE view.
The `__annotate__` function itself is one more lazy object, with its
own protocol rule:

#listing("python/samples/src/Ch08/annotate.py", first: 85, last: 100, caption: [annotate functions, the direct-call restriction, and the sanctioned wrapper])

The compiler's own `__annotate__` supports only VALUE when called
directly and raises `NotImplementedError` for the rest, lines 85-90,
which is why `call_annotate_function` exists, lines 91-95. A held
`ForwardRef` stays useful after the fact, line 96-99: `evaluate()`
resolves against the scope it came from. And `typing.ForwardRef` is
now an alias of `annotationlib.ForwardRef`, line 100, the PEP 749
cleanup. `typing.get_type_hints` still works and still normalizes a
`None` return to `NoneType`, lines 109-112.

#diagram([the same annotation, read before and after 3.14, and in the 3 formats], length: 13pt, {
  cdraw.rect((0.6, 5.3), (10.9, 8.7), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((5.75, 8.15), [through 3.13, eager], wrap: text.with(size: 7pt))
  cdraw.content((5.75, 7.4), [def f(x: Node): ...], wrap: text.with(size: 6pt))
  cdraw.content((5.75, 6.55), [NameError at the def, quote it or], wrap: text.with(size: 6pt))
  cdraw.content((5.75, 5.85), [from \_\_future\_\_ import annotations], wrap: text.with(size: 6pt))
  cdraw.content((5.75, 5.0), [annotations dict built at definition], wrap: text.with(size: 6pt))
  cdraw.rect((11.7, 5.3), (22.6, 8.7), stroke: luma(100), radius: 0.02)
  cdraw.content((17.15, 8.15), [3.14, lazy, pep 649 and 749], wrap: text.with(size: 7pt))
  cdraw.content((17.15, 7.4), [same source, no quotes needed], wrap: text.with(size: 6pt))
  cdraw.content((17.15, 6.55), [\_\_annotate\_\_ function stored, called on access], wrap: text.with(size: 6pt))
  cdraw.content((17.15, 5.85), [annotationlib is the reading api], wrap: text.with(size: 6pt))
  cdraw.content((17.15, 5.0), [get\_type\_hints unchanged in spirit], wrap: text.with(size: 6pt))
  let col = ((3.2, [value, the \_\_annotations\_\_ view], [real objects, or NameError at access]),
    (3.2, [string, the source text], ["Node", "None", never raises]),
    (3.2, [forwardref, the diagnostic view], [values plus ForwardRef proxies]))
  for (i, row) in col.enumerate() {
    let y = 3.9 - i * 1.25
    cdraw.rect((0.6, y), (8.2, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((4.4, y + 0.62), row.at(1), wrap: text.with(size: 6pt))
    cdraw.content((4.4, y + 0.28), row.at(2), wrap: text.with(size: 6pt))
  }
  cdraw.content((15.6, 3.25), [a held forwardref keeps its scope: #linebreak() evaluate() resolves it once the name exists], wrap: text.with(size: 6pt))
  cdraw.content((4.4, 0.35), [quoted annotations stay strings until you ask: eval_str=True or get_type_hints], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("warning", "string format is not source recovery", [
  STRING returns normalized text, not the exact characters you typed:
  `None` comes back quoted, constants fold, and expressions python
  cannot replay, like `a if b else c`, come back wrong or raise. Use it
  to render annotations, never to reconstruct code. The
  `from __future__ import annotations` import still exists in 3.14 and
  still forces the all-strings world, but new code should simply drop
  it, the default now defers correctly.
])

== generics

PEP 695 replaced the typing-module ceremony with syntax. `type`
statements build aliases, square brackets on `def` and `class` declare
type parameters, and the parameters are scoped to the definition
instead of leaking into the module:

#listing("python/samples/src/Ch08/generics.py", first: 23, last: 44, caption: [aliases, a generic function, a generic class, a bound, and a constraint])

Line 23 builds a `TypeAliasType` whose `__value__` is `list[T]`, lines
30-36 attach parameters to a function and a class, and lines 39-44
spell the two restrictions a parameter can carry: a bound, `[S:
LaterBound]`, means at least that, a constraint tuple, `[A: (str,
bytes)]`, means exactly one of those. The laziness of section 1 extends
to all of it:

#listing("python/samples/src/Ch08/generics.py", first: 59, last: 72, caption: [an alias to an undefined name defers its own error])

`type Late = NotDefinedHere` at line 25 succeeds quietly, and the
`NameError` fires only when `Late.__value__` is read, lines 59-67. The
`evaluate_value` hook gives the STRING view without raising, lines
68-72, the same three-format contract annotations use. Bounds behave
identically, lines 89-104 of the sample: the bound of `Bounded`'s
parameter raises until `LaterBound` exists, then resolves.

#listing("python/samples/src/Ch08/generics.py", first: 105, last: 134, caption: [parametrization documents, and the old spelling side by side])

Line 105 is the boundary restated as a check: `Box[int]("not an int")`
runs, because the parameter is documentation. `Box[int] == Box[int]`
and `!= Box[str]` at 110-113, generic aliases compare structurally.
Lines 114-134 keep the 3.11 spelling honest, `TypeVar` plus an explicit
`Generic` base still works, but the old class exposes
`__parameters__` while the new one exposes `__type_params__`, and the
old typevar carries `__covariant__` flags that the new syntax expects
checkers to infer.

#diagram([what pep 695 builds, and where laziness sits], length: 13pt, {
  cdraw.rect((0.6, 6.3), (13.6, 8.5), fill: luma(235), radius: 0.02)
  cdraw.content((7.1, 8.0), [type Vector\[T\] = list\[T\]], wrap: text.with(size: 6.5pt))
  cdraw.rect((1.0, 6.6), (4.6, 7.6), fill: luma(248), radius: 0.02)
  cdraw.content((2.8, 7.3), [\_\_name\_\_], wrap: text.with(size: 6pt))
  cdraw.content((2.8, 6.95), ["Vector"], wrap: text.with(size: 6pt))
  cdraw.rect((5.0, 6.6), (8.6, 7.6), fill: luma(248), radius: 0.02)
  cdraw.content((6.8, 7.3), [\_\_type\_params\_\_], wrap: text.with(size: 6pt))
  cdraw.content((6.8, 6.95), [(T,)], wrap: text.with(size: 6pt))
  cdraw.rect((9.0, 6.6), (13.2, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.1, 7.3), [\_\_value\_\_, lazy], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 6.95), [evaluate\_value(format)], wrap: text.with(size: 6pt))
  cdraw.rect((14.9, 6.3), (22.6, 8.5), fill: luma(235), radius: 0.02)
  cdraw.content((18.75, 8.0), [class Box\[T\]:], wrap: text.with(size: 6.5pt))
  cdraw.content((18.75, 7.3), [\_\_type\_params\_\_ = (T,)], wrap: text.with(size: 6pt))
  cdraw.content((18.75, 6.6), [Box\[int\] is an alias, unchecked at runtime], wrap: text.with(size: 6pt))
  cdraw.content((3.0, 5.4), [restrictions], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 3.7), (10.6, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.6, 4.6), [\[S: Bound\]], wrap: text.with(size: 6pt))
  cdraw.content((5.6, 4.15), [at least: solves to the most specific type], wrap: text.with(size: 6pt))
  cdraw.rect((11.2, 3.7), (21.4, 5.0), fill: luma(235), radius: 0.02)
  cdraw.content((16.3, 4.6), [\[A: (str, bytes)\]], wrap: text.with(size: 6pt))
  cdraw.content((16.3, 4.15), [exactly one of, never a subclass], wrap: text.with(size: 6pt))
  cdraw.content((3.4, 2.9), [star spellings: \[\*\*P\] paramspec, \[\*Ts\] typevartuple], wrap: text.with(size: 6pt))
  cdraw.content((3.4, 1.9), [old world: TypeVar("T") plus Generic\[T\] base, \_\_covariant\_\_ flags], wrap: text.with(size: 6pt))
  cdraw.content((3.4, 0.8), [variance is inferred by checkers in the new syntax, not declared], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the typing toolbox

Five constructs cover most signatures, and the runtime story differs
per construct, which is exactly what the sample pins:

#listing("python/samples/src/Ch08/toolbox.py", first: 22, last: 44, caption: [aliases, a literal return, a typeddict, and an exhaustive match])

Unions are real objects, `types.UnionType`, and uniquely among the
constructs they work in `isinstance` at lines 47-51 of the sample.
`Literal` at line 26 annotates the return of `user`, and lines 60-64
pin that the annotation object survives intact while the returned
strings are just strings. `TypedDict` is the struct: a dict subclass
at runtime that tracks `__required_keys__` and `__optional_keys__`,
lines 69-72, and checks nothing on construction, lines 73-80, missing
keys, extra keys, wrong value types all pass. `Callable` is runtime
checkable. `Never` and `assert_never` close the toolbox, lines 91-100:
the `match` handles every real input, and the unreachable branch calls
`assert_never`, which fires as an `AssertionError`, "Expected code to
be unreachable", if a case was missed. Exhaustiveness becomes a test.

#diagram([the toolbox, what each construct promises at runtime], length: 13pt, {
  let cols = ("construct", "spelling", "runtime behavior")
  let cw = 6.4
  let cx(i) = 0.8 + i * 6.9
  for (i, h) in cols.enumerate() {
    cdraw.rect((cx(i), 7.6), (cx(i) + cw, 8.4), fill: luma(205), radius: 0.02)
    cdraw.content((cx(i) + cw / 2, 8.0), h, wrap: text.with(size: 7pt))
  }
  let row(y, a, b, c) = {
    for (cell, i) in ((a, 0), (b, 1), (c, 2)) {
      cdraw.rect((cx(i), y), (cx(i) + cw, y + 0.95), fill: luma(235), radius: 0.02)
      cdraw.content((cx(i) + cw / 2, y + 0.47), cell, wrap: text.with(size: 6pt))
    }
  }
  row(6.4, [union], [int \| None], [isinstance works, real object])
  row(5.25, [literal], [Literal\["a", "b"\]], [annotation kept, values unchecked])
  row(4.1, [typeddict], [class P(TypedDict)], [dict, keys tracked, no checks])
  row(2.95, [callable], [Callable\[\[int\], str\]], [isinstance works])
  row(1.8, [never], [assert\_never(x)], [assertionerror if reached])
  cdraw.content((11.2, 0.5), [one rule for all five: annotations document, checkers enforce], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("pitfall", "typeddict is not validation", [
  The sample constructs `Page(url="x", extra=1)` and reads back a
  `title` set to an int, both without complaint. A `TypedDict` is a
  dict with metadata for checkers. When a boundary needs runtime
  enforcement of shape, that is a job for data validation,
  #xref-to("python", "pydantic")'s territory, or for plain checks you
  write yourself.
])

== protocols

Nominal typing asks "what do you inherit from". Structural typing asks
"what can you do". A `Protocol` class describes a shape, and any class
with that shape matches, no inheritance required:

#listing("python/samples/src/Ch08/protocols.py", first: 19, last: 30, caption: [three protocols: a method shape, an unmarked one, a data shape])

#listing("python/samples/src/Ch08/protocols.py", first: 33, last: 58, caption: [the implementations: related by shape, by blood, and not at all])

`Duck` never mentions `Quacks` yet `isinstance(Duck(), Quacks)` is
true, and `Quacks` appears nowhere in `Duck.__mro__`, while
`LoudDuck`, which does inherit, gains both the check and the mro
entry. The runtime checks have 3 limits the sample pins exactly:

#listing("python/samples/src/Ch08/protocols.py", first: 69, last: 94, caption: [the opt in, the name-only check, and the data restriction])

First, runtime checks are opt in: `isinstance` against an undecorated
protocol raises `TypeError`, lines 69-78. Second, `runtime_checkable`
checks the presence of names only, so `Fake` with `quack = 42`, not a
method at all, passes, line 79, signatures are a checker's business.
Third, `issubclass` refuses protocols with non-method members, lines
81-89, while `isinstance` still works on instances, line 90. The
choice between the two worlds is the closing decision:

#diagram([nominal or structural, the decision], length: 13pt, {
  cdraw.rect((0.7, 7.9), (21.8, 9.0), fill: luma(205), radius: 0.02)
  cdraw.content((11.25, 8.45), [do you control every implementer and want shared behavior?], wrap: text.with(size: 6.5pt))
  cdraw.line((11.25, 7.85), (6.4, 6.75), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.25, 7.85), (16.1, 6.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.6, 7.35), [yes], wrap: text.with(size: 6pt))
  cdraw.content((17.7, 7.35), [no, or third parties implement it], wrap: text.with(size: 6pt))
  cdraw.rect((0.7, 5.3), (12.1, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((6.4, 6.25), [nominal: a base class], wrap: text.with(size: 6.5pt))
  cdraw.content((6.4, 5.7), [inheritance carries code and identity, #linebreak() issubclass and isinstance walk the mro], wrap: text.with(size: 6pt))
  cdraw.rect((12.7, 5.3), (21.8, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((17.25, 6.25), [structural: a protocol], wrap: text.with(size: 6.5pt))
  cdraw.content((17.25, 5.7), [shape only, no mro entry, no injected code, #linebreak() matches classes you have never seen], wrap: text.with(size: 6pt))
  cdraw.content((11.25, 4.5), [want isinstance at runtime?], wrap: text.with(size: 6.5pt))
  cdraw.line((11.25, 4.3), (11.25, 3.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((2.4, 2.4), (20.1, 3.6), fill: luma(248), radius: 0.02)
  cdraw.content((11.25, 3.15), [decorate with runtime\_checkable, then remember its limits], wrap: text.with(size: 6pt))
  cdraw.content((11.25, 2.75), [names only, no signatures, issubclass for methods only], wrap: text.with(size: 6pt))
  cdraw.content((11.25, 1.5), [signatures, variance, and exhaustiveness are static checker work: mypy or pyright, not the interpreter], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "56 checks behind this chapter", [
  `annotate.py` pins the lazy evaluation contract, 15 checks,
  `generics.py` the PEP 695 surface and its deferral, 16, `toolbox.py`
  the five constructs and their runtime honesty, 14, and `protocols.py`
  structural matching with its 3 stated limits, 11. Two drafts went
  red on the way: the first read `__annotations__` before the names
  existed and met the VALUE `NameError`, and the first STRING
  comparison expected the quoted annotation to have become a
  `ForwardRef`. Both redrafts became checks in the final sample.
])

sources: docs.python.org/3/library/annotationlib.html, accessed
2026-09-12; peps.python.org/pep-0649 and peps.python.org/pep-0749,
accessed 2026-09-12; docs.python.org/3/library/typing.html, generic
syntax, `TypeAliasType`, `Protocol`, `Never`, and `assert_never`,
accessed 2026-09-12; docs.python.org/3/library/enum.html and
docs.python.org/3/library/dataclasses.html for the chapters either
side of this one, accessed 2026-09-12; every format, alias, bound, and
protocol limit probed on this machine the same day. Sample behavior
verified by `make verify-py`, 56 checks in chapter 8 of the samples
suite.
