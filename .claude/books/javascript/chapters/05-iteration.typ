#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= iteration and collections

Iteration in javascript is a protocol, not an array feature. Anything
that exposes `Symbol.iterator` can flow through `for..of`, spread, and
destructuring, and since ES2025 the protocol carries its own lazy
pipeline methods, `map`, `filter`, `take`, and friends, on the
`Iterator` prototype. This chapter builds the protocol by hand, then
spends it on the collections: Map and Set with their ES2025 algebra
and ES2026 `getOrInsert`, the weak references, and the binary end of
the standard library, `Float16Array` and the `Uint8Array` codecs.

== the iterator protocol

`for..of` does not consume arrays, it consumes a shape: an iterable is
an object whose `Symbol.iterator` method returns an iterator, and an
iterator is an object with a `next` method that produces `{ value,
done }` rows. `Range` below satisfies the shape directly, with no
array anywhere in it:

#listing("javascript/samples/src/ch05-iteration.mjs", first: 4, last: 37, caption: [a hand built iterable feeding spread, for..of, destructuring, and Iterator.from])

Three facts the tests pin. A fresh call to `Symbol.iterator` starts
over, which is why the same `Range` can be spread twice. `Iterator.from`
wraps any iterable in the prototype that carries the helper methods,
and plain arrays do not carry them, `typeof [].drop` is `undefined`:
the helpers belong to iterators, not to arrays.

#diagram([the protocol, stacked], length: 13pt, {
  cdraw.content((11.6, 9.0), [consumers over protocol over shape], size: 6.5pt, fill: luma(100))
  cdraw.rect((2.0, 7.2), (19.6, 8.4), fill: luma(235), radius: 0.02)
  cdraw.content((10.8, 7.8), [`for..of`, spread, destructuring], size: 6pt)
  cdraw.content((21.0, 7.8), [consume], size: 6pt)
  cdraw.rect((2.0, 5.6), (19.6, 6.8), fill: luma(205), radius: 0.02)
  cdraw.content((10.8, 6.2), [`Symbol.iterator` returns an iterator], size: 6pt)
  cdraw.content((21.0, 6.2), [protocol], size: 6pt)
  cdraw.rect((2.0, 4.0), (19.6, 5.2), fill: luma(235), radius: 0.02)
  cdraw.content((10.8, 4.6), [`next()` produces `{ value, done }`], size: 6pt)
  cdraw.content((21.0, 4.6), [shape], size: 6pt)
  cdraw.rect((2.0, 2.4), (19.6, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((10.8, 3.0), [`Range` and generators satisfy it], size: 6pt)
  cdraw.content((21.0, 3.0), [direct], size: 6pt)
  cdraw.content((11.6, 1.2), [the async pair rides the same shape, chapter 6], size: 6.5pt)
})

== generators

A generator function is syntax for writing an iterator: the body
pauses at each `yield` and resumes on the next pull. `yield*`
delegates to another iterable, and the delegated generator's return
value is the value of the whole `yield*` expression, which is how a
delegation chain reports its own summary. `next(value)` is two way:
after the first call, each call's argument becomes the value of the
suspended `yield` expression:

#listing("javascript/samples/src/ch05-iteration.mjs", first: 39, last: 66, caption: [delegation with a return value, and two way next(value)])

