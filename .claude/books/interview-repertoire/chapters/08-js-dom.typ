#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= javascript and the dom

The dom questions split cleanly: half are about the browser's
document model and css, half are plain javascript wearing a dom
costume. The `ch08-js` workspace runs the javascript half under
`node --test`, 16 tests, and keeps the dom-specific answers as a
real stylesheet, a centering decision model, and the tree-model
demos the node runtime can honestly execute.

== what the dom is [EWC]

The document object model is a tree of nodes the script can read
and write, and every api, `querySelector`, `createElement`,
`addEventListener`, is a walk or a mutation of that tree. The
workspace models the tree as plain data and implements the
canonical query by hand:

#listing("interview-repertoire/samples/ch08-js/src/dom-shape.mjs", first: 5, last: 35, caption: [the document as a tree, and querySelector as an id scope plus a tag walk])

#diagram([the id jump scopes the search, then every li below it is a descendant hit], length: 13pt, {
  // the exact tree buildTree() constructs in the listing above
  let node(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x - w / 2, y - 0.45), (x + w / 2, y + 0.45), fill: fill, stroke: luma(120), radius: 0.05)
    cdraw.content((x, y), [#t], size: 6.5pt)
  }
  node(7.0, 7.0, 3.0, "html")
  node(7.0, 5.6, 3.0, "body")
  node(3.2, 4.2, 3.4, "header")
  node(11.0, 4.2, 6.2, "main id listing", fill: luma(215))
  node(3.2, 2.8, 3.4, "h1 shop")
  node(11.0, 2.8, 3.0, "ul")
  node(8.9, 1.4, 3.4, "li sword", fill: luma(245))
  node(13.1, 1.4, 3.4, "li shield", fill: luma(245))
  cdraw.line((7.0, 6.55), (7.0, 6.05))
  cdraw.line((7.0, 5.15), (3.2, 4.65))
  cdraw.line((7.0, 5.15), (11.0, 4.65))
  cdraw.line((3.2, 3.75), (3.2, 3.25))
  cdraw.line((11.0, 3.75), (11.0, 3.25))
  cdraw.line((11.0, 2.35), (8.9, 1.85))
  cdraw.line((11.0, 2.35), (13.1, 1.85))
  // the selector's two moves: the id jump, then the descendant walk
  cdraw.content((18.3, 4.2), [id jump lands here], size: 6.5pt)
  cdraw.line((14.55, 4.2), (14.15, 4.2), mark: (end: ">"))
  cdraw.line((7.2, 0.7), (14.8, 0.7))
  cdraw.line((7.2, 0.45), (7.2, 0.95))
  cdraw.line((14.8, 0.45), (14.8, 0.95))
  cdraw.content((11.0, 0.1), [the walk takes both], size: 6.5pt)
  cdraw.content((7.0, -0.6), [scope by id, then filter by tag on the way down], size: 6.5pt)
})

The point the demo makes without a browser: `#listing li` is an id
lookup to scope, then a descendant walk for the tag, and the
browser's real implementation differs by using indexes, not by
being a different idea.

== center a div, four honest ways [EWC]

The css lives in a real stylesheet file, one panel per technique:

#listing("interview-repertoire/samples/ch08-js/src/center-a-div.css", first: 11, last: 46, caption: [flex, grid, absolute plus transform, auto margins])

#diagram([four models: the parent flexes, the grid places, the child translates, the child absorbs], length: 13pt, {
  // one panel per technique, the parent box with the child centered inside
  let panel(x, title, sub) = {
    cdraw.content((x + 2.7, 6.9), title, size: 6.5pt)
    cdraw.rect((x, 3.9), (x + 5.4, 6.3), fill: luma(245), stroke: luma(120), radius: 0.05)
    cdraw.rect((x + 2.0, 4.85), (x + 3.4, 5.35), fill: luma(205), radius: 0.02)
    cdraw.content((x + 2.7, 3.3), sub, size: 6pt)
  }
  panel(0.5, "flex, the parent", [justify + align])
  panel(6.4, "grid, one property", [place-items: center])
  panel(12.3, "absolute, the child", [top 50%, left 50%])
  panel(18.2, "auto margins, the child", [margin: auto])
  cdraw.content((12.0, 1.9), [all four handle an unknown child size], size: 6pt)
  cdraw.content((12.0, 0.8), [offer flex first, keep the child-side pair for a parent you cannot restyle], size: 6pt)
})

