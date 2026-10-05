#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= capstone part 3: the playable mvp

Parts 1 and 2 left the game complete, deterministic, and invisible.
This part makes it playable: a window through the KNI framework you
drive with keyboard and mouse, home hub to battle to reward, and the
thin htmx companion beside it. Both frontends obey the one rule that
keeps them thin, they hold no game logic: every keystroke, click, and
post translates into a campaign call, every pixel and tag comes from
the render model or a state fragment.

== kni, taught before used

KNI is a cross platform c\# game framework, a fork of MonoGame that
keeps the XNA surface, `Game`, `GraphicsDeviceManager`, `SpriteBatch`,
`Vector2`, and adds backends from Windows DirectX 11 through desktop
OpenGL to the browser over Blazor and WebGL. Everything asserted here
was verified against release 4.3.9001 on .NET 10, in this repository,
including one fact the first build missed.

The shape that matters is the `Game` lifecycle chapter 1 described in
the abstract: subclass `Game`, a `GraphicsDeviceManager` owns the
window and device, the framework calls `Update` zero or more times
then `Draw` exactly once per frame, driven by `IsFixedTimeStep` and
`TargetElapsedTime`, which this renderer sets to a sixty hertz fixed
step. Drawing goes through a `SpriteBatch`, and the honest shape
primitive is a one pixel white `Texture2D` stretched into every
rectangle. No content pipeline and no asset files: shapes are that
pixel, and the one asset-adjacent thing, the font, is a vendored ttf
rasterized at runtime, the next section.

