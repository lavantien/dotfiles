#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, xref-to

= files and serialization

Programs that stop when the process stops are demos. Everything in
this chapter persists bytes and reads them back: paths as objects,
text streams with their newline and encoding machinery, csv and json
as the interchange formats, pickle as the python-native one with its
protocol raised to 5 in 3.14, and tempfile as the staging layer that
makes writes atomic. The windows facts are stated as windows facts:
this machine writes `\r\n`, `os.linesep` says so, and the samples
assert the bytes on disk rather than hoping. The gate runs the four
samples under `Ch15/`, 67 `ok` lines in total, every file a scratch
tree under `tempfile.mkdtemp()` that the sample removes behind
itself.

== pathlib

A path in python is an object with algebra. The `/` operator composes
segments, division by a plain string works the same as division by a
path, and an absolute right operand discards everything to its left,
which is the composing rule people guess wrong first. The pure
classes, `PurePosixPath` and `PureWindowsPath`, parse without
touching the disk, and they interconvert when mixed, so windows
flavour wins on the machine that runs this book:

#listing("python/samples/src/Ch15/pathlib_basics.py", first: 18, last: 48, caption: [pure paths: anchor, drive, suffix, stem, the / operator, and the absolute right operand])

The decomposition API answers the questions string splitting gets
wrong. `parts` walks the drive first on windows, `suffixes` stacks
`.tar` then `.gz`, and `with_name` swaps the final segment. The
concrete class on this platform is `WindowsPath`, `Path.cwd()` and
`Path.home()` return absolute existing paths, and the glob methods
stay where they are told: `glob` reads one directory, `rglob`
recurses:

#listing("python/samples/src/Ch15/pathlib_basics.py", first: 50, last: 89, caption: [parts and suffixes, the concrete windows flavour, glob versus rglob])

Reading and writing ride the same objects. `read_text` and
`write_text` open and close the file for you, and the signature page
notes the newest parameter: `Path.read_text(encoding=None, errors=None,
newline=None)`, with "Changed in version 3.13: The `newline`
parameter was added." The sample writes with the default and reads
the bytes back to show what translation did, the subject of the next
section in one check:

#listing("python/samples/src/Ch15/pathlib_basics.py", first: 91, last: 117, caption: [read\_text and write\_text, the newline that reached disk, and os functions taking Path objects])

#diagram([the pathlib surface as a matrix: pure versus concrete, by operation], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(240)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 7.6, 6.6, 1.0, [parse only: PurePosixPath, PureWindowsPath], fill: luma(215))
  cell(8.0, 7.6, 6.6, 1.0, [touch the disk: Path, WindowsPath here], fill: luma(215))
  cell(15.4, 7.6, 6.6, 1.0, [both accept / and .parts], fill: luma(215))
  cell(0.6, 6.2, 6.6, 1.0, [anchor, drive, suffix, stem])
  cell(8.0, 6.2, 6.6, 1.0, [cwd(), home(), exists()])
  cell(15.4, 6.2, 6.6, 1.0, [suffixes, with\_name, parents])
  cell(0.6, 4.8, 6.6, 1.0, [no syscalls at all])
  cell(8.0, 4.8, 6.6, 1.0, [glob, rglob, read\_bytes])
  cell(15.4, 4.8, 6.6, 1.0, [read\_text, write\_text, mkdir])
  cell(0.6, 3.4, 21.4, 1.0, [windows paths: backslash display, both separators accepted on input, drive letters anchor the path], fill: luma(230))
  cdraw.content((11.3, 2.2), [Path() picks the flavour of the running platform, probed: WindowsPath on this machine], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.3, 1.2), [mixing pure flavours converts rightward: the windows side wins on the windows build], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== open, text vs binary

