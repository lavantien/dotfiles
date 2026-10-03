#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= css answers: box model, cascade, layout

The css round asks three questions in different clothes: how big
is the box, which declaration wins, and where does the content
land. This chapter answers each with the smallest model that
stays true, the box model as arithmetic, the cascade as a
sortable key, flex and grid as free-space distribution, media
queries as predicates over a viewport. The `ch32-js` workspace
runs the models under `node --test`, 14 tests, zero dependencies,
and the three stylesheets are real files, listed verbatim, never
executed by the suite, the same honesty the dom chapter set.

== the box model and the two box sizes [EWC]

A box is four nested rectangles, content, padding, border,
margin, and everything turns on which of them the `width`
property names. Under `content-box`, the default, width names the
content edge and padding and border add on. Under `border-box`,
width names the border edge and the content area shrinks to pay
for what it contains. Margin sits outside both, it separates
siblings, it is never part of the box. The stylesheet holds both
sizes side by side:

#listing("interview-repertoire/samples/ch32-js/src/box-model.css", first: 5, last: 34, caption: [the reset, then the same card measured under content-box and border-box])

The arithmetic the listing implies is one function pair:

#listing("interview-repertoire/samples/ch32-js/src/boxsize.mjs", first: 5, last: 19, caption: [outerWidth and contentWidth, the same numbers read both ways])

The spoken answer with numbers: a `width: 120px` card with `8px`
padding and a `4px` border occupies 144px under content-box and
120px under border-box, the content area 120px and 96px
respectively, and the `16px` margins push neighbors 176px and
152px away. That arithmetic is why the universal reset is
`box-sizing: border-box`: sizing by the border edge makes a
`width: 100%` child with padding stop overflowing its parent, and
every framework ships exactly that reset.

#diagram([one element measured both ways, the width property names a different edge], length: 13pt, {
  // true-scale segments, 1px = 0.07 units: margin 16, border 4, padding 8, content 120 or 96
  let span(x0, x1, y, label) = {
    cdraw.line((x0, y), (x1, y), stroke: luma(100))
    cdraw.line((x0, y - 0.15), (x0, y + 0.15), stroke: luma(100))
    cdraw.line((x1, y - 0.15), (x1, y + 0.15), stroke: luma(100))
    cdraw.content(((x0 + x1) / 2, y - 0.55), label, size: 6pt)
  }
  cdraw.content((11.5, 12.3), [content-box], size: 6.5pt)
  cdraw.content((11.5, 11.65), [the width names the content edge], size: 6pt)
  cdraw.rect((4.5, 10.3), (6.46, 11.1), fill: luma(250), stroke: luma(150), radius: 0.0)
  cdraw.rect((6.46, 10.3), (6.74, 11.1), fill: luma(205), stroke: luma(120), radius: 0.0)
  cdraw.rect((6.74, 10.3), (7.3, 11.1), fill: luma(240), stroke: luma(150), radius: 0.0)
  cdraw.rect((7.3, 10.3), (15.7, 11.1), fill: luma(225), stroke: luma(120), radius: 0.0)
  cdraw.content((11.5, 10.7), [content], size: 6pt)
  cdraw.rect((15.7, 10.3), (16.26, 11.1), fill: luma(240), stroke: luma(150), radius: 0.0)
  cdraw.rect((16.26, 10.3), (16.54, 11.1), fill: luma(205), stroke: luma(120), radius: 0.0)
  cdraw.rect((16.54, 10.3), (18.5, 11.1), fill: luma(250), stroke: luma(150), radius: 0.0)
  span(7.3, 15.7, 9.7, [width 120])
  span(6.46, 16.54, 8.5, [outer 144, padding and border added])
  cdraw.content((11.7, 7.1), [border-box], size: 6.5pt)
  cdraw.content((11.7, 6.45), [the width names the border edge, the content area pays], size: 6pt)
  cdraw.rect((4.5, 5.1), (6.46, 5.9), fill: luma(250), stroke: luma(150), radius: 0.0)
  cdraw.rect((6.46, 5.1), (6.74, 5.9), fill: luma(205), stroke: luma(120), radius: 0.0)
  cdraw.rect((6.74, 5.1), (7.3, 5.9), fill: luma(240), stroke: luma(150), radius: 0.0)
  cdraw.rect((7.3, 5.1), (14.02, 5.9), fill: luma(225), stroke: luma(120), radius: 0.0)
  cdraw.content((10.66, 5.5), [content], size: 6pt)
  cdraw.rect((14.02, 5.1), (14.58, 5.9), fill: luma(240), stroke: luma(150), radius: 0.0)
  cdraw.rect((14.58, 5.1), (14.86, 5.9), fill: luma(205), stroke: luma(120), radius: 0.0)
  cdraw.rect((14.86, 5.1), (16.82, 5.9), fill: luma(250), stroke: luma(150), radius: 0.0)
  span(6.46, 14.86, 4.5, [width 120, the declared number])
  span(7.3, 14.02, 3.3, [content 96])
  cdraw.content((11.5, 1.9), [margin sits outside both measurements: it separates siblings], size: 6pt)
  cdraw.content((11.5, 1.0), [shading, inside out: content, padding 8, border 4, margin 16], size: 6pt)
})

