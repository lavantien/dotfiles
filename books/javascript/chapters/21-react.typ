#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= react 19: components as functions

Part three opens where part two closed, with a typed program that
runs, and asks the question the first twenty chapters deferred: what
happens when the target is a browser. The answer this chapter and the
next build on is react 19.3.0, measured on this machine, installed
into a fourth npm project, `javascript/fwsamples/`, beside the
samples, tssamples, and capstone projects. Nothing about the runtime
changes. React is a library the module system of chapter 7 imports
like any other, its components are functions part two could have
typed, and the one new tool in the layer, vite, enters exactly once
per build, never per run: `node --test` stays the only runner.

The project pins `react` and `react-dom` at 19.3.0 and `vite` at
8.3.0, probed 2026-09-21, with `@sveltejs/vite-plugin-svelte` 7.3.0
waiting for chapter 22. The verify chain adds a third stage between
compile and test: `tsc -p` typechecks the `.tsx` sources, the vite
builds produce the bundles the assertions read, then node runs the
unit tests against the emitted `dist` plus smoke tests that import
the built output. This chapter's slice is 31 unit tests and 6 smokes,
37 in all, green through `npm run verify`.

== a function that returns elements

A react component is a function from props to elements. That is the
whole definition, no decorator, no base class, no registration, and
the type layer of part two describes it with an ordinary interface:

#listing("javascript/fwsamples/ch21-react/components.tsx", first: 11, last: 52, caption: [one component per concern, props in, elements out, keys where lists render])

`Stat` takes two props and returns a tree. `DocTable` takes `docs`
and `children`, and `children` is not syntax, it is a prop the caller
fills by nesting. The `key` on each row is react's reconciliation
hint, stable identity across renders, and it never reaches the
dom. Below them the file keeps one class component on purpose:

#listing("javascript/fwsamples/ch21-react/components.tsx", first: 54, last: 76, caption: [the class form still runs in 19, kept here for contrast and for the boundary pattern later])

React 19 did not remove class components. It removed almost every
reason to write one, and the two survivors are visible in this
chapter: the demo above, and the error boundary of the sixth section,
which in 19.3.0 still has no function-component equivalent. The
suite renders the class's first paint through the server and moves
on, because everything else here is a function.

#diagram([props to elements, one direction], length: 13pt, {
  cdraw.content((1.4, 7.7), [props], size: 6.5pt, fill: luma(100))
  cdraw.content((1.4, 6.6), [`{ label, value }`], size: 6pt)
  cdraw.line((7.4, 6.9), (11.6, 6.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((9.5, 7.4), [function], size: 6pt)
  cdraw.content((15.8, 7.7), [elements], size: 6.5pt, fill: luma(100))
  cdraw.content((15.8, 6.6), [the return of `Stat`], size: 6pt)
  cdraw.line((11.6, 5.0), (11.6, 3.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 2.6), [the renderer turns elements into dom on the client, html on the server], size: 6pt)
  cdraw.content((11.6, 1.4), [the function never learns which], size: 6.5pt)
})

== hooks and their rules

State lives in hooks because a function component reruns whole. The
`useState` call returns a value from the run's own slot, and the
rules exist because the slots are positional, three of them, calls at
the top level, unconditional, same order every run. A custom hook is
only a function whose name starts with `use` and whose body follows
the rules, and it moves logic between components the way chapter 3
moved any other function:

#listing("javascript/fwsamples/ch21-react/hooks.tsx", first: 19, last: 42, caption: [the custom hook, state plus memoized derivation behind one call])

`filterDocs` stays a pure function outside the component so the suite
drives it without a renderer, and the hook composes it with `useState`
and `useMemo`. The panel renders its initial state through the server,
`value="systems"`, two of three documents, and the effect-shaped parts
of react are simply absent here: the server never runs effects, which
is why this chapter's oracle can say nothing about them and says so.