Text mode is a translation layer, and the `open()` page states both
directions. Reading: "if `newline` is None, universal newlines mode
is enabled. Lines in the input can end in `\n`, `\r`, or `\r\n`, and
these are translated into `\n` before being returned to the caller.
If it is '', universal newlines mode is enabled, but line endings are
returned to the caller untranslated." Writing: "if `newline` is None,
any `\n` characters written are translated to the system default
line separator, `os.linesep`. If `newline` is '' or '\n', no
translation takes place." On this machine `os.linesep` is `\r\n`,
and the sample asserts the translation at the byte level in both
directions:

#listing("python/samples/src/Ch15/text_binary.py", first: 22, last: 44, caption: [the newline contract on windows: lf out, cr lf on disk, lf back in])

Encoding is the other half of the layer, and the habit this book
enforces is passing it explicitly every time. A utf-8 file with
accents is 13 bytes on disk and 11 characters in memory, the sample
asserts both numbers, and an intentionally wrong `ascii` read fails
with `UnicodeDecodeError` instead of guessing, which is the correct
behavior for text that is not what the reader claims. The bytes side
of the house is #xref-to("python", "strings") territory, here it is
the control group: binary mode moves the exact bytes, and its `tell`
and `seek` are plain byte offsets:

#listing("python/samples/src/Ch15/text_binary.py", first: 46, last: 89, caption: [encoding round trips, the loud wrong-decode failure, byte offsets versus text cookies])

The mode string packs several facts at once and the sample covers
the remaining ones: `a` appends without truncating, `w+` truncates
then reads, and `buffering=0` on a binary stream hands back the raw
`FileIO` object where the default wraps a `BufferedReader`. One
hazard belongs beside the modes: a text stream's `tell()` returns an
opaque cookie that happens to be a byte offset on this build, the
sample asserts the equality to the byte length, but the docs' word
for the value is a cookie and code that does arithmetic on it is
code that has already decided to be fragile:

#listing("python/samples/src/Ch15/text_binary.py", first: 91, last: 114, caption: [append, w+, and the buffering levels as object types])

#diagram([one write, before and after the translation layers], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.8, 6.0, [f.write("one\ntwo\n")], fill: luma(205))
  box(8.6, 6.8, 6.0, [newline=None: translate])
  box(15.2, 6.8, 6.0, [disk: one\r\ntwo\r\n])
  cdraw.line((6.6, 7.3), (8.6, 7.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.6, 7.3), (15.2, 7.3), stroke: luma(100), mark: (end: ">"))
  box(0.6, 4.6, 6.0, [b"0123... written], fill: luma(205))
  box(8.6, 4.6, 6.0, [mode rb or wb])
  box(15.2, 4.6, 6.0, [disk: the same bytes])
  cdraw.line((6.6, 5.1), (8.6, 5.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.6, 5.1), (15.2, 5.1), stroke: luma(100), mark: (end: ">"))
  box(0.6, 2.4, 6.0, ["héllo wörld" written], fill: luma(205))
  box(8.6, 2.4, 6.0, [encoding="utf-8"])
  box(15.2, 2.4, 6.0, [disk: 13 bytes, 2 per accent])
  cdraw.line((6.6, 2.9), (8.6, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.6, 2.9), (15.2, 2.9), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.5, 1.0), [reading runs the same layers backwards, newline=None folds every ending to lf], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.5, 0.2), [csv is the odd one out: it wants newline="" so it can place its own \r\n], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== csv and json

The csv module writes its own line endings, `\r\n` per the excel
dialect, so the file must be opened with translation off. The
reference says it in one clause: "If csvfile is a file object, it
should be opened with `newline=''`." The sample obeys on the write
side and then deliberately disobeys once, and the naive file on disk
carries `\r\r\n` per row, the double translation, exactly what the
docs warn about:

#listing("python/samples/src/Ch15/csv_json.py", first: 27, last: 61, caption: [dictwriter with newline empty, then the same write without it: cr cr lf on disk])

Dialects are parameter sets, `excel` is the default, and the sample
builds one with a semicolon delimiter and `QUOTE_ALL` into a
`StringIO` to show the dial turning without a disk in sight.
Quoting itself is minimal by default: a comma in a field forces
quotes, a quote inside doubles it, and the round trip through
`DictReader` restores the originals:

#listing("python/samples/src/Ch15/csv_json.py", first: 63, last: 75, caption: [excel as the default dialect, and a custom one against StringIO])

Json is the interchange format and its conversion rules are where
the surprises live. The sample walks the trap row by row: keys that
are not strings become strings, and a dict holding both `1` and
`"1"` serializes to a document with the same key twice, where the
decoder keeps the last, tuples come back as lists, and sets are
refused with `TypeError`. The escape hatch for the last case is the
`default=` hook, which receives each unknown object and returns
something serializable:

#listing("python/samples/src/Ch15/csv_json.py", first: 92, last: 120, caption: [the implicit conversions and the default hook catching a set])

#callout("pitfall", "the duplicated json key is legal and loses data", [
  `json.dumps({1: "a", "1": "b"})` produces `{"1": "a", "1": "b"}`,
  a document with one key spelled twice. It is valid json and the
  decoder resolves it deterministically, the last value wins, so the
  round trip is silently lossy for the first. The check names the
  exact output bytes so the behavior is pinned, not folklore. The
  cure is upstream: keep mapping keys as strings before they reach
  the serializer.
])

