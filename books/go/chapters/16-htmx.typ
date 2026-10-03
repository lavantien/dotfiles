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

= htmx 4: html over the wire

The last two chapters leave a gap: go serves html beautifully and
tests it over httptest, but the browser side of interactivity is
still hand written javascript. htmx closes that gap from the html
side. Ordinary elements gain attributes that issue ajax requests,
the server answers with html fragments, and the response lands in
the page without a line of client render code. This chapter builds
one fragment server, `go/samples/ch16`, 12 tests, every path driven
through httptest, zero browser. htmx 4.0.0 is the version taught,
vendored into the package because npm's `latest` tag still points at
2.0.10 while the 4.x documentation lives at four.htmx.org, and the
vendored file is pinned by a digest the test recomputes.

#flow(
  [two ways to update a page],
  node((0, 0), [json api]),
  edge("-|>"),
  node((1.4, 0), [data]),
  edge("-|>"),
  node((2.8, 0), [client render code]),
  edge((2.8, 0), (2.8, -1.2), "-|>"),
  node((2.8, -1.2), [dom updates]),
  node((0, -2.6), [fragment server]),
  edge((0, -2.6), (1.4, -2.6), "-|>"),
  node((1.4, -2.6), [html fragment]),
  edge((1.4, -2.6), (2.8, -2.6), "-|>"),
  node((2.8, -2.6), [swapped in place]),
)

== fragments, not json

A json api and a client render layer move two jobs into the browser:
fetching data and turning data into dom. htmx keeps both on the
server. The element says where a request goes and where its answer
lands, the handler answers html, and the same handler often serves
both faces of one url, the full document for a normal navigation and
the bare fragment when htmx asks. The `HX-Request` header is how the
server tells the two apart, and `Vary` keeps a cache from serving one
face for the other:

#listing("go/samples/ch16/htmx.go", first: 89, last: 101, caption: [one route, two faces, the vary header keeping them apart])

