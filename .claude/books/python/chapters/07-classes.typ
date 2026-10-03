#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= classes and inheritance

Chapter 3, #xref-to("python", "objects"), established that a name is a
binding to an object and that every object has a type. A class ties
those two facts together: it is itself an
object, a namespace that executes once, and the factory that makes
instances carrying that namespace as their type. This chapter walks the
surface in four stops: attribute lookup and the class body, the dunder
hooks the runtime calls on your behalf, inheritance and the method
resolution order, and the descriptor machinery that sits under every
attribute access. Every behavioral claim below is a check in the four
samples, 56 in total, run under cpython 3.14.7 with `-X utf8`, and every
byte count is a fact about this build.

== classes as namespaces and factories

The `class` statement does 3 things. It executes the body top to bottom in
a fresh namespace, that namespace becomes the class `__dict__`, and the
resulting class object is bound to the name. Nothing about that requires
an instance: the body runs at definition time, exactly once, whether or
not you ever call the class. Calling it is a separate act, routed through
`type`, which is the class of every class:

#listing("python/samples/src/Ch07/lookup.py", first: 18, last: 41, caption: [the body mechanics, the shared namespace, and the one deliberate bug])

Lines 27-28 are the two facts worth pinning early. `body_log.append` reads
outward and finds the module-level list, because reading a name in a class
body falls back to enclosing scopes. `body_reads += 1` looks outward too,
but assignment stores into the class namespace, so `Stack.body_reads` is
1 while the module-level `body_reads` stays 0. The same asymmetry explains
line 41: inside a method, the class namespace is simply not in scope, and
`read_broken` raises `NameError` when called, while `read_limit` at 37-38
qualifies through `self` and works. The lookup that `read_limit` relies
on is the whole section in one rule, instance first, then class:

#listing("python/samples/src/Ch07/lookup.py", first: 57, last: 75, caption: [rebind on the class, shadow on the instance, delete to reveal])

Line 57 rebinds `Stack.limit` and both instances see 16, because neither
has a `limit` of its own. Line 59 gives `one` a private `limit`, line 64
deletes it again, and the shared value resurfaces. Lines 66-73 pin where
private state lives: `vars(one)` is `one.__dict__`, each instance owns
one, and the `items` lists of the two instances are distinct objects.
Lines 74-75 carry the consequence for methods: `push` lives in the class
dict, never in an instance dict, and attribute access on an instance
binds it, `one.push.__self__ is one`. The binding is not a copy, it is
descriptor machinery, section 4's subject.

