// book 9: all 44 chapters registered, the metaheuristics and approximation ids land their prose this wave
#import "../theme/lib.typ": book
#import "manifest.typ": dsabook

#let written = (
  "analysis": "chapters/01-analysis.typ",
  "arrays": "chapters/02-arrays.typ",
  "dynamicarrays": "chapters/03-dynamicarrays.typ",
  "linked": "chapters/04-linked.typ",
  "stacksqueues": "chapters/05-stacksqueues.typ",
  "hashing": "chapters/06-hashing.typ",
  "trees": "chapters/07-trees.typ",
  "heaps": "chapters/08-heaps.typ",
  "tries": "chapters/09-tries.typ",
  "graphs": "chapters/10-graphs.typ",
  "shortestpaths": "chapters/11-shortestpaths.typ",
  "mstflows": "chapters/12-mstflows.typ",
  "sorting": "chapters/13-sorting.typ",
  "searching": "chapters/14-searching.typ",
  "stringmatching": "chapters/15-stringmatching.typ",
  "numtheory": "chapters/16-numtheory.typ",
  "dp": "chapters/17-dp.typ",
  "greedy": "chapters/18-greedy.typ",
  "advdp": "chapters/19-advdp.typ",
  "pruning": "chapters/20-pruning.typ",
  "ranges": "chapters/21-ranges.typ",
  "compression": "chapters/22-compression.typ",
  "geometry": "chapters/23-geometry.typ",
  "lattice": "chapters/24-lattice.typ",
  "practical": "chapters/25-practical.typ",
  "parsing": "chapters/26-parsing.typ",
  "interpreter": "chapters/27-interpreter.typ",
  "numtheory2": "chapters/28-numtheory2.typ",
  "fastarith": "chapters/29-fastarith.typ",
  "balanced": "chapters/30-balanced.typ",
  "blocks": "chapters/31-blocks.typ",
  "advdp2": "chapters/32-advdp2.typ",
  "strings2": "chapters/33-strings2.typ",
  "linalg": "chapters/34-linalg.typ",
  "combinatorics": "chapters/35-combinatorics.typ",
  "numerical": "chapters/36-numerical.typ",
  "geometry2": "chapters/37-geometry2.typ",
  "flows2": "chapters/38-flows2.typ",
  "connectivity": "chapters/39-connectivity.typ",
  "games": "chapters/40-games.typ",
  "metaheuristics": "chapters/41-metaheuristics.typ",
  "approximation": "chapters/42-approximation.typ",
  "capstone": "chapters/43-capstone.typ",
  "appendices": "chapters/44-appendices.typ",
)

#book(dsabook.meta, {
  for ch in dsabook.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
