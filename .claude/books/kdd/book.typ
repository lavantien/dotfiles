// book 8: written map is complete from the scaffold, chapters land as
// overwrites of their stub files wave by wave
#import "../theme/lib.typ": book
#import "manifest.typ": kddbook

#let written = (
  "process": "chapters/01-process.typ",
  "cleaning": "chapters/02-cleaning.typ",
  "binning": "chapters/03-binning.typ",
  "normalize": "chapters/04-normalize.typ",
  "distance": "chapters/05-distance.typ",
  "similarity": "chapters/06-similarity.typ",
  "sampling": "chapters/07-sampling.typ",
  "features": "chapters/08-features.typ",
  "pca": "chapters/09-pca.typ",
  "wavelet": "chapters/10-wavelet.typ",
  "olap": "chapters/11-olap.typ",
  "regression": "chapters/12-regression.typ",
  "id3": "chapters/13-id3.typ",
  "cart": "chapters/14-cart.typ",
  "rules": "chapters/15-rules.typ",
  "pruning": "chapters/16-pruning.typ",
  "evaluation": "chapters/17-evaluation.typ",
  "roc": "chapters/18-roc.typ",
  "bayes": "chapters/19-bayes.typ",
  "knn": "chapters/20-knn.typ",
  "ann": "chapters/21-ann.typ",
  "svm": "chapters/22-svm.typ",
  "ensembles": "chapters/23-ensembles.typ",
  "imbalance": "chapters/24-imbalance.typ",
  "apriori": "chapters/25-apriori.typ",
  "vector": "chapters/26-vector.typ",
  "maximal": "chapters/27-maximal.typ",
  "fpgrowth": "chapters/28-fpgrowth.typ",
  "interesting": "chapters/29-interesting.typ",
  "sequential": "chapters/30-sequential.typ",
  "kmeans": "chapters/31-kmeans.typ",
  "hierarchical": "chapters/32-hierarchical.typ",
  "dbscan": "chapters/33-dbscan.typ",
  "validation": "chapters/34-validation.typ",
  "cure": "chapters/35-cure.typ",
  "spectral": "chapters/36-spectral.typ",
  "anomaly": "chapters/37-anomaly.typ",
  "lof": "chapters/38-lof.typ",
  "hypothesis": "chapters/39-hypothesis.typ",
  "fdr": "chapters/40-fdr.typ",
  "rough": "chapters/41-rough.typ",
  "reducts": "chapters/42-reducts.typ",
  "discernibility": "chapters/43-discernibility.typ",
  "som": "chapters/44-som.typ",
  "somanalysis": "chapters/45-somanalysis.typ",
  "somvariants": "chapters/46-somvariants.typ",
  "bridge": "chapters/47-bridge.typ",
  "capstone": "chapters/48-capstone.typ",
)

#book(kddbook.meta, {
  for ch in kddbook.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
