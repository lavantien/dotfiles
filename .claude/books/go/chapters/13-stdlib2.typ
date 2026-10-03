#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= stdlib tour 2: json/v2, uuid, net/http, crypto, simd, os, io

The second tour covers what arrived newest and what serves the
network. The headline is `encoding/json/v2`, stable in go 1.27 with
the v1 package now running on top of it, and the tour also covers
the `uuid` package, both new enough that most go code in the wild
predates them.

== json v2

The import is `encoding/json/v2`, the package name is still `json`,
and every entry point takes variadic options:

#snippet(
  "func Marshal(in any, opts ...Options) ([]byte, error)\n"
  + "func Unmarshal(in []byte, out any, opts ...Options) error\n"
  + "// plus MarshalWrite, MarshalEncode, UnmarshalRead, UnmarshalDecode\n",
  lang: "go",
)

The defaults are stricter than v1, invalid utf-8 and duplicate
object names are rejected rather than repaired, and names match case
sensitively. The struct tag language grew one tag that matters:

#listing("go/samples/ch13/stdlib2_test.go", first: 20, last: 27, caption: [one struct, three tag behaviors])

`omitzero` and `omitempty` sound interchangeable and are not, the
distinction the test pins from both sides:

#listing("go/samples/ch13/stdlib2_test.go", first: 49, last: 69, caption: [go zero values versus empty json encodings])

`omitzero` consults the Go type system, a nil slice is zero and
vanishes, a non-nil empty slice is not zero and stays as `[]`.
`omitempty` consults the JSON encoding, anything that would encode
as null, empty string, `{}`, or `[]` vanishes whatever its Go value.
The v2 documentation's advice: prefer `omitzero` when either would
do, it is the one whose semantics a reader can reason about locally.

