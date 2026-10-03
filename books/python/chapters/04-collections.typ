#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= builtin collections, iteration, and generators

The builtin containers are not interchangeable: each one makes a
different promise about order, cost, and identity, and the interpreter
enforces those promises with concrete layouts. This chapter reads list,
tuple, dict, and set from their memory behavior outward, then the
iterator protocol that makes them interchangeable at the call site, then
comprehensions and generators, and closes on the four utility collections
that replace hand written loops. Every claim is pinned by one of the 45
checks in the four samples on cpython 3.14.7, with the size numbers
stated as facts of this build.

== list, tuple, dict, set internals

A python list is a C array of object pointers with spare capacity, and
that spare capacity is measurable. The sample records
`sys.getsizeof` before each append:

#listing("python/samples/src/Ch04/internals.py", first: 18, last: 28, caption: [the empty list, the first over-allocation, and the growth ladder])

The ladder runs 56, 88, 120, 184, 248 bytes over 17 appends on this
build: capacity grows in steps, which is why append is documented as
amortized constant time. A dict is a hash table in the compact layout it
has had since 3.6, an indices array pointing into a dense entries array,
and only the indices array is searched:

#listing("python/samples/src/Ch04/internals.py", first: 30, last: 38, caption: [the compact dict reserving its entries array between 5 and 6 entries here])

Insertion order falls out of that layout, and the language has promised
it since 3.7. The sample exercises the promise from both ends:

#listing("python/samples/src/Ch04/internals.py", first: 40, last: 53, caption: [order preserved, popitem LIFO, reversed backwards, and no shrink on delete])

Deleting keys leaves the table size untouched, 184 bytes before and
after, because removal marks entries empty rather than rebuilding. That
string-keyed table rides a slimmer entry row than the integer-keyed
ladder of chapter 13, whose same-size dict reads 224. Sets
are dicts without values, which makes membership the whole story:

#listing("python/samples/src/Ch04/internals.py", first: 55, last: 72, caption: [equal values collapsing to one element, and collisions resolved by probing])

Three objects with the same hash and different equality all survive in
the set: open addressing walks the probe sequence, so a bad `__hash__`
costs lookups but never correctness. The merge operators close the
section, `|` builds a new dict since 3.9 (PEP 584) and `|=` updates in
place, see lines 74 through 80 of the sample.

#callout("note", "sizes are build facts, order is a language fact", [
  `sys.getsizeof` ladders are pinned to this interpreter binary and would
  read differently on another build. Insertion order, `popitem` removing
  the last pair, and equal values collapsing in a set are language
  guarantees, and those are the checks that survive a version bump
  unchanged.
])

