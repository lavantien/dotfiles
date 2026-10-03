// book 4: written chapters are included, the rest render as stubs until authored
#import "../theme/lib.typ": book
#import "manifest.typ": jsbook

#let written = (
  "toolchain": "chapters/01-toolchain.typ",
  "lexical": "chapters/02-lexical.typ",
  "functions": "chapters/03-functions.typ",
  "objects": "chapters/04-objects.typ",
  "iteration": "chapters/05-iteration.typ",
  "async": "chapters/06-async.typ",
  "modules": "chapters/07-modules.typ",
  "stdlib": "chapters/08-stdlib.typ",
  "heap": "chapters/09-heap.typ",
  "profiling": "chapters/10-profiling.typ",
  "tstoolchain": "chapters/11-tstoolchain.typ",
  "typesyntax": "chapters/12-typesyntax.typ",
  "types": "chapters/13-types.typ",
  "typefunctions": "chapters/14-typefunctions.typ",
  "typeobjects": "chapters/15-typeobjects.typ",
  "unions": "chapters/16-unions.typ",
  "typelevel": "chapters/17-typelevel.typ",
  "typeclasses": "chapters/18-typeclasses.typ",
  "typemodules": "chapters/19-typemodules.typ",
  "idioms": "chapters/20-idioms.typ",
  "react": "chapters/21-react.typ",
  "svelte": "chapters/22-svelte.typ",
  "api-kernel": "chapters/23-apikernel.typ",
  "middleware": "chapters/24-middleware.typ",
  "users": "chapters/25-users.typ",
  "authn": "chapters/26-authn.typ",
  "authz": "chapters/27-authz.typ",
  "store": "chapters/28-store.typ",
  "conc": "chapters/29-conc.typ",
  "cache": "chapters/30-cache.typ",
  "limit": "chapters/31-limit.typ",
  "obs": "chapters/32-obs.typ",
  "load": "chapters/33-load.typ",
  "shipit": "chapters/34-shipit.typ",
  "suite": "chapters/35-suite.typ",
  "typed": "chapters/36-typed.typ",
  "typedsuite": "chapters/37-typed-suite.typ",
  "capstone": "chapters/38-capstone.typ",
  "appendices": "chapters/39-appendices.typ",
)

#book(jsbook.meta, {
  for ch in jsbook.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