#diagram([the kni Game contract stacked, who owns what each frame], length: 13pt, {
  let rows = (
    ([subclass Game], luma(205)),
    ([GraphicsDeviceManager owns#linebreak()the window and the device], luma(235)),
    ([Update: zero or more,#linebreak()driven by IsFixedTimeStep], luma(235)),
    ([Draw: exactly once per frame], luma(235)),
    ([SpriteBatch: one white pixel#linebreak()stretched into every shape], luma(235)),
  )
  for i in range(rows.len()) {
    let (t, f) = rows.at(i)
    let y = 8.4 - i * 2.3
    cdraw.rect((3, y), (21, y + 2.1), fill: f, radius: 0.02)
    cdraw.content((12, y + 1.05), t, size: 6pt)
  }
  cdraw.content((12, -1.7), [fixed step at sixty hertz], size: 6pt)
  cdraw.content((12, -2.8), [no content pipeline, the ttf one embedded resource], size: 6pt)
})

Onboarding is two facts and one trap. Fact one, the `PackageReference`
`nkast.Kni.Platform.WinForms.DX11` 4.3.9001 pulls the framework and
the DirectX backend. Fact two, the target framework must be
`net10.0-windows`, because the platform package ships its windows
backends under windows tfms only: a plain `net10.0` target restores
the framework references, compiles clean, and then dies at startup
inside `GameFactory` because the platform assembly that registers it
was never copied to the output. That trap was found by running, not
by building, and the csproj comment in this repository now pins it.

== the runtime font

#listing("game-systems/capstone/src/renderer/Font.cs", first: 8, last: 40, caption: [three tiers in final pixels, one font system loaded from the embedded ttf])

#listing("game-systems/capstone/src/renderer/Font.cs", first: 42, last: 67, caption: [one draw call per text, the legacy pixel-and-scale signature mapped onto the tiers])

Still no content pipeline, but there is a font now. The repo already
vendors the Iosevka Term Nerd Font ttfs for the pdf theme, and the
renderer embeds the regular cut, 13,230,756 bytes, straight from
`fonts/` as a resource, five directories up in the csproj with a
`Link` and nothing copied to the output. Rasterization is runtime
work through FontStashSharp.Kni 1.6.1 from nuget: `Load` from
`LoadContent` builds one `FontSystem` and feeds it the embedded
stream, and from then on a size is a dynamic sprite font whose glyphs
rasterize into atlas textures on first use, the atlas binding itself
to the drawing batch's device. The old 5x7 bitmap could not be made
bigger or given lowercase without hand-drawing hundreds of glyphs,
and the ttf gives both for free.

Three sizes cover every screen, named tiers in final pixels at the
1080p window: caption 18 for panel furniture, body 24 for rows and
hud lines, title 44 for headings. The layout grid scales at
`ViewBox.Scale`, 1080 over 400, so 2, and the tiers were pitched
against that grid in a re-spacing pass over the screens. Lowercase
renders now, and each call site chooses its own casing instead of a
forced `ToUpperInvariant` at the font. A compatibility overload keeps
the old pixel-and-scale signature compiling, 1 reading as body and 2
and up as title, and four call sites still ride it. Fixed sizes and
a fixed draw sequence make the StbTrueTypeSharp rasterization
deterministic, and the golden walkthrough in the last section
asserts it the blunt way, two captures of the same beat in two
processes demanding byte-identical pngs.

#diagram([the runtime font: one embedded ttf, glyphs rasterized on demand into atlas pages], length: 13pt, {
  let rows = (
    ([fonts/IosevkaTermNerdFont-Regular.ttf,#linebreak()embedded as a resource, never copied to the output], luma(205)),
    ([FontSystem.AddFont from LoadContent,#linebreak()one system for the game's life], luma(235)),
    ([a tier asks for a size, glyphs rasterize#linebreak()into atlas textures on first use], luma(235)),
    ([SpriteBatch draws the atlas pages,#linebreak()caption 18, body 24, title 44], luma(235)),
  )
  for i in range(rows.len()) {
    let (t, f) = rows.at(i)
    let y = 7.2 - i * 1.9
    cdraw.rect((3, y), (21, y + 1.7), fill: f, radius: 0.02)
    cdraw.content((12, y + 0.85), t, size: 6pt)
  }
  cdraw.content((12, -0.8), [no content pipeline, no output files], size: 6pt)
  cdraw.content((12, -1.9), [deterministic: fixed size, fixed draw order], size: 6pt)
})

== the screens and the input

#flow(
  [the screen router, the hub feeds every screen and every screen walks home],
  node((0, 0), [home]),
  node((3.2, 0), [sheet, bag, shop]),
  node((3.2, -2.2), [expedition board]),
  node((6.8, -1.1), [battle]),
  node((9.6, -1.1), [reward]),
  edge((0, 0), (3.2, 0), "-|>"),
  edge((3.2, 0), (3.2, -2.2), "-|>"),
  edge((3.2, -2.2), (6.8, -1.1), "-|>", label: [start]),
  edge((3.2, 0), (6.8, -1.1), "-|>", label: [sandbox]),
  edge((6.8, -1.1), (9.6, -1.1), "-|>", label: [over]),
  edge((9.6, -1.1), (0, 0), "-|>", bend: -35deg, label: [enter]),
)

The home hub is a static map with three doors, the sandbox range, the
expedition board, and the shop: clicks and the 1 to 3 keys route, and
the screen owns nothing but the routing. The board lists each
expedition's stages under its name, the boss stage marked and last,
locked or cleared. The unified sheet carries three tabs, character,
pet, crafting: the paper doll wears all 14 slots around the wearer
holding the equipped weapon, the level and xp bar above, the power
number under the hands, and the full stat grid below, stamina, armor,
health, mana, the four elemental damages, the four resistances, and
the four primaries. Beside the doll sits the bag, pages of 16x16
cells at 64 pixels, one item per cell, arrows walking the cursor, q
and e turning pages, r sorting stacks, enter equipping. The crafting
tab is the diamond bench, each level costs 2 to the n diamonds and
compounds every stat on the item, with the material slots strip
under it. In battle a and d walk the terrain on stamina, w and s aim,
1 through 4 switch the element, space charges and releases, e fires
the pet's recommended active, the same choice the pet brain of
chapter 18 makes, i opens the sheet over the fight, t arms the
paper plane and a minimap click flies it, b toggles the aim bot's
dotted arc drawn through the live wind. The window opens at 1920x1080
and every hud element scales with it: run it with `dotnet run
--project books/game-systems/capstone/src/renderer`, escape leaves
the home.

#figure(
  kind: image,
  supplement: [figure],
  caption: [the unified sheet as the exe captures it, the paper doll, the power number, and the bag beside it],
  image("/game-systems/figures/mvp-sheet.png", width: 100%),
)

#figure(
  kind: image,
  supplement: [figure],
  caption: [the home hub as the exe captures it, three doors on a static map, the purse and power on the header],
  image("/game-systems/figures/mvp-home.png", width: 100%),
)

The exe also produces frames without a player: `--screenshot
<scene> --out frame.png` drives the same seed 42 profile to that
scene, captures the backbuffer once the batch ends, writes the png,
and exits 0. The script behind a scene steps once per drawn frame,
so the launch burst of catch-up updates cannot shift it and the same
scene writes the same frame bytes on every run. A scene that never
arrives trips a tick guard and exits 1, a bad flag exits 2 with the
scene list in the message, and the smoke suite runs all of those
cases, so a renderer that compiles but cannot actually run fails
`dotnet test`. `make screenshots` wraps the same flag: it asks the
exe's usage error for the scene list, captures every scene plus the
web companion into `output/screenshots`, and fails if any frame is
missing or malformed.

#figure(
  kind: image,
  supplement: [figure],
  caption: [the battle scene as the exe captures it, humanoids holding their elements, the minimap top right, the aim bot armed],
  image("/game-systems/figures/mvp-aimbot.png", width: 100%),
)

== htmx, taught before used

The web companion is the same campaign served as html fragments.
htmx 4 is the hypermedia approach: the server owns the markup, small
attributes on ordinary html elements declare that this element
fetches and swaps, and no application javascript is written. The 4.0
release replaced the transport with `fetch()`, made attribute
inheritance explicit opt-in, and renamed events to
`htmx:phase:action`, but the surface this chapter uses is the same
as 2.x: `hx-get`, `hx-post`, `hx-trigger`, `hx-target`, `hx-swap`.

The vendoring recipe is book 9's, reused exactly. The `next`-tagged
npm package `htmx.org@4.0.0` ships `dist/htmx.min.js`, 36,716
bytes, its SHA-384 digest matches the published SRI value byte for
byte, and the file lives in the project's `wwwroot/js` with the
integrity attribute in the script tag. The web test downloads it
through the running app and recomputes the digest, so a corrupted or
half-updated vendor file fails the suite instead of the page.

#diagram([the htmx contract: the server owns markup, elements fetch and swap], length: 13pt, {
  let rows = (
    ([the server owns the markup], luma(205)),
    ([hx-get, hx-post: an element fetches], luma(235)),
    ([hx-trigger, hx-target, hx-swap: it swaps in place], luma(235)),
    ([no application javascript written], luma(235)),
  )
  for i in range(rows.len()) {
    let (t, f) = rows.at(i)
    let y = 6.4 - i * 1.2
    cdraw.rect((4, y), (20, y + 1.0), fill: f, radius: 0.02)
    cdraw.content((12, y + 0.5), t, size: 6pt)
  }
  cdraw.content((12, 0.5), [vendored htmx 4.0, 36,716 bytes, digest pinned], size: 6pt)
  cdraw.content((12, -0.6), [the web test recomputes the digest], size: 6pt)
})

== the thin companion

#listing("game-systems/capstone/src/web/Program.cs", first: 19, last: 50, caption: [one post advances one turn, a finished battle opens the next stage])

The page polls `/api/state` every two seconds and the fire button
posts to `/api/fire`, both swapping the same fragment div, and that
is the entire client. The fragment carries the battle, the health
bars, and one compact sheet line, level, weapon, pet, power, gold,
diamonds. The replay link serves the battle's v3 file as base64,
decodable by `ReplayV3` and replayable by any campaign with the same
binary.

#figure(
  kind: image,
  supplement: [figure],
  caption: [the companion in a browser, one fire click into stage 1],
  image("/game-systems/figures/web-companion.png", width: 100%),
)

#callout("note", "two frontends, one truth", [
  The window and the page run the same campaign core and agree
  because neither owns state: the window translates keys and clicks
  into campaign calls and reads the render model, the page translates
  posts into the same calls and renders fragments. The determinism
  suite is what lets both exist without drifting.
])

== the golden run

The last walk is the golden run: one campaign on the seed 42 profile
played start to finish through public calls only, both expeditions
cleared boss by boss, then the shop, the equip, and the bench, with
the purse asserted at every step. The renderer ships the walk as
twelve beats, five from the first fight of expedition 1 and seven
from the economy run after it, each a fresh process walking to its
beat with real campaign calls and capturing one frame. The economy
math it pins: the starter purse is 100 gold, the six battles of the
two passes pay at least 15 + 15 + 40 gold twice, so 240 at worst, and
the hat at 40 plus the egg at 100 always fit. Diamonds: two boss
wins pay 8, two weapon levels cost 2 then 4, and 2 remain. The core
test checks affordability before each buy, and a seed that ever ran
short would earn the difference as extra boss clears on the already
cleared pass, never a balance edit.

The combat half opens the first fight of expedition 1 under the
standing constraint that the scripted hand owns water only, and
slices it into five beats. Move is three fixed one-meter walks toward
the foe, and the call is `Move(10)` three times, not `Move(1)`:
stamina is charged per full meter, so a one-decimeter crawl would
spend nothing and the stamina line would not move. Aim holds the
scripted hand's own solve on the hud, the angle the water-constrained
sweep picked, with the power bar charging at two thirds of the
ceiling. Flight is the fired shell half way through its arc, the
flown trail fading behind it. Impact is the tick after the resolve,
the carved crater, the health drop, and the hud's `LAST HIT` line
reading the damage the shot dealt. Over plays the battle out, and on
seed 42 the player wins stage 1.

#figure(
  kind: image,
  supplement: [figure],
  caption: [the move beat, three fixed one-meter walks, six stamina gone from the line],
  image("/game-systems/figures/golden-move.png", width: 100%),
)

