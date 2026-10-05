// book 5: written chapters are included, the rest render as stubs until authored
#import "../theme/lib.typ": book
#import "manifest.typ": csharpnet

#let written = (
  "toolchain": "chapters/01-toolchain.typ",
  "lexical": "chapters/02-lexical.typ",
  "typesystem": "chapters/03-typesystem.typ",
  "members": "chapters/04-members.typ",
  "generics": "chapters/05-generics.typ",
  "patterns": "chapters/06-patterns.typ",
  "delegates": "chapters/07-delegates.typ",
  "exceptions": "chapters/08-exceptions.typ",
  "async": "chapters/09-async.typ",
  "memory": "chapters/10-memory.typ",
  "allocation": "chapters/11-allocation.typ",
  "profilers": "chapters/12-profilers.typ",
  "reflection": "chapters/13-reflection.typ",
  "linq": "chapters/14-linq.typ",
  "stdlib1": "chapters/15-stdlib1.typ",
  "stdlib2": "chapters/16-stdlib2.typ",
  "idioms": "chapters/17-idioms.typ",
  "functional": "chapters/18-functional.typ",
  "fsharp-language": "chapters/19-fsharp-language.typ",
  "fsharp-pipeline": "chapters/20-fsharp-pipeline.typ",
  "fsharp-dotnet": "chapters/21-fsharp-dotnet.typ",
  "api-kernel": "chapters/22-api-kernel.typ",
  "middleware": "chapters/23-middleware.typ",
  "users": "chapters/24-users.typ",
  "authn": "chapters/25-authn.typ",
  "authz": "chapters/26-authz.typ",
  "store": "chapters/27-store.typ",
  "conc": "chapters/28-conc.typ",
  "cache": "chapters/29-cache.typ",
  "limit": "chapters/30-limit.typ",
  "obs": "chapters/31-obs.typ",
  "load": "chapters/32-load.typ",
  "shipit": "chapters/33-shipit.typ",
  "suite": "chapters/34-suite.typ",
  "capstone": "chapters/35-capstone.typ",
  "appendices": "chapters/36-appendices.typ",
)

#book(csharpnet.meta, {
  for ch in csharpnet.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
