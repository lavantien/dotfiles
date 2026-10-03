// book 5: written map grows chapter by chapter
#import "../theme/lib.typ": book
#import "manifest.typ": pybook

#let written = (
  "toolchain": "chapters/01-toolchain.typ",
  "lexical": "chapters/02-lexical.typ",
  "objects": "chapters/03-objects.typ",
  "collections": "chapters/04-collections.typ",
  "strings": "chapters/05-strings.typ",
  "functions": "chapters/06-functions.typ",
  "classes": "chapters/07-classes.typ",
  "typing": "chapters/08-typing.typ",
  "dataclasses": "chapters/09-dataclasses.typ",
  "exceptions": "chapters/10-exceptions.typ",
  "modules": "chapters/11-modules.typ",
  "interpreter": "chapters/12-interpreter.typ",
  "pymalloc": "chapters/13-pymalloc.typ",
  "profiling": "chapters/14-profiling.typ",
  "files": "chapters/15-files.typ",
  "processes": "chapters/16-processes.typ",
  "threads": "chapters/17-threads.typ",
  "multiprocessing": "chapters/18-multiprocessing.typ",
  "plumbing": "chapters/19-plumbing.typ",
  "testing": "chapters/20-testing.typ",
  "fastapi": "chapters/22-fastapi.typ",
  "asyncio": "chapters/21-asyncio.typ",
  "numerics": "chapters/23-numerics.typ",
  "numpy": "chapters/24-numpy.typ",
  "pandas": "chapters/25-pandas.typ",
  "pydantic": "chapters/26-pydantic.typ",
  "http-kernel": "chapters/27-http-kernel.typ",
  "middleware": "chapters/28-middleware.typ",
  "users": "chapters/29-users.typ",
  "authn": "chapters/30-authn.typ",
  "authz": "chapters/31-authz.typ",
  "store": "chapters/32-store.typ",
  "conc": "chapters/33-conc.typ",
  "cache": "chapters/34-cache.typ",
  "limit": "chapters/35-limit.typ",
  "obs": "chapters/36-obs.typ",
  "load": "chapters/37-load.typ",
  "shipit": "chapters/38-shipit.typ",
  "suite": "chapters/39-suite.typ",
  "capstone1": "chapters/40-capstone1.typ",
  "capstone2": "chapters/41-capstone2.typ",
  "appendices": "chapters/42-appendices.typ",
)

#book(pybook.meta, {
  for ch in pybook.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