== the cascade, specificity, and selector matching [TDD]

The cascade answers "which declaration wins" with a sort, not a
vote, and matching runs first. A selector either describes a node
or it does not, and the engine below is the whole grammar the
interview needs, type, class, id, and the descendant and child
combinators, walked over the plain tree
#xref-to("repertoire", "js-dom") builds:

#listing("interview-repertoire/samples/ch32-js/src/match.mjs", first: 6, last: 47, caption: [compound matching, the two combinators, and the rightmost-first chain walk])

The subject of a selector is its rightmost compound, so the walk
tests every node as the subject and looks leftward through its
ancestors:

#listing("interview-repertoire/samples/ch32-js/src/match.mjs", first: 49, last: 63, caption: [select: every node in tree order the subject matches])

Conflict resolution is a sortable key with four fields, compared
in order, importance, origin, specificity, source order, and
specificity itself is a triple (a, b, c), ids, classes, types,
compared lexicographically, so one id beats any pile of classes
and one class beats any pile of types:

#listing("interview-repertoire/samples/ch32-js/src/cascade.mjs", first: 6, last: 22, caption: [specificity as a triple, compared lexicographically])

#listing("interview-repertoire/samples/ch32-js/src/cascade.mjs", first: 28, last: 47, caption: [the tiebreaker chain and the winning declaration])

An inline style enters with an origin above every selector, which
is the "inline beats id" rule, and `!important` flips the
importance field, which is why an author's important declaration
beats a plain style attribute and the attribute's own important
beats it back. The tests pin all three inversions.

#callout("pitfall", "!important is a debugger, not a layer", [
  Importance outranks every rung below it, including
  declarations you have not written yet, so each `!important`
  silently raises the stakes for the next conflict and the sheet
  converges on two kinds of important. The cascade already has a
  tiebreaker for "this rule should win", specificity and order.
  Reach for important to settle an argument with a third-party
  stylesheet you cannot reorder, never inside your own.
])

