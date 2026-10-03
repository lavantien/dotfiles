#import "../../theme/lib.typ": listing, snippet, callout, xref-to, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= operational plumbing

Programs that outlive the terminal session need the same handful of
parts regardless of domain: a command line worth typing, logs that
survive the process, timestamps that mean the same thing tomorrow, and
identifiers and digests that do not collide. This chapter assembles
that kit from the standard library only: argparse for the command
line, logging for the record, datetime and zoneinfo for time,
os.environ for configuration, secrets, hashlib, and uuid for identity,
plus the two field tools, pdb and faulthandler, that earn their one
paragraph each. The 4 samples under `Ch19/` carry 28 checks on the
pinned 3.14.7 interpreter, and the time-zone check documents a machine
fact this book treats as a boundary rather than working around.

== argparse

The pattern is one parser, subcommands, and the exit codes the parser
owns. The subparsers page frames the shape: "Many programs split up
their functionality into a number of subcommands", and the construction
is four calls:

#listing("python/samples/src/Ch19/cli.py", first: 12, last: 21, caption: [one parser, two subcommands, a typed positional, a constrained choice, a default])

Three behaviors are doing the work. The `type=int` callable converts
the string before you see it, and the page pins the failure contract:
"If the function raises `ArgumentTypeError`, `TypeError`, or
`ValueError`, the exception is caught and a nicely formatted error
message is displayed." The `choices` check runs after that conversion,
"choices are checked after any type conversions have been performed",
so the tuple compares ints to ints. And the subparser was built with
`required=True`, so no subcommand at all is an error too. All three
failures follow one documented exit discipline: "it will print a
message to `sys.stderr` and exit with a status code of 2":

#listing("python/samples/src/Ch19/cli.py", first: 47, last: 62, caption: [bad type, bad choice, missing subcommand: each exits 2 with usage on stderr])

The help flag is free, "By default a help action is automatically added
to the parser", and it exits 0, probed here with stdout captured so
the check can read the listing it printed:

#listing("python/samples/src/Ch19/cli.py", first: 64, last: 74, caption: [--help exits 0 and lists every subcommand it built])

The tool shape that falls out is a function that builds the parser, a
`main` that parses and dispatches on `args.command`, and exit codes
that mean one thing each: 2 for usage errors the parser caught, 1 for
runtime failures the program caught, 0 for success. The verify gate of
this whole book leans on exactly that convention, and the capstone's
cli chapter, #xref-to("python", "capstone2"), builds on this sample's
shape.