#flow(
  [the rules as one invariant],
  node((0, 0), [run 1, #linebreak() slot 0, 1, 2]),
  edge(),
  node((2.4, 0), [run 2, #linebreak() same slots]),
  edge(),
  node((4.8, 0), [rerender #linebreak() reads by position]),
)

Break the order, a conditional call between renders, and run 2 reads
slot 2 where run 1 left a different hook's state. The rule is not
etiquette, it is the addressing scheme.

== derive first, memo on evidence

Two tools that look interchangeable and are not. Derivation computes
from props during render, `const sorted = sortByPages(docs)`, and it
cannot go stale because it is recomputed every run. Memoization keeps
a cached copy keyed on dependencies and pays only when the same
component rerenders with unchanged inputs. The file counts the
factory runs so the claim is measured, not argued:

#listing("javascript/fwsamples/ch21-react/derived.tsx", first: 10, last: 46, caption: [the same derivation, plain and memoized, one shared counting factory])

Two `renderToString` calls run the factory twice in both columns, one
per render, because memo has no earlier run to reuse on a first
paint. The server oracle pins the floor: memo changes nothing until a
rerender happens, `React.memo` on a component is the same trade one
level up, skipping a subtree on shallow-equal props, and the honest
order of operations is derive, measure, then memo the leaf that
measured expensive.

#diagram([the decision, derive against memoize], length: 13pt, {
  cdraw.content((11.6, 8.6), [can it be computed from props and state?], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 5.6), (10.4, 7.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 6.5), [yes: derive inline], size: 6pt)
  cdraw.content((5.4, 5.1), [cannot go stale, #linebreak() costs one pass per render], size: 6pt)
  cdraw.line((10.8, 6.5), (13.2, 6.5), stroke: luma(100), label: [no, or measured slow])
  cdraw.rect((13.6, 5.6), (22.8, 7.4), fill: luma(205), radius: 0.02)
  cdraw.content((18.2, 6.5), [`useMemo` keyed on deps], size: 6pt)
  cdraw.content((18.2, 5.1), [pays only on a rerender #linebreak() with unchanged inputs], size: 6pt)
  cdraw.content((11.6, 3.2), [first render: both run the factory once, the suite counts it], size: 6.5pt)
  cdraw.content((11.6, 1.8), [memo is a rerender tool, never a first-paint tool], size: 6.5pt)
})

== what 19 changed

The 19 specifics were probed against the installed `@types/react`
19.3.0 before this section was written. `ref` arrives as an ordinary
prop, so the wrapper component `forwardRef` is no longer needed, it
still exists in 19.3.0, superseded rather than removed, and the
sample spells the new form directly:

#listing("javascript/fwsamples/ch21-react/react19.tsx", first: 18, last: 53, caption: [ref as a prop, use with a context, and use with a promise as the probe that fails])

`use()` stands in for `useContext` and reads either a context or
a promise. With a context it unwraps synchronously, provider or
default, both rendered by the suite. With a promise it is the honest
measured limit: under the synchronous `renderToString`, even an
already settled `Promise.resolve(42)` suspends and the render throws
`A component suspended`, because a plain promise carries no status
react can read and the sync renderer cannot wait. Promise reading
belongs to the streaming renderer or to react's own server
bookkeeping, and this book's oracle says so instead of demonstrating
a pattern it cannot run.

#diagram([the 19 surface, what replaced what], length: 13pt, {
  cdraw.content((6.0, 9.1), [before], size: 6.5pt, fill: luma(100))
  cdraw.content((17.2, 9.1), [react 19], size: 6.5pt, fill: luma(100))
  let row(y, old, now, dark) = {
    cdraw.rect((0.4, y), (22.8, y + 1.3), fill: if dark { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((6.0, y + 0.65), old, size: 6pt)
    cdraw.content((17.2, y + 0.65), now, size: 6pt)
  }
  row(7.2, [`forwardRef` wrappers], [`ref` as a prop], false)
  row(5.5, [`useContext`], [`use()`, context or promise], true)
  row(3.8, [manual pending flags], [`useActionState` forms], false)
  row(2.1, [manual optimistic copies], [`useOptimistic`], true)
  row(0.4, [class boundaries], [still classes, probed 19.3.0], false)
})

== forms as actions

A form action in 19 is a function, and the function receives the
form's own `FormData`, not synthetic arguments. `useActionState`
wires the transition to the submit, hands back state, a dispatch,
and a pending flag, and the transition function stays pure so the
suite drives it with a constructed `FormData` without a form
anywhere:

#listing("javascript/fwsamples/ch21-react/react19.tsx", first: 55, last: 86, caption: [the action reads its fields from FormData, the hook owns pending])

The server render of that form is a measured fact worth reading
closely, because it is react's own honesty about the seam: the action
attribute renders as a guard, `javascript:throw new Error('React
form unexpectedly submitted.')`, and a replay script follows the form
so a submit that races hydration is captured and replayed instead of
silently navigating. The suite asserts the guard string and the
marker comments react leaves between adjacent text nodes,
`2<!-- --> searches`, which exist so client hydration does not merge
text nodes the server laid out separately.

`useOptimistic` layers the same shape over a vote panel: the
optimistic reducer applies the vote immediately, the real action's
landed state replaces it when it settles, and the initial render
shows the passthrough state because there is nothing pending yet:

#listing("javascript/fwsamples/ch21-react/react19.tsx", first: 88, last: 123, caption: [the optimistic reducer pure and exported, the panel composing both hooks])

#flow(
  [one vote, two states],
  node((0, 0), [submit]),
  edge(),
  node((1.7, 0), [`apply(1)` #linebreak() shown now]),
  edge(),
  node((3.9, 0), [action runs]),
  edge(),
  node((5.9, 0), [landed state #linebreak() replaces shown]),
)

== boundaries catch, but not here

The error boundary is still a class component in 19.3.0,
`getDerivedStateFromError` to choose the fallback and
`componentDidCatch` to observe, and its honest limit is measured in
the suite rather than waved at: server rendering catches nothing.
`renderToString` over a boundary-wrapped throwing component lets the
throw escape to the caller, both boundary methods are client
lifecycle, so the server error path belongs to the surrounding
server, which is what the capstone's `server.mjs` will do with a
`try` around a render:

#listing("javascript/fwsamples/ch21-react/boundary.tsx", first: 7, last: 34, caption: [the boundary class, and the component that throws on purpose])

#diagram([where a throw is caught], length: 13pt, {
  cdraw.content((11.6, 8.6), [a component throws], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 5.0), (10.4, 7.0), fill: luma(235), radius: 0.02)
  cdraw.content((5.4, 6.5), [client render], size: 6pt)
  cdraw.content((5.4, 5.6), [boundary catches, #linebreak() fallback paints], size: 6pt)
  cdraw.rect((13.2, 5.0), (22.8, 7.0), fill: luma(205), radius: 0.02)
  cdraw.content((18.0, 6.5), [`renderToString`], size: 6pt)
  cdraw.content((18.0, 5.6), [escapes to the caller, #linebreak() suite asserts the throw], size: 6pt)
  cdraw.content((11.6, 3.4), [effects and event handlers are outside both boxes, the same rule as the class docs], size: 6pt)
  cdraw.content((11.6, 2.0), [the static method is pure and unit tested directly], size: 6pt)
})

== the island seam

The browser integration point this book commits to is not an
application, it is an island: a custom element whose lifecycle owns a
react root, `connectedCallback` mounts, `disconnectedCallback`
unmounts. The wrapper that implements it is deliberately framework
free, it knows the lifecycle mapping and nothing else, and the
browser globals plus the real `createRoot` are injected by the
caller, which is what lets the node suite drive the contract with
fakes:

#listing("javascript/fwsamples/ch21-react/wrap.ts", first: 22, last: 67, caption: [one root per connected host, weakly held, unmounted on disconnect])

The rules the wrapper keeps are the ones the fakes count: a root is
created once per connected host, a reconnect after an unmount mounts a
fresh root because the old one is dead, and disconnect unmounts
exactly once. The browser entry is three lines of injection:

#listing("javascript/fwsamples/ch21-react/island.tsx", first: 17, last: 22, caption: [the browser entry, globals and root handed to the framework-free wrapper])

#flow(
  [the island lifecycle],
  node((0, 0), [element #linebreak() connected]),
  edge(),
  node((2.2, 0), [`createRoot`]),
  edge(),
  node((4.2, 0), [render]),
  edge(),
  node((6.0, 0), [disconnected]),
  edge(),
  node((7.8, 0), [unmount]),
)

This file is browser only and the node suite never imports it. Vite
is the tool that turns it into something a script tag can load, and
that is the whole of vite's role in this book: `vite build` bundles
`island.tsx` with react inside it into one self-contained esm file,
861.84 kB minified, 218.69 kB gzip, measured 2026-09-21, machine
checked by a smoke that reads the bytes, asserts no import statement
survives, and leaves the number where the comparison with chapter 22
can find it.

== the server as oracle

Every render claim in this chapter was checked by
`react-dom/server`'s `renderToString` against code that exists in two
compiled forms: the tsc emit the unit tests import, and the vite
`--ssr` bundle the smokes import. The second form is the oracle that
matters, because it is the bundler's own output, dependencies
externalized exactly as a server would resolve them, and the smoke
renders the island component out of the built barrel:

#listing("javascript/fwsamples/ch21-react/render.smoke.mjs", first: 23, last: 29, caption: [the smoke, react-dom/server over the vite ssr bundle])

#flow(
  [the chapter verify chain],
  node((0, 0), [`.tsx` #linebreak() sources]),
  edge(),
  node((2.2, 0), [`tsc -p` #linebreak() typecheck, emit]),
  edge(),
  node((4.6, 0), [`vite build` #linebreak() island + ssr]),
  edge(),
  node((7.2, 0), [`node --test` #linebreak() unit + smokes]),
)

The one config file builds both ways, `vite build` for the browser
island and `vite build --ssr` for the oracle barrel, switching entry
and output directory on the build mode, and the emptyOutDir flag
stays off because all the chapter builds share one `dist` the verify
script clears once up front:

#listing("javascript/fwsamples/ch21-react/vite.config.ts", first: 7, last: 21, caption: [one config, two builds, the mode switch in three lines])

== the honest trade

React's account of a ui is a function rerunning whole, a tree diffed
against the previous run, and a runtime that owns scheduling,
reconciliation, and hydration. The costs and gains both follow from
that shape. The measured cost on this machine: an island whose
component is 29 lines ships 861.84 kB minified because the runtime
travels with it, and the gzip line, 218.69 kB, is the number a
network actually moves. The gains are equally concrete: the whole
program is ordinary typed javascript, any state shape renders, the
ecosystem is the largest of the three frameworks, and the model
survives contact with teams.

The next chapter compiles the same island shape with svelte 5 and
measures the same bundle, and the numbers will not be close. The
argument that keeps react honest here is not size, it is that the
book's own oracle, `renderToString`, the text markers, the form
guard, the suspended `use`, reads react's model back to the caller
with unusual candor, and a tool that tells you its seams is one you
can keep on the critical path.

sources: react.dev reference pages for components, hooks, `use`,
useActionState, useOptimistic, error boundaries, and custom elements,
react.dev blog react 19 release post, vite.dev guide and library
mode docs, accessed 2026-09-21. Verified live with react 19.3.0,
react-dom 19.3.0, vite 8.3.0, and tsc 7.0.2 on node 26.3.0,
windows, the chapter's 37 tests green through `npm run verify` in
`javascript/fwsamples`, bundle sizes read from the vite build output
2026-09-21.
