// book 3: written chapters are included, the rest render as stubs until authored
#import "../theme/lib.typ": book
#import "manifest.typ": gobook

#let written = (
  "toolchain": "chapters/01-toolchain.typ",
  "lexical": "chapters/02-lexical.typ",
  "types": "chapters/03-types.typ",
  "generics": "chapters/04-generics.typ",
  "functions": "chapters/05-functions.typ",
  "concurrency": "chapters/06-concurrency.typ",
  "errors": "chapters/07-errors.typ",
  "structure": "chapters/08-structure.typ",
  "runtime": "chapters/09-runtime.typ",
  "allocation": "chapters/10-allocation.typ",
  "profiling": "chapters/11-profiling.typ",
  "stdlib1": "chapters/12-stdlib1.typ",
  "stdlib2": "chapters/13-stdlib2.typ",
  "testing": "chapters/14-testing.typ",
  "idioms": "chapters/15-idioms.typ",
  "htmx": "chapters/16-htmx.typ",
  "templ": "chapters/17-templ.typ",
  "httpkernel": "chapters/18-httpkernel.typ",
  "middleware": "chapters/19-middleware.typ",
  "users": "chapters/20-users.typ",
  "authn": "chapters/21-authn.typ",
  "authz": "chapters/22-authz.typ",
  "store": "chapters/23-store.typ",
  "conc": "chapters/24-conc.typ",
  "cache": "chapters/25-cache.typ",
  "limit": "chapters/26-limit.typ",
  "obs": "chapters/27-obs.typ",
  "load": "chapters/28-load.typ",
  "shipit": "chapters/29-shipit.typ",
  "suite": "chapters/30-suite.typ",
  "numstats": "chapters/31-numstats.typ",
  "fitting": "chapters/32-fitting.typ",
  "enginetwin": "chapters/33-enginetwin.typ",
  "capstone": "chapters/34-capstone.typ",
  "appendices": "chapters/35-appendices.typ",
)

#book(gobook.meta, {
  for ch in gobook.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
