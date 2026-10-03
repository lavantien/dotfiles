#import "../../theme/lib.typ": listing, snippet, callout, diagram, flow, cdraw
#import "@preview/fletcher:0.5.8": node, edge

= svelte 5: runes and compiled reactivity

React ships a runtime and reruns it on every change. Svelte 5.57.1,
the version this chapter measures, ships a compiler that reads the
same components and emits imperative updates, a write to `count`
becomes an assignment that touches exactly the dom nodes reading it,
and the reactive words that drive it are six runes, compiler
instructions that look like globals and compile away. The chapter
lives in the same `javascript/fwsamples/` project as chapter 21, one
`@sveltejs/vite-plugin-svelte` 7.3.0 config file per concern, and
the chapter's slice of the suite is 16 tests, 9 against compiled
reactivity imported by node and 7 against the built output.

The part one discipline holds: no framework magic the book cannot
open. The runes compile to signals, the suite drives the compiled
modules directly, the same `renderToString` style oracle runs
through `svelte/server`, and the island bundle is measured as bytes
beside react's.

== a compiler, not a runtime

The component is a script plus markup, no function returns a tree,
and the reactive declarations are instructions to the compiler:

#listing("javascript/fwsamples/ch22-svelte/QueryPanel.svelte", first: 12, last: 37, caption: [props through `$props`, state, two derivations, all compiler instructions])

Nothing here imports a reactivity library. `$props`, `$state`, and
`$derived` are recognized at compile time, and the emitted javascript
creates signals and wires them into the markup the compiler also
emits. The react chapter's component was a function the runtime calls
again on every change; this one is code that runs once and then
mutates. The honest shape of what `$state` becomes, from the actual
build output of this project, simplified:

#snippet(
  "// let count = $state(4), what the compiler emits\n"
  + "let count = $.source(4);\n"
  + "// and a write, count = 5\n"
  + "$.set(count, 5);\n"
  + "// a read inside the markup's reactive statement\n"
  + "$.get(count);\n",
  lang: "js",
)

#diagram([two models of the same change], length: 13pt, {
  cdraw.content((5.8, 8.8), [react, chapter 21], size: 6.5pt, fill: luma(100))
  cdraw.content((17.4, 8.8), [svelte, this chapter], size: 6.5pt, fill: luma(100))
  cdraw.content((5.8, 7.6), [state moves], size: 6pt)
  cdraw.content((5.8, 6.6), [rerun the function], size: 6pt)
  cdraw.content((5.8, 5.6), [diff the new tree], size: 6pt)
  cdraw.content((5.8, 4.6), [apply the delta], size: 6pt)
  cdraw.content((17.4, 7.6), [state moves], size: 6pt)
  cdraw.content((17.4, 6.6), [signal fires], size: 6pt)
  cdraw.content((17.4, 5.6), [assigned nodes update], size: 6pt)
  cdraw.content((17.4, 4.6), [no diff, no rerun], size: 6pt)
  cdraw.content((11.6, 3.0), [both batch writes in one synchronous block, both flush on their own schedule], size: 6.5pt)
  cdraw.content((11.6, 1.7), [the measured difference is bytes shipped and work done per change], size: 6.5pt)
})

== runes, outside any component

Svelte 5's runes are not component-only vocabulary. A `.svelte.js`
module compiles with the same reactivity, and because the compiled
output is plain esm over the signal runtime with no dom reference,
node imports it and the reactivity is live, which is how this book
tests reactivity without a browser:

#listing("javascript/fwsamples/ch22-svelte/counter.svelte.js", first: 8, last: 25, caption: [state, derivations, and an effect root, the whole reactive vocabulary in 18 lines])

Three rules the suite pins. `$derived` is synchronous, a write to
`count` updates `doubled` on the next line with no flush. `$effect`
is batched, it runs nothing until a flush, and two writes inside one
synchronous block produce one rerun, the same coalescing rule react
applies to events. And an effect outside a component needs an owner,
`$effect.root`, whose teardown is the factory's `dispose`, otherwise
the runtime answers with the `effect_orphan` error this chapter met
on its first run and kept as a finding.

One boundary fact earned the hard way: the bundle carries its own
copy of the svelte scheduler, so `flushSync` must come out of the
built barrel too, flushing through the outer `svelte` package is a
no-op on a second instance.