#diagram([where one argv list goes: dispatch and the three exits], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 6.2, 5.0, 1.3, [argv list, #linebreak() parsed for the check])
  cell(7.2, 6.2, 7.0, 1.3, [the parser: subcommand, #linebreak() type, choices, defaults], fill: luma(205))
  cell(16.2, 7.6, 5.4, 1.2, [namespace, exit 0])
  cell(16.2, 5.9, 5.4, 1.2, [--help: exit 0, #linebreak() usage to stdout])
  cell(16.2, 4.2, 5.4, 1.2, [usage error: exit 2, #linebreak() message to stderr])
  cdraw.line((5.6, 6.85), (7.2, 6.85), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.2, 7.0), (16.2, 8.0), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.2, 6.4), (16.2, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.2, 5.7), (16.2, 4.7), stroke: luma(100), mark: (end: ">"))
  cell(3.6, 3.2, 11.2, 1.2, [dispatch on args.command: one handler per subcommand, #linebreak() each free to exit 1 on its own failures])
  cdraw.content((11.2, 1.4), [2 is the parser's, 1 is the program's, 0 is earned], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== logging

The module is a tree before it is anything else. "Multiple calls to
`getLogger()` with the same name will always return a reference to the
same Logger object", and the names are dotted paths: "Loggers that are
further down in the hierarchical list are children of loggers higher up
in the list", with every logger a descendant of the root. The
recommended construction `logging.getLogger(__name__)` makes the tree
match the package tree of #xref-to("python", "modules") for free:

#listing("python/samples/src/Ch19/logging_tree.py", first: 24, last: 31, caption: [one logger per name, app.worker hanging under app under root])

A level is a number, and the ladder is short: DEBUG 10, INFO 20,
WARNING 30, ERROR 40, CRITICAL 50, asserted exactly. A logger left at
NOTSET borrows upward, "the hierarchy is traversed towards the root
until a value other than NOTSET is found", and the root itself starts
armed at WARNING:

#listing("python/samples/src/Ch19/logging_tree.py", first: 44, last: 51, caption: [a notset child inherits the parent's effective level])

A record's path is decided by two different gates, and confusing them
is the classic logging bug. The logger's effective level decides
whether the record exists at all: `worker.debug` under an INFO parent
produces nothing anywhere. Then, for records that exist, "events
logged to this logger will be passed to the handlers of higher level
(ancestor) loggers", and each handler applies its own level
independently, so an ERROR-tinted handler drops a warning the
WARNING-tinted one kept. `propagate = False` cuts the climb, which is
how one subtree logs locally without duplicating to the root:

#listing("python/samples/src/Ch19/logging_tree.py", first: 53, last: 74, caption: [the same warning through two handlers, the filtered debug, the stopped climb])

The structured-field habit completes the picture. The `extra`
parameter is "a dictionary which is used to populate the `__dict__` of
the LogRecord created for the logging event with user-defined
attributes", with one reservation worth quoting: "The keys in the
dictionary passed in extra should not clash with the keys used by the
logging system." The sample attaches `request_id` and `attempts` and
reads them back off the record:

#listing("python/samples/src/Ch19/logging_tree.py", first: 85, last: 98, caption: [extra fields on the record, name and levelname intact])

Formatters are the rendering half, a format string over record
attributes like `%(name)s` and `%(levelname)s`. The sample keeps a
capture handler instead, because an assertion wants the record, not
the string.

#diagram([one warning's path down the tree: logger levels then handler levels then propagate], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 6.8, 5.4, 1.4, [logger app.worker #linebreak() level notset, effective 20], fill: luma(205))
  cell(0.6, 4.9, 5.4, 1.4, [logger app #linebreak() level info, 20])
  cell(0.6, 3.0, 5.4, 1.4, [root logger #linebreak() created at warning, 30])
  cdraw.line((3.3, 6.8), (3.3, 6.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.3, 4.9), (3.3, 4.4), stroke: luma(100), mark: (end: ">"))
  cdraw.content((4.6, 6.55), [parent], wrap: text.with(size: 6pt))
  cell(7.8, 4.9, 5.4, 1.4, [handler on worker #linebreak() level notset: takes it])
  cell(7.8, 3.0, 5.4, 1.4, [handler on root #linebreak() level notset: takes it])
  cdraw.line((6.0, 5.6), (7.8, 5.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.3, 3.0), (3.3, 2.4), stroke: luma(100))
  cdraw.line((3.3, 2.4), (10.5, 2.4), stroke: luma(100))
  cdraw.line((10.5, 2.4), (10.5, 3.0), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.6, 6.0), [propagate=false cuts #linebreak() every arrow left of the handlers], wrap: text.with(size: 6pt))
  cell(14.6, 4.9, 7.0, 1.4, [the debug call stops at the gate: #linebreak() effective level 20 says no])
  cdraw.line((13.2, 5.6), (14.6, 5.6), stroke: luma(140), mark: (end: "x"))
  cdraw.content((11.2, 1.2), [logger levels decide existence, handler levels decide landing, propagate decides reach], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== datetime and zoneinfo

The distinction that organizes everything is awareness. "Date and time
objects may be categorized as 'aware' or 'naive' depending on whether
or not they include time zone information", an aware object "represents
a specific moment in time that is not open to interpretation", while
for a naive one "whether a naive object represents Coordinated
Universal Time (UTC), local time, or some other time zone is purely up
to the program":

#listing("python/samples/src/Ch19/datetimes.py", first: 15, last: 21, caption: [naive carries no offset, replace() makes it aware])

The utc spellings were straightened in this decade. `datetime.UTC` is
an alias for the singleton, added in 3.11, and `utcnow()` is the
deprecated trap: "Deprecated since version 3.12: Use `datetime.now()`
with `UTC` instead", because it hands back a naive object. The page's
warning states the preference outright: "the recommended way to create
an object representing the current time in UTC is by calling
`datetime.now(timezone.utc)`":

#listing("python/samples/src/Ch19/datetimes.py", first: 23, last: 35, caption: [the utc singleton, an aware now, utcnow captured warning])

Parsing grew teeth in 3.11 and the sample leans on them:
`fromisoformat` now accepts "any valid ISO 8601 format", where
"Previously, this method only supported the formats that could be
emitted by `date.isoformat()` or `datetime.isoformat()`". The `Z`
suffix becomes real utc, `20260912T100000` parses, week dates parse,
and offsets come back as offsets:

#listing("python/samples/src/Ch19/datetimes.py", first: 37, last: 47, caption: [z, basic, week, and offset forms, all through fromisoformat])

Fixed-offset zones and the timestamp round trip carry the aware side,
and then the chapter hits the windows boundary the docs draw. The
zoneinfo module "does not directly provide time zone data, and instead
pulls time zone information from the system time zone database or the
first-party PyPI package tzdata, if available", and "Some systems,
including notably Windows systems, do not have an IANA database
available", so "it is recommended to declare a dependency on tzdata".
Without either source, "all calls to `ZoneInfo` will raise
`ZoneInfoNotFoundError`", and on this platform that sentence is
literal: a bare windows interpreter has no database at all, so even
`ZoneInfo("UTC")` raises, probed. This book's two run environments
sit on opposite sides of the line. The bare interpreter has no data
at all. The verify venv has tzdata, and not because anyone taught
it: pandas declares tzdata a hard dependency, probed with `pip show
tzdata` in that venv, version 2026.4, required-by pandas, so any
environment carrying the pandas pin of #xref-to("python", "pandas")
carries named zones with it. A check that expected one side would be
environment-dependent, the failure this book's rules ban, so the
sample asks `find_spec` which world it is in and asserts that
world's documented behavior:

#listing("python/samples/src/Ch19/datetimes.py", first: 61, last: 78, caption: [the tz boundary resolved by find\_spec: every call raises bare, ho chi minh plus 7 with tzdata])

Both branches are real assertions, and the ok line names which one
ran. The bare branch requires the documented exception from every
key it tries, and the tzdata branch pins the offset exactly, moves
10:00 utc to 17:00 plus seven, and round-trips back through utc, so
a green exit always means a documented behavior was verified, never
that the check closed its eyes.

#diagram([the datetime taxonomy: what each kind knows and where it can go], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 7.0, 6.4, 1.3, [naive datetime, #linebreak() tzinfo none], fill: luma(205))
  cell(8.2, 7.0, 6.4, 1.3, [aware datetime, #linebreak() utc or fixed offset], fill: luma(205))
  cell(15.8, 7.0, 6.0, 1.3, [zoneinfo zone, #linebreak() iana rules by key])
  cell(0.6, 5.0, 6.4, 1.4, [arithmetic is wall arithmetic, #linebreak() comparison is ambiguous])
  cell(8.2, 5.0, 6.4, 1.4, [astimezone converts, #linebreak() timestamp is defined])
  cell(15.8, 5.0, 6.0, 1.4, [needs system data #linebreak() or the tzdata package])
  cell(0.6, 3.0, 6.4, 1.4, [fromisoformat parses it, #linebreak() utcnow returns it, deprecated])
  cell(8.2, 3.0, 6.4, 1.4, [now(dt.utc), fromtimestamp(stamp, dt.utc), #linebreak() z suffix parses to utc])
  cell(15.8, 3.0, 6.0, 1.4, [windows: no system db, #linebreak() tzdata is the source])
  cdraw.line((3.8, 7.0), (3.8, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.4, 7.0), (11.4, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.8, 7.0), (18.8, 6.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.6, 7.65), (15.8, 7.65), stroke: luma(140), mark: (end: ">"))
  cdraw.content((15.2, 7.95), [replace(tzinfo=...)], wrap: text.with(size: 6pt))
  cdraw.content((11.2, 1.4), [aware is the default habit, utc is the default zone, the iana rules are a dependency], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== env, secrets, hashing

Configuration arrives through the environment, and chapter 16 already
owns the process side, #xref-to("python", "processes"). The
operational half is small: `os.environ` is a live mapping, reads
through `os.getenv`, and on windows `os.path.expandvars` expands
`%NAME%` spellings, probed:

#listing("python/samples/src/Ch19/operational.py", first: 21, last: 30, caption: [set, read, percent-expand, delete, all through the one mapping])

Identity and secrecy are separate purchases and the docs separate them
sharply. The secrets page: "The `secrets` module is used for
generating cryptographically strong random numbers suitable for
managing data such as passwords, account authentication, security
tokens, and related secrets", and in particular "secrets should be
used in preference to the default pseudo-random number generator in
the `random` module, which is designed for modelling and simulation,
not security or cryptography." The sample shows both faces: two
`Random(1401)` objects repeat their sequence exactly, while
`token_hex` never repeats and takes no seed at all:

#listing("python/samples/src/Ch19/operational.py", first: 32, last: 47, caption: [tokens from secrets, repeatable draws from a seeded random])

Digests are the other identity axis. sha256 over empty input is a
pinned constant, blake2b takes a `digest_size`, and since 3.11
`hashlib.file_digest` hashes an open file in one call, the same digest
as the streaming version over the same bytes, the file-reading half
being #xref-to("python", "files") territory:

#listing("python/samples/src/Ch19/operational.py", first: 49, last: 61, caption: [the empty-input constant, a sized blake2b, file\_digest on disk])

Identifiers have kinds. `uuid4` is random and never repeats, `uuid5`
is a deterministic hash of a namespace and a name, `uuid3` the same
over md5, and `uuid1` stamps the host and clock, which is why its
string leaks machine information into logs. The sample pins versions,
stability, and the 36-character form. The last two tools cost one
paragraph because they cost nothing to carry: `faulthandler.enable()`
installs a handler that dumps native tracebacks on hard crashes, off
by default and flipped in one check, and `python -m pdb script.py`,
or `breakpoint()` mid-run, drops into the standard debugger when a
print statement will not reach the failure.

#diagram([the operational toolkit as one pipeline: config in, identity out], length: 13pt, {
  let cell(x, y, w, h, t, fill: luma(235)) = {
    cdraw.rect((x, y), (x + w, y + h), fill: fill, radius: 0.02)
    cdraw.content((x + w / 2, y + h / 2), t, wrap: text.with(size: 6pt))
  }
  cell(0.6, 6.6, 4.6, 1.4, [os.environ, #linebreak() the config source], fill: luma(205))
  cell(6.2, 6.6, 4.6, 1.4, [argparse, #linebreak() the overrides])
  cell(11.8, 6.6, 4.6, 1.4, [logging, #linebreak() the record])
  cell(17.4, 6.6, 4.4, 1.4, [datetimes, #linebreak() the stamps], fill: luma(205))
  cell(3.0, 4.2, 6.0, 1.4, [secrets: tokens, #linebreak() no seed, never repeats])
  cell(11.0, 4.2, 6.0, 1.4, [hashlib: digests, #linebreak() streaming or file\_digest])
  cell(17.4, 4.2, 4.4, 1.4, [uuid: 1, 3, 4, 5, #linebreak() four kinds])
  cdraw.line((5.2, 6.6), (4.6, 5.6), stroke: luma(140))
  cdraw.line((18.6, 6.6), (18.6, 5.6), stroke: luma(140))
  cdraw.line((14.0, 6.6), (14.0, 5.6), stroke: luma(140))
  cell(6.2, 2.0, 10.4, 1.3, [logs and records carry the ids and digests: r-17 in extra, request traced by uuid], fill: luma(220))
  cdraw.line((6.0, 4.2), (8.0, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((14.0, 4.2), (14.0, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.line((18.6, 4.2), (16.6, 3.3), stroke: luma(100), mark: (end: ">"))
  cdraw.content((11.2, 0.8), [faulthandler and pdb ride along for the crash and the pause], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "chapter 19 in the gate", [
  The 4 samples under `python/samples/src/Ch19/` print 28 ok lines:
  `cli.py` 5, `logging_tree.py` 8, `datetimes.py` 8, `operational.py`
  7. The argparse error paths capture stderr so the gate output stays
  clean, the logging sample attaches and removes its handlers instead
  of mutating the root permanently, and the zoneinfo check resolves
  its environment through `find_spec` and asserts the documented
  behavior of whichever side it lands on, every call raising on a
  bare interpreter, ho chi minh plus 7 with a utc round trip under
  tzdata, so it stays honest in both.
])

sources: docs.python.org/3.14/library/argparse.html (error exits with
status 2, subcommands, the type-callable exception contract, choices
after conversion, the automatic help action),
docs.python.org/3.14/library/logging.html (getLogger identity, the
name hierarchy, propagate, notset delegation, the root's warning
level, the extra parameter and its key reservation),
docs.python.org/3.14/library/datetime.html (aware versus naive, the
UTC alias added 3.11, the utcnow deprecation since 3.12 and the
recommended now(timezone.utc), fromisoformat's 3.11 expansion),
docs.python.org/3.14/library/zoneinfo.html (data sources, the windows
absence of an iana database, the tzdata recommendation,
ZoneInfoNotFoundError), docs.python.org/3.14/library/secrets.html
(cryptographically strong numbers, preference over the random module's
default generator), all accessed 2026-09-12; the exit-0 help run, the
percent expansion, the 22-character token\_urlsafe, the bare
interpreter's ZoneInfoNotFoundError, the venv's tzdata-backed ho chi
minh offset, and pip's required-by pandas line probed on this
machine the same day. Sample
behavior verified by `make verify-py`, 28 checks in chapter 19.
