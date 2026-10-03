#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= the rendering pipeline and accessibility

Chapter 8 built the dom as a tree, chapter 32 built the
stylesheets as models, and this chapter walks what the browser
does with both: two trees parsed, intersected into a render
tree, laid out, painted, composited, and beside the pixels a
second published tree, the accessibility tree, derived from the
dom for assistive technology. The `ch33-js` workspace classifies
a change by the stages it invalidates, reduces the dom to the
accessibility tree, and computes the WCAG contrast ratios, 10
tests under `node --test`, zero dependencies.

== parse to dom and cssom [EWC]

Html parsing builds the dom, one node per tag, the same tree
#xref-to("repertoire", "js-dom") builds and walks. Css parsing
builds the cssom, and it is a tree for the same reason the dom
is: rules nest, and inheritance flows down it, a resolved
font-size on the body is the inherited starting point of every
descendant, and every value in it has already survived the
cascade #xref-to("repertoire", "css-answers") sorts. The two
trees never merge. What merges is their intersection, the render
tree of the next section, and everything downstream of parsing
consumes that intersection. The browser derives one more tree
from the dom alone, the accessibility tree of the fourth
section, which css touches only through the hiding properties,
display none and visibility, never through the cascade.

== layout, paint, composite [DRILL]

Layout, called reflow when it reruns, walks the render tree and
gives every node a box, position and size, geometry. Paint walks
the boxes and emits paint lists, the order to fill, stroke, and
place text in. Compositing hands layers to the gpu and combines
them, the stage where transform and opacity do their work
without touching the two above it. Each stage consumes the
previous one's output, which is why the cost of a change is the
earliest stage it invalidates plus everything downstream, the
question the classifier in the next section answers.

#diagram([two trees in, a render tree out, then the three stages, each producing its own artifact], length: 13pt, {
  // left: the two parsed trees; right: the render tree and the three stages under it
  cdraw.rect((0.6, 9.4), (5.4, 10.6), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((3.0, 10.2), [dom], size: 6.5pt)
  cdraw.content((3.0, 9.75), [html parsed], size: 6pt)
  cdraw.rect((0.6, 7.9), (5.4, 9.1), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((3.0, 8.7), [cssom], size: 6.5pt)
  cdraw.content((3.0, 8.25), [css parsed, cascaded], size: 6pt)
  cdraw.line((5.4, 10.0), (12.6, 9.7), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.4, 8.5), (12.6, 9.0), stroke: luma(100), mark: (end: ">"))
  let stage(y, name, sub) = {
    cdraw.rect((12.6, y), (22.4, y + 1.4), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((17.5, y + 0.98), name, size: 6.5pt)
    cdraw.content((17.5, y + 0.4), sub, size: 6pt)
  }
  stage(8.6, [render tree], [dom intersect cssom, minus display none])
  stage(6.6, [layout (reflow)], [each node gets a box: position and size])
  stage(4.6, [paint], [paint lists: what to draw, in what order])
  stage(2.6, [composite], [layers to the gpu, transform and opacity land here])
  for y in (8.6, 6.6, 4.6) {
    cdraw.line((17.5, y), (17.5, y - 0.6), stroke: luma(100), mark: (end: ">"))
  }
  cdraw.content((11.5, 1.2), [nothing renders that never joined the render tree], size: 6pt)
})

A visibility hidden node joins the render tree, laid out and
painted as transparent. A display none node never joins it, no
box, no paint, and no accessibility entry, the property the
fourth section inherits.

== reflow versus repaint versus compositing [TDD]

The classifier is a table walked by a function, the change names
its class and the class names its stages:

#listing("interview-repertoire/samples/ch33-js/src/pipeline.mjs", first: 6, last: 29, caption: [stage classification, and a class change paid by the union of its delta])

A class change is answered by its delta: diff the declared
properties of the two classes and pay the union of what differs,
a swap that only moves color repaints, one that moves width
relayouts. The honest framing to volunteer before anyone asks:
this is the spec-level truth, what each property invalidates by
definition. Browsers optimize underneath it, a width change that
lands on an unchanged subtree may relayout nothing it does not
touch, and a transform-only animation never enters layout at
all. The classifier is the guarantee, the optimizations are why
unmeasured intuitions surprise you.

