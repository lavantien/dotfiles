#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

#let pane(x0, x1, ytop, title, ..lines) = {
  let ls = lines.pos()
  cdraw.rect((x0, ytop - 2.3 - (ls.len() - 1) * 1.1), (x1, ytop), fill: luma(235), radius: 0.02)
  cdraw.content(((x0 + x1) / 2, ytop - 0.6), [#title], size: 6.5pt)
  for (i, l) in ls.enumerate() {
    cdraw.content(((x0 + x1) / 2, ytop - 1.75 - i * 1.1), [#l], size: 6pt)
  }
}

= capstone: line clone chat with mini apps

The capstone is a chat service in the shape of the messenger everyone
knows: named users claim a handle, join rooms, and exchange text with
history replay, typing indicators, and read receipts, while four mini
apps, a poll, a rock paper scissors duel, a shared sketchpad, and a
room-wide 2048 board, run as panels over the same wire. It lives in
this repo at `java/capstone/`, 26 java source files and 12 junit
classes plus 2 client doubles, 131 tests green three consecutive runs,
beside a react frontend at `java/capstone/web/` whose 21 node tests
include an end to end round that boots the real server and drives it
through the same wire and state modules the browser runs. The whole
tree is 8,193 lines by count including the stylesheet, no external
java dependency anywhere,
the jdk only, and one process serves the site and the websocket on
one port.

#flow(
  [the capstone, one process, one port, two protocols],
  node((0, 0), [react ui, #linebreak() vite build]),
  edge((0, 0), (1.5, 0), "-|>", label: [http get]),
  node((1.5, 0), [static site]),
  edge((2.9, 0), (4.4, 0), "-|>", label: [upgrade]),
  node((4.4, 0), [ws listener]),
  edge((4.4, 0), (5.9, 0), "-|>", label: [frames]),
  node((5.9, 0), [hub]),
  edge((5.9, 0), (7.4, 0), "-|>", label: [app frames]),
  node((7.4, 0), [mini apps]),
  edge((7.4, 0), (8.9, -0.9), "-|>"),
  node((8.9, -0.9), [rooms and #linebreak() fan-out]),
)

== the shape in thirty seconds

`Main` boots one `WsServer` on a port from argv or 8080, loopback
only, and hands it a `Hub` wired to a `MiniApps` runtime holding the
4 registered apps. When the vite build exists the same listener
serves it through an `HttpFallback` seam, so one process owns both
protocols, and during frontend development vite's dev server proxies
the `/chat` upgrade to the server's port instead. Every tunable
lives in one record: `Config.defaults()` caps a ws message at 1 MiB,
the handshake head at 8,192 bytes, the per-connection outbound queue
at 256 frames, the room history at 64 messages, and a chat text at
1,000 characters. The tests shrink those caps to reach every edge
with small payloads, which is the whole reason the record exists.

#listing("java/capstone/src/javabook/Main.java", first: 27, last: 44, caption: [the whole boot: hub, registry, fallback, park])

The wire vocabulary is 8 chat frame types, `hello`, `join`, `send`,
`typing`, `read`, `leave`, `app.open`, and `app.event`, answered by
`hello-ok`, `joined`, `history`, `message`, `typing`, `read`, `left`,
and `error`, plus the app envelopes. Errors never close the socket,
they arrive as `error` events carrying a code and a detail, because a
bad frame from a client is a client problem and the connection should
survive it. Only wire level violations close, with the RFC's own
codes.

== the wire we own

The transport is a raw `ServerSocketChannel` in blocking mode with
one virtual thread per accepted connection, and the chapter owes the
reader the reason this is not `jdk.httpserver` with a 101 handler,
because chapter 19 built the whole service spine on that kernel and
the capstone walks away from it. The probe ran both paths on the
pinned jdk 27 at wave 0:

#callout("pitfall", "why not jdk.httpserver 101", [
  `sendResponseHeaders(101, -1)` emits a byte-perfect handshake the
  jdk's own `java.net.http.WebSocket` client accepts, and then the
  exchange machinery kills it. A bodyless `sendResponseHeaders` ends
  with a flush and close, so both exchange streams die before the
  handler's next line runs. `ExchangeFinished` re-queues the socket
  to the keep-alive selector, whose next-request parser black-holes
  every websocket frame: no echo, no error, no FIN, measured past 90
  seconds. The reflection escape onto the underlying channel dies on
  `IllegalBlockingModeException`, a selector-registered channel
  cannot go back to blocking reads. Passing 0 instead of -1 differs
  only by a WARNING line. Measured on tools/jdk27/build/jdk-27,
  2026-10-04, wave 0.
])

So the socket channel is owned outright, and the accept loop is the
whole listener:

#listing("java/capstone/src/javabook/ws/WsServer.java", first: 67, last: 106, caption: [accept on a virtual thread, handshake, fenced registration])

Three details carry weight. `TcpNoDelay` is set on every socket
because a chat frame is small and latency is the product. The
`HttpFallback` returns false when a plain http request arrived and
was answered, and the connection ends there. And registration into
the connection set is fenced against `close()`: either the
registration lands before the close snapshot and the connection gets
its 1001, or the guard inside the synchronized block rejects it.

The opening handshake is RFC 6455 s4.2.1 written by hand, GET with
`Upgrade: websocket`, a `Connection` header carrying the upgrade
token, version 13, and a key that base64-decodes to exactly 16 bytes,
answered by the bare three-header 101 the jdk client accepts.
Anything else gets a 400, or a 426 carrying the supported version
when only the version header disagrees. Reads stop exactly at the
blank line so the connection's stream sees every byte a pipelining
client sent past the head:

#listing("java/capstone/src/javabook/ws/Handshake.java", first: 53, last: 98, caption: [the upgrade decision tree, header folding, the three-header 101])

Headers fold into a case-insensitive `TreeMap` with duplicates
comma-joined, the spec allows `Upgrade: h2c, websocket` lists and the
handshake is wanted when any token matches, and the accept key is
SHA-1 of key plus the RFC's fixed guid, the one place this book
touches SHA-1, because the protocol dictates it and nothing else
rides on collision resistance here.

== the frame codec's edge table

`Frame.read` pulls one frame off a client stream and enforces the
protocol's whole grammar before any payload is buffered:

#listing("java/capstone/src/javabook/ws/Frame.java", first: 33, last: 68, caption: [mask required, minimal lengths, control rules, the cap])

Client frames must be masked, rsv bits and reserved opcodes fail
with 1002, control frames stay at or under 125 bytes and never
fragment, a close payload of exactly 1 byte fails, and the length
must use its minimal encoding, 7-bit below 126, 16-bit below 65,536,
64-bit above. An announced or accumulated payload past the cap fails
with 1009 before anything is buffered, and text is decoded strict
utf-8, malformed or overlong sequences answering 1007. The test
tables pin all of it against a live listener, 125, 126, and 127
bytes crossing the length forms both directions, a 300 byte and a
70,000 byte payload through both extended forms, valid utf-8 split
mid character across fragments reassembling cleanly, and every
malformed row answered with the code the RFC names.

#diagram([the close code table this server enforces], length: 13pt, {
  cdraw.rect((0.3, 4.4), (11.3, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 6.1), [accepted on the wire], size: 6.5pt)
  cdraw.content((5.8, 5.15), [1000 to 1003, 1007 to 1011], size: 6pt)
  cdraw.content((5.8, 4.2), [3000 to 4999: registered and private], size: 6pt)
  cdraw.rect((12.5, 4.4), (23.3, 6.7), fill: luma(235), radius: 0.02)
  cdraw.content((17.9, 6.1), [refused], size: 6.5pt)
  cdraw.content((17.9, 5.15), [1004, 1005, 1006, 1015: reserved], size: 6pt)
  cdraw.content((17.9, 4.2), [0 to 999, 5000 to 65535: out of range], size: 6pt)
  cdraw.rect((0.3, 1.2), (23.3, 3.4), fill: luma(222), radius: 0.02)
  cdraw.content((11.8, 2.7), [the deliberate divergence], size: 6.5pt)
  cdraw.content((11.8, 1.75), [1012 service restart, 1013 try again later, 1014 bad gateway are IANA registered, this server still refuses them], size: 6pt)
  cdraw.content((11.8, 0.15), [the conservative RFC 6455 table is the taught one], size: 6.5pt)
})

The divergence is stated, not hidden: 1012, 1013, and 1014 sit in
the IANA registry, registered through the HYBI mailing list and
updated there in 2025, and this server still refuses them because
the RFC 6455 table is what the chapter teaches and a toy chat has no
restart or gateway story to tell with them.

== the connection, a reader and a writer

One upgraded connection runs 2 virtual threads. The reader owns the
frame loop, message assembly across continuations under the size
cap, strict utf-8 on complete text messages, ping answered with a
matching pong, and the close choreography where a peer close is
echoed then tcp closed. The writer drains an outbound queue of
pre-encoded frames:

#listing("java/capstone/src/javabook/ws/WsConnection.java", first: 95, last: 145, caption: [the reader loop, opcode dispatch, the close choreography])

The queue is the fan-out decision and the capstone's most
consequential design choice. A broadcast only enqueues, never writes,
so a room send touches 1 socket zero times and N queues once each,
and a member whose tcp window stalled fills its own queue and gets
dropped at the frame cap instead of stalling the room's sends behind
one slow socket. The room lock never waits on io. Sends from any
thread land in fifo order because the enqueue happens under the
caller's ordering and the queue serializes the writes.

The drop path is where the locking story earns its care:

#listing("java/capstone/src/javabook/ws/WsConnection.java", first: 182, last: 206, caption: [the overflow drop: fence, sentinel, kill the socket off thread])

A caller holding a room lock must never run `finish()` inline,
because finish tells the handler, the handler reenters the hub, and
the hub wants the same lock. So the drop only fences the closed
flag, clears the queue, wakes the writer with the sentinel, and
kills the socket on its own virtual thread, because `close()` can
wait on the writer's blocked write to a never-read tcp and that wait
must never run under the caller's lock either. The writer thread
runs `finish()` holding no hub state. This is chapter 25's lesson,
no blocking under a lock, paid forward with interest.

== the hub

Above the transport sits the chat core. A `hello` names the
connection and claims the user, `join` binds it to a room and
replays history, `send` broadcasts a message carrying a globally
unique monotonically increasing id from one `AtomicLong`, `typing`
and `read` fan out to the others only, `leave` acknowledges, and any
disconnect departs every room with a `left` event. Names and rooms
match `[A-Za-z0-9_-]{1,32}`, a name already online is refused, and
a second hello on the same connection is an error event.

The join path carries the membership and generation invariants:

#listing("java/capstone/src/javabook/hub/Hub.java", first: 115, last: 159, caption: [join: the retry on a dead generation, the ghost rollback, the snapshot under the lock])

Four invariants live here. A concurrent last-leave may empty and
unregister the room between the `computeIfAbsent` and the lock, so
the loop re-checks the live registration and retries. The id joins
the history append inside the room lock, so the history snapshot a
joiner sees and the live events that follow can neither duplicate
nor skip a message. The connection can die while its reader holds
this join frame, and the drop's close may already have run the only
depart that member would ever get, which would leave the room
holding a ghost forever, so the liveness re-check under the lock
rolls the registration back. And every room command enters through
one guarded path:

#listing("java/capstone/src/javabook/hub/Hub.java", first: 322, last: 344, caption: [inRoom, the one guarded path: membership and generation re-checked under the lock])

A frame racing its sender's depart must lose here instead of
broadcasting after the `left` event, and a last-leave that emptied
and replaced the room between the lookup and the lock must not let
a stale frame act on the dead generation. Departure is exactly once
per connection and room, `room.members.remove(user) != connection`
returns silently, because a racing close can run depart from the
writer thread while the same connection's reader is parked inside
`leave`, and the second run would double the `left` event and the
app's `onLeave`. When the last member leaves, the room unregisters
by name and value and the runtime hears the room object itself, the
generation key, so a stale room-closed from a dying generation can
never drop the state of the generation that replaced it:

#listing("java/capstone/src/javabook/hub/Hub.java", first: 265, last: 313, caption: [depart exactly once, and the socket the runtime sees, key is the room object])

Two of these invariants were adversarial finds, not first drafts.
The orphaned-room race reproduced at an 8.5 percent rate under
concurrent join and last-leave churn before the generation re-check
closed it, and the ghost member reproduced 12 of 12 rounds before
the rollback, its regression now driving a 4-million-element pad
array past the json parser while a 600 message flood drops the
connection mid parse, 6 rounds asserting the dropped name never
appears in a later member list.

#diagram([the hub's one guarded path, everything re-checked under the room lock], length: 13pt, {
  let step(y, label, fill) = {
    cdraw.rect((0.3, y - 0.5), (7.9, y + 0.7), fill: fill, radius: 0.02)
    cdraw.content((4.1, y + 0.1), [#label], size: 6pt)
  }
  step(7.3, [a frame arrives, session checked], luma(235))
  cdraw.line((4.1, 6.6), (4.1, 6.0), stroke: luma(100), mark: (end: ">>"))
  step(5.4, [room looked up by name], luma(235))
  cdraw.line((4.1, 4.7), (4.1, 4.1), stroke: luma(100), mark: (end: ">>"))
  step(3.5, [synchronized(room)], luma(222))
  cdraw.content((11.2, 5.5), [the room lock is the only lock,], size: 6pt)
  cdraw.content((11.2, 4.4), [apps need none of their own], size: 6pt)
  cdraw.line((4.1, 2.8), (4.1, 2.2), stroke: luma(100), mark: (end: ">>"))
  step(1.6, [generation still live, member still bound], luma(235))
  cdraw.line((4.1, 0.9), (4.1, 0.3), stroke: luma(100), mark: (end: ">>"))
  cdraw.rect((0.3, -0.9), (7.9, 0.3), fill: luma(205), radius: 0.02)
  cdraw.content((4.1, -0.3), [the action: send, typing, read, leave, app frame], size: 6pt)
  pane(16.4, 23.3, 7.3, [the two races], [orphaned room: 8.5 percent], [reproduction before the], [generation re-check], [ghost member: 12 of 12], [before the rollback])
})

== message history

Each room holds a fixed-capacity ring of its last messages, the
oldest dropped first, synchronized on itself so a snapshot copies
without holding the room lock across the copy:

#listing("java/capstone/src/javabook/msg/History.java", first: 22, last: 33, caption: [the ring: add, snapshot in order, count])

A join replays the snapshot inside the room lock as one `history`
event, then the live `message` events follow in the same lock's
order, which is why the two can never disagree. Ids come from the
hub's global counter, unique across rooms and strictly increasing
inside each, and the read receipt carries one, so a client can mark
exactly the message its member read.

== the mini app runtime

The apps are the capstone's second act. The runtime owns a registry
of app kinds by id, `[a-z0-9][a-z0-9-]{0,15}`, and one instance per
room generation per app, created lazily on the room's first frame of
either kind and dropped when the room empties. The hub forwards
`app.open` and `app.event` frames after its own session and
membership checks, then hands the room to the runtime as a
`RoomSocket`:

#listing("java/capstone/src/javabook/miniapp/MiniApps.java", first: 57, last: 85, caption: [dispatch: lazy instance, open ack and announce, event by action])

The contract that makes the whole layer lock free is placement:
every app callback runs on the caller's thread under the owning
room's lock, in arrival order interleaved with the room's chat
events. An instance needs no locks of its own, plain fields are the
whole state story, and a callback must never block, which every
send satisfying because sends only enqueue. The runtime wraps app
payloads into envelopes, `app.state` room visible, `app.priv` to one
member, `app.error` to the sender, always carrying the room and app
id. Opening a panel acks the opener with the current state through
`onOpen`, announces the panel to the others, and fires on every
open, not just the first, so a late joiner catching up is the same
code path as the first panel.

== the four mini apps

Four apps ride the runtime, each a different lesson in shared state
under one lock. The poll is the broadcast shape: one active poll per
room, `create` with a question up to 200 characters and 2 to 8
options of up to 80 each, every member votes once whether or not
their panel is open, each vote fans the live tallies with voter
names per option to the whole room, and the creator closes with the
winner or a tie: plurality, the option standing alone at the top count
wins even below half, the word tie only when the top is level. The creator
leaving an open poll closes it, since nobody else could.

#diagram([the four apps' bounds, every number from the source], length: 13pt, {
  let row(y, app, bound) = {
    cdraw.rect((0.3, y - 0.45), (5.3, y + 0.45), fill: luma(235), radius: 0.02)
    cdraw.content((2.8, y), [#app], size: 6pt)
    cdraw.content((10.6, y), [#bound], size: 6pt)
  }
  row(6.4, [poll], [question 200 chars, options 2 to 8 of 80, one vote each])
  row(5.2, [duel], [bestOf odd 1 to 9, first to (bestOf+1)/2, one match plus one slot])
  row(4.0, [sketch], [grid 1000 by 1000 per mille, 8 colors, 256 points, 128 strokes])
  row(2.8, [2048], [board 4 by 4, spawn 2 or 4 at 1 in 10, target 2048])
  cdraw.content((10.6, 1.3), [all state per room generation, plain fields, no locks], size: 6.5pt)
  cdraw.content((10.6, 0.2), [2048's best per user lives on the app object instead], size: 6.5pt)
})

The duel is the hidden information shape: one waiting slot and one
match at a time per room. `queue` enters matchmaking, a second queue
matches the two, and the waiting player's `bestOf` wins, the
responder's ignored. Each `choose` is echoed to the chooser alone,
and the room sees a round only once both weapons are in, draws
replay the same round number, and the series ends at the majority.
The validation lesson lives in one line of the queue path:

#listing("java/capstone/src/javabook/duel/DuelApp.java", first: 106, last: 119, caption: [bestOf validated on the long before the narrowing cast])

Narrowing first would wrap 2^32+1 into a legal 1, and the json
parser hands the app a `Long`, so the range check runs where the
value is still honest. A player leaving mid match forfeits to the
opponent, a waiting player leaving clears the slot.

The sketchpad is the coalescing shape. A stroke is one gesture, a
color index into a fixed 8 color palette plus its points as integer
per-mille coordinates on a 1000 by 1000 grid, so every client
renders the same board whatever its canvas size. The client
coalesces its pointer samples, one stroke is one `app.event`, never
one frame per point, 2 to 512 array entries of 0 to 1000, and the
server keeps a bounded ring of 128 strokes, oldest first out:

#listing("java/capstone/src/javabook/sketch/SketchApp.java", first: 59, last: 83, caption: [one stroke validated whole, then into the ring])

2048 is the shared state machine shape: one board per room, every
member moves the same 16 cell array. A move slides all 4 lines in
the asked direction, each tile merges at most once per move so
2,2,2,2 becomes 4,4 and never 8, the merge values sum into the
score, and a fresh 2 or 4, one in ten, spawns on a random empty cell
of the moved board. The move that changes nothing is rejected, so
the spawn never rewards a no-op. Reaching 2048 flags the win while
play continues, and the game is over when no empty cell and no equal
neighbor remain:

#listing("java/capstone/src/javabook/g2048/G2048App.java", first: 130, last: 154, caption: [slide: compaction, merge once, sum the gains])

The best score is per user but lives on the app object, not the room
instance: the registered app survives the room emptying and the name
being re-created and dies with the process, so a best is a fact
about a player in one server run, and the field is an instance field
so tests holding different app objects never bleed records into each
other. The mover banks the game's running score against their own
best after every legal move, so in a shared game whoever pushed the
score highest owns the record. The random source is injectable, a
seeded game replays deterministically in tests.

== the react frontend

The frontend is react 19.3.0 with vite 8.3.2 and the react plugin
6.1.1, pinned exact in `package.json`, and its discipline is the one
the spike probe fixed before any code was written: the logic lives
in plain `.js` modules that node's test runner can load, because
`node --test` rejects `.jsx` at the loader level, and the jsx files
are components only, covered by the vite build. The two load-bearing
modules are `wire.js`, the client, one websocket and the frame
vocabulary and nothing else, and `state.js`, the room state as a
pure fold over the hub's events, same event in, same state out, no
io, no clock. Both run unchanged in the browser and in node, both
ship the same `WebSocket` global, which is what lets the e2e suite
drive the real server through the exact files the browser runs.

#listing("java/capstone/web/src/wire.js", first: 36, last: 54, caption: [connect: open, error, close folded into the same event stream])

The fold's one subtle duty is the sketch cap. The server keeps 128
strokes, so the live fold trims to the same bound, else a resident
board and a late opener's replay diverge, a bug both blind attackers
of the frontend wave found independently before it ever shipped:

#listing("java/capstone/web/src/state.js", first: 134, last: 138, caption: [the stroke fold trimming to the server's bound])

The panels are 5, chat, poll, 2048, duel, sketch, selected on a
bottom bar, mobile first. The 2048 board reads swipes from a shared
`direction` helper with a 24 pixel threshold, a shorter gesture is a
tap and answers null. Once a room is joined the app opens every
panel, so all 4 app states fold from the same event stream and each
panel renders its slice. A dropped connection folds the socket's
close event into an offline flag instead of leaving every panel
silently stale.

== one process, two protocols

Production is one process: the listener serves the vite build when
`web/dist` exists, through the same `Handshake` seam that decides
upgrade versus plain request. `StaticSite` is deliberately small,
GET only, files that exist inside the root after percent-decoding
and normalization, no directory listing, an 8 MiB cap, content types
for the shapes a frontend build produces, and `Connection: close` on
every response:

#listing("java/capstone/src/javabook/web/StaticSite.java", first: 67, last: 107, caption: [resolve and decode: strict, contained, windows aliases refused])

The containment rules earn their lines. Percent-decoding is strict,
a bare percent, a short escape, a control or non-ascii or backslash
character is a rejection, never a repair. The decoded path must
normalize back inside the root. And windows strips trailing dots and
spaces from path segments, so those spellings are refused outright,
they would serve a file under a name nobody asked for.

The end to end round is the frontend's real gate. It boots the
compiled server on an ephemeral port with a throwaway site root,
asserts the boot line lists all 4 apps and serves the site, then
drives two clients through chat with typing and a read receipt, a
poll from create to a tied close, a shared 2048 move both boards
agree on, a best-of-one duel to a series win, and a sketch stroke
that survives a leave and rejoin as a replayed board. Its java
binary resolution is the lane's one platform concession:

#listing("java/capstone/web/test/e2e.test.js", first: 23, last: 35, caption: [the repo's pinned jdk wins, the machine's java can be a release older than the classes])

Class file version 71 needs 27, and a machine java of 26 dies at
`UnsupportedClassVersionError` before the first assertion, so the
pinned build is resolved first. The remaining 20 node tests pin the
state fold, the wire client, the swipe direction, and the dependency
smoke that asserts the react version string itself.

== measured, and why

The capstone carries no benchmark harness, and says so: the load
family lives in the service spine, chapter 29 owns measurement, and
pasting a microbenchmark of a toy chat would decorate rather than
inform. What the tree does carry is the adversarial record, and its
numbers are the chapter's honest measurements. The orphaned-room
race reproduced in 8.5 percent of rounds before the generation
re-check, 0 after, pinned by a churn regression that hammers join
against last-leave. The ghost member reproduced 12 of 12 rounds
before the rollback, 0 across 6 rounds after, each round a
4-million-element pad holding the reader in the parser while a 600
message flood drops it. The overflow drop was restructured when a
room wedge appeared, a blocked peer write holding the room lock
through an inline channel close, and the fix moved the kill off
thread, pinned by the flood regressions that park readers inside
the room lock on purpose. The double-depart guard exists because a
stalled action raced a racing close into two left events, its
regression resetting `SO_LINGER` and flooding 200 messages. None of
these are timings, they are reproduction rates and round counts,
and that is the honest shape of the evidence this tree prints.

#diagram([the adversarial record, reproduction rates before and after each fix], length: 13pt, {
  let row(y, name, before, after) = {
    cdraw.content((1.9, y), [#name], size: 6pt)
    cdraw.rect((4.0, y - 0.32), (13.3, y + 0.32), fill: luma(205), radius: 0.02)
    cdraw.content((8.65, y), [#before], size: 6pt)
    cdraw.line((13.5, y), (14.3, y), stroke: luma(100), mark: (end: ">>"))
    cdraw.content((19.0, y), [#after], size: 6pt)
  }
  row(6.4, [orphaned room], [8.5 percent of rounds], [0, churn regression])
  row(5.2, [ghost member], [12 of 12 rounds], [0 of 6, pad and flood])
  row(4.0, [double depart], [2 left events], [exactly 1, linger and flood])
  row(2.8, [room wedge], [lock held through close], [kill moved off thread])
  cdraw.content((10.6, 1.2), [no benchmark harness rides this tree, chapter 29 owns measurement], size: 6.5pt)
  cdraw.content((10.6, 0.1), [every fix landed with the regression that pins it], size: 6.5pt)
})

== accepted design, stated

Five items are design choices this chapter records rather than
fixes, and the list is the contract. The poll accepts duplicate
option texts, two options spelled the same both collect votes, an
ids-not-texts fix would buy nothing a toy poll needs. The per-user
2048 best map grows for the process lifetime, one long per user
name ever seen, unbounded across a server run, and dies with the
process, correct for a toy and stated for a real one. Two nanosecond
windows remain unconfirmed, the close fence where a reader may
observe one frame past a close the writer already flushed, and the
file size read in the static site where a file growing past the cap
between the check and the read serves the larger file, both judged
harmless for a loopback toy and both named here so a real port
knows where to look. And the two latent items chapter 24 recorded
against the service spine stand unchanged, the values-shared view
rule where a store view exposes the same list instance the store
may still mutate, and the non-ApiError throw escaping at the
chapter 20 envelope boundary where a handler bug surfaces as a 500
with its detail logged but not enveloped.

== what the capstone proves

Every layer of the book cashes once, in place. The toolchain's
pinned jdk 27 builds and runs the whole tree. The ladder's features
are the shape: records carry the messages, switch expressions
dispatch the opcodes, pattern matching guards the frames. The lexical chapter's escape families are the json parser's
surrogate discipline. Types and bit arithmetic are the frame
codec's length forms and masks. Classes and records are the whole
message layer. Generics are the writer's `Object...` pairs and the
typed registries. Nested types are the private companions, `Poll`,
`Duel`, `Board`, `Game`, `AppSocket`, while enums themselves go
unused, opcode dispatch switching on ints, a stated non-use rather
than an oversight. The functional chapter's
one-method interfaces are every seam, `WsHandler`, `HttpFallback`,
`App`, `Out`. Pattern matching is `instanceof Session s` in the
guards and record patterns in the parsers. Concurrency is virtual
threads per connection, the room lock discipline, and the atomics.
The memory chapter's sizing instinct is the bounded fan-out itself,
every connection's outbound queue capped at 256 frames, so a loud
peer costs flat memory, not growing memory.
The collections chapter is the `ArrayDeque` ring, the
`LinkedBlockingQueue` fan-out, and the case-insensitive `TreeMap`.
Formats are the writer's escape table. The io chapter's socket
channels and the jdk client's measured fragmentation are the
transport's own facts. Modules and reflection pay negatively and
say so: the capstone declares no `module-info`, it compiles and
runs on the plain classpath, and nothing in the tree reads a class
at runtime, the json codec binding through `instanceof` and
explicit constructors, which is why the record write refusals the
reflection chapter pins never bite here. Security is SHA-1 exactly
where the RFC
dictates it and nowhere else. The testing chapter's discipline is
the 131 test lane. And the service spine pays off negatively and
positively: negatively, the wave 0 probe is why the capstone does
not ride `jdk.httpserver`, positively, the spine's hand-rolled json
and its no-blocking-under-a-lock lesson are the codec and the drop
path verbatim.

#diagram([every chapter pays off once, in place], length: 13pt, {
  let pair(x0, y, ch, payoff) = {
    cdraw.line((x0, y - 0.45), (x0 + 10.6, y - 0.45), stroke: luma(220))
    cdraw.content((x0 + 1.9, y), [#ch], size: 6pt)
    cdraw.content((x0 + 7.2, y), [#payoff], size: 6pt)
  }
  cdraw.content((2.2, 7.5), [chapter], size: 6.5pt)
  cdraw.content((7.5, 7.5), [payoff], size: 6.5pt)
  pair(0.3, 6.5, [toolchain], [the pinned jdk])
  pair(0.3, 5.5, [ladder], [records, switches, virtual threads])
  pair(0.3, 4.5, [lexical], [escapes and surrogate pairing])
  pair(0.3, 3.5, [types], [masks, length forms, long ids])
  pair(0.3, 2.5, [classes], [records as the message layer])
  pair(0.3, 1.5, [generics], [the Object... writer, registries])
  pair(0.3, 0.5, [functional], [one-method seams])
  cdraw.content((13.1, 7.5), [chapter], size: 6.5pt)
  cdraw.content((18.4, 7.5), [payoff], size: 6.5pt)
  pair(12.5, 6.5, [patterns], [instanceof guards, record parsers])
  pair(12.5, 5.5, [concurrency], [a thread per connection, the lock])
  pair(12.5, 4.5, [collections], [the ring, the queue, the treemap])
  pair(12.5, 3.5, [io], [channels, the jdk client's frames])
  pair(12.5, 2.5, [security], [sha-1 only where dictated])
  pair(12.5, 1.5, [testing], [the 131 test lane])
  pair(12.5, 0.5, [the spine], [the json codec, the lock lesson])
  cdraw.content((11.8, -1.1), [131 junit tests and 21 node tests, zero skipped], size: 6pt)
})

The book's last word on the capstone is the lane's own: `make
verify-java` runs the samples, the api module, the capstone module,
and the web leg in one gate, the e2e last because it spawns the
server from the compiled classes, and the whole chain was green 3
consecutive runs the day this chapter was written.

sources: the capstone tree in this repo, `java/capstone/`, counted
from the tree at this commit: 26 source files, 12 junit classes
plus the RawClient and JdkClient doubles, 131 junit tests (Frame 16,
Handshake 6, Protocol 27, Json 18, History 5, Hub 16, MiniApp 10,
Poll 6, Duel 7, Sketch 4, G2048 8, StaticSite 8), 11 web source
files, 10 js modules plus the stylesheet, and 5 web test files
holding 21 node tests (state 13, wire 2, swipe 4, deps 1, e2e 1),
8,193 lines by wc over java sources, java tests, web sources
including the stylesheet, and web tests. Verified live 2026-10-05 on
tools/jdk27/build/jdk-27, build 27+35-2325, through
`pwsh -NoProfile -File tools/verify-java.ps1`: the junit lane green
3 consecutive runs, the web leg's `npm run verify` green the same
day. RFC 6455 for the handshake, frame, and close rules, read at
tools.ietf.org/html/rfc6455, accessed 2026-10-04 during chapter 14
and re-read for this chapter's close code table. The IANA websocket
close code registry, www.iana.org/assignments/websocket/websocket.xml,
accessed 2026-10-05, for the 1012 to 1014 divergence: all 3
registered through the HYBI mailing list, last updated there
2025-07-30, and refused by this server anyway. The wave 0
jdk.httpserver probe facts quoted from the plan ledger at
.claude/plans/briefs/java-TASKS.md, measured 2026-10-04. React
19.3.0, vite 8.3.2, and the vite react plugin 6.1.1 pinned exact in
java/capstone/web/package.json. The adversarial history, the 8.5
percent orphaned-room reproduction, the 12 of 12 ghost rounds, the
overflow restructure, and the double-depart guard, quoted from the
wave ledger and the regression tests named in the tree.
