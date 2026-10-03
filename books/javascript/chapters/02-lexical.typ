#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= values and lexical structure

Values come before types. This chapter is the runtime half of the
language's foundation, how bindings come into existence, what the
primitive types are and how `typeof` reports them, how literals are
spelled, and what the two equality operators actually compare. The
typescript spellings for these same values, annotations and generics
and overloads, live in part two, chapter 12 onward; nothing in this
chapter requires a compiler, and every fact below is executed by a
test.

== declarations and the dead zone

Three declaration forms survived into modern javascript, and each
makes a different promise. `var` is function scoped and redeclares
silently. `let` is block scoped, one binding per name per block. The
difference is observable before either line even runs, because `let`
and `const` bindings exist from the top of their scope but stay
uninitialized until their declaration line, and reading them inside
that window throws:

#listing("javascript/samples/src/ch02-values.mjs", first: 3, last: 13, caption: [the temporal dead zone, caught rather than described])

The `let sneaky` line below the `catch` is unreachable, but it is
still part of the function's scope, which is exactly why the read
above it throws instead of resolving to an outer name. `var` has no
such window, it hoists initialized to `undefined`, and `const`
behaves like `let` with one addition:

#listing("javascript/samples/src/ch02-values.mjs", first: 15, last: 41, caption: [var redeclares, let shadows per block, const freezes the binding not the value])

The third fact is the one that surprises: `const` makes the binding
unreassignable, not the value immutable. A `const` object still
mutates, and the mutation is ordinary code, while rebinding the name
is a `TypeError`. This book uses `const` for almost every binding,
`let` only inside loops that rebind, and `var` only when quoting it.

#diagram([the binding lifecycle of each declaration form], length: 13pt, {
  cdraw.content((11.6, 8.6), [when a name is readable], size: 6.5pt, fill: luma(100))
  let row(y, form, from, note, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((2.4, y + 0.7), form, size: 6pt)
    cdraw.content((7.6, y + 0.7), from, size: 6pt)
    cdraw.content((16.4, y + 0.7), note, size: 6pt)
  }
  row(6.6, [`var`], [scope top, `undefined`], [redeclares silently], false)
  row(4.6, [`let`], [its declaration line], [throws before that line], true)
  row(2.6, [`const`], [its declaration line], [and the name never rebinds], false)
  for x in (5.8, 12.4) { cdraw.line((x, 2.6), (x, 8.0), stroke: luma(220)) }
  cdraw.content((11.6, 1.5), [the window before the line is the temporal dead zone], size: 6.5pt)
})

== the words

The grammar freezes its vocabulary in strata. 35 words are reserved
outright, `if` and `typeof` and `with`, and none of them can ever
name a binding. 4 more, `let`, `static`, `yield`, and `await`, are
reserved only inside strict mode and module code, which is every
file this book runs. 7 are held for the future, `enum`,
`implements`, `interface`, `package`, `private`, `protected`, and
`public`, kept out of circulation so the language can grow into
them. Chapter 24's appendix counts the full census word by word.
Automatic semicolon insertion, the parser's power to end a statement
at a line break, is a non-issue in this book's module code: every
statement carries its own semicolon.

== seven primitives, one lying operator

Every value in the language is either a primitive or an object, and
there are exactly seven primitives: `undefined`, `null`, boolean,
number, bigint, string, and symbol. `typeof` names six of them
honestly:

#listing("javascript/samples/src/ch02-values.mjs", first: 43, last: 59, caption: [the seven primitives carried as values through typeof])

The seventh row is the famous lie, `typeof null` is `"object"`, a
compatibility decision from the language's first implementation that
the spec has carried ever since. Two more readings complete the
operator's behavior, functions report `"function"` even though
function is not a primitive type but an object kind, and `typeof` on
a name that was never declared anywhere returns `"undefined"`
without throwing, the one undeclared read the language allows:

#listing("javascript/samples/src/ch02-values.mjs", first: 61, last: 68, caption: [the null lie, the function kindness, the undeclared safe read])