#diagram([the trigger table: one row per change class, a filled cell per stage it pays], length: 13pt, {
  // columns are the stages, rows are the change classes, cells filled when paid
  cdraw.content((8.6, 9.0), [layout], size: 6.5pt)
  cdraw.content((14.2, 9.0), [paint], size: 6.5pt)
  cdraw.content((19.8, 9.0), [composite], size: 6.5pt)
  let cell(cx, y, paid) = {
    cdraw.rect((cx - 2.3, y), (cx + 2.3, y + 1.0), fill: if paid { luma(190) } else { luma(248) }, stroke: luma(120), radius: 0.0)
  }
  let row(y, label, paid) = {
    cdraw.content((3.4, y + 0.5), label, size: 6pt)
    cell(8.6, y, paid.at(0))
    cell(14.2, y, paid.at(1))
    cell(19.8, y, paid.at(2))
  }
  row(7.5, [width, height, top], (true, true, true))
  row(6.1, [a text content change], (true, true, true))
  row(4.7, [color, background], (false, true, true))
  row(3.3, [transform, opacity], (false, false, true))
  cdraw.content((3.4, 2.4), [a class change], size: 6pt)
  cdraw.content((14.2, 2.4), [the union of whatever its delta declares], size: 6pt)
  cdraw.content((11.5, 1.2), [spec-level truth: browsers skip what they can, the classifier models the guarantee], size: 6pt)
})

== the accessibility tree and semantic html [TDD]

The accessibility tree is the dom as assistive technology
receives it, derived, never authored: roles come from tags,
names from text and attributes, structure from nesting. The
reducer is honest about its one hard rule, display none, spelled
by the hidden attribute in this model, and aria-hidden prune a
node together with its whole subtree:

#listing("interview-repertoire/samples/ch33-js/src/a11y.mjs", first: 16, last: 52, caption: [pruning, implicit roles, naming, and the reduction itself])

#listing("interview-repertoire/samples/ch33-js/src/a11y.mjs", first: 54, last: 78, caption: [the tab-order walk, positives first, tabindex -1 dropped])

