#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= objects, prototypes, and classes

Everything in the language that is not a primitive is an object, and
objects carry three systems at once: literal syntax that builds them
in place, a prototype chain that lets one object delegate to another,
and a class syntax that packages constructors, prototypes, and
encapsulation into one declaration. The class keyword adds no new
object model, it is the same delegation underneath, plus one
mechanism literals never had, `#private` fields. The typescript
typing of all of this, interfaces and structural shapes, belongs to
chapter 15.

== literals and key order

Object literals accept shorthand names, computed keys in brackets,
and method shorthand, and they lay out their keys under one rule:
integer like keys first in ascending order, then string keys in
insertion order, then symbol keys:

#listing("javascript/samples/src/ch04-objects.mjs", first: 4, last: 21, caption: [shorthand, a computed key, method shorthand, and the key order they produce])

#diagram([the written order against the read order, one rule between them], length: 13pt, {
  cdraw.content((12.0, 9.0), [one literal, written against read], size: 6.5pt, fill: luma(100))
  cdraw.content((1.6, 8.4), [written], size: 6pt, fill: luma(100))
  let cell(x, y, t, dark) = {
    cdraw.rect((x, y), (x + 4.4, y + 1.2), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((x + 2.2, y + 0.6), t, size: 6pt)
  }
  cell(3.4, 7.2, [`title`], false)
  cell(8.2, 7.2, [`2`], false)
  cell(13.0, 7.2, [`1`], false)
  cell(17.8, 7.2, [`tag`], false)
  cdraw.line((12.8, 7.2), (12.8, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((14.2, 6.6), [the layout rule], size: 6pt)
  cdraw.content((1.6, 5.8), [read], size: 6pt, fill: luma(100))
  cell(3.4, 4.6, [`1`], true)
  cell(8.2, 4.6, [`2`], true)
  cell(13.0, 4.6, [`title`], false)
  cell(17.8, 4.6, [`tag`], false)
  cdraw.content((12.8, 3.5), [integer like keys ascending first, #linebreak() then strings and symbols in insertion order], size: 6pt)
  cdraw.rect((3.4, 1.2), (22.2, 2.6), fill: luma(235), radius: 0.02)
  cdraw.content((12.8, 1.9), [serialization order is a runtime concern, #linebreak() `Map` keeps insertion order for every key], size: 6pt)
})

The written order `title, 2, 1, tag` comes back as `1, 2, title,
tag`, which is why serialization order is a runtime concern and why
`Map`, which keeps insertion order for every key, exists for the
cases where that order must be exact.

== descriptors

Every property sits on a property descriptor with three flags,
`writable`, `enumerable`, and `configurable`, and the two ways to
create a property disagree about their defaults. Literal properties
are open on all three. `Object.defineProperty` defaults every flag
to false, which makes it the tool for locking a property down:

#listing("javascript/samples/src/ch04-objects.mjs", first: 23, last: 42, caption: [the two default worlds, and the assignment a closed descriptor rejects])

#diagram([the two default worlds, three flags each way], length: 13pt, {
  cdraw.content((4.4, 8.4), [created by], size: 6.5pt, fill: luma(100))
  cdraw.content((9.8, 8.4), [`writable`], size: 6.5pt, fill: luma(100))
  cdraw.content((14.4, 8.4), [`enumerable`], size: 6.5pt, fill: luma(100))
  cdraw.content((19.2, 8.4), [`configurable`], size: 6.5pt, fill: luma(100))
  let row(y, how, w, e, c, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((4.4, y + 0.7), how, size: 6pt)
    cdraw.content((9.8, y + 0.7), w, size: 6pt)
    cdraw.content((14.4, y + 0.7), e, size: 6pt)
    cdraw.content((19.2, y + 0.7), c, size: 6pt)
  }
  row(6.4, [a literal, `{ a: 1 }`], [true], [true], [true], false)
  row(4.4, [`defineProperty`], [false], [false], [false], true)
  for x in (7.4, 12.2, 16.8) { cdraw.line((x, 4.4), (x, 7.8), stroke: luma(220)) }
  cdraw.content((11.6, 3.2), [the closed descriptor rejects the assignment, a `TypeError` in module code], size: 6.5pt)
  cdraw.rect((4.0, 1.4), (19.2, 2.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 2.0), [`Object.freeze` and accessors ride the same substrate], size: 6pt)
})

The rest of the object machinery, `Object.freeze` sealing everything
shut, getters and setters as accessor descriptors, lives on this
one substrate. This book touches descriptors where the standard
library requires them and uses classes for structure.

== delegation

An object holds a link to another object, its prototype, and every
property read walks that link on a miss. `Object.create` builds the
link directly and is the whole mechanism in one call:

#listing("javascript/samples/src/ch04-objects.mjs", first: 44, last: 66, caption: [a chain built by hand, shadowing, own against inherited, and the null prototype])

#flow(
  [one property read walking a two link chain],
  node((0, 0), [read `child.greet`]),
  node((3.2, 0), [own properties, miss]),
  node((6.4, 0), [the prototype, hit]),
  node((0, 2.2), [read `child.who`]),
  node((3.2, 2.2), [own property, hit, #linebreak() the shadow]),
  node((6.4, 2.2), [never consulted]),
  edge((0, 0), (3.2, 0), "-|>"),
  edge((3.2, 0), (6.4, 0), "-|>"),
  edge((0, 2.2), (3.2, 2.2), "-|>"),
)

`this` inside the inherited method is the object the read started
from, which is why `child.greet()` says `hi child` even though
`greet` lives on `base`. `Object.hasOwn` is the modern own against
inherited question, and `Object.create(null)` builds an object that
delegates nowhere, no `toString`, no `hasOwnProperty`, a clean slate
dictionary that foreign property reads cannot pollute.

== classes

A class packages the same delegation with dedicated syntax: a
constructor, methods on the prototype, accessors as getter setter
pairs, statics that belong to the constructor, and private fields
that are a runtime brand rather than a property:

#listing("javascript/samples/src/ch04-objects.mjs", first: 68, last: 97, caption: [statics with their once only block, an accessor pair, and one hash private field])

Static fields and static blocks run once, at class definition time
and in source order, before any instance exists, which the order
array records and the test pins. `extends` links two classes, both
their prototypes and their constructors, `super` reaches the base
implementation, and statics inherit along the constructor chain:

#listing("javascript/samples/src/ch04-objects.mjs", first: 99, last: 128, caption: [extends and super, statics inherited, the instanceof chain])

#diagram([two links extends builds, and what each carries], length: 13pt, {
  // the instance rail
  cdraw.content((5.0, 8.6), [instances], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.8), (9.6, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((5.0, 7.3), [a `Calibrated` instance], size: 6pt)
  cdraw.line((5.0, 6.8), (5.0, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((6.0, 6.45), [dunder proto], size: 6pt)
  cdraw.rect((0.4, 5.0), (9.6, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((5.0, 5.5), [`Calibrated.prototype`, #linebreak() `bump` calls `super`], size: 6pt)

  // the constructor rail
  cdraw.content((17.5, 8.6), [constructors, statics], size: 6.5pt, fill: luma(100))
  cdraw.rect((12.4, 6.8), (22.6, 7.8), fill: luma(235), radius: 0.02)
  cdraw.content((17.5, 7.3), [`Calibrated`], size: 6pt)
  cdraw.line((17.5, 6.8), (17.5, 6.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((18.6, 6.45), [`extends`], size: 6pt)
  cdraw.rect((12.4, 5.0), (22.6, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((17.5, 5.5), [`Meter`, `instances`, `origin`], size: 6pt)

  // the read
  cdraw.content((11.6, 3.4), [`Calibrated.origin` resolves in one hop, #linebreak() `c instanceof Meter` walks both rails], size: 6.5pt)
  cdraw.content((11.6, 1.6), [`new Meter(3)` increments `Meter.instances`, #linebreak() derived construction runs `super` first], size: 6.5pt)
})

== private fields

A `#` name is not a property. It lives in a per class brand slot,
`Object.keys` cannot see it, no cast can reach it, and a method
invoked with a foreign receiver throws rather than reads garbage:

#listing("javascript/samples/src/ch04-objects.mjs", first: 130, last: 145, caption: [the brand against keys and against an imposter receiver])

#diagram([the hash name as a brand, what each probe meets], length: 13pt, {
  cdraw.content((11.6, 10.0), [a `#` name is not a property], size: 6.5pt, fill: luma(100))
  cdraw.rect((2.0, 8.4), (21.2, 9.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 9.0), [a per class brand slot, outside the property system], size: 6pt)
  cdraw.content((5.0, 7.5), [the probe], size: 6.5pt, fill: luma(100))
  cdraw.content((15.4, 7.5), [what it meets], size: 6.5pt, fill: luma(100))
  let row(y, probe, meets, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.2), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((5.0, y + 0.6), probe, size: 6pt)
    cdraw.content((15.4, y + 0.6), meets, size: 6pt)
  }
  row(6.0, [`Object.keys`], [cannot see it], false)
  row(4.5, [a cast], [cannot reach it], false)
  row(3.0, [a foreign receiver], [throws rather than reads garbage], true)
  row(1.5, [the name outside the class body], [a syntax error, privacy by grammar], false)
  cdraw.line((9.8, 1.5), (9.8, 7.2), stroke: luma(220))
  cdraw.content((11.6, 0.4), [closures were the other door: one brand per class, one binding per call], size: 6.5pt)
})

Outside the class body the name `#reading` is a syntax error, so
privacy is enforced by the grammar, not by convention. The getter is
the door, and chapter 3's closures were the other door to the same
privacy, one brand per class against one binding per call.

`instanceof` closes the chapter because it answers the question all
this machinery raises, what is this object. The operator consults
`Symbol.hasInstance`, and any object can implement that method, so
the check is a protocol rather than a hardcoded operation:

#listing("javascript/samples/src/ch04-objects.mjs", first: 147, last: 157, caption: [a custom hasInstance answering for plain values])

== spread and rest

Object spread copies own enumerable properties from each source in
order, later sources win, and getters are read once and copied as
plain data properties, so a live getter flattens into a snapshot.
Rest destructuring collects the keys not named:

#listing("javascript/samples/src/ch04-objects.mjs", first: 159, last: 177, caption: [later sources winning, a getter becoming data, rest collecting the rest])

#diagram([spread merging three sources into one snapshot, rest collecting the unnamed], length: 13pt, {
  cdraw.content((11.6, 9.4), [own enumerable keys only, later sources win], size: 6.5pt, fill: luma(100))

  // the three sources
  cdraw.rect((0.4, 7.4), (7.2, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 8.0), [`{ a: 1 }`], size: 6pt)
  cdraw.rect((7.9, 7.4), (14.7, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.3, 8.0), [`{ a: 2, b: 3 }`], size: 6pt)
  cdraw.rect((15.4, 7.4), (22.8, 8.6), fill: luma(235), radius: 0.02)
  cdraw.content((19.1, 8.0), [`...source`, `live` a getter], size: 6pt)

  // the merge
  for x in (3.8, 11.3, 19.1) { cdraw.line((x, 7.4), (x, 6.6), stroke: luma(100), mark: (end: ">")) }
  cdraw.rect((0.4, 5.0), (22.8, 6.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 6.25), [the merged literal], size: 6pt)
  let inner(x, w, t, dark) = {
    cdraw.rect((x, 5.2), (x + w, 6.0), fill: if dark { luma(205) } else { none }, stroke: luma(160), radius: 0.02)
    cdraw.content((x + w / 2, 5.6), t, size: 6pt)
  }
  inner(1.0, 4.4, [`a: 2`], true)
  inner(5.8, 4.4, [`b: 3`], false)
  inner(10.6, 5.8, [`live: "computed"`], false)
  inner(16.8, 4.4, [`keep: 1`], false)
  cdraw.content((11.6, 4.4), [the later `a` wins, the getter read once and copied as data], size: 6pt)

  // rest destructuring over the merged keys
  cdraw.rect((4.0, 2.6), (11.4, 3.8), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((7.7, 3.2), [`const { live, ...rest }`], size: 6pt)
  cdraw.line((11.4, 3.2), (12.4, 3.2), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.8, 2.6), (20.2, 3.8), fill: none, stroke: luma(160), radius: 0.02)
  cdraw.content((16.5, 3.2), [`rest` = `a`, `b`, `keep`], size: 6pt)
  cdraw.content((11.6, 1.4), [own enumerable only: inherited properties and `#private` fields stay behind], size: 6pt)
  cdraw.content((11.6, 0.4), [shallow: nested objects are shared], size: 6pt)
})

Spread is the literal's merge operator and the standard way to copy
with changes, `{ ...state, field: next }`. It copies own enumerable
properties only, so inherited properties and `#private` fields stay
behind, and it is shallow, nested objects are shared, which is the
fact to remember before building anything immutable on it.

sources: developer.mozilla.org working with objects, classes, and
private properties pages, tc39.es class fields proposal history,
accessed 2026-09-13. Behavior verified live with node v26.3.0 on
windows, 47 tests green through `npm run verify` in
`javascript/samples`, 11 of them this chapter's.
