// book 16: written map grows chapter by chapter
#import "../theme/lib.typ": book
#import "manifest.typ": repertoire

#let written = (
  "landscape": "chapters/01-landscape.typ",
  "paradigms": "chapters/02-paradigms.typ",
  "datastructures": "chapters/03-datastructures.typ",
  "graphs": "chapters/04-graphs.typ",
  "classics1": "chapters/05-classics1.typ",
  "classics2": "chapters/06-classics2.typ",
  "js-core": "chapters/07-js-core.typ",
  "js-dom": "chapters/08-js-dom.typ",
  "js-fromscratch": "chapters/09-js-fromscratch.typ",
  "js-data": "chapters/10-js-data.typ",
  "react-core": "chapters/11-react-core.typ",
  "react-hooks": "chapters/12-react-hooks.typ",
  "react-state": "chapters/13-react-state.typ",
  "react-build": "chapters/14-react-build.typ",
  "go-runtime": "chapters/15-go-runtime.typ",
  "go-testing": "chapters/16-go-testing.typ",
  "db-answers": "chapters/17-db-answers.typ",
  "network-answers": "chapters/18-network-answers.typ",
  "design-answers": "chapters/19-design-answers.typ",
  "go-build1": "chapters/20-go-build1.typ",
  "go-build2": "chapters/21-go-build2.typ",
  "go-streaming": "chapters/22-go-streaming.typ",
  "algopatterns": "chapters/23-algopatterns.typ",
  "weightedgraphs": "chapters/24-weightedgraphs.typ",
  "distributed-answers": "chapters/25-distributed-answers.typ",
  "systems-answers": "chapters/26-systems-answers.typ",
  "math-answers": "chapters/27-math-answers.typ",
  "mining-answers": "chapters/28-mining-answers.typ",
  "python-answers": "chapters/29-python-answers.typ",
  "lua-answers": "chapters/30-lua-answers.typ",
  "csharp-answers": "chapters/31-csharp-answers.typ",
  "css-answers": "chapters/32-css-answers.typ",
  "rendering-answers": "chapters/33-rendering-answers.typ",
  "security-answers": "chapters/34-security-answers.typ",
  "estimation-answers": "chapters/35-estimation-answers.typ",
  "design-prompts": "chapters/36-design-prompts.typ",
  "behavioral-answers": "chapters/37-behavioral-answers.typ",
  "observed-answers": "chapters/38-observed-answers.typ",
  "negotiation-answers": "chapters/39-negotiation-answers.typ",
  "transfer-answers": "chapters/40-transfer-answers.typ",
  "appendices": "chapters/41-appendices.typ",
)

#book(repertoire.meta, {
  for ch in repertoire.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