#figure(
  kind: image,
  supplement: [figure],
  caption: [the aim beat, the scripted solve's angle held, the power bar at two thirds],
  image("/game-systems/figures/golden-aim.png", width: 100%),
)

#figure(
  kind: image,
  supplement: [figure],
  caption: [the flight beat, the shell mid arc at half its flight, the trail fading behind],
  image("/game-systems/figures/golden-flight.png", width: 100%),
)

#figure(
  kind: image,
  supplement: [figure],
  caption: [the impact beat, the crater carved, the health dropped, the last hit readout],
  image("/game-systems/figures/golden-impact.png", width: 100%),
)

#figure(
  kind: image,
  supplement: [figure],
  caption: [the over beat, the foes dead, the stage 1 win on seed 42],
  image("/game-systems/figures/golden-over.png", width: 100%),
)

The five beats run on chapter 18's seam: the campaign constructs with
scripts on by default, so the enemy sweep is scored by the lua
weights and the pet's skill choice comes from the pet brain, while
the player side stays the compiled water-constrained hand. That is a
default instead of a risk because the equivalence suite walked it:
per-turn `Match.StateHash` traces are identical scripts on and off
over campaign walks on seeds 42 through 45, and mirror duels, both
brains scripted against both compiled, agree on seeds 7, 21, and 42.
The seed does not generalize: the compiled water hand loses
expedition 1 stage 3 on seeds 44, 46, and 47 and expedition 2 stage 3
on seed 48. Seed 42 wins both expeditions, which is why the golden
run walks 42.

