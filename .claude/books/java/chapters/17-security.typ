#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw

= security and cryptography

Java ships its cryptography as an architecture, not a library.
Algorithms are requested by name, `MessageDigest.getInstance("SHA-256")`,
and a chain of providers answers, the jdk's own first and hardware
or third party implementations behind registration. This build
resolves 13 providers, from `SUN` through `SunJCE` and `SunJSSE` to
the Windows `SunMSCAPI` and the `SunPKCS11` bridge, measured by the
sample. The payoff is that no line of this chapter names an
implementation class, and the platform can swap what answers.

== digests and macs

A digest is a one way fingerprint, a mac is a keyed one. Both are
`getInstance` by algorithm, both verify against known answer vectors,
published input and output pairs, which is how the sample proves it
is calling the real algorithm and not something shaped like it:

#listing("java/samples/src/Ch17/Crypto.java", first: 40, last: 57, caption: [the sha-256 vector for abc and the hmac rfc 4231 test case 1])

Digests detect corruption, macs detect tampering, and neither hides
anything, both outputs are public. Encryption comes later in the
chapter.

== secure random

`SecureRandom` is the randomness source for every key and nonce in
this chapter. Its default algorithm on this build is `DRBG`, the
nist deterministic random bit generator, seeded from the operating
system. The determinism check runs the other way, two draws must
differ, and any code that seeds it with a constant or a timestamp is
the vulnerability report of some other book.

== key derivation

Passwords are not keys, they are low entropy strings, and turning
them into key material needs a function that is deliberately
expensive. PBKDF2, `SecretKeyFactory` with `PBKDF2WithHmacSHA256`,
takes the password, a random salt, an iteration count, and an output
width:

#listing("java/samples/src/Ch17/Crypto.java", first: 69, last: 90, caption: [salted, iterated derivation with the same-salt determinism checks])

The salt kills precomputed rainbow tables, the iteration count makes
each guess cost the attacker the same tens of milliseconds it costs
you once, measured in the sample, and the width feeds an aes key
directly. Chapter 22's authn pipeline derives its stored verifier
exactly this way.

For high entropy input, raw key material rather than passwords, java
25 finalized the key derivation function api (JEP 510) with HKDF as
the bundled function. On this build SunJCE answers with
`HKDF-SHA256`, `HKDF-SHA384`, and `HKDF-SHA512`:

#listing("java/samples/src/Ch17/Crypto.java", first: 91, last: 106, caption: [extract then expand through the builder, deriveKey and deriveData])

The shape is extract, squeeze the input into a pseudorandom key, then
expand, stretch that key into as much output as needed with an info
label for domain separation. It is the derivation style of modern
protocols, TLS 1.3 included.

== aes-gcm

Authenticated encryption in one primitive: `AES/GCM/NoPadding` takes
a key, a unique nonce, and produces ciphertext with a 16 byte
authentication tag appended, tampering fails the tag instead of
decrypting to garbage:

#listing("java/samples/src/Ch17/Crypto.java", first: 107, last: 133, caption: [the round trip, the appended tag, the tamper failure, and the refused nonce reuse])

The measured facts: the ciphertext is exactly 16 bytes longer than
the plaintext, a single flipped bit raises `AEADBadTagException`, and
re-initializing encryption with the same key and nonce throws
`InvalidAlgorithmParameterException: Cannot reuse iv for GCM
encryption`, SunJCE tracks nonces per key and refuses the classic
sin at the api level. GCM with a repeated nonce is a catastrophe, the
authentication key leaks, and the platform simply will not do it.

== tls end to end

The transport layer rides the same provider architecture through
`SunJSSE`. The sample builds the whole stack live: `keytool` mints a
self signed certificate into a pkcs12 keystore with the loopback
address as a subject alternative name, `KeyManagerFactory` hands the
server side to an `SSLContext`, and the client trusts exactly that
one certificate, the pinning pattern, instead of a store of public
authorities:

