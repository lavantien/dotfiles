#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= react hooks and routing

"List the hooks and say what each is for" is a breadth check with
a depth trap attached, and 2019 through 2026 added a whole react 19
layer to it. The `ch12-react` workspace covers both under
`npm run verify`, with every claim rendered to markup through
`react-dom/server`.

== the built-in hooks that render server-side [EWC]

State, reducer, context, memoization, and identity, each in its
smallest honest form:

#listing("interview-repertoire/samples/ch12-react/src/hooks/hooks.js", first: 13, last: 63, caption: [useState seeding, useReducer transitions, context consumption, useMemo, useId])

#diagram([what each hook owns and what a static render can prove], length: 13pt, {
  // one row per hook: the own column and the prove column
  let row(y, hook, owns, proves) = {
    cdraw.rect((0.5, y), (4.1, y + 1.0), fill: luma(215), radius: 0.02)
    cdraw.content((2.3, y + 0.5), [#hook], size: 6pt)
    cdraw.rect((4.3, y), (11.0, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((7.85, y + 0.5), [#owns], size: 6pt)
    cdraw.rect((11.2, y), (23.0, y + 1.0), fill: luma(245), radius: 0.02)
    cdraw.content((17.1, y + 0.5), [#proves], size: 6pt)
  }
  row(5.4, "usestate", [one value], [the seed renders])
  row(4.2, "usereducer", [named transitions], [the initial state])
  row(3.0, "usecontext", [the ambient value], [the value renders])
  row(1.8, "usememo", [a computation], [the memo result])
  row(0.6, "useid", [a stable identity], [a generated id])
  cdraw.content((17.1, -0.5), [useeffect owns outside sync:], size: 6pt)
  cdraw.content((17.1, -1.6), [a static paint proves nothing], size: 6pt)
})

The narration map, one line each. `useState` for one value,
`useReducer` when transitions deserve names, `useContext` to skip
the drilling chain, `useMemo` to cache a computation between
renders, `useCallback` for a stable function identity, `useRef`
for a value the render must not see change, `useEffect` for
synchronization with the outside world. The honest framing for the
last one, from the react docs themselves: effects are an escape
hatch from react, not a lifecycle feature.

#callout("note", "what a server render can and cannot prove", [
  The suite pins what renders on first paint: seeded state,
  initial reducer state, context values, memo results, generated
  ids. What it cannot pin is updates after events, because
  `renderToStaticMarkup` never fires them. That is a real
  boundary, not a dodge: effects and updates belong to a browser
  runtime, and the from-scratch signal of
  #xref-to("repertoire", "js-fromscratch") demonstrates the same
  reactive core without one.
])

== a custom hook is just a function that calls hooks [EWC]

The useToggle demo owns a boolean and returns it with props for
the caller, reusable per component:

#listing("interview-repertoire/samples/ch12-react/src/hooks/hooks.js", first: 65, last: 79, caption: [useToggle: stateful behavior in a callable package])

#diagram([hook state lives in a position-indexed list, order is the address], length: 13pt, {
  // one component's slot list, useToggle's calls land at the next indexes
  cdraw.content((7.0, 5.4), [one component's hook list], size: 6.5pt)
  for i in range(4) {
    cdraw.rect((1.0 + i * 3.1, 3.6), (4.1 + i * 3.1, 4.8), fill: luma(235), radius: 0.02)
    cdraw.content((2.55 + i * 3.1, 4.2), [slot #i], size: 6pt)
  }
  cdraw.content((11.85, 2.9), [useToggle's state], size: 6pt)
  cdraw.line((11.85, 3.15), (11.85, 3.6), stroke: luma(160))
  cdraw.rect((14.0, 3.6), (21.0, 4.8), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((17.5, 4.2), [useToggle], size: 6.5pt)
  cdraw.line((14.0, 4.2), (13.45, 4.2), stroke: luma(100), mark: (end: ">"))
  cdraw.content((7.0, 1.9), [the rules exist because the position is the only address], size: 6.5pt)
})

The two rules to state unprompted: hooks call only from components
or other hooks, and they call unconditionally in the same order
every render. The rules exist because hook state lives in a
position-indexed list per component instance, which is also the
answer to "why can't I put it in an if".

== react-router, one route table [EWC]

Routes as data, `MemoryRouter` for anything but the browser,
nested paths and params:

#listing("interview-repertoire/samples/ch12-react/src/router/app.js", first: 6, last: 27, caption: [the route table and the in-memory root])

#diagram([routes as data under one in-memory root, any url mounted], length: 13pt, {
  // the table, the root, the seam, the two outcomes
  cdraw.rect((0.5, 2.4), (6.0, 5.6), fill: luma(235), stroke: luma(120), radius: 0.05)
  cdraw.content((3.25, 5.05), [the route table], size: 6.5pt)
  cdraw.content((3.25, 4.1), ["/"], size: 6pt)
  cdraw.content((3.25, 3.4), ["/listing"], size: 6pt)
  cdraw.content((3.25, 2.7), ["/item/:id"], size: 6pt)
  cdraw.line((6.0, 4.0), (7.7, 4.0), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.0, 3.4), (12.8, 4.6), fill: luma(245), stroke: luma(120), radius: 0.05)
  cdraw.content((10.4, 4.0), [the memory root], size: 6pt)
  cdraw.line((12.8, 4.3), (15.0, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((12.8, 3.7), (15.0, 3.1), stroke: luma(100), mark: (end: ">"))
  cdraw.content((13.9, 5.2), [matched], size: 6pt)
  cdraw.content((13.2, 2.4), [unmatched], size: 6pt)
  cdraw.rect((15.3, 4.4), (21.0, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((18.15, 4.9), [the element], size: 6pt)
  cdraw.rect((15.3, 2.6), (21.0, 3.6), fill: luma(245), radius: 0.02)
  cdraw.content((18.15, 3.1), [an empty render], size: 6pt)
  cdraw.content((12.0, 1.4), [the renderAt seam mounts any url, no browser history], size: 6pt)
})

The `renderAt` seam is the testable part worth narrating: the same
table mounted at any in-memory url, no browser history involved.
The suite asserts the root, the listing, a param route, and the
unknown-path empty render, which is what the router actually does
with an unmatched path.

== react 19: actions, use, and the compiler [EWC]

React 19, stable december 2024, made async transitions first
class. An action is any async function, and `useActionState` wraps
one with pending state and a returned form action:

#listing("interview-repertoire/samples/ch12-react/src/react19/actions.js", first: 14, last: 30, caption: [an action, and useActionState around it])

#diagram([react 19 made async first class, the compiler memoizes at build], length: 13pt, {
  // three pinned moments left to right
  cdraw.line((1.5, 3.2), (22.8, 3.2), stroke: luma(100), mark: (end: ">"))
  let tick(x, date, l1, l2) = {
    cdraw.circle((x, 3.2), radius: 0.09, fill: luma(100))
    cdraw.content((x, 3.85), date, size: 6.5pt)
    cdraw.content((x, 2.55), l1, size: 6pt)
    cdraw.content((x, 1.45), l2, size: 6pt)
  }
  tick(4.0, [dec 2024], [react 19 stable,], [actions first class])
  tick(11.0, [oct 2025], [the compiler 1.0,], [memoizes at build])
  tick(18.0, [into 2026], [use reads context], [after early returns])
  cdraw.content((12.0, 0.2), [signals stay a tc39 proposal, not a react primitive], size: 6.5pt)
})

`useOptimistic` renders a value that assumes success and reverts
on completion, `use` reads a promise or a context anywhere below a
provider, including after early returns, which `useContext`
forbids. The workspace renders the initial states of all of them,
and the `use(Context)` case runs for real:

#listing("interview-repertoire/samples/ch12-react/src/react19/actions.js", first: 47, last: 53, caption: [use reading context after an early return])

The compiler is its own fact, stable at 1.0 since october 2025:
it memoizes at build time so the manual `useMemo` and
`useCallback` call sites disappear from new code. The status of
signals belongs to the ecosystem, not to react: the tc39 proposal
sits at stage 1, with stage 2 blockers as the active work item,
and react's own answer to fine-grained reactivity remains the
compiler plus `use`, not a signal primitive. Both facts are pinned
in the sources appendix with their access dates.

sources: react 19 release post and the react compiler 1.0
announcement at react.dev, tc39 proposal-signals repository, the
release post and the tc39 repository accessed 2026-09-09, the
compiler announcement 2026-09-10. Verified by `npm run verify`
under node 26.3.0 with react 19.3 and react-router 7, 6 tests in
`src/hooks`, 4 in
`src/router`, 4 in `src/react19`.