#flow(
  [one write, one flush],
  node((0, 0), [`count += 1`]),
  edge(),
  node((1.8, 0), [signal dirty]),
  edge(),
  node((3.7, 0), [flush]),
  edge(),
  node((5.4, 0), [`doubled`, effect, #linebreak() dom, once each]),
)

== stores against runes

Svelte 4 ran reactivity through stores, containers with `subscribe`
that components read with a `$` prefix. Svelte 5 keeps them working
and the file builds both answers to the same counter so the trade is
readable rather than asserted:

#listing("javascript/fwsamples/ch22-svelte/store.svelte.js", first: 1, last: 46, caption: [the store twin and the rune twin, one surface, two mechanisms])

The store notifies a subscriber list the runtime maintains, `get`
reads a current value, `derived` chains a second container off the
first. The rune twin has no list, the getters read signals, and the
suite drives both: the store's subscribers see `2, 3, 10` across a
set and an update, the rune twin's `doubled` follows `value` through
the same moves. The honest difference is machinery, not capability,
and the runes win on one axis that matters to this book, they are
the compiler's own path and stores are the compatibility layer.

#diagram([two notification paths], length: 13pt, {
  cdraw.content((5.8, 7.6), [store], size: 6.5pt, fill: luma(100))
  cdraw.content((5.8, 6.5), [`set(10)`], size: 6pt)
  cdraw.content((5.8, 5.5), [notify each subscriber], size: 6pt)
  cdraw.content((5.8, 4.5), [subscriber reruns], size: 6pt)
  cdraw.content((17.4, 7.6), [runes], size: 6.5pt, fill: luma(100))
  cdraw.content((17.4, 6.5), [`$.set(count, 10)`], size: 6pt)
  cdraw.content((17.4, 5.5), [dependents marked dirty], size: 6pt)
  cdraw.content((17.4, 4.5), [flush runs each once], size: 6pt)
  cdraw.content((11.6, 3.0), [stores stay for cross component state that predates runes], size: 6.5pt)
  cdraw.content((11.6, 1.8), [runes are the 5 default and this book's choice], size: 6.5pt)
})

== props, callbacks, and bindable

Component events are gone in svelte 5, and the replacement is the
simplest thing that could work: a prop holding a function. The panel
takes `onselect` and calls it, the parent passes it like any prop,
and there is no event system, no dispatch, no listener cleanup:

#listing("javascript/fwsamples/ch22-svelte/QueryPanel.svelte", first: 39, last: 63, caption: [the markup, an onclick row, the row call, children rendered])

`$bindable` is the two way door, the child declares it with a
default, the parent may `bind:` it, and writes through the local
alias flow back. The suite renders the default through the server,
`zoom` with `0`, before any binding exists:

#listing("javascript/fwsamples/ch22-svelte/Binding.svelte", first: 1, last: 22, caption: [a bindable prop with its default and one writer])

== snippets

Slots take one shape, the parent's markup dropped in one place.
Snippets are values: declared with `#snippet`, passed like any prop,
rendered with `@render`, parameterized, and usable more than once.
The host passes both a parameterized `row` snippet and a `children`
snippet to the same panel component from chapter 21's twin:

#listing("javascript/fwsamples/ch22-svelte/SnippetHost.svelte", first: 23, last: 33, caption: [two snippets passed as props, one parameterized])

The server render shows the composition working, `go` arrives
italicized from the parent's snippet, `picked: b1` from the children
snippet, and the panel's own derivation still runs between them.
Where react solved the same problem with the `children` prop and
render callbacks, snippets are the compiler's answer, they can be
passed around, kept in variables, and they carry their rendering
context with them.

#flow(
  [one component, two snippets],
  node((0, 0), [host]),
  edge(),
  node((2.0, 0), [panel]),
  edge(),
  node((4.2, 0), [`@render row(doc)`]),
  edge(),
  node((6.6, 0), [parent markup, #linebreak() child position]),
)

== the island seam

The same seam react used, a custom element, with none of the glue
code. `svelte:options customElement` tells the compiler to emit an
element class instead of a component, props become attributes and
properties, and the entry file is one registration line:

#listing("javascript/fwsamples/ch22-svelte/Island.svelte", first: 39, last: 43, caption: [one line of options and the compiler writes the element class])

#listing("javascript/fwsamples/ch22-svelte/main.ts", first: 1, last: 16, caption: [the entry, registration and the mount contrast in 16 lines])

The react chapter needed `wrap.ts`, a framework free lifecycle
mapper with injectable globals so node could test it. Svelte's
compiler writes that class, shadow dom or not as the options say,
and the honest comparison is not that react was wrong, it is that
react stops at `createRoot` and svelte's compiler knows the target.
The capstone will ship both islands over one engine and let the
reader open both files side by side.

== transitions

Transitions are the demo feature of every framework and svelte's are
css custom properties the runtime animates, `fade` and `fly` from
the standard library. The measured server fact is the honest one:
ssr renders the settled state, no intro classes anywhere in the
output, because an intro animation is a client behavior that starts
when the element mounts:

#listing("javascript/fwsamples/ch22-svelte/Transitions.svelte", first: 1, last: 30, caption: [fly on list rows, fade on the count line, both client only])

== the server as oracle

The same oracle as chapter 21, aimed at the svelte build.
`svelte/server`'s `render` turns a compiled component into a head
and body pair, the smokes import the vite `--ssr` output, and the
assertions read the html the way react's did:

#listing("javascript/fwsamples/ch22-svelte/render.smoke.mjs", first: 15, last: 26, caption: [the oracle smoke, svelte/server over the built components])

The output carries svelte's own hydration anchors, `<!--[-->` around
each block and key hints inside the keyed each, the twin of react's
`<!-- -->` text markers, and the suite asserts them rather than
stripping them, they are the contract the client bundle hydrates
against. The runes get the same treatment through a second config
file that builds the `.svelte.js` modules client side, because
server compiled runes are inert and the reactivity tests need live
signals:

#listing("javascript/fwsamples/ch22-svelte/runes.smoke.mjs", first: 16, last: 32, caption: [compiled reactivity driven in node, no browser anywhere])

#flow(
  [the chapter builds],
  node((0, 0), [`.svelte` #linebreak() components]),
  edge(),
  node((2.4, 0), [`vite build` #linebreak() island]),
  edge(),
  node((4.9, 0), [`--ssr` #linebreak() oracle]),
  edge(),
  node((7.2, 0), [runes config #linebreak() client signals]),
)

== when svelte beats react

The same island, the same three documents, the same filter input,
measured as bytes on this machine, 2026-09-21: the react island
bundle is 861.84 kB minified, 218.69 kB gzip. The svelte island
bundle is 57.79 kB minified, 18.09 kB gzip. A fifteenth of the
bytes, and the reason is the model, react ships a runtime that
diffs trees, svelte ships the compiler's output and a signal
runtime measured in kilobytes.

#diagram([the two island bundles, to scale in bytes], length: 13pt, {
  cdraw.content((11.6, 8.8), [minified bytes, measured 2026-09-21], size: 6.5pt, fill: luma(100))
  cdraw.rect((0.4, 6.6), (22.8, 7.9), fill: luma(205), radius: 0.02)
  cdraw.content((11.6, 7.25), [react island, 861.84 kB, gzip 218.69 kB], size: 6pt)
  cdraw.rect((0.4, 4.9), (1.6, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 5.55), [svelte island, 57.79 kB, gzip 18.09 kB], size: 6pt)
  cdraw.line((1.6, 5.55), (3.4, 5.55), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 3.6), [a fifteenth of the bytes for the same island], size: 6.5pt)
  cdraw.content((11.6, 2.4), [the smoke asserts the ordering, so drift fails the gate], size: 6.5pt)
  cdraw.content((11.6, 1.2), [ssr bundles land close, 6.74 kB react against 7.18 kB svelte, both externalized], size: 6pt)
})

Bytes are where svelte wins, and they are not the whole ledger. The
react chapter's honest trade holds here in reverse: the ecosystem,
the hiring pool, and the third party component surface all favor
react, svelte's compiler means the interactive words in your file
are not plain javascript, and the error messages come from the
compiler rather than a stack you can step through. This book's
capstone ships both islands anyway, one engine under two frameworks,
because the seam that made both possible, a custom element over a
built bundle, is the framework free part, and that part belongs to
the platform, not to either camp.

sources: svelte.dev docs on runes, snippets, stores, custom elements,
and transitions, svelte.dev blog svelte 5 announcement, npmjs.com
package pages for the pinned versions, vite.dev guide, accessed
2026-09-21. Verified live with svelte 5.57.1, the
vite-plugin-svelte 7.3.0 and vite 8.3.0 on
node 26.3.0, windows, the chapter's 16 tests green through
`npm run verify` in `javascript/fwsamples`, bundle sizes read from
the vite build output 2026-09-21.