#figure(
  kind: image,
  supplement: [figure],
  caption: [the board after the golden battles, both passes clear, pass 3 unlocked],
  image("/game-systems/figures/golden-board.png", width: 100%),
)

#figure(
  kind: image,
  supplement: [figure],
  caption: [the alpha digger's payout, the second boss purse, 120 xp, scrap, and a hatch],
  image("/game-systems/figures/golden-reward.png", width: 100%),
)

The economy half is the seven steps after the battles, `golden-board`
through `golden-craft`, walked the same way: the board after the
clears, the boss payout, the shop with the 8 diamond purse, the bag
holding the bought hat while the egg hatched at the counter, the
doll wearing the sun hat, the pet tab with two hatches plus the egg,
and the bench holding a water droplet +2 over 2 leftover diamonds.
The smoke suite runs all twelve beats like every other scene. The
sheet itself now speaks the upgrade language: a worn piece names
itself with its level, "water droplet +2", and a stat prints its
base plus the bench's bonus in parens, "100 + (44)", the bonus being
exactly what the compounding scale added over the base.

#figure(
  kind: image,
  supplement: [figure],
  caption: [the golden shop, 8 diamonds and the purse that covers the hat and the egg],
  image("/game-systems/figures/golden-shop.png", width: 100%),
)

