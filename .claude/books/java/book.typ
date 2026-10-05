// book 4: written chapters are included, the rest render as stubs until authored
#import "../theme/lib.typ": book
#import "manifest.typ": javabook

#let written = (
  "toolchain": "chapters/01-toolchain.typ",
  "ladder": "chapters/02-ladder.typ",
  "lexical": "chapters/03-lexical.typ",
  "types": "chapters/04-types.typ",
  "classes": "chapters/05-classes.typ",
  "generics": "chapters/06-generics.typ",
  "enums": "chapters/07-enums.typ",
  "functional": "chapters/08-functional.typ",
  "patterns": "chapters/09-patterns.typ",
  "concurrency": "chapters/10-concurrency.typ",
  "runtime": "chapters/11-runtime.typ",
  "collections": "chapters/12-collections.typ",
  "formats": "chapters/13-formats.typ",
  "io": "chapters/14-io.typ",
  "modules": "chapters/15-modules.typ",
  "reflection": "chapters/16-reflection.typ",
  "security": "chapters/17-security.typ",
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

#book(javabook.meta, {
  for ch in javabook.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