#diagram([the body paused and resumed, three pulls of one generator], length: 13pt, {
  cdraw.content((11.6, 10.6), [each pull runs the body to the next pause], size: 6.5pt, fill: luma(100))
  let lane(y, call, happens, result) = {
    cdraw.rect((0.4, y), (4.4, y + 1.2), fill: luma(205), radius: 0.02)
    cdraw.content((2.4, y + 0.6), call, size: 6pt)
    cdraw.line((4.4, y + 0.6), (5.4, y + 0.6), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((5.4, y), (15.6, y + 1.2), fill: luma(235), radius: 0.02)
    cdraw.content((10.5, y + 0.6), happens, size: 6pt)
    cdraw.line((15.6, y + 0.6), (16.6, y + 0.6), stroke: luma(100), mark: (end: ">"))
    cdraw.rect((16.6, y), (22.8, y + 1.2), fill: none, stroke: luma(160), radius: 0.02)
    cdraw.content((19.7, y + 0.6), result, size: 6pt)
  }
  lane(8.6, [`next()`], [starts the body, pauses at the yield], [`"ready"`])
  lane(6.8, [`next(10)`], [10 becomes the suspended `yield`'s value], [`20`])
  lane(5.0, [`next(100)`], [100 in, the body returns], [`300`, done])
  cdraw.rect((0.4, 2.6), (22.8, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 3.4), [`yield* Countdown(3, "done")`: the delegated return `"done"` #linebreak() is the value of the whole `yield*` expression], size: 6pt)
  cdraw.content((11.6, 1.5), [the mechanism `for..of` automates, pull until done], size: 6.5pt)
})

Driven by hand, `Echo` answers `"ready"`, then `20` for the resent 10,
then returns `300` and is done. The test pins all four observations.
Most code never drives a generator by hand, but the mechanism is what
makes generators usable as coroutines in older codebases, and it is
the same mechanism `for..of` automates.

== lazy pipelines

An infinite generator is safe because nothing iterates it whole. The
helper methods, part of ES2025, pull exactly as many values as the
consumer keeps. The pipeline below squares an endless stream, filters
to odd squares, and keeps three. `map` runs five times, for the
squares 1, 4, 9, 16, and 25, and never again: `take(3)` stopped the
pull, and the generator is still willing to continue:

#listing("javascript/samples/src/ch05-iteration.mjs", first: 68, last: 87, caption: [an infinite source through map, filter, take: five calls, three kept])

#diagram([the pull discipline, each helper an iterator wrapping the last], length: 13pt, {
  cdraw.content((11.6, 9.6), [nothing iterates the source whole], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 7.4), (5.6, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 8.1), [`Naturals(1)` #linebreak() infinite], size: 6pt)
  cdraw.line((5.6, 8.1), (6.6, 8.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.6, 7.4), (11.6, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((9.1, 8.1), [`map`, `n * n`], size: 6pt)
  cdraw.line((11.6, 8.1), (12.6, 8.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.6, 7.4), (17.4, 8.8), fill: luma(235), radius: 0.02)
  cdraw.content((15.0, 8.1), [`filter`, odd], size: 6pt)
  cdraw.line((17.4, 8.1), (18.4, 8.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.4, 7.4), (22.8, 8.8), fill: luma(205), radius: 0.02)
  cdraw.content((20.6, 8.1), [`take(3)`], size: 6pt)
  cdraw.rect((0.4, 5.4), (22.8, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 6.1), [`map` runs five times, squares 1, 4, 9, 16, 25, then never again, #linebreak() three kept, 1, 9, 25, the generator still willing], size: 6pt)
  cdraw.rect((0.4, 3.2), (22.8, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 3.9), [`Iterator.concat`: after two `next` calls, #linebreak() the third source is untouched], size: 6pt)
  cdraw.content((11.6, 2.1), [terminals end a pipeline by consuming it: `toArray`, `some`, `every`, `find`, `reduce`], size: 6.5pt)
  cdraw.content((11.6, 1.1), [the array methods copy, the iterator helpers pull], size: 6.5pt)
})

The same discipline on an array would build every intermediate array.
Here nothing materializes: each helper is an iterator wrapping the
one before it, and the final spread is the first full traversal. The
rest of the family works the same way:

#listing("javascript/samples/src/ch05-iteration.mjs", first: 88, last: 99, caption: [drop skips, flatMap expands, reduce folds without materializing])

`reduce` and the other terminals, `toArray`, `some`, `every`, `find`,
end a pipeline because they consume it. Between terminals the chain
stays lazy, which is the whole point: the array methods copy, the
iterator helpers pull.

`Iterator.concat`, one of the ES2026 seven, chains iterables of any
kind into one iterator, left to right, and stays lazy: tapping every
source shows that after two `next` calls only the first two sources
have been touched at all:

#listing("javascript/samples/src/ch05-iteration.mjs", first: 101, last: 123, caption: [three tapped sources concatenated: two pulls in, the third source untouched])

== keyed collections

A Map tracks insertion order, admits any value as a key, and finds
keys by SameValueZero, the equality under which `NaN` equals itself
and the two zeros stay equal, the one difference from `Object.is`.
`set` on an existing key updates in place and keeps the slot, while
delete followed by set re-enters the key at the end, which the key
order in the test makes visible:

#listing("javascript/samples/src/ch05-collections.mjs", first: 1, last: 25, caption: [order kept, set in place, delete and set at the end, NaN findable])

#diagram([the map slots through three operations, order as the visible fact], length: 13pt, {
  cdraw.content((11.6, 10.8), [insertion order kept, one equality underneath], size: 6.5pt, fill: luma(100))
  let slots(y, s1, d1, s2, d2, s3, d3) = {
    let cell(x, t, dark) = {
      cdraw.rect((x, y), (x + 4.0, y + 1.2), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
      cdraw.content((x + 2.0, y + 0.6), t, size: 6pt)
    }
    cell(0.4, s1, d1)
    cell(4.8, s2, d2)
    cell(9.2, s3, d3)
  }
  slots(9.0, [`a 1`], false, [`b 2`], false, [`c 3`], false)
  cdraw.content((18.2, 9.6), [insertion order], size: 6pt)
  slots(7.2, [`a 9`], true, [`b 2`], false, [`c 3`], false)
  cdraw.content((18.2, 7.8), [`set("a", 9)`, `a` keeps its slot], size: 6pt)
  slots(5.4, [`a 9`], false, [`c 3`], false, [`b 9`], true)
  cdraw.content((18.2, 6.0), [delete `b`, then `set`: #linebreak() `b` re-enters at the end], size: 6pt)
  cdraw.line((16.2, 5.4), (16.2, 10.2), stroke: luma(220))
  cdraw.rect((0.4, 2.8), (11.4, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.9, 3.85), [`NaN` findable through `has`], size: 6pt)
  cdraw.content((5.9, 3.15), [SameValueZero: `NaN` equals itself, zeros equal], size: 6pt)
  cdraw.rect((11.8, 2.8), (22.8, 4.2), fill: luma(235), radius: 0.02)
  cdraw.content((17.3, 3.85), [`getOrInsert`: insert once per key], size: 6pt)
  cdraw.content((17.3, 3.15), [`getOrInsertComputed`: callback on the miss], size: 6pt)
  cdraw.content((11.6, 1.7), [a registry builds itself with one line per access], size: 6.5pt)
})

`getOrInsert`, from ES2026, returns the existing entry on a hit and
inserts on a miss, so a registry builds itself with one line per
access and the insert happens exactly once. `getOrInsertComputed`
takes a callback and runs it only on the miss, which is the memoizer
from chapter 3 in one method. `WeakMap` carries the same pair for
object keys:

#listing("javascript/samples/src/ch05-collections.mjs", first: 26, last: 49, caption: [insert once, compute once per key, the weak variant present])

== set algebra

Sets gained seven methods in ES2025, all over SameValueZero. Four
produce new sets, three answer predicates, and every one accepts not
just a Set but any set like object with `size`, `has`, and `keys`:

#listing("javascript/samples/src/ch05-collections.mjs", first: 73, last: 100, caption: [the seven methods, plus a set like object riding union])

#diagram([the seven set methods, four producers and three predicates], length: 13pt, {
  cdraw.content((4.6, 8.4), [produces a new Set], size: 6.5pt, fill: luma(100))
  cdraw.content((17.4, 8.4), [answers a predicate], size: 6.5pt, fill: luma(100))
  let row(y, name, what, dark) = {
    cdraw.rect((0.6, y), (22.6, y + 1.3), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((4.6, y + 0.65), name, size: 6pt)
    cdraw.content((17.4, y + 0.65), what, size: 6pt)
  }
  row(6.8, [`union`], [in either], false)
  row(5.3, [`intersection`], [in both], true)
  row(3.8, [`difference`], [in this, not the argument], false)
  row(2.3, [`symmetricDifference`], [in exactly one], true)
  cdraw.content((8.0, 6.5), [`isSubsetOf`], size: 6pt)
  cdraw.content((8.0, 5.0), [`isSupersetOf`], size: 6pt)
  cdraw.content((8.0, 3.5), [`isDisjointFrom`], size: 6pt)
  cdraw.content((14.2, 6.5), [argument contains this one], size: 6pt)
  cdraw.content((14.2, 5.0), [this one contains the argument], size: 6pt)
  cdraw.content((14.2, 3.5), [nothing in common], size: 6pt)
  cdraw.content((11.6, 1.2), [all seven take a Set or any set like object], size: 6.5pt)
})

== weak references

A `WeakMap` holds entries whose keys it does not keep alive: when
nothing else references a key, the entry can go. The observable,
deterministic facts are narrower than the garbage collector promise:
keys must be objects, primitives throw, entries are not enumerable
and the collection has no `size`, and a `WeakRef` dereferences its
target for as long as a strong reference exists somewhere:

#listing("javascript/samples/src/ch05-collections.mjs", first: 51, last: 72, caption: [primitive keys throw, no size, no iteration, deref sees the target])

#diagram([the weak side, what is deterministic and what the runtime owns], length: 13pt, {
  cdraw.content((11.6, 10.2), [the key question first], size: 6.5pt, fill: luma(100))
  cdraw.rect((8.6, 8.8), (15.0, 9.8), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 9.3), [a key arrives, #linebreak() an object?], size: 6pt)
  cdraw.line((8.6, 9.3), (5.6, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.6, 9.15), [no], size: 6pt)
  cdraw.rect((1.0, 7.0), (8.0, 8.2), fill: luma(205), radius: 0.02)
  cdraw.content((4.5, 7.6), [a primitive throws], size: 6pt)
  cdraw.line((15.0, 9.3), (18.2, 8.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.9, 9.15), [yes], size: 6pt)
  cdraw.rect((15.0, 7.0), (22.6, 8.2), fill: luma(235), radius: 0.02)
  cdraw.content((18.8, 7.6), [stored, the key not kept alive], size: 6pt)
  cdraw.line((18.8, 7.0), (18.8, 6.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((13.0, 4.8), (22.6, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((17.8, 5.4), [no strong reference anywhere: #linebreak() the entry can go, when is a runtime decision], size: 6pt)
  cdraw.content((4.5, 6.4), [no `size`, not enumerable], size: 6.5pt)
  cdraw.rect((1.0, 4.8), (11.4, 6.0), fill: luma(235), radius: 0.02)
  cdraw.content((6.2, 5.4), [`WeakRef.deref()` sees the target #linebreak() while a strong reference exists somewhere], size: 6pt)
  cdraw.content((11.6, 3.5), [uses: caches and metadata attached to objects, #linebreak() lifetimes that belong to someone else], size: 6.5pt)
})

When collection actually happens is a runtime decision, so the tests
claim only the deterministic parts. The uses are caches and metadata
attached to objects whose lifetime belongs to someone else, the
pattern chapter 3's memoizer would want if its keys were DOM nodes.

== binary data

`Float16Array`, ES2025, is the half precision end of the typed array
family, two bytes per element. It keeps exactly what fits in eleven
bits of significand and rounds the rest, `Math.f16round` performs the
rounding without the array, and `DataView` reads and writes the
format at a byte offset:

#listing("javascript/samples/src/ch05-collections.mjs", first: 101, last: 119, caption: [an exact f16, a rounded pi, f16round, and a DataView round trip])

The `Uint8Array` codecs, part of the ES2026 seven, end the era of
hand rolled base64: `toBase64` and `setFromBase64`, `toHex` and
`setFromHex`, one method per direction, each pair a byte exact round
trip:

#listing("javascript/samples/src/ch05-collections.mjs", first: 120, last: 139, caption: [hex and base64 round trips, and text through the same codecs])

#diagram([f16 memory, the view over it, and the codec pairs], length: 13pt, {
  cdraw.content((11.6, 10.4), [two bytes per element, eleven bits of significand], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 8.6), (4.0, 9.8), fill: luma(205), radius: 0.02)
  cdraw.content((2.2, 9.2), [1 sign bit], size: 6pt)
  cdraw.rect((4.2, 8.6), (11.0, 9.8), fill: luma(235), radius: 0.02)
  cdraw.content((7.6, 9.2), [5 exponent bits], size: 6pt)
  cdraw.rect((11.2, 8.6), (22.8, 9.8), fill: luma(235), radius: 0.02)
  cdraw.content((17.0, 9.2), [10 fraction bits], size: 6pt)
  cdraw.content((11.6, 7.9), [`1 + 1/1024` kept exact, `pi` rounds to the nearest f16, #linebreak() `Math.f16round` rounds the rest without the array], size: 6pt)

  // the view over a buffer
  cdraw.rect((0.4, 5.6), (3.2, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((1.8, 6.2), [byte 0], size: 6pt)
  cdraw.rect((3.4, 5.6), (6.2, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((4.8, 6.2), [byte 1], size: 6pt)
  cdraw.line((6.2, 6.2), (7.2, 6.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((7.2, 5.6), (17.0, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((12.1, 6.2), [`DataView`, reads the format #linebreak() at a byte offset], size: 6pt)

  // the codec pairs
  cdraw.rect((0.4, 3.0), (11.0, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((5.7, 3.6), [`toBase64` and `setFromBase64`], size: 6pt)
  cdraw.rect((11.6, 3.0), (22.8, 4.2), fill: luma(205), radius: 0.02)
  cdraw.content((17.2, 3.6), [`toHex` and `setFromHex`], size: 6pt)
  cdraw.content((11.6, 1.9), [es2026, one method per direction, each pair a byte exact round trip], size: 6.5pt)
  cdraw.content((11.6, 0.9), [the era of hand rolled base64 ends here], size: 6.5pt)
})

The pattern to hold onto: iteration is pull based and the helpers
keep it pull based, the keyed collections ride one equality,
SameValueZero, and the binary additions round out what used to need
userland libraries. Chapter 6 puts the same protocol to work async,
and chapter 8 places each addition on its edition shelf.

#callout("note", "what this chapter measured", [
  Iterator helpers, Set methods, and `Float16Array` are ES2025;
  `Iterator.concat`, `getOrInsert`, and the `Uint8Array` base64 and
  hex codecs are three of the ES2026 seven. All of it measured live
  on node v26.3.0, the seven set methods one by one, the laziness
  claim by call counting, and the f16 values by exact comparison.
])

sources: developer.mozilla.org iteration protocols, iterator helpers,
set methods, typed array, and base64 pages, tc39.es es2025 iterator
helpers and set methods clauses, tc39 proposals for concat, getOrInsert,
and uint8array base64, accessed 2026-09-13. Behavior verified live
with node v26.3.0 on windows, 67 tests green through `npm run verify`
in `javascript/samples`, 20 of them this chapter's.