#listing("java/samples/src/Ch17/Tls.java", first: 72, last: 93, caption: [a trust manager that accepts one certificate, and the context wiring])

#listing("java/samples/src/Ch17/Tls.java", first: 123, last: 136, caption: [a raw ssl socket client, protocol and suite read off the session])

Three clients then ride the same listener: the raw `SSLSocket`
negotiating TLSv1.3 with the `TLS_AES_256_GCM_SHA384` suite, measured,
the `java.net.http` client from chapter 14 over the same pinned
context, and the 1996 era `HttpsURLConnection`, which still works and
still has no reason to be chosen.

Java 27 turns on post-quantum key exchange by default (JEP 527). The
hybrid group `X25519MLKEM768`, elliptic curve X25519 multiplied with
the ML-KEM lattice scheme from FIPS 203, is the first entry in the
default named group list, measured on a fresh client socket,
followed by the classic groups, `x25519`, `secp256r1`, the ffdhe
family. A tls 1.3 client offers key shares for the hybrid and for
`x25519` together, so a peer that lacks the hybrid falls back without
a failed handshake. Opting out means `jdk.tls.namedGroups` or
`SSLParameters.setNamedGroups`, pinning the traditional list.

Two adjacent 27 facts, verified live in the sample: PEM encodings of
cryptographic objects (JEP 538) are in their third preview, the
`java.security.PEMEncoder` and `PEMDecoder` types compile only under
`--enable-preview --release 27` and refuse without it with `PEMEncoder
is a preview API`, and the preview run prints real RFC 7468 output,
`-----BEGIN PUBLIC KEY-----`. And the key derivation api note above
is the settled sibling, final since 25.

#callout("verify", "protocol facts are build facts", [
  The first-named group, the negotiated suite, the refusal text for
  iv reuse, these are this build's behavior, printed with dates by
  the samples. The specification fixes less than the output suggests,
  a different provider order or a disabled algorithm list shifts
  them.
])

== the security manager's exit

The sandbox api had a long goodbye: deprecated for removal in java 17
(JEP 411), permanently disabled in java 24 (JEP 486). On 27 the
measured behavior is blunt, `System.getSecurityManager` always
returns null and `System.setSecurityManager` throws
`UnsupportedOperationException`, and the deliberate probe of the
second is the one place in this book's samples that carries a
`@SuppressWarnings("removal")`, because `-Xlint:all -Werror` flags
any touch of removal marked api and the touch is the point:

#listing("java/samples/src/Ch17/Crypto.java", first: 145, last: 153, caption: [the null and the throw, the whole remaining surface])

There is no replacement sandbox inside the jdk, the position is that
isolation belongs to the operating system, containers, hypervisors,
and process boundaries. What remains of the security package is the
cryptography above and the policy free `AccessController` remnants
scheduled to follow the manager out.

sources: openjdk.org/jeps/510 (key derivation function api final in
25, HKDF), /jeps/527 (post-quantum hybrid key exchange default in 27,
X25519MLKEM768 ordering and opt outs), /jeps/538 (pem encodings third
preview in 27), /jeps/411 (deprecate security manager, 17) and
/jeps/486 (permanently disable it, 24), all accessed 2026-10-04, RFC
4231 (identifying hmac test vectors, rfc-editor.org), RFC 7468 (pem
text encoding), docs.oracle.com javadoc for `javax.crypto.KDF`,
`HKDFParameterSpec`, and `Cipher` on java 27. Behavior verified live
on `tools/jdk27/build/jdk-27` by the Ch17 samples under `pwsh
tools/run-java-samples.ps1 -Chapter Ch17`: 30 checks, Crypto 19 and
Tls 11, covering both known answer vectors, the drbg default, the
pbkdf2 cost in milliseconds, hkdf determinism, the gcm tag length,
tamper failure and nonce reuse refusal, the full tls 1.3 exchange
over a keytool minted certificate with three clients, the
X25519MLKEM768 default group order, the pem preview refusal and
acceptance, and the security manager null and throw, all dated
2026-10-04.
