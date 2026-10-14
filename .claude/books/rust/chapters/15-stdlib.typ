#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= the standard library

Std is the only dependency this book allows itself, so this chapter
walks it the way the api lane will use it: the four core collections
with measured behavior, strings and the utf-8 boundary discipline, the
io traits, paths, time, localhost sockets, and the environment and
process surface. The no-serde stance is deliberate and standing: the
http kernel in chapter 19 hand-rolls its json parser and serializer
over `str` and `Vec<u8>`, which this chapter's string machinery makes
plain, and the capstone builds its runtime over these same pieces.
Version facts ride the corpus convention: the hash map swapped its
engine for hashbrown in 1.36, `ExitCode` and `Termination` landed in
1.61.

#diagram([std at a glance, the layers this chapter walks], length: 13pt, {
  cdraw.rect((0.3, 3.4), (11.3, 6.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, 5.85), [collections], size: 6.5pt)
  cdraw.content((5.8, 4.9), [Vec, VecDeque, HashMap, BTreeMap,], size: 6pt)
  cdraw.content((5.8, 3.95), [String over the same engine], size: 6pt)
  cdraw.rect((0.3, 0.3), (11.3, 3.0), fill: luma(222), radius: 0.02)
  cdraw.content((5.8, 2.45), [io, fs-shape, path, time], size: 6.5pt)
  cdraw.content((5.8, 1.5), [Read, Write, BufReader, Path, Instant,], size: 6pt)
  cdraw.content((5.8, 0.55), [SystemTime, Duration], size: 6pt)
  cdraw.rect((0.3, -2.8), (11.3, -0.4), fill: luma(235), radius: 0.02)
  cdraw.content((5.8, -0.95), [os surfaces], size: 6.5pt)
  cdraw.content((5.8, -1.9), [TcpListener, TcpStream, env, process], size: 6pt)
  cdraw.line((5.8, 3.05), (5.8, 3.35), stroke: luma(100), mark: (end: ">>"))
  cdraw.line((5.8, 0.05), (5.8, 0.25), stroke: luma(100), mark: (end: ">>"))
  cdraw.content((13.1, 4.9), [HashMap order is,], size: 6pt)
  cdraw.content((13.1, 4.0), [unspecified, printed below], size: 6pt)
  cdraw.content((13.1, 1.5), [traits, so Cursor,], size: 6pt)
  cdraw.content((13.1, 0.6), [stands in for files], size: 6pt)
})

== the core collections

`Vec<T>` is the default container and its growth is amortized
doubling. The sample records every capacity transition over 1000
pushes: measured 2026-10-13, the ladder reads 4, 8, 16, 32, 64, 128,
256, 512, 1024, a 256x span over 9 reallocations, and the length lands
at exactly 1000. Slicing and iteration rules the corpus leans on:
`retain` filters in place, `dedup` only removes adjacent duplicates so
sort first, `chunks` yields a short final chunk.

#listing("rust/samples/src/Ch15/Collections.rs", first: 16, last: 54, caption: [the amortized growth ladder, then retain, dedup, chunks])

`VecDeque<T>` is the ring buffer: push and pop at both ends without
ever moving the elements, the double-ended queue under every work
queue in the book.

#listing("rust/samples/src/Ch15/Collections.rs", first: 56, last: 74, caption: [a ring, drained front to back, then reused at both ends])

`HashMap<K, V>` is a hash table keyed by whatever hashes, backed by
the hashbrown engine since 1.36, with `RandomState` seeding SipHash
1-3 per instance: resistant to key-collision attacks, not an
ordered structure. The entry api is the upsert idiom, one lookup:

#listing("rust/samples/src/Ch15/Collections.rs", first: 76, last: 90, caption: [insert returns the evicted value, entry or_insert upserts])

Iteration order is unspecified and the sample says so with output:
two fresh maps holding the same 12 pairs iterated in two different
orders, `[6, 9, 11, 4, 2, 3, 0, 7, 8, 10, 5, 1]` and `[1, 2, 4, 7,
10, 8, 0, 9, 3, 11, 6, 5]`, neither sorted, measured 2026-10-13. No
assert in this book ever rides on hash order, and different processes
disagree because each instance draws its own seed.

#listing("rust/samples/src/Ch15/Collections.rs", first: 92, last: 121, caption: [two instances, same pairs, printed orders, no order asserts])

