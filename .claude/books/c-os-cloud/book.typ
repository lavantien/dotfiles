// book 1: chapters land one per commit, the written map grows with them
#import "../theme/lib.typ": book
#import "manifest.typ": cosbook

#let written = (
  "toolchain": "chapters/01-toolchain.typ",
  "lexical": "chapters/02-lexical.typ",
  "types": "chapters/03-types.typ",
  "pointers": "chapters/04-pointers.typ",
  "machine": "chapters/05-machine.typ",
  "stdlib": "chapters/06-stdlib.typ",
  "llvm": "chapters/07-llvm.typ",
  "ir": "chapters/08-ir.typ",
  "opt": "chapters/09-opt.typ",
  "tooling": "chapters/10-tooling.typ",
  "processes": "chapters/11-processes.typ",
  "virtualmemory": "chapters/12-virtualmemory.typ",
  "caches": "chapters/13-caches.typ",
  "heap": "chapters/14-heap.typ",
  "threads": "chapters/15-threads.typ",
  "atomics": "chapters/16-atomics.typ",
  "scheduling": "chapters/17-scheduling.typ",
  "async": "chapters/18-async.typ",
  "allocators": "chapters/19-allocators.typ",
  "measurement": "chapters/20-measurement.typ",
  "capstone": "chapters/21-capstone.typ",
  "cloudmodel": "chapters/22-cloudmodel.typ",
  "terraform": "chapters/23-terraform.typ",
  "modules": "chapters/24-modules.typ",
  "aws": "chapters/25-aws.typ",
  "gcp": "chapters/26-gcp.typ",
  "multicloud": "chapters/27-multicloud.typ",
  "http-kernel": "chapters/28-http-kernel.typ",
  "middleware": "chapters/29-middleware.typ",
  "users": "chapters/30-users.typ",
  "authn": "chapters/31-authn.typ",
  "authz": "chapters/32-authz.typ",
  "store": "chapters/33-store.typ",
  "conc": "chapters/34-conc.typ",
  "cache": "chapters/35-cache.typ",
  "limit": "chapters/36-limit.typ",
  "obs": "chapters/37-obs.typ",
  "load": "chapters/38-load.typ",
  "ship": "chapters/39-ship.typ",
  "suite": "chapters/40-suite.typ",
  "appendices": "chapters/41-appendices.typ",
)

#book(cosbook.meta, {
  for ch in cosbook.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