Each technique is one ownership decision, and the four question
walk settles which to offer.

Flex. What: the parent becomes a flex container and distributes
its free space. Why: it is the default layout tool, so offering it
first reads as fluency rather than recall. How: `display: flex` on
the parent, `justify-content: center` for the inline axis,
`align-items: center` for the block axis. When: one item, and the
parent is yours to restyle.

Grid. What: the same two-axis centering in one declaration. Why:
fewer moving parts, and the shorthand names the concept. How:
`display: grid` then `place-items: center`, which spans
`align-items` plus `justify-items`. When: the same shape as flex,
offered as the shorter spelling.

Absolute plus transform. What: the child carries its own center
onto the parent's center. Why: it survives the one constraint the
parent-side pair cannot, a parent whose `display` must not change.
How: `position: relative` on the parent, then `top: 50%; left:
50%` on the child, whose percentages resolve against the parent's
box, plus `translate(-50%, -50%)`, whose percentages resolve
against the child's own box, the two bases meeting in the middle.
When: a parent you may annotate but not restyle, a child of
unknown size.

Auto margins. What: the child absorbs every unit of free space
around itself. Why: it is the child-side answer when the parent is
already a flex or grid container someone else owns. How:
`margin: auto` on the child, nothing else. When: one child among
siblings inside a container a library or a teammate wrote.

The trap to volunteer: all four handle an unknown child size. The
one spelling that does need a known size is the older absolute
variant, `inset: 0` with `margin: auto`, which centers only when
width and height are set, and naming why the transform spelling
replaced it is the flex that ends the follow-up.

The spoken answer: offer flex first, `justify-content` and
`align-items` on the parent, grid `place-items` as the shorter
spelling, the absolute plus transform pair when the parent's
display is frozen, and `margin: auto` when the child must own the
move inside a container someone else wrote.

== centering edge cases: the group, the overflow, the choice [TDD]

Two follow-ups end most centering questions, and both are
decisions rather than declarations, so the workspace pins the
choice as a model you can run and the panels as real css:

#listing("interview-repertoire/samples/ch08-js/src/centering.mjs", first: 10, last: 67, caption: [pickCentering walks the ownership ladder, placeItemsVsPlaceContent settles the follow-up])

#listing("interview-repertoire/samples/ch08-js/src/center-a-div.css", first: 48, last: 63, caption: [the group panel and the overflow panel])

The group edge. What: `place-content: center` centers the items as
one track. Why: `place-items` centers each item inside its own
cell, so a group asked to sit in the middle needs its track moved,
not its items. How: `display: grid` with `place-content: center`,
the shorthand spanning `align-content` plus `justify-content`.
When: more than one item with the parent's display yours to set,
and the interviewer says group, cluster, or row. A frozen parent
display forfeits the shortcut, the items wrap in one element and
the wrapper takes the transform pair.

The overflow edge. What: `safe center` abandons center for start
exactly when the item is larger than its container. Why: plain
center on an oversized item clips both ends out of scroll's reach,
the leading edge becomes unreachable on the axis that overflows.
How: `justify-content: safe center`, the modifier riding the
justify-content value, the one alignment row the sources pin.
When: user generated or image sized content
that can outgrow its box, a modal body, a carousel slide. The rule
and the fallback are pinned to the mdn row in the sources appendix.

