#import "../../theme/lib.typ": cdraw, diagram, listing, snippet, callout, xref-to

= images and layers

A docker image is a tarball of filesystem layers plus a manifest that
says which layer goes on top of which. Each layer is the directory
diff one build step produced, so two images that share a base and a
dependency step share those layers on disk and in the registry, and a
rebuild that changes only source code downloads nothing it already
has. The whole art of a fast build loop is ordering the file copies so
the layers that change rarely sit under the layers that change often.

The capstone builds five services out of one dockerfile by handing the
build stage an argument that picks the command to compile:

#listing("infrastructure/capstone/Dockerfile", first: 1, last: 11, caption: [the build stage: dependencies first, source second, one binary out])

#diagram([the build stage as a layer stack, and what a one line source edit rebuilds], length: 13pt, {
  let layer(y, label, hot) = {
    cdraw.rect((1.0, y), (13.0, y + 1.0), fill: if hot { luma(205) } else { luma(235) }, radius: 0.02)
    cdraw.content((7.0, y + 0.5), [#label], size: 6pt)
  }
  layer(0.0, [golang:1.27-alpine base], false)
  layer(1.2, [copy go.mod go.sum], false)
  layer(2.4, [go mod download], false)
  layer(3.6, [copy the source], true)
  layer(4.8, [compile, one binary out], true)

  cdraw.line((13.3, 3.7), (13.3, 5.7), stroke: luma(100))
  cdraw.line((13.0, 3.9), (13.3, 3.9), stroke: luma(100))
  cdraw.line((13.0, 5.5), (13.3, 5.5), stroke: luma(100))
  cdraw.content((18.2, 4.7), [rebuilt on a one line change], size: 6pt)

  cdraw.line((13.3, 0.1), (13.3, 2.9), stroke: luma(100))
  cdraw.line((13.0, 0.3), (13.3, 0.3), stroke: luma(100))
  cdraw.line((13.0, 2.7), (13.3, 2.7), stroke: luma(100))
  cdraw.content((18.2, 1.5), [reused bit for bit], size: 6pt)
  cdraw.content((18.2, 0.4), [identity is the content hash], size: 6pt)
})

Three choices carry the weight. `COPY go.mod go.sum` before any
source means the `go mod download` layer is built once and reused
across every code edit, which is the difference between a two second
rebuild and a two minute one. `CGO_ENABLED=0` keeps chapter 1's
promise, the binary is static, so the runtime image needs no toolchain
and no glibc version negotiation. And the `SERVICE` argument means one
dockerfile, five images, no duplicated instructions drifting apart.

#listing("infrastructure/capstone/Dockerfile", first: 13, last: 18, caption: [the runtime stage: alpine, one binary, exec form entrypoint])

The runtime stage copies exactly one artifact into an alpine base.
Alpine and not something thinner: the healthchecks in
#xref-to("infrastructure", "compose") shell out to busybox `wget`,
which alpine ships and distroless images do not. Choosing a base by
size alone quietly costs you the process you need for probing. The
entrypoint is exec form, square brackets, which matters more than it
looks and is the subject of #xref-to("infrastructure", "containers").

#callout("note", "layers are content addressed", [
  A layer's identity is the hash of its contents. Two services built
  from the same stage share the compiled dependencies layer bit for
  bit, and `docker compose up --build` after a one line go change
  rebuilds only the source copy and the compile. Watching the layer
  ids scroll past on the second build is the cheapest way to verify
  the copy order is doing its job.
])

The image tags the compose file pins, `golang:1.27-alpine`,
`alpine:3.22`, `nats:2.14.6-alpine`, `mongo:8.0`, and `debian:13-slim`
for the analytics image, were verified with `docker manifest inspect`
before landing in `compose.yml`, the same pin-then-assert discipline
the sqlite version gets.

sources: docs.docker.com/reference/dockerfile for build stages,
entrypoint forms, and build arguments, accessed 2026-09-10. Verified
by `make verify-infra-docker`, which builds all five alpine images
plus the one debian analytics image and runs the tagged suite against
them, run green 2026-09-20.
