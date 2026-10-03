#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= dataclasses, enums, and pattern matching

Chapter 7 closed with descriptors doing the attribute work. Most
classes you write are records, bags of named fields that want an
`__init__`, a `__repr__`, an `__eq__`, and nothing else, and writing
those by hand is exactly the boilerplate chapter 7 made you read
through. This chapter covers the 3 tools that remove it:
`@dataclass` for records, the `enum` family for closed sets, and
`match` for dispatching on structure. Each tool is honest about what
it removes and what it keeps: dataclasses generate methods, enums are
real classes with real members, and `match` is a binding construct,
not a switch with different spelling. Every claim below is one of the
57 checks in the four samples, run under cpython 3.14.7 with `-X utf8`.

== dataclasses

The decorator reads the annotated class body and writes the methods
for you, and the first thing it refuses to do is share mutable
default state between instances:

#listing("python/samples/src/Ch09/fields.py", first: 19, last: 31, caption: [the one default the decorator will not write for you])

`xs: list = []` looks like the trap chapter 3 demonstrated with
default arguments, and the decorator treats it as the same bug: a
list built once at class creation and shared by every instance. The
message names the fix, `default_factory`. The two classes that follow
show what gets generated:

#listing("python/samples/src/Ch09/fields.py", first: 34, last: 44, caption: [a frozen key and a record with a factory and an ignored weight])

From 8 lines of annotations, `Record` gains an `__init__` taking 3
arguments, a `__repr__` printing all 3, and an `__eq__` comparing 2,
because `weight` at line 44 opts out with `compare=False`. `Key` adds
`frozen=True` on top, and frozen plus the generated `__eq__` gives a
consistent `__hash__`, so `Key` instances work as dict keys, sample
lines 54-57. Line 43 is the mutable discipline, `default_factory=list`
constructs a fresh list per instance, and lines 51-53 pin that a
mutation through one record leaves the other alone. The copying
helpers have a depth policy worth pinning:

#listing("python/samples/src/Ch09/fields.py", first: 81, last: 107, caption: [kw_only construction, and the copy depth of asdict against a plain dict])

`kw_only=True` at lines 75-78 moves every field out of positional
construction, and lines 82-87 pin that `Conn("db")` now raises.
`asdict` at lines 100-103 recurses: the nested `Inner` becomes a
nested dict, and mutating that copy leaves the original alone. A
plain `dict(...)` at 104-106 aliases the same `Inner` object, and the
mutation lands. `astuple` strips to positionals, line 107. The cost
side of the trade is recursion itself, `asdict` deep-copies
everything, which is why the standard advice is to reach for it at
boundaries, not in loops.