#diagram([the cascade ladder, one rung per tiebreaker, the first difference decides], length: 13pt, {
  // four rungs top to bottom, consulted only while everything above ties
  let rung(y, t, sub) = {
    cdraw.rect((4.5, y), (17.5, y + 1.5), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((11.0, y + 1.02), t, size: 6.5pt)
    cdraw.content((11.0, y + 0.42), sub, size: 6pt)
  }
  rung(8.8, "importance", "!important flips the comparison")
  rung(6.9, "origin", "the style attribute beats any selector")
  rung(5.0, "specificity", "(a, b, c): one id beats any class count")
  rung(3.1, "source order", "still tied: the later declaration wins")
  for y in (8.8, 6.9, 5.0) {
    cdraw.line((11.0, y), (11.0, y - 0.4), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((11.5, 1.9), [a lower rung is consulted only when everything above ties], size: 6pt)
  cdraw.content((11.5, 1.0), [inside specificity: one class beats any type count], size: 6pt)
})

== flex and grid, the layout answers [EWC]

Flex and grid answer "where does the content land" by giving the
space a different owner. In flex the items own a basis and the
container's leftover space is distributed into the items, in
proportion to their grow factors. In grid the tracks own the
space, the fixed tracks are paid first and the remainder splits
by the fr ratio, and the items land wherever the tracks resolved.
The stylesheet holds the three layouts the inventory names, a
nav bar, a card grid, a holy-grail skeleton:

#listing("interview-repertoire/samples/ch32-js/src/layout.css", first: 5, last: 45, caption: [the flex nav bar, the auto-fill card grid, the grid holy grail])

The arithmetic each implies:

#listing("interview-repertoire/samples/ch32-js/src/layout.mjs", first: 5, last: 28, caption: [free space by grow ratio, fr tracks against what the fixed tracks leave])

The numbers to narrate: a 300px line holding two 100px items
with grow 1 and 3 has 100px free, splits it 25 and 75, and lands
at 125 and 175. A 1000px grid with a 200px fixed track and 1fr
3fr remaining pays the 200 first and splits the remaining 800
into 200 and 600. Centering is its own spoken answer with its
own precedent, flex, grid, and absolute plus translate, floored
to #xref-to("repertoire", "js-dom"), and nothing here revises
it.

#diagram([flex distributes leftover space into items, grid distributes it into tracks first], length: 13pt, {
  // left: a 300px line, bases 100 and 100, grow 1 and 3; right: a 1000px grid, 200 fixed then 1fr 3fr
  cdraw.content((6.5, 9.6), [flex, the items take the free space], size: 6.5pt)
  cdraw.rect((0.5, 8.1), (12.5, 9.1), stroke: luma(120))
  cdraw.rect((0.5, 8.1), (5.5, 9.1), fill: luma(225), stroke: luma(120), radius: 0.0)
  cdraw.content((3.0, 8.75), [grow 1], size: 6pt)
  cdraw.content((3.0, 8.35), [125], size: 6pt)
  cdraw.rect((5.5, 8.1), (12.5, 9.1), fill: luma(240), stroke: luma(120), radius: 0.0)
  cdraw.content((9.0, 8.75), [grow 3], size: 6pt)
  cdraw.content((9.0, 8.35), [175], size: 6pt)
  cdraw.content((6.5, 7.3), [300px line, 100px free, split 1:3 into 25 and 75], size: 6pt)
  cdraw.content((18.0, 9.6), [grid, the tracks are paid first], size: 6.5pt)
  cdraw.rect((13.1, 8.1), (22.9, 9.1), stroke: luma(120))
  cdraw.rect((13.1, 8.1), (15.06, 9.1), fill: luma(250), stroke: luma(120), radius: 0.0)
  cdraw.content((14.08, 8.6), [200], size: 6pt)
  cdraw.rect((15.06, 8.1), (17.02, 9.1), fill: luma(235), stroke: luma(120), radius: 0.0)
  cdraw.content((16.04, 8.6), [200], size: 6pt)
  cdraw.rect((17.02, 8.1), (22.9, 9.1), fill: luma(220), stroke: luma(120), radius: 0.0)
  cdraw.content((19.96, 8.6), [600], size: 6pt)
  cdraw.content((18.0, 7.3), [1000px: fixed 200, then 1fr 3fr over 800], size: 6pt)
  cdraw.content((11.5, 5.9), [the leftover flows into items under flex, into tracks under grid], size: 6pt)
  cdraw.content((11.5, 4.9), [grid-template-columns owns the count, no free-space walk ever runs], size: 6pt)
})

== responsive and media queries [TDD]

A media query is a predicate over the viewport, and the css it
guards applies while the predicate holds. `min-width` and
`max-width` are both inclusive at their boundary, `and` demands
every condition, and the engine is deliberately small:

#listing("interview-repertoire/samples/ch32-js/src/media.mjs", first: 5, last: 25, caption: [applicability as a predicate, and the mobile-first pick])

Mobile-first is the discipline that falls out: write the
small-screen styles as the base, add `min-width` blocks that only
add, and each block overrides while its query matches, so the
answer for any viewport is the last applicable block in source
order. The spoken rule the interviewer is checking: breakpoints
sit where the content breaks, not where a device table says, and
the file below never unsays anything the base declared:

#listing("interview-repertoire/samples/ch32-js/src/responsive.css", first: 1, last: 31, caption: [the base and two breakpoints, whole file])

