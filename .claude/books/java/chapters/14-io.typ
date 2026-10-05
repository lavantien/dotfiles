#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= io and networking

Java's input output stack has three ages stacked on each other: the
1996 byte and character streams, the 1.4 channels and buffers built
for bulk movement, and the java 7 `java.nio.file` api, `Path` and
`Files`, that replaced the old `File` class as the everyday surface.
Networking has the same shape, sockets from the beginning and the
`java.net.http` client standard since 11, HTTP/2 native and HTTP/3
since 26. This chapter walks the stack bottom up and ends with the
websocket client measured against a hand rolled peer, which is where
the capstone's chat server starts. Chapter 2 walked the ladder, here
is the io rung at work.

== streams and try-with-resources

The oldest layer is a pair of abstract classes, `InputStream` and
`OutputStream`, sequential bytes, plus `Reader` and `Writer` over them
for characters. `System.in` and `System.out` are these. Real code
layers them, a buffer over a reader over a file, and the language
feature that makes the layering safe is try-with-resources, since
java 7. Any type implementing `AutoCloseable` can sit in the resource
clause, several at once, and the compiler closes them in reverse
order, suppressing secondary exceptions. Since java 9 the resource can
be an effectively final variable declared before the try, so a stream
opened in one method can be scoped in another:

#listing("java/samples/src/Ch14/IoFiles.java", first: 31, last: 38, caption: [the same try closes a fresh declaration and a preexisting effectively final reader])

The close order matters when data flows between resources: the writer
must flush before the reader underneath it closes. Manual close calls
after every operation were the classic leak, and the platform's own
pre-7 resource code was full of it, which is why the rule is simple:
if it is `AutoCloseable`, it goes in the try.

== path and files

The pre-7 `java.io.File` class could tell you it exists but not read
itself, modeled attributes inconsistently, and walked trees badly. It
survives for interop. Java 7 replaced it with `Path`, an interface to
a location that may not exist, and `Files`, a wall of static
operations over paths. `Path.of` is a static interface method, legal
since java 8 on interfaces, and the whole family is expressive enough
that file plumbing in modern java is a few lines:

#listing("java/samples/src/Ch14/IoFiles.java", first: 40, last: 47, caption: [readString and writeString since 11, mismatch finding the first differing byte])

`readString`, `writeString`, and `mismatch` arrived in java 11, with
utf-8 as the default charset, itself a decision java 18 made global.
Before them the same job needed a `BufferedReader` loop or
`readAllBytes` plus a decode. Directory work rides the same types:
`Files.walk` streams a whole tree, `Files.find` filters it by path
and attributes, and `newDirectoryStream` globs one level.

The watch service, also java 7, turns the directory itself into an
event source. A registered directory reports create, modify, and
delete events for its direct children, buffered until taken:

#listing("java/samples/src/Ch14/WatchDir.java", first: 30, last: 40, caption: [three writes on a temp dir surface as watch events])

Two facts the sample prints rather than asserts: modify events can
coalesce, two quick writes may report once, and the event context is
the child name, so resolving it against the watched directory is the
caller's job.

== channels and buffers

The nio answer to bulk data is the channel and the buffer. A
`ByteBuffer` is a typed window over memory with three integers:
capacity, fixed at allocation, position, the read or write cursor,
and limit, the first byte that does not belong. Writing fills toward
capacity, `flip` swaps position and limit for draining, `compact`
moves the tail to the front for refilling, `clear` resets both for
reuse. The pattern is always fill, flip, drain:

#listing("java/samples/src/Ch14/IoFiles.java", first: 57, last: 76, caption: [a file channel round trip through one buffer, plus direct allocation and byte order])

`allocate` is heap memory the garbage collector owns, `allocateDirect`
is native memory the channel can move to and from the operating system
without a copy, worth it for large or hot buffers only. Endianness is
a buffer property, defaulting to big endian, `LITTLE_ENDIAN` for
x86 wire formats. A `FileChannel` is the channel over a file, and its
`map` hands back a `MappedByteBuffer`, the file mapped into the
address space, the closest java gets to memory mapped io.

== tcp sockets

The socket pair, `Socket` and `ServerSocket`, is 1996 api that java 13
quietly reimplemented over the nio infrastructure without changing a
signature. A server socket accepts, the accepted socket is a duplex
byte stream, and both sides read and write through the stream
hierarchy from the first section:

#listing("java/samples/src/Ch14/Net.java", first: 42, last: 57, caption: [connect, accept, and one line each way])

The channel equivalents, `SocketChannel` and `ServerSocketChannel`,
move the same bytes through buffers instead of streams. They are
blocking by default and switch to nonblocking with `configureBlocking`
for the selector world, where one thread multiplexes many channels,
the scalability answer before virtual threads existed. Chapter 10
covered why virtual threads make blocking sockets the plain choice
again, and the service spine in chapter 19 uses blocking handlers on
virtual threads throughout:

#listing("java/samples/src/Ch14/Net.java", first: 59, last: 73, caption: [the same echo over channels and buffers])

