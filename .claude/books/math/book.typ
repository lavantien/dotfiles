// book 7: written map is complete from the scaffold, chapters land as
// overwrites of their stub files wave by wave
#import "../theme/lib.typ": book
#import "manifest.typ": mathbook

#let written = (
  "float": "chapters/01-float.typ",
  "error": "chapters/02-error.typ",
  "trig": "chapters/03-trig.typ",
  "coordgeo": "chapters/04-coordgeo.typ",
  "vectors": "chapters/05-vectors.typ",
  "matrices": "chapters/06-matrices.typ",
  "inner": "chapters/07-inner.typ",
  "decomp": "chapters/08-decomp.typ",
  "univariate": "chapters/09-univariate.typ",
  "multivariate": "chapters/10-multivariate.typ",
  "optimization": "chapters/11-optimization.typ",
  "autodiff": "chapters/12-autodiff.typ",
  "proof": "chapters/13-proof.typ",
  "combinatorics": "chapters/14-combinatorics.typ",
  "graphs": "chapters/15-graphs.typ",
  "groups": "chapters/16-groups.typ",
  "actions": "chapters/17-actions.typ",
  "probability": "chapters/18-probability.typ",
  "statistics": "chapters/19-statistics.typ",
  "roots": "chapters/20-roots.typ",
  "interp": "chapters/21-interp.typ",
  "quadrature": "chapters/22-quadrature.typ",
  "iterative": "chapters/23-iterative.typ",
  "strategic": "chapters/24-strategic.typ",
  "sequential": "chapters/25-sequential.typ",
  "adt": "chapters/26-adt.typ",
  "railway": "chapters/27-railway.typ",
  "monads": "chapters/28-monads.typ",
  "pipeline": "chapters/29-pipeline.typ",
  "capstone-design": "chapters/30-capstone-design.typ",
  "capstone-impl": "chapters/31-capstone-impl.typ",
  "capstone-verify": "chapters/32-capstone-verify.typ",
  "appendices": "chapters/33-appendices.typ",
)

#book(mathbook.meta, {
  for ch in mathbook.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