`BTreeMap<K, V>` is the ordered map, a b-tree iterating in key order
regardless of insert order, with range queries as tree walks. When
the api lane needs deterministic serialization order in chapter 19,
this is the map it reaches for.

#listing("rust/samples/src/Ch15/Collections.rs", first: 122, last: 139, caption: [ordered iteration, range, and the ends as walks])

== strings and utf-8 boundaries

`String` is a `Vec<u8>` holding guaranteed-valid utf-8, `&str` is a
borrowed slice of the same invariant. One string holds both a byte
length and a code point count and they differ the moment anything is
non-ascii: measured, `héllo 日本語` is 16 bytes and 9 chars, with
boundaries at 0, 1, 3, 4, 5, 6, 7, 10, 13.

#listing("rust/samples/src/Ch15/Strings.rs", first: 27, last: 59, caption: [byte lengths per char, both counts, and the boundary walk])

Slicing is by byte index, and a byte index inside a multi-byte code
point is a panic, the sample measures the exact message:

#snippet("let greeting = \"héllo 日本語\";\nlet broken = &greeting[..2];\n// panicked at: end byte index 2 is not a char boundary;\n// it is inside 'é' (bytes 1..3 of string)", lang: "rust")

The safe pattern is to cut on boundaries you learned from
`char_indices`, which is exactly what the sample's `first_n_chars`
does and what the chapter 19 json parser does with every token.
Validation reports positions rather than failing opaquely, and
`Utf8Error::valid_up_to` is the offset a streaming decoder resumes
from:

#listing("rust/samples/src/Ch15/Strings.rs", first: 61, last: 106, caption: [from_utf8 with positions, unicode case mapping, split and join])

Case mapping is unicode, not ascii: sharp s uppercases to two
characters, measured as the check asserts. `split` keeps empty fields
so csv lines stay positional, `split_whitespace` drops them.

== io: readers and writers

`Read` and `Write` are traits, which is the whole point: a `Vec<u8>`
is a writer, a `Cursor<Vec<u8>>` is a reader and a seeker, and the
same generic code later runs against files and sockets unchanged. The
sample runs the io suite entirely in memory, deterministic to the
byte:

#listing("rust/samples/src/Ch15/IoPaths.rs", first: 17, last: 52, caption: [write into a vec, read_to_string, BufReader lines, read_exact, io::copy])

`BufReader` batches reads and splits lines, `read_exact` fills the
whole buffer or errors, `io::copy` pumps between any reader and
writer and returns the byte count. The socket sample at the bottom of
the chapter writes the same `Write` calls against a `TcpStream`.

== paths

`Path` and `PathBuf` are the borrowed-versus-owned pair for
filesystem spelling, and they carry `OsStr` pieces, not `str`, so a
path survives names that are not valid unicode. Windows semantics
parse into components, measured live:

#listing("rust/samples/src/Ch15/IoPaths.rs", first: 53, last: 100, caption: [file_name, extension, with_extension, join, and the component walk])

