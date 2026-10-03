#import "../../theme/lib.typ": listing, snippet, callout, diagram, cdraw, flow
#import "@preview/fletcher:0.5.8": node, edge

= toolchain: cpython 3.14 on windows

Every claim in this book runs before it is printed. This chapter pins the
interpreter that makes that sentence true: cpython 3.14.7, the current
patch of the 3.14 line, installed per user and reached through the py
launcher. Another python, 3.13.15 and also current, sits earlier on PATH
and never runs a sample. Ruff 0.16.7 plays the role clang-format plays
in the c book: the formatter and linter every sample must satisfy before
it counts as green, pinned tools-only in the same requirements file as
the libraries.

== the interpreter and the launchers

Windows installs are per user by default, and this machine follows the
default: the 3.14 line lives under
`%LOCALAPPDATA%\Programs\Python\Python314`, and the py launcher lists it
as `-V:3.14`. The launcher is the honest entry point precisely because
bare `python` is not: on this box `python` resolves to a 3.13.15 in the
same tree, one major line older. The gate in `tools/run-py-samples.ps1`
therefore resolves the interpreter itself, trying `py -3.14` first, then
PATH candidates that report 3.14, then the per-user fallback path, and
refuses to run at all when none of them answers.

The gate also owns a venv under `tools\python\build\`, its directory
name derived from the requirements hash, created with the
resolved interpreter and filled from `books/python/requirements.txt`:
pydantic 2.13.4, pandas 3.0.5, numpy 2.5.3, fastapi 0.141.1, and ruff
as the tools-only formatter, plus httpx2 2.12.0 for the test suites
that drive fastapi's TestClient on the current starlette line, never
imported by a sample, and starlette 1.6.0 itself, pinned so the venv
reproduces the exact asgi base chapter 22 asserts. The sha256 of the
requirements file names the venv directory: a changed pin builds a
fresh venv alongside the old one instead of deleting a venv another
run may still be using, and an unchanged hash reuses the built one.
The first sample asserts the whole chain from inside:

#listing("python/samples/src/Ch01/version.py", first: 1, last: 42, caption: [the check contract every sample carries, the exact 3.14.7 pin, and the venv asserts])

The `ok` function is the whole testing convention of this book: a check
prints one `ok N name` line and moves on, or raises `SystemExit` with a
`FAIL` message and a nonzero exit. The harness counts the `ok` lines,
fails on any nonzero exit, and the chapter's closing callout quotes the
count. The version checks are deliberately exact: a 3.14.8 that arrives
tomorrow turns this sample red until the book re-pins, and that is the
point. Nothing is tested by eyeball.

#callout("note", "why samples assert the venv too", [
  The last three checks pin the launch chain, not just the version:
  `sys.prefix` differing from `sys.base_prefix` proves a venv is active,
  the executable living under `Scripts` proves the gate's venv is the
  one running, and `sys._base_executable` still pointing into
  `Python314` proves the resolution ended at the per-user 3.14, never
  at the PATH python. A wrong interpreter is a loud red before any
  behavioral claim runs.
])

#diagram([the launch chain, from the py launcher to the venv that runs every sample], length: 13pt, {
  let box(x, y, w, t) = {
    cdraw.rect((x, y), (x + w, y + 1.0), fill: luma(235), radius: 0.02)
    cdraw.content((x + w / 2, y + 0.5), t, wrap: text.with(size: 6pt))
  }
  box(0.4, 4.4, 2.6, [py -3.14])
  box(4.0, 4.4, 3.6, [per-user install, #linebreak() cpython 3.14.7])
  box(8.6, 4.4, 3.0, [gate builds venv, #linebreak() pip installs pins])
  box(12.6, 4.4, 3.4, [the book venv, #linebreak() six pins plus ruff])
  box(17.0, 4.4, 3.4, [-X utf8 runs #linebreak() every sample])
  cdraw.line((3.0, 4.9), (4.0, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((7.6, 4.9), (8.6, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.6, 4.9), (12.6, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.line((16.0, 4.9), (17.0, 4.9), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.6, 2.7), (11.6, 3.7), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((10.1, 3.2), [PATH python 3.13.15], wrap: text.with(size: 6pt, fill: luma(140)))
  cdraw.content((10.1, 2.1), [one major line older, never runs a sample], wrap: text.with(size: 6.5pt, fill: luma(100)))
  cdraw.content((10.5, 1.1), [the requirements.txt sha256 names the venv directory, #linebreak() imported modules cache their bytecode next to the source], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== running code five ways

The interpreter has five everyday entrances, and each one answers the
same three questions differently: what leads `sys.path[0]`, what sits in
`sys.argv[0]`, and which module owns the name `__main__`. A script run
by path puts its own directory first on the path and its own path in
`argv[0]`. A module run with `-m` puts the cwd first and the module
file's full path in `argv[0]`. A string run with `-c` puts an empty path
entry that reads as the cwd and the literal `-c` in `argv[0]`, probed on
this machine. The repl reads from stdin with no file and an empty
`argv[0]`. A console entry point, the exe a pinned library can install,
is a generated wrapper whose target is the package's main hook. The gate
uses the first way exclusively: absolute script path from a foreign
working directory, so a sample that wants to know where it stands must
ask, not assume:

#listing("python/samples/src/Ch01/invocation.py", first: 1, last: 26, caption: [invocation facts checked from inside: main module, argv, path head, foreign cwd])

The five checks are the ones a harness can see. `__name__` equal to
`__main__` is the fact the guard at the bottom tests for: it lets the
same file serve as a script and as an importable module without
re-running its checks, and it is the guard multiprocessing needs on
windows, which chapter 18 relies on. The `interactive` flag being 0
separates this run from the repl. The last two checks encode the gate's
promise: the script's directory leads the path, and the cwd is somewhere
else entirely, a fresh temp directory per sample, so no sample can
accidentally read a file it did not create.

#diagram([the five entrances and what each one sets], length: 13pt, {
  let way(x, name, sub) = {
    cdraw.rect((x, 4.0), (x + 3.6, 5.3), fill: luma(235), radius: 0.02)
    cdraw.content((x + 1.8, 4.9), name, wrap: text.with(size: 6pt))
    cdraw.content((x + 1.8, 4.35), sub, wrap: text.with(size: 6pt, fill: luma(100)))
  }
  way(0.4, [script], [by path, its directory #linebreak() leads the path])
  way(4.7, [-m module], [the cwd leads, #linebreak() module file in argv])
  way(9.0, [-c string], [empty entry reads as #linebreak() the cwd, argv is -c])
  way(13.3, [repl], [no file, empty argv, #linebreak() interactive flag set])
  way(17.6, [console script], [generated exe, the #linebreak() package main runs])
  cdraw.content((10.8, 3.0), [every entrance but the repl runs a module in the main role, #linebreak() the guard keeps that module importable without re-running checks], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== the verify gate

`make verify-py` runs the harness in `tools/run-py-samples.ps1`. It
resolves the 3.14 interpreter, then walks every chapter's samples
through six legs: toolchain, venv, run, format, expect-dis, capstone.
The run leg executes each sample under the venv python with `-X utf8`
from a fresh temp directory and counts its `ok` lines. The format leg
runs ruff check and ruff format over the whole book directory against
`books/python/ruff.toml`: 88 columns, py314, a lint select frozen to
the classic error set, because ruff 0.16 grew its default rules from 59
to 413 and a minor upgrade must not redden a pinned book. The expect-dis
leg reads pipe-separated rows from each chapter's `expect-dis.txt` and
asserts the named substring appears in the named function's bytecode,
through `tools/py-dis-check.py`, which compiles the source without
executing it and matches nested code objects by qualname. Only stable
base opnames may be asserted, because cpython 3.14 specializes
instructions as they warm up. The capstone leg runs `unittest discover`
over the capstone suite under `books/python/capstone`, 78 tests across
10 files, and counts them in the same report line; if that suite were
ever absent the leg would say so and pass with zero tests, stated
rather than skipped silently. Any leg failing turns the target red, and
`make verify` fails with it.

#callout("verify", "the gate was written test first", [
  While proving the harness, `version.py` briefly asserted 3.14.6. The
  run leg answered `FAIL cpython 3.14.6 expected (check 1)` and exited
  1, turning the whole gate red. Restoring the exact pin turned it
  green again. That red-then-green pair is the evidence the harness
  reports failures rather than rubber-stamping output.
])

#diagram([one sample through the six legs of the verify gate], length: 13pt, {
  let leg(x, y, t) = {
    cdraw.rect((x, y), (x + 6.0, y + 1.2), fill: luma(235), radius: 0.02)
    cdraw.content((x + 3.0, y + 0.6), t, wrap: text.with(size: 6pt))
  }
  leg(0.4, 9.0, [1 toolchain: resolve #linebreak() cpython 3.14 or refuse])
  leg(0.4, 7.2, [2 venv: requirements sha256, #linebreak() rebuild or reuse])
  leg(0.4, 5.4, [3 run: -X utf8, foreign cwd, #linebreak() exit 0, count ok lines])
  leg(8.8, 9.0, [4 format: ruff check and #linebreak() format over the book])
  leg(8.8, 7.2, [5 expect-dis: base opnames #linebreak() in compiled bytecode])
  leg(8.8, 5.4, [6 capstone: unittest suite, #linebreak() 10 files, 78 tests])
  cdraw.line((3.4, 9.0), (3.4, 8.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((3.4, 7.2), (3.4, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((6.4, 6.0), (8.8, 9.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.8, 9.0), (11.8, 8.4), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.8, 7.2), (11.8, 6.6), stroke: luma(100), mark: (end: ">"))
  cdraw.line((11.8, 5.4), (11.8, 4.6), stroke: luma(100), mark: (end: ">"))
  cdraw.rect((8.8, 3.4), (14.8, 4.6), fill: luma(205), radius: 0.02)
  cdraw.content((11.8, 4.0), [green: files, checks, dis assertions, #linebreak() format clean, capstone tests], wrap: text.with(size: 6pt))
  cdraw.rect((0.4, 3.4), (6.4, 4.6), stroke: (paint: luma(160), dash: "dashed"), radius: 0.02)
  cdraw.content((3.4, 4.0), [any leg fails: red, #linebreak() make verify stops there], wrap: text.with(size: 6pt, fill: luma(140)))
  cdraw.content((8.8, 10.6), [exit codes decide, never eyeballs], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

== utf-8 mode and the windows console

Windows python already does the right thing where the user looks: an
interactive console reads and writes through the wide-character api,
utf-8 end to end, with or without any flag. The hazards live one layer
down, in what the locale decides when no encoding is named. Probed on
this machine: `locale.getpreferredencoding(False)` answers cp1252 in a
plain run, and that answer is what `open()` uses when no `encoding=`
is passed and what redirected output falls back to. The command line
flag `-X utf8`, or the environment variable `PYTHONUTF8` which is the
same switch, flips the locale answer to utf-8, and the gate passes the
flag to every sample run:

#listing("python/samples/src/Ch01/utf8.py", first: 1, last: 29, caption: [utf-8 mode from inside: the flag, the locale answer, and a default-encoding round trip])

The probe check is the one that would hurt without the flag: the text
contains characters cp1252 cannot encode, so `write_text` with no
encoding argument would raise on this box instead of round tripping.
One wrinkle the probe surfaced: this machine exports
`PYTHONIOENCODING=utf-8:surrogateescape`, which already covers pipes by
itself, so the piped-stdout check proves the gate's guarantee rather
than the flag alone. Chapter 15 makes the habit explicit anyway:
`encoding=` on every open, flag or no flag. And the boundary is moving:
pep 686 makes utf-8 mode the default in 3.15, at which point the left
column of the figure below becomes the historical one.

#callout("pitfall", "the console is not where utf-8 mode bites", [
  Interactive stdout and stderr on windows use the console's
  wide-character api and are utf-8 regardless of any flag. What the
  flag changes is the locale-preferred encoding that `open()`, pipes,
  and redirected streams fall back to when nothing names an encoding.
  Testing by printing to a terminal proves nothing; the round-trip
  check writes a file, which is where cp1252 actually bites.
])

#diagram([what changes with -X utf8: the console never did, files and pipes do], length: 13pt, {
  let left(y, t) = {
    cdraw.rect((0.4, y), (6.8, y + 1.1), fill: luma(235), radius: 0.02)
    cdraw.content((3.6, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  let right(y, t) = {
    cdraw.rect((10.8, y), (17.2, y + 1.1), fill: luma(205), radius: 0.02)
    cdraw.content((14.0, y + 0.55), t, wrap: text.with(size: 6pt))
  }
  cdraw.content((3.6, 7.6), [a plain run], wrap: text.with(size: 6.5pt))
  cdraw.content((14.0, 7.6), [-X utf8, or PYTHONUTF8], wrap: text.with(size: 6.5pt))
  left(6.1, [console: utf-8 already, #linebreak() the wide-character api])
  left(4.5, [files: open() follows the locale, #linebreak() cp1252 on this box])
  left(2.9, [redirected output: the locale, #linebreak() unless an env override])
  right(6.1, [console: unchanged, #linebreak() still utf-8])
  right(4.5, [preferred encoding answers utf-8, #linebreak() open() defaults follow])
  right(2.9, [piped stdout: utf-8, #linebreak() file round trips hold])
  cdraw.line((6.8, 5.05), (10.8, 5.05), stroke: luma(100), mark: (end: ">"))
  cdraw.content((8.8, 5.6), [the gate passes #linebreak() -X utf8 always], wrap: text.with(size: 6.5pt))
  cdraw.content((8.8, 1.7), [3.15 makes the right column the default (pep 686)], wrap: text.with(size: 6.5pt, fill: luma(100)))
})

#callout("verify", "what a green run proves", [
  A scoped run, `pwsh tools/run-py-samples.ps1 -Chapter Ch01`, walks
  this chapter's three samples and reports: 3 files, 18 checks,
  0 dis assertions, format clean, 0 capstone tests. The dis leg is
  fully live but chapter 1 pins no bytecode rows; chapter 2 starts
  asserting base opnames. The capstone leg belongs to no chapter, so
  the scoped run skips it with a stated line and reports zero; the
  unscoped `make verify-py` runs the suite itself, 78 tests across
  10 files.
])

sources: docs.python.org/using/windows (per-user installs, the py
launcher), docs.python.org/using/cmdline (-X utf8, PYTHONUTF8, -c, -m),
docs.python.org/library/sys (flags, implementation, path, argv),
docs.python.org/library/venv, docs.python.org/library/locale
(getpreferredencoding), peps.python.org/pep-0686 (utf-8 mode by default
in 3.15), accessed 2026-09-12. Interpreter paths, encodings, and the
PYTHONIOENCODING export probed on this machine the same day. Sample
behavior verified by `make verify-py`, 18 checks in chapter 1 of the
samples suite.
