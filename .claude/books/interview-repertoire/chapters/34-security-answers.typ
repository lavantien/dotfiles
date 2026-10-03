#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw

= security answers: the named taxonomy

The security round is a naming round. Handed a broken endpoint or a
leaky page, the scoring move is to name the family first, because the
family names the fix and the fix names the test that proves it. This
chapter owns the web families the six service lanes floor elsewhere
and the rehearsal book had no chapter for: xss, csrf, cors, the
injection grammar, and the response headers. The `ch34-js` workspace
runs the models under `node --test`, 14 tests, and the models are
honest about being hand-modeled spec shapes, not a browser and not a
database.

== the taxonomy, owasp-shaped [DRILL]

The OWASP Top 10 is the shared vocabulary and the 2025 edition moved
the entries around, so quote it by name and year (OWASP, "Top 10:2025",
fetched 2026-09-29): broken access control still holds the top spot,
security misconfiguration sits second, supply chain failures entered
third, cryptographic failures fourth, and injection fell from third
in 2021 to fifth. The numbers drift, the families do not, and the
interview answer rides the family. When handed a vulnerability, name
the class, then the fix, then the floor in this corpus: broken access
control means authorization was checked at the route and not at the
object, floored by the six authz chapters, #xref-to("go", "authz")
first among them. Injection means input reached a parser as grammar,
floored by the parameterized store chapters of the six service parts.
Cryptographic failures mean a hash, a comparison, or a key choice was
wrong, floored by the authn lanes this chapter re-quotes below.
Xss, csrf, and cors are this chapter's own. Ssrf, the server fetching
a url an attacker controls, gets named here and floored on the kernel
and middleware chapters of the six service parts, where the honest
defense lives: allowlist the egress destinations, refuse to fetch
user-supplied urls, pin the scheme.