#diagram([how the four containers spend their memory], length: 13pt, {
  cdraw.content((3.0, 9.1), [list: a pointer array, #linebreak() over-allocated], wrap: text.with(size: 6.5pt))
  let caps = ((0, 0), (1, 4), (5, 4), (9, 8), (17, 8))
  for (i, c) in caps.enumerate() {
    let x = 0.8 + i * 2.0
    cdraw.rect((x, 5.4), (x + 1.6, 5.4 + 0.3 * c.at(1)), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.8, 5.1), [cap #(str(c.at(0)))], wrap: text.with(size: 5.5pt))
  }
  cdraw.content((5.2, 4.4), [len 0 1 5 9 17, sizeof 56 88 120 184 248 here], wrap: text.with(size: 6pt))
  cdraw.content((15.0, 9.1), [dict: indices then entries], wrap: text.with(size: 6.5pt))
  for (i, t) in ("4", "1", "5", "2", "3").enumerate() {
    let x = 12.2 + i * 1.0
    cdraw.rect((x, 7.2), (x + 0.9, 8.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + 0.45, 7.6), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((14.5, 6.8), [indices, hash mod table size], wrap: text.with(size: 6pt))
  for (i, t) in ("key 4", "key 1", "key 5").enumerate() {
    let x = 12.2 + i * 2.4
    cdraw.rect((x, 5.2), (x + 2.2, 6.0), fill: luma(248), radius: 0.02)
    cdraw.content((x + 1.1, 5.6), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((14.5, 4.8), [entries, insertion order], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 3.6), [set: the same machinery with empty values, #linebreak() equal values collapse, collisions probe on], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 2.2), [tuple: fixed length, hashable when its contents are], wrap: text.with(size: 6pt))
  cdraw.content((11.1, 1.0), [`|` merges dicts since 3.9, `|=` updates in place], wrap: text.with(size: 6pt))
})

== the iterator and iterable protocols

`for` is one protocol. It calls `iter()` on the object, then `next()` on
the result until `StopIteration`, and both halves are reachable by hand:

#listing("python/samples/src/Ch04/iterproto.py", first: 18, last: 35, caption: [the two dunders, the for loop over them, and manual driving])

Two facts fall out of the manual half. Exhaustion is permanent, a spent
iterator yields nothing forever, and `next` takes a default that swallows
the stop. The protocol also has a legacy door: an object with only
`__getitem__` still iterates, because `iter()` falls back to the old
sequence protocol, indexes from 0, and stops at `IndexError`:

#listing("python/samples/src/Ch04/iterproto.py", first: 43, last: 50, caption: [no `__iter__`, yet fully iterable])

That fallback is why strings and old sequence classes work in for loops,
and its edges are sharp: `reversed()` refuses the same object unless it
also defines `__len__`, the diagnostic on this build being `object of
type 'Headless' has no len()` (probed 2026-09-12), see lines 53 through
62. The helpers built on the protocol finish the section:

#listing("python/samples/src/Ch04/iterproto.py", first: 64, last: 80, caption: [zip truncating silently, both strict flags, and enumerate numbering from 1])

`zip` stops at the shortest input unless told otherwise, a silent
truncation that has eaten real data, and `strict=True` turns the mismatch
into a `ValueError` naming the longer argument. New in 3.14, `map` grew
the same flag with the same semantics.

#callout("pitfall", "zip truncates by default", [
  `list(zip([1, 2], "abc"))` returns 2 pairs and no complaint. When
  uneven inputs are a bug, `strict=True` is the assertion, and since 3.14
  `map(..., strict=True)` covers the mapped case. Both error messages
  name the longer argument, which is usually the one with the bug in it.
])

#diagram([the for loop protocol, with the legacy sequence door], length: 13pt, {
  cdraw.rect((0.6, 6.6), (6.0, 7.8), fill: luma(205), radius: 0.02)
  cdraw.content((3.3, 7.2), [`iter(obj)`], wrap: text.with(size: 6.5pt))
  cdraw.rect((9.2, 6.6), (14.6, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.9, 7.2), [`__iter__` returns self], wrap: text.with(size: 6pt))
  cdraw.line((6.0, 7.2), (9.2, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((9.2, 4.6), (14.6, 5.8), fill: luma(248), radius: 0.02)
  cdraw.content((11.9, 5.2), [no `__iter__`, #linebreak() only `__getitem__`: #linebreak() indexes 0, 1, 2 ...], wrap: text.with(size: 6pt))
  cdraw.line((3.3, 6.6), (3.3, 5.2), stroke: luma(100))
  cdraw.line((3.3, 5.2), (9.2, 5.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.2, 5.5), [legacy door], wrap: text.with(size: 6pt))
  cdraw.rect((17.8, 6.6), (21.6, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((19.7, 7.2), [`next(it)`], wrap: text.with(size: 6pt))
  cdraw.line((14.6, 7.2), (17.8, 7.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((17.8, 4.6), (21.6, 5.8), fill: luma(235), radius: 0.02)
  cdraw.content((19.7, 5.2), [value], wrap: text.with(size: 6pt))
  cdraw.line((19.7, 6.6), (19.7, 5.8), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((14.6, 2.4), (21.6, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((18.1, 3.0), [`StopIteration`, or #linebreak() `IndexError` from the legacy door], wrap: text.with(size: 6pt))
  cdraw.line((19.7, 4.6), (18.1, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.4, 2.4), (13.0, 3.6), fill: luma(248), radius: 0.02)
  cdraw.content((9.7, 3.0), [loop body runs], wrap: text.with(size: 6pt))
  cdraw.line((18.1, 3.0), (13.0, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((9.7, 3.6), (11.9, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((3.6, 3.0), [exhaustion is permanent, #linebreak() a second loop over the #linebreak() same iterator sees nothing], wrap: text.with(size: 6pt))
  cdraw.content((4.2, 1.4), [`next(it, default)` swallows the stop, #linebreak() `reversed` needs `__len__` #linebreak() on the legacy door], wrap: text.with(size: 6pt))
})

== comprehensions and generators

A comprehension is an eager loop spelled inline, and since python 3 it
runs in its own scope: the loop variable never leaks. A generator
expression looks almost identical and behaves almost oppositely:

#listing("python/samples/src/Ch04/gens.py", first: 18, last: 22, caption: [laziness proven by appending to the source, and the spent genexp])

Nothing runs until the first `next`, so the appended `3` is part of the
result, and once consumed the genexp is finished. Generator functions are
the full form, with a two way channel:

#listing("python/samples/src/Ch04/gens.py", first: 25, last: 41, caption: [send injecting the value a yield evaluates to, and close ending the generator])

The `send` check is the one worth sitting with: `got = yield 1` makes 41
the value of the expression the paused generator resumes into.
`return` inside a generator is not an error, it rides out as the value of
the final `StopIteration`, and `yield from` delegates and captures it:

#listing("python/samples/src/Ch04/gens.py", first: 44, last: 63, caption: [the payload on StopIteration, and yield from delivering it])

Comprehension scoping closes the loop the lexical chapter opened: the
comprehension variable stays inside, and a walrus in a comprehension
filter binds in the enclosing scope, the one deliberate exception:

#listing("python/samples/src/Ch04/gens.py", first: 65, last: 84, caption: [no leak, the walrus exception, and nested comprehensions reading like nested for loops])

The eager and lazy forms are the same pipeline wearing different clothes,
and the async world lifts the whole design: `yield` becomes `await`, the
generator protocol becomes coroutines, see
#xref-to("python", "asyncio").

#diagram([one pipeline, two evaluations, and the two way generator channel], length: 13pt, {
  cdraw.content((4.6, 8.6), [eager: list comprehension], wrap: text.with(size: 6.5pt))
  cdraw.rect((0.6, 7.0), (4.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((2.6, 7.5), [source], wrap: text.with(size: 6pt))
  cdraw.rect((5.6, 7.0), (9.6, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((7.6, 7.5), [filter + map], wrap: text.with(size: 6pt))
  cdraw.rect((10.6, 7.0), (14.6, 8.0), fill: luma(205), radius: 0.02)
  cdraw.content((12.6, 7.5), [full list, now], wrap: text.with(size: 6pt))
  for x0 in (4.6, 9.6) {
    cdraw.line((x0, 7.5), (x0 + 1.0, 7.5), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((17.9, 8.6), [lazy: genexp, generator], wrap: text.with(size: 6.5pt))
  cdraw.rect((15.6, 7.0), (20.2, 8.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.9, 7.5), [same filter + map], wrap: text.with(size: 6pt))
  cdraw.rect((15.6, 5.2), (20.2, 6.2), fill: luma(248), radius: 0.02)
  cdraw.content((17.9, 5.7), [paused at `yield`], wrap: text.with(size: 6pt))
  cdraw.line((17.9, 7.0), (17.9, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.9, 4.6), [nothing runs until asked, one shot], wrap: text.with(size: 6pt))
  cdraw.line((12.6, 7.0), (12.6, 5.7), stroke: luma(140), dash: "dashed")
  cdraw.line((12.6, 5.7), (15.6, 5.7), stroke: luma(140), dash: "dashed", mark: (end: ">"))
  cdraw.content((14.0, 6.0), [same shape], wrap: text.with(size: 6pt))
  let chan(x, y, t) = {
    cdraw.rect((x, y), (x + 7.2, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.6, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  chan(0.6, 2.6, [`next()`: run to #linebreak() the next `yield`])
  chan(12.0, 2.6, [`send(v)`: `v` is #linebreak() the yield's value])
  chan(0.6, 1.2, [`close()`: `GeneratorExit` #linebreak() raised at the yield])
  chan(12.0, 1.2, [`return` x rides out #linebreak() on `StopIteration.value`])
})

== heapq, bisect, counter, deque

Four utility collections replace the loops people write by hand. `heapq`
keeps a list satisfying the heap invariant, parent no greater than either
child, with the minimum at index 0:

#listing("python/samples/src/Ch04/utils.py", first: 21, last: 36, caption: [the invariant checked directly, pops in ascending order, and the top of the heap])

`nlargest` and `nsmallest` (lines 38 through 42) read the same heap for
the fixed size case without paying a full sort. `bisect` maintains a
sorted list by finding the insertion point with binary search:

#listing("python/samples/src/Ch04/utils.py", first: 44, last: 51, caption: [insort keeping order on insert, and left against right around the equal run])

`deque` is a doubly linked block structure with cheap ends, a `maxlen`
that turns it into a ring, and a `rotate` that walks it:

#listing("python/samples/src/Ch04/utils.py", first: 53, last: 60, caption: [bounded eviction from the opposite end, rotation, and both ends cheap])

`Counter` is a dict subclass that counts, and because it is a dict its
order rules apply: ties in `most_common` keep first-seen order:

#listing("python/samples/src/Ch04/utils.py", first: 62, last: 70, caption: [tie order, and the + and - arithmetic with empty results dropped])

#diagram([what each utility buys, and what it costs], length: 13pt, {
  let cols = ("heapq", "bisect", "deque", "Counter")
  let cw = 4.5
  let cx(i) = 2.8 + i * 4.75
  for (i, h) in cols.enumerate() {
    cdraw.rect((cx(i), 8.2), (cx(i) + cw, 9.0), fill: luma(205), radius: 0.02)
    cdraw.content((cx(i) + cw / 2, 8.6), h, wrap: text.with(size: 7pt))
  }
  let cell(i, y, t) = {
    cdraw.rect((cx(i), y), (cx(i) + cw, y + 1.7), fill: luma(235), radius: 0.02)
    cdraw.content((cx(i) + cw / 2, y + 0.85), t, wrap: text.with(size: 6pt))
  }
  let rowlabel(y, t) = cdraw.content((1.5, y + 0.85), t, wrap: text.with(size: 6.5pt))
  rowlabel(6.3, [gives])
  rowlabel(4.3, [cost])
  rowlabel(2.3, [beats])
  cell(0, 6.3, [min at index 0, #linebreak() streaming top k])
  cell(1, 6.3, [insert keeps order, #linebreak() binary search])
  cell(2, 6.3, [O(1) at both ends, #linebreak() maxlen ring])
  cell(3, 6.3, [counts, dict order, #linebreak() arithmetic])
  cell(0, 4.3, [push pop O(log n), #linebreak() not fully sorted])
  cell(1, 4.3, [O(log n) find, #linebreak() O(n) insert])
  cell(2, 4.3, [O(1) ends only, #linebreak() O(n) middle])
  cell(3, 4.3, [one counting pass, #linebreak() ties keep first seen])
  cell(0, 2.3, [a sort per query])
  cell(1, 2.3, [linear scans])
  cell(2, 2.3, [`list.pop(0)`])
  cell(3, 2.3, [manual counting])
  cdraw.content((11.1, 0.5), [nlargest and nsmallest cover fixed size top k without a sort], wrap: text.with(size: 6pt))
})

#callout("verify", "45 checks, three red drafts behind them", [
  The collections sample went red on its own expectations three times
  before it went green, and all three were instruction, not bug. `|=`
  merges only the new operand, so the expected dict had one key, not
  three. The first `send` draft yielded 2 instead of 41 because the
  assignment target has to be the first `yield` the generator pauses at.
  And counter subtraction keeps keys the other operand never mentions,
  so the fixture needed a b count in it. The gate caught all three.
  Sample behavior verified by `make verify-py`, 45 checks in chapter 4 of
  the samples suite.
])

sources: docs.python.org/3/library/stdtypes.html (list append as
amortized constant, dict insertion order, set membership),
docs.python.org/3/library/functions.html (iter including the
`__getitem__` fallback, next, zip and its strict flag, map and its new
strict flag, enumerate, reversed),
docs.python.org/3/reference/expressions.html (comprehension scope,
yield, yield from, generator methods),
docs.python.org/3/library/heapq.html, library/bisect.html,
library/collections.html (deque and Counter),
docs.python.org/3/whatsnew/3.10.html (zip strict),
docs.python.org/3/whatsnew/3.14.html (map strict), and
peps.python.org/pep-0584/ (dict merge operators), all accessed
2026-09-12; the sizeof ladders and the heap array were probed on this
machine the same day. Sample behavior verified by `make verify-py`, 45
checks in chapter 4.