Measured 2026-10-13, `C:\Users\lavantien\dev` parses into a disk
prefix, the root dir, and three normal components, and `temp_dir`
yields `C:\Users\LAVANT~1\AppData\Local\Temp\`. Joining an absolute
path replaces the entire prefix, the one join behavior that surprises
everyone once. The api lane's router in chapter 19 matches request
targets with exactly this component walk.

== time

`Duration` is a plain quantity with checked arithmetic, `Instant` is
a monotonic clock for measuring, `SystemTime` is the wall clock with
an epoch and no monotonicity promise. The sample converts both ways,
checks the overflow-aware ops, and measures a real loop:

#listing("rust/samples/src/Ch15/Time.rs", first: 24, last: 60, caption: [duration arithmetic, a measured loop, ns per iteration])

Measured 2026-10-13: 200000 iterations of a wrapping checksum loop
in 837 microseconds, 4.18 ns per iteration, and 1791890295 seconds
since the unix epoch at the sample's run. The chapter 18 bench
discipline is this pattern with more rigor.

#listing("rust/samples/src/Ch15/Time.rs", first: 62, last: 93, caption: [instant ordering, checked_add, and the wall clock])

== sockets: a localhost echo pair

`TcpListener::bind` takes an address and port, and port 0 asks the os
for an ephemeral port, which is how every sample in this corpus
touches the network: no fixed ports, no collisions between sibling
chapters or parallel test runs. The pair below is a complete echo
server and four concurrent clients, joined before a single assert:

#listing("rust/samples/src/Ch15/EchoPair.rs", first: 16, last: 32, caption: [serve_one and request, the whole protocol in two functions])

#listing("rust/samples/src/Ch15/EchoPair.rs", first: 34, last: 78, caption: [ephemeral bind, four concurrent clients, then a fifth sequential])

Measured 2026-10-13: the listener landed on 127.0.0.1:55666, four
scoped clients each received their exact payload back, 19 request
bytes total, and a fifth sequential connection confirms the acceptor
outlives the scope. `shutdown(Write)` is the half-close that turns
`read_to_end` into a bounded wait, the same discipline the http
kernel's client side uses in chapter 19.

== environment and processes

`env::args` starts at argv 0, the program's own path. `set_var` and
`remove_var` are `unsafe` since edition 2024: the process environment
is genuinely global state and mutating it from a multithreaded
program is undefined territory on some platforms, so the edition
makes the caller state the single-threaded discipline. The sample
does its mutation first, before spawning anything:

#listing("rust/samples/src/Ch15/EnvArgs.rs", first: 18, last: 45, caption: [set_var round trip under unsafe, argv and vars counts])

Exit codes close the loop between processes. `main` can return a
`Result` since 1.61 through the `Termination` trait, or call
`process::exit` directly, and a parent reads the code back from
`Command::status`. The sample proves the whole round trip by spawning
its own exe twice with different arguments, once to exit 7 and once
to exit 0:

#listing("rust/samples/src/Ch15/EnvArgs.rs", first: 47, last: 97, caption: [child mode, self spawn, exit codes 7 then 0, missing binary as Err])

Measured 2026-10-13: argv carried 1 entry under the runner, the
environment held 112 entries, both self-spawns reported their exact
codes, and spawning a nonexistent binary is an `Err` rather than a
panic. The integration suite in chapter 31 drives the shipped server
binary through exactly this `Command` surface.

sources: the std api docs read from the offline 1.99.0 html share
under ~/.rustup/toolchains/stable-x86_64-pc-windows-msvc/share/doc/
rust/html, accessed 2026-10-13: the collections module
(doc.rust-lang.org/stable/std/collections/index.html with the Vec,
VecDeque, HashMap, and BTreeMap pages, including the hashbrown note
and the SipHash 1-3 RandomState statement on the HashMap page),
std::str and std::string (doc.rust-lang.org/stable/std/primitive.str.html
and /std/string/struct.String.html), std::io
(doc.rust-lang.org/stable/std/io/index.html with Read, Write,
BufReader, and the copy function), std::path
(doc.rust-lang.org/stable/std/path/index.html with Path, PathBuf, and
Components), std::time
(doc.rust-lang.org/stable/std/time/index.html with Duration,
Instant, and SystemTime), std::net
(doc.rust-lang.org/stable/std/net/index.html with TcpListener and
TcpStream), std::env (doc.rust-lang.org/stable/std/env/index.html,
set_var read with its unsafe signature), and std::process
(doc.rust-lang.org/stable/std/process/index.html with Command and
ExitCode). Version facts verified in
doc.rust-lang.org/stable/releases.md, accessed 2026-10-13: hashbrown
replacing the HashMap implementation in 1.36.0 (2019-07-04),
ExitCode and Termination in 1.61.0 (2022-05-19), and the
edition 2024 unsafe env mutation verified in the edition guide
(doc.rust-lang.org/stable/edition-guide/rust-2024/newly-unsafe-functions.html).
All measurements (capacity ladder 4 through 1024, hash orders of two
12 key instances both non sorted and mutually different, 16 bytes and
9 chars with boundaries, 837 us and 4.18 ns per iteration, 1791890295
epoch seconds, listener on 127.0.0.1:55666 with 19 echoed bytes,
argv 1 entry, 112 environment entries, exit codes 7 then 0, the
utf-8 panic message text) produced by `rust/samples/src/Ch15` under
`pwsh tools/run-rust-samples.ps1 -Chapter Ch15`, dated 2026-10-13 on
the pinned rustc 1.99.0.
