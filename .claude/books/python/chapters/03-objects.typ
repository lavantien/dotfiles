#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the object model

Everything a python program touches at runtime is an object, and every
name is only a binding to one. This chapter walks the model in four
steps: names and references, mutability and copying, the representation
and hashing protocols that decide what may sit in a dict key, and the
memory story, reference counting first, the generational collector
second, weak references third. Every claim is pinned by one of the 42
checks in the four samples, run on cpython 3.14.7, or stated as a
measured fact of this build.

== names, objects, references

Assignment never copies. `a = []` creates the object and then binds the
name `a` to it, so a second assignment of the same object shares, while
`list(a)` builds a new one that only compares equal:

#listing("python/samples/src/Ch03/refs.py", first: 18, last: 30, caption: [sharing a binding against materializing a copy, and rebinding leaving the old object alone])

The `is` operator answers identity, `==` answers equality, and only the
first is safe against two equal-but-distinct objects. `None` is the
boundary case: its type builds the same singleton, which is why `None`
checks are identity checks. `del` closes the section, because it does
less than people expect:

#listing("python/samples/src/Ch03/refs.py", first: 32, last: 37, caption: [None builds itself, and del removes only the name])

The binding disappears from its namespace, and whether the object dies is
a reference count question. That count is observable:

#listing("python/samples/src/Ch03/refs.py", first: 39, last: 47, caption: [each alias adds exactly one reference, and getrefcount itself adds one])

`sys.getrefcount` reports one extra because the call holds its own
temporary reference to the argument. The model's last clause is the one
with consequences: functions, classes, types, and `None` are objects in
the same sense as numbers, and types themselves have a type:

#listing("python/samples/src/Ch03/refs.py", first: 49, last: 59, caption: [the object test applied across numbers, functions, and types])

#callout("note", "names have no type, objects do", [
  A name is a binding, so binding it to something else changes what the
  name refers to, never the object. Type checks like `type(True) is bool`
  and `isinstance(True, int)` both hold, because `bool` is a subclass of
  `int` and the instance answers both questions. The samples use `is`
  only where identity is the claim being pinned.
])

