#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= react core: components, props, virtual dom

The react workspace, `ch12-react`, named for the hooks chapter and
shared by chapters 11 through 14, is a real react install,
react 19, react-dom 19, react-router 7, committed lockfile, driven
by `node --test` over `react-dom/server` rendering. That constraint
shapes what this chapter can honestly claim: everything here is
proven by rendered markup, the same guarantee a server render
gives, and the effects-and-browser half of react floors to the
hooks chapter that follows.

== function components versus class components [EWC]

A function component is a function from props to elements. A class
component is a class with a render method and instance state. The
workspace renders both to identical markup:

#listing("interview-repertoire/samples/ch12-react/src/core/components.js", first: 7, last: 22, caption: [the same output from a function and from a class])

#diagram([both are props to elements, hooks moved the state into functions], length: 13pt, {
  // two spellings on top, one markup result below
  cdraw.rect((0.5, 4.6), (7.5, 6.6), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((4.0, 6.1), [the class form], size: 6pt)
  cdraw.content((4.0, 5.0), [render, this.state], size: 6pt)
  cdraw.rect((12.5, 4.6), (19.5, 6.6), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((16.0, 6.1), [the function form], size: 6pt)
  cdraw.content((16.0, 5.0), [hooks hold the state], size: 6pt)
  cdraw.line((4.0, 4.6), (4.0, 3.9), (8.6, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.0, 4.6), (16.0, 3.9), (11.4, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.6, 1.5), (13.4, 2.7), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((10.0, 2.1), [the same markup], size: 6pt)
  cdraw.content((10.0, 0.4), [since 16.8 the function form owns the state story], size: 6.5pt)
})

The spoken history that scores: class components carried the state
and lifecycle story before hooks existed, function components plus
hooks took it over in 16.8, and new react code is function-only
because the class form buys nothing, not even `this` safety, as
#xref-to("repertoire", "js-dom") showed with the detached-method
throw. Say the one thing classes still own in old codebases,
`componentDidCatch` error boundaries, and concede it.

== props, children, and drilling [EWC]

Props flow down, `children` is a prop like any other, and the
composition demo renders both:

#listing("interview-repertoire/samples/ch12-react/src/core/components.js", first: 24, last: 44, caption: [children through composition, and the drilling chain])

#diagram([drilling repeats the downward flow until a leaf uses what the root had], length: 13pt, {
  // three levels, the middle one passes without reading, the shortcut on the left
  let box(y, t) = {
    cdraw.rect((9.0, y), (15.0, y + 1.0), fill: luma(235), stroke: luma(120), radius: 0.05)
    cdraw.content((12.0, y + 0.5), [#t], size: 6pt)
  }
  box(5.6, "theme, the root")
  box(3.4, "page")
  box(1.2, "button, the leaf")
  cdraw.line((12.0, 5.6), (12.0, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.0, 3.4), (12.0, 2.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((16.3, 5.0), [tone + label], size: 6pt)
  cdraw.content((16.3, 3.9), [passed down], size: 6pt)
  cdraw.content((16.3, 2.8), [never read], size: 6pt)
  // the shortcut that ends the drilling
  cdraw.line((9.0, 6.1), (6.2, 6.1), (6.2, 1.7), (9.0, 1.7), stroke: (paint: luma(100), dash: "dashed"), mark: (end: ">"))
  cdraw.content((4.3, 4.5), [context or], size: 6pt)
  cdraw.content((4.3, 3.4), [composition], size: 6pt)
})

Prop drilling is the same downward flow repeated until a leaf uses
something only the root had. The `Theme` to `Button` chain passes
`tone` and `label` through a `Page` that never reads them, and the
test asserts the exact markup drilling produces. The fixes are the
context of #xref-to("repertoire", "react-hooks") when the value is
ambient, or component composition when the problem is a parent in
the way.

== the virtual dom [EWC]

Elements are plain objects, not markup. Type, props, children,
and that is the whole premise:

#listing("interview-repertoire/samples/ch12-react/src/core/components.js", first: 47, last: 52, caption: [an element is data])

#diagram([elements are data, the diff emits ops, the host applies them], length: 13pt, {
  // two trees in, one op list out, the host mutates
  cdraw.rect((0.5, 3.3), (4.6, 4.5), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((2.55, 3.9), [new tree], size: 6pt)
  cdraw.rect((0.5, 1.5), (4.6, 2.7), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((2.55, 2.1), [old tree], size: 6pt)
  cdraw.line((4.6, 3.9), (5.9, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((4.6, 2.1), (5.9, 2.7), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((6.2, 2.4), (9.7, 3.6), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((7.95, 3.0), [diff], size: 6.5pt)
  cdraw.line((9.7, 3.0), (10.7, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((11.0, 1.2), (17.4, 4.6), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((14.2, 3.95), [the ops], size: 6.5pt)
  cdraw.content((14.2, 2.85), [setText, setProp], size: 6pt)
  cdraw.content((14.2, 1.75), [insert, remove, reorder], size: 6pt)
  cdraw.line((17.4, 3.0), (17.75, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((17.8, 2.4), (23.6, 3.6), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((20.7, 3.0), [the host applies], size: 6pt)
  cdraw.content((12.0, 0.4), [keys turn rewrites into moves], size: 6.5pt)
})

The interview version in one breath: components return element
trees, react diffs the new tree against the old one, and applies
the minimal set of dom mutations the diff implies, so the developer
describes the whole interface and the library pays for only what
changed. The from-scratch implementation of that diff, with keyed
reordering and patch ops a host applies, is the second half of
#xref-to("repertoire", "react-build"), built in plain js with
tests that count nodes.

sources: verified by `npm run verify` under node 26.3.0 with react
19.3, 5 tests in the `src/core` suite of `ch12-react`. React 19
release facts are pinned in the sources appendix from the react
blog, accessed 2026-09-09.
