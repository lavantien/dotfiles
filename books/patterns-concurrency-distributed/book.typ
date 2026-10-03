// book 11: all chapters written, the written map is complete
#import "../theme/lib.typ": book
#import "manifest.typ": patterns

#let written = (
  "discipline": "chapters/01-discipline.typ",
  "creational": "chapters/02-creational.typ",
  "structural": "chapters/03-structural.typ",
  "behavioral": "chapters/04-behavioral.typ",
  "functional": "chapters/05-functional.typ",
  "concfundamentals": "chapters/06-concfundamentals.typ",
  "sync": "chapters/07-sync.typ",
  "concpatterns": "chapters/08-concpatterns.typ",
  "hazards": "chapters/09-hazards.typ",
  "distributed": "chapters/10-distributed.typ",
  "consensus": "chapters/11-consensus.typ",
  "partitioning": "chapters/12-partitioning.typ",
  "messaging": "chapters/13-messaging.typ",
  "observability": "chapters/14-observability.typ",
  "resilience": "chapters/15-resilience.typ",
  "capstone": "chapters/16-capstone.typ",
  "appendices": "chapters/17-appendices.typ",
)

#book(patterns.meta, {
  for ch in patterns.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