#diagram([the breakpoint ladder: the base is always on, each block adds from its threshold rightward], length: 13pt, {
  // a viewport axis with ticks at 600 and 900, the serving block above each range
  cdraw.rect((1.0, 7.4), (11.5, 8.9), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((6.25, 8.5), [base], size: 6.5pt)
  cdraw.content((6.25, 7.9), [one card per line], size: 6pt)
  cdraw.rect((11.5, 7.4), (16.75, 8.9), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((14.1, 8.5), [600px], size: 6.5pt)
  cdraw.content((14.1, 7.9), [two columns], size: 6pt)
  cdraw.rect((16.75, 7.4), (22.0, 8.9), fill: luma(250), stroke: luma(120), radius: 0.02)
  cdraw.content((19.4, 8.5), [900px], size: 6.5pt)
  cdraw.content((19.4, 7.9), [three columns], size: 6pt)
  cdraw.line((1.0, 6.6), (22.5, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.5, 6.3), (11.5, 6.9), stroke: luma(100))
  cdraw.line((16.75, 6.3), (16.75, 6.9), stroke: luma(100))
  cdraw.content((11.5, 5.8), [600px, inclusive], size: 6pt)
  cdraw.content((16.75, 5.8), [900px], size: 6pt)
  cdraw.content((21.8, 5.8), [width], size: 6pt)
  cdraw.content((11.75, 4.4), [a breakpoint sits where the content breaks, not where a device table says], size: 6pt)
  cdraw.content((11.75, 3.5), [each block only adds: no query ever unsays the base], size: 6pt)
})

== the spoken css answers [DRILL]

z-index and stacking contexts: z-index orders elements inside a
stacking context, and the trap is that it only takes effect on
positioned elements, anything but static, and on children of
flex and grid containers. A new context is born from opacity
below 1, a transform, a filter, fixed or sticky positioning, and
a child inside a context can never win against one outside it,
so the element with z-index 9999 losing to a sibling is almost
always two contexts, not a number too small.

em versus rem: em multiplies the font size it inherits, so
nested ems compound down the tree, 1.2em inside 1.2em on a 16px
root is 23px, and the third level compounds again. rem performs
one multiplication against the root size and never compounds.
The rule to say out loud: type in rem when it should track the
page default, spacing in em when it should track the element's
own type, and know which one the value sits under.

display none, visibility hidden, opacity 0: display none removes
the box, nothing is laid out, painted, or announced. visibility
hidden keeps the box and its space, invisible but present.
opacity 0 keeps box and pixels, transparent but still there,
still clickable unless pointer-events says no. The distinction
that carries into the next chapter: only display none removes
the element from the accessibility tree, the other two leave it
in, which is why visually hidden utilities use clip patterns
instead of opacity when the content should stay announceable.

The position values: static is the flow. relative offsets from
the flow slot and leaves the slot behind. absolute positions
against the nearest positioned ancestor and leaves the flow.
fixed positions against the viewport. sticky is relative until a
scroll threshold, then held inside its containing block, and the
trap: sticky needs a scroll container and a threshold, a sticky
child of a non-scrolling parent does nothing.

vh versus dvh: vh is measured against the large viewport, the
mobile browser with its url bar hidden, so a 100vh hero
overflows the visible screen while the bar is shown. dvh tracks
the dynamic viewport as the bar shows and hides, svh and lvh
name the small and large ends. The honest trade: dvh resizes
while the user scrolls, which can shift layout during the
scroll, so heroes take dvh and stable chrome takes svh.

Why border-box is the reset default: it makes width name the
border edge, so padding stops breaking 100 percent widths, the
arithmetic in the first section, and it is the one line every
framework agrees on.

sources: verified by `npm run verify` under node 26.3.0, 14 tests
in `ch32-js`, zero dependencies. The stylesheets are real files,
listed verbatim, not executed by the suite. The tree the selector
engine walks and the centering precedent both belong to
#xref-to("repertoire", "js-dom"), the invalidation consumer of
these styles is the virtual dom,
#xref-to("repertoire", "react-core"), and an id inside a selector
is a hash lookup in the browser's implementation, the kinship to
#xref-to("dsa", "hashing").