#figure(
  kind: image,
  supplement: [figure],
  caption: [the buy beat, the bag holding the bought hat while the egg hatched at the counter],
  image("/game-systems/figures/golden-buy.png", width: 100%),
)

#figure(
  kind: image,
  supplement: [figure],
  caption: [the equip beat, the doll wearing the sun hat],
  image("/game-systems/figures/golden-equip.png", width: 100%),
)

#figure(
  kind: image,
  supplement: [figure],
  caption: [the pets beat, the pet tab with two hatches plus the egg],
  image("/game-systems/figures/golden-pets.png", width: 100%),
)

#figure(
  kind: image,
  supplement: [figure],
  caption: [the bench after the golden run, the weapon line reading +2 with 2 diamonds left],
  image("/game-systems/figures/golden-craft.png", width: 100%),
)

The web companion grew the same economy: `/api/buy` takes a stock
id, `/api/equip` an item id, `/api/upgrade` a slot, each one campaign
call and the same fragment back out, unknown ids answer 400, and the
page carries buttons for the hat, the egg, the equip, and the weapon
slot. The web test plays the golden flow over HTTP, fires to two
boss wins, buys, equips, upgrades twice, and asserts the power delta
of each bench visit is exactly the weapon's scale line, 100 to 120
to 144.

The run also exists as footage. `--record battle --out-dir <dir>`
replays the seed 42 first battle deterministically, the same
scripted play-out the over beat walks, and captures every second
tick: sixty hertz of simulation becomes thirty frames a second, so
the encode plays at real-time speed. Stage 1 runs 260 ticks, 130
frames, about 4.3 seconds. The walkthrough encodes that segment at
its capture cadence in yuv420p, then holds each of the twelve
validated beats for two seconds, about 28.3 seconds total, and
commits the result at `figures/golden-run.mp4`. The encoder measured
here is ffmpeg 9.0.1, and mp4 bytes shift across encoder versions,
so the mp4 is not a byte gate: the ordered validated pngs carry the
byte-exact contract, the mp4 answers a measured size floor and a
duration band.

`make golden` wraps the whole walkthrough: it builds both frontends,
cross-checks the beat list against the exe's usage error, captures
the twelve frames in walking order as `output/screenshots/
golden-01-move.png` through `golden-12-craft.png`, validates each
png's signature, 1920x1080 frame, and a measured byte floor, proves
the frames deterministic by capturing the board beat twice in two
processes and demanding byte equality, records and encodes the
battle, and appends the holds. The encoder is mandatory: ffmpeg on
the PATH first, a one-shot container second, and a machine with
neither fails the target with a plain message.

sources: github.com/kniEngine/kni for the framework, release
4.3.9001, verified by the restore, compile, and run probes in this
repository; nuget.org/packages/FontStashSharp.KNI for the runtime
font rasterizer, FontStashSharp.Kni 1.6.1, and
fontstashsharp.github.io for its api shape, both accessed 2026-09-23;
the vendored Iosevka Term Nerd Font ttf and its OFL license live in
this repository's fonts/, from the github.com/ryanoasis/nerd-fonts
releases; htmx.org and the npm registry for htmx 4.0.0 with the
SRI digest, accessed 2026-09-08. Verified by `dotnet test
books/game-systems/capstone/GameSystemsCapstone.slnx`, 10 web tests,
and the renderer smoke suite, 28 scene runs and 3 usage errors plus
the record lane's bounded dump, every scene an exe run that must
write a 1920x1080 png, plus `make golden` for the ordered walkthrough,
the double capture, and the motion mp4.