#diagram([the same record, handwritten and decorated], length: 13pt, {
  cdraw.rect((0.6, 1.4), (10.7, 8.7), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((5.65, 8.15), [handwritten, chapter 7 style], wrap: text.with(size: 7pt))
  let lrow(y, t) = {
    cdraw.rect((1.0, y), (10.3, y + 1.05), fill: luma(248), radius: 0.02)
    cdraw.content((5.65, y + 0.52), t, wrap: text.with(size: 6pt))
  }
  lrow(6.8, [def \_\_init\_\_(self, tag, items, weight): ...])
  lrow(5.5, [def \_\_repr\_\_(self): ...])
  lrow(4.2, [def \_\_eq\_\_(self, other): ...])
  cdraw.content((5.65, 3.3), [three methods that only restate the field list], wrap: text.with(size: 6pt))
  cdraw.content((5.65, 2.3), [and must be kept in sync with it by hand], wrap: text.with(size: 6pt))
  cdraw.rect((11.5, 1.4), (22.4, 8.7), stroke: luma(100), radius: 0.02)
  cdraw.content((16.95, 8.15), [\@dataclass], wrap: text.with(size: 7pt))
  cdraw.rect((11.9, 5.5), (22.0, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((16.95, 7.15), [annotations are the single source of truth], wrap: text.with(size: 6pt))
  cdraw.content((16.95, 6.5), [tag: str], wrap: text.with(size: 6pt))
  cdraw.content((16.95, 5.95), [items: list = field(default\_factory=list)], wrap: text.with(size: 6pt))
  cdraw.rect((11.9, 3.8), (22.0, 5.1), fill: luma(235), radius: 0.02)
  cdraw.content((16.95, 4.45), [generated: \_\_init\_\_, \_\_repr\_\_, \_\_eq\_\_, #linebreak() frozen adds \_\_hash\_\_ and blocks writes], wrap: text.with(size: 6pt))
  cdraw.content((16.95, 2.7), [the decorator runs once, at class creation], wrap: text.with(size: 6pt))
  cdraw.content((16.95, 1.85), [mutable defaults refused, factories are explicit], wrap: text.with(size: 6pt))
  cdraw.content((11.5, 0.5), [both are plain classes afterward: the descriptor machinery of chapter 7 still carries every access], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== post-init and ordering

Generation has seams, and the seams are the interesting part. A field
marked `init=False` is not a constructor argument, and a `__post_init__`
hook is where derived state belongs:

#listing("python/samples/src/Ch09/postinit.py", first: 20, last: 42, caption: [ordering with an ignored field, and frozen slots with derived state])

`order=True` on `Task` generates the full comparison set from the
declared field order, skipping `id` because it is `compare=False`, so
sorting at sample lines 51-55 orders by name then prio and the two
tasks with different `id` values compare equal at line 56. `stamp` at
line 28 is `init=False`, line 58-63 pins that passing it to the
constructor raises `TypeError`, and `__post_init__` at 30-31 computes
it. On a frozen class even your own hook cannot assign normally, so
`Pixel` writes through `object.__setattr__`, line 42. The last two
seams compose:

#listing("python/samples/src/Ch09/postinit.py", first: 64, last: 78, caption: [derived labels survive slots, and replace reruns post-init])

`slots=True` together with `frozen=True` works in one decorator, lines
66-69, the instance has no `__dict__` and writes still raise
`FrozenInstanceError`, lines 73-78. The subtle one is `replace` at
line 72: it constructs a new instance from the current field values,
and because `label` is `init=False` it is not carried over, `__post_init__`
recomputes it from the new `x`. Had `label` been an ordinary field,
`replace` would have copied the stale derivation, the trap the
`init=False` marking avoids. The `ClassVar` annotation at line 20
stays out of the fields entirely, lines 47-50.

#diagram([the pipeline from decorator to instance, where each knob bites], length: 13pt, {
  let stage(x, w, t, fill: luma(235)) = {
    cdraw.rect((x, 5.6), (x + w, 7.2), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, 6.4), t, wrap: text.with(size: 6pt))
  }
  stage(0.6, 4.6, [class body #linebreak() annotations only])
  stage(5.8, 4.6, [decorator reads #linebreak() fields, factories])
  stage(11.0, 4.6, [\_\_init\_\_ runs #linebreak() defaults applied])
  stage(16.2, 4.6, [\_\_post\_init\_\_ #linebreak() derived state])
  stage(21.2, 1.2, [instance], fill: luma(205))
  cdraw.line((5.2, 6.4), (5.8, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.4, 6.4), (11.0, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((15.6, 6.4), (16.2, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.8, 6.4), (21.0, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.0, 8.0), [knobs live on the decorator and fields], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 4.0), (10.2, 5.1), fill: luma(248), radius: 0.02)
  cdraw.content((5.4, 4.55), [compare=False: out of eq and order], wrap: text.with(size: 6pt))
  cdraw.rect((10.8, 4.0), (20.4, 5.1), fill: luma(248), radius: 0.02)
  cdraw.content((15.6, 4.55), [init=False: not a constructor arg, replace recomputes], wrap: text.with(size: 6pt))
  cdraw.rect((0.6, 2.5), (10.2, 3.6), fill: luma(248), radius: 0.02)
  cdraw.content((5.4, 3.05), [frozen: writes raise, hash generated], wrap: text.with(size: 6pt))
  cdraw.rect((10.8, 2.5), (20.4, 3.6), fill: luma(248), radius: 0.02)
  cdraw.content((15.6, 3.05), [slots: no \_\_dict\_\_, composes with frozen], wrap: text.with(size: 6pt))
  cdraw.content((15.6, 1.5), [order=True: comparisons from declared order], wrap: text.with(size: 6pt))
  cdraw.content((10.5, 0.6), [kw_only=True: construction by keyword only], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== enums

An enum is a closed set of named constants, and the family mixes in
different base types with different rules. `auto()` alone has 3
policies:

#listing("python/samples/src/Ch09/enums.py", first: 19, last: 37, caption: [the family in one place: strenum, intenum, flag, intflag])

`StrEnum` members are strings whose `auto()` value is the lowercased
member name, `IntEnum` members are integers, `Flag` and `IntFlag`
members are bit sets whose `auto()` climbs powers of two. The string
behavior is the one that surprises: `str(Color.RED)` is `"red"` and
f-string interpolation gives the value, because `StrEnum` defines
`__str__` as `str.__str__` for drop-in use as constants, while
`repr` still names the member. `IntEnum` arithmetic is a one way door,
sample line 63: `Level.LOW + Level.HIGH` is `3`, a plain int, the
membership is gone. The `Flag` rules repay attention:

#listing("python/samples/src/Ch09/enums.py", first: 40, last: 53, caption: [a missing hook, and a duplicate value that aliases instead of colliding])

`_missing_` at 44-48 is the customization point for lookup by value:
called when the constructor misses, it can map `"debug"` to
`Build.DEBUG`, sample line 109. Duplicate values at 51-53 do not
collide, `Period.LAST` is an alias of `Period.FOUR`, the same member
object, and `len(Period)` counts 1. `@unique` turns that courtesy into
an error, lines 93-103 of the sample, with the message naming the
alias. Boundaries are the family's sharpest edge:

#listing("python/samples/src/Ch09/enums.py", first: 67, last: 91, caption: [combination arithmetic, iteration, and the two boundary defaults])

`READ | WRITE` is a member with value 3, iterating it yields the
individual members, `in` tests membership, and the empty combination
is falsy with length 0. Line 77 is the split: `Big(20)`, an
`IntFlag`, keeps the out-of-range value 20, while `Perms(20)`, a
`Flag`, raises `ValueError`, and lines 88-91 pin the defaults by
identity, strict for `Flag`, keep for `IntFlag`.

#diagram([the enum family and what each variant gives up], length: 13pt, {
  let cols = ("variant", "members are", "and the cost")
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
  row(6.4, [Enum], [opaque], [lookup by value and name])
  row(5.25, [IntEnum], [ints], [arithmetic drops membership])
  row(4.1, [StrEnum], [strings], [auto lowercases, str is the value])
  row(2.95, [Flag], [bit sets], [strict boundary, or is a member])
  row(1.8, [IntFlag], [ints and bits], [keep boundary, int ops drop out])
  cdraw.content((11.2, 0.5), [auto: last value plus 1, powers of two for flags, lowercased names for strenum], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== match statements

`match` looks like a switch and behaves like destructuring assignment
tried in order. Each `case` is a pattern, patterns nest, and a bare
name inside a pattern is a capture, not a comparison:

#listing("python/samples/src/Ch09/match.py", first: 24, last: 46, caption: [class patterns, positional through match args, keyword by attribute name])

`Point(0, 0)` at line 37 is a class pattern: it checks `isinstance`
then matches subpatterns against attributes. Positional access needs
`__match_args__`, line 25, which names which attributes the positions
mean. The literals `0` compare, the bare names `x` and `y` at 39-42
capture, and line 43 adds a guard, `if x == y`, which can reject after
the pattern matches. `Point()` at 45 with no arguments is just the
isinstance check. The second function shows the other pattern kinds:

#listing("python/samples/src/Ch09/match.py", first: 49, last: 62, caption: [literals with alternatives, sequences, mappings, and the wildcard])

Line 51 matches either literal. Line 55 destructures any sequence with
a star capture for the tail, and line 57 destructures a mapping,
requiring the two keys and capturing the rest with `**extra`. Line 59
is the enum bridge, an irrefutable class pattern, and `_` at 61 always
matches and binds nothing. The capture rule bites hardest at the bottom
of the sample, lines 113-118: `case x` matches anything, so a lone
lowercase name is a capture, while a dotted name like `Color.RED`,
lines 121-132, is a value pattern that compares. That distinction is
the whole syntax in one sentence, and the enum case makes exhaustiveness
checkable: cover every member, keep a `case Color()` or `assert_never`
arm, and a missed member announces itself in tests,
#xref-to("python", "testing")'s territory.

#diagram([a value enters, patterns are tried in order], length: 13pt, {
  cdraw.rect((8.4, 7.7), (13.6, 8.8), fill: luma(205), radius: 0.02)
  cdraw.content((11.0, 8.25), [the value], wrap: text.with(size: 7pt))
  cdraw.line((11.0, 7.65), (11.0, 7.05), stroke: luma(100), mark: (end: ">"))
  let pat(y, t, note) = {
    cdraw.rect((0.7, y), (21.5, y + 0.95), fill: luma(235), radius: 0.02)
    cdraw.content((5.6, y + 0.6), t, wrap: text.with(size: 6pt))
    cdraw.content((14.0, y + 0.6), note, wrap: text.with(size: 6pt))
  }
  pat(6.0, [0 \| "stop" \| Color.RED], [literals and dotted names compare])
  pat(4.85, [\[first, \*rest\], {"k": v, \*\*extra}], [sequences and mappings destructure])
  pat(3.7, [Point(0, y), Point(x=..)], [class patterns, match args or keywords])
  pat(2.55, [Point(x, y) if x == y], [guards reject after matching])
  pat(1.4, [x], [a bare name captures anything])
  cdraw.rect((0.7, 0.3), (21.5, 1.1), fill: luma(248), radius: 0.02)
  cdraw.content((11.0, 0.7), [\_ matches last, binds nothing, never fails], wrap: text.with(size: 6pt))
  cdraw.content((19.5, 8.25), [first match wins, #linebreak() later cases never run], wrap: text.with(size: 6pt))
})

#callout("verify", "57 checks behind this chapter", [
  `fields.py` pins the decorator contract, 15 checks, `postinit.py`
  the seams and composition, 11, `enums.py` the family and its
  boundaries, 17, and `match.py` the pattern kinds, 14. Two drafts
  went red: the first `sorted` expectation had the comparison fields
  backwards, and the first `replace` check expected a derived label
  to survive replacement, which is exactly the trap `init=False`
  exists to avoid.
])

sources: docs.python.org/3/library/dataclasses.html, accessed
2026-09-12; docs.python.org/3/library/enum.html, the variant table,
`auto`, the functional api, and flag boundaries, accessed 2026-09-12;
docs.python.org/3/reference/compound_stmts.html, the match statement
grammar and pattern forms, accessed 2026-09-12; docs.python.org/3/howto/enum.html,
accessed 2026-09-12; every generated repr, boundary default, and
pattern result probed on this machine the same day. Sample behavior
verified by `make verify-py`, 57 checks in chapter 9 of the samples
suite.