#diagram([one binding added, one unbound, the objects stay what they are], length: 13pt, {
  cdraw.content((5.4, 8.6), [before], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.rect((0.6, 6.6), (3.4, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((2.0, 7.1), [`bucket`], wrap: text.with(size: 6.5pt))
  cdraw.rect((6.6, 6.6), (10.6, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((8.6, 7.1), [list object], wrap: text.with(size: 6.5pt))
  cdraw.line((3.4, 7.1), (6.6, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((15.4, 8.6), [after `alias = bucket`], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.rect((11.4, 6.6), (14.2, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((12.8, 7.1), [`alias`], wrap: text.with(size: 6.5pt))
  cdraw.rect((17.4, 6.6), (21.4, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((19.4, 7.1), [same list], wrap: text.with(size: 6.5pt))
  cdraw.line((14.2, 7.1), (17.4, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((19.4, 5.9), [refcount 2], wrap: text.with(size: 6pt))
  cdraw.content((5.4, 5.0), [`del bucket`], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((5.4, 4.1), [the binding is gone, the object answers #linebreak() to `alias` alone, refcount 1], wrap: text.with(size: 6pt))
  cdraw.rect((0.6, 1.9), (21.6, 3.1), fill: luma(248), radius: 0.02)
  cdraw.content((11.1, 2.5), [`list(bucket)` instead: a new object, equal by `==`, distinct by `is`], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 0.9), [`==` asks `__eq__`, `is` asks identity, #linebreak() never overridable], wrap: text.with(size: 6pt))
})

== mutability and copies

Immutable objects reject item assignment, mutable ones accept it, and the
split predicts everything downstream, from copying cost to the default
argument trap:

#listing("python/samples/src/Ch03/copies.py", first: 19, last: 33, caption: [str and tuple refuse item assignment, a list takes it in place])

Copying splits the same way. `copy.copy` reproduces the outer container
and shares everything inside it, `copy.deepcopy` walks the graph, and its
memo is what keeps aliasing intact inside one copy:

#listing("python/samples/src/Ch03/copies.py", first: 35, last: 46, caption: [shallow shares the inner lists, deep rebuilds the tree but preserves the alias])

`deep_two[0] is deep_two[1]` holds because the memo records the first
copy of `shared` and returns it for the second reference. The default
argument trap is mutability's most visited accident:

#listing("python/samples/src/Ch03/copies.py", first: 48, last: 68, caption: [the default list built once at def time, and the None sentinel fix])

Defaults are evaluated when `def` runs, not per call, so every call
without `target` appends into one shared list. The `None` sentinel builds
a fresh list inside the call, which is the standard fix and the reason
`None` appears so often in signatures. The section closes with the two
interning facts, one for ints, one for strings:

#listing("python/samples/src/Ch03/copies.py", first: 70, last: 79, caption: [the small int cache against fresh large ints, and sys.intern returning the canonical string])

#callout("pitfall", "interning is a cpython optimization, not a language rule", [
  The small int cache and string interning are implementation facts, not
  promises. The samples construct values at runtime through `int("257")`
  and `part + "lo"` precisely so the checks do not lean on compile time
  constant folding, and they pin this build's behavior. Equality is the
  contract, `is` on numbers and computed strings is not.
])

#diagram([one nested structure through a shallow copy and a deep copy], length: 13pt, {
  cdraw.content((3.4, 8.6), [original], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 6.4), (6.2, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((3.4, 7.0), [`nested = [[1], [2]]`], wrap: text.with(size: 6pt))
  cdraw.rect((0.9, 5.0), (2.7, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((1.8, 5.5), [list 1], wrap: text.with(size: 6pt))
  cdraw.rect((4.1, 5.0), (5.9, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 5.5), [list 2], wrap: text.with(size: 6pt))
  cdraw.line((2.0, 6.4), (1.8, 6.0), stroke: luma(100))
  cdraw.line((5.0, 6.4), (5.0, 6.0), stroke: luma(100))
  cdraw.content((12.0, 8.6), [`copy.copy(nested)`], wrap: text.with(size: 6.5pt))
  cdraw.rect((8.6, 6.4), (14.2, 7.6), fill: luma(248), radius: 0.02)
  cdraw.content((11.4, 7.0), [new outer list], wrap: text.with(size: 6pt))
  cdraw.line((9.9, 6.4), (2.0, 6.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.0, 6.4), (5.0, 6.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.4, 5.5), [inner objects shared, #linebreak() one change is visible through both names], wrap: text.with(size: 6pt))
  cdraw.content((18.8, 8.6), [`copy.deepcopy(nested)`], wrap: text.with(size: 6.5pt))
  cdraw.rect((15.6, 6.4), (21.4, 7.6), fill: luma(248), radius: 0.02)
  cdraw.content((18.5, 7.0), [new outer list], wrap: text.with(size: 6pt))
  cdraw.rect((15.9, 5.0), (17.7, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((16.8, 5.5), [new], wrap: text.with(size: 6pt))
  cdraw.rect((19.1, 5.0), (20.9, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((20.0, 5.5), [new], wrap: text.with(size: 6pt))
  cdraw.line((17.0, 6.4), (16.8, 6.0), stroke: luma(100))
  cdraw.line((20.0, 6.4), (20.0, 6.0), stroke: luma(100))
  cdraw.content((18.5, 4.2), [whole tree rebuilt, #linebreak() the memo keeps #linebreak() shared refs shared], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 2.2), [defaults are evaluated at def time, so `target=[]` is one #linebreak() list for every call, the None sentinel is the fix, #linebreak() and interning caches small ints and canonical strings], wrap: text.with(size: 6pt))
})

== representation and hashing

`repr` is for developers, `str` is for users, and when a class defines
only `__repr__` everything else follows it:

#listing("python/samples/src/Ch03/reprs.py", first: 18, last: 39, caption: [repr escapes where str does not, the default form, and the fallback])

The default `repr` carries the class name and the address, `<Plain object
at 0x...>`, good enough to tell two instances apart and nothing else.
`format` is the third channel, and 3.14 keeps the rule that made it
honest: a class that does not override `__format__` gets a `TypeError`
for any non-empty spec, rather than silently ignoring it:

#listing("python/samples/src/Ch03/reprs.py", first: 42, last: 57, caption: [a custom `__format__` receives the spec verbatim, the default one rejects it])

Hashing is the contract behind dict keys and set membership: equal
objects must hash equal, `1`, `1.0`, and `True` all do, and the dict
keeps a single entry when they collide:

#listing("python/samples/src/Ch03/reprs.py", first: 59, last: 77, caption: [the contract, one key for three equal spellings, and the unhashable kinds])

The last two checks carry the load-bearing details: a tuple is exactly as
hashable as its contents, and defining `__eq__` without `__hash__` sets
the hash to `None`, making instances unusable as keys, which is the
language forcing the contract:

#listing("python/samples/src/Ch03/reprs.py", first: 80, last: 95, caption: [eq without hash refuses, and nan's one element set])

`nan != nan` yet a set holds one nan, because containment checks try
identity before equality. Chapter 9's dataclasses generate exactly this
pair, `__eq__` with a matching `__hash__` or none, see
#xref-to("python", "dataclasses").

#diagram([may this value live in a dict key], length: 13pt, {
  cdraw.rect((0.6, 5.0), (7.2, 6.4), fill: luma(205), radius: 0.02)
  cdraw.content((3.9, 5.7), [value offered as a key], wrap: text.with(size: 6.5pt))
  cdraw.rect((10.4, 6.8), (21.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((16.0, 7.4), [`__hash__` and `__eq__` both work, #linebreak() frozen data, str, int, tuple of hashables], wrap: text.with(size: 6pt))
  cdraw.line((7.2, 5.9), (10.4, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.6, 6.9), [hashable], wrap: text.with(size: 6pt))
  cdraw.rect((10.4, 5.2), (21.6, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((16.0, 5.8), [`__eq__` defined, no `__hash__`: #linebreak() hash is set to None, TypeError], wrap: text.with(size: 6pt))
  cdraw.line((7.2, 5.7), (10.4, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((10.4, 3.6), (21.6, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((16.0, 4.2), [list, dict, set: #linebreak() unhashable, TypeError], wrap: text.with(size: 6pt))
  cdraw.line((7.2, 5.4), (10.4, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((0.6, 1.6), (9.0, 3.0), fill: luma(248), radius: 0.02)
  cdraw.content((4.8, 2.3), [tuple: hashable only if #linebreak() every element is], wrap: text.with(size: 6pt))
  cdraw.content((15.0, 2.3), [equal objects must hash equal: #linebreak() `hash(1) == hash(1.0) == hash(True)`], wrap: text.with(size: 6pt))
  cdraw.content((15.0, 1.0), [nan is unequal to itself, #linebreak() yet one set element], wrap: text.with(size: 6pt))
})

== gc and weakref

Cpython frees most objects without any collector: each object carries a
reference count, and the count hitting zero frees it immediately:

#listing("python/samples/src/Ch03/gcweak.py", first: 26, last: 38, caption: [the count arithmetic, and the weak reference flipping the moment the last name goes])

The weak reference returning `None` right after `del` is the proof no
collector pass was involved. Cycles are the exception refcounting cannot
handle, and the generational collector exists for them:

#listing("python/samples/src/Ch03/gcweak.py", first: 40, last: 51, caption: [a two node cycle survives both deletions, then one collect clears it])

The collector tracks objects in generations, promotes survivors, and
triggers on allocation counts. The thresholds are not documented values,
so the sample pins them as a fact of this build, `(2000, 10, 10)`:

#listing("python/samples/src/Ch03/gcweak.py", first: 53, last: 62, caption: [the measured thresholds, and a weak valued mapping dropping its entry])

Weak references power caches and registries that must not keep things
alive, and `finalize` puts a callback on the same hook:

#listing("python/samples/src/Ch03/gcweak.py", first: 64, last: 77, caption: [a finalizer firing at collection, and detach cancelling it])

#callout("note", "3.14 shipped two garbage collectors", [
  3.14.0 through 3.14.4 ran an incremental collector with two generations
  and much smaller pauses. Reports of memory pressure in production led
  to a revert, and 3.14.5 restored the 3.13 generational collector, which
  is what 3.14.7 runs here. The thresholds check would read differently
  on a 3.14.2 interpreter. The lesson generalizes: memory behavior is
  versioned behavior, and the whatsnew is part of the spec.
])

The last sample block answers the two timing questions people get wrong:
weak references only attach to types that opt in, and `__del__` is a
finalizer callback, not a destructor with guaranteed timing:

#listing("python/samples/src/Ch03/gcweak.py", first: 79, last: 100, caption: [int refuses weakrefs, and `__del__` runs at collection, not at scope exit])

Since PEP 442 even cycles containing `__del__` methods are collected, the
callback list runs once, and a self referencing object still dies at
`gc.collect`. Code that needs deterministic cleanup uses context
managers, the subject of #xref-to("python", "exceptions"), not `__del__`.

#diagram([the life of an object, refcounting first, the collector only for cycles], length: 13pt, {
  cdraw.rect((0.6, 6.2), (5.4, 7.6), fill: luma(205), radius: 0.02)
  cdraw.content((3.0, 6.9), [created, count 1], wrap: text.with(size: 6pt))
  cdraw.rect((7.4, 6.2), (12.2, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((9.8, 6.9), [names bind and unbind, #linebreak() count tracks each], wrap: text.with(size: 6pt))
  cdraw.line((5.4, 6.9), (7.4, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.2, 7.4), (21.6, 8.6), fill: luma(248), radius: 0.02)
  cdraw.content((17.9, 8.0), [count 0: freed at once, #linebreak() weakref now returns None], wrap: text.with(size: 6pt))
  cdraw.line((12.2, 7.1), (14.2, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.2, 5.6), (21.6, 6.8), fill: luma(248), radius: 0.02)
  cdraw.content((17.9, 6.2), [count stuck above 0: #linebreak() a cycle holds itself], wrap: text.with(size: 6pt))
  cdraw.line((12.2, 6.7), (14.2, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.4, 3.4), (18.2, 4.6), fill: luma(235), radius: 0.02)
  cdraw.content((12.8, 4.0), [generational collector, triggered by allocation deltas, #linebreak() thresholds (2000, 10, 10) on this build], wrap: text.with(size: 6pt))
  cdraw.line((17.9, 5.6), (17.9, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.4, 1.6), (18.2, 2.8), fill: luma(205), radius: 0.02)
  cdraw.content((12.8, 2.2), [cycle collected, `__del__` runs here, #linebreak() weakref.finalize callbacks fire once], wrap: text.with(size: 6pt))
  cdraw.line((12.8, 3.4), (12.8, 2.8), stroke: luma(100), mark: (end: ">"))
  cdraw.content((1.0, 4.0), [no name ever held it, #linebreak() only the cycle #linebreak() kept it alive], wrap: text.with(size: 6pt))
  cdraw.content((1.0, 2.2), [cleanup with guaranteed #linebreak() timing belongs to #linebreak() context managers], wrap: text.with(size: 6pt))
})

#callout("verify", "42 checks, one red draft behind them", [
  The first run of the names sample failed its last check: it asserted
  `type(True) is int`, and the interpreter answered that `type(True)` is
  `bool`, a subclass of `int`. The corrected check pins both facts
  separately. The cycle, weakref, and finalizer checks all passed on the
  first run, and the thresholds check is a measured build fact rather
  than a documented default, the gc page documents the shape of the tuple
  only. Sample behavior verified by `make verify-py`, 42 checks in
  chapter 3 of the samples suite.
])

sources: docs.python.org/3/reference/datamodel.html (objects, values,
types, `del`, the `__eq__`/`__hash__` contract, `__repr__` and `__str__`,
`__format__`, `__del__`),
docs.python.org/3/library/stdtypes.html (hashability of dict keys, NoneType),
docs.python.org/3/library/copy.html (shallow against deep, the memo),
docs.python.org/3/library/gc.html (generations, thresholds, freeze),
docs.python.org/3/library/weakref.html (ref, WeakValueDictionary,
finalize and detach),
docs.python.org/3/library/sys.html (getrefcount, intern),
docs.python.org/3/whatsnew/3.14.html (the incremental gc revert in
3.14.5), and peps.python.org/pep-0442/ (safe object finalization), all
accessed 2026-09-12; the refcount values, thresholds, and interning
behavior were probed on this machine the same day. Sample behavior
verified by `make verify-py`, 42 checks in chapter 3.