#diagram([which centering tool when: the ladder the model walks], length: 13pt, {
  // left column: the scenario gates in priority order, right column: the picks
  let gate(x, y, t) = {
    cdraw.rect((x, y), (x + 6.4, y + 1.0), fill: luma(235), stroke: luma(120), radius: 0.05)
    cdraw.content((x + 3.2, y + 0.5), [#t], size: 6pt)
  }
  let pick(x, y, t) = {
    cdraw.rect((x, y), (x + 6.0, y + 1.0), fill: luma(252), stroke: luma(150), radius: 0.05)
    cdraw.content((x + 3.0, y + 0.5), [#t], size: 6pt)
  }
  gate(0.5, 7.6, "more than one, parent free?")
  pick(8.4, 7.6, [place-content: center])
  gate(0.5, 6.0, "parent display frozen?")
  pick(8.4, 6.0, [absolute + translate])
  gate(0.5, 4.4, "only the child is yours?")
  pick(8.4, 4.4, [margin: auto])
  gate(0.5, 2.8, "otherwise")
  pick(8.4, 2.8, [flex, grid place-items])
  cdraw.line((6.9, 8.1), (8.3, 8.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.9, 6.5), (8.3, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.9, 4.9), (8.3, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.9, 3.3), (8.3, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.2, 6.2), [overflow risk rides any pick:], size: 6.5pt)
  cdraw.content((17.2, 5.3), [add safe, center falls], size: 6pt)
  cdraw.content((17.2, 4.5), [back to start when the item], size: 6pt)
  cdraw.content((17.2, 3.7), [outgrows the container], size: 6pt)
})

The step by step, said aloud for any centering question: count
the items, because more than one under a free parent display
means the track moves with `place-content` while a frozen one
means the group wraps in one element first, ask whether the
content can outgrow the box, because that adds the `safe`
modifier, ask whose declarations you own, because the parent
means flex or grid and the child means transform or auto margins,
then name the properties and stop.

== class versus arrow, map filter reduce, async await, es6 [EWC]

Class methods read `this` from the call site, arrow functions
close over the enclosing `this`, and the difference is observable
without a dom: a detached method call throws in strict mode, while
`bind` and arrow wrappers keep working:

#listing("interview-repertoire/samples/ch08-js/src/functions.mjs", first: 5, last: 40, caption: [the detached call throws, bind and the arrow survive])

#diagram([this binds at the call site or lexically, awaits sum or take the slowest], length: 13pt, {
  // left: what happens to this when the method detaches; right: two fetch orders
  cdraw.rect((0.5, 4.4), (5.5, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 4.9), [detached method], size: 6pt)
  cdraw.line((5.5, 4.9), (6.4, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.0, 4.9), [this lost, throws], size: 6pt)
  cdraw.rect((0.5, 2.4), (5.5, 3.4), fill: luma(235), radius: 0.02)
  cdraw.content((3.0, 2.9), [arrow or bind], size: 6pt)
  cdraw.line((5.5, 2.9), (6.4, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((10.0, 2.9), [this kept, works], size: 6pt)
  // right: three 30ms requests, sequential chains, parallel aligns
  cdraw.content((18.0, 6.5), [sequential awaits], size: 6.5pt)
  for i in range(3) {
    cdraw.rect((13.8 + i * 2.8, 5.3), (16.6 + i * 2.8, 5.85), fill: luma(215), radius: 0.0)
  }
  cdraw.content((19.8, 4.7), [30ms each, 90ms total], size: 6pt)
  cdraw.content((18.0, 3.6), [Promise.all], size: 6.5pt)
  for i in range(3) {
    cdraw.rect((13.8, 2.5 - i * 0.75), (16.6, 3.05 - i * 0.75), fill: luma(215), radius: 0.0)
  }
  cdraw.content((19.8, 0.9), [the slowest, 30ms], size: 6pt)
})

The same rule is why react class components needed `bind` in
constructors and function components do not, the bridge to
#xref-to("repertoire", "react-core"). The array and async half of
the question runs as a pipeline and two fetch orders:

#listing("interview-repertoire/samples/ch08-js/src/arrays-async.mjs", first: 5, last: 24, caption: [the filter map reduce pipeline, sequential awaits, Promise.all])

The comparison to narrate: sequential awaits preserve call order
at the cost of the sum of latencies, `Promise.all` preserves
result order at the cost of the slowest request. The es6 shapes,
destructuring, template literals, spread, computed keys, sit in
one small function the suite pins.

sources: verified by `npm run verify` under node 26.3.0, 16 tests
in `ch08-js`. The stylesheet is a real file, listed verbatim, not
executed by the suite. The safe alignment fallback is pinned to
the mdn justify-content row in the sources appendix.
