// book 3: written chapters are included, the rest render as stubs until authored
#import "../theme/lib.typ": book
#import "manifest.typ": rustbook

#let written = (
  "toolchain": "chapters/01-toolchain.typ",
  "editions": "chapters/02-editions.typ",
  "lexical": "chapters/03-lexical.typ",
  "types": "chapters/04-types.typ",
  "ownership": "chapters/05-ownership.typ",
  "borrowing": "chapters/06-borrowing.typ",
  "adts": "chapters/07-adts.typ",
  "traits": "chapters/08-traits.typ",
  "generics-macros": "chapters/09-generics-macros.typ",
  "closures-iterators": "chapters/10-closures-iterators.typ",
  "errors": "chapters/11-errors.typ",
  "memory": "chapters/12-memory.typ",
  "concurrency": "chapters/13-concurrency.typ",
  "async": "chapters/14-async.typ",
  "stdlib": "chapters/15-stdlib.typ",
  "crates": "chapters/16-crates.typ",
  "unsafe": "chapters/17-unsafe.typ",
  "testing": "chapters/18-testing.typ",
  "httpkernel": "chapters/19-httpkernel.typ",
  "middleware": "chapters/20-middleware.typ",
  "users": "chapters/21-users.typ",
  "authn": "chapters/22-authn.typ",
  "authz": "chapters/23-authz.typ",
  "store": "chapters/24-store.typ",
  "conc": "chapters/25-conc.typ",
  "cache": "chapters/26-cache.typ",
  "limit": "chapters/27-limit.typ",
  "obs": "chapters/28-obs.typ",
  "load": "chapters/29-load.typ",
  "shipit": "chapters/30-shipit.typ",
  "suite": "chapters/31-suite.typ",
  "capstone": "chapters/32-capstone.typ",
  "appendices": "chapters/33-appendices.typ",
)

#book(rustbook.meta, {
  for ch in rustbook.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