#diagram([attribute lookup is a walk down a stack of namespaces], length: 13pt, {
  cdraw.rect((0.7, 6.6), (14.6, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 8.05), [instance one], wrap: text.with(size: 7pt))
  cdraw.rect((1.2, 6.95), (5.2, 7.7), fill: luma(248), radius: 0.02)
  cdraw.content((3.2, 7.32), [items: []], wrap: text.with(size: 6pt))
  cdraw.content((9.9, 7.32), [\_\_dict\_\_ holds private state only], wrap: text.with(size: 6pt))
  cdraw.line((3.2, 6.55), (3.2, 5.75), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.1, 6.15), [miss, keep walking], wrap: text.with(size: 6pt))
  cdraw.rect((0.7, 4.4), (14.6, 5.7), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 5.15), [class Stack], wrap: text.with(size: 7pt))
  cdraw.rect((1.2, 4.7), (4.4, 5.42), fill: luma(248), radius: 0.02)
  cdraw.content((2.8, 5.06), [limit = 8], wrap: text.with(size: 6pt))
  cdraw.rect((4.8, 4.7), (7.6, 5.42), fill: luma(248), radius: 0.02)
  cdraw.content((6.2, 5.06), [push], wrap: text.with(size: 6pt))
  cdraw.rect((8.0, 4.7), (11.2, 5.42), fill: luma(248), radius: 0.02)
  cdraw.content((9.6, 5.06), [\_\_init\_\_], wrap: text.with(size: 6pt))
  cdraw.content((12.9, 5.06), [the shared namespace], wrap: text.with(size: 6pt))
  cdraw.line((3.0, 4.35), (3.0, 3.55), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.3, 3.95), [built by, and callable as a factory], wrap: text.with(size: 6pt))
  cdraw.rect((0.7, 2.2), (14.6, 3.5), fill: luma(205), radius: 0.02)
  cdraw.content((7.6, 2.85), [type, the class of classes], wrap: text.with(size: 7pt))
  cdraw.content((18.1, 7.6), [the body runs once, at definition, #linebreak() whether or not you call the class], wrap: text.with(size: 6.5pt))
  cdraw.content((18.1, 5.5), [assignment in the body lands on the class, #linebreak() methods never see it unqualified], wrap: text.with(size: 6.5pt))
  cdraw.content((18.1, 3.4), [type(name, bases, dict) builds a class directly, #linebreak() calling Stack() asks type to run \_\_new\_\_ then \_\_init\_\_], wrap: text.with(size: 6.5pt))
  cdraw.content((7.6, 1.0), [the object model of chapter 3 is the floor under this: a class is just an object with a useful type], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("note", "one rule, applied recursively", [
  Instance first, then class, is also the whole inheritance story: when the
  class namespace misses, the walk continues through the classes of the
  method resolution order, section 3. Nothing in this lookup is special
  to `class`, it is the same binding machinery chapter 3 traced for plain
  names, extended one level.
])

== dunders

Dunder methods are the operator table of the language, and the runtime,
not your code, decides when to dial one. Define `__len__` and `len`
calls it, define `__eq__` and `==` calls it, define `__getitem__` and
indexing, slicing, iteration, and membership all call it. The first
listing is the comparison pair, with the two returns that make the
protocol composable:

#listing("python/samples/src/Ch07/dunders.py", first: 18, last: 44, caption: [the comparison pair and the container surface])

`NotImplemented` at lines 27 and 32 is a signal, not an exception: it
tells the runtime to try the other operand's reflected hook and fall
back to identity, which is why `a == 5` at line 73 is `False` rather
than an error. Line 74 pins the price of defining `__eq__` alone, the
class becomes unhashable, because equal objects must hash equal and the
runtime cannot know that your `__eq__` agrees with the inherited hash.
`sorted` at line 81 uses `__lt__` and nothing else, one method is the
whole ordering protocol. The `Shelf` pair shows one method buying four
operations:

#listing("python/samples/src/Ch07/dunders.py", first: 47, last: 64, caption: [the arithmetic surface, forward and reflected])

The arithmetic rules follow one pattern: for `a + b`, the runtime tries
`a.__add__` then `b.__radd__`. Lines 90-93 pin both lanes, `[5] + Vec`
succeeds only because `list.__add__` refuses a `Vec` and the reflected
`__radd__` runs. Lines 96-98 close the loop: without `__iadd__`,
`v += w` computes `v + w` and rebinds the name, visible as a changed
`id`.

#diagram([what you call versus what the runtime calls], length: 13pt, {
  let cols = ("what you write", "what runs", "what it returns")
  let cw = 6.2
  let cx(i) = 1.0 + i * 6.6
  for (i, h) in cols.enumerate() {
    cdraw.rect((cx(i), 7.5), (cx(i) + cw, 8.3), fill: luma(205), radius: 0.02)
    cdraw.content((cx(i) + cw / 2, 7.9), h, wrap: text.with(size: 7pt))
  }
  let row(y, a, b, c) = {
    for (cell, i) in ((a, 0), (b, 1), (c, 2)) {
      cdraw.rect((cx(i), y), (cx(i) + cw, y + 0.85), fill: luma(235), radius: 0.02)
      cdraw.content((cx(i) + cw / 2, y + 0.42), cell, wrap: text.with(size: 6pt))
    }
  }
  row(6.35, [repr(x)], [\_\_repr\_\_], [the debug string])
  row(5.3, [print(x)], [\_\_repr\_\_ via \_\_str\_\_ fallback], [the user string])
  row(4.25, [a == b], [\_\_eq\_\_, maybe reflected], [bool, hash disabled])
  row(3.2, [sorted(xs)], [\_\_lt\_\_ only], [ordered list])
  row(2.15, [len(x), bool(x)], [\_\_len\_\_], [count, truthiness])
  row(1.1, [x\[i\], for, in], [\_\_getitem\_\_], [item, iterator, membership])
  cdraw.content((11.0, 0.35), [arithmetic tries forward then reflected: a + b is \_\_add\_\_ then \_\_radd\_\_], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== inheritance and the mro

Multiple inheritance needs a rule for ordering the namespaces, and
python's is c3 linearization, computed once when the class object is
built and stored as `__mro__`. The diamond is the canonical case:

#listing("python/samples/src/Ch07/mro.py", first: 18, last: 38, caption: [the diamond: four classes, one super call each])

`super()` is the sentence everyone misreads. It does not mean "my parent
class", it means "the next class after me in this instance's mro". In a
`D` instance the order is D, B, C, Base, object, so `D.who` calls
`B.who`, which calls `C.who`, not `Base.who`, and the result is the
string `d+b+c+a`. The same code outside the diamond, `C().who`, gives
`c+a`, because a `C` instance's mro never mentions `B`. That single
mechanism is what makes cooperative multiple inheritance work:

#listing("python/samples/src/Ch07/mro.py", first: 56, last: 87, caption: [cooperative inits: each class consumes its keywords, forwards the rest])

Every `__init__` in the chain takes `**kwargs`, pulls out only the
keywords it owns, and forwards the remainder. The recorded order is
file, reader, writer, root, each initializer ran exactly once, and
`Reader`'s `super().__init__` dispatched to `Writer`, a class it has
never heard of. The contract for entering that chain is cheap: accept
and forward what you do not consume. C3 also refuses to be fooled:

#listing("python/samples/src/Ch07/mro.py", first: 100, last: 113, caption: [an inconsistent request is refused at class creation, not at call time])

Asking for bases `(Left, Right)` when `Right` already inherits `Left`
cannot be linearized, and the `type` call raises `TypeError` with
"Cannot create a consistent method resolution order" before any instance
exists.

#diagram([the diamond and the linear order c3 derives from it], length: 13pt, {
  cdraw.rect((8.6, 8.0), (12.6, 9.0), fill: luma(205), radius: 0.02)
  cdraw.content((10.6, 8.5), [D(B, C)], wrap: text.with(size: 7pt))
  cdraw.rect((4.2, 5.9), (7.6, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((5.9, 6.4), [B], wrap: text.with(size: 7pt))
  cdraw.rect((13.6, 5.9), (17.0, 6.9), fill: luma(235), radius: 0.02)
  cdraw.content((15.3, 6.4), [C], wrap: text.with(size: 7pt))
  cdraw.rect((8.9, 3.8), (12.3, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((10.6, 4.3), [Base], wrap: text.with(size: 7pt))
  cdraw.rect((8.9, 1.7), (12.3, 2.7), fill: luma(248), radius: 0.02)
  cdraw.content((10.6, 2.2), [object], wrap: text.with(size: 7pt))
  cdraw.line((9.4, 8.0), (6.4, 6.9), stroke: luma(100))
  cdraw.line((11.8, 8.0), (14.8, 6.9), stroke: luma(100))
  cdraw.line((5.9, 5.9), (9.6, 4.8), stroke: luma(100))
  cdraw.line((15.3, 5.9), (11.6, 4.8), stroke: luma(100))
  cdraw.line((10.6, 3.8), (10.6, 2.7), stroke: luma(100))
  cdraw.content((2.4, 7.4), [bases are a graph], wrap: text.with(size: 6.5pt))
  cdraw.content((19.0, 6.4), [D.\_\_bases\_\_ is (B, C)], wrap: text.with(size: 6pt))
  cdraw.line((1.4, 5.4), (1.4, 0.9), stroke: luma(160))
  let names = ("D", "B", "C", "Base", "object")
  for (i, n) in names.enumerate() {
    let y = 5.0 - i * 1.05
    cdraw.rect((0.7, y - 0.4), (2.1, y + 0.4), fill: luma(235), radius: 0.02)
    cdraw.content((1.4, y), n, wrap: text.with(size: 6pt))
    if i < 4 {
      cdraw.line((1.4, y - 0.42), (1.4, y - 0.61), stroke: luma(100), mark: (end: ">"))
    }
  }
  cdraw.content((3.3, 3.1), [\_\_mro\_\_ is a list], wrap: text.with(size: 6.5pt))
  cdraw.content((18.6, 3.3), [super() means next in this list #linebreak() for the instance at hand], wrap: text.with(size: 6pt))
  cdraw.content((10.6, 0.6), [in a D instance, B's super call reaches C, and the chain spells d+b+c+a], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== slots, properties, descriptors

The instance `__dict__` of section 1 is flexible and costs memory, and
`__slots__` is the opt-out. Declaring slots tells the class to store
attributes in fixed positions instead:

#listing("python/samples/src/Ch07/descriptors.py", first: 18, last: 51, caption: [the storage trade, measured on this build])

The numbers on this build: both instances are 48 bytes, but the
dictionary version carries a 296-byte `__dict__` beside it, and the
slots version refuses new attributes outright with "no
`__dict__` for setting new attributes". Slots are inherited by
declaring new ones, lines 55-64, and a subclass without its own
`__slots__` quietly reintroduces a `__dict__`, the trap the sample
sidesteps by declaring `("z",)`. The attribute you access every day is
usually not a plain value but a protocol participant:

#listing("python/samples/src/Ch07/descriptors.py", first: 67, last: 96, caption: [property is a descriptor living in the class namespace])

`Temp.__dict__["c"]` is a `property` object, and `property` carries
`__get__` and `__set__`. Reads and writes on the instance route through
your functions, `t.c = 5` lands as `_c = 45`, and class access returns
the property itself. The last listing is the same protocol written by
hand, which is what `property`, plain functions, `staticmethod`, and
`classmethod` all are:

#listing("python/samples/src/Ch07/descriptors.py", first: 99, last: 113, caption: [a hand written descriptor, with the hook that names it])

`__set_name__` runs at class creation and hands the descriptor its
attribute name, so one `Twice` class serves many attributes. The
instance stores `_n`, the descriptor stores the doubling policy, and
`h.n = 21` reads back as 42. Lines 122-125 are the punchline that close
the chapter: a plain function has `__get__`, which is exactly the machinery
behind section 1's observation that methods live on the class and bind
on access. Bound methods were descriptors all along.

#diagram([where attributes live, with and without slots], length: 13pt, {
  cdraw.content((4.3, 8.5), [plain class, \_\_dict\_\_ per instance], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 6.3), (8.0, 8.1), fill: luma(235), radius: 0.02)
  cdraw.content((4.3, 7.65), [instance, 48 bytes], wrap: text.with(size: 6.5pt))
  cdraw.rect((1.0, 6.5), (4.0, 7.35), fill: luma(248), radius: 0.02)
  cdraw.content((2.5, 6.92), [x = 1], wrap: text.with(size: 6pt))
  cdraw.rect((4.4, 6.5), (7.4, 7.35), fill: luma(248), radius: 0.02)
  cdraw.content((5.9, 6.92), [y = 2], wrap: text.with(size: 6pt))
  cdraw.line((4.3, 6.25), (4.3, 5.65), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((1.0, 4.5), (7.6, 5.6), fill: luma(205), radius: 0.02)
  cdraw.content((4.3, 5.05), [\_\_dict\_\_, 296 bytes on this build], wrap: text.with(size: 6.5pt))
  cdraw.content((4.3, 3.6), [arbitrary attributes later: obj.anything = v], wrap: text.with(size: 6pt))
  cdraw.content((15.9, 8.5), [slotted class, fixed positions], wrap: text.with(size: 6.5pt))
  cdraw.rect((10.6, 6.3), (18.0, 8.1), fill: luma(235), radius: 0.02)
  cdraw.content((14.3, 7.65), [instance, 48 bytes], wrap: text.with(size: 6.5pt))
  cdraw.rect((11.0, 6.5), (14.0, 7.35), fill: luma(248), radius: 0.02)
  cdraw.content((12.5, 6.92), [slot x], wrap: text.with(size: 6pt))
  cdraw.rect((14.4, 6.5), (17.4, 7.35), fill: luma(248), radius: 0.02)
  cdraw.content((15.9, 6.92), [slot y], wrap: text.with(size: 6pt))
  cdraw.content((14.3, 5.05), [no \_\_dict\_\_: new names raise AttributeError], wrap: text.with(size: 6.5pt))
  cdraw.line((9.6, 7.2), (10.2, 7.2), stroke: luma(160), mark: (end: ">"))
  cdraw.content((4.3, 1.9), [access for both goes through descriptors: #linebreak() property, function, staticmethod, classmethod, your own], wrap: text.with(size: 6.5pt))
  cdraw.content((4.3, 0.6), [a plain function's \_\_get\_\_ is what binds methods, chapter section 1's observation explained], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "56 checks behind this chapter", [
  The four samples ran green under cpython 3.14.7 with `-X utf8`:
  `lookup.py` pins the namespace and factory facts, 13 checks,
  `dunders.py` the operator table, 19, `mro.py` linearization and
  cooperative init, 10, and `descriptors.py` storage and the protocol,
  14. Three drafts went red on the way: the class-body counter stored
  into the class instead of the module, `5 + Vec` cannot iterate an
  int, and the first inconsistent-mro probe used a consistent order.
  Each red draft is now a check that would catch the same mistake.
])

sources: docs.python.org/3/reference/datamodel.html, special method
names, custom classes, and the descriptor protocol sections, accessed
2026-09-12; docs.python.org/3/library/functions.html#super, accessed
2026-09-12; docs.python.org/3/reference/expressions.html, binary
arithmetic operations and value comparisons, accessed 2026-09-12; the
48 and 296 byte figures and every lookup, binding, and linearization
order probed on this machine the same day. Sample behavior verified by
`make verify-py`, 56 checks in chapter 7 of the samples suite.