#diagram([omitzero asks the go type, omitempty asks the json encoding], length: 13pt, {
  cdraw.content((6.0, 7.6), [omitzero], size: 6.5pt)
  cdraw.content((15.5, 7.6), [omitempty], size: 6.5pt)
  let row(y, val, oz, oe) = {
    cdraw.line((0.9, y - 0.45), (21.8, y - 0.45), stroke: luma(220))
    cdraw.content((2.8, y), [#val], size: 6pt)
    cdraw.content((7.4, y), [#oz], size: 6pt)
    cdraw.content((15.5, y), [#oe], size: 6pt)
  }
  row(6.4, [#"nil slice"], [omits], [omits, null])
  row(5.4, [#"[]int{} non nil"], [#"keeps: []"], [omits, encodes empty])
  row(4.4, [#"\"\" string"], [omits], [omits])
  row(3.4, [#"empty map"], [#"keeps: {}"], [omits])
  cdraw.content((11.3, 2.2), [one asks the go zero value, the other the json encoding], size: 6pt)
  cdraw.content((11.3, 1.1), [prefer omitzero: its meaning reads locally], size: 6pt)
  cdraw.content((11.3, 0.0), [v2 defaults: invalid utf-8 and duplicates rejected], size: 6pt)
})

Options compose at call sites, and the useful three:

#listing("go/samples/ch13/stdlib2_test.go", first: 71, last: 100, caption: [deterministic maps, strict input, quoted numbers])

`Deterministic(true)` sorts map keys, `RejectUnknownMembers(true)`
turns typos into errors on the way in, `StringifyNumbers(true)`
quotes numbers both directions for apis that demand string ids. On
strictness, unknown members are ignored by default like v1, invalid
utf-8 is not repaired, and the escapes are minimal, all reversible
through jsontext options when a legacy peer needs the old behavior.

== jsontext

Under v2 sits a token layer, `encoding/json/jsontext`, for code that
must see json as syntax rather than as Go values, streaming
protocols, validators, transformers:

#listing("go/samples/ch13/stdlib2_test.go", first: 102, last: 116, caption: [indent a value, peek the next kind])

`Value` holds pre-encoded json and reformats in place, `Indent`
taking options like `WithIndent`, `Canonicalize` applies RFC 8785
canonical form, and the `Decoder` `PeekKind` looks ahead without
consuming, the first step of every hand rolled dispatch on mixed
streams. `MarshalEncode` and `UnmarshalDecode` bridge the layers,
writing go values into an encoder mid stream.

#diagram([the token layer: peek without consuming, reformat in place, bridge mid stream], length: 13pt, {
  let stage(x0, title, l1) = {
    cdraw.rect((x0, 4.4), (x0 + 5.2, 6.6), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 6.0), [#title], size: 6.5pt)
    cdraw.content((x0 + 2.6, 5.0), [#l1], size: 6pt)
  }
  stage(0.3, [Decoder], [reads tokens])
  cdraw.line((5.7, 5.5), (6.1, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(6.1, [PeekKind], [peeks ahead])
  cdraw.line((11.5, 5.5), (11.9, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(11.9, [dispatch], [picks handler])
  cdraw.line((17.3, 5.5), (17.7, 5.5), stroke: luma(100), mark: (end: ">>"))
  stage(17.7, [decode], [into go values])
  pane(0.3, 11.3, 3.2, [Value], [pre encoded json,], [Indent, Canonicalize])
  cdraw.content((17.6, 2.6), [#"MarshalEncode bridges: go values"], size: 6pt)
  cdraw.content((17.6, 1.5), [written into an encoder mid stream], size: 6pt)
})

== uuid

Go 1.27 also standardized `uuid`, RFC 9562, `[16]byte` with text
marshaling wired in:

#listing("go/samples/ch13/stdlib2_test.go", first: 118, last: 146, caption: [new, newv7 ordering, parse round trip, must panic])

`New` is currently v4, 122 random bits, and `NewV7` is the one to
reach for in databases, 48 bits of unix millisecond timestamp plus
random, so ids sort by creation time. `Parse` accepts hyphenated,
braced, urn, and bare hex spellings, and the type is comparable and
json serializable through its text methods.

#diagram([sixteen bytes, two layouts: v4 all random, v7 timestamp first], length: 13pt, {
  cdraw.content((2.2, 7.1), [v4], size: 6.5pt)
  cdraw.rect((4.2, 6.5), (17.2, 7.3), fill: luma(205), radius: 0.02)
  cdraw.content((10.7, 6.9), [random, 122 bits], size: 6pt)
  cdraw.rect((17.4, 6.5), (19.2, 7.3), fill: luma(225), radius: 0.02)
  cdraw.content((18.3, 6.9), [ver], size: 6pt)
  cdraw.rect((19.4, 6.5), (21.2, 7.3), fill: luma(225), radius: 0.02)
  cdraw.content((20.3, 6.9), [var], size: 6pt)
  cdraw.content((2.2, 5.3), [v7], size: 6.5pt)
  cdraw.rect((4.2, 4.7), (9.4, 5.5), fill: luma(235), radius: 0.02)
  cdraw.content((6.8, 5.1), [48-bit unix ms], size: 6pt)
  cdraw.rect((9.6, 4.7), (11.4, 5.5), fill: luma(225), radius: 0.02)
  cdraw.content((10.5, 5.1), [ver], size: 6pt)
  cdraw.rect((11.6, 4.7), (19.2, 5.5), fill: luma(205), radius: 0.02)
  cdraw.content((15.4, 5.1), [random], size: 6pt)
  cdraw.rect((19.4, 4.7), (21.2, 5.5), fill: luma(225), radius: 0.02)
  cdraw.content((20.3, 5.1), [var], size: 6pt)
  cdraw.content((12.6, 3.4), [the timestamp leads, so v7 ids sort by creation time], size: 6pt)
  pane(0.3, 11.3, 1.9, [parse accepts], [hyphenated, braced, urn,], [and bare hex spellings])
  cdraw.content((17.6, -0.3), [#"comparable, and json via text methods"], size: 6pt)
})

== net/http

The server is still the standard library's crown: a handler is a
function, and `httptest.NewServer` gives it a real local listener
for tests. Go 1.27's `httptest.NewTestServer` goes further, an
in-memory fake network with no sockets at all, designed to pair
with `synctest` bubbles for deterministic concurrency tests, and
production servers gained `MaxHeaderValueCount` and RFC 9218 http/2
priority honoring:

#listing("go/samples/ch13/stdlib2_test.go", first: 148, last: 175, caption: [serve, get, read, decode])

The client needs no configuration for the ordinary case, `http.Get`,
read the body, close it, and since 1.27 the http/1 client drains
small unread bodies on close so keep alive connections survive.

#diagram([the round trip: handler is a function, client is get, read, close], length: 13pt, {
  cdraw.content((11.8, 7.7), [server side], size: 6.5pt)
  cdraw.rect((0.3, 5.1), (7.5, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((3.9, 6.4), [handler func], size: 6pt)
  cdraw.content((3.9, 5.4), [#"http.HandlerFunc"], size: 6pt)
  cdraw.line((7.7, 5.95), (8.5, 5.95), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((8.7, 5.1), (15.9, 6.8), fill: luma(235), radius: 0.02)
  cdraw.content((12.3, 6.4), [#"httptest.NewServer"], size: 6pt)
  cdraw.content((12.3, 5.4), [a real listener], size: 6pt)
  cdraw.line((16.1, 5.95), (16.9, 5.95), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((17.1, 5.1), (23.3, 6.8), fill: luma(225), radius: 0.02)
  cdraw.content((20.2, 6.4), [1.27: in memory], size: 6pt)
  cdraw.content((20.2, 5.4), [#"NewTestServer"], size: 6pt)
  cdraw.content((11.8, 4.3), [client side], size: 6.5pt)
  let step(x0, title, l1) = {
    cdraw.rect((x0, 2.0), (x0 + 5.2, 3.9), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 2.6, 3.35), [#title], size: 6pt)
    cdraw.content((x0 + 2.6, 2.35), [#l1], size: 6pt)
  }
  step(0.3, [#"http.Get(url)"], [no config needed])
  cdraw.line((5.7, 2.95), (6.1, 2.95), stroke: luma(100), mark: (end: ">>"))
  step(6.1, [read the body], [#"io.ReadAll, decode"])
  cdraw.line((11.5, 2.95), (11.9, 2.95), stroke: luma(100), mark: (end: ">>"))
  step(11.9, [close it], [always, defer])
  cdraw.line((17.3, 2.95), (17.7, 2.95), stroke: luma(100), mark: (end: ">>"))
  step(17.7, [keep alive], [small unread drained])
  cdraw.content((11.8, 0.9), [1.27 drains small unread bodies on close, the], size: 6pt)
  cdraw.content((11.8, -0.2), [connection survives for the next request], size: 6pt)
})

== crypto and simd

Hashes are `Sum256` and friends over byte slices, and the known
vector test pins the digest of `"hello"` to its published value. The
post quantum story is the 1.27 headline: `crypto/mldsa` implements
ML-DSA signatures from FIPS 204, TLS 1.3 negotiates the ML-DSA
signature schemes, and ML-KEM hybrid key exchange ships on by
default. `crypto/rand` remains the randomness source, never
`math/rand`, which exists for simulation.

#diagram([the crypto and simd corner of the tour], length: 13pt, {
  pane(0.3, 7.4, 7.2, [hashes], [#"Sum256 and friends, over"], [byte slices, known vectors])
  pane(8.0, 15.1, 7.2, [randomness], [crypto/rand is the], [source, math/rand], [is simulation])
  pane(15.7, 22.8, 7.2, [1.27 post quantum], [#"crypto/mldsa: FIPS 204"], [ML-KEM hybrid on by], [default, TLS negotiates])
  cdraw.content((11.5, 2.2), [simd: portable vector types behind GOEXPERIMENT], size: 6pt)
  cdraw.content((11.5, 1.1), [#"amd64 to 512 bit, arm64 neon, wasm 128"], size: 6pt)
  cdraw.content((11.5, 0.0), [documented here, not tested: enabling], size: 6pt)
  cdraw.content((11.5, -1.1), [the experiment pins the build to it], size: 6pt)
})

#callout("note", "simd is experimental and off by default", [
  The `simd` and `simd/archsimd` packages give portable, vector
  width agnostic types like `simd.Int8s` and `simd.Float32s`, amd64
  up to 512 bit, arm64 neon, and wasm 128 bit. In go 1.27 they sit
  behind `GOEXPERIMENT=simd` with an unstable api, so this book
  documents them without testing them: enabling the experiment in a
  module pins the build to toolchains honoring it.
])

== os and io

File io is `os.Open`, `os.Create`, `os.WriteFile`, with `t.TempDir`
giving tests a directory the framework cleans:

#listing("go/samples/ch13/stdlib2_test.go", first: 186, last: 206, caption: [write, copy into a builder, assert the bytes])

The `io` package is the core three interfaces, `Reader`, `Writer`,
`ReadWriter`, plus the combinators over them, `Copy`, `ReadAll`,
`MultiReader`, `Pipe`, and `strings.Builder` as the in memory
writer. Everything streams, `io.Copy` moves bytes through a 32 kb
buffer without loading either end, and the interfaces compose with
every type in this chapter, hash writers, http bodies, file
handles, json encoders.

#diagram([three interfaces, combinators over them, everything composes], length: 13pt, {
  cdraw.content((11.8, 7.6), [the interfaces], size: 6.5pt)
  cdraw.rect((0.9, 5.9), (7.5, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((4.2, 6.5), [Reader], size: 6pt)
  cdraw.rect((8.4, 5.9), (15.0, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((11.7, 6.5), [Writer], size: 6pt)
  cdraw.rect((15.9, 5.9), (22.5, 7.1), fill: luma(235), radius: 0.02)
  cdraw.content((19.2, 6.5), [ReadWriter], size: 6pt)
  cdraw.line((11.7, 5.7), (11.7, 4.9), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((11.8, 4.4), [the combinators], size: 6.5pt)
  let cell(xc, text) = {
    cdraw.rect((xc - 2.7, 2.5), (xc + 2.7, 3.7), fill: luma(225), radius: 0.02)
    cdraw.content((xc, 3.1), [#text], size: 6pt)
  }
  cell(3.4, [#"Copy, 32 kb buf"])
  cell(9.1, [ReadAll])
  cell(14.8, [MultiReader])
  cell(20.1, [#"Pipe, Builder"])
  cdraw.content((11.8, 1.4), [composes with hash writers, http bodies,], size: 6pt)
  cdraw.content((11.8, 0.3), [file handles, json encoders: everything streams], size: 6pt)
})

sources: pkg.go.dev for encoding/json/v2, encoding/json/jsontext,
uuid, net/http, crypto, os, io, accessed 2026-09-08, and the go 1.27
release notes for the simd, mldsa, and httptest changes. Verified
by `go/samples/ch13` tests, 11 of them.