#diagram([the same bytes asked two ways, distinguished by one request header], length: 13pt, {
  cdraw.rect((0.3, 4.6), (7.3, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((3.8, 6.7), [plain navigation], size: 6.5pt)
  cdraw.content((3.8, 5.7), [no special header], size: 6pt)
  cdraw.content((3.8, 4.9), [#"the whole document"], size: 6pt)
  cdraw.line((7.5, 5.9), (8.5, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.7, 4.6), (15.7, 7.2), fill: luma(222), radius: 0.02)
  cdraw.content((12.2, 6.7), [#"page handler"], size: 6.5pt)
  cdraw.content((12.2, 5.7), [branches on the header], size: 6pt)
  cdraw.content((12.2, 4.9), [and adds Vary], size: 6pt)
  cdraw.line((15.9, 5.9), (16.9, 5.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((17.1, 4.6), (23.3, 7.2), fill: luma(205), radius: 0.02)
  cdraw.content((20.2, 6.7), [hx request], size: 6.5pt)
  cdraw.content((20.2, 5.7), [#"HX-Request: true"], size: 6pt)
  cdraw.content((20.2, 4.9), [the bare fragment], size: 6pt)
  cdraw.content((11.8, 3.2), [the test drives both faces and asserts the Vary], size: 6pt)
  cdraw.content((11.8, 2.1), [header on both, because a cached fragment served], size: 6pt)
  cdraw.content((11.8, 1.0), [to a plain navigation is the classic bug], size: 6pt)
})

The fragment face is ordinary html, escaped exactly like a full page,
so the same rendering discipline covers both.

== what changed in 4.0

Version 4 keeps the idea and rewires the middle. Five changes matter
to a go author, each from the migration notes at four.htmx.org,
accessed 2026-09-21. The core now rides the fetch api, and the new
`hx-config` attribute maps fetch options per element, `timeout`,
`credentials`, `cache`, `redirect`, `integrity`, with one deliberate
omission: `mode` is always reset to `htmx.config.mode`, `same-origin`
by default, so injected markup cannot widen a request's scope.
Attribute inheritance flipped from implicit to explicit, a child now
opts in with `hx-target:inherited` and combines with `:append`,
restorable to 2.x behavior through `htmx.config.implicitInheritance`.
Error responses are swapped by default, where 2.x dropped 400 and 500
bodies, revertible with `htmx.config.noSwap` or per element
`hx-status`. Event names were standardized and rationalized, with the
`htmx-2-compat` extension bridging old names. And history no longer
snapshots the dom into session storage, it re-issues a request to the
server, which is why fragment routes should stay answerable forever.

#snippet(
  "<div hx-config='\"timeout\": 4000, \"redirect\": \"error\"'\n"
  + "     hx-get=\"/fragment/notes\">list</div>\n"
  + "<!-- mode is never honored here: same-origin is pinned -->\n",
  lang: "html",
)

#diagram([2.x habits against 4.0 defaults, five rows from the migration notes], length: 13pt, {
  let row(y, topic, left, right) = {
    cdraw.line((0.3, y - 0.45), (23.3, y - 0.45), stroke: luma(220))
    cdraw.content((2.6, y), [#topic], size: 6pt)
    cdraw.content((9.2, y), [#left], size: 6pt)
    cdraw.content((17.4, y), [#right], size: 6pt)
  }
  cdraw.content((2.6, 7.6), [what], size: 6.5pt)
  cdraw.content((9.2, 7.6), [2.x], size: 6.5pt)
  cdraw.content((17.4, 7.6), [4.0], size: 6.5pt)
  row(6.6, [transport], [xmlhttprequest], [fetch, hx-config options])
  row(5.6, [inheritance], [implicit], [explicit, opt in per attribute])
  row(4.6, [400 and 500], [not swapped], [swapped by default])
  row(3.6, [event names], [accumulated], [standardized, compat ext])
  row(2.6, [history], [dom snapshot cache], [a fresh server request])
  cdraw.content((11.8, 1.2), [also new: built in innerMorph and outerMorph swaps], size: 6pt)
  cdraw.content((11.8, 0.1), [all five rows cited to four.htmx.org migration], size: 6pt)
})

== the core attributes

Five attributes carry the whole library. `hx-get` and `hx-post`
issue the request, `hx-target` picks the css selector the answer
lands in, `hx-swap` picks how it lands, and `hx-trigger` picks what
fires it. The demo's mux routes them with go 1.22 method patterns, so
a wrong verb is a 405 from the mux, never from handler code:

#listing("go/samples/ch16/htmx.go", first: 66, last: 87, caption: [the demo's whole route table, method patterns on every entry])

The served page carries each attribute on a real element, and one
test walks the whole catalog against the served bytes:

#snippet(
  "<input type=\"search\" name=\"q\"\n"
  + "  hx-get=\"/fragment/search\" hx-trigger=\"keyup changed delay:500ms\"\n"
  + "  hx-target=\"#results\" hx-swap=\"innerHTML\">\n",
  lang: "html",
)

#diagram([five attributes, five decisions, one request cycle], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 4.4, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.2, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.2, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [#"hx-get, hx-post"], [the request])
  cdraw.line((4.9, 5.5), (5.3, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(5.3, [#"hx-trigger"], [what fires it])
  cdraw.line((9.9, 5.5), (10.3, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(10.3, [server], [answers html])
  cdraw.line((14.9, 5.5), (15.3, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(15.3, [#"hx-target"], [where it lands])
  cdraw.line((19.9, 5.5), (20.3, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(20.3, [#"hx-swap"], [how it lands])
  cdraw.content((11.8, 3.2), [without hx-target the element itself is the target], size: 6pt)
  cdraw.content((11.8, 2.1), [without hx-trigger the natural event fires: click,], size: 6pt)
  cdraw.content((11.8, 1.0), [submit for forms, change for inputs, per the docs], size: 6pt)
})

== triggers and their modifiers

`hx-trigger` replaces the natural event and its modifiers carry real
logic. `every 2s` polls on an interval. `changed` fires only when the
value differs. `delay:500ms` waits, resetting the countdown when the
event refires, the debounce. `throttle:1s` fires immediately then
holds, queueing the last event for the end, the rate limit. `once`
fires a single time. `from:` listens on another element, `load`
fires when the element first appears, and `revealed` when it scrolls
into view. The demo needs three of them for real, and the page markup
shows the wiring:

#listing("go/samples/ch16/htmx.go", first: 213, last: 230, caption: [the served body: debounce search, two pollers, a one shot load])

#snippet(
  "<div hx-get=\"/fragment/tip\" hx-trigger=\"revealed once\">tip</div>\n"
  + "<body> <input hx-get=\"/fragment/search\"\n"
  + "  hx-trigger=\"keyup changed throttle:1s from:body\"> </body>\n",
  lang: "html",
)

#diagram([delay versus throttle under a burst of five events], length: 13pt, {
  cdraw.content((2.2, 7.6), [five events], size: 6.5pt)
  for i in range(5) {
    cdraw.rect((0.6 + i * 1.1, 6.7), (1.2 + i * 1.1, 7.4), fill: luma(160), radius: 0.02)
  }
  cdraw.content((2.2, 5.6), [delay:], size: 6.5pt)
  cdraw.rect((0.6, 4.7), (1.2, 5.4), fill: luma(235), radius: 0.02)
  cdraw.content((6.0, 5.1), [countdown resets on each refire, so one], size: 6pt)
  cdraw.content((6.0, 4.1), [request leaves, after the quiet], size: 6pt)
  cdraw.line((1.2, 5.05), (10.6, 4.2), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((2.2, 2.9), [throttle:], size: 6.5pt)
  cdraw.rect((0.6, 2.0), (1.2, 2.7), fill: luma(205), radius: 0.02)
  cdraw.rect((5.0, 2.0), (5.6, 2.7), fill: luma(205), radius: 0.02)
  cdraw.content((6.0, 2.4), [first fires now, the window holds, the], size: 6pt)
  cdraw.content((6.0, 1.4), [last queued event fires at the end], size: 6pt)
  pane(13.7, 23.3, 7.4, [the demo uses], [keyup changed delay:500ms], [every 2s, every 5s, load once])
  cdraw.content((18.5, 0.1), [each one pinned by the catalog test], size: 6pt)
})

== swaps and out of band

`hx-swap` defaults to `innerHTML`. The demo also uses `outerHTML`,
where the fragment carries its own id and replaces itself whole,
keeping the id stable across polls, and `none`, where the element
fires a request and ignores the body. One response can update more
than one place: elements marked `hx-swap-oob="true"` are pulled out
of the response and swapped into their own id matches instead of the
target, so the note post returns the list and the counter in the
same bytes:

#listing("go/samples/ch16/htmx.go", first: 165, last: 170, caption: [the oob counter, one response, two destinations])

#diagram([the response body split at the target and at the id match], length: 13pt, {
  cdraw.rect((7.1, 5.6), (16.5, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 6.7), [the response body], size: 6.5pt)
  cdraw.content((11.8, 5.9), [#"ul notes + span count"], size: 6pt)
  cdraw.line((9.0, 5.4), (5.4, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((14.6, 5.4), (18.2, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 2.4), (10.5, 4.1), fill: luma(205), radius: 0.02)
  cdraw.content((5.4, 3.6), [the target swap], size: 6pt)
  cdraw.content((5.4, 2.8), [#"ul id notes, outerHTML"], size: 6pt)
  cdraw.rect((13.1, 2.4), (23.3, 4.1), fill: luma(222), radius: 0.02)
  cdraw.content((18.2, 3.6), [the oob pull aside], size: 6pt)
  cdraw.content((18.2, 2.8), [#"span id count, by id match"], size: 6pt)
  cdraw.content((11.8, 1.2), [the test asserts the oob markup and the count text], size: 6pt)
  cdraw.content((11.8, 0.1), [in the same body the target swap consumed], size: 6pt)
})

== the response protocol

Headers are the server's channel into the client loop. `HX-Request`
rides every ajax request and is the branching input. `HX-Trigger`
fires a client side event from the server, the honest way to tell
listeners a mutation happened without making them parse html.
`HX-Redirect` hands the client a location to load, `HX-Refresh`
reloads, `HX-Push-Url` and `HX-Replace-Url` edit the address bar, and
`HX-Retarget`, `HX-Reswap`, `HX-Reselect` rewrite the swap contract
on the way out. Status codes participate too: 204 and 304 sit in the
default `noSwap` list, so a no-content answer costs nothing, which
suits actions whose visible effect arrives on the next poll:

#listing("go/samples/ch16/htmx.go", first: 122, last: 139, caption: [204 answers: swap nothing, say why through the trigger header])

#diagram([the header vocabulary as one channel per intent], length: 13pt, {
  pane(0.3, 11.3, 7.3, [the request side], [#"HX-Request: true", the], [branch input for the], [two faced route])
  pane(12.7, 23.3, 7.3, [the reply side], [#"HX-Trigger, HX-Redirect,"], [#"HX-Push, HX-Retarget"], [and 204 in noSwap])
  cdraw.content((11.8, 4.6), [in], size: 6pt)
  cdraw.content((11.8, 3.5), [out], size: 6pt)
  cdraw.content((11.8, 2.1), [the demo uses three: the branch, the], size: 6pt)
  cdraw.content((11.8, 1.0), [trigger on save and clear, the redirect on logout], size: 6pt)
})

== polling and server sent events

`hx-trigger="every 2s"` is the two attribute dashboard: one element,
one interval, one fragment route. Its cost is arithmetic, open tabs
times frequency, so the fragment must be cheap and uncached, which
the demo's clock handler states outright with `Cache-Control:
no-store`. When the server owns the timing instead, server sent
events flip the direction: one response held open on the
`text/event-stream` wire, each event an event line, a data line, a
blank line, and a flush. The browser half rides htmx's bundled sse
extension, `hx-ext="sse"` with `sse-connect` and `sse-swap`, and the
go half is the whole of this section:

#listing("go/samples/ch16/htmx.go", first: 141, last: 163, caption: [the no-store clock and the sse stream, flush between events])

#diagram([polling asks on a timer, sse holds one response open], length: 13pt, {
  cdraw.content((2.6, 7.6), [polling], size: 6.5pt)
  for i in range(4) {
    cdraw.line((0.8 + i * 2.2, 5.2), (1.8 + i * 2.2, 5.2), stroke: luma(100), mark: (end: ">>"))
  }
  cdraw.content((2.6, 4.0), [request, fragment, request], size: 6pt)
  cdraw.content((2.6, 3.0), [cost grows with tabs open], size: 6pt)
  cdraw.content((15.9, 7.6), [server sent events], size: 6.5pt)
  cdraw.line((13.0, 5.2), (21.5, 5.2), stroke: luma(100))
  cdraw.content((15.9, 4.0), [one response, held open], size: 6pt)
  cdraw.content((15.9, 3.0), [events framed and flushed], size: 6pt)
  cdraw.content((11.8, 1.5), [the demo streams three ticks then ends, the test reads the exact bytes], size: 6pt)
  cdraw.content((11.8, 0.4), [client half: the bundled sse extension, cite four.htmx.org], size: 6pt)
})

== validation and errors

Validation lives where the data lands, on the server, and in 4.0 the
error path is a fragment path: a 400 whose body is the markup that
explains the problem, swapped into the form's target exactly like a
success, where 2.x dropped the body and needed configuration to do
better. The demo's empty note returns one:

#listing("go/samples/ch16/htmx.go", first: 103, last: 120, caption: [validate, answer a fragment either way, announce the save])

Bodies are hostile input and the fragment renderers escape them with
`html.EscapeString` before they touch markup, the same discipline a
full page owes. The test posts whitespace, asserts the 400, and
asserts the error paragraph is in the body it can read.

#diagram([one handler, two fragment outcomes, both swapped in 4.0], length: 13pt, {
  cdraw.rect((8.1, 5.6), (15.5, 7.2), fill: luma(235), radius: 0.02)
  cdraw.content((11.8, 6.7), [post a note], size: 6.5pt)
  cdraw.content((11.8, 5.9), [trim the body field], size: 6pt)
  cdraw.line((9.7, 5.4), (5.4, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((13.9, 5.4), (18.2, 3.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, 2.4), (10.5, 4.1), fill: luma(205), radius: 0.02)
  cdraw.content((5.4, 3.6), [empty], size: 6pt)
  cdraw.content((5.4, 2.8), [400, error fragment], size: 6pt)
  cdraw.rect((13.1, 2.4), (23.3, 4.1), fill: luma(222), radius: 0.02)
  cdraw.content((18.2, 3.6), [present], size: 6pt)
  cdraw.content((18.2, 2.8), [200, list plus oob count], size: 6pt)
  cdraw.content((11.8, 1.2), [2.x dropped the 400 body: 4.0 swaps it, says the migration], size: 6pt)
  cdraw.content((11.8, 0.1), [notes page, and reverting is a config line], size: 6pt)
})

== serving and pinning htmx

The script is an asset like any other, so it is vendored into the
package and served by the standard library, `go:embed` folding the
bytes into the binary and `http.FileServer` over `http.FS` serving
them. The pin is the digest: a SHA-384 over the exact bytes, embedded
in the `integrity` attribute so the browser verifies the script it
runs, and recomputed by the test over the bytes the server actually
serves, so the vendored file cannot drift silently. The digest below
matches the published artifact byte for byte:

#listing("go/samples/ch16/htmx.go", first: 19, last: 25, caption: [embed the bytes, pin them with the sri constant])

#listing("go/samples/ch16/htmx_test.go", first: 70, last: 84, caption: [the test recomputes the digest from the served bytes])

#callout("note", "why vendored instead of installed", [
  The npm registry's `latest` tag still points at 2.0.10 while 4.0.0
  rides the `next` tag, so `npm install htmx` buys the wrong major
  version. The 4.0.0 file here is copied byte-identical from this
  repo's vendored copy, 36716 bytes, its SHA-384 digest matching the
  published integrity value, and the documentation consulted is
  four.htmx.org, accessed 2026-09-21. A build step would add a
  toolchain to avoid a file copy.
])

#diagram([the pin: one file, one digest, three places it is checked], length: 13pt, {
  pane(0.3, 7.5, 7.2, [the file], [vendored in the package], [folded in by go:embed])
  cdraw.line((7.7, 4.0), (8.3, 4.0), stroke: luma(100), mark: (end: ">>"))
  pane(8.4, 15.6, 7.2, [the const], [sha384 over the bytes], [in the script integrity])
  cdraw.line((15.8, 4.0), (16.4, 4.0), stroke: luma(100), mark: (end: ">>"))
  pane(16.5, 23.3, 7.2, [the test], [recomputes from the], [served bytes, equal])
  cdraw.content((11.8, 2.1), [a swapped or truncated file fails the test, a changed], size: 6pt)
  cdraw.content((11.8, 1.0), [const fails the page assertion, nothing drifts silently], size: 6pt)
})

sources: four.htmx.org for the htmx 4.0.0 reference and migration
notes, accessed 2026-09-21, and pkg.go.dev for net/http, embed, and
crypto/sha512. Verified by `go/samples/ch16` tests, 12 of them.