== the http client

Before 11, http in the jdk was `HttpURLConnection`, protocol version
1.0 habits under a 1996 era api. Java 11 standardized `java.net.http`
(JEP 321, incubated in 9) with http/2 native, a builder for requests,
and one call for the blocking case:

#listing("java/samples/src/Ch14/Net.java", first: 113, last: 127, caption: [the blocking send against the hand rolled responder, version fallback included])

The client prefers http/2 and negotiates down, the sample measures the
fallback to 1.1 against a 1.1-only peer. `sendAsync` returns a
`CompletableFuture`, the same pipeline type chapter 10 composed, and
`BodyHandlers.ofString`, `ofFile`, `ofInputStream` decide where the
body lands without touching the call site. Java 26 adds HTTP/3
(JEP 517), QUIC over UDP with TLS 1.3 inside: opt in with
`Version.HTTP_3` on the client or per request, the client races an
HTTP/3 attempt against HTTP/2 unless discovery mode pins it, and there
is no server-side implementation, the client is the whole feature.

#flow([an http/2 client against a 1.1 peer: the upgrade attempt fails, the same connection answers], node((0, 0), [builder\nversion 2]), node((1, 0), [tcp connect\n+\ upgrade attempt]), node((2, 0), [1.1 response,\nno upgrade]), node((3, 0), [request, response\nversion 1.1]), edge((0, 0), (1, 0), "-|>"), edge((1, 0), (2, 0), "-|>", label: [refused]), edge((2, 0), (3, 0), "-|>"))

For a zero-config server peer the jdk ships one since java 18
(JEP 408): `java -m jdk.httpserver`, the jwebserver tool, a static
file server over the same `com.sun.net.httpserver` package the service
spine builds on. The sample starts it as a subprocess with `--port 0`,
reads the bound port off its startup line, and fetches a file through
the http client.

== websockets, client and peer

`java.net.http.WebSocket`, standard since 11 with the http client, is
a client only, and the capstone needs the server half hand rolled, so
this chapter builds the peer first. The protocol, RFC 6455, is an http
upgrade followed by small binary frames. The client opens with
`GET` plus `Sec-WebSocket-Key`, a 16 byte nonce, the server answers
`101 Switching Protocols` with `Sec-WebSocket-Accept`, the base64 of
sha1 over the nonce and a fixed guid, and from then on the connection
carries frames: an opcode byte with a fin bit, a length, up to 7 bits
inline or 16 or 64 extended, a 4 byte mask on every client frame, and
the payload xored with that mask:

#listing("java/samples/src/Ch14/WebSocketEcho.java", first: 116, last: 144, caption: [the upgrade handshake: parse the key, answer the accept, then frames])

#listing("java/samples/src/Ch14/WebSocketEcho.java", first: 146, last: 173, caption: [the frame loop: unmask, record, echo, mirror the close code])

The measured facts on this build, 2026-10-04, pinned jdk 27: a text
message of 16384 characters is one final frame, 16385 is two, a
16384 byte frame plus a 1 byte continuation, so `sendText` fragments
above 16384. Every client frame arrives masked, the one rule that
distinguishes the two directions on the wire. The close handshake
echoes: the client sends close with code 1000, the peer mirrors the
code, and the client's `onClose` sees its own 1000 come back.

The listener is a pull model, the one surprise in the api. The default
`onOpen` grants one invocation, and every override that consumes a
message must call `request(1)` or delivery stops mid message, silently:

#listing("java/samples/src/Ch14/WebSocketEcho.java", first: 57, last: 71, caption: [onText appends and renews the permit, onClose records the echoed code])

#callout("verify", "measured, not documented", [
  The 16384 boundary, the masking, and the close echo are behavior of
  this build, printed by `WebSocketEcho` with its date, not promises
  of the specification. RFC 6455 only requires that fragments exist
  and that clients mask. Re-measure before relying on a number.
])

The capstone in chapter 32 grows this peer into the line clone's
server: one accept loop, one frame parser, the same close handshake.

sources: Java in a Nutshell 8th edition, chapter 10 (File Handling and
I/O) and chapter 13 (Platform Tools) for the 8-through-17 stream,
channel, path, socket, and urlconnection grounding, rewritten here.
openjdk.org/jeps/321 (http client standard, 11), /jeps/213
(effectively final try-with-resources, 9), /jeps/517 (HTTP/3, 26),
/jeps/408 (simple web server, 18), docs.oracle.com javadoc for
`java.nio.file.Files` at java 11 (readString, writeString, mismatch),
RFC 6455 (tools.ietf.org/html/rfc6455) for the websocket handshake,
frame, and close rules, all accessed 2026-10-04. Every number in this
chapter is measured live on `tools/jdk27/build/jdk-27` by the Ch14
samples under `pwsh tools/run-java-samples.ps1 -Chapter Ch14`: 38
checks, the fragmentation boundary, the masked frames, the echoed
close code, and the jwebserver fetch, dated 2026-10-04.