#diagram([typeof against the seven primitives, six honest answers, the 1995 lie starred], length: 13pt, {
  cdraw.content((3.8, 11.8), [primitive], size: 6.5pt, fill: luma(100))
  cdraw.content((10.6, 11.8), [`typeof` answer], size: 6.5pt, fill: luma(100))
  let row(y, p, t, dark) = {
    cdraw.rect((0.4, y), (14.0, y + 1.2), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((3.8, y + 0.6), p, size: 6pt)
    cdraw.content((10.6, y + 0.6), t, size: 6pt)
  }
  row(10.4, [`undefined`], [`"undefined"`], false)
  row(8.9, [`null`], [`"object"` \*], true)
  row(7.4, [boolean], [`"boolean"`], false)
  row(5.9, [number], [`"number"`], false)
  row(4.4, [bigint], [`"bigint"`], false)
  row(2.9, [string], [`"string"`], false)
  row(1.4, [symbol], [`"symbol"`], false)
  cdraw.line((7.2, 1.4), (7.2, 11.6), stroke: luma(220))

  // the two kindnesses beside the table
  cdraw.rect((15.6, 7.0), (22.8, 9.2), fill: luma(235), radius: 0.02)
  cdraw.content((19.2, 8.3), [functions report `"function"`], size: 6pt)
  cdraw.content((19.2, 7.4), [an object kind, not a primitive], size: 6pt)
  cdraw.rect((15.6, 2.6), (22.8, 4.8), fill: luma(235), radius: 0.02)
  cdraw.content((19.2, 3.9), [an undeclared name reads `"undefined"`], size: 6pt)
  cdraw.content((19.2, 3.0), [without throwing, the one allowed], size: 6pt)
  cdraw.content((11.6, 0.3), [\* the 1995 lie, `typeof null` is `"object"`, carried by the spec ever since], size: 6.5pt)
})

The seventh primitive is the one with no literal spelling, a symbol
is a name minted at run time: `Symbol("s")` returns a fresh unique
value on every call, two calls never compare equal, and a symbol
used as a property key never shows up in `Object.keys`. The
well-known symbols, `Symbol.iterator`, `Symbol.hasInstance`, and
`Symbol.dispose`, are the protocol hooks chapters 4 through 7 build
on.

Primitives are immutable and compared by value, objects are compared
by identity, and that split drives the equality section below.
`Object.freeze` and the object half of the language belong to chapter
4.

== literals

Numbers read in four radices, decimal, hexadecimal with the `0x`
prefix, octal with `0o`, binary with `0b`, and digit separators group
long decimals. Past 2^53 the `number` type, an ieee 754 double, has
run out of exact integers, rounds to even, and `Number.isSafeInteger`
draws the line, while a `bigint` literal carries its trailing `n`
into arbitrary precision:

#listing("javascript/samples/src/ch02-values.mjs", first: 70, last: 82, caption: [four radices, separators, and the 2^53 boundary against bigint])

Strings are single or double quoted or template literals, and
template literals interpolate arbitrary expressions, not just
variables. String contents are utf-16 code units, so one emoji
spans two units and `length` reports 2 while `codePointAt` still
reaches the full code point. The escape grammar spells both, a four
digit code unit escape for the é and a braced code point escape for
the emoji, and `String.raw` keeps a template's backslashes for paths
and patterns:

#listing("javascript/samples/src/ch02-values.mjs", first: 84, last: 95, caption: [interpolation, utf-16 units against code points, escapes, raw])

#diagram([one emoji in utf-16 memory, and the numeric rail beside it], length: 13pt, {
  // the emoji as two code units, one code point
  cdraw.content((6.0, 8.4), [one emoji, two code units, one code point], size: 6.5pt, fill: luma(100))
  cdraw.rect((2.0, 6.6), (7.2, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((4.6, 7.1), [d83d], size: 6pt)
  cdraw.rect((7.4, 6.6), (12.6, 7.6), fill: luma(235), radius: 0.02)
  cdraw.content((10.0, 7.1), [de00], size: 6pt)
  cdraw.content((4.6, 6.1), [unit 0], size: 6pt)
  cdraw.content((10.0, 6.1), [unit 1], size: 6pt)
  cdraw.line((2.0, 5.4), (12.6, 5.4), stroke: luma(220))
  cdraw.line((2.0, 5.2), (2.0, 5.6)); cdraw.line((12.6, 5.2), (12.6, 5.6))
  cdraw.content((7.3, 4.9), [`.length` 2, `codePointAt(0)` 0x1F600], size: 6pt)

  // the numeric rail
  cdraw.content((0.6, 3.6), [the numeric rail], size: 6.5pt, fill: luma(100))
  let chip(x, w, t) = {
    cdraw.rect((x, 2.0), (x + w, 2.9), fill: none, stroke: luma(160), radius: 0.02)
    cdraw.content((x + w / 2, 2.45), t, size: 6pt)
  }
  chip(0.4, 3.0, [`0xff`])
  chip(3.6, 3.0, [`0o10`])
  chip(6.8, 3.4, [`0b101`])
  chip(10.4, 3.2, [`1_000_000`])
  cdraw.content((18.6, 2.45), [four radices, separators], size: 6pt)
  cdraw.rect((0.4, 0.2), (11.0, 1.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.7, 0.8), [`number` rounds 2^53 + 1 to even], size: 6pt)
  cdraw.content((12.6, 0.8), [against], size: 6pt)
  cdraw.rect((14.2, 0.2), (22.8, 1.4), fill: luma(235), radius: 0.02)
  cdraw.content((18.5, 0.8), [`2n ** 53n + 1n` exact], size: 6pt)
})