#diagram([name the family, the family names the fix, the fix names the floor], length: 13pt, {
  // three columns: the family, the defense, the corpus floor
  cdraw.content((3.6, 9.6), [the family], size: 6.5pt, fill: luma(100))
  cdraw.content((11.6, 9.6), [the defense], size: 6.5pt, fill: luma(100))
  cdraw.content((19.6, 9.6), [the floor], size: 6.5pt, fill: luma(100))
  let row(y, family, defense, floor) = {
    cdraw.rect((0.3, y), (6.4, y + 1.1), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((3.35, y + 0.55), [#family], size: 6pt)
    cdraw.rect((7.0, y), (15.9, y + 1.1), fill: luma(245), stroke: luma(120), radius: 0.02)
    cdraw.content((11.45, y + 0.55), [#defense], size: 6pt)
    cdraw.rect((16.5, y), (23.2, y + 1.1), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content((19.85, y + 0.55), [#floor], size: 6pt)
    cdraw.line((6.4, y + 0.55), (7.0, y + 0.55), stroke: luma(100), mark: (end: ">"))
    cdraw.line((15.9, y + 0.55), (16.5, y + 0.55), stroke: luma(100), mark: (end: ">"))
  }
  row(7.6, [broken access control], [authorize objects, not routes], [the six authz chapters])
  row(5.9, [injection], [placeholders, grammar first], [the store chapters])
  row(4.2, [cryptographic failures], [argon2id, scrypt, or pbkdf2], [the authn lanes])
  row(2.5, [xss, csrf, cors], [escape, tokens, the origin rule], [this chapter])
  row(0.8, [ssrf], [allowlisted egress, no user urls], [the kernel chapters])
})

== xss and csrf [TDD]

Xss is a context problem, which is why one universal sanitizer is the
wrong answer. The same payload string is inert in a text node, a
breakout attempt inside a quoted attribute, and a scheme execution in
a url sink, and each surface has its own escape. The workspace walks
all three:

#listing("interview-repertoire/samples/ch34-js/src/escape.mjs", first: 11, last: 42, caption: [text entities, the attribute quotes that close the boundary, and the url scheme allowlist with the whitespace browsers strip])

The spoken taxonomy: stored xss persists the payload in the database
and fires for every viewer, reflected xss rides the request back into
the page, dom-based xss never leaves the browser, a sink like
innerHTML writing a value the server never saw. The fix tracks the
sink, not the source, and the honest concession is that the model
escapes strings, it does not run a parser.

Csrf exploits the browser, not the user: the attacker's page cannot
read your cookies across origins, but it can make the browser attach
them to a forged request. The double-submit defense demands something
an attacker's page cannot supply, an echo of a token it was never
allowed to read:

#listing("interview-repertoire/samples/ch34-js/src/csrf.mjs", first: 13, last: 31, caption: [the timing-safe compare, every byte read into one accumulator, the read count riding the return so the test proves no early exit])

The compare must be timing-safe or the defense leaks a matching
prefix through response time, one byte of the token confirmed per
forged request. The test drives a first-byte mismatch and asserts the
model still read every byte. SameSite=Lax is the modern first line,
the browser declines to attach the cookie to cross-site posts, and it
kills most csrf with no code at all. The trap it leaves open:

#callout("pitfall", "Lax still rides top-level navigation", [
  Lax sends the cookie on top-level navigation with safe methods, so
  an endpoint that mutates state on GET keeps the csrf hole open even
  with Lax everywhere. State changes belong behind non-safe methods,
  and the token pair stays as the second lock. And the classic trap
  question, can CORS prevent csrf: no, CORS is a read relaxation, the
  browser sends the forged request regardless and CORS only decides
  whether the attacker's page may read the response, and simple
  requests fly without a preflight at all.
])

== cors and the same-origin rule [TDD]

The same-origin policy is the browser's default isolation: a script
on one origin may not read a response from another. Cors is the
relaxation mechanism, and the whole subject reduces to one triple and
one decision. The triple:

#listing("interview-repertoire/samples/ch34-js/src/origin.mjs", first: 8, last: 27, caption: [the origin triple with the https 443 and http 80 defaults filled in before any comparison])

The traps the triple sets: scheme differs means origin differs, so
https on 443 and http on 80 are two origins on one hostname, and
subdomains are different origins outright, `app.example.com` is not
`example.com`. The decision is which requests preflight. Per MDN
("Cross-Origin Resource Sharing", fetched 2026-09-29), a request
flies without preflight only when the method is GET, HEAD, or POST,
every header is on the safelist, accept, accept-language,
content-language, content-type, range, and the content type is one of
the three form values. Everything else sends an OPTIONS first:

#listing("interview-repertoire/samples/ch34-js/src/origin.mjs", first: 29, last: 58, caption: [the preflight triggers, then the response decision: exact-origin echo, the anonymous wildcard, and the credentials error])

The response table the interviewer wants: an allowed origin gets its
exact origin echoed in ACAO, the wildcard serves anonymous reads
only, and the wildcard with credentials is the error row, the browser
refuses the combination outright, so credentialed cross-origin reads
need the echo plus `Access-Control-Allow-Credentials: true`.

#diagram([the two lanes: simple requests fly, everything else asks first], length: 13pt, {
  // top lane: the simple path, bottom lane: the preflighted path
  let box(x0, y0, x1, y1, t, sub, fill: luma(235)) = {
    cdraw.rect((x0, y0), (x1, y1), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, y0 + (y1 - y0) * 0.62), [#t], size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, y0 + (y1 - y0) * 0.26), [#sub], size: 6pt)
  }
  cdraw.content((11.5, 9.7), [simple: GET, HEAD, or a form post], size: 6.5pt, fill: luma(100))
  box(0.4, 7.7, 5.2, 9.1, [sent at once], [with Origin attached])
  box(6.6, 7.7, 11.4, 9.1, [server decides], [echo, wildcard, omit])
  box(12.8, 7.7, 18.2, 9.1, [response lands], [readable if echoed])
  box(19.6, 7.7, 23.2, 9.1, [if omitted], [nothing readable], fill: luma(215))
  cdraw.line((5.2, 8.4), (6.6, 8.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.4, 8.4), (12.8, 8.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.2, 8.4), (19.6, 8.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.5, 6.9), [custom header, non-simple method, json body], size: 6.5pt, fill: luma(100))
  box(0.4, 4.9, 5.2, 6.3, [OPTIONS first], [asks method, headers], fill: luma(245))
  box(6.6, 4.9, 11.4, 6.3, [server answers], [ACAO, allow-headers])
  box(12.8, 4.9, 18.2, 6.3, [the real request], [carries the cookies])
  box(19.6, 4.9, 23.2, 6.3, [it fires], [answer or not], fill: luma(215))
  cdraw.line((5.2, 5.6), (6.6, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.4, 5.6), (12.8, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.2, 5.6), (19.6, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.5, 3.6), [the preflight asks permission before the request that matters], size: 6pt)
  cdraw.content((11.5, 2.6), [credentialed reads never get the wildcard, the exact origin echoes], size: 6pt)
})

== sql injection [TDD]

The one-sentence version interviewers keep scoring: concatenation
lets input change the grammar of the query, placeholders decide the
grammar before any input exists. The workspace models the taint, and
the classic payload rides inside the listing where it belongs:

#listing("interview-repertoire/samples/ch34-js/src/query.mjs", first: 7, last: 19, caption: [the taint model: concatenation tainted by construction, the placeholder version with the sql text fixed])

#listing("interview-repertoire/samples/ch34-js/src/query.test.mjs", first: 5, last: 15, caption: [the payload closing the quote, splicing the always-true OR, and commenting out the tail])

Read the defeat aloud: the payload closes the string literal the
template opened, splices an OR over a tautology, and the comment
swallows the closing quote, so the predicate is true for every row.
The parameterized version is indifferent to the same bytes, the sql
text never changes, and the payload arrives at the engine as an
ordinary string value that matches no name in the table. The
follow-up is second-order injection: a payload stored safely through
placeholders can still detonate later when a different code path
concatenates it back out of the database, which is why the fix is
parameterization everywhere rather than sanitizing input at the door.
The floors are real: the store chapters of the six service parts run
prepared statements against real engines, and the query side of the
rehearsal is #xref-to("repertoire", "db-answers"). The concession
stands, this model flags strings, it does not parse sql.

== security headers: csp, hsts, and friends [TDD]

Headers are the defense you can read in a curl. Csp restricts what a
page may load and execute, hsts pins the transport, and the workspace
parses both as data:

#listing("interview-repertoire/samples/ch34-js/src/headers.mjs", first: 7, last: 42, caption: [csp directives with the script-src reading and its default-src fallback, the nonce-ignores-unsafe-inline case, and the hsts parse with the preload bar])

Two facts carry the Csp questions. `unsafe-inline` defeats the script
policy, MDN is blunt about it ("Content-Security-Policy", fetched
2026-09-29: developers should avoid `'unsafe-inline'` because it
defeats much of the purpose of having a CSP). And the quieter trap:
a nonce or hash beside `unsafe-inline` makes the browser ignore the
keyword, so a policy carrying both has silently changed meaning
rather than failed. Hsts parses to three knobs, max-age in seconds,
includeSubDomains extending the policy down the host, and preload,
whose browser lists demand one year of max-age plus subdomains (MDN,
"Strict-Transport-Security", fetched 2026-09-29). The spoken ladder
the round actually tests: same-origin policy, CORS, and CSP are three
different things. SOP is the browser's default isolation, CORS
relaxes who may read across origins, CSP restricts what a page may
load inside its own origin. Confusing any two is the fail marker.

#diagram([the layers are concentric: each one assumes the layer outside it held], length: 13pt, {
  // nested bands: hsts, the origin rules, csp, escaping at the center
  cdraw.rect((0.5, 1.6), (22.5, 9.6), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((11.5, 9.0), [hsts: https only, the transport pinned], size: 6pt)
  cdraw.rect((2.4, 2.6), (20.6, 8.2), fill: luma(235), stroke: luma(120), radius: 0.02)
  cdraw.content((11.5, 7.6), [the origin rules: sop default, cors relaxation], size: 6pt)
  cdraw.rect((4.6, 3.6), (18.4, 6.8), fill: luma(225), stroke: luma(120), radius: 0.02)
  cdraw.content((11.5, 6.2), [csp: what this page may load and run], size: 6pt)
  cdraw.rect((6.8, 4.3), (16.2, 5.4), fill: luma(215), stroke: luma(120), radius: 0.02)
  cdraw.content((11.5, 4.85), [escaping the values, by context], size: 6pt)
  cdraw.content((11.5, 0.8), [no https and the origin rules are spoofable, no csp and one injected tag runs], size: 6pt)
})

== authn, authz, tokens: oauth and oidc at interview altitude [DRILL]

The six lanes each built the same spine and chose their hash on
platform honesty, so name the lane and its choice: go runs argon2id
with EdDSA tokens, #xref-to("go", "authn"). C sharp runs
`Rfc2898DeriveBytes.Pbkdf2` and ES256, its reader pinning the
algorithm before any payload byte is trusted so the classic
algorithm-confusion attack dies at the door, #xref-to("csharp-net",
"authn"). Javascript runs scrypt at `N=2^17`, 128 MiB of memory
against gpu farms, with ed25519 for signatures. Python runs
`hashlib.pbkdf2_hmac`, salted sha256 iterated 210000 times. Lua builds
sha-256 by hand and chains hmac and pbkdf2 over it. The c lane walks
the whole ladder, sha-256, then hmac, then pbkdf2, each floor built
before the next composes it. Bcrypt gets named honestly on the OWASP
row (Password Storage Cheat Sheet, fetched 2026-09-29): argon2id
first, minimum 19 MiB of memory at two iterations, scrypt the
fallback, bcrypt for legacy only, work factor at least 10, and its
72-byte input cap is the reason a bcrypt password field maxes there,
the pedigree and the cap both worth saying out loud. Memory-hardness
is why argon2id won the recommendation, it prices gpu attack the way
bcrypt could not.

The authz half is one set of answers across all six lanes. 401 versus
403: unauthenticated versus authenticated and still refused. IDOR,
insecure direct object reference, is authorization missing at the
object level, the route checked the session but never asked whether
that session owns the id in the path. Deny by default means the route
audit exists and fails when a new route appears ungated, and the rbac
matrix is a test, not a wiki page, #xref-to("go", "authz"). Token
format: JWT versus PASETO is floored on #xref-to("cookbook",
"repo-order"), whose answer is the pinned algorithm and the encrypted
payload. Oauth 2.0 is delegated authorization, not authentication,
RFC 6749's four roles (fetched 2026-09-29) are resource owner,
client, authorization server, resource server, and none of them
assert who the user is. OIDC is the authentication layer on top, the
id token "represents the outcome of an authentication process"
(OpenID Foundation, "How OpenID Connect Works", fetched 2026-09-29).
The spoken flow is authorization code plus PKCE: the code is
short-lived, single-use, delivered through the browser channel, and
exchanged server-side, while PKCE's verifier and challenge close the
code-interception hole for clients that cannot hold a secret. Key
exchange belongs to the math: #xref-to("math", "actions") builds
diffie-hellman in the open and ends with the sentence this book
repeats, never build crypto from a textbook toy.