#diagram([rows through the interchange pipeline, both formats end as text on disk], length: 13pt, {
  let box(x, y, w, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 6.6, 5.0, [python values], fill: luma(205))
  box(6.8, 7.4, 5.0, [csv.DictWriter])
  box(6.8, 5.8, 5.0, [json.dumps])
  box(13.0, 7.4, 5.0, [comma text, quoted, #linebreak() cr lf rows])
  box(13.0, 5.8, 5.0, [json text, escaped, #linebreak] + [ one line per record])
  box(19.2, 6.6, 2.6, [disk], fill: luma(215))
  cdraw.line((5.6, 7.1), (6.8, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((5.6, 7.1), (6.8, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.8, 7.9), (13.0, 7.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.8, 6.3), (13.0, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.0, 7.9), (19.2, 7.1), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.0, 6.3), (19.2, 6.9), stroke: luma(100), mark: (end: ">"))
  box(6.8, 3.6, 5.0, [csv.DictReader])
  box(6.8, 2.0, 5.0, [json.loads])
  cdraw.line((19.2, 6.2), (19.2, 4.1), (13.0, 4.1), stroke: (paint: luma(140), dash: "dashed"))
  cdraw.line((13.0, 4.1), (11.8, 4.1), (11.8, 4.1), stroke: (paint: luma(140), dash: "dashed"), mark: (end: "<"))
  cdraw.line((13.0, 2.5), (11.8, 2.5), stroke: luma(100), mark: (end: "<"))
  cdraw.content((3.1, 3.6), [values back], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.5, 0.6), [traps: int keys become strings and collide, tuples come back lists, sets are refused], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== pickle and tempfile

Pickle serializes python objects for python consumers, and 3.14
moved its default: the protocol page states "Currently the default
protocol is 5", the data stream section adds "Protocol version 5 ...
adds support for out-of-band data and speedup for in-band data. It
is the default protocol starting with Python 3.14", and the
changelog rows read "Changed in version 3.8: The default protocol is
4" then "Changed in version 3.14: The default protocol is 5." The
sample pins the header byte, `\x80\x05`, and confirms that asking
for 6 is refused:

#listing("python/samples/src/Ch15/pickle_tempfile.py", first: 19, last: 30, caption: [the 3.14 default: protocol 5, its header byte, and the refusal of 6])

What protocol 5 enables is the out-of-band buffer path, pep 574's
design. An object whose `__reduce__` returns a `PickleBuffer` for a
large block does not get that block copied into the stream. Instead
`dumps` with a `buffer_callback` hands the buffer to the caller,
writes a marker into the stream, and `loads` reassembles the object
only when the same buffers are passed back. The sample demonstrates
the whole contract: one buffer handed over, the payload absent from
the blob, the object rebuilt, loading without buffers failing, and
`buffer_callback` under protocol 4 rejected:

#listing("python/samples/src/Ch15/pickle_tempfile.py", first: 33, last: 68, caption: [pep 574: buffers handed out, markers in the stream, data reassembled on load])

#callout("warning", "unpickling runs code", [
  The module page does not soften it: pickle "is not secure. Only
  unpickle data you trust. It is possible to construct malicious
  pickle data which will execute arbitrary code during unpickling."
  The sample proves the mechanism with a benign `__reduce__` that
  returns a function, and the function runs on load, checked. The
  spawn boundary in #xref-to("python", "multiprocessing") leans on
  pickle, which is why that chapter treats process arguments as
  trusted-by-construction and everything socket-facing as json.
])

Staging is tempfile's job. The module page sorts the surface: the
"high-level interfaces which provide automatic cleanup and can be
used as context managers" against the "lower-level functions which
require manual cleanup", `mkstemp()` and `mkdtemp()`. The atomic
write pattern stitches the two halves together: write a complete
file beside the target, then `os.replace` it over the target, which
on windows replaces an existing destination where `os.rename`
fails, probed on this machine. A `SpooledTemporaryFile` stays in
memory under its size limit, no name on disk, and rolls over to a
real file past it:

#listing("python/samples/src/Ch15/pickle_tempfile.py", first: 112, last: 153, caption: [stage beside the target, os.replace over it, spool until the limit])

#diagram([the pickle stream as a data structure, with buffers outside the frame], length: 13pt, {
  let box(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  box(0.6, 5.8, 5.4, 1.4, [dumps(obj, protocol=5)], fill: luma(205))
  box(7.6, 5.8, 6.2, 1.4, [in-band stream: opcode bytes, #linebreak] + [ class refs, markers])
  box(7.6, 3.4, 6.2, 1.4, [buffer callback: PickleBuffer views, #linebreak] + [ never copied in])
  box(15.8, 5.8, 6.2, 1.4, [loads(blob, buffers=...)])
  box(15.8, 3.4, 6.2, 1.4, [the object, reassembled])
  cdraw.line((6.0, 6.5), (7.6, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((13.8, 6.5), (15.8, 6.5), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.7, 5.8), (10.7, 4.8), stroke: luma(100), mark: (end: ">"))
  cdraw.line((10.7, 3.4), (12.0, 2.9), (15.8, 3.9), stroke: (paint: luma(140), dash: "dashed"), mark: (end: ">"))
  cdraw.content((13.4, 2.6), [the same buffers must ride back in], wrap: text.with(size: 6pt, fill: luma(100)))
  cdraw.content((11.3, 1.6), [header 0x80 0x05, protocol 4 streams carry everything in band], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((11.3, 0.7), [unpickling executes \_\_reduce\_\_ results: trust is a precondition, not a feature], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "what a green run of this chapter proves", [
  The four samples print 67 `ok` lines: path algebra and globs, the
  newline and encoding layers at the byte level, csv dialects and
  the doubled-row hazard, json conversions and the duplicate-key
  trap, pickle protocol 5 with out-of-band buffers, and the atomic
  write plus tempfile staging. All of it ran on cpython 3.14.7 with
  files under temp directories that the samples removed.
])

sources: docs.python.org/3.14 library/pathlib (read\_text signature
and newline note, glob), library/functions open (newline semantics),
library/csv (newline requirement, dialects), library/json, library/
pickle (DEFAULT\_PROTOCOL, data stream format, security warning),
library/tempfile, and peps.python.org pep 574, all accessed
2026-09-12. Sample behavior verified by `make verify-py`, 67 checks
in chapter 15.
