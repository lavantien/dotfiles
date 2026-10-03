#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= toolchain and modules

Go ships as one command. `go build`, `go test`, `go vet`, `go fmt`,
`go mod tidy`, `go generate`, `go doc` are all the same binary, which
is why Go projects have no per-project build scripts: the module file
plus the toolchain is the whole configuration surface. This book pins
go 1.27, released august 2026, and every sample lives in one module at
`go/samples/` with `go 1.27` in its `go.mod`.

== the module

A module is a directory tree with a `go.mod` at the root declaring the
module path and the language version:

#snippet(
  "module gobook\n\n"
  + "go 1.27\n",
  lang: "go",
)

The `go` line is a language version, not a toolchain request. Code in
the module is compiled under 1.27 rules even when a newer toolchain
builds it, so a language change like the promoted literal keys of
chapter 3 is opt in per module. A separate `toolchain` directive, for
example `toolchain go1.27.2`, requests a patch release, and
`GOTOOLCHAIN=auto` (the default) downloads and switches to it
transparently. Dependencies carry semantic import versions, `go get`
records them in `go.mod` and hashes into `go.sum`, and `go mod tidy`
adds what imports need and drops the rest, merging duplicate require
blocks into direct and indirect since 1.27.

#diagram([one go.mod governs the whole tree: import paths, compile rules, patch release], length: 13pt, {
  cdraw.rect((7.4, 5.5), (15.6, 6.5), fill: luma(205), radius: 0.02)
  cdraw.content((11.5, 6.0), [go.mod], size: 7pt)
  let field(x0, label, m1, m2) = {
    cdraw.line((11.5, 5.5), (x0 + 3.6, 4.7), stroke: luma(100))
    cdraw.rect((x0, 2.7), (x0 + 7.2, 4.7), fill: luma(235), radius: 0.02)
    cdraw.content((x0 + 3.6, 3.7), [#label], size: 6.5pt)
    cdraw.content((x0 + 3.6, 1.9), [#m1], size: 6pt)
    cdraw.content((x0 + 3.6, 0.7), [#m2], size: 6pt)
  }
  field(0.3, [module gobook], [import path prefix], [for the whole tree])
  field(8.1, [go 1.27], [compile rules], [locked per module])
  field(15.9, [toolchain #linebreak() go1.27.2], [GOTOOLCHAIN picks], [the patch release])
})

#callout("note", "one module or many", [
  One module per repository is the default stance, and this book keeps
  its samples in one. Multi module repositories exist for versioned
  public apis, and `go work` stitches several modules into one build
  for local development without editing their `go.mod` files.
])

== build tags, embed, generate

Three directives run before, at, and after compilation, and the sample
package uses all three.

Build tags choose which files compile. The `//go:build` constraint
sits under the package clause, and exactly one of a pair of files
enters the build:

#listing("go/samples/ch01/flavor_default.go", first: 1, last: 8, caption: [the default variant compiles without tags])

`go build` takes this file, `go build -tags hardened` takes its twin
`flavor_hardened.go`, and both declare `BuildFlavor` exactly once per
build. This is how platform and build flavor differences are expressed,
never through runtime flags. The constraints understand `GOOS`,
`GOARCH`, `//go:build linux && amd64`, release tags like `go1.27`, and
custom names like `hardened` above.

#diagram([three directives at three trigger points on the road from source to binary], length: 13pt, {
  cdraw.line((0.8, 2.8), (22.6, 2.8), stroke: luma(100), mark: (end: ">>"))
  let stage(x, name, sub) = {
    cdraw.line((x, 2.8), (x, 3.1), stroke: luma(100))
    cdraw.content((x, 4.65), [#name], size: 6.5pt)
    cdraw.content((x, 3.5), [#sub], size: 6pt)
  }
  stage(3.4, [generate], [writes new source])
  stage(10.8, [build tags], [selects the files])
  stage(18.2, [embed], [folds bytes in])
  cdraw.content((3.4, 2.1), [on demand], size: 6pt)
  cdraw.content((14.5, 2.1), [both inside go build], size: 6pt)
})

`go:embed` folds a file into the binary at compile time:

#listing("go/samples/ch01/toolchain.go", first: 6, last: 22, caption: [generate directive, embed directive, and the metadata readers])

The directive is an import of compile time data: the bytes of
`tagline.txt` land in the binary verbatim, trailing newline included,
with no file io at runtime. Embed accepts single files, patterns like
`static/*.html`, and the `embed.FS` type for directory trees.

`go:generate` is a make for source. The directive runs a command with
the package directory as working directory, and the convention is to
commit both generator and output so reviewers see what ran:

#snippet(
  "//go:generate go run ./gen\n"
  + "// then, once:\n"
  + "go generate ./...\n",
  lang: "go",
)

The generator here writes `greeting_gen.go`, whose
`GeneratedGreeting` is an ordinary function once generated, and the
test suite asserts its value so a deleted or stale file fails `go
test`, not production. Wire format marshaling, string tables, and code
derived from schemas are the real world uses.

== build info

A compiled binary knows what built it. `runtime.Version` answers
during execution, and `debug.ReadBuildInfo` carries the same plus
module versions and vcs state, which survives into installed binaries
and is what `go version -m ./binary` prints from outside:

#listing("go/samples/ch01/toolchain.go", first: 25, last: 33, caption: [build metadata, readable at runtime])

#diagram([what the binary knows about itself, read from inside and outside], length: 13pt, {
  cdraw.rect((8.4, 1.6), (16.9, 6.6), fill: luma(240), radius: 0.02)
  cdraw.content((12.65, 7.1), [the installed binary], size: 6.5pt)
  cdraw.rect((9.0, 5.1), (16.3, 6.0), fill: luma(205), radius: 0.02)
  cdraw.content((12.65, 5.55), [go1.27.0 toolchain], size: 6pt)
  cdraw.rect((9.0, 3.9), (16.3, 4.8), fill: luma(205), radius: 0.02)
  cdraw.content((12.65, 4.35), [module versions], size: 6pt)
  cdraw.rect((9.0, 2.7), (16.3, 3.6), fill: luma(205), radius: 0.02)
  cdraw.content((12.65, 3.15), [vcs revision], size: 6pt)
  cdraw.content((3.9, 4.75), [at run time], size: 6.5pt)
  cdraw.content((3.9, 3.65), [runtime.Version], size: 6pt)
  cdraw.content((3.9, 2.55), [debug.ReadBuildInfo], size: 6pt)
  cdraw.line((7.8, 3.1), (8.4, 3.1), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((20.1, 4.75), [from outside], size: 6.5pt)
  cdraw.content((20.1, 3.65), [go version -m], size: 6pt)
  cdraw.content((20.1, 2.55), [./binary], size: 6pt)
  cdraw.line((17.4, 3.1), (16.95, 3.1), stroke: luma(100), mark: (end: ">>"))
})

== the checks that gate every commit

`go vet ./...` runs the standard analyzers: printf argument mismatch,
unreachable code, struct tags, lock copies, and `stringintconv`, the
check that flags `string(65)` because it yields the rune `A` rather
than `"65"`. `gofmt -l .` lists files whose formatting differs from
canonical, and Go formatting is not configurable, which ends style
debates by decree. `go fix -diff` previews the 1.27 modernizers, among
them `atomictypes` for the atomic pointer types, `embedlit` and
`slicesbackward`, and `go doc` now takes `package@version` to read a
dependency's docs without cloning it. This repo runs vet plus tests
for every go module it finds, under `make verify-go`.

#flow(
  [the commit gate: vet analyzers, gofmt decree, fix modernizers, doc at version, one pipeline into make verify-go],
  node((0, 0), [vet]),
  edge((0, 0), (1.6, 0), "-|>"),
  node((1.6, 0), [gofmt]),
  edge((1.6, 0), (3.2, 0), "-|>"),
  node((3.2, 0), [fix]),
  edge((3.2, 0), (4.8, 0), "-|>"),
  node((4.8, 0), [doc]),
  edge((4.8, 0), (6.4, 0), "-|>"),
  node((6.4, 0), [verify-go]),
)

sources: go.dev, go 1.27 release notes and modules reference, accessed
2026-09-08. Toolchain behavior verified live with go1.27.0 on windows,
26 tests across ch01 to ch03 green via `make verify-go`.