#diagram([the hash lane proves who you are once, the token lane carries the proof per request], length: 13pt, {
  // top strip: password to stored string to verify, bottom strip: the token's three dots
  let box(x0, x1, t, sub, fill: luma(235)) = {
    cdraw.rect((x0, 7.4), (x1, 9.2), fill: fill, stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 8.55), [#t], size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, 7.85), [#sub], size: 6pt)
  }
  box(0.4, 3.6, [password], [never stored])
  cdraw.line((3.6, 8.3), (4.5, 8.3), stroke: luma(100), mark: (end: ">"))
  box(4.5, 10.7, [salt + hash], [argon2id, scrypt, pbkdf2])
  cdraw.line((10.7, 8.3), (11.6, 8.3), stroke: luma(100), mark: (end: ">"))
  box(11.6, 17.2, [stored string], [params ride beside], fill: luma(245))
  cdraw.line((17.2, 8.3), (18.1, 8.3), stroke: luma(100), mark: (end: ">"))
  box(18.1, 23.2, [verify], [re-derive, compare])
  let part(x0, x1, t, sub) = {
    cdraw.rect((x0, 4.6), (x1, 6.4), fill: luma(235), stroke: luma(120), radius: 0.02)
    cdraw.content(((x0 + x1) / 2, 5.75), [#t], size: 6.5pt)
    cdraw.content(((x0 + x1) / 2, 5.05), [#sub], size: 6pt)
  }
  part(0.4, 6.0, [header], [alg, typ])
  cdraw.content((6.55, 5.5), [.], size: 9pt)
  part(7.1, 12.7, [payload], [the claims])
  cdraw.content((13.25, 5.5), [.], size: 9pt)
  part(13.8, 19.4, [signature], [over both parts])
  cdraw.line((19.4, 5.5), (20.0, 5.5), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((20.0, 4.6), (23.2, 6.4), fill: luma(245), stroke: luma(120), radius: 0.02)
  cdraw.content((21.6, 5.75), [the wire], size: 6.5pt)
  cdraw.content((21.6, 5.05), [three parts], size: 6pt)
  cdraw.content((11.5, 3.4), [the signature is over the bytes, dots included, padding stripped], size: 6pt)
  cdraw.content((11.5, 2.4), [one stored secret, per-request proof, refresh rotation on reuse], size: 6pt)
})

== attack rounds [DRILL]

The strongest security answer is a test someone ran. This corpus
proved its own lanes three ways worth quoting by name. Go holds
forgery resistance as a fuzz target, `FuzzJWTParse` feeding mutated
tokens to the verifier and holding the alg pin through all of them,
#xref-to("go", "suite"). C sharp runs the ETag duel over the wire,
two racing writers and a conditional request referee deciding which
byte wins, #xref-to("csharp-net", "conc"). Lua replays the four
vector scenarios, the happy walk, the login limits, the refresh
reuse attack, and the roles story, each on its own fresh fixture
because the fourth acts with the session the third revoked,
#xref-to("lua", "suite"). Rate limiting belongs in the same breath,
the bucket and the 429 contract floored by #xref-to("go", "limit").
And the meta-answer for any find-the-vulnerability prompt, the three
sentences that end the round: name the class, name the fix, name the
test that proves it. The first sentence earns the vocabulary, the
second earns the engineering, the third earns the job.

sources: verified by `npm run verify` under node 26.3.0, 14 tests in
`ch34-js`, and the models are hand-modeled spec shapes, not a browser
and not a database. The lanes floor the spine: go's argon2id and
EdDSA chapters at #xref-to("go", "authn") with its authz and limit
chapters beside them, c sharp's Rfc2898 and ES256 lane at
#xref-to("csharp-net", "authn"), javascript's scrypt and ed25519
lane, python's 210000-iteration pbkdf2 lane, lua's hand-built hmac
and pbkdf2 lane, and the c lane's sha256, hmac, pbkdf2 ladder.
Https floors to #xref-to("repertoire", "network-answers"), PASETO
versus JWT to #xref-to("cookbook", "repo-order"), key exchange and
the never-build-toys sentence to #xref-to("math", "actions"). Online
claims verified 2026-09-29: MDN's CORS, CSP, and HSTS pages, OWASP's
Top 10:2025 and Password Storage Cheat Sheet, RFC 6749, and the
OpenID Foundation's OIDC overview, each cited where it lands above
with its access date.
