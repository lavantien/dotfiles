#import "../../theme/lib.typ": listing, snippet, callout, flow, diagram, cdraw
#import "@preview/fletcher:0.5.8": node, edge

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= templ: compiled html components

Chapter 16 built fragments with `strings.Builder` and hand escaped
strings, which is honest work and scales poorly. templ is the
compiled alternative: components are declared in a `.templ` file as
typed functions, a generator turns them into ordinary go source, and
the fragment a handler serves becomes a function call. The version is
v0.3.1020, pinned in both of this book's modules, and its generated
files are committed so the builds need no templ cli. This chapter's
samples live in `go/samples/ch17`, 10 tests, and the capstone that
follows builds its web ui on exactly what is taught here.

#flow(
  [the same fragment, two ways],
  node((0, 0), [handler]),
  edge("-|>"),
  node((1.5, 0.9), [builder + escape, ch16]),
  edge((1.5, 0.9), (3.0, 0), "-|>"),
  node((1.5, -0.9), [typed component, ch17]),
  edge((1.5, -0.9), (3.0, 0), "-|>"),
  node((3.0, 0), [html fragment]),
)

== the component is a function

A templ component looks like markup and is a function. The `templ`
keyword declares it, the parameters are typed go values, `{ name }`
interpolates, and calling `Hello("gabriel")` returns a
`templ.Component`, one method, render to a writer:

#listing("go/samples/ch17/components.templ", first: 3, last: 7, caption: [markup that is a typed function])

#listing("go/samples/ch17/serve_test.go", first: 24, last: 28, caption: [the exact bytes, asserted whole])

The output is deterministic and whitespace free because the
generator emits only the markup it was given, so the test can pin the
whole string rather than a substring. The render helper every later
section uses is four lines:

#listing("go/samples/ch17/serve.go", first: 20, last: 28, caption: [a component to a string, the swap shaped bridge])

#diagram([component as function: typed in, bytes out, no parse step], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [call it], [#"Hello(\"gabriel\")"])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [a component], [#"templ.Component"])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [render], [to any writer])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [the bytes], [exact, asserted])
  cdraw.content((11.8, 3.4), [the signature is checked where you typed it, not], size: 6pt)
  cdraw.content((11.8, 2.3), [at runtime against an any, and no template], size: 6pt)
  cdraw.content((11.8, 1.2), [text is ever parsed on the request path], size: 6pt)
})

== codegen, with the artifact committed

The `.templ` file is not read at runtime. `templ generate` compiles
it to `components_templ.go`, ordinary go that imports the templ
runtime, and this repo commits that artifact, so `make verify-go`
needs no templ cli installed: the module builds from source alone.
The directive documents regeneration, pinned to the same version as
the runtime dependency:

#listing("go/samples/ch17/serve.go", first: 6, last: 9, caption: [regeneration is one command, version pinned])

#listing("go/samples/ch17/components_templ.go", first: 34, last: 47, caption: [what the generator emitted for hello])

The emitted code is readable: a static write of the literal, a
`JoinStringErrs` for the interpolated value, `EscapeString` before it
touches the buffer, the error threaded through. Committed generated
code has precedent in chapter 1's `greeting_gen.go`, and the
`_templ.go` files are exempt from the repo's 400 line source ceiling
because their length is the generator's business, measured at 302
lines for 54 lines of source.

