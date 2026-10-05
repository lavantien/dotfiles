// book 8: all chapters written, the written map is complete
#import "../theme/lib.typ": book
#import "manifest.typ": luabook

#let written = (
  "toolchain": "chapters/01-toolchain.typ",
  "lexical": "chapters/02-lexical.typ",
  "values": "chapters/03-values.typ",
  "expressions": "chapters/04-expressions.typ",
  "statements": "chapters/05-statements.typ",
  "functions": "chapters/06-functions.typ",
  "coroutines": "chapters/07-coroutines.typ",
  "environments": "chapters/08-environments.typ",
  "collector": "chapters/09-collector.typ",
  "profiling": "chapters/10-profiling.typ",
  "stdlib1": "chapters/11-stdlib1.typ",
  "stdlib2": "chapters/12-stdlib2.typ",
  "stdlib3": "chapters/13-stdlib3.typ",
  "capi": "chapters/14-capi.typ",
  "incompat": "chapters/15-incompat.typ",
  "idioms": "chapters/16-idioms.typ",
  "ffi": "chapters/17-ffi.typ",
  "allegro": "chapters/18-allegro.typ",
  "kernel": "chapters/19-http-kernel.typ",
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
  "shipping": "chapters/30-shipping.typ",
  "suite": "chapters/31-suite.typ",
  "capstone": "chapters/32-capstone.typ",
  "appendices": "chapters/33-appendices.typ",
)

#book(luabook.meta, {
  for ch in luabook.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