== two equalities and the same-value operator

`==` runs a coercion algorithm before comparing, `===` does not, and
the honest summary is a table of pairs rather than a rule of thumb:

#listing("javascript/samples/src/ch02-values.mjs", first: 97, last: 108, caption: [coercive pairs against strict pairs, nan, identity, signed zero])

The algorithm has one step the table cannot show, because no pinned
pair mixes an object with a primitive: when only one operand is an
object, it is asked for a primitive first, `valueOf` before
`toString`, and only then do the pair rules apply. Three readings
fall out. Loose equality's one cross type pair is
`null == undefined`, both meaning absence, equal to each other and to
nothing else. `NaN` violates reflexivity under both operators, which
is why `Number.isNaN` exists and why `indexOf` hunts of nan fail.
Objects compare by identity, two fresh `{}` are two different
objects, and the one operator with different opinions is `Object.is`,
the same-value comparison, which distinguishes the two zeros and
identifies the two nans:

#diagram([three verdicts for the hard pairs], length: 13pt, {
  cdraw.content((4.4, 7.1), [pair], size: 6.5pt, fill: luma(100))
  cdraw.content((10.0, 7.1), [`===`], size: 6.5pt, fill: luma(100))
  cdraw.content((16.8, 7.1), [`Object.is`], size: 6.5pt, fill: luma(100))
  let row(y, pair, triple, same, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.4), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((4.4, y + 0.7), pair, size: 6pt)
    cdraw.content((10.0, y + 0.7), triple, size: 6pt)
    cdraw.content((16.8, y + 0.7), same, size: 6pt)
  }
  row(5.4, [`0` against `-0`], [equal], [different], false)
  row(3.6, [`NaN` against `NaN`], [different], [equal], true)
  row(1.8, [`1` against `"1"`], [different], [different], false)
  for x in (7.6, 14.2) { cdraw.line((x, 1.8), (x, 6.8), stroke: luma(220)) }
  cdraw.content((11.6, 0.8), [`Object.is` answers where `===` flattens detail], size: 6.5pt)
})

This book writes `===` everywhere and `==` only in the table above,
where the coercion itself is the subject.

== truthiness

Exactly eight values are falsy. Every other value is truthy, and the
surprises are all strings and objects: `"0"` and `"false"` are
non-empty strings, `[]` and `{}` are objects, and objects are always
truthy no matter how empty:

#listing("javascript/samples/src/ch02-values.mjs", first: 110, last: 116, caption: [the eight falsy values, and truthiness as one operator])

#diagram([the eight falsy values as a closed list, the surprises that stay truthy], length: 13pt, {
  cdraw.content((11.6, 9.3), [exactly eight values are falsy, everything else is truthy], size: 6.5pt, fill: luma(100))
  let chip(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.55), t, size: 6pt)
  }
  chip(0.4, 7.7, 5.2, [`false`])
  chip(6.0, 7.7, 5.2, [`0`])
  chip(11.6, 7.7, 5.2, [`-0`])
  chip(17.2, 7.7, 5.6, [`0n`])
  chip(0.4, 6.3, 5.2, [`""`])
  chip(6.0, 6.3, 5.2, [`null`])
  chip(11.6, 6.3, 5.2, [`undefined`])
  chip(17.2, 6.3, 5.6, [`NaN`])

  // the surprises, all strings and objects
  cdraw.rect((0.4, 3.9), (11.0, 5.1), fill: luma(205), radius: 0.02)
  cdraw.content((5.7, 4.5), [`"0"` and `"false"` #linebreak() non-empty strings, truthy], size: 6pt)
  cdraw.rect((11.6, 3.9), (22.8, 5.1), fill: luma(205), radius: 0.02)
  cdraw.content((17.2, 4.5), [`[]` and `{}` #linebreak() objects, always truthy], size: 6pt)
  cdraw.rect((0.4, 1.4), (22.8, 2.6), fill: luma(235), radius: 0.02)
  cdraw.content((11.6, 2.0), [`??` narrows the list to the two absence values, `null` and `undefined`], size: 6pt)
})

Default parameters and the `??` operator in chapter 3 build directly
on this list, `??` defaults exactly the two absence values rather
than all eight.

sources: developer.mozilla.org grammar and types pages, tc39.es
ecma 262 sections on declarations and equality, accessed 2026-09-13.
Behavior verified live with node v26.3.0 on windows, 23 tests green
through `npm run verify` in `javascript/samples`, 13 of them this
chapter's.
