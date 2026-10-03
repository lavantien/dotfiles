// book 10: all fourteen chapters written; the six finals years landed in wave 3
#import "../theme/lib.typ": book
#import "manifest.typ": icpc

#let written = (
  "contest": "chapters/01-contest.typ",
  "toolbox-c": "chapters/02-toolbox-c.typ",
  "toolbox-cs": "chapters/03-toolbox-cs.typ",
  "toolbox-go": "chapters/04-toolbox-go.typ",
  "toolbox-js": "chapters/05-toolbox-js.typ",
  "toolbox-py": "chapters/06-toolbox-py.typ",
  "toolbox-lua": "chapters/07-toolbox-lua.typ",
  "y2017": "chapters/08-y2017.typ",
  "y2018": "chapters/09-y2018.typ",
  "y2019": "chapters/10-y2019.typ",
  "y2022": "chapters/11-y2022.typ",
  "y2023": "chapters/12-y2023.typ",
  "y2025": "chapters/13-y2025.typ",
  "fastarith": "chapters/14-fastarith.typ",
)

#book(icpc.meta, {
  for ch in icpc.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
