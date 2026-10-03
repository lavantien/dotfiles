#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= network answers

The network round is layered: name the layers, say what each
protocol guarantees, and explain tls without hand-waving the key
exchange. The `ch18-go` module answers with running code, four
echo servers, tcp, udp, http, and a websocket implemented over the
stdlib alone, 9 tests under `make verify`.

== the stack in one breath [DRILL]

Ip routes packets, no delivery guarantee. Tcp builds a reliable
byte stream on top, ordered, retransmitted, flow and congestion
controlled, connection-oriented. Udp keeps the packet shape, no
ordering, no delivery promise, no connection, which is exactly why
it is the substrate for dns, games, and real-time media. Http is a
request-response protocol over tcp, ws upgrades an http connection
into a framed bidirectional stream, and graphql is a query
protocol riding http post, not a transport.

The contrast the echo servers make executable: the tcp echo is
`io.Copy(c, c)` because tcp has no message boundaries, just bytes
to return, while the udp echo reads one datagram and writes one
datagram back, because boundaries are the one thing udp preserves:

#listing("interview-repertoire/samples/ch18-go/echo.go", first: 55, last: 80, caption: [the udp loop: one packet in, the same packet back to its sender])

#diagram([ip routes, tcp streams, udp keeps boundaries], length: 13pt, {
  // the stack: riders on top, the two transports, ip underneath
  cdraw.rect((5.0, 8.3), (18.0, 9.3), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((11.5, 8.8), [http, ws, graphql], size: 6.5pt)
  cdraw.line((8.5, 8.3), (8.5, 7.65), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.5, 8.3), (14.5, 7.65), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((3.0, 5.8), (11.0, 7.6), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((7.0, 7.15), [tcp], size: 6.5pt)
  cdraw.content((7.0, 6.15), [ordered byte stream], size: 6pt)
  cdraw.rect((13.0, 5.8), (21.0, 7.6), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((17.0, 7.15), [udp], size: 6.5pt)
  cdraw.content((17.0, 6.15), [keeps boundaries], size: 6pt)
  cdraw.line((7.0, 5.8), (7.0, 5.05), stroke: luma(100), mark: (end: ">"))
  cdraw.line((17.0, 5.8), (17.0, 5.05), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((5.0, 3.2), (19.0, 5.0), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((12.0, 4.55), [ip], size: 6.5pt)
  cdraw.content((12.0, 3.55), [routes packets, no delivery promise], size: 6pt)
  cdraw.content((11.5, 2.3), [tcp echo: io.Copy, bytes only], size: 6pt)
  cdraw.content((11.5, 1.3), [udp echo: one datagram in, one back], size: 6pt)
})

The suite pins the difference: three tcp writes on one connection
come back as three reads the caller frames itself, one udp
datagram comes back as exactly one datagram.

== http, the protocol with semantics [EWC]

The http echo answers with the method it saw and the body it
received, which is the whole protocol shape, request line, method,
path, headers, body, response with status:

#listing("interview-repertoire/samples/ch18-go/echo.go", first: 92, last: 103, caption: [the handler that reflects the protocol])

Worth adding unprompted: http/1.1 keep-alive reuses connections,
http/2 multiplexes streams over one tcp connection, http/3 moves
to quic, a udp transport with tls built in, and the go http server
speaks all three through the same handler interface.

#diagram([request in, status out, one handler across versions], length: 13pt, {
  // the protocol shape as a pipeline, the three versions beneath
  cdraw.rect((1.0, 6.2), (10.0, 8.0), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.5, 7.4), [request: method, path,], size: 6pt)
  cdraw.content((5.5, 6.4), [headers, body], size: 6pt)
  cdraw.line((10.0, 7.1), (12.0, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((12.0, 6.2), (17.0, 8.0), fill: luma(205), stroke: luma(120), radius: 0.02)
  cdraw.content((14.5, 7.4), [one], size: 6pt)
  cdraw.content((14.5, 6.4), [handler], size: 6pt)
  cdraw.line((17.0, 7.1), (19.0, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((19.0, 6.2), (23.0, 8.0), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((21.0, 7.4), [status], size: 6pt)
  cdraw.content((21.0, 6.4), [response], size: 6pt)
  cdraw.content((9.5, 4.6), [http/1.1: keep-alive, connection reuse], size: 6pt)
  cdraw.content((9.5, 3.5), [http/2: streams over one connection], size: 6pt)
  cdraw.content((9.5, 2.4), [http/3: quic over udp], size: 6pt)
  cdraw.content((19.9, 4.6), [same handler], size: 6pt)
  cdraw.content((19.9, 3.5), [speaks all three], size: 6pt)
})

== websockets from the metal [TDD]

A websocket is an http handshake followed by a framed protocol,
and the module implements both from the stdlib. The handshake is
the rfc 6455 arithmetic: base64 of sha1 over the client key plus a
fixed guid, no negotiation, just proof:

#listing("interview-repertoire/samples/ch18-go/ws.go", first: 16, last: 48, caption: [the guid, the accept key, the upgrade check and the 101])

The frame codec handles the two header bytes, the extended length
forms, the 4-byte mask on client frames, and the xor unmask, then
the server echoes text and answers pings with pongs:

#listing("interview-repertoire/samples/ch18-go/ws.go", first: 60, last: 104, caption: [frame decode with extended lengths and unmasking])

#diagram([handshake proof, then frames: opcodes, lengths, mask xor], length: 13pt, {
  // left: the rfc arithmetic handshake; right: the five frame fields
  cdraw.content((5.2, 9.0), [the handshake], size: 6.5pt)
  cdraw.rect((0.8, 7.7), (9.6, 8.6), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.2, 8.15), [client sends the key], size: 6pt)
  cdraw.line((5.2, 7.7), (5.2, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.5, 7.1), [sha1(key + guid)], size: 6pt)
  cdraw.rect((0.8, 5.6), (9.6, 6.5), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((5.2, 6.05), [server: 101 + accept], size: 6pt)
  cdraw.content((5.2, 4.5), [no negotiation, just proof], size: 6pt)
  cdraw.content((17.1, 9.0), [the frame, five fields], size: 6.5pt)
  for i in range(5) {
    let x0 = 12.2 + i * 2.0
    cdraw.rect((x0, 7.6), (x0 + 1.8, 8.4), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((x0 + 0.9, 8.0), [#(i + 1)], size: 6pt)
  }
  cdraw.content((17.1, 6.3), [1 opcode and flags, 2 length,], size: 6pt)
  cdraw.content((17.1, 5.3), [3 extended length, 4 mask key,], size: 6pt)
  cdraw.content((17.1, 4.3), [5 payload, xor unmasked], size: 6pt)
  cdraw.content((11.5, 1.4), [the rfc's own vector proves the implementation], size: 6pt)
})

The tests speak the client side over a real socket, masked
payloads, a hand-built 300-byte extended-length frame, and the
rfc's own handshake vector, `dGhlIHNhbXBsZSBub25jZQ==` hashing to
`s3pPLMBiTxaQ9kYGzzhZRbK+xOo=`, which is the check that the
implementation matches the spec rather than itself.

== https, certificates, symmetric versus asymmetric [DRILL]

Https is http inside tls. The handshake: the client hello offers
cipher suites, the server answers with its certificate, the
certificate chains to a root the client already trusts, and that
trust anchor is what a certificate authority sells, a signature
over a domain identity the browser ships. Key agreement lands on a
session secret, then everything else is symmetric encryption,
aes-gcm typically, because symmetric is orders of magnitude
cheaper than asymmetric.

That is the crisp version of the symmetric versus asymmetric
answer: asymmetric, rsa and elliptic curve, solves key agreement
and signatures at handshake scale, symmetric does the bulk traffic
at wire speed, and tls uses each for exactly that. The follow-up
about why the certificate works, the chain of trust, and the one
about what a man in the middle actually breaks, the key exchange,
since the attacker's certificate will not validate against a root
both sides trust.

#diagram([handshake with asymmetric, bulk with symmetric], length: 13pt, {
  // the tls timeline: hello, certificate, chain, secret, then aes-gcm
  cdraw.line((1.5, 4.2), (22.5, 4.2), stroke: luma(100), mark: (end: ">"))
  for x in (3.0, 7.5, 12.0, 16.5, 19.8) {
    cdraw.circle((x, 4.2), radius: 0.1, fill: luma(60))
  }
  cdraw.content((3.0, 5.9), [client hello], size: 6pt)
  cdraw.content((7.5, 4.9), [certificate], size: 6pt)
  cdraw.content((12.0, 5.9), [chain to root], size: 6pt)
  cdraw.content((16.5, 4.9), [session secret], size: 6pt)
  cdraw.content((19.8, 5.9), [aes-gcm bulk], size: 6pt)
  cdraw.content((8.0, 3.0), [asymmetric for the handshake,], size: 6pt)
  cdraw.content((8.0, 1.9), [symmetric for the bulk traffic], size: 6pt)
  cdraw.content((18.5, 3.0), [a mitm cert fails], size: 6pt)
  cdraw.content((18.5, 1.9), [the root check], size: 6pt)
})

== graphql versus rest, said precisely [DRILL]

Rest exposes resources with uniform verbs, graphql exposes one
endpoint and a typed query language over it. The real tradeoffs:
graphql shifts over-fetching and under-fetching from client
guesswork to client choice, concentrates complexity on the server,
and turns the n+1 problem into a resolver-layer problem, as
#xref-to("repertoire", "react-state") demonstrated by counting
queries. Rest keeps caching semantics from http itself,
conditional gets, etags, cdn invalidation, that graphql's single
post endpoint gives up by default. Neither is a transport, both
ride http, and the honest close is that the choice is about where
the query flexibility should live.

#diagram([rest against graphql: where the flexibility lives], length: 13pt, {
  // two columns: uniform verbs and http caching against one typed endpoint
  cdraw.content((6.2, 8.8), [rest], size: 6.5pt)
  cdraw.content((18.0, 8.8), [graphql], size: 6.5pt)
  cdraw.content((6.2, 7.9), [uniform verbs], size: 6pt)
  cdraw.content((18.0, 7.9), [one typed endpoint], size: 6pt)
  cdraw.line((13.2, 3.0), (13.2, 9.2), stroke: luma(220))
  cdraw.content((6.2, 6.4), [resources as urls], size: 6pt)
  cdraw.content((6.2, 5.3), [conditional gets, etags], size: 6pt)
  cdraw.content((6.2, 4.2), [cdn semantics from http], size: 6pt)
  cdraw.content((18.1, 6.4), [client picks exact fields], size: 6pt)
  cdraw.content((18.0, 5.3), [complexity concentrates], size: 6pt)
  cdraw.content((18.2, 4.2), [n+1 moves to resolvers], size: 6pt)
  cdraw.content((11.7, 2.6), [neither is a transport; both ride http], size: 6pt)
  cdraw.content((11.7, 1.5), [the choice is where query flexibility lives], size: 6pt)
})

sources: verified by `go vet` and `go test` through `make verify`,
9 tests in `ch18-go`, real sockets on loopback. Rfc 6455 guid and
handshake vector cited from the websocket protocol, rfc editor,
accessed 2026-09-10.