#diagram([the nav subtree before and after the reduction: hidden prunes, roles and names survive], length: 13pt, {
  // left: the dom subtree, hidden and aria-hidden dashed; right: the exposed tree
  cdraw.content((5.6, 10.5), [the dom], size: 6.5pt)
  cdraw.rect((3.8, 8.9), (7.4, 9.9), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.6, 9.4), [nav], size: 6pt)
  cdraw.rect((0.8, 6.9), (3.6, 7.9), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((2.2, 7.4), [button open], size: 6pt)
  cdraw.rect((4.2, 6.9), (7.0, 7.9), fill: luma(248), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((5.6, 7.4), [button hidden], size: 6pt)
  cdraw.rect((7.6, 6.9), (10.4, 7.9), fill: luma(248), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((9.0, 7.4), [aria-hidden], size: 6pt)
  cdraw.rect((7.6, 5.1), (10.4, 6.1), fill: luma(248), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((9.0, 5.6), [button ghost], size: 6pt)
  cdraw.line((4.8, 8.9), (2.2, 7.9))
  cdraw.line((5.6, 8.9), (5.6, 7.9))
  cdraw.line((6.4, 8.9), (9.0, 7.9))
  cdraw.line((9.0, 6.9), (9.0, 6.1))
  cdraw.line((10.6, 8.1), (12.4, 8.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((17.5, 10.5), [the accessibility tree], size: 6.5pt)
  cdraw.rect((15.3, 8.9), (19.7, 9.9), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((17.5, 9.62), [navigation], size: 6pt)
  cdraw.content((17.5, 9.18), [categories], size: 6pt)
  cdraw.rect((15.3, 6.9), (19.7, 7.9), fill: luma(225), stroke: luma(120), radius: 0.02)
  cdraw.content((17.5, 7.62), [button], size: 6pt)
  cdraw.content((17.5, 7.18), [open], size: 6pt)
  cdraw.line((17.5, 8.9), (17.5, 7.9))
  cdraw.content((11.5, 3.9), [the pruned nodes are gone with their subtrees, not grayed], size: 6pt)
  cdraw.content((11.5, 2.9), [the survivors carry derived roles and names, no author annotation], size: 6pt)
})

Semantic html is the answer to "how do you make it accessible":
the native tags already carry the roles, the h1 through h6
outline, the landmarks nav and main, and a button that is
focusable and announceable with no attributes at all. The trap
the model pins: an anchor is only a link while it carries an
href, a bare anchor degrades to a generic node, no role, no
focus, because the role is conditional on the attribute.

== aria, contrast, and keyboard paths [TDD]

Contrast is arithmetic, and the arithmetic is the WCAG 2.2
definition: relative luminance linearizes each srgb channel and
combines them with the rec 709 weights, the ratio is the lighter
luminance plus 0.05 over the darker plus 0.05, and the
thresholds are 4.5:1 for body text, 3:1 for large text and for
non-text ui components, criteria 1.4.3 and 1.4.11:

#listing("interview-repertoire/samples/ch33-js/src/contrast.mjs", first: 6, last: 29, caption: [luminance, the ratio, and the three thresholds])

The known numbers the tests pin: black on white is exactly 21:1
either direction, \#767676 on white is 4.54:1, the lightest gray
that still passes body text, and \#888888 is 3.55:1, enough for
large text and ui edges, not enough for a paragraph. The tab
walk beside it: naturally focusable elements and tabindex 0
follow document order, positive tabindex jumps the queue in
numeric order, tabindex -1 leaves the walk while staying
programmatically focusable. The first rule of aria, prefer the
native element: a button is a state machine someone else
maintains, a div with role button is one you maintain, and the
role attribute carries none of the keyboard behavior for free.

#diagram([the contrast ladder against its two thresholds, and the keyboard path the tab walk takes], length: 13pt, {
  // left: three ratios as bars, dashed thresholds at 3:1 and 4.5:1; right: the tab path
  cdraw.content((5.8, 10.5), [contrast], size: 6.5pt)
  cdraw.rect((0.6, 8.7), (10.7, 9.3), fill: luma(200), stroke: luma(120), radius: 0.0)
  cdraw.content((5.4, 9.0), [21: black on white], size: 6pt)
  cdraw.rect((0.6, 7.5), (2.78, 8.1), fill: luma(225), stroke: luma(120), radius: 0.0)
  cdraw.content((6.4, 7.8), [4.54: lightest gray that passes text], size: 6pt)
  cdraw.rect((0.6, 6.3), (2.3, 6.9), fill: luma(235), stroke: luma(120), radius: 0.0)
  cdraw.content((6.2, 6.6), [3.55: large text and ui only], size: 6pt)
  cdraw.line((2.04, 5.9), (2.04, 9.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.line((2.76, 5.9), (2.76, 9.6), stroke: (paint: luma(150), dash: "dashed"))
  cdraw.content((1.5, 5.4), [3:1], size: 6pt)
  cdraw.content((3.2, 5.4), [4.5:1], size: 6pt)
  cdraw.content((17.5, 10.5), [the tab path], size: 6.5pt)
  let key(x0, x1, t, sub) = {
    cdraw.rect((x0, 8.5), (x1, 9.7), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 9.22), t, size: 6pt)
    cdraw.content(((x0 + x1) / 2, 8.78), sub, size: 6pt)
  }
  key(12.0, 14.6, [skiplink 1], [tabindex 1])
  key(15.0, 17.6, [skiplink 2], [tabindex 2])
  key(18.0, 20.2, [first], [tab 0])
  key(20.6, 22.8, [second], [tab 0])
  cdraw.line((14.6, 9.1), (15.0, 9.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.6, 9.1), (18.0, 9.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((20.2, 9.1), (20.6, 9.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((18.0, 6.6), (20.2, 7.6), fill: luma(248), stroke: (paint: luma(100), dash: "dashed"), radius: 0.02)
  cdraw.content((19.1, 7.1), [tabindex -1], size: 6pt)
  cdraw.content((17.5, 5.6), [positives jump the queue, then document order resumes], size: 6pt)
  cdraw.content((17.5, 4.6), [positive tabindex is the anti-pattern: it scrambles the page's own order], size: 6pt)
  cdraw.content((11.5, 3.4), [a ratio is one division, a keyboard path is a promise about order], size: 6pt)
})

== the spoken rendering answers [DRILL]

What forces reflow: writing geometry then reading it. A style
write marks layout dirty, the next `offsetHeight` or
`getBoundingClientRect` read forces the relayout synchronously,
and interleaving writes and reads inside a loop pays a full
layout per iteration, the layout thrash. The fix is batching,
every write, then every read.

Why animations jank: an animation that animates width pays
layout on every frame, one that animates transform and opacity
pays compositing only, the gpu lane, and the frame budget is
roughly 16ms at 60hz. The spoken rule: animate transform and
opacity, keep width and top out of the hot path, and measure
when a transform-only animation still stutters, because the
compositor has its own ceiling.

How the virtual dom helps, floored to
#xref-to("repertoire", "react-core"): the diff batches
declarative changes into one mutation pass, so a component
updating ten nodes pays one layout for the batch instead of ten
interleaved ones, and reconciliation is the pipeline's biggest
customer, the reason a framework's update model is a rendering
answer, not only a state one.

What the accessibility tree is: the dom rewritten as roles,
names, and structure, pruned by display none and aria-hidden,
published to assistive technology, and the reason semantic tags
are the cheapest accessibility there is, they populate the tree
with no author effort at all.

Semantic landmarks and heading order: nav, main, header,
footer, aside name the regions a screen reader jumps between,
and h1 through h6 outline the page one level at a time, a path
the reader walks, which is why skipping from h2 to h5 is an
audit finding even when the type size looks right.

floored to the corpus: the dom tree itself and the tree walk
idiom are #xref-to("repertoire", "js-dom"), the scheduling that
decides when any of this runs is the event loop of
#xref-to("repertoire", "js-core"), the server-side contrast to
one process juggling many connections is epoll in
#xref-to("repertoire", "systems-answers"), and the batching
consumer is the virtual dom of
#xref-to("repertoire", "react-core"). The contrast thresholds
are WCAG 2.2's own rows, 1.4.3 and 1.4.11, w3.org/TR/WCAG22,
accessed 2026-09-29. Verified by `npm run verify` under node
26.3.0, 10 tests in `ch33-js`, zero dependencies.
