// book 13: written map grows chapter by chapter
#import "../theme/lib.typ": book
#import "manifest.typ": gamesystems

#let written = (
  "gameloop": "chapters/01-gameloop.typ",
  "ecstheory": "chapters/02-ecstheory.typ",
  "ecsimpl": "chapters/03-ecsimpl.typ",
  "dod": "chapters/04-dod.typ",
  "fsm": "chapters/05-fsm.typ",
  "behavior": "chapters/06-behavior.typ",
  "math": "chapters/07-math.typ",
  "physics": "chapters/08-physics.typ",
  "terrain": "chapters/09-terrain.typ",
  "turns": "chapters/10-turns.typ",
  "randomness": "chapters/11-randomness.typ",
  "serialization": "chapters/12-serialization.typ",
  "testing": "chapters/13-testing.typ",
  "characters": "chapters/14-characters.typ",
  "items": "chapters/15-items.typ",
  "pets": "chapters/16-pets.typ",
  "expeditions": "chapters/17-expeditions.typ",
  "scripting": "chapters/18-scripting.typ",
  "capstone1": "chapters/19-capstone1.typ",
  "capstone2": "chapters/20-capstone2.typ",
  "capstone3": "chapters/21-capstone3.typ",
  "capstone4": "chapters/22-capstone4.typ",
  "appendices": "chapters/23-appendices.typ",
)

#book(gamesystems.meta, {
  for ch in gamesystems.chapters {
    let file = written.at(ch.id, default: none)
    if file != none {
      include file
    } else {
      heading(level: 1)[#ch.title]
      text(fill: luma(120))[in preparation, chapter id: #ch.id]
    }
  }
})