#diagram([the .templ file is a source language, the .go file is the artifact], length: 13pt, {
  pane(0.3, 11.3, 7.2, [the source], [#"components.templ,"], [54 lines, edited by hand])
  cdraw.line((11.6, 4.0), (12.4, 4.0), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((12.0, 5.0), [generate], size: 6pt)
  pane(12.7, 23.3, 7.2, [the artifact], [#"components_templ.go,"], [302 lines, committed])
  cdraw.content((11.8, 2.1), [the build never runs the generator, the repo runs], size: 6pt)
  cdraw.content((11.8, 1.0), [it when the source changes, and commits both], size: 6pt)
})

== composition and children

Components nest two ways: `@Hello(...)` places another component, and
a parameter of type `templ.Component` becomes a slot the caller fills
with content between the call's braces. `Card` is the small slot,
`Page` the document shell, and both are ordinary values, so the shell
of a page is built by function composition rather than a layout
inheritance scheme:

#listing("go/samples/ch17/components.templ", first: 9, last: 15, caption: [the slot: children arrive as a component, @ places it])

#listing("go/samples/ch17/components.templ", first: 17, last: 30, caption: [the shell, the same slot at document scale])

The composition test pins the whole tree in one string, doctype to
closing html, which is the property that matters: what nests is what
renders.

#diagram([composition is call structure: page around card around results], length: 13pt, {
  cdraw.rect((0.3, 4.2), (11.3, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.7), [page], size: 6.5pt)
  cdraw.content((5.8, 5.7), [doctype, head, body], size: 6pt)
  cdraw.content((5.8, 4.9), [the shell], size: 6pt)
  cdraw.line((5.8, 4.0), (5.8, 3.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((6.7, 3.6), [children], size: 6pt)
  cdraw.rect((0.3, 2.1), (11.3, 3.2), fill: luma(222), radius: 0.02)
  cdraw.content((5.8, 2.7), [card: section and h2], size: 6pt)
  cdraw.line((5.8, 1.9), (5.8, 1.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 0.1), (11.3, 1.1), fill: luma(205), radius: 0.02)
  cdraw.content((5.8, 0.6), [results: ul and li rows], size: 6pt)
  pane(12.7, 23.3, 7.2, [no inheritance], [no layout objects, no], [blocks, just calls], [with slot parameters])
  cdraw.content((18.0, 0.6), [the test pins the whole tree], size: 6pt)
})

== contextual escaping, honestly against html/template

Values are escaped by where they land. The same string in a text
context and an attribute context comes out differently escaped, url
attributes go through scheme sanitization, and the whole contract is
generated per expression rather than applied by a runtime escaper.
The standard library's `html/template` is also context aware, so the
honest comparison is side by side, same markup, same hostile value:

#listing("go/samples/ch17/components.templ", first: 32, last: 44, caption: [one value, three contexts: text, attribute, url])

#listing("go/samples/ch17/serve.go", first: 30, last: 35, caption: [the identical markup through html/template])

Both engines escape `<b>` to `&lt;b&gt;` in both contexts, and both
refuse an unsafe url scheme, templ answering
`about:invalid#TemplFailedSanitizationURL` where html/template
answers `#ZgotmplZ`. The difference is when the checking happens:
templ rejects a misspelled component or a wrong typed argument at
compile time and emits plain writes, html/template parses its text at
startup and resolves `{{.Name}}` through reflection on an `any`. The
security property is a tie, the type safety is not:

#listing("go/samples/ch17/serve_test.go", first: 67, last: 83, caption: [both sanitizations pinned, templ's and the stdlib's])

#diagram([same contract, different sentinels, different checking time], length: 13pt, {
  pane(0.3, 11.3, 7.3, [templ], [escapes at generation], [per context, per write], [checked at compile time])
  cdraw.content((11.8, 4.0), [versus], size: 6pt)
  pane(12.7, 23.3, 7.3, [html/template], [escapes at execution], [context walked at runtime], [dot is an any])
  cdraw.content((11.8, 2.1), [both refuse javascript: urls, templ with], size: 6pt)
  cdraw.content((11.8, 1.0), [about:invalid, the stdlib with \#ZgotmplZ], size: 6pt)
})

== rendering to strings for htmx swaps

Chapter 16's contract was never about strings.Builder, it was that a
handler answers html a swap can consume. A templ component renders to
exactly that, so the fragment route becomes one call, and the
component carries its own id the way the poll fragment there did:

#listing("go/samples/ch17/components.templ", first: 46, last: 54, caption: [the fragment as a component: own id, bare rows, a loop])

#listing("go/samples/ch17/serve.go", first: 62, last: 70, caption: [the fragment route: filter, render, answer])

#diagram([the swap consumes a component render, same bytes as ch16], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [the request], [#"GET results?q="])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [filter], [the corpus, fold])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [render], [results component])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [answer], [html, 200])
  cdraw.content((11.8, 3.4), [the test asserts the filter held and the rows], size: 6pt)
  cdraw.content((11.8, 2.3), [rendered, the same assertions ch16 made], size: 6pt)
  cdraw.content((11.8, 1.2), [over hand built fragments], size: 6pt)
})

== wiring into net/http

The mux is unchanged from the last chapter, method patterns and all,
because components only replace the inside of handlers. The page
route composes the whole tree in one expression, shell around card
around results, and the wrong verb still answers 405 from the mux
itself:

#listing("go/samples/ch17/serve.go", first: 49, last: 72, caption: [two routes, one composed page, one bare fragment])

#diagram([components inside handlers, the mux untouched], length: 13pt, {
  cdraw.rect((0.3, 4.6), (7.3, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 6.7), [the mux], size: 6.5pt)
  cdraw.content((3.8, 5.7), [method patterns], size: 6pt)
  cdraw.content((3.8, 4.9), [405 for free], size: 6pt)
  cdraw.line((7.5, 5.9), (8.5, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.7, 4.6), (15.9, 7.2), fill: luma(222), radius: 0.02)
  cdraw.content((12.3, 6.7), [the handler], size: 6.5pt)
  cdraw.content((12.3, 5.7), [composes, renders], size: 6pt)
  cdraw.content((12.3, 4.9), [answers html], size: 6pt)
  cdraw.line((16.1, 5.9), (17.1, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((17.3, 4.6), (23.3, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((20.3, 6.7), [the tests], size: 6.5pt)
  cdraw.content((20.3, 5.7), [httptest, exact], size: 6pt)
  cdraw.content((20.3, 4.9), [bytes pinned], size: 6pt)
  cdraw.content((11.8, 3.2), [a component stream can also be handed to the response], size: 6pt)
  cdraw.content((11.8, 2.1), [writer directly, zero copy, the render to string], size: 6pt)
  cdraw.content((11.8, 1.0), [form is kept because the tests read whole strings], size: 6pt)
})

== when not to

The standard library already serves html, and `html/template` in
particular is dependency free, parsed once, context aware. templ buys
typed parameters, compile time checking, and component composition,
and charges a dependency plus a generation step whose artifact must
be committed or installed on every machine. For one or two pages of
mostly static markup the stdlib wins and no generator is worth its
footprint. For a surface of many fragments, an htmx app especially,
where every route answers a component and the fragments nest, the
typing pays for itself, and the capstone's web ui is exactly that
shape. templ is also html only: json answers stay with the json
encoder, and the component file is the wrong place for anything that
is not markup.

#diagram([the decision: how much fragment surface, that is the whole question], length: 13pt, {
  cdraw.content((11.8, 7.6), [how many fragments will this server answer], size: 6.5pt)
  cdraw.line((11.8, 7.0), (11.8, 6.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 4.4), (10.3, 6.2), fill: luma(235), radius: 0.02)
  cdraw.content((5.3, 5.7), [one or two, mostly static], size: 6pt)
  cdraw.content((5.3, 4.9), [#"html/template", zero deps], size: 6pt)
  cdraw.rect((13.3, 4.4), (23.3, 6.2), fill: luma(205), radius: 0.02)
  cdraw.content((18.3, 5.7), [many, nested, htmx], size: 6pt)
  cdraw.content((18.3, 4.9), [templ, typed components], size: 6pt)
  cdraw.content((11.8, 3.2), [both contextually escape, both sanitize url], size: 6pt)
  cdraw.content((11.8, 2.1), [schemes, both testable through httptest, so], size: 6pt)
  cdraw.content((11.8, 1.0), [the choice is typing and workflow, not safety], size: 6pt)
})

sources: templ.guide for the language, component, and security
references of templ v0.3.1020, accessed 2026-09-21, and pkg.go.dev
for html/template and net/http. Verified by `go/samples/ch17` tests,
10 of them.
